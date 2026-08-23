# dev-workflows

A role-based pipeline of 20 skills — invoked in this edition via a `name:` colon keyword rather than a leading slash (`specify:`, not `/specify`; `/clear`, `/compact`, and `/rename` are Copilot's own built-ins and keep their slashes). This edition has no slash commands at all. The Claude edition of this plugin calls these same 20 skills 20 slash commands, and adds one more of its own, `/statusline` — a 21st slash command with no counterpart here, since this edition bundles no `statusline:` skill. Its spine runs idea refinement → Value Increment → architecture → Epic breakdown → specification → design → implementation → readiness → documentation → release notes, with strong-tier planning, code review, and doc/design review gates along the way; around that spine sit CVE remediation, dependency upgrades, guideline reviews, and the plugin's own feedback skills. The table below is the complete list.

> Part of the `ihudak-copilot-plugins` marketplace — see the [repo-root setup guide](../README.md) for marketplace install + prerequisites.

## What it does

Every skill owns one role's step in the pipeline and hands a concrete artifact to the next. See [Workflow overview](docs/workflow.md) for the diagram and [Roles](docs/roles.md) for what each role is accountable for.

| Role | Skills | What it does |
|------|--------|--------------|
| PM | `idea:`, `create-vi:`, `update-vi:`, `release-notes:` *(early run)* | Refine a raw idea, author or refresh the Value Increment, and draft an early release-notes note. |
| PA *(optional)* | `create-ard:` | Ground an architecture decision in the mounted implementation code. |
| PE | `epics:`, `specify:` | Break a VI into Epics, then author an org-standard specification through a grill. |
| Dev | `design:`, `implement:`, `ready:`, `document:`, `release-notes:` *(final run)* | Design against the spec, implement it under review gates, verify a Jira status against the record, document the result, and draft the final release-notes note. |
| Anytime — maintenance | `vuln:`, `upgrade:`, `docs-profile:` | Remediate a CVE, upgrade a dependency, or profile a docs repo. |
| Anytime — guideline review | `api-guideline-reviewer:`, `guideline-reviewer:` | Review an OpenAPI spec or app UI against the bundled guidelines. |
| Anytime — plugin feedback | `feedback:`, `prompt:`, `prompt-brainstorm:`, `prompt-grill-me:` | Log friction about the plugin itself, or capture and act on a correction. |

`release-notes:` is the one skill in two rows — the same skill run at two points in a Value Increment's life, attributed by inference rather than a fixed role.

## Documentation

| Page | What's there |
|------|--------------|
| [Documentation index](docs/README.md) | The full "I want to…" lookup table, plus the skill and reference inventories. |
| [Getting started](docs/getting-started.md) | Install, environment variables, your first `idea:` run. |
| [Workflow overview](docs/workflow.md) | The whole pipeline as one diagram. |
| [Roles](docs/roles.md) | What each role owns and hands off. |
| [Agents](docs/reference/agents.md) | The subagent inventory the skills dispatch internally. |
| [References](docs/reference/references.md) | The reference-doc inventory under `skills/_shared/`. |
| [Environment](docs/reference/environment.md) | Every environment variable the plugin reads. |
| [Hooks](docs/reference/hooks.md) | The bundled hooks and what each does. |
| [Model routing](docs/reference/model-routing.md) | Task-complexity classification and the model fallback chain. |
| [Session feedback](docs/reference/session-feedback.md) | Two signals: what you report, and what your corrections reveal. |
| [Follow-ups](docs/reference/follow-ups.md) | How a skill emits follow-up tasks into your vault. |
| [Resume and checkpoints](docs/reference/resume-and-checkpoints.md) | Session hygiene for a long-running skill. |

## Not ported from the Claude Code edition

Two features from the upstream Claude Code plugin are intentionally omitted because they depend on capabilities GitHub Copilot CLI does not expose — see [Roles](docs/roles.md) for what that means for a run's output:

- **Session cost reporting** — no cost/usage API, so there is no `emit-cost` and no role/phase cost attribution anywhere.
- **Statusline integration** — no statusline extension point.

## Recommended environment

Mount every repository and your vault under one `/workspace`, matching this plugin's defaults, with [`ihudak/ai-containers`](https://github.com/ihudak/ai-containers). Outside a container the skills still work — set `$REPOS_PATH` and `$VAULT_PATH` yourself; see [Environment](docs/reference/environment.md).

## License

MIT — see [LICENSE](LICENSE).
