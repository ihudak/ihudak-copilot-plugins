# Agents reference

`dev-workflows` bundles 34 agents under `agents/`, dispatched internally by the invoking skill via `task(agent_type: "dev-workflows:<name>")` — none of them is a user entry point. **None of the 34 carries a `model:` frontmatter field** — this edition pins the model at the `task()` call site instead, not in the agent file. Nine of the 34 are, by convention, always pinned by the caller to the strong reasoning tier (shown as **strong tier** below) regardless of the run's own classification — the reviewers and `risk-planner`; the remaining twenty-five (shown as **per routing**) are assigned a tier by the dispatching skill per [`skills/_shared/model-routing.md`](../../skills/_shared/model-routing.md) §2.1's detection chain. The strong tier is itself a multi-vendor peer set — `claude-opus-5`, `gpt-5.6`, `claude-opus-4.8`, `claude-opus-4.7`, `claude-opus-4.6`, `gpt-5.5` — not an Opus-only ladder; see [Model routing](model-routing.md). Agents are grouped below by role — reviewers and planners, readers and scanners, writers, fixers, and maintenance — and each row's **Used by** column lists only the skills that actually dispatch that agent; a skill that merely names another skill's agent in passing is not counted as a dispatch.

One tool-declaration inconsistency survives in the source as shipped: every agent except `vault-prior-art-finder` declares Copilot CLI's lowercase tool tokens (`view`, `glob`, `grep`, …); `vault-prior-art-finder` alone still carries the Claude-edition capitalized names (`"Read", "Glob", "Grep"`), a leftover from the port. This page reports what each agent file literally declares.

## Reviewers and planners

Strong-tier quality gates the caller always pins, plus the lighter-weight planners and style checkers that feed or precede them.

| Agent | Model | Tools | What it does | Used by |
|---|---|---|---|---|
| `ard-reviewer` | strong tier | view, glob, grep | Reviews an ARD for grounding integrity, well-formed `AD#N` rules, non-contradiction with inherited VI-level invariants, and altitude purity; returns PASS / PASS WITH RECOMMENDATIONS / BLOCK. | `create-ard:` |
| `code-review` | strong tier | view, glob, grep | Post-implementation review for SIGNIFICANT / HIGH-RISK changes — correctness, security, architecture, edge cases, migration, dependencies, tests, rollback; gates the test run. | `implement:`, `upgrade:`, `vuln:` |
| `design-reviewer` | strong tier | view, glob, grep | Reviews an engineering design against the design-format authority and its specification, treating any unresolved design open question as a BLOCKER. | `design:` |
| `doc-reviewer` | strong tier | view, glob, grep | Reviews product documentation written by `document:` for correctness, completeness, and fitness for purpose; product-docs only — Epic drafts go through `epic-reviewer`. | `document:` |
| `epic-reviewer` | strong tier | view, glob, grep | Reviews Epic drafts for goal clarity, testable acceptance criteria, scope boundaries, and non-duplication with existing Epics under the parent VI. | `epics:` |
| `readiness-reviewer` | strong tier | view, glob, grep | Cross-artifact readiness verifier — checks the ARD/spec/design justify the Jira status and the next transition; the only reviewer that does joint cross-artifact analysis. | `ready:` |
| `risk-planner` | strong tier | view, glob, grep, bash, web_fetch | Risk-weighted planner for SIGNIFICANT / HIGH-RISK tasks; returns a structured plan with an explicit risks section. Never dispatched for SIMPLE / MODERATE work. | `implement:`, `upgrade:` |
| `spec-reviewer` | strong tier | view, glob, grep | Reviews a specification for per-stage quality, cross-stage consistency, coverage, and identifier integrity. | `specify:` |
| `vi-reviewer` | strong tier | view, glob, grep | Reviews a Value Increment for goal crispness, testable stories/criteria, internal consistency, measurable metrics, and product-level purity (no implementation detail). | `create-vi:`, `update-vi:` |
| `api-guideline-reviewer` | per routing | view, glob, grep | Reviews an OpenAPI spec against the bundled REST API and IAM permission naming guidelines — version consistency, naming, IAM scope format, status codes, schema composition. | `api-guideline-reviewer:` |
| `guideline-reviewer` | per routing | view, glob, grep, bash | Reviews app code and UI against the Experience Standards — AppHeader, DataTable, permissions, accessibility/WCAG, terminology, Grail naming. | `guideline-reviewer:` |
| `docs-style-checker` | per routing | view, glob, grep, bash, task | Runs the docs repo's configured prose linter and, when the dt-style-guide plugin is installed, a complementary Dynatrace-style pass; merges both finding sets for `doc-reviewer`/`doc-fixer`. | `document:` |
| `doc-planner` | per routing | view, glob, grep | Synthesises Jira data, per-repo diff summaries, and confirmed write targets into the documentation checklist the writer follows and the reviewer checks against; writes no content itself. | `document:` |
| `interface-designer` | per routing | view, glob, grep, bash | Produces one interface proposal for one contested interface under one named design constraint, for `design:`'s optional three-take Phase 5 fan-out. | `design:` |
| `upgrade-planner` | per routing | view, grep, glob, bash, web_fetch | Detects a component, resolves its requested target version, and verifies compatibility with every other component in the repo; one instance per component, dispatched in parallel. | `upgrade:` |

## Readers and scanners

Read-only discovery and grounding — each returns a structured digest rather than editing anything. `test-baseliner` is the one that touches the working tree at all: it holds `bash` because its job is to *run* the suite, so build and coverage output appears as a side effect.

| Agent | Model | Tools | What it does | Used by |
|---|---|---|---|---|
| `code-scanner` | per routing | view, glob, grep, bash | Scans one code repository for existing capabilities and gaps relative to a set of themes; pure filesystem search, designed for parallel per-repo invocation capped at 4 concurrent. | `create-ard:`, `design:`, `epics:`, `idea:`, `implement:`, `specify:` |
| `counterpart-finder` | per routing | view, glob, grep, bash | For a space-constrained `document:` run, finds the counterpart space's existing docs for the same feature as read-only grounding; never writes and never adds images to the pipeline. | `document:` |
| `diff-summarizer` | per routing | view, glob, grep, bash | Reads one repository's PR diff(s) and returns a documentation-focused summary; host-aware — `gh` CLI for GitHub when available, pure local git for Bitbucket and GitHub fallback. | `document:`, `release-notes:` |
| `doc-location-finder` | per routing | view, glob, grep | Finds the right place(s) in a docs repository to write new or extended documentation, returning a prioritised list of write targets with rationale; heuristic search, no content written. | `document:` |
| `docs-grounder` | per routing | view, glob, grep, bash | Read-only `$DOCS_PATH` grounding — retrieves the most relevant existing product-doc pages and returns a bounded digest of positive references plus reconciliation challenges. | `create-ard:`, `create-vi:`, `epics:`, `idea:`, `release-notes:`, `specify:`, `update-vi:` |
| `idea-reader` | per routing | view, glob, grep | Ingests one idea source — an inline prompt, a markdown file, a community post, or an exported Jira ticket — and returns a structured source digest for `idea:`. | `idea:` |
| `jira-reader` | per routing | view, glob, grep | Reads a pre-exported Jira markdown hierarchy from the vault and returns a structured handoff — linked items, PR URLs with host classification, capability themes. | `create-ard:`, `document:`, `epics:`, `implement:`, `ready:`, `release-notes:`, `specify:` |
| `vault-prior-art-finder` | per routing | "Read", "Glob", "Grep" | Searches the vault for tracked initiatives that cover, precede, parallel, or are superseded by new work, returning each match classified, status-resolved, and summarised. | `idea:`, `create-vi:` |
| `vuln-research` | per routing | view, grep, glob, bash, web_fetch | Read-only CVE research phase — NVD lookup, library detection in the repository, current-version discovery, and minimum-safe-version resolution. Has no side effects. | `vuln:` |
| `test-baseliner` | per routing | bash, view, glob | Runs the full test suite and returns structured results in two modes — capture a baseline, or verify a later run's result against a previously captured one. | `implement:`, `upgrade:`, `vuln:` |

## Writers

Produce artifact content from a structured handoff. None of these run git.

| Agent | Model | Tools | What it does | Used by |
|---|---|---|---|---|
| `doc-writer` | per routing | view, glob, grep, create, edit, bash | Writes product documentation from a structured handoff — the `doc-planner` checklist, approved per-page write strategies, discrepancy decisions, snippets, screenshots, frontmatter, links. | `document:` |
| `epic-writer` | per routing | view, glob, grep, create, edit | Writes one file per child Epic from a structured handoff, traceable to the `jira-reader` handoff and `code-scanner` evidence; write-only, never commits. | `epics:` |
| `release-notes-writer` | per routing | view, glob, grep | Renders a release-notes draft — exactly one Summary, shaped by its resolved destination; emits no Jira ID, PR link, or internal-note wrapper. Does not write files. | `release-notes:` |
| `test-writer` | per routing | view, glob, grep, create, edit | Writes tests for new or changed behaviour based on a diff; does not run them, and reports "not detected" immediately when no test framework is found. | `implement:` |

## Fixers

Apply changes the caller has already decided on, rather than deciding anything themselves. `doc-fixer` and `review-fixer` patch findings a reviewer or linter surfaced, and the caller re-runs the gate afterward; `upgrade-executor` applies an upgrade plan and runs the build, and `vuln-fixer` applies the version change `vuln-research` resolved.

| Agent | Model | Tools | What it does | Used by |
|---|---|---|---|---|
| `doc-fixer` | per routing | view, glob, grep, create, edit | Applies targeted fixes for surviving BLOCKER/MAJOR findings from `doc-reviewer` or `epic-reviewer`, or for violations from a style checker; mirrors `review-fixer` for the docs domain. | `document:`, `epics:` |
| `review-fixer` | per routing | view, glob, grep, create, edit | Applies targeted code fixes for surviving BLOCKER/MAJOR findings from a `code-review` report; returns a structured fix report for the caller to re-review against. | `implement:`, `upgrade:`, `vuln:` |
| `upgrade-executor` | per routing | view, grep, glob, bash, edit, create, task | Applies one component's approved upgrade plan, runs the build, verifies tests via `test-baseliner`, and auto-fixes test-code breakage caused by the new version's API changes. | `upgrade:` |
| `vuln-fixer` | per routing | view, grep, glob, bash, edit, create, task | Captures a baseline, applies the minimal version change `vuln-research` produced, rebuilds, verifies tests, commits to a new branch, and opens a PR. | `vuln:` |

## Maintenance

| Agent | Model | Tools | What it does | Used by |
|---|---|---|---|---|
| `impl-maintenance` | per routing | view, glob, grep | Reads what happened during a session and produces a Lessons Learned report — `copilot-instructions.md`, reference-doc, hook, and workflow suggestions; suggest-only, writes nothing itself. | `create-ard:`, `create-vi:`, `design:`, `document:`, `epics:`, `idea:`, `implement:`, `ready:`, `release-notes:`, `specify:`, `update-vi:`, `upgrade:`, `vuln:` |

Every one of the 34 agents above is dispatched by at least one skill — none has an empty **Used by** cell. Two of them, `docs-grounder` and `vault-prior-art-finder`, are dispatched indirectly: their calling skills invoke a named procedure (`dispatch-docs-grounder` in [`docs-grounding.md`](../../skills/_shared/docs-grounding.md), `dispatch-prior-art-finder` in [`vault-prior-art.md`](../../skills/_shared/vault-prior-art.md)) rather than writing `task(agent_type: "dev-workflows:<name>")` inline, but that procedure resolves to exactly the agent named above, so the derivation counts it as a real dispatch. `test-baseliner`, `review-fixer`, and `code-review` are each dispatched by `upgrade:` and `vuln:` the same indirect-in-a-different-sense way — by bare name in prose ("using the existing `test-baseliner` agent", "Invoke `code-review` using…", "invoke `review-fixer` with model: …") rather than the literal `dev-workflows:` prefix, but they are still direct dispatches from those skills' own orchestrator steps, not delegated through a shared reference's procedure.
