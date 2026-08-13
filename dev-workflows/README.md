# dev-workflows

A GitHub Copilot CLI plugin providing a **full product-development lifecycle** as
structured workflow skills — from raw idea, through requirements and design, to
implementation, documentation, and release. Plus vulnerability remediation,
dependency upgrades, and guideline reviews.

## Installation

```
copilot plugin install dev-workflows@ihudak-copilot-plugins
```

## Triggers

Skills activate on a **flat keyword trigger** — the plugin runs when your prompt
*starts with* the keyword followed by a colon, e.g.:

```
implement: add rate limiting to the /login endpoint
document: PRODUCT-14902
vuln: CVE-2024-1234
```

## Skills

### Product-development lifecycle

The lifecycle skills chain from idea to release. Each writes a reviewable artifact
and offers the next phase.

| Trigger | Skill | Description |
|---------|-------|-------------|
| `idea:` | idea | Capture a raw idea and shape it into a structured problem statement. Pre-VI, keyless. Optionally grounds against mounted code with `--ground-code [<repo>,…]` — off by default, never auto-triggered (see the code-grounding paragraph below). |
| `create-vi:` | create-vi | Draft a Value Increment (VI) from an idea or problem statement (or seed a new one from a sibling VI with `--from-vi`). Release-notes fields (`release_versions`, `change_type`, `release_notes_category`) are NOT captured — they are Jira dropdowns the PM sets on the ticket and the importer returns on the round-trip. Reviewed by `vi-reviewer`. |
| `update-vi:` | update-vi | Refresh/re-do an existing Value Increment — Jira-import-first (source of truth), canonical + archived revisions. Reviewed by `vi-reviewer`. |
| `create-ard:` | create-ard | Draft an Architecture Decision Record for a VI. Reviewed by `ard-reviewer`; resolves open decisions. |
| `specify:` | specify | Write an engineering specification (Jira-driven). Reviewed by `spec-reviewer`. |
| `design:` | design | Write an engineering design from a specification. Reviewed by `design-reviewer`. |
| `epics:` | epics | Draft child Epic definitions for a VI (Jira-driven). Scans repos via `code-scanner`; reviewed by `epic-reviewer` (Opus). |
| `implement:` | implement | Implement a feature or fix. Classifies complexity → risk-weighted plan (Opus critique for complex tasks) → branch → test baseline → implement → `test-writer` → Opus code-review (SIGNIFICANT/HIGH-RISK) → verify no regressions → post-impl maintenance. |
| `document:` | document | Dual-mode documentation. **Doc-edit mode** for direct Markdown/wiki/vault edits; **Jira mode** reads Jira exports + merged PRs, runs parallel `diff-summarizer`s, plans via `doc-planner`/`doc-location-finder`, writes, style-checks, and gates on `doc-reviewer`. On a space-constrained run, `--counterpart <JiraID|PR-url>` (or auto-discovery) grounds the doc on the other space's existing docs — read-only, never copied, never an image source. Phase 0 runs a toolchain preflight (stops a run whose linter/build tooling is absent), and every verification gate records a ledger row that `doc-reviewer` gates on — including a new `image_review` gate for its single, always-running image phase, which reviews both new screenshots and possibly-stale ones already on an extended page (listed per occurrence, swapped via CDN-URL replacement — an image is never refreshed in place). A deprecation or other hand-authored announcement can land on its real cross-cutting page (a profiled `announcement_pages` target) alongside the feature-subtree write. Rendered pages carry no Jira/PR provenance (traceability lives in the commit and the run handoff). Phase 8's `copilot-instructions.md` / knowledge-base maintenance edits are only ever *proposed*; an accepted proposal is applied in a later phase, after the docs commit is sealed, and left uncommitted so it never rides the docs PR. |
| `release-notes:` | release-notes | Generate a release-notes draft for a VI — renders **exactly one** dynatrace-docs Summary, shaped by the destination it routes to (`breaking-changes.md` / `feature-updates.md` / `fixes.md`, per `_shared/release-note-types.md`); the `{{#context}}` label is the imported `release_notes_category` used verbatim, and the run is gated on the imported `relevant_for_release_notes`. Output to markdown/stdout — **never** written into the docs repo (Jira automation owns that path). |
| `ready:` | ready | Readiness gate: verify a VI/feature is ready to ship. Reviewed by `readiness-reviewer`. |

### Maintenance & review workflows

| Trigger | Skill | Description |
|---------|-------|-------------|
| `vuln:` | vuln | Remediate one or more CVEs. Researches each via NVD (`vuln-research`), applies the minimal safe version bump (`vuln-fixer`), verifies tests, applies Opus code-review, runs post-batch maintenance. One branch + PR per CVE. |
| `upgrade:` | upgrade | Upgrade dependencies to a target version. Branch → test baseline → per-component compatibility plan (`upgrade-planner`) → upgrade + verify in sequence (`upgrade-executor`) → Opus code-review → maintenance. |
| `api-guideline-reviewer:` | api-guideline-reviewer | Review OpenAPI specs against Dynatrace REST API and IAM permission naming guidelines. Thin dispatcher → `api-guideline-reviewer` agent. |
| `guideline-reviewer:` | guideline-reviewer | Review code/UI against Dynatrace Experience Standards (GUIDElines) — component usage, accessibility/WCAG, terminology. Thin dispatcher → `guideline-reviewer` agent. |
| `docs-profile:` | docs-profile | Bootstrap or refresh a machine-readable `.dev-workflows/docs-profile.yml` for a docs repo (consumed by `document:` Jira mode). Writes as a reviewable PR. |

### Utilities

| Trigger | Skill | Description |
|---------|-------|-------------|
| `feedback:` | feedback | Capture structured feedback about a plugin run into the specs repo. |
| `prompt:` | prompt | Improve or refine a prompt. |
| `prompt-brainstorm:` | prompt-brainstorm | Collaboratively brainstorm and expand a prompt/idea. |
| `prompt-grill-me:` | prompt-grill-me | Adversarially interrogate a prompt/plan to surface gaps. |

**Which docs skill?** `document:` doc-edit mode is for one-shot manual doc edits (no Jira, no branch/commit). `document:` Jira mode is the Jira-driven feature-documentation workflow end to end. `docs-profile:` is a one-time profiler that generates a repo's `.dev-workflows/docs-profile.yml` (consumed by `document:` Jira mode).

**Counterpart-space grounding (`document: <VI> saas|managed`).** When you document one space, someone may already have written the *other* space's docs for the same feature. `document:` discovers that counterpart page (in-tree keyword search + `git log --grep`, or an explicit `--counterpart <JiraID|PR-url>` for an unmerged PR) and hands it to the writer as **read-only grounding** — concepts, terminology, and structure to consult, never text to copy and never screenshots to reuse (Managed and SaaS UIs differ; target images still come from `$VAULT_PATH`). If the counterpart page is already pulled into your target's render, the run tells you the space may already be covered.

**Documentation grounding (`$DOCS_PATH`).** When `$DOCS_PATH` (default `/workspace/docs`) is set and points at a readable directory containing at least one markdown file, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `epics:`, and `release-notes:` ground automatically on the product's existing shipped documentation — via the read-only `docs-grounder` agent (see `_shared/docs-grounding.md`). Disable per-run with `--no-docs`, or point at a different root with `--docs <path>`. Grill commands rank the grounding into their existing gap list (never adding extra questions); writer commands attach the digest to the writer handoff. Every miss is a silent, non-blocking skip — the run behaves exactly as it does without `$DOCS_PATH` set. `document:` does not consume this grounding; it only uses `$DOCS_PATH` as a docs-repo discovery hint.

**Vault prior-art grounding (`$VAULT_PATH`).** Unlike `$DOCS_PATH`, `$VAULT_PATH` has **no default** — it is a write root. When it is set and resolves to an existing directory with a `Projects/Products/` or `Projects/ideas/` subtree, `idea:` and `create-vi:` ground automatically on tracked initiatives that already cover, precede, parallel, or are superseded by the new work — via the read-only `vault-prior-art-finder` agent (see `_shared/vault-prior-art.md`). It searches `Projects/Products/**` and `Projects/ideas/**` — a few hundred markdown files, retrieved by `glob`/`grep` with no retrieval index. Disable per-run with `--no-prior-art`. Grill commands rank the resulting challenges into their existing gap list (never adding extra questions). Every miss is a silent, non-blocking skip.

**Code grounding (`--ground-code`, `idea:` only).** Off by default and never auto-triggered. `--ground-code` bare derives a repo set from the idea's themes and the directories under `${REPOS_PATH:-/workspace}` (one confirm gate); `--ground-code <repo>,<repo>` scans exactly those. Round 1 is the standard `code-scanner` fan-out (cap 4); a theme it leaves inconclusive gets **one** narrow follow-up round seeded with round 1's verified `file:line` anchors, per `_shared/model-routing.md` §8.5 — there is no round 3. Findings enter the grill as facts, not questions, except one that contradicts the idea's premise, which competes for a question slot like any other challenge. They land in `idea.md`'s optional `## Feasibility grounding` section, never in `Signals & evidence` (which is demand evidence only).

## Workflow overview

The lifecycle skills form a role-based pipeline. Each role has a starting trigger and hands a concrete artifact to the next role. `idea: → create-vi:` (PM) opens it; `document:` + `release-notes:` (Dev) close it.

```mermaid
flowchart TD
    subgraph PM["PM — ideation & framing"]
        idea["idea:"] --> createvi["create-vi:"]
        createvi --> rnpm["release-notes: (early draft)"]
        createvi -.->|VI exists| updatevi["update-vi:"]
        updatevi --> rnpm
    end
    subgraph PA["PA — architecture (optional)"]
        createard["create-ard:"]
    end
    subgraph PE["PE — breakdown & specification"]
        epics["epics:"]
        specify["specify:"]
    end
    subgraph DEV["Dev — build"]
        design["design:"] --> implement["implement:"]
        implement --> document["document:"]
        document --> rndev["release-notes: (final)"]
    end
    subgraph QA["QA — verification & gates"]
        ready["ready:"]
    end
    subgraph ANY["Anytime — improve the plugin & utilities"]
        improve["feedback: · prompt: · prompt-brainstorm: · prompt-grill-me:"]
        maint["vuln: · upgrade:"]
        tooling["docs-profile: · api-guideline-reviewer: · guideline-reviewer:"]
    end

    createvi -->|VI| createard
    createvi -->|VI| epics
    createard -->|ARD| epics
    epics -->|Epic drafts| specify
    specify -->|specification.md| design
    ready -. verifies ARD/spec/design .-> implement
```

| Role | Starts with | Consumes | Produces → where it lands |
|------|-------------|----------|---------------------------|
| **PM** | `idea:`, `create-vi: <KEY>`, `update-vi: <KEY>`, `release-notes: <VI>` | a prompt / community post / RFE / existing VI; then a refined `idea.md` + a JIRA-KEY | `<KEY>_<slug>.md` in `$SPECS_PATH/specifications/<KEY>-<slug>/` (idea.md relocated in); an early release-notes draft in the vault; paste-to-Jira → re-import to `$VAULT_PATH/jira-products/<KEY>/` |
| **PA** *(optional)* | `create-ard: <VI> [<Epic>]` | the VI (and Epic) | `<VI>_ARD.md` / `<EPIC>-<area>_ARD.md` in the same specs feature folder |
| **PE** | `epics: <VI>`, `specify: <VI> [<Epic>]` | the VI (+ ARD, existing Epics) | Epic drafts in `$VAULT_PATH/jira-drafts/<VI-KEY>/`; `specification.md` on the specs-repo main (branch + PR) |
| **Dev** | `design: <VI> <Epic>`, `implement: <VI> <Epic>`, `document: <VI>`, `release-notes: <VI>` | the `specification.md` (+ ARD); `design.md`; the code repos | `design.md` on the specs-repo main; code + PR in `$REPOS_PATH`; product docs in the docs repo; the final release-notes draft in the vault |
| **QA** | `ready: <VI \| Epic>` (+ the strong-tier reviewer gate embedded in every authoring/build skill) | the Jira status + the ARD / spec / design artifacts | a `SUPPORTED` / `PARTIAL` / `NOT-SUPPORTED` verdict — read-only; sets no status |

**`specify:` VI-level scope.** `specify: <VI>` (no focus Epic) is valid and stays in the PE lane — the `[<Epic>]` above is genuinely optional, it's just collapsed at this diagram's role-level granularity. For a VI with **≥2 Epics**, Phase 2 renders the Epic picker and offers three paths: pick one Epic (the usual per-Epic spec), explicitly **"Author one broad VI-level spec instead,"** or the tool's own recommendation, **"Split into Epics first with `epics:`, then re-import."** For a **single-Epic VI**, `specify: <VI>` auto-resolves to that Epic — there is no true VI-level path in that case. A broad VI-level spec writes one `specification.md` for the whole VI (branch `spec/<VI>-<vslug>` instead of `spec/<EPIC>-<eslug>`), and its `### Next step` recommendation points to `epics: <VI>` (still PE) rather than `design: <VI> <Epic>` (Dev).

**Sources of truth & artifact homes**

- **Jira** is the source of truth for workflow *status*. The external `jira-workitem-import` tool imports the ticket tree into `$VAULT_PATH/jira-products/<KEY>/`; the plugin reads status but **never sets it**.
- **`$SPECS_PATH/specifications/<KEY>-<slug>/`** — the shared, team-visible home for the VI, ARD, `specification.md`, and `design.md`.
- **`$VAULT_PATH`** — your personal store: `Projects/…/<slug>/idea.md` (depth per the container rule), the imported `jira-products/` tree, `jira-drafts/<VI-KEY>/` Epic drafts, and release-notes drafts.
- **`$REPOS_PATH`** — the code clones (`implement:` works on branches + PRs here); product documentation is written into the external **docs repo**.
- **Plugin-generated artifacts live in the specs repo.** Feedback and follow-up files are written under `<VI-dir>/dev-workflows/` in `$SPECS_PATH` — `<KEY>-feedback.md` and `<KEY>-followups.md`. **Committing and pushing these alongside the specs is expected and encouraged** — team-visible feedback is the point, not clutter. (Unlike the Claude Code edition, there is no `cost/<sid8>.md` — see [Not ported](#not-ported-from-the-claude-code-edition).)

**Cross-cutting skills (any time)**

- **Plugin improvement — please use these.** `feedback:` logs a note about the plugin itself; `prompt:`, `prompt-brainstorm:`, and `prompt-grill-me:` turn a correction you just made into logged feedback plus a fix.
- **Standalone maintenance.** `vuln:` (CVE remediation) and `upgrade:` (dependency / runtime upgrades) run on their own, outside the VI pipeline.
- **Repo tooling.** `docs-profile:` (bootstrap a docs repo's profile), `api-guideline-reviewer:` and `guideline-reviewer:` (Dynatrace API / UI compliance reviews).

*Legend: **Dev** is the plugin's "Team" lane; **QA** denotes verification and quality gates, not an artifact-authoring role; `release-notes:` appears twice because it serves a PM early draft (from the VI alone) and a Dev final draft (grounded in the merged PR diffs).*

## `implement:` workflow

```mermaid
flowchart TD
    IN["implement:"] --> C{"Classify complexity (model-routing)"}
    C -->|SIMPLE · MODERATE| P1["Standard plan → approve"]
    C -->|SIGNIFICANT · HIGH-RISK| P2["Strong-tier risk-planner → approve"]
    P1 --> BR["Branch + capture test baseline"]
    P2 --> BR
    BR --> IM["Implement"]
    IM --> G{"SIGNIFICANT · HIGH-RISK?"}
    G -->|Yes| RV["test-writer → strong-tier code-review → review-fixer (gate: tests never run before non-BLOCK)"]
    G -->|No| TS["test-writer + verify vs baseline (fix loop)"]
    RV --> VF["Verify vs baseline (fix loop)"]
    TS --> MT["Post-impl maintenance (4 agents)"]
    VF --> MT
    MT --> RP["Final report"]
```

`document:` (both modes) and `epics:` never run tests and never touch production code.

When a `specification.md`/`design.md` is in scope on a SIGNIFICANT/HIGH-RISK run, `implement:` runs a **spec/design-conformance ("converge") check** — the Opus `code-review` traces every in-scope `[Uxx]`/`[ACxx]`/`[TCxx]` against the shipped diff, and unresolved `missing`/`contradicts` gaps are escalated as `- [ ]` notes back onto the spec/design. Bug-shaped tasks additionally follow `skills/_shared/bug-diagnosis.md` — a red-capable repro before hypotheses, 3–5 ranked falsifiable hypotheses, and `[DEBUG-xxxx]` instrumentation stripped before the review diff is captured.

## Session feedback

Beyond the lifecycle skills, `dev-workflows` captures **friction and improvement
signals about the plugin itself** and persists them per-VI into the specs repo,
so the plugin maintainer can aggregate feedback across engineers and plan
improvements. Capture is **silent and high-recall** — there is no approval gate;
curation is the maintainer's job, centrally, at analysis time.

- **Automatic.** The end-of-run maintenance phase of the lifecycle and maintenance
  skills (`implement:`, `document:`, `epics:`, `vuln:`, `upgrade:`, `release-notes:`,
  `specify:`, `design:`, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `ready:`) projects the
  plugin-facing slice of the `impl-maintenance` report (workflow improvements, new
  agents/skills, reference-doc gaps) into a feedback entry (`origin: auto`). A
  routine session with no plugin-facing signal writes nothing.
- **`feedback: <text>`** — a universal manual note about the plugin, tied to no
  skill (`origin: manual`).
- **`prompt: <text>`** — capture a corrective interaction (a skill produced
  something wrong; you fix it) as Friction + your verbatim prompt + the
  Resolution, then act on the correction directly (`origin: prompt`).
- **`prompt-brainstorm: <text>`** — same capture, then hand off to a
  collaborative brainstorm.
- **`prompt-grill-me: <text>`** — same capture, then grill the fix **inline** — a
  bounded one-question-at-a-time interrogation of the correction.

**Graceful degradation.** Persistence is **specs-first** (central aggregation is
the point) and deterministic: `$SPECS_PATH` VI dir
(`<VI-dir>/dev-workflows/<KEY>-feedback.md`) → `$SPECS_PATH/dev-workflows-feedback/`
→ a writable vault (with a loud "won't auto-aggregate to the maintainer" notice)
→ beside an imported Jira directory → report-only. It **never** writes into the
current working directory, and no capture phase ever fails the run. See
[`skills/_shared/feedback-emission.md`](skills/_shared/feedback-emission.md).

## Sub-agents

Each sub-agent lives in `agents/<name>.md` and is dispatched with
`task(agent_type: "dev-workflows:<name>", ...)`. Agents run in their own context
window and inherit the orchestrator's model **unless the caller passes an explicit
`model:` override on the `task()` call** — there is no `model:` frontmatter pin on
the agent file itself (unlike the Claude Code edition, where the nine strong-tier
reviewers/planners are pinned in frontmatter). The caller is responsible for
passing the strong-tier model for the nine reviewer/planner agents below. There
are **33** sub-agents:

| Agent | Model | Description |
|-------|-------|--------------|
| `risk-planner` | Strong tier, caller-pinned | Risk-weighted planner for SIGNIFICANT / HIGH-RISK tasks. Returns a structured plan with an explicit risks section. Refuses SIMPLE / MODERATE and returns a re-classification notice instead. |
| `code-review` | Strong tier, caller-pinned | Post-implementation reviewer — 8 dimensions (correctness, security, architecture, edge cases, migration, dependencies, test adequacy, rollback). Verdict: PASS / PASS WITH RECOMMENDATIONS / BLOCK. BLOCK gates the test run. |
| `doc-reviewer` | Strong tier, caller-pinned | Product-documentation reviewer for `document:` — 17 dimensions including factual correctness, completeness vs plan, audience fit, structural integrity (incl. anchor form), page structure conventions (callout scope + component-pattern fidelity), YAML frontmatter, screenshots (incl. stale-image swap completeness), snippets, actionability, source traceability (a Jira key or PR URL in a rendered page is a MAJOR — the rendered page carries no source provenance), cross-space grounding integrity, and style-check follow-through. |
| `epic-reviewer` | Strong tier, caller-pinned | Epic-draft reviewer for `epics:` — goal clarity, testable acceptance criteria, scope boundaries, dependencies, non-duplication vs sibling Epics (BLOCKER), and reference-path evidence (when `code-scanner` output is provided). |
| `spec-reviewer` | Strong tier, caller-pinned | Specification reviewer for `specify:` — checks problem/scope clarity, user-story and acceptance-criteria testability, test-case coverage, open-question resolution (BLOCKER on unresolved items that could be resolved live), and adherence to the org-standard `specification.md` format. |
| `design-reviewer` | Strong tier, caller-pinned | Engineering-design reviewer for `design:` — validates `design.md` against the design-format authority and traceability to its `specification.md` (every in-scope requirement covered; BLOCKER on a gap), plus interface concreteness, seam/test-strategy soundness, and risk coverage. Treats any unresolved `design.md` open question as a BLOCKER. |
| `vi-reviewer` | Strong tier, caller-pinned | Value-Increment reviewer for `create-vi:` — validates the VI against `vi-format.md`: mandatory-spine completeness, testable acceptance criteria, scope/success-metric clarity, and hollow-prose / filler (MAJOR). |
| `ard-reviewer` | Strong tier, caller-pinned | Architecture-decision-record reviewer for `create-ard:` — checks each `AD-N` has a concrete Binds/Prevents/Rule, grounding findings cite real `file:line`, the cross-repo map is coherent, and open questions are surfaced. |
| `readiness-reviewer` | Strong tier, caller-pinned | Readiness reviewer for `ready:` — verifies the Jira status against the actual ARD/spec/design artifacts and returns a SUPPORTED / PARTIAL / NOT-SUPPORTED readiness verdict. Read-only; never sets Jira status. |
| `test-baseliner` | Caller-assigned | Runs the test suite in `capture` or `verify` mode; `verify` diffs against a prior baseline and returns a structured regression report. Framework detection: Maven, Gradle, npm, pytest, Makefile. |
| `test-writer` | Caller-assigned | Writes tests for new or changed behaviour based on a diff. Never runs tests. Framework detection mirrors `test-baseliner`; returns "not detected" immediately if no framework is configured. |
| `review-fixer` | Caller-assigned (default, not strong tier) | Applies BLOCKER / MAJOR findings from a `code-review` report; returns a structured fix report. Used by `implement:`, `vuln:`, `upgrade:`. |
| `upgrade-planner` | Caller-assigned | Phase-1 compatibility planner for `upgrade:`: detects the component, resolves the target version (exact/minor/latest/lts/bare), and verifies compatibility with other components. Returns a structured upgrade plan or a conflict report. |
| `upgrade-executor` | Caller-assigned | Phase-2 executor for `upgrade:`: applies the plan for one component, runs the build, verifies tests via `test-baseliner`, and auto-fixes test-code breakage from the new version's API changes. |
| `vuln-research` | Caller-assigned | Read-only research phase of `vuln:`: NVD lookup, library detection, current-version discovery, and minimum-safe-version resolution. No side effects. |
| `vuln-fixer` | Caller-assigned | Fix phase of `vuln:`: captures a baseline, applies the minimal version bump, rebuilds, verifies tests, commits to a branch, and opens a PR. |
| `doc-fixer` | Caller-assigned | Applies BLOCKER / MAJOR findings from a `doc-reviewer`, `epic-reviewer`, or `docs-style-checker` report. Shared between `document:` and `epics:`. |
| `docs-style-checker` | Caller-assigned | Runs the docs repo's project-configured prose linter (Vale, `package.json` lint script, markdownlint, or remark) on files written by `document:`, and falls back to `dt-style-checker` when no repo linter exists. |
| `doc-planner` | Caller-assigned | Synthesises Jira data + per-repo diff summaries + confirmed write targets into a documentation checklist the writer follows and `doc-reviewer` checks against. Detects the repo's image policy (local / CDN-upload / ambiguous). |
| `doc-location-finder` | Caller-assigned | Finds the write target(s) in a docs repo — extend-existing, new-page-in-existing-section, or new-section — with confidence scoring. Never writes content. |
| `doc-writer` | Caller-assigned | Writes product documentation for `document:` from a structured handoff file — applies the `doc-planner` checklist, approved per-page write strategies, discrepancy decisions, snippets, screenshots, frontmatter, and internal links. Write-only; never runs git. |
| `counterpart-finder` | Caller-assigned | For a space-constrained `document:` run, finds the OTHER space's existing docs for the feature (in-tree keyword search + `git log --grep`, or an explicit `--counterpart` Jira/PR ref via the diff-summarizer resolver) and returns read-only grounding. Never writes; never an image source. |
| `jira-reader` | Caller-assigned | Reads the pre-exported Jira markdown hierarchy (VI, Epics, Stories, Sub-tasks, Research, RFA) from `$VAULT_PATH/jira-products/<KEY>/`. Parses PR URLs and classifies hosts. Read-only. Used by `document:`, `epics:`, `release-notes:`, `implement:` (multi-source input), `create-ard:`, `specify:`, and `ready:`. |
| `docs-grounder` | Caller-assigned | Read-only documentation grounding on `$DOCS_PATH` for `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `epics:`, and `release-notes:` — retrieves via the `qmd` CLI (falls back to keyword-overlap + `git log --grep`) and returns a bounded digest of `docs_references` (positive grounding: same-feature / analogous-precedent / building-block facts) plus `docs_challenges` (reconciliation prompts, incl. `diverges_from_precedent`). Never writes; advisory only. |
| `idea-reader` | Caller-assigned | Read-only ingester for `idea:` — auto-detects the source type (inline prompt, markdown file with followed wikilinks/images, community post, or an exported Jira ticket — either an RFE or an existing Value Increment the idea extends, parallels, or rewrites) and returns a provenance-tagged normalization. Never writes files. |
| `vault-prior-art-finder` | Caller-assigned | Read-only prior-art discovery on the vault for `idea:` and `create-vi:` — searches `Projects/Products/**` and `Projects/ideas/**` (excluding `Jira - <KEY>/` snapshots, Value Packs, and `_archive/`) and returns a bounded digest of `prior_art` matches (each classified by relation — `same_capability`, `predecessor_phase`, `analogous_precedent`, `supersedes_self`, `adjacent_initiative` — and status-resolved via `_shared/vault-prior-art.md`'s ladder) plus `prior_art_challenges` and a write-path `area_proposal`. Never writes; advisory only. |
| `release-notes-writer` | Caller-assigned | Renders the dynatrace-docs authored release-notes body for a Jira VI or ticket — exactly ONE Summary per run, shaped by the destination it routes to: a `{{#context}}` label + `### title` + prose for `feature-updates` / `breaking-changes`, or one bare past-tense sentence for `fixes`. Emits no Jira IDs, no PR links, and no `{{#internal-note}}` block. Does not write files; returns the draft to the caller. |
| `diff-summarizer` | Caller-assigned | Resolves a single repo's PR diffs and returns a doc-focused summary. GitHub uses the `gh` CLI when available; Bitbucket Cloud / Server + GitHub-fallback use local-git strategies. Designed for parallel invocation (caller caps at 4 concurrent). |
| `code-scanner` | Caller-assigned | Scans one repo for existing capabilities and gaps relative to themes (from an Epic, an implementation spec, or an idea's themes). Fanned out one-per-repo, cap 4 concurrent, with an optional narrow second round for themes round 1 left inconclusive (`_shared/model-routing.md` §8.5, used by `idea:` and `implement:`); evidence entries may carry an optional `lines` array when the match came from a grep hit. Used by `epics:`, `implement:` (multi-source fan-out), and `idea:` (`--ground-code`, broad-then-narrow per `_shared/model-routing.md` §8.5). |
| `epic-writer` | Caller-assigned | Writes child Epic-definition files for `epics:` from a structured handoff file — one file per Epic, following the Epic template, traceable to the `jira-reader` handoff and `code-scanner` evidence. Write-only (vault content); never commits. |
| `impl-maintenance` | Caller-assigned | Post-session lessons-learned analyst. Reads the session handoff, scans `copilot-instructions.md` rules / hooks / reference docs / agents, and returns a structured Lessons Learned report. Suggest-only; does NOT write files. |
| `guideline-reviewer` | Caller-assigned | Reviews Dynatrace app code and UI for compliance with Dynatrace Experience Standards (GUIDElines). Checks AppHeader, DataTable, FilterField, Connections, Permissions, Settings, Dashboards, accessibility/WCAG, terminology, and Grail naming. |
| `api-guideline-reviewer` | Caller-assigned | Reviews OpenAPI specification files against Dynatrace REST API and IAM permission naming guidelines. Checks version consistency, required elements, naming conventions, IAM scope format, HTTP status codes, and schema composition. |

"Caller-assigned" = no fixed pin; tier is assigned by the invoking skill per the `model-routing` policy (mechanical → default session model, synthesis/review → strong tier).

## Model routing

`skills/_shared/model-routing.md` is the single source of truth for complexity
classification, the model fallback chain, and the 8-dimension Opus code-review
checklist. All orchestrators load it at runtime; sub-agents receive the routing
block in their prompt.

| Complexity | Model |
|------------|-------|
| SIMPLE | Default session model |
| MODERATE | Default session model (with structured planning) |
| SIGNIFICANT / HIGH-RISK | Strong tier — `claude-opus-5` / `4.8` / `4.7` / `4.6` or `gpt-5.6` / `gpt-5.5`, pinned via `model:` override |

The strong tier treats Opus 5/4.8/4.7/4.6 and GPT-5.6/5.5 as peers (fallback chain:
Opus 5 → GPT-5.6 → Opus 4.8 → 4.7 → 4.6 → GPT-5.5 → Opus 4.5 → Sonnet 5 → Sonnet 4.6
→ Sonnet 4.5 → GPT-5.4 → Gemini 3.1 Pro Preview).

## Feature highlights

- **Full lifecycle**: `idea:` → `create-vi:` → `create-ard:` → `specify:` →
  `design:` → `epics:` → `implement:` → `document:` → `release-notes:` → `ready:`,
  each with a dedicated Opus/GPT-5.6 reviewer sub-agent.
- **Source-code is the truth, discrepancies escalate to YOU**
  (`_shared/source-truth.md`): every sub-agent that writes or reviews user-visible
  docs verifies enums, labels, defaults, and counts against the actual source.
  When source and Jira disagree, the plugin presents an analysis table and asks
  you per-discrepancy — it never silently picks a winner.
- **Mandatory style checking with fallback**: docs workflows run a style-check
  phase that cannot be skipped. If the repo's linter (Vale, markdownlint, remark)
  is unavailable, `docs-style-checker` falls back to `dt-style-checker` from the
  `dt-style-guide` plugin. Some check is always better than no check.
- **Branch-per-change** with shared **branch-prefix detection**
  (`_shared/branch-naming.md`): resolves the prefix via `$GIT_USER_INITIALS` →
  `git config user.initials` → existing-branch sniff → a per-workflow fallback,
  and asks before falling back. Teams with `<initials>/`-prefix conventions
  (hyphenated or not — `iv-gu`, `ivgu`) set the env var once and every
  branch-creating workflow follows it: `implement:`, `document:`,
  `docs-profile:`, `upgrade:`, `vuln:`. A pattern documented in the repo's own
  `CONTRIBUTING.md` still wins for the name's overall shape.
- **Jira-driven docs & epics**: `document:` (Jira mode) and `epics:` read Obsidian
  vault Jira exports, resolve PR URLs as **pure local-git identifiers** (no
  Bitbucket REST API, no HTTPS fetch), and run parallel `diff-summarizer`s or
  `code-scanner`s per repo. `epics:` Epic drafts carry mandatory inline Jira + PR
  citations; `document:` rendered pages carry none — traceability lives in the
  commit message and the run handoff (`_shared/doc-structure-conventions.md` §1).
- **Repo discovery via `$REPOS_PATH`**: Jira workflows resolve repo URL slugs to
  local clone paths by scanning `$REPOS_PATH` (default `/workspace`; colon-separated
  list supported) and matching `git remote get-url origin`. When multiple clones
  share an upstream, the fast copy (`<slug>-repo`) is auto-preferred.
- **Release-notes draft**: `release-notes:` renders dynatrace-docs block format
  and writes to markdown or stdout — **never** into the docs repo (Jira automation
  owns that path); you paste the draft into Jira and automation re-emits it.
  Staged artifacts are **never** written to `/tmp/` (container restarts wipe it).
- **Test-writing gate**: `implement:` writes tests for all new/changed behaviour
  via `test-writer` and verifies no regressions against a pre-impl baseline. No
  test framework? The workflow asks — it never silently skips.
- **Opus/GPT-5.6 code-review gate**: code workflows run a strong-tier review before
  committing for SIGNIFICANT/HIGH-RISK tasks; `review-fixer` auto-applies fixable
  findings.
- **Post-batch maintenance**: `impl-maintenance` updates the knowledge base,
  `copilot-instructions.md`, and project docs after each workflow.
- **Stateless sub-agents**: every sub-agent receives full context in its prompt —
  no hidden state between calls.

## Not ported from the Claude Code edition

Two features from the upstream Claude Code plugin are intentionally omitted because
they depend on capabilities GitHub Copilot CLI does not expose:

- **Session cost reporting** (`/statusline`, `emit-cost`) — no cost/usage API.
- **Statusline integration** — no statusline extension point.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `notify-done` | Stop | Desktop notification when a workflow completes. |
| `preload-context` | UserPromptSubmit | Injects git/context info on lifecycle-skill triggers (`implement:`, `document:`, `epics:`, `release-notes:`, `vuln:`, `upgrade:`, …). |
| `test-notify` | PostToolUse | Parses test-command output and sends a desktop notification with pass/fail counts. |
| `changelog-owners-reminder` | PostToolUse | Warn-only reminder when a dynatrace-docs content page is edited without a `changelog:` entry dated today, or (managed pages) without the required owners. Always exits 0. |

> Copilot CLI has no `matcher` field for `PostToolUse` (unlike Claude Code) — `test-notify` and `changelog-owners-reminder` both fire on every tool use and self-filter internally (return immediately unless the command was a test runner / the edited file is a dynatrace-docs content page).

## Environment prerequisites

These skills run fine on a bare host, but depend on a few external tools for their richest behaviour:

- **`gh auth login`** — required once on the host to enable `diff-summarizer`'s GitHub PR resolution path. Without it, GitHub URLs fall back to local-git strategies against the cloned repo. No hard failure.
- **No Bitbucket CLI required or assumed.** Bitbucket Cloud and self-hosted Bitbucket Server URLs are resolved purely from the local clone — `diff-summarizer` never makes Bitbucket HTTPS calls.
- **`vale`** (optional but recommended) — when the target docs repo has `.vale.ini`, `docs-style-checker` invokes `vale` first. Falls back to the repo's `package.json` lint script, then to `dt-style-checker` from the `dt-style-guide` plugin.
- **`dt-style-guide` plugin** (optional companion) — `docs-style-checker` falls back to it when no repo-configured linter exists; `epics:` always uses `dt-style-checker` as its primary style gate (vault content has no repo linter). Both plugins are independently installable — without `dt-style-guide`, the fallback is skipped gracefully.
- **`qmd`** (optional) — enables semantic retrieval for `docs-grounder`'s `$DOCS_PATH` documentation grounding. Without it, `docs-grounder` falls back to keyword-overlap + `git log --grep` matching — host users only; the AI Container installs `qmd` automatically.
- **Recommended environment: [ihudak/ai-containers](https://github.com/ihudak/ai-containers).** Mounts every repository and the Obsidian vault under `/workspace` (repos at `/workspace/<repo>`, vault at `/workspace/vault`), installs `gh`, and mounts `~/.config/gh` from the host so `gh auth login` on the host is sufficient. Outside the container, set `$REPOS_PATH` yourself and manage `gh` installation.
- **`$VAULT_PATH` / `$SPECS_PATH` / `$REPOS_PATH`** — see the [repo-root setup guide](../README.md#prerequisites) for the full environment-variable configuration shared across this marketplace's plugins.
- The Jira hierarchy under `$VAULT_PATH/jira-products/<KEY>/` is produced by the [`jira-workitem-import`](https://github.com/ivan-gudak/jira-workitem-import) tool.
- **Follow-up task emission** (`document:`, `release-notes:`, `epics:`, `implement:`) persists out-of-scope / manual-step follow-ups as durable Obsidian tasks via a batch preview. Works without the `obsidian-llm-wiki` plugin (mirrors its task conventions internally). Degrades gracefully: `$VAULT_PATH` → the VI's `$SPECS_PATH` dir → beside the imported Jira directory → report-only. See [`skills/_shared/followup-emission.md`](skills/_shared/followup-emission.md).
- **Specs-repo git completeness (all seventeen skills that write to `$SPECS_PATH`).** The specs repo maintains itself. At run start — as early as `$SPECS_PATH` is known (Phase 0 in most skills, Step 0 in `vuln:`, the shared mode-detection section in `document:`) — `specs-preflight` commits and pushes any artifacts a previous run left behind, retries a commit whose push failed, and settles the branch — switching away only from branches the plugin created, and standing still on anything else. As the run's last action — or, where a later phase cedes control to another skill or a long interactive stretch, immediately before that hand-off — `commit-artifacts` stages the bounded artifact paths, commits `<KEY|NOISSUE> Add dev-workflows session artifacts (<skill>)`, and pushes; for the five VI-authoring skills that opened a specs-repo PR at handoff, that push updates the PR they already opened. It is bounded to two path shapes inside `$SPECS_PATH`, never issues `git add -A` at repository scope, never force-pushes, never deletes a branch with `-D` or a lock file, and never fails the run. A detached HEAD blocks the commit outright and says so loudly — a commit made there would be unreachable and garbage-collectable, and reporting a SHA over it would be a failure that looked like success. See [`skills/_shared/specs-repo-git.md`](skills/_shared/specs-repo-git.md).

## Reference docs

`skills/_shared/` contains the vendored reference docs the skills consult:

- `model-routing.md` — four-level complexity taxonomy, model fallback chain, and the 8-dimension Opus code-review checklist
- `idea-format.md` — the lean one-page `idea.md` format authored by `idea:`
- `vi-format.md` — the Value-Increment format authored by `create-vi:`
- `ard-format.md` — the ARD format (`AD-N: Binds/Prevents/Rule`) authored by `create-ard:`
- `specification-format.md` — the org-standard `specification.md` format authored by `specify:`
- `design-format.md` — the engineering `design.md` format authored by `design:`
- `ard-resolution.md` — most-specific-first ARD resolution (per-area → Epic-level → inherited VI-level) consumed by `design:`, `implement:`, `specify:`, `epics:`
- `vi-source-resolution.md` — Jira-import-first resolution of an existing VI (3-day freshness), consumed by `update-vi:` and `create-vi: --from-vi`
- `grilling-technique.md` — the embedded bounded one-question-at-a-time grilling SSOT (used by `idea:`, `create-vi:`, `update-vi:`, `specify:`, `design:`, `prompt-grill-me:`)
- `next-phase-offer.md` — the role-aware next-step routing graph (PM → PA → PE → Team) emitted at the end of every lifecycle skill
- `session-hygiene.md` — the prepare-checkpoint + role-aware `/compact` suggestion (guidance-only)
- `context-management.md` — mid-run context-window guidance
- `pre-lint.md` — the deterministic advisory pre-reviewer grep checks
- `escalation-rules.md` — canonical `choices:` prompt sets for shared interactive escalation points
- `jira-input-resolution.md` — the shared Jira-input grammar front-end (JiraID / imported-dir / prompt) resolution, plus the `resolve-export-for-key <KEY>` entry point (locates one exact key's export at any depth, most-recently-modified wins on multiple copies) consumed by `idea:` and `vault-prior-art-finder`
- `workflow-states.md` — the readiness rubric + Jira-status → phase mapping consumed by `ready:`
- `dependencies.md` — recommended companions + the external `jira-workitem-import` importer
- `source-truth.md` — implementation-vs-description discrepancy-escalation protocol; §2 also covers a lifecycle-dates claim class (end-of-life / end-of-support / shutdown / sunset / availability), with a milestone-equivalence rule so semantically identical date phrasings are never flagged as discrepancies
- `doc-structure-conventions.md` — the traceability boundary (rendered page carries no source provenance; the commit message and run handoff do), callout scope and adjacency (a callout sits with the option it qualifies, never trailing the whole set), and component-pattern fidelity (reuse the area's established content component for a recurring shape instead of an ad-hoc structure). Consumed by `doc-planner`, `doc-writer`, and `doc-reviewer`
- `docs-grounding.md` — `$DOCS_PATH` documentation grounding: the `resolve-docs-grounding` resolution gate (`${DOCS_PATH:-/workspace/docs}`, read-only, silent-skip), the `dispatch-docs-grounder` procedure, and the grill-rank / writer-attach consumption modes (consulted by `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `epics:`, `release-notes:`)
- `vault-prior-art.md` — `$VAULT_PATH` prior-art discovery (no default, no index, no consent gate): the `resolve-prior-art` gate, the `dispatch-prior-art-finder` procedure, the search scope + exclusions (`Jira - <KEY>/` snapshots, Value Packs, `_archive/`), the status-resolution ladder + short-code map, and the container derivation shared by `idea:`'s write path and `area_proposal` (consulted by `idea:` and `create-vi:`)
- `read-only-repos.md` — read-only repository mounts: the detection probe (`test -w` on the repo and `.git`, plus the `Read-only file system` error as a secondary trigger), what read-only mode skips (`fetch`/`pull`/`switch`/`remote set-head`, and the dirty-tree gate), write-free ref resolution and reading (`ls-tree`, `git grep <ref>`, `git show <ref>:<path>`), the 14-day staleness / ahead-of-ref escalation trigger, and the `prep` output contract (`read_only`, `scanned_ref`, `ref_committed_at`, `head_divergence`). Consumed by `code-scanner`, `diff-summarizer`, and `docs-grounder`, and cited by the eight skills that dispatch them. Writable mounts are unaffected: `git switch` and `git pull --ff-only` remain sanctioned prep on a writable clone
- `prose-formatting.md` — output line-wrapping: never hard-wrap prose; write each paragraph/prose block as one unbroken line, so Obsidian and IntelliJ Idea soft-wrap it for reading and a straight copy-paste into Jira/Grammarly needs no manual cleanup (consumed by `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epic-writer`, `doc-writer`, `release-notes-writer`)
- `branch-naming.md` — branch naming: the **repo's own documented convention wins** (read from its `CONTRIBUTING.md` / `README.md` / `DOCUMENTATION-GUIDELINES.md` / `.github/copilot-instructions.md`), with its segments classified and filled — an identity placeholder from the `$GIT_USER_INITIALS` → `git config user.initials` → existing-branch-inference → prompt ladder, an issue-key segment from the run's resolved Jira key, the description from each workflow's own slug rule; a pattern with no identity segment never gets one. Only when the repo documents nothing does the ladder supply the whole prefix (per-workflow fallback `feat/` / `docs/` / `fix/` / `chore/`). Consumed by `implement:`, `document:`, `docs-profile:`, `upgrade:`, and `vuln:` (via `vuln-fixer`)
- `toolchain-preflight.md` — the Phase 0 environment check: derives the run's required tool set from the resolved profile (`commands.*`, `commands.per_space.*`, `dev_servers`, `prerequisites`), the repo's config signals (`.vale.ini`, lockfiles, `node_modules/`, `.markdownlint.json`, `.remarkrc*`), and the repo's own documented `Prerequisites` section; maps each tool to the gates it powers so the run can state its outcome before it happens; prompts only when something is missing, recommending Cancel so a run started in the wrong container stops before writing. Consumed by `document:` (both modes)
- `gate-ledger.md` — the six-outcome vocabulary (`RAN` / `DEGRADED` / `FAILED` / `UNAVAILABLE` / `SKIPPED_BY_USER` / `NOT_APPLICABLE`) with **no orchestrator-assignable skip**: every non-run path ends in a named missing precondition, a named missing tool, or the user's verbatim decision. Carries the `document:` gate registry, the `UNAVAILABLE` conversion prompt, and the reviewer contract that makes a missing or unattributed row a BLOCKER. Consumed by `document:` (both modes); written generically for other skills to adopt
- `repo-verification-gates.md` — finding and extracting a docs repo's **own** pre-PR checklist (`CONTRIBUTING.md` `## PR checklist` and its equivalents) and turning it into the `repo_verification_gates` block: which headings to look for, which items are checkable against the written files, and the rule that a repo gate augments but never overrides a built-in reference. Applied by `doc-planner` in Jira mode and by the orchestrator itself in direct mode, which has no planner
- `fix-vuln/nvd-api.md`, `fix-vuln/build-systems.md` — NVD API shape and build-system detection for `vuln:`
- `upgrade/ecosystems.md`, `upgrade/compatibility.md`, `upgrade/lts-sources.md` — ecosystem detection, compatibility constraints, LTS lookups for `upgrade:`
- `handoff/` — per-agent handoff schemas (`code-scanner`, `diff-summarizer`, `impl-maintenance`, `jira-reader`, `release-notes-writer`, `test-baseliner`, `upgrade-executor`, `upgrade-planner`, `vuln-fixer`, `vuln-research`)
- `api-guidelines/` — Dynatrace REST API and IAM permission naming guidelines (consulted by `api-guideline-reviewer:`)
- `guidelines/` — Dynatrace Experience Standards reference docs and checklist template (consulted by `guideline-reviewer:`)
- `dynatrace-docs/multi-space-writing.md`, `dynatrace-docs/render-verification.md`, `dynatrace-docs/frontmatter-guidelines.md`, `dynatrace-docs/changelog-guidelines.md`, `dynatrace-docs/managed-owners.txt`, `dynatrace-docs/docs-profile-schema.md`, `dynatrace-docs/docs-profile.default.yml` — dynatrace-docs-specific writing, frontmatter, and profile rules consumed by `document:` (Jira mode) and `docs-profile:`; the schema and default profile now also carry the `announcement_pages` block (`{postid, path, kinds}`) naming a repo's hand-authored, cross-cutting destination pages so `doc-location-finder` can propose one as an additional target alongside the feature-subtree write, plus the `images.policy` CDN-immutability statement (a new or replacing screenshot is always a new URL; an image is never refreshed in place)
- `dynatrace-docs/anchor-conventions.md` — one `{:#id}` per heading (multi-anchor unsupported), the four verified link forms (whole-page, cross-page-section, same-page-section, `{{#tabgroup anchor=}}`), the `pnpm docstack validate-anchors` contract, and the rule that a product `dt-url` deep link's anchor wins reconciliation. Consumed by `doc-writer`, `doc-reviewer`, and `doc-planner`
- `feedback-emission.md` — the session-feedback emitter shared by the automatic maintenance phases and the `feedback:` / `prompt*:` skills
- `finish-and-handoff.md` — how `document:` (Jira mode) finishes a run (squash, opt-in push, host-aware copy-paste PR draft)
- `followup-emission.md` — the end-of-run follow-up task emitter shared by `document:`, `release-notes:`, `epics:`, and `implement:`
- `specs-repo-git.md` — the two specs-repo git entry points shared by all seventeen skills that write into `$SPECS_PATH`: `specs-preflight` (run start — flush leftover artifacts, retry an unpushed artifact commit, settle the branch) and `commit-artifacts` (terminal — stage the bounded artifact paths, commit, push). Owns the bounded write authority (two path shapes; `^(vi|ard|spec|design)/` branches only), the three guards and their four-part notice contract, the branch-disposition table, and the `Specs repo:` outcome line. Always `git -C "$SPECS_PATH"`, never a `cd`; never force-pushes; never fails the run.

> There is no `references/cost-emission.md` or statusline reference doc on this side — [session cost reporting is not ported](#not-ported-from-the-claude-code-edition).

## Architecture (ARD) consumption

`design:`, `implement:`, and `specify:` respect the applicable **ARD** (produced by `create-ard:`) when one exists — resolved via `_shared/ard-resolution.md` (most-specific first: per-area → Epic-level → inherited VI-level `AD-N`). A design / implementation / spec that violates an `AD-N` Rule without a recorded "ARD deviation" (flagged to the architect) is a reviewer **BLOCKER**. When no ARD exists these skills behave exactly as before — the check is skipped — and `vuln:` / `upgrade:` are unaffected.

## Dependencies & companions

dev-workflows is self-contained — no skill hard-requires another plugin. Recommended companions
(`dt-style-guide`) and the external
[`jira-workitem-import`](https://github.com/ivan-gudak/jira-workitem-import) importer are documented in
[`skills/_shared/dependencies.md`](skills/_shared/dependencies.md); every relationship is convention +
runtime-resolve + graceful fallback.

## License

[MIT](LICENSE)
