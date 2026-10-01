---
name: docs-profile
description: >
  Scan a documentation repository and write/refresh a machine-readable docs-profile (.dev-workflows/docs-profile.yml) plus complementary copilot-instructions.md guidance, as a reviewable PR. Captures spaces, dev-servers, cross-space override/shadowing, shared registries, gen3/Classic tokens, links, announcement pages, branch-naming, images, and prerequisites; defers changelog/owners to the dynatrace-docs-frontmatter skill. Bootstraps or refreshes the profile that document: consumes.
  Activated when the user prompt starts with "docs-profile:".
allowed-tools: view, edit, create, bash, glob, grep, task, ask_user
---

Profile the documentation repository: the argument (text following the `docs-profile:` trigger)

The argument (text following the `docs-profile:` trigger) is an optional repo path (default: the current working directory), optionally followed by `--inline`. The `--inline` token is passed when `document:` (Jira mode) invokes this flow inline (its Phase 0 case (c)); it switches this command to **inline mode** — see Phase 5 step 1, step 2, step 6, and Phase 6.

`docs-profile:` **bootstraps or refreshes** the machine-readable docs-profile that `document:` (Jira mode) consumes. It scans a documentation repository, synthesises a `.dev-workflows/docs-profile.yml` (and complementary copilot-instructions.md guidance) that conforms to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/docs-profile-schema.md`, then writes the result as a **reviewable PR** — branch + commit + a drafted PR message. It never pushes or auto-merges.

The command is **generic** — it works on any docs repo — but produces a richer profile when it detects a multi-space / docstack repo (it then populates `cross_space_override` and `shared_registries`; a single-space repo omits them).

It does **not** re-specify changelog or owners rules. Those are owned by the `dynatrace-docs-frontmatter` skill (+ `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/changelog-guidelines.md`, `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/managed-owners.txt`); the profile's `frontmatter:` fields are **pointers only**.

For one-off doc edits use direct mode; for Jira-driven feature documentation use `document:` (Jira mode).

---

## Phase 0 — Resolve and validate the target repo

**Run flags — before anything else in this phase, standalone only: where the argument string carries no `--inline` token.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. **`--inline` does not re-strip and inherits its caller's `run_flags` instead.** `document:` (Jira mode) Phase 0 step 4(c) constructs this run's whole argument string explicitly — `docs_repo_resolved --inline` — from a value it already holds, so that string never carries a run-flag token of its own to find; a fresh strip would resolve each flag to its environment default, losing the caller's explicit `--enforce-model` and running profiling's two dispatches unpinned inside an enforced run. An inline run reuses the `run_flags` record `document:` already resolved at its own Mode detection, unchanged, for every step below that reads one. On a standalone run the strip returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill **only `--enforce-model` applies** — this skill dispatches no `impl-maintenance`, so an explicit `--skip-feedback` is reported ignored rather than acted on. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

1. **Resolve the repo path.** Take the first token of the argument (text following the `docs-profile:` trigger) as the target path; if the argument (text following the `docs-profile:` trigger) is empty, default to the current working directory. Resolve it to an absolute path and record it as `<repo>`. Treat a `--inline` token (in any position) as the inline-mode flag, not a path; record `inline = true` when present.

2. **Validate it is a writeable git work tree:**
   - `git -C <repo> rev-parse --is-inside-work-tree` must print `true`. If it errors or prints anything else, stop with the named error: `NOT_A_GIT_WORKTREE: <repo> is not inside a git work tree.`
   - `test -w <repo>` must succeed. If not, stop with the named error: `REPO_NOT_WRITEABLE: <repo> is not writeable.`
   - Resolve and record the repo's git root as `<repo-root>`: `git -C <repo> rev-parse --show-toplevel`. It is the profile's one home (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/docs-profile-schema.md`, **Where the profile lives**): this run reads and writes `<repo-root>/.dev-workflows/docs-profile.yml` even where `<repo>` is a site below it, and all later detection and writes are relative to this root.
   - **Inline mode: a leftover bootstrap branch stops the run here.** Where this is an `--inline` run and `git -C <repo-root> rev-parse --verify --quiet refs/heads/dev-workflows/docs-profile-bootstrap` exits 0, an earlier inline run left that branch — one that stopped after profiling — and this run never switches onto it: `document:` would rename it into the docs branch, which would then fork where the leftover forked and lack every commit the base has gained since. It is tested now, before step 3's question, Phase 2's scan and Phase 3's strong-tier synthesis, because nothing any of them produces can let the run finish: the operator answers nothing and no synthesis is spent. Resolve `<base>` as Phase 5 step 2 does, and stop:

     `DOCS_PROFILE_BOOTSTRAP_BRANCH_EXISTS: <repo-root> already has the branch dev-workflows/docs-profile-bootstrap, forked from <base> at <fork> — an earlier document: run left it after profiling. This run does not switch onto it: a docs branch built on it would lack every commit <base> has gained since <fork>. Delete it or merge it into <base>, then re-run.`

     `<fork>` is the short hash and subject of `git -C <repo-root> merge-base <base-ref> dev-workflows/docs-profile-bootstrap`, where `<base-ref>` is the ref Phase 5 step 2's chain finds for `<base>` — `origin/<base>` — or `<base>` itself where that step falls back to a local branch: a read takes the ref (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/read-only-repos.md` §3, **A switch takes the name**), and nothing has pulled `<base>` up to it yet.

3. **Detect docs-repo signals** in `<repo>` — the directory this run was given, which may be a site below the top level and keeps its `package.json` and Vale configuration beside itself — and under `<repo-root>`; a signal in either counts:
   - `package.json` with any doc script (matching `*:start`, `*:build`, `*:lint`, `docs:*`, `prettier`),
   - a `.docstack/` directory,
   - a Vale configuration file (any of the five names Vale reads — `.vale.ini`, `_vale.ini`, `vale.ini`, `.vale`, `_vale`),
   - any `*/_content/` directory (e.g. `dynatrace/_content`, `managed/_content`),
   - any `_snippets/` directory.

   If **≥ 1** signal is present → proceed silently to Phase 1.
   If **0** signals are present → ask before continuing:
   ```
   "No documentation-repo signals detected under <repo> (checked: package.json doc scripts, .docstack/, a Vale configuration file, */_content/, _snippets/). Profile it anyway?"
   choices: ["Proceed — I confirm this is a docs repo (Recommended)", "Cancel — point me at a docs repo first", "Other… (describe)"]
   ```
   Default = Proceed. On Cancel, stop and report.

---

## Phase 1 — Model routing

Load and follow the model-routing policy at
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then record:

Profiling is **SIGNIFICANT** — it is a cross-cutting synthesis of the whole repository whose output (`docs-profile.yml`) steers every later `document:` run, so a wrong profile has a large blast radius. State the classification and a one-line reason.

Record a `model_routing` block modeled on §4 (a profiling command does no implementation/fix edits, so those fields are N/A), resolving each model against the fallback chains:

```yaml
model_routing:
  classification: SIGNIFICANT
  reason: "cross-cutting synthesis of the whole docs repo; output steers all later document: runs"
  current_model: <the model this orchestrator is running under>
  enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
  detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>
  planning_model: <§2 work tier: claude-opus-5.5 … fallback Sonnet 5.5/5/4.6/4.5>
  review_model: <same as planning_model — conceptually the synthesis_model; the synthesis step runs on the §2 Opus chain>
  opus_available: true | false
  notes: <any §2.1/§2 degradation, e.g. "Opus unavailable; synthesis fell back to claude-sonnet-4.6">
```

The detection phase (Phase 2) pins its subagent to `detection_model` (the §2.1 chain) via the `task` tool's `model:` override — never the session model. The synthesize phase (Phase 3) pins to `planning_model` (the §2 Opus chain). Announce any fallback now and again in Phase 6.

---

## Phase 2 — Detect (Sonnet-tier)

Dispatch a **read-only** detection subagent **pinned to the §2.1 mid-tier chain** via the `task` tool's `model:` override — `claude-sonnet-5.5`, fallback `claude-sonnet-5`/`4.6`/`4.5`; record the model actually used as `detection_model` in the `model_routing` block. Detection is mechanical repo scanning, so it must NOT inherit the session model (an Opus session would otherwise burn Opus on a cheap step, per §2.1).

→ task(agent_type: "general-purpose", model: `<detection_model — §2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5; under §10, run_flags.enforced_model>`):
  > "Read-only detection scan for a docs-profile. Do NOT write or edit any file — return a structured detection report only.
  >
  > repo_root: <resolved git root from Phase 0>
  >
  > Gather and report, each with the file path + a short verbatim excerpt as evidence:
  >
  > 1. **package.json scripts** — every script whose name matches `*:start`, `*:lint`, `*:build`, `docs:*`, `format`/`prettier`. For each `*:start` script, extract the dev-server port and base path (grep the script and any referenced config — e.g. `--port`, `PORT=`, a `base`/`basePath` in a docusaurus/mkdocs/eleventy/vitepress config). Note whether two `*:start` servers can run concurrently (distinct ports → concurrent; shared port / single server → sequential).
  > 2. **Cross-space override manifest** — presence and shape of `managed/docstack.jsonc` (or any `docstack.jsonc`): the allowlist block that pulls `../dynatrace/_content/...` pages, and whether it has an `ignore` list. Quote the allowlist + ignore keys.
  > 3. **Shared registries** — presence of `schema-ids.yml` and `schema-mappings.yml` (search the tree); report their paths and whether both exist.
  > 4. **Templating tokens** — grep the content roots for: `{{tag kind='latest'}}` (gen3/Latest marker), `::app-settings::` (gen3 settings breadcrumb), and `{{#if project=` (project conditionals — list the distinct project values seen, e.g. saas/managed/classic).
  > 5. **Content + snippet roots** — every `*/_content` and every `*/_snippets` directory (e.g. `dynatrace/_content`, `dynatrace/_snippets`, `managed/_content`, `managed/_snippets`). This determines the `spaces[]` list: one rendered space per content root.
  > 6. **Branch-naming + internal-link conventions** — read CONTRIBUTING.md, CONTRIBUTION.md, README.md, DOCUMENTATION-GUIDELINES.md, and .github/copilot-instructions.md at the repo root (and `.github/`). Quote any documented branch-naming pattern (e.g. `<initials>/<JIRA-KEY>-<slug>`) and any internal-link convention (e.g. `[text](<postid>)` where postid comes from target frontmatter).
  > 7. **Image policy** — any documented rule for screenshots/images (CDN-hosted vs committed binaries); quote the source.
  > 8. **Prerequisites** — anything a dev server needs before `*:start` boots (e.g. a `.docstack` toolchain / shim, an axios version pin, an env var); quote the source.
  > 9. **Announcement pages** — hand-authored destination pages inside an otherwise automation-owned tree (e.g. a release-notes / what's-new tree). Detection signal: a page under such a tree whose frontmatter does NOT carry `meta.content-type: release-notes` (absent, or any other value) AND whose `git log` shows human PR commits rather than automation. For each match, record its `postid` (frontmatter `postid:`), its repo-relative `path`, and a proposed `kinds` list inferred from the page title and headings (e.g. an "End-of-life announcements" page → `[deprecation, end-of-life, shutdown, sunset]`). Report `announcement_pages: []` explicitly when none are found.
  >
  > Return one section per item above. For anything not found, say `not found` explicitly — do not guess. End with a one-paragraph summary: single-space vs multi-space, and whether this looks like a docstack repo."

**Wait for the detection report.** If the agent returns nothing usable or fails, gather the same facts yourself via Glob/Grep/Read (read-only) before Phase 3 — but still record `detection_model` as the chain you attempted.

---

## Phase 3 — Synthesize the draft profile (Opus)

On the §2 powerful chain (`planning_model`), turn the detection report into a draft `docs-profile.yml`. This synthesis is the SIGNIFICANT reasoning step, so it runs on the strongest available reasoning model (Opus), pinned via the `task` tool's `model:` override — not the §2.1 detection chain.

→ task(agent_type: "general-purpose", model: `<planning_model — §2 chain: claude-opus-5.5, fallback per §2; under §10, run_flags.enforced_model>`):
  > "Synthesise a docs-profile from a detection report. This is a planning/synthesis task, not a code change — return the drafted YAML + drafted copilot-instructions.md additions, nothing else; do not write files.
  >
  > Schema (the draft MUST conform exactly): `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/docs-profile-schema.md`
  > Detection report: [paste the full Phase 2 report]
  > model_routing: [paste the Phase 1 block]
  >
  > Rules:
  > - Emit `schema_version: 1` and one `spaces[]` entry per detected content root (`id`, `content_root`, `snippet_root`, `base_path`). `spaces[]` is required and non-empty.
  > - `dev_servers`: one `servers[]` entry per `*:start` script with its `command`, `port`, `base_path`; set `concurrent: false` unless detection proved two servers can run at once.
  > - `commands`: `lint`, `format`, and any commit-hook chain detected.
  > - **Multi-space / docstack only:** include `cross_space_override` (manifest path + the last-write-wins shadowing mechanism + the `ignore`-to-win rule) and `shared_registries` (the `schema-ids.yml` / `schema-mappings.yml` lock-step rule). **Single-space repo:** OMIT both.
  > - `tokens`: only the markers detection actually found (`latest_tag`, `gen3_settings_breadcrumb`, `project_conditionals`).
  > - `internal_links.convention`, `branch_naming.pattern`, `images.policy`, `prerequisites[]`: fill from detection; leave a field out rather than inventing it.
  > - `announcement_pages[]`: one entry per page found by detection item 9 (Announcement pages), each `{postid, path, kinds}`. Emit `announcement_pages: []` explicitly when detection found none — do not omit the key.
  > - `commands.per_space:` — when `package.json` (or the repo's task runner) exposes **per-space** lint / build / format scripts whose names correspond to entries in `spaces[]` (e.g. `dynatrace:lint` + `managed:lint` for spaces `saas` + `managed`), record them under `commands.per_space.<space id>`. Map the script name to the space id by the space's `content_root` (`dynatrace/_content` ⇒ script prefix `dynatrace`), never by guessing. Omit `per_space` entirely for a single-space repo, or when only whole-repo scripts exist.
  > - `frontmatter:` is **POINTERS ONLY** — set `owned_by_skill: dynatrace-docs-frontmatter`, `changelog_guidelines: ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/changelog-guidelines.md`, `managed_owners: ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/managed-owners.txt`. NEVER copy any changelog or owners rule text into the profile.
  > - **Every path and every command is rooted at the repo's git root** (the schema's **Where the profile lives**): write each path relative to it, and each command in the form that runs from it. A script the report found in a `package.json` below that root runs in that file's directory, so record its command as `cd <that directory, relative to the root> && <the script invocation>` — run from the root, the bare invocation would read the wrong `package.json`, or none.
  > - Mark every field as `detected` (grounded in the report) or `needs-confirmation` (inferred / not found) so the orchestrator knows what to ask in Phase 4.
  > - Separately, draft minimal complementary **copilot-instructions.md additions** ONLY for conventions not already covered by the dynatrace-docs-frontmatter skill or its reminder hook (e.g. the cross-space shadowing gotcha, the shared-registry lock-step rule, dev-server sequencing). Do NOT restate changelog/owners — defer to the skill."

**Wait for the synthesis.** Hold the drafted `docs-profile.yml` and the drafted copilot-instructions.md additions for Phase 4. If Opus was unavailable and the synthesis fell back to Sonnet, note it in `model_routing.notes` and carry it to Phase 6.

---

## Phase 4 — Confirm and fill gaps

**Rule: Ask, don't guess.** For every field the synthesis marked `needs-confirmation` — and anything detection could not settle — ask the user. Use `choices` arrays; the **last** choice is always `"Other… (describe)"`; the recommended default is first and labelled `"(Recommended)"`. Group related fields into one question where possible. On a **refresh** (below), a field the Phase 2 report found nothing for is not a gap: the existing profile already answers it and keeps it, so ask about it only where the existing profile does not carry it either.

Typical gaps:

- **Exact build / start command** when a script was ambiguous:
  ```
  choices: ["Use detected `<cmd>` (Recommended)", "Enter the correct command", "Leave unset", "Other… (describe)"]
  ```
- **Prerequisites** such as the `.docstack` shim (e.g. an axios>=1.16 pin) that must be in place before `*:start` boots:
  ```
  choices: ["Record detected prerequisite(s) (Recommended)", "Add a prerequisite I'll describe", "No prerequisites", "Other… (describe)"]
  ```
- **Ambiguous space mapping** (a content root with no obvious `id` / `base_path`):
  ```
  choices: ["Accept proposed space mapping (Recommended)", "Edit a space's id/base_path", "Drop this space", "Other… (describe)"]
  ```
- **Branch-naming convention** when none was documented (drives Phase 5):
  ```
  choices: ["Use repo convention if detected, else `<prefix>/NOISSUE-docs-profile` (Recommended)", "Enter a different pattern", "Other… (describe)"]
  ```

**Idempotent refresh.** Before writing, check whether `<repo-root>/.dev-workflows/docs-profile.yml` already exists:
- **Exists** → this run is a **refresh**, and it builds the new profile **from the existing one**, never from the draft alone. Phase 2 detects only what it looks for, and the Phase 3 synthesis sees the detection report and the schema, never the existing profile — so the draft is a partial view of the repo, and a diff against it reads everything detection missed, and every field an operator added by hand, as a deletion under the recommended option. Build the refreshed profile by these rules:
  - **The refresh proposes a change only for a field detection produced a value for** — one the Phase 2 report found evidence for, marked `detected` or `needs-confirmation` over a value the report did find, and never one the report says `not found` for or never looks for, whatever the synthesis drafted in its place. Where that value differs from the existing one it is a proposed change; where the existing profile lacks the field, a proposed addition.
  - **Every other field is carried forward verbatim** — including any field the report found nothing for and any the schema allows that Phase 2 has no detection step for.
  - **Detection finding nothing is never a proposal to delete.** A field or entry the draft omits, leaves empty or writes as `[]` because nothing was found — `announcement_pages: []`, a `dev_servers.servers[]` list with no `*:start` script behind it — leaves the existing one as it stands.
  - **`spaces[]` is kept, never emptied.** It is required and non-empty; where detection found no content root, the existing entries stand.
  - **Lists are compared entry by entry**, each entry by what identifies it — a `spaces[]` entry by its `id`, a `dev_servers.servers[]` entry by its `space`, an `announcement_pages[]` entry by its `path`, a `prerequisites[]` entry by its text — and leaf by leaf within a matched entry, so a key detection never produces inside an entry it did detect is carried over with it. Where one identifier matches more than one entry on either side, propose nothing for that list: keep it as it stands, and say why in the diff.

  **Where the diff lists no change and no addition** — as built, or with the operator's edits folded in — every field is kept as it stands and the profile is up to date. Say so, list the kept fields, ask nothing, and end the run exactly as "Keep existing, write nothing" does below: no branch, no stash offer, no commit and no copilot-instructions.md additions, with the Phase 6 report reading "up to date — nothing written". Asking anyway offers "Apply the diff", which cuts a branch whose commit then fails with nothing to commit.

  Otherwise, show the result as a **field-level diff** in two parts — every proposed change (`existing → new`) and addition, then every field kept, each named **kept, not detected**, so the operator sees what the refresh leaves alone — and confirm:
  ```
  "A docs-profile already exists. Apply these field-level changes?"
  choices: ["Apply the diff — change the listed fields, keep the rest (Recommended)", "Keep existing, write nothing", "Edit specific fields first (you'll be prompted)", "Other… (describe)"]
  ```
  "Apply the diff" changes exactly the fields listed as changed or added and nothing listed as kept. Do not overwrite without this confirmation. Where each choice goes:
  - **"Apply the diff — change the listed fields, keep the rest"** → Phase 5, which writes the existing profile with those changes applied.
  - **"Keep existing, write nothing"** → this run writes nothing. Skip Phase 5 entirely — no branch, no stash offer, no commit, and no copilot-instructions.md additions — and go straight to Phase 6, whose report reads "kept — nothing written". In inline mode, which has no Phase 6 report of its own, control returns to `document:` with the existing profile unchanged and no branch or commit to hand back, and `document:` proceeds with that profile (its Phase 0 step 4(c)). Phase 5 runs unconditionally for every other path, so a choice that did not say where it went took Phase 5's recommended *"Stash changes and continue"*, cut a branch, and ended on a commit with nothing in it.
  - **"Edit specific fields first (you'll be prompted)"** → take the edits and fold them into the diff; where it now lists no change and no addition, end the run as the paragraph above says, and otherwise show the diff again and ask this question again.
- **Absent** → bootstrap: proceed to Phase 5 with the confirmed draft.

Record the final, confirmed `docs-profile.yml` — on a refresh, the existing profile with the confirmed changes applied, or, where the operator kept it or the refresh found nothing to change, the existing profile as it stands — and the copilot-instructions.md additions, and tag each field `detected`, `user-supplied`, or, on a refresh, `kept, not detected` for the Phase 6 report.

---

## Phase 5 — Write as a reviewable PR

Produce a reviewable PR in the **target repo** (never the plugin). **Never push or auto-merge** unless the user explicitly asks. A refresh answered "Keep existing, write nothing", or one that found nothing to change, never reaches this phase (Phase 4): there is nothing to write, so no branch is cut, no stash is offered and nothing is committed.

1. **Resolve the branch name.** **Inline mode** (`--inline`): skip the prompt and the confirmation entirely — use the deterministic name `dev-workflows/docs-profile-bootstrap`; `document:` (Jira mode) Phase 6.2 renames it to the docs-branch convention. Phase 0 step 2 has already stopped the run where a branch of that name exists (`DOCS_PROFILE_BOOTSTRAP_BRANCH_EXISTS`), so step 2 below cuts it fresh. **Standalone** (default):
   - If the repo documents a branch-naming convention (detected in Phase 2 / confirmed in Phase 4), fill its placeholders and use it.
   - If the convention has an **identity** placeholder, fill it from the §2 ladder in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md` (`$GIT_USER_INITIALS` → `git config user.initials` → inference from existing branches → the §2.5 prompt); its issue-key segment takes the documented no-issue literal, since profiling has no ticket.
   - Else (no convention documented, §1.4) use `<prefix>/NOISSUE-docs-profile`, where `<prefix>` comes from the same §2 ladder with fallback `docs/`. If the ladder yields nothing, run its §2.5 escalation:
     ```
     "I couldn't infer a branch prefix from $GIT_USER_INITIALS, `git config user.initials`, or existing branches. This workflow's default is `docs/`. What prefix should I use?"
     choices: ["Use `docs/` (default for this workflow)", "Use my initials — I'll enter them next", "Other… (describe)"]
     ```
   Always confirm the final name (initials/slugs are subjective):
   ```
   choices: ["Use proposed branch `<name>` (Recommended)", "Edit the name", "Other… (describe)"]
   ```

2. **Prepare the working tree.** `git -C <repo-root> status --porcelain`; if non-empty:
   ```
   choices: ["Stash changes and continue (Recommended)", "Proceed anyway — pre-existing changes will appear in the diff", "Cancel", "Other… (describe)"]
   ```
   Then base the branch on the repo's default branch so the profile PR is cut from a clean base. `<base>` is that branch's **name**, never its `origin/<name>` ref, which `git switch` refuses: resolve it by `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/read-only-repos.md` §3's chain, run against `<repo-root>`, and its **A switch takes the name** rule — rung 1 prints `origin/<name>` and `<base>` is what follows `origin/`; where rung 1 fails — `origin/HEAD` unset, or naming a ref that no longer exists (§3 rung 1) — `<base>` is the literal `main` or `master` whose ref rungs 2–3 find. Run `git -C <repo-root> switch <base> && git -C <repo-root> pull --ff-only` (the clean-tree check above already ran; if the fast-forward pull fails, offer the same stash/proceed/cancel choices). Where the chain is exhausted — no `origin`, or one holding neither branch — this command's own fallback applies: `<base>` is the local `main`, then `master`, whichever `git -C <repo-root> rev-parse --verify --quiet refs/heads/<name> >/dev/null` finds, switched to without the pull, there being no remote branch to bring it up to; with neither, `<base>` is the branch HEAD is on and nothing is switched. Then create the branch: `git -C <repo-root> switch -c <name>` (or, standalone, `git -C <repo-root> switch <name>` if it already exists, resuming this command's own branch — an inline run has already stopped on an existing one at step 1).

3. **Write the profile.** Create `<repo-root>/.dev-workflows/` if absent, then write the confirmed `.dev-workflows/docs-profile.yml` — on a refresh, the existing profile with only the changes Phase 4 confirmed, every field listed as kept exactly as it stood. It MUST conform to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/docs-profile-schema.md`. Apply the confirmed complementary copilot-instructions.md additions to the repo's `.github/copilot-instructions.md` (create the file if absent) — minimal, additive, scoped edits only; never restate changelog/owners rules owned by the dynatrace-docs-frontmatter skill.

4. **Format / lint.** If the repo has a formatter or linter (the `format`/`lint` commands captured in the profile), run it from `<repo-root>`, where every command the profile records runs, on the written files; fix anything it flags on those files. Skip silently if none is configured.

5. **Commit.** `git -C <repo-root> add .dev-workflows/docs-profile.yml .github/copilot-instructions.md` (only the files this command wrote), then commit:
   ```
   git -C <repo-root> commit -m "docs: add/refresh .dev-workflows/docs-profile.yml"
   ```

6. **Draft the PR message.** **Inline mode** (`--inline`): skip this step — control returns to `document:` (Jira mode), which owns the single PR draft (its Phase 8.5). **Standalone:** Detect the host (`git -C <repo-root> remote get-url origin`) and draft a copy-paste-ready PR title + body for Bitbucket or GitHub (whichever the remote indicates). Title e.g. `docs: bootstrap docs-profile for document:`; body summarising the profile (spaces, dev-servers, cross-space override, tokens, branch-naming, images, prerequisites) and the copilot-instructions.md additions. **Do not push, do not open the PR via any CLI** — present the branch name + the drafted message for the user to push and open themselves.

---

## Phase 6 — Final report

**Inline mode** (`--inline`): skip this report — control returns to `document:` (Jira mode), which produces the consolidated report (its Phase 9), and hands it two values: `profile_branch`, the branch Phase 5 step 1 named, and `profile_commit`, the commit Phase 5 made — `git -C <repo-root> rev-parse HEAD`, read immediately after that commit succeeds. `document:` renames that branch and squashes onto that commit (its Phase 6.2 and Phase 8.5), so it takes both from here rather than looking either up. Where Phase 5 made no commit — the operator kept the existing profile (Phase 4) — neither is handed back. The rest of this section is the standalone report.

Output a structured report — do NOT ask any closing confirmation:

```
## Docs-profile Report

### Classification
SIGNIFICANT — cross-cutting synthesis of the whole docs repo; output steers all later document: runs

### Target repo
<resolved git root>  (single-space | multi-space / docstack)

### Profile written
<repo-root>/.dev-workflows/docs-profile.yml  (bootstrapped | refreshed | kept — nothing written | up to date — nothing written)

### Fields: detected vs user-supplied
- detected: [spaces, dev_servers, commands, cross_space_override, shared_registries, tokens, internal_links, announcement_pages, branch_naming, images, prerequisites — list those that were detected]
- user-supplied: [list the fields confirmed/filled in Phase 4]
- kept, not detected: [on a refresh, the fields carried forward from the existing profile because detection found nothing for them]
- omitted: [e.g. "cross_space_override + shared_registries — single-space repo"]
- frontmatter: pointers only → dynatrace-docs-frontmatter skill (+ changelog-guidelines.md, managed-owners.txt); changelog/owners NOT re-specified

### copilot-instructions.md additions
- [what was added to the repo's copilot-instructions.md, or "none — all conventions covered by the dynatrace-docs-frontmatter skill"]

### Branch
<branch name created>

### PR draft (copy-paste)
**Title:** <title>

<body>

### Model Routing
- Classification: SIGNIFICANT
- Detection model (§2.1): <detection_model>
- Synthesis model (§2): <planning_model>
- Opus available: <true | false>
- Notes: <any §2.1/§2 fallback that occurred, or "none">

### Git state
Branch <name> created with 1 commit on <repo-root>. NOT pushed and NOT merged — push and open the PR yourself when ready.

### Assumptions & limitations
- [list any]
```

---

## Invariants (always enforced)

- ALWAYS validate the target is a writeable git work tree (Phase 0); stop with a named error if not
- ALWAYS pin detection to the §2.1 detection chain via the `task` `model:` override — never inherit the session model — and record `detection_model`
- ALWAYS run the synthesis on the §2 powerful (Opus) chain via the `task` `model:` override
- ALWAYS conform the written profile to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/docs-profile-schema.md`
- ALWAYS treat `frontmatter:` as pointers to the dynatrace-docs-frontmatter skill; NEVER copy changelog/owners rules into the profile
- OMIT `cross_space_override` and `shared_registries` for a single-space repo; include them only when a multi-space / docstack repo is detected
- ALWAYS show a field-level diff and confirm before overwriting an existing `.dev-workflows/docs-profile.yml` (idempotent refresh)
- ALWAYS write the profile to `.dev-workflows/docs-profile.yml` at the TARGET repo's git work-tree top level (`<repo-root>`, the schema's **Where the profile lives**) — never the plugin, and never a directory below that top level
- NEVER push or auto-merge — output a reviewable PR (branch + commit + drafted PR message) for the user to push
- NEVER switch an inline run onto an existing `dev-workflows/docs-profile-bootstrap` — stop with `DOCS_PROFILE_BOOTSTRAP_BRANCH_EXISTS`, naming the branch, its base and where it forked, at Phase 0 step 2, before any question, scan or synthesis; a standalone run may resume its own existing branch (Phase 5 step 2)
- ALWAYS use `choices` arrays for decision points; recommended default first and labelled "(Recommended)"; last choice always `"Other… (describe)"`
- ALWAYS reference plugin paths with `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows`
- ALWAYS produce the Phase 6 report as the final output, noting any §2.1/§2 model fallback
