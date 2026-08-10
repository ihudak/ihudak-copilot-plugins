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
    └── skills/
        ├── _shared/            ← cross-skill reference docs (not a skill itself)
        └── <skill-name>/
            ├── SKILL.md        ← orchestrator skill (user-facing, slash-command trigger)
            └── references/     ← optional supporting docs read at runtime
                                  (kept under skills/<sub-agent>/references/ for
                                   sub-agents that used to be skills — the SKILL.md
                                   was promoted to agents/<name>.md but the handoff
                                   docs stayed where they were)
```

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

**Skills** are user-facing slash-command triggers (e.g. `/impl:code`). They run in the
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

All orchestrators that dispatch sub-agents (`impl`, `impl-docs`, `impl-jira`, `fix-vuln`, `upgrade`) must load and follow `model-routing.md` at the start of every invocation. Standalone review orchestrators (`api-guideline-reviewer`, `guideline-reviewer`) are exempt — they do not classify complexity or route models. Sub-agents receive the `model_routing` block in their prompt; they do not re-read the file.

`skills/_shared/release-note-types.md` is the **single source of truth** for the release-note **destination map** (`breaking-changes.md` / `feature-updates.md` / `fixes.md`), the per-destination **draft shape** (label + title + prose, vs one bare sentence for `fixes`), the per-destination prose rules, the deprecation-note rule (end-of-life date required, end-of-support optional), and Change Type sourcing (import → infer). It is consulted by `release-notes-writer`; the Change Type is never rendered as text.

`skills/_shared/bug-diagnosis.md` is the **single source of truth** for the bug-diagnosis discipline consulted by the `implement:` skill (Phase 2B) and followed by `risk-planner` when a task is bug-shaped (`task_shape: bug`): feedback-loop-first (a red-capable, deterministic repro before hypothesizing), 3–5 ranked falsifiable hypotheses, `[DEBUG-xxxx]`-tagged instrumentation with a mandatory cleanup gate (stripped before the Opus-review diff), and a regression test at a correct seam. It cross-references `skills/_shared/design-format.md` `## Seams` and is paired with `implement:`'s spec/design-conformance ("converge") check — `code-review`'s conditional 10th dimension that traces in-scope `[Uxx]`/`[ACxx]`/`[TCxx]` against the shipped diff.

`skills/_shared/gate-ledger.md` is the **single source of truth** for verification-gate accounting — the six outcomes (`RAN` / `DEGRADED` / `FAILED` / `UNAVAILABLE` / `SKIPPED_BY_USER` / `NOT_APPLICABLE`), the rule that **no outcome is orchestrator-assignable to mean "I decided not to run this"**, the `document:` gate registry (now seven gates, including `image_review` for Phase 5.6's always-running image step), the `UNAVAILABLE` conversion prompt, and the reviewer contract. Consumed by `document:` (both modes) and written generically for other skills to adopt.

`skills/_shared/repo-verification-gates.md` is the **single source of truth** for extracting a docs repo's own pre-PR checklist into the `repo_verification_gates` block — the heading patterns, what counts as checkable against the written files, and the augment-never-override rule. Applied by `doc-planner` in `document:` Jira mode and by the orchestrator itself in direct mode, which has no planner.

`skills/_shared/toolchain-preflight.md` is the **single source of truth** for the Phase 0 environment check — deriving the required tool set from the resolved profile, the repo's config signals, and the repo's own documented `Prerequisites`; the `toolchain` block with its tool→gate map; and the missing-tool prompt (Cancel recommended, silence when everything resolves). Consumed by `document:` (both modes).

`skills/_shared/doc-structure-conventions.md` is the **single source of truth** for how a written page is structured and what it may contain — the traceability boundary (a rendered page carries no source provenance; the Jira key lives in the commit message, per-claim attribution lives in the run handoff), callout scope and adjacency (a callout sits with the option it qualifies, never trailing the whole set — a scope violation is a `doc-reviewer` MAJOR), and component-pattern fidelity (reuse the docs area's established content component for a recurring shape instead of an ad-hoc structure — divergence is MINOR). Consumed by `doc-planner`, `doc-writer`, and `doc-reviewer`.

`skills/_shared/dynatrace-docs/anchor-conventions.md` is the **single source of truth** for heading-anchor mechanics on dynatrace-docs pages — one `{:#id}` per heading (multi-anchor unsupported), the four verified internal-link forms, the `pnpm docstack validate-anchors` contract, and the rule that a product `dt-url` deep link's anchor wins reconciliation. Consumed by `doc-writer`, `doc-reviewer`, and `doc-planner`.

## `dev-workflows` plugin — skill relationships

```
Lifecycle (each phase writes a reviewable artifact, offers the next):
idea:            → idea → idea-reader → (problem statement)
create-vi:       → create-vi → [vi-reviewer@strong] → (Value Increment)
update-vi:       → update-vi (jira-import-first) → [vi-reviewer@strong] → (refreshed Value Increment)
create-ard:      → create-ard → [ard-reviewer@strong] → (ARD, resolves decisions)
specify:         → specify (jira-driven) → [spec-reviewer@strong] → (engineering spec)
design:          → design → [design-reviewer@strong] → (engineering design)
epics:           → epics (jira-driven) → jira-reader → [code-scanner×N (parallel, optional)] → writing → [dt-style-checker] → [doc-fixer] → [epic-reviewer@strong] → [doc-fixer] → impl-maintenance
release-notes:   → release-notes → release-notes-writer: resolve destination + shape per destination + source the {{#context}} label + detect deprecation → (dynatrace-docs block draft: destination-shaped Summary; NEVER written to docs repo)
ready:           → ready → [readiness-reviewer@strong] → impl-maintenance

Implementation & maintenance:
implement:       → implement → [risk-planner@strong plan critique] → [code-review@strong] → review-fixer → test-writer → tests → impl-maintenance
document:        → document (dual-mode)
                    ├─ doc-edit mode → writing → [docs-style-checker] → [doc-fixer] → [doc-reviewer] → [doc-fixer] → impl-maintenance → [maintenance proposals: apply/skip]
                    └─ jira mode → jira-reader → [diff-summarizer×N (parallel)] → [doc-location-finder] → [image review: add-list + existing-page staleness] → [counterpart-finder (space-constrained runs)] → [doc-planner] → writing → [docs-style-checker → dt-style-checker fallback] → [doc-fixer] → [doc-reviewer] → [doc-fixer] → impl-maintenance → squash → [maintenance proposals: apply/skip]
vuln:            → vuln → vuln-research → vuln-fixer → [code-review@strong] → review-fixer → tests → impl-maintenance
upgrade:         → upgrade → upgrade-planner → upgrade-executor → [code-review@strong] → review-fixer → tests → impl-maintenance
docs-profile:    → docs-profile → (writes .dev-workflows/docs-profile.yml as reviewable PR; consumed by document: jira mode)

Shared sub-agents:
                    └── test-baseliner    (used by upgrade-executor, vuln-fixer, and implement:)
                    └── test-writer       (used by implement: only — Phase 3.7)
                    └── risk-planner      (used by implement: — Phase 2.5, replaces rubber-duck)
                    └── code-review       (used by implement: — Phase 3.9, vuln, upgrade)
                    └── doc-reviewer      (used by document: doc-edit Phase 3.5, and jira mode Phase 7)
                    └── doc-fixer         (used by document: Phase 3.5, jira mode Phases 6.7/7, epics:)
                    └── doc-location-finder (used by document: jira mode Phase 5.6)
                    └── counterpart-finder (used by document: jira mode Phase 5.6.5, space-constrained runs)
                    └── doc-planner       (used by document: jira mode Phase 5.7)
                    └── docs-style-checker (used by document: Phase 6.7)
                    └── dt-style-checker  (from dt-style-guide plugin; fallback for docs-style-checker, primary for epics)
                    └── epic-reviewer     (used by epics: Phase 7)

Standalone reviewers (thin dispatcher skill → agent holding the logic):
api-guideline-reviewer:  → api-guideline-reviewer skill → api-guideline-reviewer agent (OpenAPI vs Dynatrace REST API + IAM guidelines)
guideline-reviewer:      → guideline-reviewer skill → guideline-reviewer agent (code/UI vs Dynatrace Experience Standards)

Utilities: feedback:, prompt:, prompt-brainstorm:, prompt-grill-me:

"@strong" = strong reasoning tier (Opus 5/4.8/4.7/4.6 or GPT-5.6/5.5), pinned by the caller.
```

Key invariants enforced by all three code orchestrators (`implement:`, `vuln:`, `upgrade:`):
- Branch created before any file is touched (`feat/<slug>` or equivalent)
- Strong-tier (Opus/GPT-5.6) review gate runs **before** tests for `SIGNIFICANT`/`HIGH-RISK` tasks
- `review-fixer` handles BLOCKER findings; only one review-fixer cycle per review
- `impl-maintenance` runs post-batch to update KB, `copilot-instructions.md`, and project docs

Key invariants for `implement:` specifically:
- Test baseline captured (Phase 2.6) **before** any source edits, using `test-baseliner`
- `test-writer` sub-agent (Phase 3.7) writes tests for **new/changed behaviour** — mandatory for code changes
- If no test framework is detected, user is asked explicitly — test-writing is never silently skipped
- Full test suite verified against baseline (Phase 3.8) before Phase 4

Key invariants for `document:` doc-edit mode:
- **No branch creation by default** — works on current branch unless user requests one
- **No test-baseliner, no test-writer, no code-review** — docs-only phases only
- `doc-reviewer` sub-agent (Phase 3.5) performs comprehensive review: links, headings, wikilinks, style, completeness
- BLOCKER findings trigger a fix cycle via `doc-fixer` sub-agent (max one fix + one re-review); CONCERNs are recorded and may be fixed inline
- Mixed code + docs changes must use `implement:` instead

Key invariants for `document:` jira mode and `epics:`:
- Mode dispatch is by trigger: `document:` (feature docs) vs `epics:` (epic writing)
- **Zero direct API calls** — PR URLs from Jira exports are identifiers only; the agent never calls the GitHub or Bitbucket REST API **directly over HTTPS**. GitHub resolution may use the `gh` CLI (which wraps the API — allowed); Bitbucket has no `gh` and is pure local `git`; all resolution runs on clones under `$REPOS_PATH` (default `/workspace`; colon-separated list supported via `REPOS_PATH=/a:/b:/c`)
- `jira-reader` is strictly read-only — never modifies vault files
- Parallel sub-agent invocation: all diff-summarizers (`document:` jira mode) or code-scanners (`epics:`) are launched in a **single response** (one `task()` per repo)
- Branch setup happens **before** writing output files — never after
- Branch policy: walk up cwd for `.obsidian/` → `obsidian` (never branch); else `git rev-parse` → `git_repo` (branch opt-in) or `plain_dir` (never branch). User can override at plan approval
- `doc-location-finder` (`document:` jira mode only) identifies write targets before writing begins
- `doc-planner` (`document:` jira mode only) synthesises Jira + diffs into a documentation checklist
- Counterpart-space grounding (`counterpart-finder`, Phase 5.6.5) runs only on space-constrained runs; it is **read-only** — never copies counterpart-space-specific detail or screenshots into the target doc; `--counterpart <JiraID|PR-url>` reaches an unmerged counterpart PR by reusing `document:`'s existing PR-diff resolver (`diff-summarizer`, no new external-API surface); nothing found ⇒ the run behaves exactly as today
- `docs-style-checker` + `doc-fixer` lint prose after writing, before review gate; if no repo linter detected, falls back to `dt-style-checker` (from `dt-style-guide` plugin) when installed
- `epics:`: `dt-style-checker` is the primary style checker (vault content has no repo linter); gracefully skipped if `dt-style-guide` not installed
- Review gate: `doc-reviewer` (`document:`) or `epic-reviewer@strong` (`epics:`); `doc-fixer` resolves BLOCKERs; cap 1 fix cycle + 1 re-review
- Sub-agents return `DIRTY_TREE` / `REFRESH_BLOCKED` when they cannot refresh repos — orchestrator escalates to user; never silent failure
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
