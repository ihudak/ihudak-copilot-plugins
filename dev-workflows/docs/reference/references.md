# References reference

`dev-workflows` bundles 96 files under `skills/_shared/` — 36 top-level markdown files and six vendored subtrees. This page enumerates every one of the 36 top-level files by name, grouped by concern below, then counts the six subtrees rather than listing each file inside them. The arithmetic: 36 named individually, plus 24 + 11 + 10 + 6 + 3 + 2 = 56 markdown pages counted (not enumerated) across the six subtrees — 36 + 56 = 92 markdown files, against 96 files on disk. The remaining four are non-markdown vendored data inside those same subtrees, deliberately not listed as reference pages: `api-guidelines/template/openapi-template.yaml`, `dynatrace-docs/docs-profile.default.yml`, `dynatrace-docs/managed-owners.txt`, and `guidelines/check_guidelines.py` — a template, a defaults file, an owners list, and a lint script, none of them prose a reader would open. The 56-file subtree figures below are markdown-page counts specifically; the four files above already sit inside those same subtrees and are not part of that count, so nobody should later "correct" a subtree figure by adding them back in. Unlike the Claude edition, this edition has no `references/model-routing/` subtree and no cost-prices.yaml file — `model-routing.md` is a flat file directly under `skills/_shared/`, counted among the 36, and there is no cost-price file to count because this edition has no cost subsystem at all (`skills/_shared/specs-repo-git.md:54`).

## Authoring formats

The canonical structure each artifact type is authored and reviewed against, plus the shared conventions every authoring skill applies while writing one.

- `idea-format.md` — canonical structure and per-section rules for a refined idea brief; `idea:` is the only author and cites it directly, while `create-vi:` consumes the resulting artifact without citing this format doc.
- `vi-format.md` — canonical structure and per-section rules for a Value Increment file; `create-vi:` and `update-vi:` author against it, `vi-reviewer` reviews against it, and `release-notes:` reads its Jira-mirror fields.
- `vi-source-resolution.md` — the Jira-import-first resolution ladder for an existing Value Increment: once a VI has been pasted into Jira and gained comments, Jira — not the specs-repo markdown — is authoritative.
- `ard-format.md` — canonical structure and rules for an Architecture Requirements/Decision Document; `ard-reviewer` reviews against it and `ready:` reads its `grounded_repos:` frontmatter.
- `specification-format.md` — canonical structure and per-stage rules for a product specification; `specify:` authors against it and `spec-reviewer` reviews against it. An embedded snapshot, not a net-new format.
- `design-format.md` — canonical structure and per-section rules for an engineering design; `design:` authors against it, `design-reviewer` reviews against it, `interface-designer` reads its `## Seams` categories, and `ready:` reads its repos header.
- `grilling-technique.md` — the one-question-at-a-time interview technique every authoring skill (and `prompt-grill-me:`) uses to refine an artifact; embedded so callers carry no runtime dependency.
- `prose-formatting.md` — the line-wrapping rule every authoring skill and agent applies: never hard-wrap prose, write each paragraph or prose block as one unbroken line.
- `release-note-types.md` — the release-note destination map (breaking-changes / feature-updates / fixes), the per-destination draft shape and prose rules, and the deprecation-note rule; consulted by `release-notes-writer`.
- `doc-structure-conventions.md` — three product-docs authoring conventions: the traceability boundary, callout scope and adjacency, and component-pattern fidelity; consumed by `document:`, `epics:`, `doc-planner`, `doc-writer`, and `doc-reviewer`.

## Git and handoff

The two git entry points that bound every write into the specs repo, plus the naming and read-only-mount conventions those entry points depend on.

- `specs-repo-git.md` — the two git entry points every bookkeeping write against the specs repo runs through: a start-of-run preflight and a terminal artifact commit, both bounded to plugin-created branches and enumerated paths, never fatal. States outright, at line 54, that this edition has no cost subsystem.
- `phase-handoff.md` — the two phase-boundary git entry points: a producer step that lands a phase's deliverable on the specs repo's default branch, and a consumer gate that requires the deliverable be there before expensive work starts.
- `branch-naming.md` — how the five skills that branch in a code repo (`implement:`, `document:`, `docs-profile:`, `upgrade:`, `vuln:`) decide a branch name; the specs-repo handoff branches are named by `phase-handoff.md` §2.2 instead: the target repo's own documented convention always wins, and this doc supplies one only when the repo documents none.
- `finish-and-handoff.md` — the mechanics `document:` (Jira mode) uses for its inline-profiling-branch handling and its finish-and-handoff step: squash, opt-in push, copy-paste PR draft.
- `read-only-repos.md` — how to detect a read-only repository mount, what to skip when one is found, and how to resolve a ref and read from it without ever attempting a write.

## Review and triage

The gates a written artifact passes through before it counts as done, and the discipline for turning a reviewer's findings into fixes.

- `finding-triage.md` — the step between a reviewer's findings and a fixer's edits: verify each finding at the location it names, record every dismissal with a reason, and hand the fixer survivors only.
- `gate-ledger.md` — the six verification-gate outcomes and the rule that no outcome is orchestrator-assignable to mean "I decided not to run this"; consumed by `document:` and the agents whose gates it registers.
- `repo-verification-gates.md` — how to extract a docs repo's own pre-PR checklist into a structured block a reviewer can check the written files against, augmenting the plugin's own gates rather than overriding them.
- `pre-lint.md` — deterministic, grep-expressible structural checks a reviewer-gated skill runs against a just-authored artifact before spending a strong-reasoning review pass on mechanical structure.
- `source-truth.md` — the Implementation-vs-Description discrepancy-escalation protocol: how to verify a user-visible claim against shipped source, and what to do when Jira and source disagree.
- `escalation-rules.md` — the canonical `choices:` arrays for escalation decision points, so every stop-and-ask prompt across the plugin offers consistently-shaped options.
- `workflow-states.md` — maps each Jira workflow status on the VI and Epic ladders to its owning role, the skill that drives the transition into it, and the artifacts expected to exist at that status; the rubric `readiness-reviewer` applies.
- `ard-resolution.md` — given a Jira item, resolves any applicable ARD(s) into a normalized context (or `none`); cited by every skill that must honor an ARD's invariants as implementation guardrails.
- `bug-diagnosis.md` — the bug-diagnosis discipline `implement:` follows for a bug-shaped task: a deterministic repro before hypothesizing, ranked falsifiable hypotheses, tagged and cleaned-up instrumentation, a regression test at a correct seam.

## Grounding

Read-only, advisory context-gathering — never a gate, never a write into the source it reads.

- `docs-grounding.md` — the resolution gate, retrieval procedure, and consumption modes for optional `$DOCS_PATH` documentation grounding; read-only and advisory, never a gate or reviewer BLOCKER.
- `vault-prior-art.md` — how vault prior-art discovery works for the idea-authoring skills: supplied vs. discovered, the status-resolution ladder, and the container derivation a write-path default shares with it.
- `jira-input-resolution.md` — shared input-resolution mechanics for the Jira-driven skills, including the `resolve-export-for-key` sub-procedure `idea:` also uses on its own.

## Session artifacts

The bookkeeping every long-running skill emits around its actual work — feedback, follow-ups, hygiene, and the maintenance loop that feeds tooling improvements back in. This edition emits no cost entry, so there is no cost-emission reference file here.

- `feedback-emission.md` — the session-feedback emitter the thirteen workflow skills' automatic maintenance phase (and `feedback:`/`prompt:*`) cites to capture friction about the plugin itself.
- `followup-emission.md` — the follow-up task and journal emitter a terminal "Emit follow-up tasks" phase cites in `document:`, `release-notes:`, `epics:`, `implement:`, and `ready:`.
- `next-phase-offer.md` — the plugin-wide contract for the next-phase offer every pipeline skill surfaces at the end of its run, naming the natural next skill(s).
- `session-hygiene.md` — the plugin-wide contract for session-hygiene suggestions: flush resume-critical state to disk, then suggest the right context action, after a big skill finishes or a long run checkpoints.
- `context-management.md` — strategies for an implementation run whose step list is too long to complete in one context window without degrading.
- `instruction-file-maintenance.md` — the verification discipline for changes to agent-instruction files: verify every skill claim against what actually runs it, itemise a narrowed rule as a deletion, and never retire a rule on "it looks derivable."

## Environment

What the plugin needs installed or configured around it, independent of any single artifact or skill.

- `dependencies.md` — how dev-workflows relates to companion plugins with no hard dependency: convention plus runtime-resolve plus graceful fallback, since Copilot CLI plugins express no dependency-manifest field.
- `toolchain-preflight.md` — the Phase 0 environment check `document:` runs: deriving the required tool set from the resolved profile and the repo's own documented prerequisites, prompting only on a missing tool.
- `model-routing.md` — a flat file, not a subtree, in this edition — the single source of truth for task-complexity classification, the multi-vendor strong-tier peer set and detection chain, the mandatory strong-reasoning code-review checklist, and the `model_routing` handoff block every pipeline skill loads at its own classification step.

## Bundled reference sets

Six subtrees carry vendored guidance too large or too domain-specific to enumerate file-by-file; each is counted here instead.

- `api-guidelines/` (24) — vendored REST API and IAM permission naming guidance, consulted by `api-guideline-reviewer:`.
- `guidelines/` (11) — vendored Experience Standards, consulted by `guideline-reviewer:`.
- `handoff/` (10) — one input/output document-format contract per agent, usually read by the agent itself rather than by the dispatching skill — `handoff/test-baseliner.md` is the exception, read by `vuln-fixer` and `upgrade-executor`, which dispatch it.
- `dynatrace-docs/` (6) — dynatrace-docs authoring conventions (frontmatter, changelog, anchors, multi-space writing, render verification, the docs-profile schema), consulted by `docs-profile:`, `document:`, and the external `dynatrace-docs-frontmatter` skill.
- `upgrade/` (3) — component-specific upgrade guidance, consulted by `upgrade-planner` and `upgrade-executor`.
- `fix-vuln/` (2) — CVE-remediation guidance, consulted by `vuln-research` and `vuln-fixer`.

Three of these subtrees (`api-guidelines/`, `guidelines/`, `dynatrace-docs/`) also hold the vendored data or template files named in the introduction above, so their `*.md` count here is smaller than `find <dir> -type f` would report; `handoff/`, `upgrade/`, and `fix-vuln/` are markdown only, and for those the two counts agree.

## The three per-skill `references/` subdirs — a different, unreferenced thing

Three skill directories also carry their own local `references/` subdirectory: `skills/upgrade/references/` (3 files, mirroring `upgrade/` above), `skills/api-guideline-reviewer/references/` (mirroring `api-guidelines/` above, plus its own copy of `template/openapi-template.yaml`), and `skills/guideline-reviewer/references/` (mirroring `guidelines/` above, plus its own copy of `check_guidelines.py`). Each is a byte-for-byte content duplicate of its `skills/_shared/` counterpart — differing only in line endings (CRLF here, LF there). `skills/upgrade/references/` is left over from `5af7a8f`, the commit that first added the `dev-workflows` plugin (v1.0.0); `skills/api-guideline-reviewer/references/` and `skills/guideline-reviewer/references/` are left over from `9ea8e31`, the commit that first added those two review skills. Nothing reads them: `agents/guideline-reviewer.md` states outright that "All reference paths are relative to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared`," `agents/api-guideline-reviewer.md` cites only `api-guidelines/...` paths under `_shared/`, and `agents/upgrade-planner.md` / `agents/upgrade-executor.md` read exclusively from `_shared/upgrade/`. None of the three skills' own SKILL.md files mention a `references/` path at all. These three subdirectories are not part of the 96-file `skills/_shared/` inventory above, and this page does not claim they are consulted by anything.

## Skills

Unlike the Claude edition, this edition bundles no `skills/` subtree of its own beyond the twenty pipeline skills already documented under [Skills](../README.md#skills) — each of those **is** a Copilot CLI skill (a SKILL.md file with `name:`/`description:` frontmatter), so there is no separate "N bundled skills" count here. `model-routing.md` is a flat reference file consumed by path, not an invocable skill. The one skill named throughout this plugin's source that genuinely isn't bundled here is `dynatrace-docs-frontmatter` — referenced by `docs-profile:`, `document:`, and the `changelog-owners-reminder` hook as "the `dynatrace-docs-frontmatter` skill," but the source files that reference it never say where it comes from, and no such skill exists in this repo or in any of the marketplace's other three plugins (`dt-style-guide`, `obsidian-llm-wiki`, `acli`) — so there is no page for it in this reference section.
