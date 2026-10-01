---
name: implement
description: >
  End-to-end code implementation workflow. Classifies task risk, creates a branch, plans (Opus for SIGNIFICANT/HIGH-RISK), implements, writes tests, runs review-tier code review, and performs post-session maintenance.
  Activated when the user prompt starts with "implement:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Implement the following: the argument (text following the `implement:` trigger)

---

## Phase 0 — Load and classify inputs

**Run flags — before anything else in this phase.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. It returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill both `--skip-feedback` and `--enforce-model` apply. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

the argument (text following the `implement:` trigger) may contain free-text prose plus **zero or more `@path` tokens** (today's single-`@file` form is a subset). Resolve each `@path` relative to the current working directory. Classify each `@path` — and the current working directory — **by inspection, not by matching the path string**:

| Detected as | Recognition rule | Handling |
|---|---|---|
| **Spec file** | a single `.md` file | read fully; use as the description/spec |
| **Spec folder** | a directory containing `prompt.md` and/or a `*-design.md` | read all `.md` specs within; fold into the description |
| **Jira ticket folder** | a directory containing a `*-index.md`, or ticket-key subdirectories each containing a `KEY.md` | hand to `jira-reader` in Phase 1.7 |
| **Code repo** | a directory where `git -C <path> rev-parse --is-inside-work-tree` succeeds (includes the cwd) | scan target in Phase 1.7 |

**Jira-input resolution (shared front-end).** Before the per-`@path`
classification above, run `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md`
against the argument (text following the `implement:` trigger). It unifies the input grammar with `document:`: a **JiraID**
token (`^[A-Z][A-Z0-9]+-[0-9]+`) is resolved to its feature folder's `jira-import/`
(Fallbacks A/B on miss); a directory that inspects as a **jira-export** is used as
`jira_export_root`; a **spec-folder** contributes to `specs`; everything else is
`direct` (free-text/`@file`, this command's existing flow). The classification
table above is the directory branch of that front-end — a Jira ticket folder ↔
jira-export, a spec folder ↔ spec-folder, a code repo ↔ an `implement:`-only
target. Carry `mode`, `jira_key`, `jira_export_root`, `focus_key`, and `specs` forward.

**Epic-unit resolution (jira-driven).** `implement:` implements one Epic at a time.
After the front-end resolves, when `mode: jira-driven`:

- **`focus_key` set** (explicit `<VI> <Epic>`, a bare nested `<Epic>`, or chosen in
  the picker below) → proceed for that Epic. The Jira read (Phase 1.7) and specs
  resolution both scope to it.
- **`focus_key` null** → classify the target with a cheap `jira-reader`
  `depth: vi-plus-epics` read on `jira_export_root`, then follow
  `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md` §"Progress-aware Epic
  picker":
  - the item is **itself an Epic** (stand-alone / top-level) → no picker; proceed
    directly (`focus_key` stays null; specs resolve at the item's top-level dir).
  - **VI with exactly 1 Epic** → no picker; set `focus_key` to that Epic and proceed.
  - **VI with ≥2 Epics** → render the picker. `implement:`'s **done-predicate is the
    Epic's Jira status** (`linked_items[].status`): map *done / closed / resolved* →
    ● (greyed, not default-selectable; selecting offers "implement anyway"), *in
    progress / in review* → ◐, anything else → ○; always show the raw status text
    beside each row so a lagging status can't mislead. If the export carries no
    status, degrade to a plain unstatused selection list. Include the explicit choice
    **"Implement one broad VI-level slice instead"** (`focus_key` stays null → specs
    resolve VI-level). Selecting an Epic sets `focus_key` and proceeds for **that Epic
    only** — there is **no "Next Epic?" loop** (code-writing is heavy and branchy;
    each `implement:` run targets one Epic).
  - **VI with 0 Epics** → offer: split with `epics:` first (then re-import), or
    implement one broad VI-level slice (`focus_key` stays null).

When the picker (or the 1-Epic auto-path) sets `focus_key` that was initially null,
**re-resolve `specs`** per the shared reference §Specs-resolution now that `focus_key`
is set — the front-end's first pass resolved `specs` with `focus_key` null, so it must
run again to pick up the Epic's nested per-Epic home.

Rules:
- The **primary description** is: the spec file if one was given → else the spec-folder design doc → else the inline prose. Echo `📄 Reading prompt from <file>…` (or `from inline text`) and confirm `"Loaded prompt (N lines)."`.
- **Design-doc open-question guard.** If the primary description is a **design doc** — a file named
  `design.md` or matching `*-design.md` (the `design:` output; distinct from a `specification.md`) —
  scan it for unresolved `- [ ]` open questions under its `## Open questions` heading. If any exist,
  **refuse to proceed**:
  `choices: ["Cancel — resolve the design's open questions in design: first (Recommended)", "Override and implement anyway (logged in the Phase 5 report)", "Other… (describe)"]`
  A design must be decision-complete before implementation (enforced upstream by `design-reviewer`;
  this is the cross-command backstop). **`specification.md`-level open questions are exempt** — they are
  the spec's way of flagging what the design phase resolves, and a design doc may legitimately
  incorporate a spec that still carries them. "Override" is the only escape and is recorded in the
  Phase 5 report's `### Assumptions & limitations`.
- Multiple inputs of the same kind are allowed.
- A referenced `@dir` that is missing, or is neither a recognized folder type nor a git repo, MUST be surfaced to the user immediately (do not silently skip) — then ask whether to continue without it or stop. This mirrors `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §8.4.
- Note any embedded images as "referenced image: <path>".
- If a single `@file` cannot be read, stop and report the error immediately.
- **Specs are required for jira-driven runs.** When `mode: jira-driven` and the
  front-end resolved `specs: []`, do not plan blind — prompt:
  `choices: ["Point me at a specs directory (you'll provide the path)", "Proceed without specs — not recommended", "Cancel"]`
  "Point me…" takes a path, classifies it as a spec-folder, and re-resolves
  `specs`. "Proceed without specs" is logged in the Phase 5 report's
  `### Assumptions & limitations`. Direct-mode runs (no Jira input) are exempt —
  the prompt/spec file is the instruction.

**Specs-repo preflight.** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
and execute its `specs-preflight` entry point (§3) inline: flush any leftover
session artifacts from an earlier run, retry an artifact commit that failed to
push, and settle the branch. This runs against `$SPECS_PATH` only —
`git -C "$SPECS_PATH"`, never a `cd`, so the code/docs repo this run is working
in is untouched (§1 rule 1). Prompt-free and silent when the specs repo is clean
and on its default branch. If a guard fires, emit its §5 notice; if it returns
`specs_git: blocked` (§3.3 G0), carry that flag for the whole run — the terminal
`commit-artifacts` step skips on it.

**Gate the in-scope specs on `$SPECS_PATH`'s main.** This runs after the cheap `focus_key`-null `jira-reader` classification above — a deliberate, bounded exception to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §5 rule 2's "before its first subagent dispatch", and structurally forced: this gate's `specs` set is derived from `focus_key`, which that dispatch resolves. The exception is bounded to that one read-only Epic-unit classification; every expensive step still follows the gate. (`epics:` records its own §5 rule 2 deviation the same way.) For each resolved `specs` path whose basename is `specification.md` or `design.md` — `implement:`'s **in-scope** spec/design files, the same set Phase 2B and the invariants section reference for the conformance dimension — execute `require-on-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §3) against it, mapping its §3.7 return value by `stopped` first, never by `on_main` alone. Any stopping state → stop per §4.4, naming `$SPECS_PATH` explicitly — `implement:` stands in a **code** repo, so an unqualified stop message would point at the wrong repository. Otherwise (`stopped: false`): `pass`/`pass_amending` → proceed (on `pass_amending`, print §3.3's row-B message — reachable only when an **earlier** `implement:` run's Phase 4.5 handoff created the branch and `specs-repo-git.md` §3.5 B3 kept this run's preflight checkout on it — never this run's own Phase 4.5, which has not executed when this Phase 0 gate runs; `implement:` does not itself author `specification.md`/`design.md`, so a leftover `spec/`/`design/` branch left by an earlier `specify:`/`design:` run is never row B for this gate — it is row C/C′, and the stop/repair path above already covers it). `absent` → **only an in-scope spec is gated at all** — a direct-prompt run resolves none of these `specs` entries and is entirely unaffected, so do not stop; behave exactly as before this feature. `unmanaged` → behave exactly as before this feature. A spec/design supplied directly as a lone `@path` primary description — the Design-doc open-question guard's own input above, a separate mechanism from the `specs` list this gate reads — is **out-of-contract**: read where it sits, deliberately not gated here, the same rule this plan set for `create-vi: <KEY> @<path>`.

---

## Phase 0.5 — Readiness pre-flight (jira-driven only; advisory)

**Jira mode only.** When `mode: direct` this phase is a **no-op** — skip it entirely
(direct-mode runs are byte-identical to before).

When `mode: jira-driven`, read the resolved item's declared Jira status (reuse the
Phase 0 `vi-plus-epics` read if it ran, else a cheap Status-column read of
`<jira_export_root>/<jira_key>-index.md`). Also, if `$SPECS_PATH` is set, check for a
co-located `_readiness.md` in the item's specs dir.

Surface a **one-line, non-blocking** recommendation to run `ready: <VI> [<Epic>]` first when
EITHER: the status is below the readiness bar (VI below **Ready for Implementation**; Epic below
**Refined**), OR a `_readiness.md` records **NOT-SUPPORTED** / **PARTIAL**. This NEVER blocks —
proceed regardless; it is guidance only. If neither condition holds, say nothing and continue.

---

## Phase 1 — Clarification

**Rule: Ask, don't guess. This rule is absolute.**

Before producing a plan, analyze the description for:
- Ambiguous scope or unclear boundaries
- Missing constraints (performance, security, backwards-compatibility)
- Multiple valid implementation approaches
- Undefined integration points or dependencies
- Missing acceptance criteria

If **any** ambiguity exists, ask the user. Rules:
- Use `choices` arrays for every question — never plain text questions
- The **last choice** in every `choices` array MUST be `"Other… (describe)"` to allow free-text
- When a clearly superior default exists, make it the first choice and label it `"(Recommended)"`
- Group related decisions into a single question (minimize total questions)
- Do **not** proceed until all questions are answered

If **nothing** is ambiguous, skip directly to Phase 1.5.

---

## Phase 1.5 — Classify task complexity

Load and follow the model-routing policy at `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then classify the task as exactly one of:

- **SIMPLE** — local, trivial, clearly reversible; no mandatory Opus steps
- **MODERATE** — bounded scope, few files, clear requirements; no mandatory Opus steps
- **SIGNIFICANT** — risky in at least one dimension from the classification reference; Opus planning + review-tier review are mandatory
- **HIGH-RISK** — multiple risky dimensions, or security/migration/compliance scope; Opus planning + review-tier review are mandatory and must be especially thorough

State the classification and the specific criterion that triggered it. When in doubt between MODERATE and SIGNIFICANT, pick SIGNIFICANT.

**Resolve the per-step routing.** Following `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §9, record a `model_routing` block resolving each model against the fallback chains:

```yaml
model_routing:
  classification: <SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK>
  reason: <one-line>
  current_model: <the model this orchestrator is running under>   # = the inline implementation coding
  enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
  defect_model: <§2.2 cheap chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
  detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # jira-reader, code-scanner, Phase 2A exploration, test-writer, test-baseliner, review-fixer
  planning_model: <§2 Opus chain>   # risk-planner (Phase 2B; SIGNIFICANT/HIGH-RISK only; dispatch-pinned to this chain, recorded, no override unless §10 enforces a model)
  review_model:  <§2.3 review tier>    # code-review (Phase 3B; dispatch-pinned to this chain, recorded, no override unless §10 enforces a model)
  implementation_model: <= current_model>   # coding done inline by the orchestrator
  fixes_model: <= detection_model>          # review-fixer (Phase 3B)
  opus_available: <true if a §2 Opus model resolved, else false>
  notes: <any §2 / §2.1 fallback or degradation>
```

Each subagent dispatch below cites its chain (§9 role→chain map); mechanical steps pin `detection_model` via `model:`, and the two dispatch-pinned gates — `risk-planner` on the §2 work tier, `code-review` on the §2.3 review tier — are recorded and not overridden unless §10 enforces a model.

**Detect task shape.** Inspect the description for defect signals (fix / bug / regression / broken / incorrect / wrong output / crash / fails). If bug-shaped, set `task_shape: bug`. `task_shape: bug` only affects the SIGNIFICANT / HIGH-RISK path (Phase 2B/3B); for SIMPLE / MODERATE it is guidance only (no extra question). On the SIGNIFICANT / HIGH-RISK path, if it is genuinely ambiguous whether this is a defect fix or new work, ask with a `choices` prompt (last choice `"Other… (describe)"`).

Then choose the branch:

- **SIMPLE / MODERATE** → continue to Phase 2A (standard planning)
- **SIGNIFICANT / HIGH-RISK** → continue to Phase 2B (Opus-planned)

---

## Phase 1.6 — Input scale assessment

From the Phase 0 classification, compute:
- `repo_count` = number of code repos (cwd + referenced git-repo dirs)
- `has_ticket_folder` = any Jira ticket folder present
- `has_spec_folder` = any spec/design folder present

Set `fan_out = (repo_count > 1) OR has_ticket_folder OR has_spec_folder`.

- **`fan_out = true`** → the input is multi-source. Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §1.1 (the multi-source trigger; see §8 for the fan-out policy) this floors the classification at **SIGNIFICANT** (raise it now if Phase 1.5 chose SIMPLE/MODERATE). Announce: `"Multi-source input detected (<facts>) — flooring at SIGNIFICANT; this is overridable at plan approval."` Then run **Phase 1.7** (fan-out scan) and continue on the SIGNIFICANT/HIGH-RISK branch (Phase 2B).
- **`fan_out = false`** → unchanged behavior; skip Phase 1.7 and proceed to Phase 2A or 2B exactly as the Phase 1.5 classification directs (the single-explorer path).

---

## Phase 1.7 — Multi-source exploration (only when `fan_out = true`)

Runs after Phase 1.6 and replaces the single Phase 2B exploration subagent for multi-source input. Follows `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §8.

1. **Read Jira ticket folders.** For each Jira ticket folder, invoke `jira-reader` (read-only):

   → task(agent_type: "dev-workflows:jira-reader", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "Return the structured handoff for this brief — linked items, PR URLs (identifiers only — no fetching), and capability themes:
     >
     > jira_export_root: [the resolved jira_export_root (from the Phase 0 front-end), or the ticket-folder absolute path]
     > jira_key:         [the resolved <KEY>]
     > depth:            full"

   Run multiple `jira-reader` calls sequentially (it is fast and read-only). Collect the themes and PR references.

   When `focus_key` is set, scope the collected result to the focus Epic's subtree:
   keep the focus Epic plus the items linked beneath it (its Stories / Sub-tasks) and
   drop sibling Epics' subtrees before folding themes/PRs into the plan. `jira-reader`
   itself is not modified — the scoping is done here, mirroring `specify:`.

2. **Read spec/design folders inline.** Read each spec-folder `.md` and fold its content into the themes and primary description.

3. **Fan out `code-scanner` — one per repo, single response, cap 4 concurrent.** Spawn all repo scanners in **one** message (batch in groups of 4 if there are more than 4 repos). For each code repo:

   → task(agent_type: "dev-workflows:code-scanner", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "repo_path: <absolute repo path>
     >  capability_themes: <themes from steps 1–2 + the implementation spec>
     >  context: <3–5 sentences: the implementation goal and what the change must accomplish>
     >  search_hints: <symbols/paths/keywords derived from the spec, if any>
     >  refresh: {switch_to_default_branch: false, pull: false}"

   **`refresh` is pinned false/false, never left to the agent's default.** `code-scanner`'s own declared default is `{switch_to_default_branch: true, pull: true}`, and Phase 0 can classify the current working directory itself as a scan target — an unpinned dispatch would run `git switch <default>` and `git pull --ff-only` in the user's own working repository, mid-run and with no consent step, moving HEAD out from under any committed work in progress before Pre-Phase 3 ever creates this run's branch. Pinning it false also keeps Pre-Phase 3's HEAD-guard branch offer reachable: that guard only fires when HEAD is not already on the default branch, and a scan that moved it there first would make the offer unreachable on the ordinary path.

   Wait for all scanners in the batch to return. A scanner returning `REPO_MISSING` — the path is not a directory — escalates per the `Repo missing (after resolution)` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`; `DIRTY_TREE` escalates per the `Dirty working tree` rule and `REFRESH_BLOCKED` per the `Refresh blocked` rule in the same file. None is ever hidden, and none is merely announced — each offers the user a way forward (§8.4). A scanner returning `prep.read_only: true` is not a failure — it scanned at `prep.scanned_ref`; escalate per the `Read-only mount — ref stale or diverged` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` only when `prep.ref_committed_at` is more than 14 days old or `prep.head_divergence.ahead > 0`, and cite evidence at `prep.scanned_ref`.

   **Round 2 — narrow and seeded (§8.5).** Apply `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §8.5. A theme is **inconclusive** when its round-1 `classification` is `partial`, `absent`, or `error`, or when **two or more** scanners' per-theme `capability_map[].gap_summary` texts point at each other's repo in a cycle, or at a component/subsystem that no scanned repo covers — the shape that yields confident answers which together say nothing. For every inconclusive theme that round 1 left at least one evidence anchor for, dispatch `code-scanner` again on `<detection_model — §2.1 detection chain>` — same `refresh: {switch_to_default_branch: false, pull: false}` as round 1 — with `capability_themes` holding exactly **one** question — the single thing round 1 failed to settle, not the broad theme — and `search_hints.paths`/`.symbols`/`.keywords` seeded from that round's verified `evidence[].path` and `.symbols`; where an evidence entry carries `lines`, name the anchor as `<path>:<line>` in the `context` prose. Cap **4 dispatches, one round only** — there is no round 3. This matters more here than where §8.5 was first adopted: `idea:`'s summary feeds a grill with a human in it, while this one feeds a planner whose output becomes code. **A theme round 1 left with no evidence anchor never enters round 2** — it stays inconclusive with no round-2 attempt possible, and that absence of an attempt is not itself a resolution.

4. **Synthesize.** Combine the `jira-reader` output, all `code-scanner` reports, and the spec into a single **multi-source codebase summary** (per-repo: relevant files, existing capabilities, gaps; plus the cross-repo picture and the Jira themes/PR references). This summary is the codebase context for Phase 2B — do **not** also run the single Explore subagent. Write this summary to a temp file (`command mktemp -t dw-impl-summary-XXXXXX` — **never inside a repo working tree**, so a captured `git diff` never picks it up) and record its absolute path as `summary_file`; Phase 2B receives this path, not the pasted summary. Remove it with `command rm -f -- "<summary_file>"` once Phase 2B has read it and no later phase cites it.

   **Name what the scan did not settle.** The summary carries a `## Unresolved` section listing **every theme still inconclusive at the end of Phase 1.7** — this explicitly includes a theme that never entered round 2 because round 1 left no anchor to seed from, a theme classified `error`, and a mutual-deferral theme, whether or not either scanner logged an anchor. None of these becomes resolved merely by having had no round-2 attempt. Per `model-routing.md` §8.5 Bounds, name **why** each theme is unresolved — mutual deferral / scan error / partial-or-absent with no anchor — and give the repos-and-conclusions detail only where scanners actually disagreed. An inconclusive theme is **never** folded in as an ordinary gap: a gap asserts the capability is absent with no deferral outside the scanned set, an unresolved theme asserts only that the scan could not tell, and once flattened the two are indistinguishable to the planner. Omit the section entirely when nothing is unresolved.

---

## Phase 1.8 — Resolve applicable ARD (Jira mode; optional)

Only when the run resolved a Jira key (VI/Epic) — i.e. NOT direct-prompt mode — resolve any ARD by citing `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/ard-resolution.md` with the resolved `<VI>`, `<EPIC>`, and `$SPECS_PATH`. Direct mode (no Jira key) → treat as `status: none`. On `status: none`, **skip and proceed exactly as before**. On `status: unmerged`, **stop**, naming the returned `branch` and any `pr` and naming `$SPECS_PATH` explicitly (`implement:` stands in a code repo, not the specs repo, so an unqualified message would point at the wrong one) — per `ard-resolution.md`'s Output section, this state is unreachable when no ARD resolves. On `status: found`, carry the `invariants` as **implementation guardrails** (the implementer honors each `AD#N` `rule`; a necessary deviation is logged as an `- ARD deviation:` line in the Phase 5 report), and — in the SIGNIFICANT / HIGH-RISK path — pass them to `code-review` (Phase 3B) as `applicable_ard`. In the SIMPLE / MODERATE path there is no `code-review` gate, so the guardrails act as guidance only.

---

## Phase 2A — Standard Plan (SIMPLE / MODERATE only)

**Codebase exploration** — Before writing the plan, spawn an exploration subagent to map the relevant parts of the codebase:

→ task(agent_type: "general-purpose", tools: view/glob/grep only — no bash, no edit, model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
  "Given this implementation description: [paste the full implementation description from Phase 0 or Phase 1 here], find and return:
   - Relevant source files and their primary responsibility
   - Existing patterns and conventions used in this codebase
   - Test file locations and test naming conventions
   - Naming conventions (class names, method names, file names)
   Return a structured summary — no code changes, no file edits."

**Wait for the agent's response before proceeding. If the agent returns no relevant files or fails, proceed with the plan using your own file reads to gather context. Do not begin writing the plan until the file map is returned or you have gathered context yourself.**

→ Use the returned file map as codebase context when writing the plan below.

Produce a written implementation plan:

1. **Classification** — `SIMPLE` or `MODERATE` (with reason)
2. **Goal** — one-sentence summary of what will be built
3. **Approach** — chosen strategy and why
4. **Steps** — numbered, concrete implementation steps
5. **Files to create/modify** — list with brief rationale
6. **Tests** — what tests will be added or run
7. **Assumptions** — decisions made without user input (must be minimal)
8. **Out of scope** — explicitly list what is NOT being done

Then ask:
```
"Implementation plan ready. What would you like to do?"
choices: ["Approve & implement now (Recommended)", "Revise plan", "Cancel"]
```

- **Approve** → write the approved plan to a temp file (`command mktemp -t dw-impl-plan-XXXXXX`, never inside a repo tree) and record its absolute path as `plan_file`; proceed to Phase 3A
- **Revise** → ask what to change, update, re-show, re-ask
- **Cancel** → stop and summarize what was planned

---

## Phase 2B — Opus-planned (SIGNIFICANT / HIGH-RISK)

**Codebase exploration** — If Phase 1.7 ran (`fan_out = true`), use its **multi-source codebase summary** (already written to `summary_file` in Phase 1.7 step 4) as the codebase context and skip the single Explore subagent. Otherwise, run the same exploration subagent call as Phase 2A (same prompt, same fallback rule), then write the Explore agent's returned output to a temp file (`command mktemp -t dw-impl-summary-XXXXXX`, never inside a repo tree) recorded as `summary_file`. Either way, `summary_file` holds an absolute path before the planner is dispatched.

Once the file map is returned, delegate planning to Opus.

When a `specification.md`/`design.md` is in scope, extract its **in-scope** `[Uxx]`/`[ACxx]`/`[TCxx]` IDs (reuse the specs resolved in Phase 0) into `in_scope_ids` for the review dispatch below. When `task_shape: bug`, the plan will lead with a repro step and a ranked-hypotheses section — surface them in the normal plan-approval gate (no extra interrupt) **when the ranking is present**. When the planner instead returns `Ranking withheld — no red-capable repro`, the withheld-repro branch below fires first and the normal gate does not run.

→ task(agent_type: "dev-workflows:risk-planner"):  # planning_model — §2 Opus chain; dispatch-pinned to this chain, recorded in model_routing, no override added unless §10 enforces a model
  > "Produce the risk-weighted plan for the following brief:
  >
  > Task description: [substitute full description]
  > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [the criterion from Phase 1.5, or the multi-source floor from Phase 1.6 when fan_out]
  > Codebase summary: read it from the file at [the `summary_file` absolute path]
  > Constraints: [any from clarification, plus runtime/version/deadline known]
  > Current state: branch = [git branch], uncommitted = [git status --short summary]
  > Specs in scope: [the resolved specification.md/design.md path(s) from Phase 0, or "none"]
  > Unresolved scan themes: [the summary's `## Unresolved` entries, or "none"] — each is a theme the scan could not settle, NOT a confirmed gap; carry every one into the plan's risks and never plan as though its location is known
  > task_shape: [bug | omit]"

**Wait for the risk-planner to return.** Its output is one of:

1. A full plan in the risk-weighted format (the normal case).
2. A short `### Re-classification` section, if the planner decided on inspection that the task is actually `SIMPLE` or `MODERATE`.

**If the return contains `### Re-classification`:** surface it to the user, ask for confirmation of the revised level with a `choices` prompt (`["Accept revised classification (Recommended)", "Override and stay SIGNIFICANT/HIGH-RISK", "Cancel"]`). If the user accepts, **fall back to Phase 2A** (standard plan) using the codebase context already captured above (the `summary_file` path) — the Phase 1.7 **multi-source codebase summary** when `fan_out = true`, otherwise the Explore summary — and do not re-run exploration. Accepting here is the user exercising the **plan-approval override** of the multi-source SIGNIFICANT floor (Phase 1.6); that is the sanctioned way to leave the fan_out floor. If the user overrides, re-invoke risk-planner with an additional constraint stating the classification is intentional; do not down-classify again. If the user cancels, stop and summarize.

**If the return is a full plan whose `### Hypotheses (ranked)` section contains `Ranking withheld`:**
the planner could not get a red-capable repro, so its hypotheses are absent by design and the rest of
the plan rests on unverified theory. Do NOT fall through to the normal approval gate — its Recommended
option is "Approve & implement now", which is exactly the proceed-on-a-guess outcome
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/bug-diagnosis.md` step 1 forbids. Surface the planner's `Tried:` line
verbatim and ask:

```
choices: ["Help construct a repro (you'll be prompted for what to try)", "Proceed without a repro (recorded in the Phase 5 report)", "Cancel"]
```

- **Help construct a repro** → take the user's suggestion, re-dispatch `risk-planner` with it carried in the brief, and re-enter this branch on the new return.
- **Proceed without a repro** → record it in the Phase 5 report's `### Assumptions & limitations` as `No repro: <what the planner tried>` and continue to the normal full-plan gate below.
- **Cancel** → stop.

**If the return is a full plan** (ranking present, or the user chose to proceed without a repro)**:** present it to the user verbatim and ask:

```
"Opus-planned. What would you like to do?"
choices: ["Approve & implement now (Recommended)", "Revise plan", "Cancel"]
```

- **Approve** → write the approved plan to a temp file (`command mktemp -t dw-impl-plan-XXXXXX`, never inside a repo tree) and record its absolute path as `plan_file`; proceed to Phase 3B
- **Revise** → ask what to change, then re-invoke risk-planner with the **complete** brief plus the additional constraint merged in (never send just a delta — the planner refuses to plan without a full brief). Re-show, re-ask.
- **Cancel** → stop and summarize

---

## Pre-Phase 3 — Create feature branch

Before writing any file:

1. **Clean-tree check** — Run `git status --porcelain`. If the output is non-empty:
   - Show the user what is dirty (paste the `git status --short` output).
   - Ask:
     ```
     choices: ["Stash changes and continue (Recommended)", "Proceed anyway — pre-existing changes will appear in the diff and review outputs", "Cancel"]
     ```
   - **Stash**: run `git stash push -m "pre-impl stash"`, then continue. Record the resulting stash as `stash_ref` — Phase 4.6 names it in its outcome line, and never drops it (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.2 carve-out 2).
   - **Proceed**: note in the Phase 5 report that the working tree was dirty at implementation start, **and record the `git status --porcelain -z --untracked-files=all` paths as `pre_existing_dirty`**. `-z` is required, not optional: without it, git quotes and octal-escapes a path carrying a space, a `"`, a `\`, or a non-ASCII byte, and the resulting mismatch against the raw current porcelain set breaks the subtraction `code-repo-handoff.md` §2.2 carve-out 1 relies on.

   A clean tree records `pre_existing_dirty: null` and `stash_ref: null` — the state Phase 4.6's precondition assumes. Phase 4.6 needs them to avoid sweeping somebody else's uncommitted work into this run's commit (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.2 carve-out 1); a run that does not record them here cannot honour that carve-out later.
   - **Cancel**: stop and summarize what was planned.

2. **Resolve the branch name** per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md` — **the repo's own documented convention wins**. Read the target repo's `CONTRIBUTING.md`, `CONTRIBUTION.md`, `README.md`, `DOCUMENTATION-GUIDELINES.md`, `.github/copilot-instructions.md` (+ `.github/`) for a branch-naming section (§1.1); if one is found, classify its segments (§1.2) and fill them: an **identity** placeholder (`<your-name-or-initials>`, `<user>`, …) from the §2 ladder (`$GIT_USER_INITIALS` → `git config user.initials` → inference from existing branches → the §2.5 prompt), an **issue-key** segment from the `jira_key` resolved in Phase 0 (or the pattern's documented no-issue literal in direct mode), and the **description** segment from step 3's slug. A pattern with no identity segment gets none — never inject initials into a convention that does not ask for one. Only when the repo documents no convention (§1.4) build `<prefix>/<slug>` with `<prefix>` from the §2 ladder, whose fallback here is `feat/`.

3. **Generate slug** — derive from the implementation description: lowercase, hyphens, max 40 chars, strip punctuation and special chars. Example: "Add user authentication to login page" → `add-user-authentication-login-page`. When a `jira_key` is resolved and the chosen shape has no separate issue-key segment, prefix it: `<jira_key>-<slug>`.

4. **Check HEAD context** — resolve `<base>`, the default branch's name, by `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.8, with `<repo>` the repository this phase branches. It is the ladder Phase 4.6 resolves the pull request's base with, so the branch this run cuts from is the base its pull request targets. Never judge by a list of names: in a repository whose default is `main`, a local `develop` is a branch like any other, and the commits it carries are what this step asks about.
   - **§2.8's ladder is exhausted** — no `origin`, or an unset `origin/HEAD` and none of the branches it probes → there is no base to measure against or to branch from, so ask nothing: print `Base branch unresolved (<reason>) — branching from the current position.`, carry that line into the Phase 5 report's `### Branch` section, and go to step 5.
   - **HEAD is on `<base>`** — `git branch --show-current` prints `<base>` → nothing to check; go to step 5.
   - **HEAD is not on `<base>`** — it prints another name, or nothing on a detached HEAD → list the commits HEAD carries that the base does not: `git log origin/<base>..HEAD --oneline`, or `git log <base>..HEAD --oneline` where `origin/<base>` does not exist (`git rev-parse --verify --quiet origin/<base> >/dev/null` fails). Non-empty output → ask the question below. Empty output with exit 0 → HEAD carries nothing the base lacks; go to step 5. **A non-zero exit is a failed read, never "no ahead commits"** — keep its error rather than redirecting it away, show it, and ask the question below anyway, saying beside it that the ahead commits could not be read.

   The question names `<base>` beside it and lists the commits the read returned, or its error:
   ```
   choices: ["Branch from current position — continue on this work (Recommended)", "Branch from default branch — fresh start", "Cancel"]
   ```
   - **Branch from current position** → step 5 cuts the branch from HEAD.
   - **Branch from default branch** → `git switch <base>` and nothing more — no fetch and no pull, as at `vuln:` Step 3's switch onto the same base. It takes the name, which `git switch` accepts where it refuses an `origin/<name>` ref, and it creates a local `<base>` from `origin/<base>` where none exists. Step 5 then cuts from `<base>`. Where git refuses the switch — an uncommitted change it would overwrite — report its error and the paths it named, and stop as Cancel does: no branch exists yet, and step 5 must not cut one from the HEAD the user just declined.
   - **Cancel** → stop and summarize what was planned.

5. **Create and checkout** — `git checkout -b <prefix>/<slug>`. If that name already exists, append the first 7 chars of HEAD's SHA: `<prefix>/<slug>-<short-sha>`.

---

## Pre-Phase 3.5 — Capture test baseline

Placed **after** branch creation (Pre-Phase 3), **before** any file edits. The `.5` numbering signals "inserted between step 3 and step 4 of the existing ordering" — it is its own phase, not a sub-step of Pre-Phase 3's branch-creation steps.

Invoke the `test-baseliner` agent in capture mode:

→ task(agent_type: "dev-workflows:test-baseliner", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Run the agent in the following mode:
  >
  > Mode: capture
  > Project root: [absolute path of the current working directory]"

Store the returned `## Test Baseline` block verbatim — it will be passed to `test-baseliner` again in verify mode at Phase 3.5 and to `test-writer` as the baseline snapshot. On a repository with more than one test suite the agent baselines **all** of them and the block's `### Suites` section names each; store it whole, unsummarized, since the verify call pairs against those rows.

**Act on the block's `Status` here, before a single file is edited.** This is the last point in the run where the answer can still be honest: a capture is a baseline because nothing has changed yet, and a capture taken after the edits is just a test run.

- `OK` / `NO_TESTS` → continue.
- `PARTIAL` → continue, and record every suite `### Suites` does not mark `OK` or `NO_TESTS`, with the command that failed, in the Phase 5 `### Deferred items` section — this run's verification will not cover them and the Final Report says so. A suite whose runner is not installed is not a reason to stop work on the suites that do run. **Surface the block's `### Notes` lines here as well, and carry what they say about a deferred suite into that suite's entry.** A watch carve-out the capture declined lands the run in this arm wherever its own suite produced no counts and some other suite did — the `RUN_FAILED` arm below is where it lands when none did — and a suite left unmarked because its watcher ran to the per-suite bound is not a suite whose runner failed, though the `Status` and the `### Suites` rows alone cannot tell the two apart (`dev-workflows:test-baseliner` capture step 1). Naming the reason is what keeps the Final Report from reporting a runner failure this run never saw.
- `COMMAND_NOT_FOUND` (`Framework: not detected`) or `RUN_FAILED` → nothing was captured at all. **Surface the block's `### Notes` lines and its `### Suites` rows before asking** — the Phase 3.5 arm handling these same two values already does that for `### Suites`, and `### Notes` is where capture reports a watch carve-out it could not fire: which script it was, and what in it could not be resolved or rebuilt (`dev-workflows:test-baseliner` capture step 1). From the `Status` and the rows alone that state is indistinguishable from a suite that genuinely failed, and it is the state in which *Specify test command to use* has an answer to give — the runner's own single-run command, which the note has just named the script for. The section reads `none` where there is nothing to say, so on every other cause this costs one line. Then ask the user:
  ```
  choices: ["Specify test command to use", "Skip tests for this run (documented in the Phase 5 report's Deferred items)", "Cancel"]
  ```
  - **Specify test command** → take free-text, record it as `test_command_hint`, and re-dispatch the capture above **immediately**, adding the line `command_hint: [the answer]` to the prompt. Act on the returned block's `Status` by this same list. Ask at most twice in a run; after that record `test_decision: skip` with the last failure as its reason, **marked as the run's own record rather than the operator's answer**. The two provenances are not the same decision and Phase 4.6 reads which one this is: here the operator asked twice for a working command and never agreed to skip, so the run finishes `clean_finish: false` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.9), where the *"Skip tests"* answer below finishes `true`.
  - **Skip tests** → take free-text rationale; record `test_decision: skip` with that rationale in the Phase 5 `### Deferred items` section.
  - **Cancel** → stop and summarize.

**Every `### Notes` line the block opens with `CAVEAT: ` is surfaced here, and recorded in the Phase 5 `### Deferred items` section where the run reaches one, whatever the `Status` was** — `OK` and `NO_TESTS` included, which is the one arm above that carries no obligation of its own and is an arm three of the five marked kinds can arrive on (`dev-workflows:test-baseliner` capture step 5). A marked line says the baseline is not what its own numbers claim: a qualifying suite nothing ran because the candidate containing it does not recurse over it, counts a `Make` indirection may have summed twice, or an identifier list a `Make` fold leaves unattributed to what printed it — none of which the `Status` or the `### Suites` rows state. **The mark is the agent's and is not re-judged here**, and it is also the whole of the test: an unmarked note records where a command ran, and surfacing those on every run is how an operator learns to skip the section. The `PARTIAL` and `RUN_FAILED` / `COMMAND_NOT_FOUND` arms above still surface the **whole** section, marked lines included — more than this rule asks, and not narrowed by it.

**Where `test_command_hint` was recorded, every later `test-baseliner` dispatch in this run carries it** — verify compares like with like only when both calls run the same set of suites.

---

## Phase 3A — Implementation (SIMPLE / MODERATE)

**Implement immediately. Do NOT ask "Should I implement?" or any variation.**

1. Work through each step in order
2. Make precise, surgical changes — do not modify unrelated code
3. Follow existing code style and LF line endings
4. Assume broad permissions; avoid unnecessary stops
5. If a **new ambiguity** emerges mid-implementation: STOP, ask with choices (last: `"Other… (describe)"`), resume after answer
6. **Run Phase 3.5 below** (test writing + regression verification) — do NOT run tests directly here; Phase 3.5 owns the lint/build/test sequence and the fix loop
7. Verify the outcome matches the approved plan
8. Proceed to Phase 4 (post-implementation maintenance).

---

## Phase 3.5 — Write and verify tests (SIMPLE / MODERATE)

Runs after Phase 3A step 5 completes (all code changes written), before the outcome-verification step.

1. **Invoke `test-writer` agent.** First, at the orchestrator, capture the diff for the dispatch: write `git add -N . && git diff` (so new files are included) to a temp file (`command mktemp -t dw-impl-diff-XXXXXX`, never inside a repo tree) and record its absolute path as `test_diff_file`. `test-writer` has no shell tool — it can only `view` the path it is given. Then spawn:

   → task(agent_type: "dev-workflows:test-writer", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "Write tests for this brief:
     >
     > Task description: [substitute full description]
     > Plan: read it from the file at [the `plan_file` path recorded at Phase 2A approval]
     > Diff: read it from the file at [the `test_diff_file` path]
     > Project root: [absolute path]
     > Baseline: [paste the ## Test Baseline block captured in Pre-Phase 3.5]"

2. **Handle a `test-writer` stop.** Check the report's first line before anything else. If it is `Diff: unreadable at <path>`, the orchestrator's own `test_diff_file` could not be read — this is an orchestrator bug, not a user choice: surface the unreadable path to the user and **stop the run**; do not offer to skip tests (skipping would silently proceed past evidence that could not be read). Otherwise, **where Pre-Phase 3.5 recorded a `test_decision`, apply it** rather than asking again — that question was put to the user before any file was edited. On `skip`, run step 3 (linters and builds) and skip **steps 4–6**, then proceed to Phase 3A step 7 (Verify outcome). **The skip is scoped to the tests because that is what was asked**: Pre-Phase 3.5's option reads *"Skip tests for this run"*, and the lint and build gate is neither a test nor something a missing baseline prevents — a run that skips it commits code that was never compiled, which nobody consented to. There is no second prompt here, and a command supplied here would not help: a capture taken after the edits is a test run, not a baseline. **The gate is the recorded decision, not the report's `Framework` field**: `Framework: not detected` is emitted only where the capture was `COMMAND_NOT_FOUND`, while the other capture that asked — `RUN_FAILED` — names the runner it could not run, so `test-writer` writes against it and reading the field alone would drop the recorded skip and re-prompt at step 5.

3. **Run linters and builds.** Use the project's standard lint/build commands as discovered in Phase 2A exploration. Do not run the full test suite here — that is step 4.

4. **Invoke `test-baseliner` in verify mode** against the baseline captured in Pre-Phase 3.5:

   → task(agent_type: "dev-workflows:test-baseliner", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "Run the agent in the following mode:
     >
     > Mode: verify
     > Baseline: [paste the captured ## Test Baseline block]
     > Project root: [the same absolute path Pre-Phase 3.5's capture sent, and never a different one — `### Suites` records each marker as a path relative to this root, so a verify rooted anywhere else reads every marker as moved and, where a framework names more than one detected suite, every identifier of it as missing (`dev-workflows:test-baseliner` capture step 1, measured there)]
     > command_hint: [the recorded `test_command_hint` — include this line only where Pre-Phase 3.5 recorded one, and never a different value: a verify run over a different set of suites is not a comparison]"

5. **Act on the verify report.** **A non-empty `### New failures` list sends the run to the fix loop whatever the `Status` says.** A test this run's own `test-writer` just wrote has never been in any baseline list, so when it fails it is a **New failure** and nothing else — and `New failures` is not a `Status` value, so `OK` and `PARTIAL` are both reachable with one standing (`dev-workflows:test-baseliner` verify step 6). Branching on the `Status` alone reports a pass on the run's own broken test. **The list and the `Status` are read together, not one instead of the other**: work the `Status` arm below first, so its own record is written, and let the list decide where the run goes next. Every value is handled here, none is passed over. **And every `### Notes` line the report opens with `CAVEAT: ` is surfaced and recorded in the Phase 5 `### Deferred items` section whatever the `Status` says** — the same obligation Pre-Phase 3.5 carries over its own capture and for the same reason: a marked line is a note whose harm neither the `Status` nor this report's identifier lists show, and verify marks three of its own beside every one capture step 1's detection owed (`dev-workflows:test-baseliner` verify step 7). **On `REGRESSIONS`, read them before step 6 rather than after it**: two of verify's own three put baseline identifiers into `### Missing from run` without that being evidence this change removed them — a pairing nothing could resolve, and a `command_hint` that narrowed the run — and the fix loop would otherwise spend both its attempts chasing them.
   - `OK` → the `Status` itself leaves nothing to do, **though the lead-in's `CAVEAT: ` obligation still holds here and this is the arm on which it earns its keep**: nothing else in a green report puts a marked line into the run's record, and one of them is a suite that aborted without losing a baseline test — an abort this value is defined to tolerate. With `### New failures` empty, Phase 3.5 is done; with it non-empty, step 6 takes the run.
   - `PARTIAL` → no regressions, and a suite could not be run at either end. Record each such suite from `### Suites` in the Phase 5 `### Deferred items` section — **that record is this arm's own obligation and is made either way**, since step 6 records regressions and new failures and nothing about `### Suites`. **Read the report's `### Notes` beside those rows and carry what they say about a suite into its entry** — the same obligation Pre-Phase 3.5's own `PARTIAL` arm carries, and for the same reason: verify mode's `### Notes` carries capture step 1's detection notes as well as this call's aborts and pairing facts (`dev-workflows:test-baseliner` verify step 7), so a suite the watch carve-out never reached is recorded as that rather than as a runner that could not run. Then, with `### New failures` empty, there is nothing to fix and Phase 3.5 is done; with it non-empty, step 6 takes the run.
   - `RUN_FAILED` or `COMMAND_NOT_FOUND` → **nothing was compared, so neither is a pass.** They differ only in how far the call got: `RUN_FAILED` means no detected suite paired with the baseline (**`Comparison status: invalid`** — verify step 2), or none produced counts (**`best-effort`**, not `invalid`: "none produced counts" means every suite aborted, and verify step 3 sets `best-effort` on the first abort with nothing resetting it, so quote the field the report actually carries rather than this arm's other half's); `COMMAND_NOT_FOUND` means **this run's** detection selected no suite at all (`invalid` as well — verify step 1), which after a baseline that named one says the edits removed its marker — a renamed `pom.xml`, a deleted `Makefile`. Neither is settled by anything Pre-Phase 3.5 recorded, and a run whose baseline named no framework never reaches this step. Surface the report's `Reason` line **where it carries one** — verify step 2's `invalid` return does, step 6's `RUN_FAILED` does not, and `Reason` is no field of the return structure — and the `### Suites` rows and the `### Notes` lines either way, the notes being where a watch carve-out that did not fire is named, which is what *Investigate further* would otherwise have to rediscover, then ask:
     ```
     choices: ["Investigate further", "Accept an unverified run and proceed (document in Phase 5 report)", "Cancel"]
     ```
     **Investigate further** → diagnose manually and re-run step 4 when ready. **Accept** → record in the Phase 5 `### Deferred items` section that no comparison was made, with whatever the report gave as its reason, and set `clean_finish: false` for Phase 4.6. **Cancel** → stop and summarize.
   - `REGRESSIONS` → read the lead-in's `CAVEAT: ` lines first, since two of the kinds verify marks say these identifiers are in `### Missing from run` for something other than this change, then the fix loop below.

6. **Fix loop** — on `Status: REGRESSIONS`, or on a non-empty `### New failures` list under any `Status`:
   - The **session model** (not a subagent) applies fixes. No `review-fixer`-style indirection is used here — the scope is narrow and the context is already fully in-session. Use the `test-baseliner` verify report as the authoritative list of what broke.
   - After each fix attempt, re-capture the diff (`git add -N . && git diff`) and re-run `test-baseliner` in verify mode against the **original** baseline (never re-baseline mid-loop — a mid-loop re-baseline would silently absorb a regression as the new normal).
   - Cap at **2 fix attempts**. If any regression or new failure remains after the second attempt, surface to the user:
     ```
     choices: ["Investigate further", "Accept the remaining failures and proceed (document in Phase 5 report)", "Cancel"]
     ```
     - **Investigate further** → stop the automated loop; the session model diagnoses manually and re-runs verify when ready.
     - **Accept the remaining failures** → record each regression and each new failure in the Phase 5 `### Deferred items` section with the user's rationale; proceed.
     - **Cancel** → stop and summarize.

Once Phase 3.5 returns (passed, skipped, or accepted with failures kept or without a comparison), return to Phase 3A step 7 (Verify outcome).

---

## Phase 3B — Implementation + review-tier review (SIGNIFICANT / HIGH-RISK)

Use the currently selected model or Sonnet for implementation itself. Opus is reserved for the review.

For a long step list, apply `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/context-management.md` — checkpoint at N,
offload parallel-safe (`[P]`) steps to subagents, or decompose — so the run does not degrade as context fills.

At each checkpoint, also consider suggesting **`/compact`** to free context before the next scope/Epic (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §3 — mid-command → `/compact` only, never `/clear`; guidance only).

1. Work through each step in order
2. Make precise, surgical changes — do not modify unrelated code
3. Follow existing code style and LF line endings
4. If a **new ambiguity** emerges mid-implementation: STOP, ask with choices (last: `"Other… (describe)"`), resume after answer
4a. **Invoke `test-writer` agent** (inserted before the review diff capture in step 5 so the review-tier review sees code and tests together — test adequacy is already a review dimension in `code-review.md`). First, at the orchestrator, capture the diff for the dispatch: write `git add -N . && git diff` (so new files are included) to a temp file (`command mktemp -t dw-impl-diff-XXXXXX`, never inside a repo tree) and record its absolute path as `test_diff_file`. `test-writer` has no shell tool — it can only `view` the path it is given. Then spawn:

   → task(agent_type: "dev-workflows:test-writer", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "Write tests for this brief:
     >
     > Task description: [substitute full description]
     > Plan: read it from the file at [the `plan_file` path]
     > Diff: read it from the file at [the `test_diff_file` path]
     > Project root: [absolute path]
     > Baseline: [paste the ## Test Baseline block captured in Pre-Phase 3.5]"

   Check the `test-writer` report's first line before invoking review-tier review. If it is `Diff: unreadable at <path>`, the orchestrator's own `test_diff_file` could not be read — this is an orchestrator bug, not a user choice: surface the unreadable path to the user and **stop the run**; do not invoke review-tier review. Otherwise, where Pre-Phase 3.5 recorded a `test_decision`, apply it and carry it into the Phase 5 report (mirrors the SIMPLE/MODERATE branch, gate included — the recorded decision, never the report's `Framework` field). On `skip`, step 8 below runs **only step 3 of the Phase 3.5 sequence — the lint and build — and none of steps 4–6**, exactly as the SIMPLE/MODERATE branch scopes it, and for the same reason: what was declined — or, on the run's own record, given up on — was the tests and not the build. There is no prompt here — asking after the edits would be asking for a baseline that can no longer be taken.

5. After all changes are written: **DO NOT run tests yet.** When `task_shape: bug`, first **strip every `[DEBUG-xxxx]` probe** added during diagnosis (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/bug-diagnosis.md`); the review diff must contain no debug instrumentation. Capture the diff and the project root. Use `git add -N . && git diff` — this includes intent-to-add untracked new files so the diff is never empty for implementations that only create new files, and it now also includes the test files from step 4a. Write this diff to a temp file (`command mktemp -t dw-impl-diff-XXXXXX`, never inside a repo tree) and record its absolute path as `review_diff_file`; the code-review dispatch (step 6) receives this path. Also capture `git diff --stat` for the summary (small — kept inline).
6. **review-tier code review** — spawn.

   → task(agent_type: "dev-workflows:code-review"):  # review_model — §2.3 review tier; dispatch-pinned to this chain, recorded in model_routing, no override added unless §10 enforces a model
     > "Produce the review-tier code review for this brief:
     >
     > Task description: [substitute full description]
     > Classification: [SIGNIFICANT | HIGH-RISK] — reason: [from Phase 1.5]
     > Plan: read it from the file at [the `plan_file` path]
     > Diff: read it from the file at [the `review_diff_file` path from step 5]
     > Project root: [absolute path]
     > applicable_ard: [the ARD invariants from Phase 1.8, or omit if none / direct mode]
     > applicable_spec: [ { spec_paths: [...], in_scope_ids: [...] } when a spec/design is in scope, else omit ]
     > claims_file: [the `claims_file` path — pass it only when a `review-fixer` Fix Report exists for this run; omit otherwise]"

7. Act on the return:

   **Check the review's first line before acting on the verdict.** If it is `Diff: unreadable at <path>`, the orchestrator's own `review_diff_file` could not be read — an orchestrator bug, not a user choice: surface the unreadable path to the user and stop the run. Do NOT triage the finding and do NOT dispatch `review-fixer`: the finding names a capture failure no fixer can act on, and running the cycle would spend a fix dispatch and a re-review to arrive back here.
   - **`### Re-classification` section** — the reviewer decided the change is actually `SIMPLE` or `MODERATE` on inspection. Surface it to the user and ask `choices: ["Accept revised classification (Recommended)", "Override and keep the BLOCK-gated review", "Cancel"]`. If accepted, treat the review as an implicit PASS: skip the BLOCK branch, proceed to step 8, and do NOT re-invoke the reviewer on later fix deltas. Record the revised classification for the Phase 5 report. If overridden, re-invoke code-review with an explicit note that the classification is intentional.
   - **BLOCK** — invoke the review-fixer agent (see Review-fixer sub-step below). If `Stop condition flag` is `CLEAR`, re-run the review-tier code review on the updated diff (one re-review only). If `Stop condition flag` is `NEEDS HUMAN`, do not re-review: surface the deferred BLOCKER(s) to the user with the reason `review-fixer` gave and stop. If the second verdict is still BLOCK, stop: surface the remaining blockers to the user, exactly as the `NEEDS HUMAN` stop above does. **This stop offers no arms, and the reason is worth stating so that one is not added back.** It is in Phase 4.6's `"Every run"` list, so by the time it presents anything the implementation is **already committed** on its own branch with `clean_finish: false` — and `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §1 rule 3 forbids every operation an *"abandon and restore to pre-impl state"* arm would need on that commit (`reset`, `checkout --`, `branch -D`, `--amend`). Such an arm was offered here and was unfollowable: no file defined what it did, and the one phase that could have undone it is the phase that had just made it durable. What replaces it is a report the user can act on themselves — nothing was merged and the base branch was never touched, so abandoning the work is `git switch <base>` in their own hands, and Phase 4.6's outcome line has already named the branch, the sha, the outstanding `stash_ref` where Pre-Phase 3 pushed one, and, where §2.4's choice allowed one, the draft pull request whose DO-NOT-MERGE banner says not to merge it. State those beside the blockers. Do not run tests until the verdict is not BLOCK.
   - **PASS WITH RECOMMENDATIONS** — invoke the review-fixer agent for MAJOR findings (see Review-fixer sub-step below). MINOR / NIT findings may be deferred — note them in the Phase 5 report.
   - **PASS** — proceed.

   **Triage sub-step** (before any fixer dispatch): follow `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md`. For each finding, verify its claimed consequence at the location it names; keep or dismiss; record every dismissal with a reason that disposes of that finding's own claim. Hand the fixer **survivors only**, and carry the dismissal list into this run's report.

   **Review-fixer sub-step** (for BLOCK and PASS WITH RECOMMENDATIONS): first write the **triaged survivor list** from the sub-step above — the surviving findings only, each with its severity, location, observation, and suggestion — to a temp file (`command mktemp -t dw-impl-review-XXXXXX`, never inside a repo tree) and record its path as `review_file`. Dismissed findings NEVER enter that file; they go to the `### Review triage` report section instead.

   → task(agent_type: "dev-workflows:review-fixer", model: `<fixes_model — = detection_model, §2.1 detection chain; under §10, run_flags.enforced_model>`):
     > "Fix the review findings for this brief:
     >
     > Task description: [substitute full description]
     > Review output: read it from the file at [the `review_file` path]
     > Project root: [absolute path]
     > Severities to fix: BLOCKER and MAJOR"

   Wait for the fix report. Re-capture the diff after the fixer completes, **overwriting `review_diff_file`** (write a fresh `git add -N . && git diff` to that same path) — so the one re-review at step 7 reads the post-fix diff, not the stale step-5 capture. Also write the fixer's full Fix Report to a temp file (`command mktemp -t dw-impl-claims-XXXXXX`, never inside a repo tree) and record its path as `claims_file` — the one re-review reads it as the deferred claims input, so the reviewer checks the fixer's account of its own work instead of assuming it.

   - If the fix report contains any `DEFERRED — plan-conflict` finding, surface it to the user **immediately** (do not wait for the BLOCK-still-BLOCK path): show the finding beside the plan text it contradicts and ask `choices: ["Revise the plan (the finding governs)", "Apply the fix against the plan (the plan governs — logged in Phase 5)", "Other… (describe)"]`. Act on the answer before re-running the review.

7.5. **Spec/design conformance escalation.** For each unresolved `missing`/`contradicts` in-scope requirement from the code-review Spec/design-conformance dimension, write a `- [ ]` note back onto the source `specification.md`/`design.md` under an `## Engineering review` heading (the same escalation `design:` uses; annotate only — never mutate existing `[Uxx]`/`[ACxx]`/`[TCxx]` IDs). Never silently drop them, never invent new Jira work. Record which of `specification.md`/`design.md` actually received a note — the handoff step needs to know whether only one, or both, were annotated. The notes are written here and handed off later — see the escalation handoff after Phase 4.
8. **Run Phase 3.5 (post-review).** After the review gate clears (non-BLOCK verdict), run the Phase 3.5 sequence (lint/build, `test-baseliner` verify, fix loop) — **not before**. This preserves the invariant "NEVER run tests for SIGNIFICANT / HIGH-RISK before review-tier review returns non-BLOCK". The fix loop inside Phase 3.5 applies fixes via the session model; if the fixes are non-trivial **and** the reviewer was NOT down-classified in step 7, re-invoke the review-tier code review on the delta after Phase 3.5 completes (first overwrite `review_diff_file` with a fresh `git add -N . && git diff` so the re-review reads the post-Phase-3.5 diff). If the reviewer WAS down-classified, skip the re-review.
9. Verify the outcome matches the approved plan and the review verdict.
10. Proceed to Phase 4.

---

## Phase 4 — Post-implementation maintenance (both branches)

First gather the actual change context:

a. Run `git diff --stat` (or equivalent) and capture the list of changed files with line counts.
b. Compose a **change summary block**:

```
Implementation: [one-sentence description of what was built]
Change type: code
Classification: [SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK]
Files changed (from git diff --stat):
<paste the git diff --stat output>
Notable additions/removals: [new commands, APIs, config keys, dependencies — one line each; or "none"]
Review-tier review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK — or "N/A (SIMPLE / MODERATE)"]
```

Then spawn all four agents. They are independent and can run in any order — spawn them all before waiting for any to complete:

**Agent 1 — Documentation** (general-purpose):
> "Post-implementation documentation review. Change summary:
> [paste change summary block]
>
> Scan for README.md, CHANGELOG.md, docs/, or any .md files in the project root or a docs/ directory.
> Determine if documentation needs updating:
> - Skip if: purely a bug fix, vulnerability fix, internal refactor, or test-only change
> - Update if: new feature, changed behavior, new commands/APIs/config options, altered usage patterns
> Use the file list above to reason precisely about what changed. If an update is warranted: apply minimal edits to the relevant section(s).
> Return: file updated and what changed, OR 'no update required (reason)'."

**Agent 2 — Knowledge base** (general-purpose):
> "Post-implementation knowledge review. Change summary:
> [paste change summary block]
>
> Check ~/.copilot/memory/ (global) and .copilot/memory/ (project-level, preferred for repo-specific knowledge) for existing knowledge files.
> Determine if a new knowledge entry is warranted — look for: reusable insights or patterns, non-obvious constraints or gotchas, anti-patterns discovered, clarified trade-offs.
> If YES: append to the most appropriate existing file (never create a new file if an existing one fits) using this format:
> ### [Short title]
> - **Context**: what problem/situation triggered this
> - **Insight**: the learned rule, pattern, or gotcha
> - **When it applies**: conditions under which this matters
> - **Date**: YYYY-MM-DD
> - **Ref**: [first 60 chars of implementation description]
> Return: file updated/created and summary of entry, OR 'no update required'."

**Agent 3 — Instructions** (general-purpose):
> "Post-implementation instructions review. Change summary:
> [paste change summary block]
>
> Check .github/copilot-instructions.md in the project root and ~/.copilot/copilot-instructions.md (global).
> Determine if any rules, guidance, or guardrails are missing because of what this implementation revealed.
> Skip if: the implementation followed existing patterns with no surprises, required no novel constraints, and introduced no anti-patterns. Only update if a concrete, recurring rule would have prevented a decision point or misunderstanding during this implementation.
> If YES: apply minimal, additive, scoped changes only — do not rewrite sections wholesale.
> Return: what was changed and why, OR 'no update required'."

**Agent 4 — Session maintenance** (dev-workflows:impl-maintenance):

**Under `--skip-feedback`** (`run_flags.skip_feedback`, `_shared/run-flags.md` §4), this step dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance` — the same compact handoff, plus `Plugin root:` — on `run_flags.enforced_model` when set, else the `_shared/model-routing.md` §2.2 cheap chain. Only when it returns at least one defect, persist them through `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, `feedback-emission.md` is not read at all. Report `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`. The in-session Lessons Learned report is what the flag costs. `emit-block` is unaffected and fires exactly as it would without the flag.
> "Analyse this session and return a Lessons Learned report.
>
> Session handoff:
> - Command run: implement:
> - What was done: [one-paragraph summary of the implementation]
> - Key events: [BLOCK reviews encountered and their reason, test regressions, workarounds, unexpected ambiguities — or 'none']
> - Workarounds used: [manual steps not automated by the workflow — or 'none']
> - Review verdict: [PASS | PASS WITH RECOMMENDATIONS | BLOCK | N/A]
> - Test result: [passed N tests, N regressions, not run — or actual result]
> - Project root: [absolute path]"

Collect all four summaries for the Phase 5 report.

**Persist plugin feedback (automatic).** After Agent 4 (`impl-maintenance`)
returns, project its plugin-facing slice into the specs repo by citing
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and calling its
`emit-auto` entry point (§6). Pass Agent 4's Lessons Learned report,
`command: implement:`, the run's `jira_key` and `source`, and `plugin_version`
(read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). `emit-auto`
renders only the report's **Command workflow improvements**, **New agents /
skills**, and plugin **Reference docs** sections plus the **Key observations**
that triggered them (§4 plugin-facing predicate) — never target-project
`copilot-instructions.md`/hook advice — as `origin: auto` entries, dedupes by stable `id`
(§3), resolves the target via the §2 specs-first ladder, and writes silently.
List the persisted path (or "no plugin-facing signal — nothing persisted") in
the Phase 5 `### Session learnings` line. ADDITIVE — the impl-maintenance report
still appears in the report; this step NEVER fails the run, NEVER commits (still
true — this step only writes the feedback file; those writes are committed by
the terminal `commit-artifacts` step in Phase 6, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4), and NEVER writes into the code repo or the current working directory.

---

## Phase 4.5 — Escalation handoff (spec/design conformance notes)

A **silent no-op** when step 7.5 (Phase 3B) wrote no `- [ ]` notes — which covers every SIMPLE/MODERATE run (no `code-review`, so step 7.5 never runs) and every run with no spec/design in scope, direct-prompt or otherwise.

When step 7.5 did write one or more notes: `prefix` = `spec` when only `specification.md` was annotated, otherwise `design`; `feature_folder` = the directory the annotated file(s) live in (the same specs-repo folder Phase 0 resolved them from); `deliverable_paths` = the annotated file(s) themselves. Present the `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §4.3 array this run's set selects (§4.0's strongest-class rule), verbatim, after that section's push-target probe. Where `specification.md` is among the annotated files — **gated — stopping**:

`choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase will stop until this is on main)", "Cancel"]`

Where `design.md` alone was annotated — **gated — falling back**:

`choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase does not stop on this, but until this is on main it might not read your copy)", "Cancel"]`

On the first choice, execute `handoff-to-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2) with `prefix`, `feature_folder`, and `deliverable_paths` as above; `title: <KEY> Record spec/design conformance findings from implement:`; and `body_facts` = the count of escalated `- [ ]` notes, the code-review Spec/design-conformance dimension summary they came from, and the fact that whoever next reads this `specification.md`/`design.md` will not see them until this pull request is merged. Emit its §4.1 outcome line in the Phase 5 `### Spec/design conformance` section.

Placement is deliberate, not stylistic: step 7.5 sits inside Phase 3B, before the tests run, so calling `handoff-to-main` there would commit mid-review — hence the notes are written in 7.5 and handed off here instead, after Phase 4's post-implementation maintenance and before Phase 6's follow-ups, `resume.md`, and terminal `commit-artifacts` steps. A call from inside Phase 6 would falsify Phase 6's never-commits-the-deliverable claim below.

---

## Phase 4.6 — Code-repo handoff (commit, push, PR)

Runs on **every** run that created a branch in Pre-Phase 3 — both classification branches, Jira mode and direct-prompt mode alike. Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` and execute its `finish-code-branch` entry point (§2) inline.

Placement is load-bearing. Phase 4's Agents 1–3 edit files **inside the code repo** — `README.md`, `CHANGELOG.md`, `docs/`, `.github/copilot-instructions.md`, and any project-level memory file — so a call placed before Phase 4 would commit a partial run and leave the maintenance edits behind (`code-repo-handoff.md` §4 obligation 1). Phase 4.5 runs first because it commits a *different* repository (`$SPECS_PATH`), and interleaving the two would make the run's two outcome lines impossible to attribute.

**"Every run" includes every early stop.** This command has exits that stop *after* Pre-Phase 3 created the branch and after files were written: the two unreadable-`test_diff_file` stops (Phase 3.5 step 2, Phase 3B step 4a), the Cancel arms of the framework and repro prompts and of both Phase 3.5 prompts (step 5's unverified-run prompt and step 6's regression prompt), the unreadable-`review_diff_file` stop (Phase 3B step 6), the `review-fixer` `NEEDS HUMAN` stop, and a second verdict still `BLOCK`. **Each of those runs Phase 4.6 before it stops**, with `clean_finish: false` and the stop's reason as the blocking fact. Skipping it would leave a written, branched, sometimes fully-reviewed implementation uncommitted — which this command's own invariants call a defect, and which is the case where losing the work costs most. Phase 4 is skipped on these paths (its maintenance agents have nothing to summarise for an aborted run), so 4.6's "after every in-repo write" precondition is satisfied trivially. Report the §3.1 line with the stop, not in a Phase 5 report that will not be produced.

The one exit that does **not** reach Phase 4.6 is the "Abandon implementation and restore to pre-impl state" arm, whose entire purpose is to discard the work; say so explicitly when taking it.

Placement is load-bearing. Phase 4's Agents 1–3 edit files **inside the code repo** — `README.md`, `CHANGELOG.md`, `docs/`, `CLAUDE.md`, and any project-level `.claude/memory/` entry — so a call placed before Phase 4 would commit a partial run and leave the maintenance edits behind (`code-repo-handoff.md` §4 obligation 1). Phase 4.5 runs first because it commits a *different* repository (`$SPECS_PATH`), and interleaving the two would make the run's two outcome lines impossible to attribute.

Pass the §2.11 inputs:

- `repo` — the repo Pre-Phase 3 branched; `branch` — the name it created (or the `-<short-sha>` variant it fell back to).
- `pre_existing_dirty` and `stash_ref` — as recorded in Pre-Phase 3 step 1; both `null` on the clean-tree path.
- `title` — the commit subject and pull-request title. With a `jira_key`: `<KEY> <one-line summary of what was built>`; direct mode: the imperative summary alone.
- `body_facts` — what was implemented; the files changed; the review-tier review verdict and triage summary where Phase 3B produced one; the `test-baseliner` verify result against the Pre-Phase 3.5 baseline; and any deferred `MINOR`/`NIT` findings.
- `clean_finish` — `false` when the review-tier review is still `BLOCK` after its one fix cycle plus re-review, when the Phase 3.5 fix loop ended with failures the user chose to keep — regressions or new failures —, when the user accepted an **unverified** run at Phase 3.5 step 5 (`RUN_FAILED` / `COMMAND_NOT_FOUND` — nothing was compared), or when Pre-Phase 3.5's `test_decision: skip` is **the run's own record** rather than the operator's answer (the two-failed-`command_hint` path); `true` otherwise. The third is the same state `upgrade:` and `vuln:` set `false` on as `TESTS_NOT_RUN`. **The last is a provenance test, not a token test**, and §2.9 says why: the operator's own *"Skip tests for this run"* is a typed decision taken up front and is honoured without penalty, while the run's own record after two failed hints is that bullet's "attempted and could not complete, and proceeded on anyway" with nobody's consent attached. Pass the provenance, never the bare `test_decision` value. Per §2.9 this changes only the pull request (draft, with a DO-NOT-MERGE banner) — never whether the commit and push happen.
- `commit_template: null` — `implement:` documents no template of its own, so §2.3 derives the subject from the repo's own `git log`.

Emit the §3.1 `Code repo:` outcome line in the Phase 5 report's `### Branch` section — once, and verbatim. Once it is emitted, remove this run's now-unread temp files — `command rm -f -- "<summary_file>" "<plan_file>" "<test_diff_file>" "<review_diff_file>"` — for whichever of those the run actually created and no stop message above still cites.

**A run that wrote into a repo it never branched.** A multi-source run (Phase 1.7) may edit a repo other than the one Pre-Phase 3 branched. This step has no branch there to commit onto, so it does not invent one: list those repos and their dirty paths in the Phase 5 report under `### Branch`, explicitly flagged as uncommitted. Never leave them unmentioned — an unreported dirty repo is exactly the loss this phase exists to prevent.

---

## Phase 5 — Final Report

Output a structured report — do NOT ask any closing confirmation:

```
## Implementation Report

### Classification
[SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK] — [reason]
[Under `run_flags.enforced_model`: `Model routing: bypassed — enforced <id> (flag|env)` — every dispatched step (planner, reviewer, fixer, test agents, scanners) already carries the enforced id in place of its own chain, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §10. The `model_routing` block's `opus_available` is unaffected by enforcement (§10: a property of the environment, never rewritten to agree with the enforced id) and, wherever this report states it, is stated exactly as it stands. Omit the line otherwise.]

### Branch
[branch name created in Pre-Phase 3, e.g. feat/add-user-authentication]
[Pre-Phase 3 step 4's `Base branch unresolved …` line, verbatim, when it printed one; omit the line otherwise]
[the Phase 4.6 `Code repo:` outcome line, verbatim (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §3.1)]
[any repo this run wrote into but never branched — path + dirty paths, flagged uncommitted; omit the line when there is none]

### What was implemented
[High-level summary]

### Files changed
- path/to/file.ext — [what changed]

### Review-tier review (if applicable; on the enforced id under §10)
[Verdict and 1-line summary — naming the enforced id it ran on wherever `run_flags.enforced_model` is set (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §10) — or "N/A (SIMPLE / MODERATE)"]

### Review triage
- **Review triage:** [N findings reviewed, M survived] — dismissals: [one line per dismissal, `finding — reason`; or "none"] — or "N/A (SIMPLE / MODERATE, no review-tier review)"

### Spec/design conformance (if a spec/design was in scope)
[coverage summary from code-review's dimension; list any missing/partial/contradicts — or "N/A"; if Phase 4.5 escalated notes, add the `Phase handoff:` outcome line from `handoff-to-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §4.1)]

### Commands / tests run
- [command] → [result]

### Knowledge base
- [file updated/created] — [summary of entry] OR "no update required"

### Instructions
- [summary of change] OR "no update required"

### Documentation
- [file updated] — [what was added/changed] OR "no update required (bug fix / no user-facing change)" OR "no documentation files found"

### Session learnings
- [top suggestions from impl-maintenance agent, or "no suggestions — routine session"]

### Assumptions & limitations
- [list any]

### Deferred items (from review or tests)
[every line below that has content; "none" only where all of them are empty. Seven instructions in this file write test records here and the heading admits every one of them — they land in the six test bullets below, the two `CAVEAT: ` instructions (Pre-Phase 3.5's over its capture and Phase 3.5 step 5's over its verify) sharing one, and a template naming only the review half is how those records get dropped; this section is the run's only account of what it did not verify. Phase 6 deliberately does **not** turn these into follow-ups, on the ground that they are in-scope work already carried by this task — which holds only if they are written down here.]
- [MINOR / NIT review findings that were not applied; omit the line where there are none]
- [each suite the Pre-Phase 3.5 capture left unmarked `OK`/`NO_TESTS`, with the command that failed and whatever that block's `### Notes` said about it (Pre-Phase 3.5's `PARTIAL` arm); omit where none]
- [the recorded `test_decision: skip` — the operator's rationale, or, on the run's own record, the capture failure that produced it (Pre-Phase 3.5); omit where none]
- [each suite the Phase 3.5 verify could not run at either end, with whatever that report's `### Notes` said about it (step 5's `PARTIAL` arm); omit where none]
- [an accepted unverified run, with whatever the report gave as its reason (step 5's `RUN_FAILED` / `COMMAND_NOT_FOUND` arm); omit where none]
- [each kept regression and each kept new failure, with the user's rationale (step 6's Accept arm); omit where none]
- [each `CAVEAT: ` line the Pre-Phase 3.5 capture block or a Phase 3.5 verify report carried, verbatim and with which of the two carried it — written whatever those returns' `Status` values were, `OK` and `NO_TESTS` included, since a marked line is exactly the kind of note a return that reports nothing wrong can still carry; omit where neither carried one]

### Next step
[Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md` — guidance only, never auto-invoked. Jira mode: finish the remaining Epics under the VI (breadth) — `implement: <VI> <another-Epic>` — and, once **all** Epics are implemented, `document: <VI>` then `release-notes: <VI>` (both VI-level, run once). Depth vs breadth is the team's call. Direct mode: no forward pipeline step (omit). If review is still BLOCK, resolve that first.]

### Context hygiene

*(Jira mode only — omit this whole block in direct-prompt mode, like the `### Next step` above.)*
The resume pointer is written in the terminal follow-up phase (Phase 6), per `session-hygiene.md` §1. Then:

- **More Epics to build (`implement: <VI> <Epic2>`) or on to `document: <VI>` — same build lane?** → run **`/compact`** — context stays relevant.
- Consider **`/rename <VI-ID>-<slug>-dev`** to relocate this session later.

Guidance only — see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`.
```

---

## Phase 6 — Emit follow-up tasks

Terminal phase — runs AFTER the Phase 5 Final Report is composed; NEVER
interrupts an earlier phase. Persist the run's out-of-scope / manual-step
follow-ups by citing `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/followup-emission.md`
and executing its steps inline.

1. **Collect** the qualifying follow-ups: manual publish/config steps and
   out-of-scope maintenance items surfaced in the Phase 5 `### Session
   learnings` section (e.g. an impl-maintenance suggestion that touches
   another repo or team, or a manual post-merge step). **Do NOT** collect the
   report's `### Deferred items (from review or tests)` or skipped tests — §6
   explicitly excludes those as in-scope work already carried by the current
   task.
2. **Filter** them with the reference's §6 qualifying predicate.
3. **Resolve** the write target via the §4 ladder using `jira_key` and `source`
   (jira-driven runs carry a key; direct-prompt runs usually do not, so tasks
   land in `Tasks.md # Irregular` when the vault is writable, else report-only);
   render + place tasks and verbose notes per §1–§3; dedupe per §5.
4. **Preview + confirm** per §7 (`approve-all | select | cancel`), then write.

ADDITIVE — the follow-ups also remain in the Phase 5 report. This phase NEVER
fails the run, NEVER commits (still true — this phase only writes follow-up
files; those writes are committed by the terminal `commit-artifacts` step at the
end of this phase, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4), and NEVER writes into the code repo or the current working directory.

**Then write the resume pointer (Jira mode only).** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`
§1 and write/overwrite `<VI-dir>/dev-workflows/resume.md` now — after the
follow-up entries above, so the pointer reflects the completed run, and before
the commit step below, so it is included in it. Redact per §1. Silent; the
printed `### Context hygiene` guidance already appeared in the Phase 5 report.
Direct-prompt mode writes none (§1 skip list — no VI anchor).

**Then commit session artifacts (terminal).** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
and execute its `commit-artifacts` entry point (§4) inline — the LAST action of
the run. It stages ONLY the §2.1 bounded artifact paths inside `$SPECS_PATH`,
commits `<KEY> Add dev-workflows session artifacts (implement:)`, and pushes
per §4 step 5. It NEVER writes into the code repo this run just changed — that
repo's own commit, push, and pull request were Phase 4.6's, through a different
reference and against a different remote —
NEVER touches a docs repo, the vault, or the current working directory; NEVER
force-pushes; NEVER fails the run; and skips entirely when the run carries
`specs_git: blocked` (§3.3 G0), re-emitting that notice. Because the Phase 5
report was composed before this phase, **print its §6 outcome line here**, as
the run's last output — prefixed `Specs repo:`, with any guard notice repeated
in full.

ADDITIVE — this phase NEVER fails the run, NEVER commits the deliverable (the terminal step above commits only the bounded session-artifact paths in `$SPECS_PATH`; the implementation itself was committed in Phase 4.6, in the code repo, and pushed there where §2.4's consent choice, an `origin` and §2.5's push itself all allowed it — §3.1's rows are the authority on which line the run emitted — via `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2; the spec/design conformance notes from step 7.5 are handed off separately, also before this phase, via `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2), and NEVER writes into the code repo or the current working directory; no user name is ever written.

---

## Invariants (always enforced)

- ALWAYS `emit-block` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) before escalating a halt caused by a **plugin / skill / command / reference gap** (a capability the run needed but the plugin lacked) — so a run abandoned at the block still records it. NEVER for a work-quality review BLOCK or an environment / user halt (repo-missing, dirty-tree, jira-not-found, cancellation)
- NEVER skip Phase 1.5 classification — every run must state the level
- NEVER use Opus for routine implementation, unless §10 enforces a model (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §10 — every dispatched step then runs on `run_flags.enforced_model`, whatever it is); otherwise reserve it for planning + review on SIGNIFICANT / HIGH-RISK
- NEVER run tests on SIGNIFICANT / HIGH-RISK work before the review-tier code review returns a non-BLOCK verdict
- NEVER skip Phase 3.5 — where the Pre-Phase 3.5 capture returns `COMMAND_NOT_FOUND` (no framework detected) or `RUN_FAILED` (every suite the capture actually ran aborted with no parseable counts — *run*, not *detected*, since a `command_hint` can narrow one set against the other, and a suite that ran to completion printing unrecognised output never failed to start), ask the user there, where a baseline can still be taken, rather than silently skipping; a "Skip" decision must be explicit and logged in the Phase 5 report, and it drops steps 4–6 only — step 3's lint and build still run
- NEVER dispatch a `test-baseliner` verify without the `command_hint` its capture was taken with — a verify over a different command is not a comparison
- NEVER read `OK` or `PARTIAL` as a pass while the report's `### New failures` list is non-empty — a test this run wrote and that fails now is in neither baseline list, so it moves no `Status` at all; Phase 3.5 step 5 reads the list **beside** the `Status` rather than instead of it (the `PARTIAL` arm's `### Deferred items` record is still owed either way), and a non-empty list then sends the run into step 6's fix loop
- NEVER read a verify report as a pass on any value but `OK` or `PARTIAL` — `RUN_FAILED` means nothing was compared and `COMMAND_NOT_FOUND` means nothing was run, and each is surfaced (Phase 3.5 step 5), never passed over
- NEVER make assumptions that could have been asked — ask instead
- NEVER end implementation with "Should I implement?" — if approved, implement
- NEVER rewrite files wholesale when only an append/edit is needed
- NEVER skip Phase 4 — documentation, knowledge, instructions, and session-maintenance are mandatory after every successful impl; always collect all four agent summaries for Phase 5
- ALWAYS capture a test baseline (Pre-Phase 3.5) before writing any file
- ALWAYS create a feature branch (Pre-Phase 3) before writing any file — never implement directly on the default branch
- ALWAYS check for a clean working tree before branching; stash or get explicit user consent if dirty — and record `stash_ref` / `pre_existing_dirty` for Phase 4.6, which cannot honour `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.2's carve-outs without them
- ALWAYS run Phase 4.6 (`finish-code-branch`, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md`) after Phase 4 and before the Phase 5 report — the commit is prompt-free (§1 rule 5) and the push + pull request sit behind §2.4's choice; a run that ends with the implementation uncommitted is a defect, not a style
- NEVER commit the implementation before Phase 4 — Phase 4's Agents 1–3 write into the same repo, and a commit ahead of them ships a partial run
- ALWAYS spawn Phase 4 agents in a single message — never sequentially
- ALWAYS use `choices` arrays for decision points; last choice is always `"Other… (describe)"`
- ALWAYS produce the Phase 5 report as the final output
- ALWAYS end the Phase 5 report with a `### Next step` recommendation (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md`) — guidance only, never auto-invoked; omitted in direct mode (no VI/Epic pipeline context)
- ALWAYS pass `Command run: implement:` in the Phase 4 Agent 4 session handoff
- ALWAYS pass `Change type: code` in the Phase 4 change summary block (scopes the four maintenance agents' suggestions to code-change territory — docs / Jira variants use `docs`)
- AFTER one review-fixer pass + one re-review, if verdict is still BLOCK: stop and surface to user — do NOT loop
- ALWAYS state, with the recorded review verdict, which version it was taken against — where any edit followed it (a review-fixer pass, a manual fix, a Phase 3.5 regression fix), the Phase 5 report says so and names the edits, per the `A recorded verdict names the version it was taken against` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`; where none did, it says that too
- AFTER two Phase 3.5 fix-loop attempts, if regressions remain: stop and surface to user — do NOT loop
- NEVER read a verify report as a pass on any value but `OK` — `RUN_FAILED` means nothing was compared and `COMMAND_NOT_FOUND` means nothing was run, and each is surfaced (Phase 3.5 step 5), never passed over
- ALWAYS classify each `@path` input by inspection (Phase 0) — never by matching the path string
- WHEN `fan_out` is true (multi-repo or any directory input): floor classification at SIGNIFICANT (overridable at plan approval), run Phase 1.7, and feed its synthesized summary to the planner instead of the single Explore subagent
- WHEN `fan_out` is true and a theme stays inconclusive: run round 2 (§8.5) when round 1 left an evidence anchor to seed it, and name every still-unresolved theme — including one that never entered round 2 for lack of an anchor — in the summary's `## Unresolved` section and the risk-planner brief's `Unresolved scan themes:` field; NEVER fold it in as an ordinary gap
- WHEN a `specification.md`/`design.md` is in scope on a SIGNIFICANT / HIGH-RISK run: extract its in-scope IDs, pass `applicable_spec` to `code-review`, report conformance in Phase 5, and escalate unresolved `missing`/`contradicts` as `- [ ]` notes on the spec/design — never silently
- WHEN `task_shape: bug` on a SIGNIFICANT / HIGH-RISK run: risk-planner follows `bug-diagnosis.md` (repro-first + ranked hypotheses), and all `[DEBUG-xxxx]` instrumentation is stripped before the Opus-review diff is captured
- WHEN `task_shape: bug`: the ranked hypotheses MUST be backed by a repro `risk-planner` **actually ran** — its `### Hypotheses (ranked)` block carries the command, its redacted output, and the reproduction rate (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/bug-diagnosis.md` step 1's completion criterion). If it returns "Ranking withheld — no red-capable repro", do NOT proceed to implementation on a guess: surface what it tried and ask `choices: ["Help construct a repro (you'll be prompted for what to try)", "Proceed without a repro (recorded in the Phase 5 report)", "Cancel"]`. Proceeding is the user's call to make explicitly, never the default.
- ALWAYS fan out `code-scanner` one-per-repo in a single response, capped at 4 concurrent — never sequentially
- NEVER silently skip a referenced `@dir` that is missing or unrecognized — surface it and ask (~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md §8.4)
- Scanning agents (`jira-reader`, `code-scanner`) are pinned to the §2.1 detection (Sonnet) chain like every mechanical step (never inherit the session model); escalate a single scanner to Opus only when one repo slice is oversized
- ALWAYS end the Phase 5 report with a `### Context hygiene` block per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` — prepare-first (the `resume.md` write runs later, in the terminal follow-up phase, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 — this block prints the guidance only), then a same-lane `/compact` suggestion + `/rename <VI-ID>-<slug>-dev`; **omitted in direct mode** (no VI/Epic context, no `resume.md`); the Phase 3B checkpoint additionally suggests `/compact` mid-run. Guidance only, never auto-run.
- ALWAYS run `specs-preflight` at Phase 0 and `commit-artifacts` as the run's last action (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`) — bounded to `$SPECS_PATH`'s artifact paths (§2.1) and to plugin-created branches (§2.2), always `git -C "$SPECS_PATH"` and never a `cd` (§1 rule 1), never force-pushing, and never failing the run
