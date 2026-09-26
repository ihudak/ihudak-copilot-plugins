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

## Path-specific instruction files

Two files under `.github/instructions/` hold rules that apply only while Copilot is working with
a matching file — they load automatically for a matching file in Copilot CLI, VS Code, and the
cloud agent, never at session start, and never for a file outside their `applyTo` glob. Each opens
with its own header paragraph restating this. Read the matching file before editing there, the
same way you would read an area's own docs first.

| File | `applyTo` | Holds |
|---|---|---|
| `.github/instructions/dev-workflows-shared.instructions.md` | `dev-workflows/skills/_shared/**,dev-workflows/agents/**` | The `_shared/` directory catalogue — what each shared reference under `dev-workflows/skills/_shared/` is the single source of truth for, and who consumes it. |
| `.github/instructions/dev-workflows-skill-map.instructions.md` | `dev-workflows/skills/**,dev-workflows/agents/**` | The `dev-workflows` plugin's skill-relationship map (the lifecycle diagram, shared sub-agents, standalone reviewers) and its invariants (VI-creation flow, the three code orchestrators, `implement:`, `document:` doc-edit mode, `document:` jira mode and `epics:`). |

Both files are also honoured by Copilot code review, subject to the 4,000-character read
described below, and by VS Code and the cloud agent.

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

`scripts/validate-catalog.py` also enforces this file's own size budget and its sibling `.github/instructions/*.instructions.md` files' size and `applyTo` shape — see § Instruction-file size gate below.

## Requirement-ID grammar

Every requirement ID a plugin doc teaches is the bracketed `[PREFIX#N]` form — `[US#1]`, `[AC#1]`, `[SM#1]`, `[SMC#1]`, `[UC#1]`, `[FR#1]` in a VI and `[AD#1]` in an ARD — never the dash-separated form. A dash-separated ID has the shape of a Jira issue key, so pasting a VI, ARD, or Epic draft into Jira auto-links it to an unrelated real ticket in any project sharing the prefix, and the vault importer rewrites it into a triple-bracketed wikilink on export. `skills/_shared/pre-lint.md`'s `## Jira-key collision` check catches it at authoring time in `create-vi:`, `update-vi:`, `create-ard:`, and `epics:`; `vi-reviewer`, `ard-reviewer`, `epic-reviewer`, and `readiness-reviewer` treat a survivor as a BLOCKER.

`scripts/check-id-grammar.sh` enforces it across the repo — run `./scripts/check-id-grammar.sh --root .` locally before pushing; it also runs on every push via `.github/workflows/validate-catalog.yml`, preceded there by `--selftest`, which asserts the gate's exit code against each fixture, so a gate that has stopped being able to fail shows up as a red build instead of a green one. `CHANGELOG.md` is excluded (history keeps the old form), and a line that has to quote the legacy form in order to forbid or report it carries an `id-grammar-ok` HTML-comment marker — ten such lines across six files (six accept the legacy form as tolerant readers, three forbid it at an authoring gate, and one reports it without gating), audited per file so the marker never becomes a general escape hatch. The `specify:` / `design:` numbered-ID namespace is deliberately outside this grammar and unchanged; `scripts/spec-id-baseline.txt` is its census tripwire.

This rule applies repo-wide — the gate scans every tracked markdown file, not just `dev-workflows/`'s — so it stays in this tier-1 file rather than moving to a path-scoped one.

## Adding a new plugin

1. Create `<plugin-name>/` at the repo root
2. Add `.plugin/plugin.json` using the format above
3. Add skills under `<plugin-name>/skills/<skill-name>/SKILL.md`
4. Update path references to use `~/.copilot/installed-plugins/ihudak-copilot-plugins/<plugin-name>/skills/`
5. Add `LICENSE` and `README.md`
6. **Add an entry to `.github/plugin/marketplace.json`** under `plugins`
7. Register in `settings.json` under `enabledPlugins`: `"<plugin-name>@ihudak-copilot-plugins": true`

## Instruction-file size gate

`scripts/validate-catalog.py` fails this file above 40,000 characters and warns above 36,000,
and warns on any `.github/instructions/*.instructions.md` file above 20,000 characters; it also
fails a `.github/instructions/**/*.instructions.md` file with no non-empty `applyTo` frontmatter
string, or whose `applyTo` has a comma-separated glob matching no file in the repository. Run
`python3 scripts/validate-catalog.py` locally before pushing; `--selftest` exercises both red and
green cases and runs in CI immediately before the normal check. Overflow belongs in a narrower
`.github/instructions/*.instructions.md` file, or, for evidence and history rather than rule,
in `docs/maintainers/rationale.md` — never auto-loaded, so nothing gates its size.

**Copilot code review reads only the first 4,000 characters of any custom instruction file** —
this one included. That is why the structure, manifest-format, and skill/agent rules sit ahead of
everything else in this file: a reviewer that never reads past character 4,000 still gets the
rules that apply to any file it is reviewing.

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
