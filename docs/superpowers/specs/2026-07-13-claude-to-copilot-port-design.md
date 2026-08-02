---
tags: tasks-exclude
type: design
project: dev-workflows copilot port
date: 2026-07-13
status: approved
---

# Claude → Copilot Marketplace Port — Design

## 1. Goal

Bring the **Copilot** plugin marketplace (`/workspace/ihudak-copilot-plugins`,
`dev-workflows` at **1.8.2**) up to parity with the **Claude** marketplace
(`/workspace/ihudak-claude-plugins`, `dev-workflows` at **2.30.0**), porting every
feature that is portable to GitHub Copilot CLI, adapting those that need it, and
skipping those that cannot exist in Copilot.

End state: Copilot `dev-workflows` reaches functional parity with Claude 2.30.0
minus the skipped cost/statusline features, installable and working via
`copilot plugin install dev-workflows@ihudak-copilot-plugins`.

## 2. Source of truth for behaviour

For every ported command/agent, the **Claude file is the behavioural spec**. The
supporting specs/plans live in
`/workspace/obsidian/Projects/AI-First/dev-workflows - docs automation/{plan,spec,research}`
and explain *why* each feature exists. When Claude file and spec disagree, the
Claude file (shipped behaviour) wins; discrepancies are logged to
`FOUND-CLAUDE-BUGS.md` in this folder.

## 3. Approved decisions

1. **Skip** (Claude-Code-only, no Copilot equivalent): `/statusline` +
   `scripts/statusline-command.sh`; cost reporting (`scripts/session-cost.py`,
   `references/cost-emission.md`, `references/cost-prices.yaml`). All dangling
   references to these are pruned.
2. **Full parity**, executed in 6 increments (below), checkpoint after each.
3. **Flat trigger grammar** mirroring Claude 1:1. Consolidations:
   `impl:code:`→`implement:`; `impl:docs:` + `impl:jira:docs:` → one `document:`
   (mode auto-detected); `impl:jira:epics:`→`epics:`; `fix-vuln:`→`vuln:`;
   `upgrade:` unchanged. `impl-dispatcher` retired/repurposed. All internal
   cross-refs + `.github/copilot-instructions.md` updated.
4. **Model routing**: strong tier = {`claude-opus-4.8`/`4.7`/`4.6`, `gpt-5.5`} as
   peers; prefer the orchestrator's current model; GPT-5.5 is first-class (no
   "degradation" language). Port classification.md §8 large-input fan-out.

## 4. Structural transform rules (Claude → Copilot)

| Claude | Copilot |
|---|---|
| `commands/<x>.md` | `skills/<x>/SKILL.md` + `allowed-tools:` frontmatter, keyword-prefix trigger in `description` |
| `agents/<x>.md` (`subagent_type`) | `agents/<x>.md` (`tools:` frontmatter), dispatched `task(agent_type:"dev-workflows:<x>")` |
| `${CLAUDE_PLUGIN_ROOT}/...` (agent/skill bodies) | `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/...` |
| `${CLAUDE_PLUGIN_ROOT}` (hooks.json/scripts) | `${PLUGIN_ROOT}` |
| `.claude-plugin/plugin.json` | `.plugin/plugin.json` (`skills:`/`agents:` = dir paths) |
| PostToolUse `matcher` | dropped; scripts self-gate and exit 0 |
| `opus`/`sonnet`/`haiku` | `claude-opus-4.8`, `claude-sonnet-4.6`, `claude-haiku-4.5`, `gpt-5.5`, … |
| `references/<x>.md` (flat) | consuming skill's `references/`, or `skills/_shared/` for cross-skill |
| `$ARGUMENTS` (Claude arg macro) | the text following the keyword trigger |

Frontmatter conventions (from `.github/copilot-instructions.md`):
- Skills: `name`, `description` (with trigger), `allowed-tools:` (comma list).
- Agents: `name`, `description`, `tools:` (array). No `allowed-tools:`.

## 5. Increment plan

### Increment 1 — Foundation (shared refs, model routing, hooks)
- Extend `skills/_shared/model-routing.md`: GPT-5.5 as first-class strong-tier
  peer; port §8 large-input fan-out (SIGNIFICANT floor + jira-reader→code-scanner×N
  cap 4 → synthesis).
- Port shared reference docs into `skills/_shared/` (or a new `references/`):
  `session-hygiene.md`, `workflow-states.md`, `next-phase-offer.md`,
  `jira-input-resolution.md`, `grilling-technique.md`, `followup-emission.md`,
  `feedback-emission.md`, `finish-and-handoff.md`, `pre-lint.md`,
  `context-management.md`, `escalation-rules.md` (reconcile with existing
  `source-truth.md`).
- Hooks: add `changelog-owners-reminder.{sh,py}`; update `hooks.json` (no matchers,
  `${PLUGIN_ROOT}`). Verify `preload-context.sh` triggers include new keywords.

### Increment 2 — VI-creation lifecycle
- Skills: `idea:`, `create-vi:`, `create-ard:`, `specify:`, `design:`, `ready:`.
- Agents: `idea-reader`, `vi-reviewer`, `ard-reviewer`, `spec-reviewer`,
  `design-reviewer`, `readiness-reviewer`.
- Refs: `idea-format.md`, `vi-format.md`, `ard-format.md`, `ard-resolution.md`,
  `specification-format.md`, `design-format.md`, `workflow-states.md` (shared).

### Increment 3 — Docs / epics / release-notes
- Skills: `docs-profile:`, `release-notes:`; consolidate `document:`; split `epics:`.
- Agents: `doc-writer`, `epic-writer`, `release-notes-writer`.
- Refs: `dynatrace-docs/*` (docs-profile schema + default, frontmatter, multi-space,
  render-verification, changelog, managed-owners), `handoff/*` for new agents.
- Bring `document`/`epics` to 2.30 parity (discrepancy escalation Phase 5.8,
  multi-space write safety, docs-profile preflight).

### Increment 4 — Utilities
- Skills: `feedback:`, `prompt:`, `prompt-brainstorm:`, `prompt-grill-me:`.
- Uses `feedback-emission.md`, `grilling-technique.md` (from Increment 1).

### Increment 5 — Existing-workflow sync
- Bring `implement:`(`impl`), `vuln:`(`fix-vuln`), `upgrade:` to 2.30 parity:
  multi-source fan-out, session-hygiene blocks, next-phase-offer, finish-and-handoff.
- Rename triggers to flat grammar; retire/repurpose `impl-dispatcher`.

### Increment 6 — Marketplace wiring
- `README.md` (root + plugin), `CHANGELOG.md`, `.github/plugin/marketplace.json`,
  `.github/copilot-instructions.md`, `.plugin/plugin.json` version → target
  (e.g. 2.0.0), keywords, skills/agents dir paths.
- Final consistency sweep for dangling refs (skipped features, old triggers).

## 6. Validation per increment
- Each new skill has valid YAML frontmatter with `allowed-tools`.
- Each new agent has `name`/`description`/`tools` and is dispatchable.
- No `${CLAUDE_PLUGIN_ROOT}`, no `~/.claude/`, no `/command` refs remain in ported files.
- No references to skipped features remain.
- `plugin.json` `skills`/`agents` dir paths resolve; marketplace.json version bumped.

## 7. Out of scope
- `dt-style-guide` and `obsidian-llm-wiki` deep sync (Copilot versions equal/ahead;
  touch only where dev-workflows cross-references them).
