# obsidian-llm-wiki

LLM Wiki pattern for an active Obsidian vault. Compiles knowledge from meetings,
projects, daily notes, and raw sources into a persistent, cross-referenced wiki at
`Knowledge/wiki/`. Supports both GitHub Copilot (natural language prefixes) and
Claude Code (slash commands) as first-class agents.

## Installation

```
copilot plugin install obsidian-llm-wiki@copilot-marketplace
```

## Prerequisites

- Obsidian vault — default `~/obsidian_vault`; set `VAULT_PATH` env var to override
  (WSL users with Windows-side vault: `export VAULT_PATH=/mnt/c/Users/<name>/obsidian_vault`)
- `.raw/` directory in your vault root:
  ```bash
  cd /path/to/your/vault
  mkdir .raw && touch .raw/.gitkeep
  ```

## Usage — Natural Language Prefixes

| Prefix | Description |
|--------|-------------|
| `wiki-ingest: @filepath` | Ingest one source file into the wiki |
| `wiki-scan: [directory]` | Scan directory for unprocessed files; batch-ingest new/changed |
| `wiki-query: <question>` | Answer from the compiled wiki with citations |
| `wiki-save:` | Save current conversation as a wiki page |
| `wiki-lint:` | Run wiki health check, produce lint report |
| `wiki-hot:` | Manually refresh the hot cache |
| `wiki-tags-refresh:` | Sync wiki tags with `.obsidian/copilot/tag-index.md` |

## Skills

| Skill | Trigger |
|-------|---------|
| wiki-ingest | `wiki-ingest:` |
| wiki-scan | `wiki-scan:` |
| wiki-query | `wiki-query:` |
| wiki-save | `wiki-save:` |
| wiki-lint | `wiki-lint:` |
| wiki-hot | `wiki-hot:` |
| wiki-tags-refresh | `wiki-tags-refresh:` |
| wiki-schema | Loaded automatically before every wiki operation |

## Boundary Rules

Wiki operations never write to: `Meetings/`, `Daily/`, `Projects/`, `Customers/`,
`People/`, `Clippings/`, `Research/`. All wiki output goes to `Knowledge/wiki/`.

## Claude Code

Identical slash commands are available via the
[claude-marketplace](https://github.com/ihudak/claude-marketplace/tree/main/plugins/obsidian-llm-wiki)
entry. Both agents write to the same wiki — switching mid-session is seamless.

## License

MIT
