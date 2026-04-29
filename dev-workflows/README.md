# dev-workflows

A GitHub Copilot plugin providing structured development workflow skills for implementing features, remediating vulnerabilities, and upgrading dependencies.

## Installation

```
copilot plugin install dev-workflows@ihudak-copilot-plugins
```

## Skills

### Orchestrator skills (invoke by keyword)

| Trigger | Skill | Description |
|---------|-------|-------------|
| `impl:` | impl | Implement a feature or fix from a spec. Creates a feature branch, runs risk-weighted planning (Opus for complex tasks), implements with TDD, runs Opus code-review, applies fixes via `review-fixer`, commits and optionally opens a PR. |
| `fix-vuln:` | fix-vuln | Remediate one or more CVEs. Researches each CVE via NVD, applies the minimal safe version bump, verifies tests, applies Opus code-review, runs post-batch maintenance. Each CVE gets its own branch and PR. |
| `upgrade:` | upgrade | Upgrade one or more dependencies to a target version. Creates an upgrade branch, captures test baseline, plans compatibility per-component, upgrades and verifies in sequence, applies Opus code-review, runs post-batch maintenance. |

### Sub-agent skills (invoked by orchestrators)

| Skill | Role |
|-------|------|
| test-baseliner | Captures test baseline before a change; compares after; returns regression report |
| impl-maintenance | Post-implementation maintenance: updates knowledge base, copilot-instructions, and project docs |
| upgrade-planner | Plans a single component upgrade: resolves target version, checks compatibility |
| upgrade-executor | Executes a single planned upgrade: applies change, builds, verifies tests, auto-fixes test breakage |
| vuln-research | Read-only CVE research: NVD lookup, library detection, minimum safe version resolution |
| vuln-fixer | Applies a CVE fix: captures baseline, bumps version, rebuilds, verifies tests, commits, opens PR |
| review-fixer | Receives Opus code-review output; applies BLOCKER and MAJOR locally-actionable findings in one cycle |

### Shared reference

`skills/_shared/model-routing.md` is the single source of truth for complexity classification, model routing policy (default → Opus thresholds), and the 8-dimension Opus review checklist. All orchestrators read it at runtime.

## Model routing

| Complexity | Model |
|------------|-------|
| TRIVIAL / LOW | Default session model |
| MEDIUM | Default session model (with structured planning) |
| SIGNIFICANT / HIGH-RISK | `claude-opus-4.7` (forced via `model:` override) |

## Feature highlights

- **Branch-per-change**: `impl:` and `upgrade:` create a feature branch before touching code; `fix-vuln:` creates one per CVE
- **Opus code-review gate**: every workflow runs an Opus review before committing; `review-fixer` sub-agent auto-applies fixable findings
- **Post-batch maintenance**: after `fix-vuln:` and `upgrade:` batches, `impl-maintenance` updates the project knowledge base, `copilot-instructions.md`, and docs
- **Stateless sub-agents**: all sub-agents receive full context in their prompt — no hidden state between calls

## License

[MIT](LICENSE)
