# Phase handoff — Shared Reference

Single source of truth for the two entry points that move a **phase deliverable** into `$SPECS_PATH`'s default branch and that refuse to start a phase whose input never got there: `handoff-to-main` (§2, producer) and `require-on-main` (§3, consumer).

**The principle.** A workflow phase is not finished until its artifact is on the default branch. A command that ends a phase commits, pushes, and opens a pull request. The command that starts the next phase does not run until the previous artifact is there. The gate applies even when the role does not change — it may be a different human of the same role, and even the same human should have to confirm the previous phase is done.

**Relationship to `specs-repo-git.md`.** That reference owns the *bookkeeping* paths (its §2.1) and the run-start/terminal steps for them. This one owns *deliverables*. It inherits four of that file's hard rules and deliberately differs on three; §1 states which.

**Relationship to `code-repo-handoff.md`.** That reference is this one's counterpart in the **code** repo: same shape (gate, stage, commit, push, `gh` probe, outcome line), different repository, and one deliberate inversion — its commit is prompt-free, because a deliverable is already safe on disk when this file's §4.3 choice is asked and a code change is not. Neither file's entry points ever run against the other's repository.

## 1. Hard rules

Inherited from `specs-repo-git.md`, unchanged:

1. **`git -C` always; `cd` never.** Every invocation is `git -C "$SPECS_PATH" …`. Most callers are running inside a *different* repository; a `cd` would corrupt their git state. The `gh` calls in §2.6 and §3.5 name the repository with `-R` for the same reason.
2. **Bounded paths.** Only the calling command's own declared deliverable paths are staged, by enumeration (§2.3). `git add -A` is never issued at repository scope.
3. **Bounded branches.** Only branches matching `^(idea|vi|ard|spec|design|ready)/` are the plugin's (`specs-repo-git.md` §2.2).
4. **Never destructive.** No `push --force`, no `push -f`, no `branch -D`, no `merge`, no `rebase`, no `reset`, no `stash`, no `checkout --`, and never delete an `index.lock`.

Where this reference **differs** — each difference is deliberate, and a reader who "corrects" one to match `specs-repo-git.md` breaks this contract:

5. **`require-on-main` is fatal by design.** `specs-repo-git.md` §1 rule 5 is "never fatal", which is right for bookkeeping. A gate that reports and continues is not a gate. `handoff-to-main` is *not* fatal — the deliverable is already written — but it must report the phase as **not handed off**.
6. **The `Co-authored-by` trailer IS carried.** `specs-repo-git.md` §1 rule 6 forbids it because bookkeeping files are plugin-generated. A deliverable is authored content, and the existing handoff phases already carry the trailer.
7. **`handoff-to-main` runs only behind a user choice.** `specs-repo-git.md` §1 rule 7 is "prompt-free". Opening a pull request is outward-facing, so it is never reached except through the calling command's consent choice (§4.3).

## 2. `handoff-to-main` — the producer entry point

Called from a producing command's Handoff phase, and **only** when the user picked the branch-and-PR choice of §4.3. **One step of it runs earlier, and it is read-only:** §2.1's push-target probe, which §4.3 runs before it presents the choice, because the probe's result decides what that section prints above the array.

### 2.1 Gate

All of: `$SPECS_PATH` is set and is an existing directory; `git -C "$SPECS_PATH" rev-parse --git-dir` succeeds; the resolved `.git` directory is **writable**; and the run does not carry `specs_git: blocked` (`specs-repo-git.md` §3.3 G0 — a commit on a detached HEAD is reachable from no ref).

Gate fails on path / repo / permission grounds → report that the deliverable is written but not handed off, and stop. Gate fails on `specs_git: blocked` → re-emit that notice. **Never silent** — unlike the bookkeeping steps, silence here would hide the fact that the phase did not complete.

**The push-target probe — run before the choice, and never gated on.** `git -C "$SPECS_PATH" remote get-url origin`: exit 0 with a non-empty URL sets `remote: origin`, anything else sets `remote: none`. **It runs before §4.3 presents its array, not here**: it only reads, and its result is what decides whether §4.3 prints its no-remote notice, which a probe run after the choice could never have fed. This entry point then carries the `remote` value that probe set rather than probing a second time. A specs repo with no `origin` is an ordinary state (a tree kept locally, a clone whose remote was removed), and it is deliberately **not** a gate failure: branching and committing there still does the useful half of this entry point, and a deliverable is safer on a local commit than in a working tree. What `remote: none` removes is §2.5's push and §2.6's pull request — both are skipped — so the run says so **before** the choice is presented (§4.3's notice) and reports it afterwards through §4.1's *No remote* row.

**The probe is `origin` specifically, because every later step names `origin` literally** — §2.2's `refs/remotes/origin/<name>`, §2.5's `push -u origin`, §2.6's `OWNER_REPO` derivation. A repository whose only remote is under some other name is therefore `remote: none` for this entry point. **Probing is not optional and no earlier step stands in for it:** the four gate conditions above are all satisfiable on a repository with no remote at all, so without this probe the producer offers — marked `(Recommended)` — a *"push + open PR"* option that cannot succeed, and the operator learns it only from the raw `git push` error §2.5 reports.

### 2.2 Branch resolution, and the collision rule

Intended name: `<prefix>/<KEY>-<slug>`, where `<prefix>` is the caller's own (§2.9) and `<KEY>-<slug>` come from **the resolved feature folder the deliverable was written into** — never re-derived from the Jira title. Folder resolution already tolerates a human-adjusted slug and a stray `-`/`_` after the key, and re-deriving would produce a branch name that disagrees with the directory it commits.

Collision is normal, not exceptional: `_readiness.md` is overwritten on every `ready:` run, and a `create-vi:` re-run after its pull request merged wants the same name again. `gh pr create` fails on an already-merged branch, and force-pushing and `branch -D` are both forbidden (§1 rule 4). So:

1. Test both `git -C "$SPECS_PATH" rev-parse --verify --quiet refs/heads/<name>` and `… refs/remotes/origin/<name>`.
2. Neither exists → use `<name>`.
3. **At least one exists** (the local ref, the remote ref, or — the common reuse case — both) **and** it is this run's own in-progress branch — its prefix is the caller's, its key is in the run key set (`specs-repo-git.md` §3.2), and the branch is **not already merged** → **reuse it**, switching to it rather than creating it.

   **Test the merge against a ref that still exists, and read a missing ref as merged.** Resolve the branch ref first — `refs/remotes/origin/<name>` when it exists, else `refs/heads/<name>` — and run `git -C "$SPECS_PATH" merge-base --is-ancestor <that ref> <default-ref> 2>/dev/null` (`specs-repo-git.md` §3.2 — `origin/<default>` where the repo has a remote, the local default branch where it has none): exit 0 = merged (do not reuse; fall to rule 4 and create a fresh name), non-zero = not yet merged (reuse). The `2>/dev/null` is required for the same reason §3.2 gives for its own probe — on a missing ref git writes `fatal: Not a valid object name`, which must not leak into the run's output.

   **Why the remote ref alone is not enough.** With GitHub's *delete branch on merge* — the ordinary configuration — a merged branch's **remote** ref is gone while the **local** one survives. Probing only `refs/remotes/origin/<name>` then exits 128, which reads as "not yet merged", so the run switches onto a merged branch and calls `gh pr create` — the failure this section's own premise names ("`gh pr create` fails on an already-merged branch"). Verified empirically: after a merge followed by `git push origin --delete <branch>` and `git fetch --prune`, `merge-base --is-ancestor refs/remotes/origin/<name> …` exits 128 (`fatal: Not a valid object name`) while the same test against the surviving `refs/heads/<name>` exits 0 (merged).
4. Otherwise → append the lowest free integer suffix, starting at `-2`, retesting both refs each time. Report the substitution in the §4.1 outcome line, because a branch name the user did not expect is a branch name they will not find.

### 2.3 Staging the deliverable

Staging is by enumeration, never by glob — the same discipline as `specs-repo-git.md` §2.1, applied to a different path set:

1. `git -C "$SPECS_PATH" status --porcelain -z --untracked-files=all`. `--untracked-files=all` is **required**: the default collapses an untracked directory to a single `?? dir/` line, hiding which files are staged.
2. Classify each reported path against the caller's declared deliverable paths (§2.9). Everything else is **OTHER** and is never staged — including the `dev-workflows/**` bookkeeping paths, which belong to `commit-artifacts`.
3. `git -C "$SPECS_PATH" add -A -- <path> [<path>…]` with the literal paths. `-A` is used deliberately: a producer may delete a file it relocated (`idea:` moves `idea.md` out of the vault; `update-vi:` supersedes a revision), and that deletion must be staged. `-A` states the intent explicitly and was strictly required before git 2.0; on git ≥ 2.0 a plain `git add -- <path>` stages a deletion for a literal path too — verified empirically — so keep `-A`, but do not justify it by claiming plain `git add` cannot stage the deletion.
4. **Account for every declared path.** Each path §2.9 declared is now either staged by step 3, or reported by no record at all. A path with no record is **accounted for only where it is already on the branch unchanged**: `git -C "$SPECS_PATH" cat-file -t "HEAD:<path>" 2>/dev/null` prints `blob`. No record means the worktree, the index and `HEAD` agree, so a path `HEAD` carries as a blob is committed and byte-identical to what this phase wrote. Anything else — a non-zero exit, or an output of `tree` — is named in §4.1's *declaration unaccounted for* clause: a path nothing wrote, one git ignores, and the shapes nothing could place — a declaration given as an absolute path, as a directory, or as a glob. A **record** step 2 could not read as a path takes §4.1's *record unreadable* clause instead, which quotes the record. **Do not test existence under `$SPECS_PATH` in its place:** a re-run that rewrites a file byte-for-byte leaves it existing, staging nothing and already on the branch, so an existence test names it as NOT on a branch it is on. This does not stop the entry point: the paths that did stage are still committed, pushed and opened as a pull request, and the clause is what tells the operator which declared artifact is not among them.

**`-z` is required, and `specs-repo-git.md` §2.1 is where the hazard it answers is stated:** `git status --porcelain` wraps a path carrying a space, a `"`, a `\` or a non-ASCII byte in double quotes and octal-escapes the non-ASCII bytes, and a classifier reading the path as reported never matches it. A deliverable is `<KEY>_<slug>.md` in `<KEY>-<slug>/`, and the slug is a kebab of a title, so a non-English title puts exactly such a byte in a declared path. Under `-z` each record is terminated by a NUL and the path is emitted raw; a **rename or copy** record carries a second NUL-terminated field, the original path, straight after it — consume it with the record it belongs to. `-c core.quotepath=false` is **not** the fix: it suppresses only the octal escaping, and a path carrying a space is still quoted.

**What this closes.** Until `-z` was read here, a declared deliverable whose name carried such a byte was reported quoted, matched no declared path, fell to **OTHER**, and was never staged — while the run reported the handoff as done. Step 4 closes the other half: the drop had no voice, so nothing said that a declared artifact was not in the commit.

Nothing staged → no commit. Emit the §4.1 `nothing to commit` line. This is not an error: a re-run that changed nothing is a legitimate outcome.

### 2.4 Commit

Message `<KEY> <summary>`, matching the specs repo's own `<KEY|NOISSUE> <summary>` convention. Carry `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` (§1 rule 6).

### 2.5 Push

`git -C "$SPECS_PATH" push -u origin <branch>`. Never force. A non-fast-forward rejection is reported, never resolved by rebasing or forcing mid-run.

**Skipped entirely where §2.1 set `remote: none`**, and §2.6 is skipped with it — a pull request needs a pushed head. The commit §2.4 made still stands; §4.1's *No remote* row reports it, and the phase is described as **not handed off** exactly as §2.8 requires of every other way the push can fail to land.

### 2.6 Open the pull request

Not reached where §2.1 set `remote: none` — §2.5 pushed nothing, and `gh` has no head branch to open a pull request from.

**First, probe for an existing pull request** — §2.2 rule 3 deliberately *reuses* an in-progress branch, and collision is normal rather than exceptional, so a branch that already carries a pull request is the ordinary case here:

    gh pr list -R "$OWNER_REPO" --head <branch> --state open --json number,url

One already open ⇒ §2.5's push has already updated it. Report it through §4.1's *already existed* row and do **not** call `gh pr create`, which fails on the duplicate and would send the run down §4.2 telling the user to open a pull request that exists. This is the same primitive §3.5 uses on the consumer side.

Otherwise: derive the repository, run a cheap `gh auth status` pre-check purely to avoid a confusing raw error, then call `gh` with every argument that would otherwise make it prompt — the plugin must never block on an interactive editor:

    url=$(git -C "$SPECS_PATH" remote get-url origin)
    host=$(printf '%s' "$url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^/@]+@##; s#[:/].*$##')
    slug=$(printf '%s' "$url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^/@]+@##; s#^[^/:]+(:[0-9]+)?[/:]##; s#/+$##; s#\.git$##')
    case "$host" in github.com) OWNER_REPO="$slug" ;; *) OWNER_REPO="$host/$slug" ;; esac

    gh pr create -R "$OWNER_REPO" --base <default> --head <branch> \
                 --title "<title>" --body-file <body-path>

**The host is kept, not stripped** — the same rule as `code-repo-handoff.md` §2.6, and for the same reason. `gh -R` accepts `[HOST/]OWNER/REPO`, and `gh auth status` succeeds whenever the user is authenticated to *any* host, so a bare `OWNER/REPO` derived from a GitHub Enterprise remote resolves against **github.com** — silently opening the phase's pull request on an unrelated public repository if one happens to sit at that path, with the capability probe catching nothing because the call succeeded. Only `github.com` may drop the host. Validate the slug against `^[^/]+/[^/]+$` before calling `gh`; anything else (a Bitbucket `scm/proj/repo`, a nested GitLab group) is not a `gh` target — skip to §4.2. §3.5's `gh pr list -R "$OWNER_REPO"` uses the same value and mistargets identically without this.

The expressions strip a scheme, a `user@`, and a host with an optional `:port` terminated by `/` or `:` (the scp-like `git@host:Org/repo` form uses a colon), then a trailing slash and `.git`. The earlier two-expression form handled only `git@host:` and `https://host/`, and passed an `ssh://git@host/Org/repo.git` remote through unchanged — `gh` then failed on a repository argument that was a whole URL. Do not simplify it back.

**Capability probe, not host classification.** Try the call; on any failure fall back to §4.2's instruction. Push authority and pull-request authority are independent — push runs over SSH with a per-repo key, `gh` runs over the API with a token, and the same account can have write access to one repository and read access to another. No hostname or host-type test can detect that mismatch, so a run can push successfully and still be unable to open the pull request. This is why `finish-and-handoff.md` §4's host classification is right for choosing *instructions* and insufficient here.

`gh` wraps the API rather than calling it over HTTPS, which is what the zero-direct-API rule permits — the same allowance `document:` already relies on.

### 2.7 Title and body

Title: the commit subject of §2.4.

Body: written to a file (never passed inline, which would break on newlines and quoting) containing what the phase produced; the artifact paths; the reviewer verdict where the caller has one; the count of open questions or `[NEEDS CLARIFICATION]` markers; and, **where the caller has one**, the next command in the chain together with §4.1's `<downstream-clause>` for this artifact — never the bare "it will not run until this pull request is merged", which is false for an artifact whose consumer falls back and for one nothing gates (§4.0).

### 2.8 Failure discipline

Every failure is reported and the phase is described as **not handed off**. The run is not retroactively failed — the deliverable is written and intact — but no report may imply the handoff succeeded. The next phase's gate is what enforces the consequence.

### 2.9 Caller-supplied inputs

| Input | Meaning |
|---|---|
| `prefix` | one of `idea`, `vi`, `ard`, `spec`, `design`, `ready` |
| `feature_folder` | the resolved directory the deliverable was written into |
| `deliverable_paths` | the literal repo-relative paths this phase authored |
| `title` | the commit subject and pull-request title |
| `body_facts` | what §2.7 renders |

## 3. `require-on-main` — the consumer entry point

Runs in the caller's Phase 0, immediately after `specs-preflight`, so it reuses that step's best-effort `fetch` (`specs-repo-git.md` §3.2) — no second network call.

### 3.1 Gate

`$SPECS_PATH` set, an existing directory, and `git -C "$SPECS_PATH" rev-parse --git-dir` succeeding. Unlike §2.1 the `.git` directory need **not** be writable — the gate only reads. A failed gate is a **silent skip** (state H): the artifacts are going to a tier the plugin does not manage, and there is nothing to verify.

### 3.2 Inputs and primitives

Inputs: the repo-relative `path` of the artifact, the `default` branch (`specs-repo-git.md` §3.2), the caller's own branch prefixes, and the run key set.

**`<default-ref>` is resolved by `specs-repo-git.md` §3.2**, which owns default-branch resolution and also owns which ref represents it: `origin/<default>` where a remote is configured, the local `refs/heads/<default>` where none is. It is defined there rather than here because `specs-repo-git.md` is the reference this one extends, and two definitions of one ref is how they drift apart. Row G below fires on the **resolved** ref, so a configured-but-unreadable remote still stops, which is its correct case.

The four primitives, each verified against a real specs repo:

- **The default-branch ref exists:** `git -C "$SPECS_PATH" rev-parse --verify --quiet "<default-ref>"` Exit 0 = the ref exists — run the next primitive. Non-zero = row G: nothing to verify against, stop. This runs **before** the next primitive, because that primitive's own required `2>/dev/null` discards the only signal that would otherwise distinguish "path absent on an existing ref" (row F) from "the ref itself does not exist" (row G) — `git cat-file -e` exits 128 for both, verified empirically: a missing path and a missing ref are indistinguishable by exit code alone.
- **On the default branch:** `git -C "$SPECS_PATH" cat-file -e "<default-ref>:<path>" 2>/dev/null` Exit 0 = present. The `2>/dev/null` is required — on absence git writes `fatal: path '<path>' does not exist in '<default-ref>'` to stderr, which must not leak into the run's output. Only reached once the ref-existence primitive above has already confirmed `<default-ref>` exists, so a non-zero exit here means the path is absent, never that the ref is.
- **Worktree matches the ref:** `git -C "$SPECS_PATH" diff --quiet "<default-ref>" -- "<path>"` Exit 0 = identical. This also catches a **staged-only** change, which a `hash-object` comparison against the working file would miss.
- **Plugin branches carrying the artifact:** `git -C "$SPECS_PATH" for-each-ref --format='%(refname:short)' refs/remotes/origin refs/heads` filtered to `(origin/)?(idea|vi|ard|spec|design|ready)/*`, then `git -C "$SPECS_PATH" cat-file -e "<ref>:<path>" 2>/dev/null` on each. **Local `refs/heads` are scanned as well as remote ones**, and for the same reason §2.2's branch resolution tests both: a deliverable that was committed but whose push failed (§2.5, reported by §4.1 as "NOT handed off") exists only on a local branch. Scanning remote refs alone would return `absent` for it — the one state §2.8 promises "the next phase's gate is what enforces the consequence" of. Prefer the remote ref when both carry the path, so rows D and E report the branch the pull request is open against. **Then strip a leading `origin/` and carry the bare branch name forward** — `%(refname:short)` of a remote ref is `origin/spec/PRODUCT-1234-y`, while the branch that exists on the host is `spec/PRODUCT-1234-y`. This is not cosmetic: §3.5 feeds this value to `gh pr list --head`, which filters by the head branch name **on the host** and matches nothing against an `origin/`-prefixed string, so leaving the prefix on made **row D unreachable in every repository state** — a pushed branch with an open pull request reported row E's "was never handed off", silently, with `gh` exiting 0. The bare name is also the only form the operator can act on. **This primitive is unaffected by which case `<default-ref>` resolved to** — it scans plugin-prefixed branches, a pattern the default branch itself never matches, whether or not the repo has a remote.

### 3.3 The state table

First matching row applies.

| # | On `<default-ref>` | Worktree | HEAD | Outcome |
|---|---|---|---|---|
| H | — | — | gate of §3.1 fails | **silent skip** — return `unmanaged`; the caller proceeds exactly as it did before this feature |
| I | — | — | run carries `specs_git: blocked` (detached HEAD), **or** HEAD is detached and no preflight set that flag | **stop**, re-emitting that notice where there is one. A phase cannot complete from a detached HEAD, so verifying one is meaningless |
| G | `<default-ref>` does not exist | — | any | **stop** — the plugin cannot verify what is on `<default>` |
| A | present | matches ref | any | **pass** |
| B | present | differs | a branch **this run itself created or reused during this run**: created earlier in the same invocation via this caller's own `handoff-to-main`, or reused because `specs-repo-git.md` §3.5 B3 kept the preflight checkout on it AND the branch is the caller's **own** — its prefix is this caller's and its key is in the run key set (`specs-repo-git.md` §3.2). The test is **branch ownership, not artifact authorship**: the load-bearing case is `design:` resumed on its own `design/<EPIC>-<eslug>` branch gating the `specification.md` that same branch amends, and `design:` is not that file's original author (`specify:` is). Requiring authorship would exclude the one case this row exists for and drop it into row C, whose repair offer re-grounds the session on the un-amended copy. Ownership is still never merely a prefix the caller is *capable of* producing for an unrelated purpose, such as `implement:`'s Phase 4.5 escalation handoff onto `spec`/`design` | **pass, reported** — `reading <path> from your in-progress <branch>, which amends the approved version on <default>` |
| C′ | present | differs | any other HEAD, **and** the tree is dirty in a way that would block the switch **or** the `pull --ff-only` that follows it | **stop**, naming the exact files |
| C″ | present | differs | HEAD **is** the default branch (so nothing to switch to), and the divergence is local — an uncommitted edit **or** a committed-but-unpushed one | **stop**, naming the files and saying the repair offer cannot help here |
| C | present | differs | any other HEAD | **repair offer**, then re-test once |
| D | not on ref | — | artifact found on a plugin ref, pull request open | **stop** — `<path> is on branch <branch> with PR #<n> open, not merged` |
| E | not on ref | — | found on a plugin ref, no open pull request | **stop** — `<path> is on branch <branch> and was never handed off` |
| F | not on ref | — | found on no ref | **delegate** — return `absent`; see §3.4 |

**`not on ref` describes the repository, not the return value.** Rows D, E, and F all read `not on ref` in the first column because none of the three has the artifact on `<default-ref>` — that column is a statement about the repository. It is row F alone that returns `absent` (§3.7), and D/E are stopping rows that never reach a caller's `absent` branch at all. A consumer that keys off this column instead of the returned `stopped` flag cannot tell D/E from F.

**Row order matters.** H, I, and G precede everything else because they are about the repository, not the artifact — and G, like H and I, must precede every row that keys on `not on ref` (D, E, F) and every row that tests the worktree against the ref at all (A, B, C′, C″, C): §3.2's ref-existence primitive runs before the on-ref-presence primitive, so a reader who has not first ruled out G cannot tell "path absent on an existing ref" (row F) from "the ref itself does not exist" (row G) — a defect closed in §3.2 but, until now, never propagated to this table's own row order. **Both primitives run against the same resolved `<default-ref>`** (§3.2) — a remote-tracking ref when the specs repo has a remote, the local default branch when it does not — so ruling out G rules out the same absence for either case. C′ and C″ precede C because offering a switch that git would refuse is worse than naming the blocker.

**Row B is load-bearing and must not be folded into C.** `design:` amends `specification.md` on its own branch, so on a resume the worktree copy legitimately differs from the default branch. Under row C the plugin would offer `switch to <default> + pull --ff-only` and **discard the in-progress design**. The distinguishing test is **branch ownership**, never whether the file differs.

**Row C's repair offer:**

    choices: ["Switch to <default> and pull --ff-only, then continue (Recommended)", "Cancel"]

**Row C″ exists because the offer above is a no-op on the branch you are already standing on.** Row B is scoped to a branch this run owns and row C′ requires a dirty state that would *block* a switch — so a user sitting on the default branch with a local edit to the gated artifact matched neither and fell to row C, which offered `git switch <default>` from `<default>` ("Already on 'main'") followed by a `git pull` that aborts on the unstaged change, then re-tested, failed, and stopped. The offer could never resolve it. Row C″ catches that state first and says so plainly instead of spending a prompt on it: the remedy is to commit, stash, or discard the local edit, and the stop names the files.

On the first choice: `git -C "$SPECS_PATH" switch <default>` then `git -C "$SPECS_PATH" pull --ff-only`, then re-test **once**. A second failure stops — never merge, rebase, or reset, and never loop.

**Three states the C-row family used to misclassify, each fixed above and recorded so the narrowing is not undone.**

- **A committed local divergence on the default branch (C″).** A commit whose push failed — the state `specs-repo-git.md` §3.4's retry exists for — is a divergence that is *committed*, not uncommitted. Row C's offer is `switch` + `pull --ff-only`, and on the default branch the switch reports *"Already on 'main'"* and the pull *"Already up to date."*, both exit 0: a repair that changes nothing, reports success, and then stops anyway. C″ covers it.
- **Dirt that blocks the pull rather than the switch (C′).** Row C's offer is a switch **and** a pull, and a dirty file that is identical on both branches blocks only the second: `git switch` succeeds and moves the user off their branch, then `pull --ff-only` aborts with *"Your local changes … would be overwritten"*. The user is left relocated by a repair that failed. C′ therefore tests both commands, not the first.
- **A detached HEAD on a read-only mount (I).** Row I keyed on the `specs_git: blocked` flag, whose only producer is `specs-preflight` — which requires a **writable** `.git`, where this gate deliberately does not (§3.1). On a read-only mount the preflight is a silent no-op, so the flag is never set, and a detached HEAD fell through to row C, whose offer is a write: `git switch` exits 128 with a raw `fatal: Unable to create '.git/index.lock': Permission denied`. Row I tests the state as well as the flag.

### 3.4 Row F delegates — the gate never makes an optional input mandatory

Row F is the difference between "this phase was not handed off" and "this phase never happened". Only the second is row F, and the gate has no opinion about it. Every gated input except `design:`'s `specification.md` is **optional today**, and that must not change. The gate returns `absent`; the caller does what it already does.

| Caller | Input | Pre-existing absent behaviour, preserved |
|---|---|---|
| `create-vi: <KEY>` | `idea.md` | continue down the Phase 0 idea ladder — prompt for a path, or grill the VI from scratch. **`idea:` is not a prerequisite.** |
| `create-ard:` | the VI | fall back to `jira-reader` against the Jira export — now **reported** rather than silent |
| `specify:` | the VI | `jira-reader` is already the primary read path (the merged VI is a grounding confirmation, not a new content source); on `absent` the confirmation is simply skipped — now **reported** rather than silent, the same shape as `create-ard:`'s row |
| `specify:` `design:` `implement:` `epics:` `ready:` | the ARD | `status: none` and the no-regression rule of `ard-resolution.md` |
| `epics:` | VI-level `specification.md` | `vi_spec_present: false`, the existing silent skip |
| `implement:` | `specification.md` / `design.md` | only an **in-scope** spec is gated; a direct-prompt run resolves none |
| `design:` | `specification.md` | **stops** — but that stop already exists; this reference only makes its test correct |
| `ready:` | ARD / spec / design | records the artifact as missing in its coverage roll-up, as today |

Rows D and E add the only new stop: an artifact that **exists** and was never handed off. That state was **not** unreachable before this feature — pre-J, `specify:` already created `spec/<EPIC>-<eslug>` (or `spec/<VI>-<vslug>`) branches and offered branch + PR, and `create-vi:` did the same on `vi/<KEY>-<slug>`, with no downstream gate reading them; an artifact sitting on such a branch, unmerged, was a common, ordinary state. This is a real behaviour change: for that state, `create-ard:`, `specify:`, and `epics:` now hard-stop where they previously proceeded with a documented fallback (the deliberate, well-argued stop at `epics/SKILL.md`'s own gate). It qualifies caller-contract rule 3 (§5 — no consumer turns an optional input into a prerequisite) precisely: row F's `absent` case is still fully delegated to the caller's own pre-existing behaviour, but rows D/E are a new stop for a state that was previously reachable and previously non-blocking.

### 3.5 Locating the branch and its pull request

For rows D and E, after §3.2's ref scan finds a carrying branch:

    gh pr list -R "$OWNER_REPO" --head <branch> --state open --json number,url

**Derive `$OWNER_REPO` first (§2.6), and skip this probe when the derivation does not validate.** §2.6's slug test (`^[^/]+/[^/]+$`) is what says whether this remote is a `gh` target at all; running the probe before it means calling `gh` with an unvalidated `-R`. `<branch>` is the bare name §3.2 carried forward, never `origin/`-prefixed. On `gh` failure, use **row E's** wording plus a note that the pull-request state could not be checked — never assert a pull request exists, and never assert one does not.

### 3.6 Degraded verification

- **Fetch failed** (offline, auth) → test against the last-known `origin/<default>` and say so, the precedent `specs-repo-git.md` §3.2 already sets: `offline — checked against the last-fetched ref`. This case presupposes a remote: with no remote configured there is nothing to fetch, so §3.2's resolution never enters it and `<default-ref>` is simply the local default branch.
- **Read-only specs mount** → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/read-only-repos.md` applies: no `fetch`, use the existing ref, emit the degraded clause. **The read-only rows degrade in freshness only; the repair row does not run at all.** Every classifying primitive in §3.2 is a read, so **ten of the eleven rows** — H, I, G, A, B, C′, C″, D, E, F — reach their verdict unchanged against a stale ref. Row C's offer, though, is a `switch` and a `pull` — writes that `read-only-repos.md` forbids and that git refuses with a raw `fatal:` — so on a read-only mount row C **stops with its finding instead of offering the repair**, naming the mount as the reason.
- **No `<default-ref>` at all** → row G, whichever case §3.2 resolved to — a missing `origin/<default>` where the specs repo has a remote, a missing local `<default>` branch where it does not. Nothing to verify against either way, and proceeding silently is the failure this reference exists to prevent.

### 3.7 Return value

    on_main: pass | pass_amending | absent | unmanaged
    stopped: true | false
    branch: <the carrying plugin branch, or null>
    pr: <number, or null>
    degraded: <the clause to print, or null>

`pass_amending` is row B. `absent` is row F and is the caller's to interpret per §3.4. `unmanaged` is row H. Every stopping row returns `stopped: true`, and every caller but one then stops.

**`ready:` is the sole exception, by design.** It is a read-only verifier whose entire function is to report, so a run that stops instead of reporting has failed at the one thing it exists to do. It records each stopping row as a readiness finding — capping the verdict at `PARTIAL` — and continues. `ard-resolution.md` carves `ready:` out of its own `status: unmerged` stop in exactly the same way and for exactly the same reason. No other caller may take this exception, and a caller that wants one adds it here first.

**`on_main` is defined only when `stopped: false`.** Its four values — `pass` (row A), `pass_amending` (row B), `absent` (row F), `unmanaged` (row H) — map to the four **non**-stopping rows, and the other **seven** (I, C′, C″, C, D, E, G) define none: every stopping row carries no defined `on_main` value; a caller has nothing to read there and must act on `stopped`/`branch`/`pr`/`degraded` instead.

**A caller tests `stopped` before `on_main`.** `on_main: absent` is returned only by row F; every stopping row (I, C′, C″, C, D, E, G — seven of the eleven) returns `stopped: true` regardless of what `on_main` reads. A caller that branches on `on_main == "absent"` before checking `stopped` cannot distinguish row F (never happened — §3.4 applies) from rows D/E (happened, but not handed off — the run must stop).

## 4. Reporting

### 4.0 The downstream classes

`<downstream-clause>` (§4.1), `<next-phase-clause>` (§4.1) and the consent array (§4.3) all answer one question about the artifact the producer has just written — **what does not landing it cost?** — and all three must answer it the same way. Until this section existed they answered it one way for every artifact — *"the next phase will stop until this is on main"* — which is true of exactly one of the six deliverables below.

| Class | The test | What declining costs |
|---|---|---|
| **gated — stopping** | a consumer runs `require-on-main` on it, and **some** §3.4 row naming it says *stops* | that consumer stops |
| **gated — falling back** | a consumer runs `require-on-main` on it, and **every** §3.4 row naming it preserves a pre-existing absent behaviour | nothing stops; the consumer does what it does when the deliverable is missing, which might not read the un-landed copy |
| **advisory** | no §3.4 row, **but** a command reads the artifact and never gates on it | nothing stops **because of the decline**; the reader reads the working copy, so it still sees this run's result — the artifact is unshared, not blocking |
| **unread** | no §3.4 row and no reader after the run that wrote it | nothing |

The classes as the tree stands, each derived from the consumer rather than asserted here — the gated rows are a two-way match with §3.4's Input column, and the advisory row was derived by opening the reader it names:

| Artifact | Class | Derivation |
|---|---|---|
| `specification.md` | gated — stopping | §3.4's `design:` row stops |
| `idea.md` | gated — falling back | its one row is `create-vi:`'s idea ladder |
| the VI | gated — falling back | `create-ard:` falls back to `jira-reader`; `specify:` skips a confirmation |
| the ARD | gated — falling back | every consumer resolves `status: none` and applies `ard-resolution.md`'s no-regression rule |
| `design.md` | gated — falling back | gated in-scope-only by `implement:`, recorded as a coverage gap by `ready:` |
| `_readiness.md` | advisory | `implement:` Phase 0.5 reads a co-located copy and surfaces a one-line advisory on a `NOT-SUPPORTED`/`PARTIAL` verdict, explicitly never blocking. §3.4 names no gate on it |
| `specify:`'s `_session.md` and `_glossary.md`, `design:`'s `_design-session.md` and `_design-glossary.md`, `update-vi:`'s archived revision | ride in a set with a gated path | each producer's `deliverable_paths` also holds a gated artifact, so the strongest-class rule below selects for the whole set |

**A handoff whose `deliverable_paths` set spans classes takes the strongest class in it** — *gated — stopping* if any one path is, otherwise *gated — falling back*, otherwise *advisory*. One array is presented for one handoff, and it has to state the largest thing declining costs: an operator told nothing stops who then meets a stop has lost a run, where an over-warned operator has lost nothing. `design:` is the live case — its set carries the amended `specification.md`, which `design:` itself stops on, beside a `design.md` nothing stops on. **A producer whose set varies between runs resolves this per run**: `implement:` Phase 4.5 hands off an annotated `design.md` alone (falling back), or `specification.md` with or without it (stopping).

**Classify by naming the reader, never by the absence of a §3.4 row.** A missing row rules out **gated** and settles nothing else: it says the artifact is not *gated*, and says nothing about whether it is *read*. **Treat an unlisted path as unclassified rather than as unread** — name its reader, add its row, and only then pick the array. A producer adding a deliverable adds its row here in the same change.

**What this is not.** Rows D and E of §3.3 are unaffected: an artifact that *is* on a plugin branch and was never merged stops every gated consumer, falling-back ones included. The class answers what a **decline** costs — declining writes no branch and no commit, so the next phase reads row F.

### 4.1 `handoff-to-main` outcome line

Exactly one per handoff the run **offers**, prefixed `Phase handoff:`. A decline is inside that scope — the *Declined by the user* row is still the line — and a run that never reaches an offer (`idea:` on `status: draft`; `implement:` Phase 4.5 where step 7.5 wrote no note) prints none, because that row would assert a decision nobody was asked to make.

| Case | Line |
|---|---|
| Committed, pushed, PR opened | `Phase handoff: <branch> pushed — PR #<n> open (<url>). <downstream-clause>` |
| PR already existed | `Phase handoff: <branch> pushed to existing PR #<n> (<url>). <downstream-clause>` |
| PR not opened | `Phase handoff: <branch> pushed — PR NOT opened (<reason>). Open it manually. <downstream-clause>` |
| Push failed | `Phase handoff: committed <sha7> on <branch> — push FAILED (<reason>). The phase is NOT handed off.` |
| No remote | `Phase handoff: committed <sha7> on <branch> — this specs repo has no origin remote, so nothing was pushed and no PR was opened. The phase is NOT handed off.` |
| Nothing to commit | `Phase handoff: no deliverable changes to commit on <branch>` |
| Branch name substituted | append `; branch name <intended> was taken, used <actual>` |
| Declaration unaccounted for | append `; <path> was declared but staged by nothing — this run put nothing on <branch> for it` (§2.3 step 4), one clause per path |
| Record unreadable | append `; a status record could not be read as a path (<record>) — nothing was staged for it` (§2.3 step 4), one clause per record |
| Declined by the user | `Phase handoff: skipped at your request — this run's deliverable (<artifacts>) is written but not on <default>. <next-phase-clause>` |
| Gate failed | `Phase handoff: NOT handed off — <reason>` |

**`<artifacts>` names the whole declared set** — every path of the run's `deliverable_paths` (§2.9), comma-separated. A decline stages nothing, so the declaration is the only list there is.

**Every staged path is named, beneath the line.** On each row that committed something — *Committed, pushed, PR opened*, *PR already existed*, *PR not opened*, *Push failed*, *No remote* — follow the outcome line with one indented line per path §2.3 step 3 staged, in the order it staged them, each written exactly as git reported it under `-z`. The line itself stays one line. This is the positive half of §2.3 step 4: nothing used to print which paths landed, so nothing revealed that one had not.

**`<downstream-clause>` is resolved from §4.0's class.** On a **gated** artifact — either half, because a deliverable sitting on an unmerged plugin branch is rows D and E, which stop every gated consumer whatever its row F does — it is `The next phase runs once it is merged.`, or, on the *PR not opened* row, `The next phase will stop until it is merged.` On an **advisory** one it is `No command waits on this; what reads it reads it as advice.` On an **unread** one, `Nothing downstream reads it, so no command waits on this.` The *No remote* and *Push failed* rows carry no clause: neither landed the artifact.

**`<next-phase-clause>` resolves the same four ways, for a decline** — which writes no branch and no commit, so the next phase reads **row F**:

- **gated — stopping** (§4.3's first array) → `The next phase will stop until it is.`
- **gated — falling back** (§4.3's second array) → `The next phase does not stop on that: it falls back to what it does when the deliverable is missing, and that might not read your copy.`
- **advisory** (§4.3's third array) → `Nothing stops on this; the phase that reads it reads your working copy, so it still sees this run's result.`
- **unread** (§4.3's fourth array) → `Nothing downstream reads it, so no command stops on this.`

No two are interchangeable, and each wrong pick misleads in its own direction: the stop clause on an artifact no row stops on promises a refusal the operator will not meet, the fallback clause describes a fallback by a phase that was never waiting on the file, the advisory clause tells them a reader exists where none does, and the unread clause tells them to ignore a phase that is in fact reading the file.

### 4.2 The no-`gh` fallback text

    The branch is pushed but no pull request was opened (<reason>).
    Open one from <branch> into <default> in the web UI, using this title:
      <title>
    The body is at <body-path>.
    <downstream-clause>   # §4.1 — never the bare "until it is merged, the next phase will
                          # stop", which is false for every class but the first.

### 4.3 The consent choice

**One array per `<next-phase-clause>` value (§4.1) — four, and §4.1's bullet list is the authority on the count.** A producing command presents the array its deliverable set's class selects (§4.0), verbatim — order, wording, and the `(Recommended)` marker are not the caller's to change. Only the second option's parenthetical differs between the four; the first and third options are identical in all of them.

**gated — stopping** — some consumer's §3.4 row stops on this artifact. `specification.md` is the case; `specify:` and `design:` are the producers, and `implement:` Phase 4.5 where its set holds the spec:

    choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase will stop until this is on main)", "Cancel"]

**gated — falling back** — every §3.4 row naming it preserves a pre-existing absent behaviour. `idea.md` (`idea:`), the VI (`create-vi:`, `update-vi:`), the ARD (`create-ard:`), and an annotated `design.md` handed off alone (`implement:` Phase 4.5):

    choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase does not stop on this, but until this is on main it might not read your copy)", "Cancel"]

**advisory** — nothing gates it, but a command reads it. `_readiness.md` is the case, and `ready:` the producer:

    choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (no command stops on this; what reads it reads your working copy)", "Cancel"]

**unread** — nothing gates it and nothing reads it after the run that wrote it. §4.0 lists no standalone member today — every such file rides in a set with a gated path — so no producer selects this array; it is here so that a producer adding one has the right text to reach for, after it has looked for a reader and found none:

    choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (nothing downstream reads this, so no command stops on it)", "Cancel"]

The second option's parenthetical is load-bearing: it is the only place the user learns what declining costs, and the only reason there are four arrays rather than one. It must agree with the `<next-phase-clause>` §4.1 prints on that same decline — the two are read by the same operator minutes apart, and a run that contradicts its own prompt teaches them to trust neither half.

**Before presenting the array, run §2.1's push-target probe.** It is read-only — `git -C "$SPECS_PATH" remote get-url origin` — and it is the one step of §2 that runs ahead of the choice, because its result is what decides the line below; `handoff-to-main` carries the `remote` value it set into §2.5 and §2.6 when option 1 is taken. Where `git -C "$SPECS_PATH" rev-parse --git-dir` fails there is no repository to probe: print nothing here, and §2.1's gate reports that state if option 1 is taken. **Where the probe set `remote: none`, print one line immediately above the array**, then present the array itself unchanged:

    This specs repo has no `origin` remote: the first option will branch and commit locally, and the push and pull request cannot run.

The array is not reworded for this: the option text says what the option is *for*, and the class parenthetical is the only thing that varies between the arrays. The first option keeps its `(Recommended)` marker — committing the deliverable locally is still the best of the three options, and the notice has already said what it will and will not do.

**What each option means.** Option 1 runs `handoff-to-main` (§2). Options 2 and 3 both decline it: the deliverable stays written and uncommitted, and the producer emits §4.1's "Declined by the user" line either way. They differ only in recorded intent — option 2 states the user will handle git themselves, option 3 states nothing — so a caller must not infer from option 3 that the artifact is unwanted, and must never delete or revert it. **Neither option stops the run's emitter tail**: feedback → follow-ups → cost → `resume.md` → `commit-artifacts` still executes, because that tail commits only `$SPECS_PATH`'s bounded session-artifact paths (`specs-repo-git.md` §2.1), never the deliverable this choice governs.

### 4.4 Stop contract

Every `require-on-main` stop carries the same four parts as `specs-repo-git.md` §5, in this order: what was found (the concrete state — the path, the branch, the pull-request number); what the plugin did **not** do, stated as the consequence; the exact commands to resolve it with `$SPECS_PATH` already substituted; and one clause on what happens if it is ignored.

## 5. Caller contract

Four obligations. Omitting any one is a defect, not a style choice.

1. A command that **produces** a `$SPECS_PATH` deliverable cites and **offers** `handoff-to-main` (§2) in its Handoff phase, behind §4.3's choice — running §2.1's push-target probe before it presents that choice — and emits the §4.1 outcome line on §4.1's own count: once per handoff it offered, none where it offered none.
2. A command that **consumes** one cites and executes `require-on-main` (§3) in its Phase 0 — before its first subagent dispatch, code scan, docs-grounding retrieval, or grill question. A gate that fires after a scan has already spent what it was meant to save.
3. A consumer acts on the returned state, and on `absent` applies its own pre-existing behaviour (§3.4). **No consumer turns an optional input into a prerequisite.**
4. **Never restate this reference's rules** — cite the section number. A rule copied into a command is a rule that goes stale. **§4.3's choice arrays are the one exception, and they are quoted rather than cited on purpose.** An array is not a rule: it is user-facing text that `ask_user` renders literally, so a skill that only cited one would leave the run to reconstruct the wording. The exemption is that narrow — the arrays, nothing else — and a skill that quotes one names the §4.0 class it quotes it for.
