---
name: diff-summarizer
description: "Reads a single code repository's PR diff(s) and returns a documentation-focused summary. Host-aware resolver — uses the gh CLI for GitHub when available, falls back to pure-local-git strategies for Bitbucket Cloud, Bitbucket Server, and GitHub when gh is not installed or not authenticated, cannot make the PR's commits local, or returns an empty range. Designed for parallel invocation (one instance per repo, capped at 4 concurrent by the caller). Model tier assigned by the caller per the model-routing policy (no fixed pin)."
tools: [view, glob, grep, bash]
---

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/handoff/diff-summarizer.md` for the exact input/output document format.

Summarise a single code repository's PR diff(s) from a documentation-consumer's point of view. One instance per repo; the caller (the `document:` command) spawns up to 4 concurrent instances per batch.

## Inputs

```yaml
repo_path:   <absolute path to a local clone, e.g. /workspace/<repo-name>>
repo_url_slug: <repo slug from the PR URL, e.g. "cluster"; optional>
pr_refs:
  - url:         <full PR URL>
    host:        github_cloud | bitbucket_cloud | bitbucket_server | other
    repo:        <repo name>
    owner:       <github_cloud: <OWNER>; bitbucket_cloud: <WORKSPACE>; null otherwise>
    pr_id:       <id>
    branch_from: <feature branch from jira-reader>
    branch_to:   <target branch from jira-reader>
    title:       <link text>
    source_item: <Jira key of the item the PR link was found in, from jira-reader>
    status:      MERGED | OPEN | DECLINED | UNKNOWN
context: |
  <what this repo's PRs relate to — for documentation focus>
jira_keys_hierarchy:   # optional; passed by caller to enable Strategy 4 cross-key grep
  - <VI-KEY>
  - <every Epic/Story/Sub-task/Research/RFA/Bug key discovered by jira-reader>
refresh:
  fetch: true   # default true
  pull:  false  # default false — historical PR diffs do not need the current branch tip;
                # pulling risks moving HEAD away from the merge commit we want to reach.
```

Refuse to run without `repo_path` and at least one element in `pr_refs`.

When `repo_url_slug` is provided, before summarising run
`git -C <repo_path> remote get-url origin`, strip a trailing `.git`, and compare
the URL's last path segment to `repo_url_slug`. On mismatch, return
`status: REPO_MISSING` with a note naming both slugs — do NOT summarise the wrong
repository. When `repo_url_slug` is absent, trust `repo_path` as given.

## Resolver selection by host

Inspect `pr_refs[*].host` and route per-PR. Rule: **if the URL is on a cloud service AND an official CLI is available locally, use the CLI; otherwise fall back to pure-local-git strategies against the cloned repo.**

| Category | Detected by | Cloud CLI (preferred when installed + authenticated) | Fallback |
|---|---|---|---|
| `github_cloud` | `host == github.com` | `gh` CLI (see **GitHub resolver** below) | Local-git Strategies 1–4 |
| `bitbucket_cloud` | `host == bitbucket.org` | none shipped (no vetted official CLI at time of writing) | Local-git Strategies 1–4 |
| `bitbucket_server` | `host` contains the substring `bitbucket` and is NOT `bitbucket.org` | none | Local-git Strategies 1–4 |
| `other` | anything else | — | Record as `unresolved` with `reason: unsupported host <host>`; caller escalates |

**Fallback semantics:** when a cloud URL's preferred CLI cannot resolve the PR — not installed or not authenticated on the host, its commits not available locally, or its range empty (GitHub resolver steps 2–4) — silently fall back to the local-git strategies. The repo must still be cloned under the `repo_path` for the fallback to succeed; if it isn't, the per-PR result is `unresolved` with `reason: CLI could not resolve the PR, and the local-git strategies did not either`.

## URL parse notes

- **Bitbucket Server** — extract only `<REPO_NAME>` for the local-lookup path. `<PROJECT_KEY>` identifies the Bitbucket project namespace on the server and plays no role in local resolution.
- **Bitbucket Cloud** — `<WORKSPACE>` is analogous to Server's `<PROJECT_KEY>` and is not used for local lookup.
- **GitHub** — `<REPO_NAME>` is the only piece used for the filesystem path; `<OWNER>` is passed to `gh --repo <OWNER>/<REPO>` but not used in the path.

## Local-git strategies (pure local; no HTTPS)

Used for Bitbucket Server, Bitbucket Cloud, and GitHub when `gh` cannot resolve the PR — not installed or not authenticated, its commits not available locally, or its range empty (GitHub resolver steps 2–4).

**What the placeholders below name.** `<pr_id>` is the element's `pr_id`, `<target_branch>` its `branch_to`, and `<issue_key>` its `source_item`.

**Read `<target_branch>` where it is current.** The Refresh step's fetch moves `origin/<target_branch>`, and a local `<target_branch>` moves only under `refresh.pull`. So wherever `refs/remotes/origin/<target_branch>` exists and the local branch is absent or an ancestor of it (`git -C "<repo_path>" merge-base --is-ancestor <target_branch> origin/<target_branch>`), read `origin/<target_branch>` for every `<target_branch>` below; otherwise read it as given. A stale local branch reads a PR merged since it stopped as not landed, and dates the fork point to wherever it stopped, which carries other PRs' work into the diff.

**Every diff Strategies 1–3 take is `git -C "<repo_path>" diff <base>...<head>` — three dots, as the `gh` path's is.** Its merge base is the fork point whichever base a strategy names, so the target branch's own changes since the fork never enter the PR's diff — as a two-dot tree diff between a merge's two parents would carry them, reversed. Strategy 4 reads matched commits one at a time instead (below).

**A head that has already landed has an empty merge-base range, so test for it before deriving a base.** Once Strategy 1 or 2 has chosen a head, run `git -C "<repo_path>" merge-base --is-ancestor <head> <target_branch>`. Where it exits 1 the head is not on the target — an open PR, or one squash- or rebase-merged — and the strategy's own base stands. Any other status means `<target_branch>` does not resolve in the clone; fall through to Strategy 3. Where it exits 0, `merge-base <target_branch> <head>` returns `head` itself and the range is empty; read the merge that landed it instead:

- **Find `landing`** — the oldest commit on `<target_branch>`'s first-parent line that descends from `head`, which is the last commit both lists share: `git -C "<repo_path>" rev-list --first-parent <head>..<target_branch> | grep -Fx -f <(git -C "<repo_path>" rev-list --ancestry-path <head>..<target_branch>) | tail -n 1`. The two lists are taken separately because the two flags in one call follow first-parent edges only, and find nothing for a PR that reached the target through an intermediate branch's merge.
- **Read the merge.** Where `landing` exists, `git -C "<repo_path>" rev-list --parents -n 1 <landing>` names two or more parents, and `git -C "<repo_path>" merge-base --is-ancestor <head> <landing>^1` exits non-zero — `head` arrived through one of the merge's later parents — base = `<landing>^1`, and the diff is `<landing>^1...<head>` under the strategy's own `resolved_via`.
- **Otherwise there is no merge to read** — no `landing`, a `landing` with one parent (a fast-forward), or a `head` the merge's first parent already holds. Fall through to Strategy 3.

**An empty range is never a resolution.** A strategy — the `gh` resolver included — whose range changes no file (`git -C "<repo_path>" diff --quiet <range>` exits 0) has not resolved the PR, and falls through to the next.

1. **Strategy 1 — Bitbucket Server PR refs (optimistic; usually absent).** Try `git -C "<repo_path>" rev-parse refs/pull-requests/<pr_id>/from`. If present, use as head; derive base via `git -C "<repo_path>" merge-base <target_branch> <head>` — or, where the head has already landed, from the merge that landed it (above). If the ref does not exist (the default for a fresh clone), fall through to Strategy 2. Do NOT attempt to configure the refspec or fetch it at runtime — that is an explicit opt-in step for the user, not an automatic side effect. On Bitbucket Cloud and GitHub clones these refs don't exist either — Strategy 1 simply no-ops and the resolver moves on.

2. **Strategy 2 — Branch search.** Run `git -C "<repo_path>" branch -a --list "*<pr_id>*"` and `git -C "<repo_path>" branch -a --list "*<issue_key>*"`. If **exactly one** branch matches → use as head, with its base derived as in Strategy 1, the landed-head rule above included. If **0 matches** (branch deleted after merge — common for merged PRs) or **2+ matches** (multiple revisions of the feature branch, or overlapping issue keys) → fall through silently to Strategy 3. Do NOT prompt the user here; unresolved PRs are aggregated and surfaced once via the caller's escalation for "All PRs unresolved".

3. **Strategy 3 — Merge-commit search.** Run `git -C "<repo_path>" log --all -E --grep="[Pp]ull[ _-]?[Rr]equest[ _-]?#?<pr_id>\b" --format='%H %P %s'` — one line per candidate, its sha, its parents and its subject, which is all the test below reads — with no `-n` cap: every later commit whose body mentions the PR is newer than its merge, so a cap cuts the merge first, as printing those bodies would bury it. The pattern matches the subjects forges write for a merged PR — `Pull request #<pr_id>: …` (Bitbucket Server), `Merge pull request #<pr_id> …` (GitHub's `from …`, and an older Bitbucket Server's `in <project>/<repo> from …`), `Merged in <branch> (pull request #<pr_id>)` (Bitbucket Cloud) — and also any message body that mentions the PR, so it returns candidates, not answers. **Read the PR from the newest candidate that qualifies, and discard the rest; fall through to Strategy 4 where none qualifies, or where the one read changes no file.**
   - **A candidate qualifies** only where its **subject** has one of the three forms above for this `<pr_id>` and it is not a `Revert "…"` commit: a merge's or a squash's body lists other commits' messages, so a match there — or the PR number inside other text — names some other change.
   - **Read a qualifying merge commit** as head = `<commit>^2`, base = `<commit>^1`; **a qualifying one-parent commit** — a squash — as head = `<commit>`, base = `<commit>^1`, which reads that commit's own change.
   - **There is no search by the PR's title.** A title's words also match other PRs' merges — a sibling PR's, or a release PR merging the target onward, whose `^1...^2` is another change — and a fast-forwarded PR's own commits one at a time. Read as this PR, any of them is a wrong diff with no caveat, where Strategy 4 reads the key's own commits and says what it did.

4. **Strategy 4 — Cross-hierarchy Jira-key commit search (last resort).** If the caller supplied `jira_keys_hierarchy`, for each key run `git -C "<repo_path>" log --all -E --grep='(^|[^A-Za-z0-9_-])<key>([^A-Za-z0-9_-]|$)' --oneline` — the whole-key ERE form: the key's ERE metacharacters escaped, both edges anchored to a non-identifier boundary (or start/end of string), so a key `ACME-7` finds `[ACME-7]` and never `[ACME-77]` or `[ACME-70-01]`. **Trade-off:** this also stops matching a merge-commit title like `Merge branch feat/ACME-7-x`, where the key is a branch-name substring rather than delimited on both sides — Strategy 3 does not read it either, since its subject test takes only a forge's own PR forms; this search finds such a PR only through the branch's own commits, and only where they carry the key delimited. Treat matches as "commits associated with this feature" rather than a specific reconstructed PR. Return every match's full diff (`git -C "<repo_path>" show --format= <sha>`) as a **separate per-PR entry** — a match whose `show` prints no change, as a clean merge commit's does not, is not an entry — with `pr_id: <the PR's own id, best-effort>` and `resolved_via: jira_key_commits`. Annotate the `summary` explicitly:
   *"Diff reconstructed from commit <sha> matched on Jira key <key>; this may not correspond to the original PR content exactly."*

   If Strategies 1–3 did not resolve the PR — its merge commit and branch both missing, or present but leaving no merge to read and no range that changes a file — but Strategy 4 returns at least one entry: the PR is **partially resolved** — content is drawn from key-matched commits, and the output notes this clearly.

   If `jira_keys_hierarchy` is not provided, fall back to the original single-key behaviour (grep only the PR's own `source_item` key) and emit candidate SHAs in `unresolved_prs` for user review.

If all four strategies fail — an empty range, or a Strategy 4 whose every match prints no change, counts as a failure — record the PR under `unresolved_prs` and continue. The caller handles user-facing escalation.

**Note on non-MERGED PRs.** The default filter is MERGED-only. If the caller opts into OPEN / DECLINED / UNKNOWN PRs, expect a high rate of `unresolved`: DECLINED PRs often have no merge commit (Strategy 3 fails) and feature branches may have been deleted after decline (Strategy 2 fails). Surface the unresolved count clearly in `aggregate_summary` so the documentation writer knows what's missing.

## GitHub resolver (via `gh` CLI, used when `host == github_cloud` AND `gh` is installed + authenticated)

1. **Resolve head/base SHAs.** Run `gh pr view <pr_id> --repo <owner>/<repo> --json headRefOid,baseRefOid,state,title,mergeCommit`. This is the single authoritative call. `gh` handles authentication via `gh auth login` (configured once on the host).

2. **Ensure commits are local.** If `headRefOid` or `baseRefOid` is missing from the local clone (`git -C "<repo_path>" cat-file -e <sha>` returns non-zero):
   - If `refresh.fetch` is true AND the mount is not read-only (per the Refresh step's read-only detection, item 2 below): run `git -C "<repo_path>" fetch origin <headRefOid> <baseRefOid>`. If fetch is rejected (server refuses direct-SHA fetch), fetch the PR's head ref instead — `git -C "<repo_path>" fetch origin pull/<pr_id>/head`, which writes only `FETCH_HEAD` and the objects and leaves the working tree alone. Never `gh pr checkout`, which switches the working tree (below). Where that fetch fails too, or `git -C "<repo_path>" cat-file -e` still finds either commit missing, drop to the local-git strategies, as for a missing `gh`.
   - Otherwise (`refresh.fetch` is false, or the mount is read-only): do NOT run `git fetch` and do NOT run `gh pr checkout` — both write, and the latter also moves the working tree. Drop to the local-git strategies, which read only the object database; where they fail too, record the PR under `unresolved_prs` with `reason: "commits not present locally; fetching disabled by refresh.fetch: false"` (or `"commits not present locally; fetching disabled by a read-only mount"`, as applicable), and continue to the next PR.

3. **Produce diff.** `git -C "<repo_path>" diff <baseRefOid>...<headRefOid>` — three dots, so a base that moved after the fork contributes nothing to the PR's diff. Set `resolved_via: gh_cli`. Where that range changes no file it has not resolved the PR: drop to the local-git strategies, as for a missing `gh`.

4. **Failure modes:**
   - `gh` not installed → drop to local-git strategies (do NOT set `REFRESH_BLOCKED` — the fallback may still succeed).
   - Not authenticated → same fallback.
   - The range changes no file → same fallback (step 3).
   - The commits cannot be made local (step 2) → same fallback.
   - PR not found (deleted, private, wrong repo) → record in `unresolved_prs` with the gh error; do NOT fall back (the local repo won't have it either).

**Every command names `repo_path`.** Your Bash tool starts every call in the session's directory — where the dispatching command stands, which need not be `repo_path` — and a `cd` does not persist between calls, so a bare `git` fetches, switches and reads the session's repository instead of this one: with `refresh.pull: true` that moved the *session's* repository off its branch while `repo_path` stayed where it was. Every git command in this file is written `git -C "<repo_path>" …`; `gh pr view` takes `--repo`, and `gh pr checkout`, which takes no `-C`, is never run.

## Refresh step

Before resolving any PR:

1. **Verify repo exists.** If `repo_path` is not a directory, return `status: REPO_MISSING`.
2. **Read-only detection.** Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/read-only-repos.md` §1, test whether `repo_path` and `repo_path/.git` are writable. On a read-only mount, skip items 3–5 entirely and follow that reference — §2 for what to skip, §3 for ref resolution, §4 for reading at the ref, §5 for when to escalate. `refresh.fetch` writes refs and `refresh.pull` writes the working tree, so neither can run; PR resolution proceeds against the object database as it stands. A read-only mount is NOT `DIRTY_TREE` and NOT `REFRESH_BLOCKED`.
3. **Clean-tree check.** `git -C "<repo_path>" status --porcelain`; if non-empty AND `refresh.fetch` is true, return `status: DIRTY_TREE`.
4. **Fetch.** If `refresh.fetch` is true: `git -C "<repo_path>" fetch origin`. On failure, if the error contains `Read-only file system`, abandon the writable path and continue in read-only mode per `read-only-repos.md` §1; on any other failure return `status: REFRESH_BLOCKED` with a one-line reason.
5. **Pull.** If `refresh.pull` is true (default false): resolve `<default>`, the default branch's **name** — the form `git switch` takes — by `read-only-repos.md` §3's chain and its **A switch takes the name** rule: rung 1 prints `origin/<name>` and `<default>` is what follows `origin/`; where rung 1 fails — `origin/HEAD` unset, or naming a ref that no longer exists (§3 rung 1) — it is the literal `main` or `master` whose ref rungs 2–3 find. Never the `origin/<name>` ref itself, which `git switch` refuses. One step is this agent's own, beside that chain: where rung 1 fails, run `git -C "<repo_path>" remote set-head origin --auto` and retry rung 1 before rungs 2–3. An exhausted chain returns `status: REFRESH_BLOCKED` with reason `cannot resolve default branch`. Then `git -C "<repo_path>" switch <default>` + `git -C "<repo_path>" pull --ff-only`. On a failure whose error contains `Read-only file system`, enter read-only mode per `read-only-repos.md` §1 and continue there; on any other failure return `status: REFRESH_BLOCKED`.

## Per-PR summary content

For each resolved PR, the `summary` prose (3–8 sentences) focuses on what a documentation writer needs:

- **New behavior** — what the user can do after this change that they couldn't before.
- **Changed behavior** — what existing behavior has been altered and how.
- **API surface** — new commands, routes, config keys, CLI flags, public functions, environment variables, UI controls.
- **Migration notes** — anything in the diff that implies a user-facing migration (schema change, renamed flag, deprecated behavior).

Skip implementation detail a doc writer doesn't need (internal refactors, pure test-only changes, dependency bumps with no observable effect).

If `resolved_via == jira_key_commits`, the summary MUST include the verbatim caveat quoted under Strategy 4.

## Output

```yaml
status:   OK | REPO_MISSING | DIRTY_TREE | REFRESH_BLOCKED | NO_PRS_RESOLVED | PARTIAL
repo:      <short repo name — the basename of repo_path>
repo_path: <absolute path as received in input, so callers can reference the source tree>
prep:
  fetched:          true | false
  pulled:           true | false
  refresh_note:     <e.g. "fetched 3 new refs" | "read-only mount; resolved at origin/main" | "tree was dirty, refresh skipped">
  read_only:        true | false
  scanned_ref:      <ref name, e.g. "origin/main"; the default branch name when writable>
  ref_committed_at: <ISO-8601 timestamp of the ref's newest commit>
  head_divergence:  { branch: <working-tree branch>, ahead: <n>, behind: <n> }
per_pr:
  - pr_id: <id>
    url: <url>
    resolved_via: pr_ref | branch_search | merge_commit | jira_key_commits | gh_cli | unresolved
    base: <sha | null>
    head: <sha | null>
    files_changed: <count>
    insertions: <count>
    deletions: <count>
    diff_truncated: false
    summary: |
      <prose; 3–8 sentences: new behavior, changed behavior, API surface, migration notes.
      If resolved_via == jira_key_commits, the summary MUST note that the diff was
      reconstructed from commits matching a Jira key and may not exactly correspond to
      the original PR content.>
unresolved_prs:
  - pr_id: <id>
    url: <url>
    reason: <why resolution failed>
    candidates: [<sha — first line, if Strategy 4 found any>]
aggregate_summary: |
  <1–2 paragraphs: what this repo contributed to the feature. If any non-MERGED PRs
  were in scope and ended up unresolved, state the count explicitly so the doc writer
  knows.>
```

`PARTIAL` is returned when some PRs resolved and others did not, or when Strategy 4 was the only path that worked for at least one PR (content correctness is reduced).

## Hard rules

- NEVER make HTTPS / REST calls to Bitbucket (Cloud or Server). All Bitbucket resolution is pure local git.
- NEVER make HTTPS / REST calls to GitHub outside the `gh` CLI. No direct API calls, no raw `curl` to `api.github.com`.
- NEVER mutate the repo (no commits, no branch creation, no `git reset`, no `git clean`). (still true — this binds the code repo being summarized; the caller's terminal `commit-artifacts` step touches only `$SPECS_PATH` and never dispatches this agent's git.)
- NEVER switch the repo's HEAD when `refresh.pull` is false — leave the working tree as found.
- NEVER hardcode a Bitbucket Server hostname. Host classification uses the substring rule documented above.
- NEVER fabricate diff content. If a PR cannot be resolved by any strategy, record it in `unresolved_prs`.
- NEVER report an empty range as resolved. A range that changes no file has not resolved its PR, on any path; fall through to the next strategy, and to `unresolved_prs` after the last.
- If `resolved_via == jira_key_commits`, the `summary` MUST carry the explicit caveat — omitting it would silently degrade content trust.
- On `REPO_MISSING`, `DIRTY_TREE`, `REFRESH_BLOCKED`: return immediately with the status; do NOT partially resolve any PRs.
- On a read-only mount, NEVER `git fetch`, `git pull`, `git switch`, or `git remote set-head` — all write. Follow `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/read-only-repos.md` instead of returning `REFRESH_BLOCKED`.
