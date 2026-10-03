---
name: epics
description: >
  Jira-driven Epic-writing workflow. Reads a Value Increment and existing Epics from exported markdown, optionally scans code repos, drafts child Epic definitions, and gates on dt-style-checker and Opus epic-reviewer.
  Activated when the user prompt starts with "epics:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Draft child Epics for the Jira Value Increment: the argument (text following the `epics:` trigger)

Usage: `epics: <VI-Key> [<Epic-Key>] [--no-docs | --docs <path>]` (`--no-docs` turns off documentation grounding for the run; `--docs <path>` overrides `$DOCS_PATH` for this run — see Phase 2).

`epics:` is the **Jira-driven Epic-writing** workflow. Given a Value Increment key, it reads the VI plus its existing Epics from pre-exported markdown (the VI's feature-folder `jira-import/`, or an imported-Jira directory), optionally scans code repos to identify reusable capabilities and gaps, drafts child Epic definitions as markdown files under the resolved output directory, and gates the result on a review-tier review.

Key distinction from `document:` (Jira mode): the VI being Epic-ized is **not yet implemented** — there are no PRs to diff. Code scanning (when enabled) is a plain filesystem search to understand what exists and what needs to be built.

`epics:` **never branches**, never runs `handoff-to-main` and never opens a pull request (still true — the run's git **writes** are confined to `$SPECS_PATH`, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`; the run does make read-only git calls elsewhere — Phase 4's `git remote get-url origin` per candidate clone and Phase 8's `git diff --stat` from `project_root` — but none of them writes), and writes only to the resolved output directory — `<VI folder>/epic-drafts/`, or a derived `epic-drafts/<jira_key>/` dir beside an imported hierarchy outside `$SPECS_PATH`. Drafts written under `$SPECS_PATH` (`<VI folder>/epic-drafts/`) are committed by the terminal `commit-artifacts` step (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.1), unless the run carries `specs_git: blocked` or `specs_git: misrooted`, which leave them written and uncommitted; drafts written beside an import outside `$SPECS_PATH` are never committed — git there is the user's responsibility. The run commits only inside `$SPECS_PATH`, and only its bounded artifact paths (§2.1) — via the `specs-preflight` flush at run start (§3.4) and the terminal `commit-artifacts` step (§4); never anything outside `$SPECS_PATH`. It still creates no branch (still true — `specs-preflight` switches `$SPECS_PATH` only between branches that already exist, and only plugin-created ones (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.2); it creates none).

---

## Phase 0 — Load

**Run flags — before anything else in this phase.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. It returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill both `--skip-feedback` and `--enforce-model` apply. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

1. **Resolve the Jira input via the shared front-end.** Strip every recognised
   flag first — `--no-docs` and `--docs <path>` (consumes the token after it)
   — so an unstripped flag or its value is never mistaken for part of the Jira
   grammar. Execute
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md` against
   the stripped argument (text following the `epics:` trigger). `epics:` is **jira-driven only**: expect `mode: jira-driven`
   with `jira_key` (the input Value Increment key), `jira_export_root` (the VI
   export dir — `<feature-folder>/jira-import` for a JiraID, or the passed
   directory), and `source`. The front-end owns the
   import-location validation and Fallbacks A/B. Carry `jira_key`,
   `jira_export_root`, and `focus_key` forward. Downstream, `<JIRA_KEY>` and
   `<VI-KEY>` both denote this `jira_key`.

   If the front-end returns `mode: direct` (no Jira input), stop with
   `EPICS_NEEDS_JIRA: epics: needs a Jira key or an imported-Jira directory.` —
   `epics:` has no direct-prompt behavior.

`epics:` is **cwd-agnostic**: it writes Epic drafts to an absolute output
directory (resolved in Phase 1), so it does **not** require cwd to be inside the
specs repo.

**Specs-repo preflight.** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
and execute its `specs-preflight` entry point (§3) inline: flush any leftover
session artifacts from an earlier run, retry an artifact commit that failed to
push, and settle the branch. Prompt-free, and silent unless it acts, a guard fires, or §3.1 reports a misconfigured `$SPECS_PATH`. If a guard fires, emit its §5 notice; if it returns
`specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1), carry that flag for the whole run — the
terminal `commit-artifacts` step skips on it.

---

## Phase 1 — Clarification

**Rule: Ask, don't guess. This rule is absolute.**

Group questions where possible; use `choices` arrays; the last choice in every array MUST be `"Other… (describe)"`.

Ask about:

- **Output directory.** One `.md` file per Epic, filename `<NEW-EPIC-SLUG>.md`
  (drafted Epics have no Jira ID yet, so they are slug-named files inside the
  VI-keyed folder). The default is **`<VI folder>/epic-drafts/`** — beside `jira-import/`, never inside it: a re-import regenerates `jira-import/`, so a draft written there would be lost, while `epic-drafts/` survives re-imports. The terminal `commit-artifacts` step commits it (`specs-repo-git.md` §2.1), unless the run carries `specs_git: blocked` or `specs_git: misrooted`, which leave it written and uncommitted. For a directory-token input outside `$SPECS_PATH`: `<parent-of-jira_export_root>/epic-drafts/<jira_key>/`, with the path-safety guard — warn and offer another path if it would fall *inside* `jira_export_root`. A pre-existing directory that already holds drafts is normal — **not** a warning.
  The directory is auto-created if missing. Record `output_dir`, and record
  `project_root` = `$SPECS_PATH` when the VI folder resolved, else `output_dir`. Ask:
  ```
  choices: ["Use <output_dir> (Recommended)", "Use a different path (you'll be prompted)", "Cancel", "Other… (describe)"]
  ```

- **Code examination on/off** (default ON). If ON, ask which repos under `$REPOS_PATH` to scan:
  ```
  choices: ["Scan repos referenced by sibling/parent Epics under this VI (Recommended — auto-derived)", "Let me list the repos manually (you'll be prompted)", "Turn code scan off — produce Epic drafts from Jira content alone", "Other… (describe)"]
  ```
  When "auto-derived" is chosen, inspect the sibling/parent Epics' `## Pull Requests` sections (if any) for repo references; if none, fall back to asking the user to list repos.

- **Repo refresh policy** (only if code scan is ON):
  ```
  choices: ["fetch + pull default branch (Recommended)", "fetch only", "no refresh", "Other… (describe)"]
  ```
  The `fetch + pull default branch` default matches `code-scanner`'s default (`refresh.switch_to_default_branch: true, refresh.pull: true`) — capability scans target present-day code and want the default-branch tip. This is deliberately different from `document:` (Jira mode), which keeps `pull: false` because historical merged commits must not move.

- **Repos search base (`$REPOS_PATH`)** (only if code scan is ON). Read `${REPOS_PATH:-/workspace}` (the container mounts every repo under `/workspace`). `$REPOS_PATH` may be a single directory or a colon-separated list. Ask:
  ```
  choices: ["Use $REPOS_PATH (default /workspace) (Recommended)", "Use a different path (you'll be prompted)", "Cancel", "Other… (describe)"]
  ```
  If "different path", take free-text input (single dir or colon-separated list) and validate that at least one directory exists under it. Record the resolved value as `$REPOS_PATH`. Individual clones are located in Phase 4 by matching their `git remote` against each repo slug — not by assuming a `<base>/<slug>` directory name.

Also display (for user context):
- Resolved cwd absolute path
- Resolved output directory
- Resolved `$REPOS_PATH` (or "N/A — code scan off")
- Resolved `jira_export_root` and `jira_key` (plus the VI folder when resolved)

No branching context is shown — this command never branches (still true — `specs-preflight` only switches `$SPECS_PATH` between branches that already exist, and only ones the plugin created, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.2; it creates none).

---

## Phase 1.5 — Classify

Load and follow the model-routing policy at `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then classify the task as exactly one of: `SIMPLE`, `MODERATE`, `SIGNIFICANT`, or `HIGH-RISK`. Epic writing is typically **MODERATE** (bounded scope, single VI, specs-repo output). State the classification and a one-sentence reason.

MODERATE → no separate Opus planner; the `epic-reviewer` gate (Opus, dispatch-pinned to this chain) is mandatory. Resolve the per-step routing per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §9:

```yaml
model_routing:
  classification: MODERATE        # typical; SIGNIFICANT possible
  reason: <one-line>
  current_model: <the model this orchestrator is running under>
  enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
  defect_model: <§2.1 detection chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
  detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # jira-reader, code-scanner, dt-style-checker, doc-fixer, epic-writer (MODERATE), Phase 8 maintenance agents
  review_model:    <§2.3 review tier>     # epic-reviewer (dispatch-pinned to this chain; recorded, no override unless §10 enforces a model)
  implementation_model: <= detection_model>   # the epic-writer subagent (Phase 6); planning_model if SIGNIFICANT/HIGH-RISK
  opus_available: <true if a §2 Opus model resolved, else false>
  notes: <any §2/§2.1 fallback or degradation>
```

Each subagent dispatch below cites its chain (§9 role→chain map). **No relaunch advisory** for MODERATE — the writer runs on its detection pin and the gates run on `current_model`, which §3.1 allows (if a run is classified SIGNIFICANT/HIGH-RISK, the §9.1 advisory applies and `epic-writer` escalates to the §2 chain). If no Opus is available, `epic-reviewer` falls to the Sonnet floor — record the degradation in `notes` and the Phase 9 report.

---

## Phase 2 — Plan + approval

**Documentation grounding (optional, independent of code scan).** Before presenting the plan below, run `resolve-docs-grounding epics` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md` — this is the run's only consent-bearing step (an index build or a capped refresh), so it must resolve here, before Phase 3's `jira-reader`, Phase 4's repo resolution, and Phase 5's parallel code scan do any of the run's real work. This runs ahead of Phase 2.5/2.6's `require-on-main`/`ard-resolution.md` gates — a deliberate exception to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §5 rule 2's ordering, kept here rather than moved because `resolve-docs-grounding`'s only expensive step is itself behind its own consent prompt (`docs-grounding.md` step 3.5), and an index build it produces is a durable, run-independent artifact, not per-run work a later stop would waste.

Present a concise plan:

- Resolved `jira_key` and the `jira_export_root` path
- Existing Epics identified under this VI (will NOT be duplicated)
- Repos to scan (or "code scan off")
- Docs grounding: the `docs grounding:` line that `resolve-docs-grounding` returned, verbatim — including its `retrieval:` value and any index-build, staleness, or shadowing clause (off switch: --no-docs)
- Output directory with one file per new Epic; propose a name stub per Epic if the themes already suggest them
- Parallelism plan (up to 4 `code-scanner` instances per batch, single task message per batch)
- Proposed Epic sizing/sequencing — prefer fewer, larger Epics where the VI direction is validated; split only at a genuine risk / feedback-loop boundary; order so that no Epic depends on a later one
- **Wide-refactor exception** — a blast-radius-wide *mechanical* change (rename/retype a shared symbol, column, or type) that genuinely cannot be tracer-bulleted into independent vertical slices is sequenced **expand → migrate-in-batches → contract**: one Epic adds the new form alongside the old, one-or-more Epics migrate call sites in batches, and a final Epic removes the old form (blocked by every migrate-batch). Prefer this over forcing the change into an awkward vertical slice

Ask:
```
"Epic drafting plan ready. What would you like to do?"
choices: ["Approve & continue (Recommended)", "Revise plan", "Cancel"]
```

- **Approve** → proceed to Phase 3
- **Revise** → ask what to change, update, re-show, re-ask
- **Cancel** → stop and summarise what was planned

---

## Phase 2.5 — Resolve applicable ARD (optional)

Resolve any VI-level ARD for this VI by citing
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/ard-resolution.md` with `vi = jira_key`,
**`epic: null`** (Epics do not exist yet — VI-level ARD only), and `$SPECS_PATH`.

- On `status: none` (including `$SPECS_PATH` unset/unresolvable) → **skip and
  proceed exactly as before.** No prompt, no extra output.
- On `status: unmerged` → **stop**, naming the returned `branch` and any `pr` — an ARD that exists but has not landed on `<default>` is a weaker architectural basis than the one about to arrive, and Epics drafted against it would need re-doing once it does.
- On `status: found` → carry `invariants` + `guidance_summary` forward: pass them
  to `epic-writer` (Phase 6 handoff, as `applicable_ard`) so drafts stay
  consistent with the `AD#N`, and to `epic-reviewer` (Phase 7, as `applicable_ard`)
  which then activates its ARD-conformance dimension. A necessary deviation is
  recorded by the writer in the Epic draft (`- ARD deviation: … flag: architect`)
  and surfaced in the Phase 9 report — never edit the ARD.

---

## Phase 2.6 — VI-level spec enrichment (optional)

If a VI-level specification exists, fold its requirements into the coverage
inventory. **Additive, zero-cost when absent** — the common case, since
`specify:` usually runs per-Epic *after* `epics:`.

1. **Resolve the VI dir:** `$SPECS_PATH/specifications/<VI>-<vslug>/`, matched by
   key-number, tolerating a stray `-`/`_` and a human-adjusted slug (the same
   rule `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/ard-resolution.md` step 1 uses). If
   `$SPECS_PATH` is unset/unresolvable, or no VI dir matches → **skip** (set
   `vi_spec_present: false`).
2. **Detect:** execute `require-on-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §3) against `<VI-dir>/specification.md`, mapping its §3.7 return value by `stopped` first, never by `on_main` alone. On any stopping state, stop per §4.4, naming `$SPECS_PATH` explicitly — a spec that exists but has not yet landed on `<default>` is a weaker grounding basis than the one about to arrive, and Epics drafted against it would need re-doing. Otherwise (`stopped: false`): on `pass`/`pass_amending`, proceed to step 3 (`pass_amending` prints §3.3's row-B message). On `unmanaged`, behave exactly as before this feature — **skip** (set `vi_spec_present: false`). On `absent`, **skip** (set `vi_spec_present: false`); the run proceeds byte-identically to today — this is the common case, and VI-level `specify:` remains optional.
3. **Parse** `<VI-dir>/specification.md` directly (Read it — one file, a simple
   heading scan): extract its user stories `[Uxx]` and their nested acceptance
   criteria `[ACxx]` into `vi_spec_requirements[]`. **Skip `[TCxx]` test cases**
   (per-AC, non-unique, below Epic granularity) and the prose sections
   (Problem/Scope). Because `[ACxx]` numbering restarts per story, qualify each
   `spec-criterion` id with its parent story (`<Uxx>/<ACxx>`) so every `Req` id
   in `_coverage.md` is unique; `spec-story` `[Uxx]` ids are document-unique and
   used as-is:

   ```yaml
   vi_spec_requirements:
     - id:   <Uxx (story) | <parent-Uxx>/<ACxx> (criterion)>   # spec-story id is document-unique; qualify criterion ids with the parent story
       type: spec-story | spec-criterion
       text: <requirement text>
   ```

   Set `vi_spec_present: true` and record the resolved `specification.md` path
   for the Phase 9 report.

---

## Phase 3 — Read Jira hierarchy

Invoke `jira-reader` with `depth: vi-plus-epics`. This depth is specifically designed for Epic writing: richer than `vi-only` so themes extracted for `code-scanner` aren't starved of context, but lighter than `full` so the agent doesn't read dozens of already-closed child Stories.

→ task(agent_type: "dev-workflows:jira-reader", model: `<detection_model — §9 / §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Return the structured handoff for this brief:
  >
  > jira_export_root: [resolved jira_export_root]
  > jira_key:         [resolved jira_key]
  > depth:      vi-plus-epics"

Wait for the handoff. If `status: NOT_FOUND` or `status: EMPTY`, surface the `Jira key dir not found` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` (`["Re-enter key", "Cancel"]`). On `OK`, carry the handoff `requirements[]` and `requirements_source` forward —
they are the coverage ground truth for Phases 6–7.

When Phase 2.6 set `vi_spec_present: true`, **append** its
`vi_spec_requirements[]` to this `requirements[]` — the VI's own rows are
unchanged; the appended rows carry `type: spec-story` / `spec-criterion`, which
separates them from the VI's `story`/`criterion` rows. The merged list flows
unchanged into the Phase 6 handoff and the Phase 7 reviewer brief. When
`vi_spec_present: false`, `requirements[]` is exactly what `jira-reader` returned.

On `OK`, identify the Epics already linked to the VI (filter `linked_items` to `type == Epic`) — the new Epic drafts MUST NOT duplicate their scope (enforced later by `epic-reviewer`).

**Refinement target (`focus_key`).** `epics:` always reads and analyses the whole VI
(the partition and non-duplication logic are inherently VI-holistic). When `focus_key`
is set (explicit `<VI> <Epic>`), validate it is among the linked Epics; if it is not,
surface `EPICS_FOCUS_NOT_FOUND: <focus_key> is not a linked Epic of <jira_key>.` and
offer `choices: ["Proceed VI-level (draft the full partition)", "Re-enter the Epic key", "Cancel"]`.
When present, treat `focus_key` as the **single refinement target**: Phase 6 re-drafts
only that Epic's definition, and Phase 7 reviews only that file. The non-duplication
set (`existing_epics`) is the *other* linked Epics — exclude the focus Epic so Phase 6
re-emits it rather than skipping it as a duplicate. When `focus_key` is null, behaviour
is unchanged (draft the full partition of new Epics).
When `focus_key` is set, `mode = refine` and `refinement_targets = [the focus Epic]` — Phase 6 iterates on its current imported content (see `epic-writer` refinement mode) rather than regenerating from the VI alone.

**Refinement candidates.** From the same `linked_items` (`type == Epic`), read the additive per-Epic fields `refinement_candidate`, `team`, and `scope_hint` (emitted by `jira-reader` at `vi-plus-epics`). Collect `refinement_candidates` = every linked Epic with `refinement_candidate: true`. These are empty/almost-empty team-Epic shells the PE pre-created to encode team boundaries — refinement *targets to fill in*, not non-duplication constraints. This set drives the Phase 3.5 gate.

---

## Phase 3.5 — Refinement-mode gate (conditional)

Runs only when `focus_key` is set OR `refinement_candidates` is non-empty. Otherwise skip silently — `mode = generate`, behaviour byte-identical to the legacy net-new flow.

**Focus key set** → `mode = refine`, `refinement_targets = [focus Epic]`; skip the mode question (the PE named the target explicitly).

**No focus key, `refinement_candidates` non-empty** → present the detected set as a CONFIRMABLE list (detection only *proposes*; the PE is the authority) and ask the mode:
```
Detected N empty/almost-empty team-Epic shells linked to <jira_key>:
  - <EPIC-KEY> · <team, or "team: [NEEDS CLARIFICATION]"> · <scope_hint>
  ...
choices: ["Refine these N (partition the VI across them) (Recommended)", "Generate net-new Epics (ignore the shells)", "Both — refine the shells and draft net-new for leftover scope", "Let me adjust which shells to refine (you'll be prompted)", "Other… (describe)"]
```
Record `mode` (`refine` | `generate` | `both`) and the confirmed `refinement_targets` (empty for `generate`). A target whose `team` is empty carries a `[NEEDS CLARIFICATION — team]` note into the writer handoff.

**Adaptive code-scan default (refine / both only).** Re-surface the code-examination choice now that the target count is known — the Phase 1 answer was given before detection. Default **ON when `len(refinement_targets) >= 2`** (a real cross-team boundary to draw), **OFF when == 1**:
```
choices: ["<adaptive default> (Recommended)", "<the other setting>", "Keep my Phase 1 choice", "Other… (describe)"]
```
with a one-line rationale ("2+ team-Epics → code context helps draw the boundary" / "single Epic → no cross-team boundary; scan off is faster"). This runs ONLY in the refine branch, so the generate / no-candidate path never sees it (no-regression).

---

## Phase 3.6 — Documentation grounding dispatch

**Documentation grounding dispatch (optional, independent of code scan).** `docs_grounding` was already resolved in Phase 2 — consume that cached result here; never re-run `resolve-docs-grounding`. When `docs_grounding: ON`, `dispatch-docs-grounder` with `feature_summary` = the VI goal + Epic-set intent, `jira_key` = the VI key, `themes` = the `jira-reader` themes. Carry the digest into Phase 6 with **writer-attach** consumption. When OFF, skip silently.

This phase sits **before** the conditional repo-resolution and code-scanning phases deliberately. It needs only Phase 3's output — the VI goal and the `jira-reader` themes — and nothing from the code scan, and Phase 4 and Phase 5 both skip to Phase 6 when code scan is OFF. Dispatching from inside either of them would discard the digest on exactly the runs that turned code scanning off, after Phase 2 had already asked the user to consent to building an index for it.

---

## Phase 4 — Resolve repos (conditional)

If code scan is OFF, skip to Phase 6.

If code scan is ON:

1. Derive the repo list:
   - **Auto-derived** (Phase 1 default) — walk the `jira-reader` `linked_items` filtered to `type == Epic`; for each Epic `.md` file (already read during Phase 3), collect repo names from its `## Pull Requests` section URLs. Dedupe. If the auto-derived list is empty, fall back to asking the user.
   - **Manual list** — prompt for a free-text list of repo short names (one per line or space-separated). Resolve each against the `$REPOS_PATH` slug→clone map built in step 2 below.

2. Build a slug→clone map. For each top-level directory under each entry of `$REPOS_PATH`, run `timeout 5 git -C <dir> remote get-url origin 2>/dev/null`, strip a trailing `.git`, and take the URL's last path segment as that clone's slug. Skip directories with no `.git` or whose `git remote` call fails/times out. Resolve each in-scope repo slug against the map: one match → use it; multiple matches → auto-prefer basename ending `-repo`, then `_repo`/`_fast`, then alphabetically last (show candidates at plan approval); zero matches → escalate per the `Repo unresolved (zero matches) — epics:` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`:
   ```
   choices: ["Skip and continue without this repo's scan", "I'll clone it — wait", "Cancel", "Specify a different absolute path for this repo", "Other… (describe)"]
   ```

3. If the final resolved repo list is empty (every repo was skipped or missing), escalate per the `No repos derivable — epics:` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`:
   ```
   choices: ["List repos to scan manually", "Proceed without code scan", "Cancel", "Other… (describe)"]
   ```

---

## Phase 5 — Parallel code scanning (conditional)

If code scan is OFF, skip to Phase 6.

Spawn `code-scanner` instances in **batches of up to 4 concurrent agents** per task message. Wait for each batch before spawning the next.

For each repo in the batch:

→ task(agent_type: "dev-workflows:code-scanner", model: `<detection_model — §9 / §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Scan this repo for the brief:
  >
  > repo_path:     <resolved absolute path for this repo from Phase 4>
  > repo_url_slug: <repo slug, e.g. "cluster">
  > capability_themes:
  >   [paste the themes array from jira-reader, plus any VI-goal-derived themes]
  > context: |
  >   [3–5 sentences: VI goal, what the Epic-set is meant to achieve]
  > search_hints:
  >   symbols:  [class/function names inferred from VI/Epic descriptions, or []]
  >   paths:    [directory globs inferred from themes, or []]
  >   keywords: [grep keywords extracted from themes]
  > refresh:
  >   switch_to_default_branch: [true if Phase 1 chose 'fetch + pull default branch' (default) or 'fetch only'; false if 'no refresh']
  >   pull: [true if 'fetch + pull default branch'; false otherwise]"

Handle per-repo status after the batch returns:

- `OK` / `PARTIAL` / `EMPTY` — store the output, continue.
- `REPO_MISSING` — should not happen at this stage (Phase 4 already checked). If it does, escalate per the `Repo missing (after resolution)` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`.
- `DIRTY_TREE` — escalate:
  ```
  choices: ["Stash changes and retry this repo", "Skip this repo", "Cancel"]
  ```
- `REFRESH_BLOCKED` — escalate:
  ```
  choices: ["Continue with current local state", "Skip this repo", "Cancel"]
  ```
- `prep.read_only: true` — not a failure. The scan ran at `prep.scanned_ref`. Escalate per the `Read-only mount — ref stale or diverged` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` **only** when `prep.ref_committed_at` is more than 14 days old or `prep.head_divergence.ahead > 0`; otherwise proceed silently and cite evidence at `prep.scanned_ref`.

---

---

## Phase 6 — Write Epics

The drafting is delegated to the **`epic-writer`** subagent (pinned to the §2.1 detection chain for MODERATE; §2 Opus only if the run is SIGNIFICANT/HIGH-RISK — see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §9.2). The orchestrator prepares a handoff and dispatches; it does not write Epics itself, and **nothing commits in this phase** (still true — `epics:` never branches; drafts written under `$SPECS_PATH` (`<VI folder>/epic-drafts/`) are committed later by the terminal `commit-artifacts` step, and drafts written beside an import outside `$SPECS_PATH` are never committed — git there is the user's responsibility. The run commits only inside `$SPECS_PATH`, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.1).

1. **Write the handoff file.** Create a temp file (`command mktemp -t dw-epics-handoff-XXXXXX` — never a repo) containing the `epic-writer` input contract: `jira_reader_handoff`, `code_scanner_outputs` (empty if no scan), `scope` (Phase 2 in/out of scope), `existing_epics` (non-duplication), `output_dir` (resolved Phase 1 dir), `vi_goal`, `jira_key`, `requirements` + `requirements_source` (from Phase 3), `applicable_ard` (the Phase 2.5 invariants + guidance_summary, or omit when status was none), `existing_epic_themes` (themes of the already-linked Epics), `mode` (`generate` | `refine` | `both` — from Phase 3.5; `generate` when 3.5 skipped), and `refinement_targets` (list of `{key, team, scope_hint, current_body_path}`, where `current_body_path = <jira_export_root>/<EPIC-KEY>/<EPIC-KEY>.md`; empty in `generate` mode), and `docs_grounding` (the Phase 3.6 digest, or omit when OFF/EMPTY). Record its absolute path. When `focus_key` is set (the Phase 3 refinement target), set `scope` in-scope to just the focus Epic and `existing_epics` to the *other* linked Epics, so `epic-writer` re-drafts the single focus Epic's definition file; `output_dir` is unchanged. Remove the handoff file (`command rm -f -- "<path>"`) once step 2's dispatch (and any re-dispatch on `status: BLOCKED`) has returned — no later step in this run reads it again.

2. **Dispatch the writer:**

→ task(agent_type: "dev-workflows:epic-writer", model: `<detection_model — §9 / §2.1 detection chain; planning_model (§2 Opus) only if classification is SIGNIFICANT/HIGH-RISK; under §10, run_flags.enforced_model>`):
  > "Write the child Epic definitions for this brief.
  >
  > handoff_file: [absolute path of the temp handoff file from step 1]"

3. **Handle the return.** `status: DONE` → record `files_written` for Phase 6.1 onward. `status: BLOCKED` → surface the named gap:
   ```
   choices: ["Provide the missing input (you'll be prompted)", "Cancel"]
   ```
   On a provided value, rewrite the handoff and re-dispatch once. Nothing is committed here (still true — this step writes only Epic drafts into the output directory; under `$SPECS_PATH` the terminal `commit-artifacts` step commits them, save on a run carrying `specs_git: blocked` or `specs_git: misrooted`, and outside it nothing does — git management there is the user's responsibility).

   Also record `coverage_file` (the `_coverage.md` path) and `clarifications_needed[]` for Phases 6.1 and 7.

---

## Phase 6.1 — Resolve clarifications

If the writer returned a non-empty `clarifications_needed[]`, resolve it BEFORE
the style check and review (so no review cycle is spent on known unknowns).
Present ONE batched prompt listing every marker grouped by Epic; for each:
```
choices: ["Use the writer's suggested answer", "I'll answer (you'll be prompted)", "Leave unresolved", "Other… (describe)"]
```
Fold each resolved answer into the affected Epic draft (Edit the file inline, or
re-dispatch `epic-writer` once with the resolutions). Markers the user chooses to
**leave unresolved** stay visible in the draft and become `epic-reviewer`
BLOCKERs in Phase 7. If `clarifications_needed[]` is empty, this phase is a
**silent no-op** (byte-identical to a run without it).

**Leftover disposition (refine / both only).** After the writer returns, read `_coverage.md`; every `❌ gap` row is a VI requirement no team-Epic covers. In ONE batched prompt, ask per gap:
```
choices: ["Assign to team-Epic <KEY> (re-drafts that Epic to include it)", "Propose as a new (net-new, slug-named) Epic", "Defer (leave as an uncovered row)", "Other… (describe)"]
```
Fold the results back: *assign* → re-dispatch `epic-writer` once (or Edit inline) to add the requirement to the named target's `## Covers` + scope; *new Epic* → add a slug-named net-new draft; *defer* → the row stays `❌ gap` in `_coverage.md` and is listed in the Phase 9 report. Reuses the same batched-gate pattern as the clarification resolution above; no gaps → silent no-op.

---

## Phase 6.2 — Dynatrace style check

Invoke `dt-style-checker` on the files written in Phase 6. Unlike `document:` (Jira mode), this does NOT use `docs-style-checker` (no repo linter for specs-repo content). Instead, the Dynatrace corporate style guide checker validates terminology, trademarks, voice/tone, and inclusive language.

→ task(agent_type: "dt-style-guide:dt-style-checker", model: `<detection_model — §9 / §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Run the style check for this brief:
  >
  > files:    [absolute paths of every Epic file written in Phase 6]
  > doc_type: epic
  > emphasis: terminology and customer-facing captions, labels, messages, and text
  >
  > known_conventions:
  >   - the section headings mandated verbatim by the Epic template and matched
  >     literally by `pre-lint.md`'s required-heading grep — sentence-casing them fails the
  >     plugin's own lint
  >   - spaced em dashes, the house convention in every plugin-authored artifact in the
  >     specs repo
  >   - bracketed requirement IDs (`[AC#1]`, `[US#1]`, `[SM#1]`, `[UC#1]`, `[FR#1]`)
  >   - wikilinked tracker keys
  >   - this is an internal planning document, exempt from the trademark/(R) rule"

Act on the return:

- **`status: OK`** — zero violations. Proceed to Phase 7.
- **`status: VIOLATIONS_FOUND`** — invoke `doc-fixer` with the violations treated as per their severity. After `doc-fixer` completes, re-run `dt-style-checker` once:

  → task(agent_type: "dev-workflows:doc-fixer", model: `<detection_model — §9 / §2.1 detection chain; under §10, run_flags.enforced_model>`):
    > "Fix the style violations for this brief:
    >
    > Task description: [Epic drafting for <JIRA_KEY>]
    > Reviewer or style-checker output: [paste full dt-style-checker output]
    > Project root: [resolved project_root]
    > Severities to fix: MAJOR only"

  If violations remain after the re-run, proceed to Phase 7 — the remaining findings (mostly MINOR/NIT for epics) are informational and will appear in the Phase 9 report.

- **`status: ERROR`** — surface the error reason. Proceed to Phase 7 regardless (style check is not a gate for Epics, but a quality enhancement).

If `dt-style-checker` is unavailable (agent file not found), proceed directly to Phase 7. The style check is optional but recommended.

---

## Phase 6.3 — Structural pre-lint

Before the review gate, run the deterministic checks in
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/pre-lint.md` against each drafted Epic file: the **Universal checks**,
the **Jira-key collision** check (run on the whole Epic file — the template has no frontmatter), and
the **Epic** block (required headings incl. `## Independent Test`; Given/When/Then acceptance
criteria; `[NEEDS CLARIFICATION]` ≤ 3 per Epic; `_coverage.md` present). Surface every finding;
inline-fix the mechanical ones (delete a stray placeholder token); leave content gaps for the author.
**Advisory** — never blocks; proceed to Phase 7 once findings are surfaced. `epic-reviewer` remains the
gate.

## Phase 7 — Epic review gate

Invoke `epic-reviewer` (Opus). This reviewer is Epic-specific — scope clarity, acceptance-criteria testability, non-duplication of existing Epics. `docs-style-checker` is NOT used here (no repo linter for specs-repo content); Dynatrace corporate style is handled by the Phase 6.2 `dt-style-checker` step above.

→ task(agent_type: "dev-workflows:epic-reviewer"):
  > "Review the Epic drafts for this brief:
  >
  > Task description: [one-paragraph: VI key, VI goal, number of Epics drafted]
  > Written Epic file paths: [absolute paths of every Epic file written in Phase 6]
  > jira-reader handoff: [paste full YAML from Phase 3]
  > code-scanner output:  [paste array of per-repo scanner outputs from Phase 5, or 'N/A — code scan off']
  > requirements:        [paste the requirements[] array from Phase 3]
  > _coverage.md path:    [absolute path of the coverage file from Phase 6]
  > applicable_ard:       [the Phase 2.5 invariants, or omit if status was none]"

When `mode` is `refine`/`both`, include `refinement_targets` in the `epic-reviewer` brief so its conditional refinement dimensions (completeness, partition integrity, cross-team dependency sanity, team preserved) activate; omit it in `generate` mode so those dimensions report N/A.

Act on the verdict (same shape as `document:` Jira mode Phase 7):

**Triage sub-step** (before any fixer dispatch, and on every re-review): follow `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md`. For each finding, verify its claimed consequence at the location it names; keep it, mark it unverified, or dismiss it; record every dismissal and every unverified finding with its reason; and raise a grade only by effect. Hand the fixer **survivors only**, and carry every disposition into this run's report. A re-review — the one the fix cycle allows, or one you chose at the first settle prompt — is triaged under that reference's § On re-review: it carries forward what this run already ruled — save, on a re-review you chose at the first settle prompt, the dismissed and unverified findings it re-verifies — and no survivor of it is handed to a fixer. At either of that reference's settle prompts, **Keep the verdict** means the review **stayed blocked** (below) — on a kept verdict that is not `BLOCK`, which raised no BLOCKER, the run ends as Cancel does — and **Cancel** aborts the run, as the escalation's own *Cancel the whole run* does.

- **BLOCK** — invoke `doc-fixer` with `Severities to fix: BLOCKER and MAJOR`. Write the `doc-fixer` Fix Report to a temp file (`command mktemp -t dw-epics-claims-XXXXXX`, never inside a repo tree), record its path as `claims_file`, then **check `doc-fixer`'s `Stop condition flag` before re-invoking anything**. If it is `NEEDS HUMAN`, the fixer deferred at least one BLOCKER as needing a human decision: do NOT re-invoke `epic-reviewer` — a re-review can only re-find the BLOCKER the fixer has just reported it could not resolve — and instead surface each deferred BLOCKER with the reason the fixer gave, then escalate it individually per the `Review verdict BLOCK (unresolved after one fix cycle) — epics:` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`, which names this entry point alongside a review that stayed blocked. Only when the flag is `CLEAR` do you re-invoke `epic-reviewer` once **passing `claims_file`** — so the re-review falsifies the fixer's account rather than assuming it. Remove `claims_file` (`command rm -f -- "<path>"`) once this re-review (or the NEEDS HUMAN escalation above) has returned — no later step reads it. Triage the re-review under `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md` § On re-review (the triage sub-step above); on that section's **Proceed**, continue to Phase 8 as after a verdict that is not BLOCK. If the review **stayed blocked** — a BLOCKER survives that triage, or you keep the verdict at either settle prompt — escalate per the `Review verdict BLOCK (unresolved after one fix cycle) — epics:` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` for each unresolved BLOCKER individually:
  ```
  choices: ["Provide manual fix notes (you'll be prompted)", "Defer to a follow-up issue (record in Phase 9 report)", "Override and accept the finding", "Cancel the whole run", "Other… (describe)"]
  ```
  For `epics:`, "Defer" means the finding goes into an Epic-refinement note in the draft itself (appended as a `## Refinement notes` section) in addition to the Phase 9 report.

- **PASS WITH RECOMMENDATIONS** — invoke `doc-fixer` for MAJOR findings only:

  → task(agent_type: "dev-workflows:doc-fixer", model: `<detection_model — §9 / §2.1 detection chain; under §10, run_flags.enforced_model>`):
    > "Fix the review findings for this brief:
    >
    > Task description: [Epic drafting for <JIRA_KEY>]
    > Reviewer or style-checker output: [paste the triaged survivor list from the triage sub-step above — the surviving `epic-reviewer` findings only, never the dismissed or unverified ones]
    > Project root: [resolved project_root]
    > Severities to fix: BLOCKER and MAJOR"

  MINOR / NIT findings are deferred to the Phase 9 report.

- **PASS** — proceed to Phase 8.

Cap: one fix cycle + one re-review maximum.

**The recorded verdict names the version it was taken against** — where any edit followed it, the final report says so and names the edits, per the `A recorded verdict names the version it was taken against` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`. Where none did, it says that too.

---

## Phase 8 — Post-write maintenance

First gather the change context:

a. `project_root` (`$SPECS_PATH` when the VI folder resolved, else the resolved output directory) is the "project root" for this run. Run `git diff --stat` from `project_root` if it is a git repo; otherwise list the written files manually. This step never commits — just report what changed (when `project_root` is `$SPECS_PATH`, the terminal `commit-artifacts` step commits the drafts and the other bounded artifact paths, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.1, unless the run carries `specs_git: blocked` or `specs_git: misrooted`, which commit nothing; outside `$SPECS_PATH` nothing commits them).
b. Compose a **change summary block**:

```
Implementation: [one-sentence description: how many Epics drafted for <JIRA_KEY>, resolved output directory]
Change type: docs
Classification: MODERATE
Files changed:
<list of new Epic file paths, one per line>
Notable additions/removals: [new Epics by slug — one line each]
(In `refine`/`both` mode, refined Epics are identified by key `<EPIC-KEY>`, not slug.)
Epic-review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK]
```

Then spawn all four maintenance agents in a **single task message**. They are independent and run concurrently.

**Agent 1 — Documentation** (general-purpose, model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
> "Post-write documentation review. Change summary:
> [paste change summary block]
>
> The project root is the specs repo when the VI folder resolved, else the resolved output directory; look only for internal documentation files that reference Epic drafts (e.g., an `epic-drafts/README.md` or an index page enumerating active drafts).
> Determine if any such file needs updating — e.g., a new entry in a drafts index.
> Skip if: no such file exists or drafts aren't indexed centrally.
> If an update is warranted: apply minimal edits.
> Return: file updated and what changed, OR 'no update required (reason)'."

**Agent 2 — Knowledge base** (general-purpose, model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
> "Post-write knowledge review. Change summary:
> [paste change summary block]
>
> Check ~/.copilot/memory/ (global) and .copilot/memory/ (project-level, preferred for specs-repo-specific knowledge) for existing knowledge files.
> Determine if a new knowledge entry is warranted — look for: reusable insights about this VI-family's Epic patterns, non-obvious scoping constraints uncovered, code-reuse discoveries from code-scanner, duplicate-Epic near-misses that required scope adjustment.
> If YES: append to the most appropriate existing file (never create a new file if an existing one fits) using this format:
> ### [Short title]
> - **Context**: what problem/situation triggered this
> - **Insight**: the learned rule, pattern, or gotcha
> - **When it applies**: conditions under which this matters
> - **Date**: YYYY-MM-DD
> - **Ref**: [first 60 chars of the Jira key + VI summary]
> Return: file updated/created and summary of entry, OR 'no update required'."

**Agent 3 — Instructions** (general-purpose, model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
> "Post-write instructions review. Change summary:
> [paste change summary block]
>
> Check .github/copilot-instructions.md in the project root and ~/.copilot/copilot-instructions.md (global).
> Determine if any Epic-drafting rules, guidance, or guardrails are missing because of what this run revealed (e.g., a domain-specific acceptance-criteria pattern, a naming convention for Epic files, a scope-boundary rule that caught you out).
> Skip if: the run followed existing conventions with no surprises.
> If YES: apply minimal, additive, scoped changes only.
> Return: what was changed and why, OR 'no update required'."

**Agent 4 — Session maintenance** (dev-workflows:impl-maintenance, model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):

**Under `--skip-feedback`** (`run_flags.skip_feedback`, `_shared/run-flags.md` §4), this step dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance` — the same compact handoff, plus `Plugin root:` — on `run_flags.enforced_model` when set, else the `_shared/model-routing.md` §2.1 detection chain. Only when it returns at least one defect, persist them through `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, `feedback-emission.md` is not read at all. Report `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`. The in-session Lessons Learned report is what the flag costs. `emit-block` is unaffected and fires exactly as it would without the flag.
> "Analyse this session and return a Lessons Learned report.
>
> Session handoff:
> - Command run: epics:
> - What was done: [one-paragraph summary of Epics drafted]
> - Key events: [BLOCK reviews and their reason, DIRTY_TREE / REFRESH_BLOCKED scanner statuses, duplicate-Epic near-misses, missing repos, user override decisions — or 'none']
> - Workarounds used: [manual steps not automated by the workflow — or 'none']
> - Review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK]
> - Test result: N/A (no tests in epics:)
> - Project root: [resolved project_root]"

Collect all four summaries for the Phase 9 report.

**Persist plugin feedback (automatic).** After Agent 4 (`impl-maintenance`)
returns, project its plugin-facing slice into the specs repo by citing
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and calling its
`emit-auto` entry point (§6). Pass Agent 4's Lessons Learned report,
`command: epics:`, the run's `jira_key` and `source`, and `plugin_version`
(read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). `emit-auto`
renders only the report's **Command workflow improvements**, **New agents /
skills**, and plugin **Reference docs** sections plus the **Key observations**
that triggered them (§4 plugin-facing predicate) — never target-project
`copilot-instructions.md`/hook advice — as `origin: auto` entries, dedupes by stable `id`
(§3), resolves the target via the §2 specs-first ladder, and writes silently.
List the persisted path (or "no plugin-facing signal — nothing persisted") in
the Phase 9 report's Session learnings line. ADDITIVE — the impl-maintenance
report still appears in the report; this step NEVER fails the run, NEVER
commits (still true — this step only writes the feedback file; those writes
are committed by the terminal `commit-artifacts` step in Phase 10, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4), and NEVER writes into `jira-import/`, `jira_export_root`, or the
current working directory.

---

## Phase 9 — Final Report

Output a structured report — do NOT ask any closing confirmation:

**When `mode` is `refine`/`both`,** begin the report with a `Mode: <refine | both>` line and split the written-Epics listing into three labelled groups: **Refined** (keyed `<EPIC-KEY>.md`), **Net-new** (slug-named), and **Deferred** (VI requirements left uncovered via the Phase 6.1 leftover gate). In `generate` mode the report is unchanged.

```
## Jira-driven Epic Drafting Report

### Classification
MODERATE — specs-repo Epic drafting for a single VI

### Model Routing
- Session model (current_model): [model]
- epic-writer (implementation_model): [model] — detection (MODERATE) | reasoning (SIGNIFICANT)
- Detection steps — jira-reader, code-scanner, dt-style-checker, doc-fixer (detection_model): [model]
- epic-reviewer (review_model): [model]
- Opus available: [yes | no]

### VI summary
- Key: <JIRA_KEY>
- Summary: [VI summary, 1 line]
- Goal: [2–3 sentence extraction from jira-reader]

### Existing Epics (not duplicated)
- [<KEY>] [summary] — [status]
- ...
- _or_ "none"

### New Epics written
- [absolute path] — [1-line Epic summary]
- ...

### Repos scanned
- <repo-1> (<resolved repo_path>) — [status: OK | PARTIAL | EMPTY | DIRTY_TREE | REFRESH_BLOCKED; N themes classified present, M partial, K absent, E error]
- ...
- _or_ "N/A — code scan off"

### Epic review verdict
[PASS | PASS WITH RECOMMENDATIONS | BLOCK] — [1-line summary of findings applied / deferred]

### Review triage
- **Review triage:** [one line per review pass, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md` § Reporting — N findings reviewed: M survived, U unverified, X dismissed (C carried, on a re-review)] — survivors: [on a re-review, `finding — severity` per survivor, or "none"; "N/A (first review)" otherwise] — dismissals: [`finding — reason`, or "none"] — unverified: [`finding — if-true severity — what would settle it`, or "none"] — raised: [`finding — from → to — effect`, or "none"] — settled: [the answer given at a settle prompt, or "not asked"]

### Requirement coverage
[Roll-up verdict + N/M covered (P%); list each ❌ gap requirement ID; _coverage.md path] If Phase 2.6 enriched the inventory, also name the VI-level `specification.md` path and the count of `spec-*` rows added. — _or_ "derived (coarse) — VI had no structured requirements"

### Clarifications
[Resolved: <n>; Deferred (left unresolved → became blockers): <n>] — _or_ "none raised"

### ARD conformance
[verdict + any `- ARD deviation:` lines recorded] — _omit this whole section when Phase 2.5 status was none_

### Dynatrace style check (Phase 6.2)
[OK | VIOLATIONS_FOUND (N fixed, M remaining) | ERROR (reason) | SKIPPED (dt-style-checker unavailable)] — [1-line summary]

### Documentation (Agent 1)
- [file updated] — [what was added/changed] OR "no update required (reason)"

### Knowledge base (Agent 2)
- [file updated/created] — [summary of entry] OR "no update required"

### Instructions (Agent 3)
- [summary of change] OR "no update required"

### Session learnings (Agent 4)
- [top suggestions from impl-maintenance agent, or "no suggestions — routine session"]

### Deferred items
[MINOR / NIT findings that were not applied, OR epic-reviewer BLOCK findings that were overridden / deferred with the ## Refinement notes section appended — one line each; or "none"]

### Assumptions & limitations
- [list any]

### Git state
The project root has uncommitted changes. If it is `$SPECS_PATH`, the terminal `commit-artifacts` step commits the drafts and the session artifacts, unless this run carries `specs_git: blocked` or `specs_git: misrooted` — see its outcome line at the end of the run. Otherwise `epics:` does not commit the project root — git management there is your responsibility.

### Next step
[Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md` — guidance only, never auto-invoked. For each Epic just drafted, author its spec → `specify: <VI> <Epic>` (PE); the **Epic fan-out** (depth vs breadth) applies from the spec/design stage on. Optionally a Product Architect adds an Epic-level ARD first → `create-ard: <VI> <Epic>`. If the review BLOCKED, resolve that first.]

### Context hygiene

The resume pointer is written in the terminal follow-up phase (Phase 10), per `session-hygiene.md` §1. Then:

- **Continuing as PE (`specify: <VI> <Epic>`)?** → run **`/compact`** — context still relevant.
- **Handing to PA (`create-ard: <VI> <Epic>`), even yourself?** → run **`/clear`** for a clean slate.
- Consider **`/rename <VI-ID>-<slug>-pe`** to relocate this session later.

Guidance only — see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`.
```

---

## Phase 10 — Emit follow-up tasks

Terminal phase — runs AFTER the Phase 9 Final Report is composed; NEVER
interrupts an earlier phase. Persist the run's manual-step / out-of-scope
follow-ups by citing `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/followup-emission.md`
and executing its steps inline.

1. **Collect** the qualifying follow-ups: the manual publish step ("create these
   drafted Epics in Jira manually" — the drafts are specs-repo files, not Jira
   tickets) and the Phase 9 `### Deferred items` that are out-of-scope refinement.
2. **Filter** them with the reference's §4 qualifying predicate.
3. **Resolve** the write target via the §2 ladder using `jira_key` and `source`;
   render + place tasks per §1 (verbose detail inlined as a section of the file); dedupe per §3.
4. **Preview + confirm** per §5 (`approve-all | select | cancel`), then write.

ADDITIVE — the follow-ups also remain in the Phase 9 report. This phase NEVER
fails the run, NEVER commits (still true — this phase only writes follow-up
files; those writes are committed by the terminal `commit-artifacts` step at the
end of this phase, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4), and NEVER writes into `jira-import/`, `jira_export_root`, or the current
working directory.

**Then write the resume pointer.** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`
§1 and write/overwrite `<VI-dir>/dev-workflows/resume.md` now — after the
follow-up entries above, so the pointer reflects the completed run, and before
the commit step below, so it is included in it. Redact per §1. Silent; the
printed `### Context hygiene` guidance already appeared in the Phase 9 report.

**Then commit session artifacts (terminal).** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
and execute its `commit-artifacts` entry point (§4) inline — the LAST action of
the run. It stages ONLY the §2.1 bounded artifact paths inside `$SPECS_PATH`,
commits `<KEY> Add dev-workflows session artifacts (epics:)`, and pushes per §4
step 5. It NEVER touches an imported directory outside `$SPECS_PATH` (drafts written there are never committed), a
code/docs repo, or the current working directory (an import under `$SPECS_PATH` and `<VI folder>/epic-drafts/` are committed by
this step, `specs-repo-git.md` §2.1); NEVER
force-pushes; NEVER fails the run; and skips entirely when the run carries
`specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1, or §8's `specs-root-check` stop), re-emitting that notice. Because the Phase 9
report was composed before this phase, **print its §6 outcome line here**, as
the run's last output — prefixed `Specs repo:`, with any guard notice repeated
in full.

---

## Invariants (always enforced)

- ALWAYS `emit-block` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) before escalating a halt caused by a **plugin / skill / command / reference gap** (a capability the run needed but the plugin lacked) — so a run abandoned at the block still records it. NEVER for a work-quality review BLOCK or an environment / user halt (repo-missing, dirty-tree, jira-not-found, cancellation)
- ALWAYS resolve input via the shared Jira-input front-end (Phase 0) — a JiraID requires `$SPECS_PATH` and an import in its feature folder; an imported-Jira directory works without either; `epics:` is cwd-agnostic and rejects `mode: direct`
- NEVER create a git branch — this command never branches. `specs-preflight` may switch `$SPECS_PATH` between branches that already exist, and only ones the plugin created (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.2); it creates none.
- NEVER branch, run `handoff-to-main`, or open a pull request. NEVER commit anything in an imported directory outside `$SPECS_PATH` (drafts written there are never committed) or the current working directory — git management there is the user's responsibility. Drafts under `$SPECS_PATH` (`<VI folder>/epic-drafts/`) and an import under `$SPECS_PATH` are committed by the terminal step, not by this skill's own phases, save on a run carrying `specs_git: blocked` or `specs_git: misrooted`, which commits nothing. The terminal `commit-artifacts` step commits ONLY `$SPECS_PATH`'s bounded artifact paths (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §2.1).
- ALWAYS run `specs-preflight` at Phase 0 and `commit-artifacts` as the run's last action (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`) — bounded to `$SPECS_PATH`'s artifact paths (§2.1) and to plugin-created branches (§2.2), always `git -C "$SPECS_PATH"` and never a `cd` (§1 rule 1), never force-pushing, and never failing the run
- NEVER write inside `jira-import/` — re-created on every import; writes would be lost
- NEVER write inside `_archive/` — read-only by convention
- NEVER write inside `jira_export_root` — it is re-created on every Jira import, so drafts there would be lost (the Phase 1 path-safety guard enforces this for the derived `epic-drafts/` default)
- ALWAYS write to the resolved `output_dir` — `<VI folder>/epic-drafts/`, else `<parent-of-jira_export_root>/epic-drafts/<jira_key>/` (or the user-confirmed alternative) — auto-create the directory if missing
- ALWAYS escalate missing repos before proceeding — never silent skip
- ALWAYS invoke `epic-reviewer` before Phase 8 maintenance
- ALWAYS resolve the `model_routing` block at Phase 1.5 and pin each subagent dispatch to its §9 chain via `model:` — the mechanical steps (`jira-reader`, `code-scanner`, `dt-style-checker`, `doc-fixer`), the Phase 8 maintenance agents (three `general-purpose`, one `impl-maintenance`), and `epic-writer` (MODERATE) to the §2.1 detection chain; `epic-reviewer` keeps its §2.3 review-tier pin fixed at dispatch (no override unless §10 enforces a model); coordination + interactive gates run on `current_model`
- ALWAYS delegate Phase 6 writing to the `epic-writer` subagent (write-only); the orchestrator never writes Epics itself and never commits the drafts itself (still true — drafts under `$SPECS_PATH` are committed by the terminal `commit-artifacts` step, save on a run carrying `specs_git: blocked` or `specs_git: misrooted`; drafts outside it are never committed, and git there is the user's responsibility)
- ALWAYS cap review/fix cycles: 1 fix + 1 re-review max
- ALWAYS pass `Change type: docs` in the Phase 8 change summary block
- ALWAYS pass `Command run: epics:` in the Phase 8 Agent 4 session handoff
- ALWAYS spawn Phase 8 agents in a single message — never sequentially
- ALWAYS use `choices` arrays for decision points; last choice is always `"Other… (describe)"`
- ALWAYS produce the Phase 9 report as the final output
- ALWAYS end the Phase 9 report with a `### Next step` recommendation (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md`) — guidance only, never auto-invoked
- ALL written claims must be traceable to Jira keys (from `jira-reader`) or code paths (from `code-scanner`); do not invent content the sources don't contain. `[[KEY]]` wikilinks in the draft are correct here and stay: they are the specs tree's required traceability form, not a link that has to resolve — the specs tree is a git repository, not a vault, and nothing there resolves `[[name]]`. `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/doc-structure-conventions.md` §1 — which bans in-page provenance — governs **rendered product-docs pages** (`document:`'s write targets), not Epic drafts; do not apply it to them
- NEVER run `docs-style-checker` — Epic drafts are plugin-internal and not subject to product-docs prose linting. Dynatrace corporate style is checked via `dt-style-checker` in Phase 6.2 instead.
- ALWAYS have `epic-writer` write `_coverage.md` to `output_dir` (VI-holistic, even in focus mode); it is NOT a Jira Epic and is never pasted to Jira
- ALWAYS run the Phase 6.1 clarification gate when the writer returns clarifications; unresolved-by-choice markers become `epic-reviewer` BLOCKERs
- ARD steps (Phase 2.5, writer/reviewer `applicable_ard`, the Phase 9 ARD section) are ADDITIVE and guarded on `status: found` — a run with no ARD is byte-identical to before
- ALWAYS pass `requirements[]`, the `_coverage.md` path, and `applicable_ard` (when found) to `epic-reviewer`
- ALWAYS treat linked Epics flagged `refinement_candidate: true` as fill-in targets (not non-duplication constraints) once the Phase 3.5 gate selects `refine`/`both`; the confirmed target set is the PE's, not the raw detection
- ALWAYS write refined team-Epics to `<output_dir>/<EPIC-KEY>.md` (keyed by real Jira id) and net-new Epics to `<output_dir>/<slug>.md`; refined files carry a `**Team:**` line
- ALWAYS re-surface the code-scan default adaptively in Phase 3.5 for refine/both (ON at ≥2 targets, OFF at 1) — never in the generate path
- ALWAYS run the Phase 6.1 leftover-disposition gate in refine/both when `_coverage.md` has `❌ gap` rows; silent no-op when none
- Refinement mode (Phase 3.5 gate, `refinement_targets` handoff, leftover gate, keyed output) is ADDITIVE and guarded — no `refinement_candidate` targets AND no `focus_key` ⇒ `mode = generate` and the run is byte-identical to the legacy net-new flow
- ALWAYS end the Phase 9 report with a `### Context hygiene` block per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` — prepare-first (the `resume.md` write runs later, in the terminal follow-up phase, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 — this block prints the guidance only), then a role-aware `/compact`|`/clear` suggestion + `/rename <VI-ID>-<slug>-pe`; guidance only, never auto-run.
