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
| `impl:` / `impl:code:` | impl | Implement a feature or fix from a spec. Creates a feature branch, captures a test baseline, runs risk-weighted planning (Opus critique for complex tasks), implements, runs Opus code-review (SIGNIFICANT/HIGH-RISK), writes tests for changed behaviour via `test-writer`, verifies no regressions, and runs post-impl maintenance. `impl:` is a silent alias for `impl:code:`. |
| `impl:docs:` | impl-docs | Implement documentation-only changes (Markdown, READMEs, wikis, Obsidian vault, etc.). Lightweight: no branch by default, no tests, no code-review. Redirects to `impl:code:` if source code changes are detected. |
| `impl:jira:docs:` / `impl:jira:epics:` / `impl:jira:` | impl-jira | Jira-driven documentation workflow. Reads Jira work-item exports from an Obsidian vault, resolves Bitbucket PR URLs as local-git identifiers (no HTTPS/API calls), runs parallel diff-summarizers (use case A — feature docs) or code-scanners (use case B — Epic writing), synthesises output with mandatory inline citations, gates on doc-reviewer, and runs impl-maintenance. |
| `fix-vuln:` | fix-vuln | Remediate one or more CVEs. Researches each CVE via NVD, applies the minimal safe version bump, verifies tests, applies Opus code-review, runs post-batch maintenance. Each CVE gets its own branch and PR. |
| `upgrade:` | upgrade | Upgrade one or more dependencies to a target version. Creates an upgrade branch, captures test baseline, plans compatibility per-component, upgrades and verifies in sequence, applies Opus code-review, runs post-batch maintenance. |

### Sub-agent skills (invoked by orchestrators)

| Skill | Role |
|-------|------|
| test-baseliner | Captures test baseline before a change; compares after; returns regression report. Used by `impl:code:`, `upgrade-executor`, and `vuln-fixer`. |
| test-writer | Writes or updates tests for newly added or changed code behaviour. Used by `impl:code:` (Phase 3.7). Returns a Test Report with framework detection, files created/modified, and status. |
| doc-reviewer | Performs a comprehensive review of changed documentation files: link integrity, heading structure, wikilinks, style, structural coherence, and completeness. Used by `impl:docs:` (Phase 3.5) and `impl:jira:` (Phase 7). Returns a Doc Review Report with status and findings. |
| impl-maintenance | Post-implementation maintenance: updates knowledge base, copilot-instructions, and project docs |
| upgrade-planner | Plans a single component upgrade: resolves target version, checks compatibility |
| upgrade-executor | Executes a single planned upgrade: applies change, builds, verifies tests, auto-fixes test breakage |
| vuln-research | Read-only CVE research: NVD lookup, library detection, minimum safe version resolution |
| vuln-fixer | Applies a CVE fix: captures baseline, bumps version, rebuilds, verifies tests, commits, opens PR |
| review-fixer | Receives Opus code-review output; applies BLOCKER and MAJOR locally-actionable findings in one cycle |
| jira-reader | Read-only: parses `$VAULT_PATH/_archive/jira-products/<KEY>/` Jira exports. Returns structured handoff with VI summary, linked items, PR URLs with provenance, and capability themes. Used by `impl:jira:` (Phase 3). |
| diff-summarizer | Use case A: given a repo path and a set of PR identifiers, resolves each PR against local git refs (4 strategies: PR ref, branch search, merge commit, issue grep) and produces prose diff summaries. Pure local git — no HTTPS. Used by `impl:jira:docs:` (Phase 5, parallel). |
| code-scanner | Use case B: given a repo path and capability themes, scans the filesystem with rg/glob/view to classify each theme as present/partial/absent and produce a gap summary for Epic writing. Used by `impl:jira:epics:` (Phase 5, parallel). |

### Shared reference

`skills/_shared/model-routing.md` is the single source of truth for complexity classification, model routing policy (default → Opus thresholds), and the 8-dimension Opus review checklist. All orchestrators read it at runtime.

## Model routing

| Complexity | Model |
|------------|-------|
| SIMPLE | Default session model |
| MODERATE | Default session model (with structured planning) |
| SIGNIFICANT / HIGH-RISK | `claude-opus-4.7` (forced via `model:` override) |

## Feature highlights

- **Branch-per-change**: `impl:code:` and `upgrade:` create a feature branch before touching code; `fix-vuln:` creates one per CVE. `impl:docs:` works on the current branch by default. `impl:jira:` branches when run from a git repo (opt-in at plan approval); never branches in an Obsidian vault.
- **Jira-driven docs**: `impl:jira:docs:` and `impl:jira:epics:` read Obsidian vault Jira exports, resolve PR URLs as pure local-git identifiers (no Bitbucket REST API), run parallel diff-summarizers or code-scanners per repo, and produce documentation with mandatory inline Jira + PR citations.
- **Test-writing gate**: `impl:code:` writes tests for all new/changed behaviour via `test-writer` (Phase 3.7) and verifies no regressions against a pre-impl baseline (Phase 3.8). No test framework? The workflow asks — it never silently skips.
- **Opus code-review gate**: every code workflow runs an Opus review before committing for SIGNIFICANT/HIGH-RISK tasks; `review-fixer` sub-agent auto-applies fixable findings
- **Post-batch maintenance**: after all workflows, `impl-maintenance` updates the project knowledge base, `copilot-instructions.md`, and docs
- **Stateless sub-agents**: all sub-agents receive full context in their prompt — no hidden state between calls

## License

[MIT](LICENSE)
