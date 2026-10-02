# ihudak-copilot-plugins

Ivan Gudak's private GitHub Copilot plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| [dev-workflows](dev-workflows/) | Twenty-one keyword-triggered skills for the PM → PA → PE → Dev pipeline — idea to VI, ARD, Epics, spec/design, implementation, docs, release notes, CVE, upgrade, guideline/frontmatter review. |
| [dt-style-guide](dt-style-guide/) | Dynatrace corporate style guide enforcement: `/dt-review-pr`, `/dt-review-docs`, `/dt-style-refresh`, and sub-agents used by `dev-workflows` for style checking Epics and feature docs |
| [obsidian-llm-wiki](obsidian-llm-wiki/) | Eleven slash-command skills for compiling Obsidian vault knowledge into a persistent, cross-referenced wiki with task management; supports GitHub Copilot and Claude Code |
| [acli](acli/) | Atlassian CLI (`acli`) reference skill for Jira and Confluence — search, work items, comments, boards, spaces/pages. From [pi-skill-acli](https://github.com/ziegenberg/pi-skill-acli) (MIT). |

## Prerequisites

- **GitHub Copilot CLI** — the plugins install into `copilot` (some `obsidian-llm-wiki` skills also support Claude Code).
- **[`jira-workitem-import`](https://github.com/ivan-gudak/jira-workitem-import)** *(required for Jira-driven skills)* — imports Jira tickets into the specs repo (`$SPECS_PATH/ideas/<KEY>-<slug>/jira-import/` for a `PRODFB-` feedback ticket, `$SPECS_PATH/specifications/<KEY>-<slug>/jira-import/` for every other) in the structure every Jira-driven skill expects — run it as `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>`. Every Jira-driven skill (`idea:` from an RFE, `create-vi:`, `update-vi:`, `epics:`, `specify:`, `design:`, `implement:`, `document:`, `release-notes:`, `ready:`) reads that import.
- **[`superpowers`](https://github.com/obra/superpowers)** *(recommended)* — the plugin `dev-workflows` cedes to for `prompt-brainstorm:`, whose Phase 3 hands off to `superpowers:brainstorming`. No hard dependency; without it that one hand-off has nowhere to go and everything else degrades gracefully. *Grilling* is **not** an external dependency — the relentless-interrogation technique the authoring skills run is bundled in this plugin, at `dev-workflows/skills/_shared/grilling-technique.md`.
- **`gh` + `gh auth login`** *(recommended)* — enables reading GitHub PR diffs (`document:`, `release-notes:`); without it those skills fall back to local-git strategies.
- **`vale`** *(optional)* — a prose linter for docs; `dev-workflows` falls back to a repo lint script, then the `dt-style-guide` plugin, when `vale` is absent.
- **Recommended environment: [`ihudak/ai-containers`](https://github.com/ihudak/ai-containers)** — mounts every repository and your specs repo under one `/workspace` umbrella (repos at `/workspace/<repo>`), so the default `$REPOS_PATH` (`/workspace`) just works; it also installs `gh` and mounts the host `gh` auth. Outside a container the commands still work — set `$REPOS_PATH` yourself and manage `gh` login.

> `dev-workflows` has no hard dependency on any of these — every relationship above is convention + runtime-resolve + graceful fallback (see [`dev-workflows/skills/_shared/dependencies.md`](dev-workflows/skills/_shared/dependencies.md)).

## Installation

### 1. Add this marketplace to GitHub Copilot (once)

```bash
copilot plugin marketplace add ihudak/ihudak-copilot-plugins
```

### 2. Install plugins

```bash
copilot plugin install dev-workflows@ihudak-copilot-plugins
copilot plugin install dt-style-guide@ihudak-copilot-plugins
copilot plugin install obsidian-llm-wiki@ihudak-copilot-plugins
copilot plugin install acli@ihudak-copilot-plugins
```

### 3. Configure environment variables

`dev-workflows` resolves its inputs and outputs through two core environment variables — `SPECS_PATH` and `REPOS_PATH` — plus two optional ones, `DOCS_PATH` for documentation grounding and `GIT_USER_INITIALS` for branch-name identity. Export them in your shell profile (or rely on the AI-Containers defaults):

```bash
export SPECS_PATH="/workspace/specs"   # shared store: specifications, designs, ARDs
export REPOS_PATH="/workspace"         # where your code clones live (default: /workspace)
export DOCS_PATH="/workspace/docs"     # optional, read-only: product docs for grounding (default: /workspace/docs)
export GIT_USER_INITIALS="iv-gu"       # optional: identity segment for branch names
export VAULT_PATH="$HOME/obsidian"     # obsidian-llm-wiki only: the vault it maintains
```

- **`SPECS_PATH`** — the shared, team-visible store: each ticket's Jira import (`jira-import/`), `idea.md`, VI, ARD, `specification.md` and `design.md` live under `specifications/<KEY>-<slug>/…` (a `PRODFB-` feedback ticket's import and idea under `ideas/<KEY>-<slug>/…`). Required by `idea:`, the specs-authoring skills (`create-vi:`, `create-ard:`, `specify:`, `design:`, `ready:`) and by every Jira-driven skill given a Jira key (the importer writes here); only a directory input works without it. For the specs *content* it is advisory for `implement:` and additive for `document:`.
- **`REPOS_PATH`** — where code clones live; a single directory or a colon-separated list. Defaults to `/workspace`. How a repo is matched depends on how the skill finds it: a skill resolving one from a pull-request URL matches the clone's `git remote get-url origin` slug, not its directory name; a skill that lets you pick repos — `create-ard:`, `idea: --ground-code` — lists the top-level directories and matches their names.
- **`DOCS_PATH`** *(optional)* — a **read-only** clone of the product documentation (default `/workspace/docs`). When it is an existing directory containing markdown, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `epics:`, and `release-notes:` automatically ground on the existing shipped docs (via the read-only `docs-grounder` agent), and `document:` prefers it as a docs-repo discovery hint. Never written to; every miss is a silent, non-blocking skip. Disable per-run with `--no-docs`, or override the root with `--docs <path>`.
- **`GIT_USER_INITIALS`** *(optional)* — the identity placeholder every branch-creating skill (`implement:`, `document:`, `docs-profile:`, `upgrade:`, and `vuln:` via `vuln-fixer`) fills into a target repo's own documented branch-naming pattern. Falls back to `git config user.initials`, then inference from existing branches, then a prompt.
- **`VAULT_PATH`** *(optional, `obsidian-llm-wiki` only)* — the Obsidian vault `obsidian-llm-wiki` works in; `dev-workflows` does not read it.

### 4. Update after new releases

```bash
copilot plugin update --all
```

## Runtime directories

The environment variables expect these layouts:

```
$SPECS_PATH/                      # shared, team-visible store
  ideas/<PRODFB-KEY>-<slug>/      # a feedback ticket: jira-import/ + idea.md
  specifications/<KEY>-<slug>/    # specification.md, design.md, ARD (+ per-Epic subfolders)
    jira-import/                  # Jira hierarchy from jira-workitem-import (input; regenerated each import)

$REPOS_PATH/                      # code clones (default /workspace)
  <repo>/                         # matched by git remote slug, or by directory name where a run offers repos to pick

$DOCS_PATH/                       # optional, read-only: product docs clone (default /workspace/docs)
  ...                             # e.g. a dynatrace-docs checkout; searched for grounding, never written
```

## Repository structure

```
ihudak-copilot-plugins/
├── dev-workflows/
│   ├── .plugin/plugin.json
│   ├── README.md
│   ├── agents/               ← 35 sub-agents, dispatched via task(agent_type: "dev-workflows:<name>")
│   └── skills/
│       ├── implement/
│       ├── document/
│       ├── vuln/
│       ├── upgrade/
│       ├── _shared/          ← model-routing.md + other cross-skill reference docs
│       └── <17 more lifecycle/utility skills>
├── dt-style-guide/
│   ├── .plugin/plugin.json
│   ├── README.md
│   ├── references/          ← vendored Dynatrace style guide rules
│   └── skills/
│       ├── dt-style-checker/
│       ├── dt-doc-fixer/
│       ├── dt-review-pr/
│       ├── dt-review-docs/
│       ├── dt-style-refresh/
│       └── dt-style-rules/
├── obsidian-llm-wiki/
│   ├── .plugin/plugin.json
│   ├── README.md
│   └── skills/
│       ├── wiki-ingest/
│       ├── wiki-scan/
│       ├── wiki-query/
│       └── <other wiki skills>
└── .github/
    ├── copilot-instructions.md
    └── plugin/marketplace.json
```

## License

MIT — see [LICENSE](LICENSE).
