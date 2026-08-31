# Getting started

## Install

### 1. Add this marketplace to GitHub Copilot (once)

```bash
copilot plugin marketplace add ihudak/ihudak-copilot-plugins
```

### 2. Install dev-workflows

```bash
copilot plugin install dev-workflows@ihudak-copilot-plugins
```

Recommended alongside it — `docs-style-checker` falls back to `dt-style-guide`'s `dt-style-checker` whenever the target repo has no configured prose linter, and `epics:` / `release-notes:` use it directly for their style gate:

```bash
copilot plugin install dt-style-guide@ihudak-copilot-plugins
```

`dev-workflows` has no hard dependency on `dt-style-guide` or on anything else in this marketplace — every cross-plugin relationship is convention + runtime-resolve + graceful fallback (see [`skills/_shared/dependencies.md`](../skills/_shared/dependencies.md)).

## Update

```bash
copilot plugin update --all
```

## What you set on your machine

`dev-workflows` resolves its inputs and outputs through five environment variables. Export them in your shell profile:

```bash
export VAULT_PATH="$HOME/obsidian"        # personal store: Jira imports + idea/project files
export SPECS_PATH="/workspace/specs"      # shared store: specifications, designs, ARDs
export REPOS_PATH="/workspace"            # where your code clones live (default: /workspace)
export DOCS_PATH="/workspace/docs"        # optional, read-only: product docs for grounding (default: /workspace/docs)
export GIT_USER_INITIALS="iv-gu"          # optional: identity segment for branch names
```

- **`VAULT_PATH`** — your personal store. Holds `jira-products/<KEY>/` (produced by `jira-workitem-import`) and `Projects/<area>/<slug>/` (idea and project files).
- **`SPECS_PATH`** — the shared, team-visible store for a ticket's `specification.md` / `design.md` / ARD under `specifications/<KEY>-<slug>/…`. Required by the specs-authoring skills (`create-vi:`, `create-ard:`, `specify:`, `design:`, `ready:`); advisory for `implement:`; additive for `document:`.
- **`REPOS_PATH`** — where code clones live; a single directory or a colon-separated list. Defaults to `/workspace`. Repos are matched by their `git remote get-url origin` slug, not by directory name.
- **`DOCS_PATH`** *(optional)* — a read-only clone of the product documentation (default `/workspace/docs`). When it is an existing directory containing markdown, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `epics:`, and `release-notes:` automatically ground on the existing shipped docs, and `document:` prefers it as a docs-repo discovery hint. Never written to; every miss is a silent, non-blocking skip.
- **`GIT_USER_INITIALS`** *(optional)* — the identity placeholder every branch-creating skill (`implement:`, `document:`, `docs-profile:`, `upgrade:`, and `vuln:` via `vuln-fixer`) fills into a target repo's own documented branch-naming pattern. Falls back to `git config user.initials`, then inference from existing branches, then a prompt.

## Your first run

Start with `idea:` — it writes only to your vault, touches no Jira, no code, and no specs repo, so there is nothing to undo:

```
idea: <describe the thing you want to build>
```

`idea:` asks up to 10 questions, one at a time (`--deep` makes the grill relentless instead of bounded), then writes a lean one-page `idea.md`. Once you create an empty Jira workitem to get an ID, `create-vi: <JIRA-KEY>` picks the idea up from there and turns it into a reviewed Value Increment.

## superpowers — recommended, not required

`prompt-brainstorm:` hands its Phase 3 off to `superpowers:brainstorming` ([`obra/superpowers`](https://github.com/obra/superpowers)) to explore a correction together with you instead of applying it in one shot. This is the plugin's only tie to `superpowers`, and it is not a hard dependency: without `superpowers` installed, that one hand-off has nowhere to go, and every other skill — including `prompt:` and `prompt-grill-me:`, the other two correction-logging skills — runs unaffected.

This is separate from *grilling*, the interrogation technique that `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, and `design:` all run to converge on a well-formed artifact — one question at a time where the grill is capped, round by round where it is relentless. Grilling is **not** an external dependency — it is bundled in this plugin, at [`skills/_shared/grilling-technique.md`](../skills/_shared/grilling-technique.md).
