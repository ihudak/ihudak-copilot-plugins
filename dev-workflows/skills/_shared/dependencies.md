# dev-workflows — companion plugins & dependencies

dev-workflows is **self-contained**: no command hard-requires another plugin. There is **no
dependency-manifest field** in `.plugin/plugin.json` (Copilot CLI plugins don't express one), so
every cross-plugin relationship is **convention + runtime-resolve + graceful fallback** — a missing
companion degrades the feature, never breaks the run.

## Recommended companions

| Companion | Used by | Relationship | Fallback when absent |
|-----------|---------|--------------|----------------------|
| `superpowers` (skill `brainstorming`) | `prompt-brainstorm:` | Recommended | Embedded technique; no hard dependency. |
| `dt-style-guide` (in this marketplace) | `docs-style-checker`; planning-doc style checks | Optional companion | `docs-style-checker` falls back to it when no repo-configured prose linter exists; `epics:` and `release-notes:` skip the style gate entirely if it is absent. |

## Related external tooling (not a plugin)

| Tool | Role |
|------|------|
| [`jira-workitem-import`](https://github.com/ivan-gudak/jira-workitem-import) | Jira WorkItem Reporter — imports Jira tickets into the specs repo — `$SPECS_PATH/ideas/<ID>-<slug>/jira-import/` for a `PRODFB-` ticket and `$SPECS_PATH/specifications/<ID>-<slug>/jira-import/` for every other (an existing `<ID>` or `<ID>-…` folder is reused; a new one is named from the ticket's summary), its SPECS mode — in the exact structure `jira-reader` (and every Jira-driven command) expects. The upstream producer of the pre-exported markdown tree the plugin consumes. Run it as `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>`; the stock `runme.sh` unsets `SPECS_PATH`. |

## Marketplace siblings (independent plugins, same marketplace)

`dt-style-guide` and `obsidian-llm-wiki` ship in the `ihudak-copilot-plugins` marketplace alongside
dev-workflows but are versioned independently.
