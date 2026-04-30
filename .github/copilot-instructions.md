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
    └── skills/
        ├── _shared/            ← cross-skill reference docs (not a skill itself)
        └── <skill-name>/
            ├── SKILL.md        ← required; the skill definition
            └── references/     ← optional supporting docs read at runtime
```

## Plugin manifest format

`.plugin/plugin.json` is the canonical Copilot CLI manifest. The `skills` field is a **directory path**, not an array:

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
  "skills": "./skills/"
}
```

Do **not** put `plugin.json` under `.github/plugin/` — that path is not read by the Copilot CLI.

## SKILL.md format — two distinct types

### Orchestrator skills
Top-level user-facing skills. Must have `allowed-tools:` in YAML frontmatter. Triggered by a keyword the user types.

```yaml
---
name: skill-name
description: >
  Activated when the user prompt starts with "keyword:".
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---
```

### Sub-agent skills
Invoked only by orchestrators via the `task` tool. Must **not** have `allowed-tools:`. No frontmatter except `name:` and `description:`.

```yaml
---
name: sub-agent-name
description: >
  Receives <X> and returns <Y>. Invoked by <orchestrator>.
---
```

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
- Model fallback chain (Opus 4.7 → 4.6 → 4.5 → Sonnet 4.6 → Sonnet 4.5)
- The 8-dimension mandatory Opus code-review checklist
- The `model_routing` YAML block format passed between orchestrators and sub-agents
- The `phase: verify-resume` protocol for gating tests on Opus review

All orchestrators must load and follow `model-routing.md` at the start of every invocation. Sub-agents receive the `model_routing` block in their prompt; they do not re-read the file.

## `dev-workflows` plugin — skill relationships

```
impl:code: / impl:  → [rubber-duck@Opus plan critique] → impl → [code-review@Opus] → review-fixer → test-writer → tests → impl-maintenance
impl:docs:          → impl-docs → [doc-reviewer] → impl-maintenance
fix-vuln:           → vuln-research → vuln-fixer → [code-review@Opus] → review-fixer → tests → impl-maintenance
upgrade:            → upgrade-planner → upgrade-executor → [code-review@Opus] → review-fixer → tests → impl-maintenance
                    └── test-baseliner (used by upgrade-executor, vuln-fixer, and impl:code:)
                    └── test-writer    (used by impl:code: only — Phase 3.7)
                    └── doc-reviewer   (used by impl:docs: only — Phase 3.5)
```

Key invariants enforced by all three code orchestrators:
- Branch created before any file is touched (`feat/<slug>` or equivalent)
- Opus review gate runs **before** tests for `SIGNIFICANT`/`HIGH-RISK` tasks
- `review-fixer` handles BLOCKER findings; only one review-fixer cycle per review
- `impl-maintenance` runs post-batch to update KB, `copilot-instructions.md`, and project docs

Key invariants for `impl:code:` specifically:
- Test baseline captured (Phase 2.6) **before** any source edits, using `test-baseliner`
- `test-writer` sub-agent (Phase 3.7) writes tests for **new/changed behaviour** — mandatory for code changes
- If no test framework is detected, user is asked explicitly — test-writing is never silently skipped
- Full test suite verified against baseline (Phase 3.8) before Phase 4

Key invariants for `impl:docs:`:
- **No branch creation by default** — works on current branch unless user requests one
- **No test-baseliner, no test-writer, no code-review** — docs-only phases only
- `doc-reviewer` sub-agent (Phase 3.5) performs comprehensive review: links, headings, wikilinks, style, completeness
- BLOCKER findings trigger a fix cycle (max one fix + one re-review); CONCERNs are recorded and may be fixed inline
- Mixed code + docs changes must use `impl:code:` instead

## Test-writing requirement for code changes

Any `impl:code:` (or `impl:`) invocation that touches source code **must** produce at least
one passing test for each new or changed behaviour before the workflow is considered complete.

- Prefer unit tests; use integration/e2e only if that is the project's established pattern.
- Tests must be meaningful (assert specific behaviour), deterministic, and follow existing project conventions.
- If no test framework is detected, the workflow surfaces this explicitly and asks the user how to proceed — it never silently skips test-writing.
- Docs-only changes (`impl:docs:`) are exempt from this requirement.

## Updating the installed plugin after editing

After editing files in this repo and pushing, update the installed copies on each machine:

**Linux (this dev machine):**
```bash
cp -r dev-workflows/. ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/
```

**Windows (via WSL):**
```bash
cp -r dev-workflows/. /mnt/c/Users/ivan.gudak/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/
```

On any other machine, `copilot plugin install dev-workflows@ihudak-copilot-plugins` handles everything natively after the marketplace is registered.

## Marketplace manifest

`.github/plugin/marketplace.json` at the **repo root** (not inside a plugin dir) is required for `copilot plugin install` to work. It lists all plugins in this marketplace:

```json
{
  "name": "ihudak-copilot-plugins",
  "metadata": { "description": "...", "version": "1.0.0", "pluginRoot": "." },
  "owner": { "name": "...", "email": "..." },
  "plugins": [
    { "name": "dev-workflows", "source": "dev-workflows", "description": "...", "version": "1.0.0" }
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
