# Copilot Instructions — ihudak-copilot-plugins

This repository is a private GitHub Copilot plugin marketplace. Each subdirectory is a self-contained plugin installable via:

```
copilot plugin install <plugin-name>@ihudak-copilot-plugins
```

The marketplace is registered in `~/.copilot/settings.json` under `extraKnownMarketplaces`:
```json
"ihudak-copilot-plugins": { "source": { "source": "github", "repo": "ihudak/ihudak-copilot-plugins" } }
```

## Repository structure

```
ihudak-copilot-plugins/
└── <plugin-name>/
    ├── .plugin/plugin.json     ← plugin manifest (required; this exact path)
    ├── LICENSE
    ├── README.md
    ├── agents/                 ← Copilot custom agents (one .md per agent)
    │   └── <agent-name>.md     ← dispatched via task(agent_type: "<plugin>:<agent-name>")
    ├── hooks/                  ← lifecycle hooks (Stop, UserPromptSubmit, PostToolUse)
    │   ├── hooks.json          ← registration; use ${PLUGIN_ROOT} for paths
    │   └── *.sh                ← hook scripts, each must exit 0
    ├── skills/
    │   ├── _shared/            ← cross-skill reference docs (not a skill itself)
    │   └── <skill-name>/
    │       └── SKILL.md        ← orchestrator skill (user-facing, keyword trigger, e.g. `implement:`)
    └── docs/                   ← human-facing docs tree (index, per-skill, reference pages)
```

**Hooks note.** Copilot CLI runs plugin hooks but does **not** support Claude Code's `matcher` field, so every `PostToolUse` hook fires on *every* tool use. Each script must therefore return fast and exit 0 for invocations it does not care about — `test-notify.sh` returns unless the command is a test runner, `changelog-owners-reminder.sh` unless the edited file is a docs content page. Hook scripts must never block the agent.

## Plugin manifest format

`.plugin/plugin.json` is the canonical Copilot CLI manifest. The `skills` field is a **directory path**, not an array. The `agents` field (optional, plugin-level) is also a directory path:

```json
{
  "name": "plugin-name",
  "description": "...",
  "version": "1.0.0",
  "author": { "name": "...", "url": "..." },
  "homepage": "...",
  "repository": "https://github.com/ihudak/ihudak-copilot-plugins",
  "license": "MIT",
  "keywords": [...],
  "skills": "./skills/",
  "agents": "./agents/"
}
```

Do **not** put `plugin.json` under `.github/plugin/` — that path is not read by the Copilot CLI.

## SKILL.md vs agent .md — when to use which

**Skills** are user-facing keyword triggers (e.g. `implement:`, activated when the user prompt starts with that string — never a slash command in this edition). They run in the
main session context with the user's selected model. They MUST have `allowed-tools:` in
YAML frontmatter.

**Agents** are sub-routines dispatched via `task(agent_type: "<plugin>:<name>", ...)`.
They run in their own context window, inherit the orchestrator's model by default,
and can have a `model:` override via the `task` tool. They go in `agents/<name>.md` and
require `name`, `description`, and `tools` in YAML frontmatter (no `allowed-tools:`).

### Orchestrator skill (user-facing)
```yaml
---
name: skill-name
description: >
  Activated when the user prompt starts with "keyword:".
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---
```

### Custom agent (dispatched via task tool)
```yaml
---
name: agent-name
description: "Receives <X> and returns <Y>. Invoked by <orchestrator> via task tool."
tools: [view, grep, glob, bash]
---
```

> Earlier versions of this marketplace defined sub-agents as skills (no `allowed-tools:`).
> That worked only by accident — Copilot CLI's `task` tool's `agent_type` enum does not
> accept skill names. Since `dev-workflows 1.4.0` and `dt-style-guide 0.3.0`, all
> sub-agents live in `agents/` and are dispatched as `agent_type: "<plugin>:<name>"`.

## Path references in skill files

All cross-skill references must use the **installed-plugins absolute path**:

```
~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/...
```

Never use `~/.copilot/skills/...` — that path is for user-level skills not managed by this plugin.

When adding a new skill that references shared content, always reference via the full installed path, e.g.:
```
~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md
```

## The `_shared/` directory

`skills/_shared/model-routing.md` is the **single source of truth** for:
- Task complexity classification (`SIMPLE` / `MODERATE` / `SIGNIFICANT` / `HIGH-RISK`)
- Model fallback chain (Opus 5 → GPT-5.6 → Opus 4.8 → 4.7 → 4.6 → GPT-5.5 → Opus 4.5 → Sonnet 5 → Sonnet 4.6 → Sonnet 4.5 → GPT-5.4 → Gemini 3.1 Pro Preview); Opus 5/4.8/4.7/4.6 + GPT-5.6/5.5 are co-equal strong-tier peers, the rest are further fallbacks
- The 8-dimension mandatory Opus code-review checklist
- The `model_routing` YAML block format passed between orchestrators and sub-agents
- The `phase: verify-resume` protocol for gating tests on Opus review

All fourteen pipeline orchestrators (`implement:`, `vuln:`, `upgrade:`, `document:`, `epics:`, `release-notes:`, `docs-profile:`, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `ready:`) must load and follow `model-routing.md` at the start of every invocation. Standalone review orchestrators (`api-guideline-reviewer:`, `guideline-reviewer:`) and the utility surfaces (`feedback:`, `prompt:`, `prompt-brainstorm:`, `prompt-grill-me:`) are exempt — they do not classify complexity or route models. Sub-agents receive the `model_routing` block in their prompt; they do not re-read the file.

`skills/_shared/release-note-types.md` is the **single source of truth** for the release-note **destination map** (`breaking-changes.md` / `feature-updates.md` / `fixes.md`), the per-destination **draft shape** (label + title + prose, vs one bare sentence for `fixes`), the per-destination prose rules, the deprecation-note rule (end-of-life date required, end-of-support optional), and Change Type sourcing (import → infer). It is consulted by `release-notes-writer`; `release-notes:` cites it for its own invariants but never re-derives the writer's decision. The Change Type is never rendered as text.

`skills/_shared/bug-diagnosis.md` is the **single source of truth** for the bug-diagnosis discipline consulted by the `implement:` skill (Phase 2B) and followed by `risk-planner` when a task is bug-shaped (`task_shape: bug`): feedback-loop-first (a red-capable, deterministic repro before hypothesizing), 3–5 ranked falsifiable hypotheses, `[DEBUG-xxxx]`-tagged instrumentation with a mandatory cleanup gate (stripped before the Opus-review diff), and a regression test at a correct seam. It cross-references `skills/_shared/design-format.md` `## Seams` and is paired with `implement:`'s spec/design-conformance ("converge") check — `code-review`'s conditional 10th dimension that traces in-scope `[Uxx]`/`[ACxx]`/`[TCxx]` against the shipped diff.

`skills/_shared/gate-ledger.md` is the **single source of truth** for verification-gate accounting — the six outcomes (`RAN` / `DEGRADED` / `FAILED` / `UNAVAILABLE` / `SKIPPED_BY_USER` / `NOT_APPLICABLE`), the rule that **no outcome is orchestrator-assignable to mean "I decided not to run this"**, the `document:` gate registry (now seven gates, including `image_review` for Phase 5.6's always-running image step), the `UNAVAILABLE` conversion prompt, and the reviewer contract. Consumed by `document:` (both modes), plus `doc-reviewer` and `docs-style-checker`, which read the ledger it produces; written generically for other skills to adopt.

`skills/_shared/repo-verification-gates.md` is the **single source of truth** for extracting a docs repo's own pre-PR checklist into the `repo_verification_gates` block — the heading patterns, what counts as checkable against the written files, and the augment-never-override rule. Applied by `doc-planner` in `document:` Jira mode and by the orchestrator itself in direct mode, which has no planner.

`skills/_shared/toolchain-preflight.md` is the **single source of truth** for the Phase 0 environment check — deriving the required tool set from the resolved profile, the repo's config signals, and the repo's own documented `Prerequisites`; the `toolchain` block with its tool→gate map; and the missing-tool prompt (Cancel recommended, silence when everything resolves). Consumed by `document:` (both modes).

`skills/_shared/doc-structure-conventions.md` is the **single source of truth** for how a written page is structured and what it may contain — the traceability boundary (a rendered page carries no source provenance; the Jira key lives in the commit message, per-claim attribution lives in the run handoff), callout scope and adjacency (a callout sits with the option it qualifies, never trailing the whole set — a scope violation is a `doc-reviewer` MAJOR), and component-pattern fidelity (reuse the docs area's established content component for a recurring shape instead of an ad-hoc structure — divergence is MINOR). Consumed by `document:` and `epics:`, and by `doc-planner`, `doc-writer`, and `doc-reviewer`.

`skills/_shared/dynatrace-docs/anchor-conventions.md` is the **single source of truth** for heading-anchor mechanics on dynatrace-docs pages — one `{:#id}` per heading (multi-anchor unsupported), the four verified internal-link forms, the `pnpm docstack validate-anchors` contract, and the rule that a product `dt-url` deep link's anchor wins reconciliation. Consumed by `doc-writer`, `doc-reviewer`, and `doc-planner`.

`skills/_shared/specs-repo-git.md` is the **single source of truth** for the two specs-repo git entry points shared by all seventeen skills that write into `$SPECS_PATH`: `specs-preflight` (run start — flush leftover artifacts, retry an unpushed artifact commit, settle the branch) and `commit-artifacts` (terminal — stage the bounded artifact paths, commit, push). Owns the bounded write authority (two path shapes; `^(idea|vi|ard|spec|design|ready)/` branches only — the six-prefix authority), the three preflight guards and their four-part notice contract, the branch-disposition table, and the `Specs repo:` outcome line. Always `git -C "$SPECS_PATH"`, never a `cd`; never force-pushes; never fails the run. Deliverable handoff — a different concern, committing the phase's own authored artifact rather than plugin bookkeeping — is owned by `skills/_shared/phase-handoff.md`, not this file.

`skills/_shared/code-repo-handoff.md` is the **single source of truth** for the **code** repo's own git finish — the `finish-code-branch` entry point (§2): gate (§2.1), staging with its three carve-outs (§2.2), commit (§2.3), the consent choice asked once per run via `ask_user` (§2.4), push (§2.5), the `gh` capability probe and its fallback (§2.6), the base-branch ladder (§2.8), the not-clean-finish draft-PR rule (§2.9), and the split-call form a per-unit loop uses (§2.12). Its one structural divergence from `phase-handoff.md` is §1 rule 5: **the commit is prompt-free**, because there the deliverable is already safe on disk and here the work is not safe until it is committed — so only the push and the pull request sit behind consent. Consumed by the three skills that branch a code repo and write into it: `implement:` (Phase 4.6), `vuln:` (Step 3.9, once per CVE), and `upgrade:` (step 6.5 commit per component + step 7.5 push/PR once per batch). It never touches `$SPECS_PATH`, a docs repo, or the vault.

`skills/_shared/phase-handoff.md` is the **single source of truth** for the two entry points that move a phase deliverable onto `$SPECS_PATH`'s default branch: `handoff-to-main` (§2, the producer side — resolves or reuses a plugin branch, stages the deliverable by enumeration, commits with a carried `Co-authored-by` trailer, pushes, and opens a pull request via a `gh` capability probe) and `require-on-main` (§3, the consumer side — a ten-state gate, rows H/I/G/A/B/C′/C/D/E/F, first matching row applies, tested against `origin/<default>` by ref rather than by worktree contents). §3.4 carries the row-F delegation table naming each caller's pre-existing absent-input behaviour, so the gate never turns an optional artifact into a hard prerequisite; §4.1 defines the single `Phase handoff:` outcome line every producer emits exactly once; §4.3 defines the three-choice consent array every producer presents verbatim. Eight producers call `handoff-to-main`: `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `implement:` (Phase 4.5, for spec/design-conformance notes), and `ready:` (for its `_readiness.md` snapshot). Seven consumers call `require-on-main`: `create-vi:` (its own `idea.md`), `create-ard:` (the VI), `specify:` (the VI), `design:` (`specification.md`), `implement:` (its in-scope `specification.md`/`design.md`), `epics:` (the VI-level `specification.md`), and `ready:` (every `specification.md`/`design.md` in its artifact inventory) — `update-vi:` deliberately calls neither, since its authoritative base is the Jira import and gating its read-only secondary grounding would block a legitimate refresh over an unrelated branch.

`skills/_shared/finding-triage.md` is the **single source of truth** for the step between a reviewer's findings and a fixer's edits — run by the **orchestrator**, never by the fixer, because a dismissal must not sit at a weaker station than the strong-tier reviewer that produced the finding. It owns the attachment rule (wherever a reasoned-claim producer feeds a fixer: `code-review` → `review-fixer` in `implement:` / `vuln:` / `upgrade:`, `doc-reviewer` → `doc-fixer` in `document:` Jira mode, `epic-reviewer` → `doc-fixer` in `epics:`; **never** a style checker → `doc-fixer`, and where a skill dispatches a fixer more than once it attaches to the reviewer-fed dispatch only), the three-step process (verify each finding's own claimed consequence at the location it names, keep or dismiss, record every dismissal with a reason that disposes of that finding's own claim — there is no silent-drop disposition), the patch gate (auto-fix only a defect that actually occurs, missing coverage for a specific case, or a broken gate/convention — never a state nothing reaches, and never a fix that guards state the finding did not demonstrate), the reporting contract (findings reviewed, survivors, and every dismissal with its reason — a triage that reports only survivors is indistinguishable from a reviewer that found less), and the disposition when triage empties the survivor set (never dispatch a fixer with nothing to apply, never run the unresolved-BLOCKER escalation on a refuted BLOCKER, and never silently promote a non-PASS verdict — the user settles a verdict its own findings no longer support). Consumed by `implement:`, `vuln:`, `upgrade:`, `document:` (Jira mode), and `epics:`, and by `review-fixer` and `doc-fixer` for the patch gate.

`skills/_shared/instruction-file-maintenance.md` is the **single source of truth** for changes to agent-instruction files (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, rules files, and this plugin's own `_shared/*.md`) — verify every command claim against the thing that runs it; a rewrite that narrows a rule is a deletion and is itemised separately; a pointer names an observable trigger, never one the agent must judge; two live contradictory instructions is a defect; retirement needs grounds, never "it looks derivable" and never "nothing has failed on it lately". Consumed by `impl-maintenance`, and binding on hand edits to this file.

**`dev-workflows`'s human-facing documentation lives in `dev-workflows/docs/`, not in its README.** 33 pages — `docs/README.md` (the index), `getting-started.md`, `workflow.md`, `roles.md`, 21 skill pages under `docs/skills/`, and 8 reference pages under `docs/reference/` — with the plugin `README.md` reduced to a role-indexed pointer table. **A Claude edition's page is a source of topics, never a source of facts**: every claim on a page here must be re-derived from this edition's own shipped tree — this edition's `agents/`, this edition's own skill triggers and phases, this edition's own env-var reads — never copied across from a Claude-edition page's wording, numbers, or examples. `scripts/check-docs.sh` enforces the tree: run `./scripts/check-docs.sh --root .` before pushing, and it runs on every push via `.github/workflows/validate-catalog.yml`, preceded there by `--selftest`. Nine checks, shared byte-for-byte with the Claude editions below the edition-config block at the top of the script: links and anchors resolve; no page is unreachable from `docs/README.md`; the skill/agent/reference-file/hook inventories match the shipped tree in both directions; every plugin-read environment variable is documented and every documented one is actually read; no table cell exceeds 200 characters; `getting-started.md`'s install commands match the repo-root `README.md` verbatim; every skill handing `emit-cost` a fixed `phase`/`role` pair has a matching `cost-emission.md` §7 row; and every prose count matches the tree. **State the checks accurately for this edition, never copy the Claude numbers**: this edition sets `HAS_COST=0` — no cost subsystem exists here (`skills/_shared/specs-repo-git.md:54` states it) — which makes check 8 and check 9's cost-emitting-skills assertion inert-and-reported rather than gating, so `--selftest` runs **32 cases, not 37** — the other 5 are cost-only mechanics this edition can never trip. **Identity quarantine:** no page under `docs/` may name a marketplace or a container repo — `getting-started.md` is the single sanctioned exception, pinned by check 7, which is why it carries the install commands inline instead of linking out.

## `dev-workflows` plugin — skill relationships

```
Lifecycle (each phase writes a reviewable artifact, offers the next):
idea:            → idea → idea-reader → [code-scanner×N (--ground-code, cap 4, broad-then-narrow)] → (embedded grilling) → write idea.md → relocate idea.md → [handoff-to-main: idea.md] → commit-artifacts
create-vi:       → [require-on-main: idea.md] → create-vi → [vi-reviewer@strong] → (Value Increment) → [handoff-to-main: VI] → commit-artifacts
update-vi:       → update-vi (jira-import-first) → [vi-reviewer@strong] → (refreshed Value Increment) → [handoff-to-main: VI] → commit-artifacts
create-ard:      → [require-on-main: VI] → create-ard → [ard-reviewer@strong] → (ARD, resolves decisions) → [handoff-to-main: ARD] → commit-artifacts
specify:         → [require-on-main: VI] → specify (jira-driven) → [spec-reviewer@strong] → (engineering spec) → [handoff-to-main: specification.md] → commit-artifacts
design:          → [require-on-main: specification.md] → design → [interface-designer×3 (offered on a contested interface; --design-twice forces the fan-out, no offer)] → [design-reviewer@strong] → (engineering design) → [handoff-to-main: design.md] → commit-artifacts
epics:           → epics (jira-driven) → jira-reader → [code-scanner×N (parallel, optional)] → [require-on-main: VI-level specification.md — a deliberate exception to phase-handoff.md §5 rule 2's ordering] → writing → [dt-style-checker] → [doc-fixer] → [epic-reviewer@strong] → [triage: verify each finding] → [doc-fixer] → impl-maintenance → commit-artifacts
release-notes:   → release-notes → release-notes-writer: resolve destination + shape per destination + source the {{#context}} label + detect deprecation → (dynatrace-docs block draft: destination-shaped Summary; NEVER written to docs repo) → commit-artifacts
ready:           → [require-on-main: spec/design paths — gates as a finding capping PARTIAL, never stops] → ready → [readiness-reviewer@strong] → [handoff-to-main: _readiness.md] → impl-maintenance → commit-artifacts

Implementation & maintenance:
implement:       → [require-on-main: in-scope specification.md/design.md] → implement → [risk-planner@strong plan critique] → [code-review@strong] → [triage: verify each finding] → review-fixer → test-writer → tests → impl-maintenance → [handoff-to-main: escalated spec/design notes, when any] → [finish-code-branch: commit + consent-gated push/PR in the code repo] → commit-artifacts
document:        → document (dual-mode)
                    ├─ doc-edit mode → writing → [docs-style-checker] → [doc-fixer] → impl-maintenance → [maintenance proposals: apply/skip] → commit-artifacts   (no doc-reviewer gate in this mode)
                    └─ jira mode → jira-reader → [diff-summarizer×N (parallel)] → [doc-location-finder] → [image review: add-list + existing-page staleness] → [counterpart-finder (space-constrained runs)] → [doc-planner] → writing → [docs-style-checker → dt-style-checker fallback] → [doc-fixer] → [doc-reviewer] → [triage: verify each finding] → [doc-fixer] → impl-maintenance → squash → [maintenance proposals: apply/skip] → commit-artifacts
vuln:            → vuln → vuln-research → vuln-fixer (branch + fix, uncommitted) → [code-review@strong] → [triage: verify each finding] → review-fixer → tests → [finish-code-branch: commit + push/PR, per CVE, from the base branch] → impl-maintenance → commit-artifacts
upgrade:         → upgrade → upgrade-planner → [risk-planner@strong] → upgrade-executor → [code-review@strong] → [triage: verify each finding] → review-fixer → tests → [finish-code-branch §2.2–§2.3: commit this component] ⟲ → [finish-code-branch: push/PR once for the batch] → impl-maintenance → commit-artifacts
docs-profile:    → docs-profile → (writes .dev-workflows/docs-profile.yml as reviewable PR; consumed by document: jira mode)

All seventeen in-scope skills additionally run `specs-preflight` at run start — as early as
$SPECS_PATH is known (Phase 0 in most skills, Step 0 in vuln:, the shared mode-detection section
in document:) — and `commit-artifacts` as their last action (skills/_shared/specs-repo-git.md),
including the four Utilities below, which have no line of their own here because they are
single-purpose logging skills rather than pipelines. In prompt-brainstorm: and prompt-grill-me:
the terminal step runs immediately before their Phase 3, which cedes the session (§4).
docs-profile: is out of scope — it writes no $SPECS_PATH artifact.

Shared sub-agents:
                    └── test-baseliner    (used by implement:, and by upgrade: and vuln: both directly and via upgrade-executor / vuln-fixer)
                    └── test-writer       (used by implement: only — Phase 3.5 SIMPLE/MODERATE, Phase 3B SIGNIFICANT/HIGH-RISK)
                    └── risk-planner      (used by implement: — Phase 2B, replaces rubber-duck; and upgrade: — SIGNIFICANT/HIGH-RISK components)
                    └── code-review       (used by implement: — Phase 3B, vuln, upgrade)
                    └── doc-reviewer      (used by document: jira mode Phase 7 only — doc-edit mode has no reviewer gate)
                    └── doc-fixer         (used by document: doc-edit Phase 3.5, jira mode Phases 6.4/7, epics:)
                    └── doc-location-finder (used by document: jira mode Phase 5.5)
                    └── counterpart-finder (used by document: jira mode Phase 5.6.5, space-constrained runs)
                    └── doc-planner       (used by document: jira mode Phase 5.7)
                    └── docs-style-checker (used by document:, both modes — doc-edit Phase 3.5, jira mode Phase 6.4)
                    └── dt-style-checker  (from dt-style-guide plugin; fallback for docs-style-checker, primary for epics)
                    └── epic-reviewer     (used by epics: Phase 7)

Standalone reviewers (thin dispatcher skill → agent holding the logic):
api-guideline-reviewer:  → api-guideline-reviewer skill → api-guideline-reviewer agent (OpenAPI vs Dynatrace REST API + IAM guidelines)
guideline-reviewer:      → guideline-reviewer skill → guideline-reviewer agent (code/UI vs Dynatrace Experience Standards)

Utilities: feedback:, prompt:, prompt-brainstorm:, prompt-grill-me:

"@strong" = strong reasoning tier (Opus 5/4.8/4.7/4.6 or GPT-5.6/5.5), pinned by the caller.
```

Key invariants for the VI-creation flow (`idea:`, `create-vi:`, `create-ard:`, `specify:`, `design:`, `implement:`, `epics:`, `ready:`):
- `idea:` Phase 5 relocates `idea.md` into `$SPECS_PATH/specifications/<KEY>-<slug>/` and hands it off via `handoff-to-main` (`skills/_shared/phase-handoff.md` §2) behind the §4.3 consent choice; relocation is `idea:`'s alone — `create-vi: <KEY>` finds it there and never moves it
- `create-vi: <KEY>` derives `idea.md` in-contract from the resolved feature folder and gates it via `require-on-main` (`skills/_shared/phase-handoff.md` §3); an explicit `@<path>` argument is out-of-contract — read where it sits, never relocated, never gated
- `design:` offers a three-take `interface-designer` fan-out (one take per constraint — minimise the interface, maximise flexibility, optimise for the most common caller) on a contested interface — any `skills/_shared/design-format.md` `## Seams` signal; `--design-twice` forces the fan-out itself, skipping the offer, even with no signal fired (a user who typed the flag has already answered what the offer would ask); the offer's two options carry no `(Recommended)` marker, because the list is only shown once the interface is already contested; declining costs nothing — the interview continues and `design.md`'s unconditional `### Alternatives considered` requirement is satisfied by hand as it would have been anyway
- `ready:` is **read-only for Jira status** — it verifies status against the ARD/spec/design, never sets it, and never stops on an unmerged artifact (`skills/_shared/phase-handoff.md` §3.3 rows D/E, a readiness finding capping the verdict at `PARTIAL`) or a missing one (row F, delegated per §3.4, recorded as a coverage gap); it commits the deliverable or the `_readiness.md` snapshot only through `phase-handoff.md` §4.3's consent choice via `handoff-to-main` (§2), never automatically
- A phase is not finished until its artifact is on the specs repo's default branch — every producer offers branch + commit + push + PR, and every consumer executes `require-on-main` before expensive work; an absent optional input still delegates to the command's pre-existing behaviour and never becomes a prerequisite

Key invariants enforced by all three code orchestrators (`implement:`, `vuln:`, `upgrade:`):
- Branch created before any file is touched (`feat/<slug>` or equivalent)
- Phase 4.6 (`finish-code-branch`) runs **after** Phase 4, never before it — Phase 4's Agents 1–3 write `README.md`, `CHANGELOG.md`, `docs/`, `.github/copilot-instructions.md`, and in-repo memory files into the same repository, so a commit ahead of them ships a partial run. A multi-source run that wrote into a repo it never branched names that repo and its dirty paths in the Phase 5 report rather than inventing a branch for it
- The work is COMMITTED on that branch before the run ends — prompt-free, because a commit is local and reversible and an uncommitted implementation is the one loss no later step can undo (`skills/_shared/code-repo-handoff.md` §1 rule 5). Pushing it and opening a pull request sit behind §2.4's single consent choice, asked once per run and reused for every later branch in it. A run that did not end clean is still committed, and still offered for push and PR under the same choice; only the pull request itself changes — a draft whose body leads with a DO-NOT-MERGE line (§2.8)
- Strong-tier (Opus/GPT-5.6) review gate runs **before** tests for `SIGNIFICANT`/`HIGH-RISK` tasks
- `code-review`'s findings are triaged by the orchestrator before `review-fixer` sees them (`skills/_shared/finding-triage.md`) — each finding verified at the location it names, every dismissal recorded with a reason that disposes of that finding's own claim, and the fixer handed **survivors only**; a survivor that fails the patch gate is surfaced for a human decision instead of patched
- `review-fixer` handles BLOCKER findings; only one review-fixer cycle per review
- Every file path these skills hand to `risk-planner`, `code-review`, `test-writer`, `review-fixer`, `vuln-fixer`, or `upgrade-executor` carries a read-failure tier, stated by that agent where it takes the input (`skills/_shared/context-management.md`) — an unreadable **evidence** input is a hard stop and is NEVER regenerated by other means (a resume that re-derives its own input is exactly the failure the contract exists to prevent); an unreadable **context** input degrades to absent and the output records the degradation
- A reviewer handed `claims_file` reads it ONLY after every other dimension is complete — the deferral is what makes the falsification independent, and it is bought structurally (a path, read late) rather than by instruction
- `impl-maintenance` runs post-batch to update KB, `copilot-instructions.md`, and project docs

Key invariants for `implement:` specifically:
- Test baseline captured (Phase 2.6) **before** any source edits, using `test-baseliner`
- `test-writer` sub-agent (Phase 3.7) writes tests for **new/changed behaviour** — mandatory for code changes
- If no test framework is detected, user is asked explicitly — test-writing is never silently skipped
- Full test suite verified against baseline (Phase 3.8) before Phase 4

Key invariants for `document:` doc-edit mode:
- **No branch creation by default** — works on current branch unless user requests one
- **No test-baseliner, no test-writer, no code-review** — docs-only phases only
- **No `doc-reviewer` gate** — this mode is deliberately lightweight: a mandatory style check (Phase 3.5) and `doc-fixer`, but no strong-tier review
- Style-check findings are fixed via `doc-fixer`; with no reviewer gate there is no BLOCKER fix cycle, no re-review, and no finding triage in this mode — a linter violation is a deterministic match with nothing to trace, so `skills/_shared/finding-triage.md` explicitly excludes this path
- Mixed code + docs changes must use `implement:` instead

Key invariants for `document:` jira mode and `epics:`:
- Mode dispatch is by trigger: `document:` (feature docs) vs `epics:` (epic writing)
- **Zero direct API calls** — PR URLs from Jira exports are identifiers only; the agent never calls the GitHub or Bitbucket REST API **directly over HTTPS**. GitHub resolution may use the `gh` CLI (which wraps the API — allowed); Bitbucket has no `gh` and is pure local `git`; all resolution runs on clones under `$REPOS_PATH` (default `/workspace`; colon-separated list supported via `REPOS_PATH=/a:/b:/c`)
- `jira-reader` is strictly read-only — never modifies vault files
- Parallel sub-agent invocation: all diff-summarizers (`document:` jira mode) or code-scanners (`epics:`) are launched in a **single response** (one `task()` per repo)
- Branch setup happens **before** writing output files — never after
- Branch policy: `epics:` never branches. `document:` classifies its write context against the resolved `docs_repo_path` (not necessarily cwd) — walk up for `.obsidian/` → `obsidian` (never branch); else `git rev-parse` plus docs signals → `docs_repo` (branch opt-in, confirmed at plan approval) or `non_docs_repo` (user confirmation promotes it to `docs_repo` behaviour); else `plain_dir` (never branch)
- `doc-location-finder` (`document:` jira mode only) identifies write targets before writing begins
- `doc-planner` (`document:` jira mode only) synthesises Jira + diffs into a documentation checklist
- Counterpart-space grounding (`counterpart-finder`, Phase 5.6.5) runs only on space-constrained runs; it is **read-only** — never copies counterpart-space-specific detail or screenshots into the target doc; `--counterpart <JiraID|PR-url>` reaches an unmerged counterpart PR by reusing `document:`'s existing PR-diff resolver (`diff-summarizer`, no new external-API surface); nothing found ⇒ the run behaves exactly as today
- `docs-style-checker` + `doc-fixer` lint prose after writing, before review gate; if no repo linter detected, falls back to `dt-style-checker` (from `dt-style-guide` plugin) when installed
- `epics:`: `dt-style-checker` is the primary style checker (vault content has no repo linter); gracefully skipped if `dt-style-guide` not installed
- Review gate: `doc-reviewer` (`document:`) or `epic-reviewer@strong` (`epics:`); the reviewer's findings are triaged by the orchestrator before `doc-fixer` sees them (`skills/_shared/finding-triage.md` — each finding verified at the location it names, every dismissal recorded with a reason that disposes of that finding's own claim, survivors only, and a survivor failing the patch gate surfaced rather than patched); `doc-fixer` resolves surviving BLOCKERs; cap 1 fix cycle + 1 re-review. Both flows dispatch `doc-fixer` more than once — the triage attaches to the **reviewer-fed dispatch only**, never to the style-checker-fed one
- The re-review is handed the `doc-fixer` Fix Report as `claims_file`, and the reviewer reads it ONLY after every other dimension is complete — the deferral is what makes the falsification independent, and it is bought structurally (a path, read late) rather than by instruction
- Sub-agents return `DIRTY_TREE` / `REFRESH_BLOCKED` when a **writable** repo cannot be refreshed; a read-only mount returns neither and scans at `prep.scanned_ref` — orchestrator escalates to user; never silent failure
- Every written claim must be traceable to a Jira key + PR URL (`document:`) or file path (`epics:`) — but for `document:`, that attribution goes in the run's return payload and the commit message, **never** inline in the rendered page (`doc-structure-conventions.md` §1); `epics:` Epic drafts still cite `[[KEY]]` inline
- `document:` jira mode's Phase 5.6 image step **always runs** — declining new screenshots skips only the add-list, never the review of images already on an `extend-existing` page for staleness; a page's declared `announcement_pages` block lets `doc-location-finder` propose a hand-authored cross-cutting page (e.g. a deprecation notice) as an additional target alongside the feature-subtree page
- Phase 8's (jira mode) / Phase 4's (doc-edit mode) knowledge-base and instructions maintenance agents only ever **propose** an edit (`{file, anchor, replacement, reason}`); a following maintenance-proposals phase asks the user to skip/apply-all/choose-per-proposal before anything is written, and an applied edit is left uncommitted so it never rides the docs commit
- Writes never touch `_archive/` (vault read-only zone); never write outside cwd unless user provides explicit absolute path
- (docs flow) Phase 0 runs the toolchain preflight after profile resolution; it prompts **only** when a required tool is missing, and Cancel is the recommended option
- (docs flow) Every gate in the `gate-ledger.md` registry appends its row **when the gate completes**; a missing row, an unconverted `UNAVAILABLE`, or an unattributed skip is a `doc-reviewer` BLOCKER
- A phase's `choices:` array is presented verbatim — order, wording, and the `(Recommended)` marker are not the orchestrator's to change

## Test-writing requirement for code changes

Any `implement:` invocation that touches source code **must** produce at least
one passing test for each new or changed behaviour before the workflow is considered complete.

- Prefer unit tests; use integration/e2e only if that is the project's established pattern.
- Tests must be meaningful (assert specific behaviour), deterministic, and follow existing project conventions.
- If no test framework is detected, the workflow surfaces this explicitly and asks the user how to proceed — it never silently skips test-writing.
- Docs-only changes (`document:` doc-edit mode) are exempt from this requirement.

## Updating the installed plugin after editing

After editing files in this repo, **commit and push first**, then run the native
Copilot CLI update command on each machine. This fetches the latest from GitHub
and updates both the installed files and the registry in `~/.copilot/config.json`
(which `copilot plugin list` reads):

```bash
# Update one plugin
copilot plugin update dev-workflows@ihudak-copilot-plugins

# Or update everything from every marketplace at once
copilot plugin update --all
```

> **Do not** use `cp -r` or `rsync` to sync from the source repo into
> `~/.copilot/installed-plugins/`. That updates the plugin files but leaves the
> version field in `~/.copilot/config.json` stale, so `copilot plugin list` keeps
> reporting the old version even though the new code is in place. The CLI's own
> `plugin update` command is the only safe way to keep both in sync.

If you genuinely need to test local edits before pushing (e.g., iterating on a
SKILL.md without a commit round-trip), you can use `rsync` as a temporary
workaround — but remember it will leave the registry version stale. After your
final commit + push, run `copilot plugin update <name>@ihudak-copilot-plugins`
to restore parity.

On a fresh machine, `copilot plugin install dev-workflows@ihudak-copilot-plugins`
handles everything natively after the marketplace is registered.

## Marketplace manifest

`.github/plugin/marketplace.json` at the **repo root** (not inside a plugin dir) is required for `copilot plugin install` to work. It lists all plugins in this marketplace:

```json
{
  "name": "ihudak-copilot-plugins",
  "metadata": { "description": "...", "version": "1.0.0", "pluginRoot": "." },
  "owner": { "name": "...", "email": "..." },
  "plugins": [
    { "name": "dev-workflows", "source": "dev-workflows", "description": "...", "version": "1.3.0" }
  ]
}
```

`pluginRoot: "."` means plugin directories are at the repo root. `source` is the subdirectory name.

**A plugin `description` is a stable capability blurb, never a changelog.** Hard budget: **1024 characters**, in both `.plugin/plugin.json` and the `marketplace.json` entry. Copilot CLI enforces this limit and rejects the **entire catalog** when any one entry exceeds it — every plugin in the marketplace then fails to install or update, not just the offending one, which is what the error `plugins.0.description: String must contain at most 1024 character(s)` means. A new capability **replaces** wording; it never appends. Release detail belongs in `CHANGELOG.md`.

`scripts/validate-catalog.py` enforces this — it fails above 1024 and warns above 900, and also catches version drift between a `plugin.json` and the catalog entry advertising it. It runs on every push via `.github/workflows/validate-catalog.yml`; run it locally with `python3 scripts/validate-catalog.py` before pushing. The Claude editions of this marketplace enforce no such limit upstream, so their blurbs grew to 2788 characters unnoticed and the overflow arrived here at port time — trimmed by hand three times before this check existed.

## Requirement-ID grammar

Every requirement ID a plugin doc teaches is the bracketed `[PREFIX#N]` form — `[US#1]`, `[AC#1]`, `[SM#1]`, `[SMC#1]`, `[UC#1]`, `[FR#1]` in a VI and `[AD#1]` in an ARD — never the dash-separated form. A dash-separated ID has the shape of a Jira issue key, so pasting a VI, ARD, or Epic draft into Jira auto-links it to an unrelated real ticket in any project sharing the prefix, and the vault importer rewrites it into a triple-bracketed wikilink on export. `skills/_shared/pre-lint.md`'s `## Jira-key collision` check catches it at authoring time in `create-vi:`, `update-vi:`, `create-ard:`, and `epics:`; `vi-reviewer`, `ard-reviewer`, `epic-reviewer`, and `readiness-reviewer` treat a survivor as a BLOCKER.

`scripts/check-id-grammar.sh` enforces it across the repo — run `./scripts/check-id-grammar.sh --root .` locally before pushing; it also runs on every push via `.github/workflows/validate-catalog.yml`, preceded there by `--selftest`, which asserts the gate's exit code against each fixture, so a gate that has stopped being able to fail shows up as a red build instead of a green one. `CHANGELOG.md` is excluded (history keeps the old form), and a line that has to quote the legacy form in order to forbid or report it carries an `id-grammar-ok` HTML-comment marker — ten such lines across six files (six accept the legacy form as tolerant readers, three forbid it at an authoring gate, and one reports it without gating), audited per file so the marker never becomes a general escape hatch. The `specify:` / `design:` numbered-ID namespace is deliberately outside this grammar and unchanged; `scripts/spec-id-baseline.txt` is its census tripwire.

## Adding a new plugin

1. Create `<plugin-name>/` at the repo root
2. Add `.plugin/plugin.json` using the format above
3. Add skills under `<plugin-name>/skills/<skill-name>/SKILL.md`
4. Update path references to use `~/.copilot/installed-plugins/ihudak-copilot-plugins/<plugin-name>/skills/`
5. Add `LICENSE` and `README.md`
6. **Add an entry to `.github/plugin/marketplace.json`** under `plugins`
7. Register in `settings.json` under `enabledPlugins`: `"<plugin-name>@ihudak-copilot-plugins": true`

## Behavioral guardrails (Karpathy) — project-specific notes

The full four principles live in `~/.copilot/copilot-instructions.md` (user scope).
This section only adds notes specific to this marketplace.

- **Goal-Driven Execution** maps directly onto the existing `test-baseliner` →
  implementation → `test-writer` → re-run flow already enforced by `dev-workflows`.
  When invoking those orchestrators, frame the task as a verifiable goal up front
  so the test gates have something concrete to verify against.
- **Surgical Changes** — when editing skill YAML, SKILL.md frontmatter, or shared
  references under `_shared/`, the orphan-cleanup rule applies in both directions:
  if you remove a `model_routing` field or a phase, also remove every cross-skill
  reference to it in the same change. Stale cross-references between
  orchestrators and sub-agents silently break the workflow.
