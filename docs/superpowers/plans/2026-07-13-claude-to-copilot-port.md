---
tags:
  - tasks-exclude
---

# Claude → Copilot Marketplace Port — Implementation Plan

> **For agentic workers:** Execute increment-by-increment with a checkpoint after each.
> Steps use checkbox (`- [ ]`) syntax. This is a **content-transformation** port
> (markdown skills/agents), so "tests" are validation greps: valid YAML frontmatter,
> no dangling refs, no `${CLAUDE_PLUGIN_ROOT}`, no `~/.claude/`, no `/command` refs,
> no references to skipped features.

**Goal:** Bring Copilot `dev-workflows` (1.8.2) to functional parity with Claude
`dev-workflows` (2.30.0), minus skipped cost/statusline features.

**Architecture:** Port Claude `commands/*.md` → Copilot `skills/<x>/SKILL.md`;
`agents/*.md` → `agents/*.md`; `references/*` → consuming skill `references/` or
`skills/_shared/`. Flat trigger grammar mirroring Claude 1:1.

**Tech Stack:** Markdown + YAML frontmatter; Copilot CLI plugin conventions.

## Global Constraints

- Skill frontmatter: `name`, `description` (keyword-prefix trigger), `allowed-tools:` (comma list).
- Agent frontmatter: `name`, `description`, `tools:` (array). No `allowed-tools:`.
- Body path refs: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/...`
- Hook/script path refs: `${PLUGIN_ROOT}`.
- Model IDs (dots, real Copilot task-tool IDs): `claude-opus-4.8/4.7/4.6/4.5`,
  `claude-sonnet-4.6/4.5`, `claude-haiku-4.5`, `gpt-5.5/5.4/5.4-mini`, `gemini-3.1-pro-preview`, `gemini-3.5-flash`.
- Strong (reasoning) tier = {`claude-opus-4.8`,`4.7`,`4.6`, `gpt-5.5`} peers; prefer current model; GPT-5.5 first-class.
- Detection (mid-tier) chain = `claude-sonnet-4.6` → `claude-sonnet-4.5` → `gpt-5.4` (announce degradation only past Sonnet).
- Agent dispatch: `task(agent_type: "dev-workflows:<name>", model: "<id>", ...)`.
- Flat triggers: `implement: document: epics: vuln: upgrade: idea: create-vi: create-ard: specify: design: ready: release-notes: docs-profile: feedback: prompt: prompt-brainstorm: prompt-grill-me: api-guideline-reviewer: guideline-reviewer:`
- Never port: `statusline`, `session-cost.py`, `cost-emission.md`, `cost-prices.yaml`, or any reference to them.
- Log Claude source bugs to `FOUND-CLAUDE-BUGS.md` (never fix in source).

---

## Increment 1 — Foundation

**Files:**
- Modify: `dev-workflows/skills/_shared/model-routing.md` (merge Claude classification.md §2.1/§8/§9 + GPT-5.5 peer tier + detection_model)
- Create: `dev-workflows/skills/_shared/session-hygiene.md`
- Create: `dev-workflows/skills/_shared/workflow-states.md`
- Create: `dev-workflows/skills/_shared/next-phase-offer.md`
- Create: `dev-workflows/skills/_shared/jira-input-resolution.md`
- Create: `dev-workflows/skills/_shared/grilling-technique.md`
- Create: `dev-workflows/skills/_shared/followup-emission.md`
- Create: `dev-workflows/skills/_shared/feedback-emission.md`
- Create: `dev-workflows/skills/_shared/finish-and-handoff.md`
- Create: `dev-workflows/skills/_shared/pre-lint.md`
- Create: `dev-workflows/skills/_shared/context-management.md`
- Reconcile: `dev-workflows/skills/_shared/source-truth.md` vs Claude `escalation-rules.md` + `source-truth.md`
- Create: `dev-workflows/hooks/changelog-owners-reminder.sh` + `.py`
- Modify: `dev-workflows/hooks/hooks.json` (add changelog reminder; keep no-matcher note)
- Modify: `dev-workflows/hooks/preload-context.sh` (add new trigger keywords)

- [ ] **T1.1 — Merge model-routing.md.** Take current Copilot `_shared/model-routing.md`
  as base (it already has dot-form IDs + GPT-5.5). Add from Claude classification.md:
  §2.1 detection chain (map Sonnet→`claude-sonnet-4.6`→`4.5`→`gpt-5.4`), §8 large-input
  fan-out (verbatim, fix `/implement`→`implement:`, `/epics`→`epics:`, `/document`→`document:`),
  §9 per-step routing (verbatim, same trigger fixes), and `detection_model` field in §4 block.
  Reframe §2: strong tier = Opus 4.8/4.7/4.6 + GPT-5.5 as peers (no "degradation" wording for GPT-5.5).
  Update §1.1 multi-source floor bullet. Fix all `${CLAUDE_PLUGIN_ROOT}` and `/command` refs.
- [ ] **T1.2 — Port shared refs** (verbatim copy + transform rules) for: session-hygiene,
  workflow-states, next-phase-offer, jira-input-resolution, grilling-technique,
  followup-emission, feedback-emission, finish-and-handoff, pre-lint, context-management.
  Prune any statusline/cost references.
- [ ] **T1.3 — Reconcile source-truth.** Compare Claude `source-truth.md` + `escalation-rules.md`
  against existing Copilot `_shared/source-truth.md`; port the escalation protocol delta.
- [ ] **T1.4 — Hooks.** Port `changelog-owners-reminder.{sh,py}` (`${CLAUDE_PLUGIN_ROOT}`→`${PLUGIN_ROOT}`);
  add to `hooks.json` PostToolUse (no matcher; script self-gates on file-edit tools).
  Update `preload-context.sh` keyword triggers to the flat grammar.
- [ ] **T1.5 — Validate.** grep for `${CLAUDE_PLUGIN_ROOT}`, `~/.claude`, `/implement`, `/document`,
  `session-cost`, `statusline`, `cost-emission` across new/modified files → expect none (except
  intentional migration notes). Confirm YAML frontmatter where applicable.
- [ ] **T1.6 — Commit.** `git add` the new/modified files; commit
  `feat(dev-workflows): foundation — model-routing §2.1/§8/§9, shared refs, changelog hook`.

**Validation (T1.5) commands:**
```bash
cd /workspace/ihudak-copilot-plugins
grep -rn 'CLAUDE_PLUGIN_ROOT\|~/.claude\|/implement\b\|/document\b\|session-cost\|statusLine\|cost-emission\|cost-prices' dev-workflows/skills/_shared dev-workflows/hooks || echo "CLEAN"
```

---

## Increment 2 — VI-creation lifecycle (detail at checkpoint)

**Skills (commands→skills):** idea, create-vi, create-ard, specify, design, ready.
**Agents:** idea-reader, vi-reviewer, ard-reviewer, spec-reviewer, design-reviewer, readiness-reviewer.
**Refs:** idea-format, vi-format, ard-format, ard-resolution, specification-format, design-format.
Each command/agent: apply Global Constraints transforms; pin reviewers to strong tier; validate.

## Increment 3 — Docs / epics / release-notes (detail at checkpoint)

**Skills:** docs-profile (new), release-notes (new), document (consolidate impl-docs + impl-jira docs mode), epics (split from impl-jira).
**Agents:** doc-writer, epic-writer, release-notes-writer.
**Refs:** dynatrace-docs/* (docs-profile-schema, docs-profile.default.yml, frontmatter-guidelines, multi-space-writing, render-verification, changelog-guidelines, managed-owners.txt).
Bring document/epics to 2.30 parity (Phase 5.8 discrepancy escalation, multi-space write safety, docs-profile preflight). Add dynatrace-docs-frontmatter skill + model-routing skill wrapper if needed.

## Increment 4 — Utilities (detail at checkpoint)

**Skills:** feedback, prompt, prompt-brainstorm, prompt-grill-me. Reuse Increment-1 refs.

## Increment 5 — Existing-workflow sync (detail at checkpoint)

Rename triggers flat: impl:code:→implement:, fix-vuln:→vuln:. Retire impl-dispatcher.
Bring implement/vuln/upgrade to 2.30 parity: multi-source fan-out (§8), session-hygiene,
next-phase-offer, finish-and-handoff. Update every internal cross-reference.

## Increment 6 — Marketplace wiring (detail at checkpoint)

README (root + plugin), CHANGELOG, `.github/plugin/marketplace.json`,
`.github/copilot-instructions.md`, `.plugin/plugin.json` (version→2.0.0, keywords,
skills/agents dir paths). Final dangling-ref sweep across whole plugin.

---

## Self-Review notes
- Spec coverage: every Claude command/agent/ref (minus skip list) maps to a task above.
- Skipped explicitly: statusline, session-cost.py, cost-emission.md, cost-prices.yaml.
- Type consistency: model IDs use dot form throughout; agent dispatch prefix `dev-workflows:`.
