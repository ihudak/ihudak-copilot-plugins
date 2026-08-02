# PORT-TRANSFORM-SPEC — Claude command/agent/ref → Copilot skill/agent/ref

Reusable transform rules for porting `ihudak-claude-plugins` dev-workflows files
to `ihudak-copilot-plugins`. Apply VERBATIM copy + these token/structure transforms.
**Do NOT paraphrase, summarize, or reword prose.** Change only what the rules below say.

## Layout mapping
- Claude `commands/<x>.md` → Copilot `dev-workflows/skills/<x>/SKILL.md`
- Claude `agents/<x>.md`   → Copilot `dev-workflows/agents/<x>.md`
- Claude `references/<x>.md` (cross-consumed) → Copilot `dev-workflows/skills/_shared/<x>.md`
- Claude `references/dynatrace-docs/*` → Copilot `dev-workflows/skills/_shared/dynatrace-docs/*`

## A. Skill frontmatter (from a Claude command)
Claude command frontmatter:
```
---
name: <x>
description: <prose>
allowed-tools: Read Edit Write Bash Glob Grep Task WebFetch LS   # space-separated Claude names
---
```
Copilot skill frontmatter:
```
---
name: <x>
description: >
  <same prose, unchanged>
  Activated when the user prompt starts with "<x>:".
allowed-tools: <comma-separated mapped tools>
---
```
Tool-name map (dedupe, preserve order, drop unmappable):
Read→view, Write→create, Edit→edit, MultiEdit→edit, Bash→bash, Glob→glob,
Grep→grep, LS→(drop; glob covers it), Task→task, WebFetch→web_fetch,
AskUserQuestion→ask_user, TodoWrite→sql.
**Always ADD `ask_user`** if the body uses `choices:` prompts (they all do).
Typical result: `view, edit, create, bash, glob, grep, task, web_fetch, ask_user`.

## B. Agent frontmatter (from a Claude agent)
Claude:
```
---
name: <x>
description: <prose ending "Uses Claude Opus.">
model: opus                      # may be absent
tools: ["Read", "Glob", "Grep", "LS"]
---
```
Copilot:
```
---
name: <x>
description: "<same prose, but replace 'Uses Claude Opus.' → 'Uses the strong reasoning tier (Opus 4.8/4.7/4.6 or GPT-5.5), pinned by the caller.'>"
tools: [view, glob, grep]        # mapped, unquoted; DROP the model: line entirely
---
```
- DROP `model:` frontmatter (Copilot pins model via the caller's `task(model:)`).
- Map tools same as §A; unquoted list.

## C. Body transforms (both skills and agents)

1. **`$ARGUMENTS`** → "the argument (text following the `<x>:` trigger)". Keep meaning; reword minimally.

2. **Plugin path variable:**
   - `${CLAUDE_PLUGIN_ROOT}/references/<f>.md` → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/<f>.md`
   - `${CLAUDE_PLUGIN_ROOT}/references/model-routing/classification.md` → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`
   - `${CLAUDE_PLUGIN_ROOT}/references/dynatrace-docs/<f>` → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/<f>`
   - `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`
   - any remaining `${CLAUDE_PLUGIN_ROOT}` → `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows`

3. **model-routing SKILL → doc reference.** Claude commands invoke a `model-routing`
   skill to resolve paths (e.g. "Invoke the `model-routing` skill (Skill tool,
   `skill: "dev-workflows:model-routing"`), then record:"). Copilot has NO model-routing
   skill — replace such invocations with: "Load and follow the model-routing policy at
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then record:".
   Likewise any `dynatrace-docs-frontmatter` skill invocation stays as a skill reference
   (that skill IS ported), rendered `dev-workflows:dynatrace-docs-frontmatter`.

4. **Agent dispatch:** `subagent_type: "dev-workflows:<a>"` → `agent_type: "dev-workflows:<a>"`.
   Keep the `model:` argument on the dispatch (it pins the sub-agent's model). Convert any
   `→ Agent (subagent_type: ...)` prose to `→ task(agent_type: "dev-workflows:<a>", model: <...>)`.

5. **Model IDs** (version hyphen→dot; map non-existent Sonnet-5):
   `claude-opus-4-8`→`claude-opus-4.8`, `4-7`→`4.7`, `4-6`→`4.6`, `4-5`→`4.5`;
   `claude-sonnet-5`→`claude-sonnet-4.6`; `claude-sonnet-4-6`→`claude-sonnet-4.6`;
   `claude-sonnet-4-5`→`claude-sonnet-4.5`. Detection chain phrases like
   "§2.1 Sonnet chain: claude-sonnet-5, fallback claude-sonnet-4-6/4-5" →
   "§2.1 detection chain: claude-sonnet-4.6, fallback claude-sonnet-4.5/gpt-5.4".
   "§2 Opus chain" phrasing may stay (it maps to the strong tier).

6. **Plugin slash-commands → flat keyword triggers** (colon suffix, no slash), inside backticks too:
   /implement→implement:, /document→document:, /epics→epics:, /vuln→vuln:, /upgrade→upgrade:,
   /idea→idea:, /create-vi→create-vi:, /create-ard→create-ard:, /specify→specify:, /design→design:,
   /ready→ready:, /release-notes→release-notes:, /docs-profile→docs-profile:, /feedback→feedback:,
   /prompt-brainstorm→prompt-brainstorm:, /prompt-grill-me→prompt-grill-me:, /prompt→prompt:,
   /api-guideline-reviewer→api-guideline-reviewer:, /guideline-reviewer→guideline-reviewer:.
   `/prompt*` → `prompt:*`.

7. **CLI built-ins — KEEP as `/slash`** (Copilot CLI built-ins, do NOT convert):
   `/compact`, `/clear`, `/rename`, `/context`, `/new`, `/resume`.

8. **State labels — keep verbatim:** tokens like `/done` that denote a Jira/workflow status
   (not a plugin command in the list above) stay as-is.

9. **Product names:** "Claude Code"→"Copilot CLI"; "Claude" meaning the agent/product→"Copilot".
   Keep "Claude" inside model IDs (claude-opus-4.8) and factual historical notes untouched.

10. **`.claude-plugin/marketplace.json`** → `.github/plugin/marketplace.json`.

## D. SKIPPED FEATURES — prune cleanly (no dangling refs)
- **Cost reporting.** Remove every cost sub-step and reference:
  - Drop references to `cost-emission.md`, `emit-cost`, `session-cost`, `cost-prices`.
  - Command maintenance phases are titled "Session maintenance, feedback & cost" with a
    numbered "**Session cost (ALWAYS runs).**" step (usually the last numbered step). DELETE that
    whole step, renumber remaining steps, and rename the phase heading to
    "Session maintenance & feedback". Fix the "Final report" line that mentions "the cost path
    (or notice)" — delete that clause.
  - Keep the `impl-maintenance` step and the feedback (`emit-auto` / `feedback-emission.md`) step.
- **statusline.** Remove any mention of the plugin's `/statusline` command / status line install.
- Do NOT remove the `feedback-emission.md` / `followup-emission.md` mechanisms (those are kept).

## E. Verification (run after writing; report output)
For each ported file, expect ZERO matches (except intentional historical notes):
```
grep -nE 'CLAUDE_PLUGIN_ROOT|~/\.claude/|cost-emission|emit-cost|session-cost|cost-prices|statusline|/implement\b|/document\b|/epics\b|/create-vi\b|/create-ard\b|/specify\b|/design\b|/ready\b|/idea\b|claude-opus-4-[0-9]|claude-sonnet-5' <file>
```
Confirm YAML frontmatter parses (skill has `allowed-tools:`, agent has `tools:` and NO `model:`).
