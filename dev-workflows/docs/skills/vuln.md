# vuln:

Researches CVEs via the NVD API, then applies dependency and code fixes one CVE at a time — each gated by a strong-reasoning code review for SIGNIFICANT / HIGH-RISK fixes — and verifies every fix against a captured test baseline.

## Who runs it

`vuln:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `vuln:` alongside `upgrade:`, `feedback:`, the `prompt:` family, `docs-profile:`, and the two guideline reviewers as skills that carry no next-phase offer. Run it against any repo, any time a CVE needs remediation — it is tied to no VI, Epic, or other pipeline artifact.

## Synopsis

    vuln: <JIRA-ID:CVE-ID | CVE-ID> [<JIRA-ID:CVE-ID | CVE-ID> ...] [--skip-feedback] [--enforce-model=<model>]

[Run flags](../reference/run-flags.md): both of this edition's run flags apply. Each has an environment default (`$WORKFLOWS_SKIP_FEEDBACK`, `$WORKFLOWS_ENFORCE_MODEL`) that an explicit flag overrides. `--skip-costs` is a Claude-edition flag only — this edition has no cost subsystem, so it is not parsed here at all.

Each argument token is either `JIRA-ID:CVE-ID` (e.g. `MGD-2423:CVE-2023-46604`) or a bare `CVE-ID` (e.g. `CVE-2023-46604`) — a Jira ID is optional per token, never required for the run as a whole. Step 1 parses each token, filters out anything that isn't a CVE pattern (`CWE-*`, OWASP patterns) with a warning, and determines the project's `NOJIRA`/`NO-JIRA` placeholder convention from recent branch names and commit history for any token missing a Jira ID. All CVEs are researched together before any fix is applied, then fixed one at a time to avoid conflicting edits to the same dependency files.

## How it runs

```mermaid
flowchart TD
    s0["Step 0 — Classify & Route (mandatory)"] --> s1["Step 1 — Prepare"]
    s1 --> s2["Step 2 — Research (parallel)"]
    s2 --> d1{"Finalized per-CVE class?"}
    d1 -->|"SIMPLE / MODERATE"| s3a["Step 3 — Fix: vuln-fixer"]
    d1 -->|"SIGNIFICANT / HIGH-RISK"| s3b["Step 3 — Fix: vuln-fixer, review-tier review → triage → review-fixer"]
    s3a --> verify["Step 3 — Verify tests against baseline"]
    s3b -->|"Non-BLOCK: verify-resume"| verify
    verify --> s4["Step 4 — Summarise"]
```

`vuln/SKILL.md` uses `## Step` headings, not `## Phase` — five of them, shown above. It dispatches six subagents directly, all real (`agents/*.md` exists for each): `vuln-research` (Step 2, one per CVE, batched in a single agent message), `vuln-fixer` (Step 3, sequential per `READY` CVE), `test-baseliner` (Step 3, capturing the run's one baseline before the first CVE is worked, on both paths), `code-review` (Step 3, SIGNIFICANT/HIGH-RISK only, before tests run), `review-fixer` (Step 3, for surviving BLOCKER/MAJOR findings after triage), and `impl-maintenance` (Step 4, session lessons-learned). Only `vuln-research` and `vuln-fixer` appear as literal `task(agent_type: "dev-workflows:…")` calls in the file; `impl-maintenance` is invoked in prose with its full `agent_type` and `model:`, while `test-baseliner`, `code-review`, and `review-fixer` are invoked by bare name in prose ("Dispatch `test-baseliner` in `capture` mode with…", "Invoke `code-review` with…", "invoke `review-fixer` with model: …") without repeating the `dev-workflows:` prefix — a citation-style inconsistency inside the file itself, not an indirection through a `skills/_shared/` procedure, so all six are direct dispatches. No `dispatch-*`/`resolve-*` indirection appears anywhere in this skill.

## What it needs

- **At least one CVE token**, per the Synopsis grammar. Every non-CVE token is filtered out with a warning rather than silently dropped.
- **The repo path** — the run's target, snapshotted at Step 1 alongside the primary ecosystem when it's obvious, so `vuln-research` can disambiguate library detection.
- **A per-CVE classification**, finalized from the research report — not known up front, so Step 0 starts with a provisional `MODERATE` routing block for research and re-classifies once each research report returns (`READY`/`NOT_IN_REPO`/`LOOKUP_FAILED`/`SKIP_NON_CVE`). A finalized `HIGH-RISK` re-runs `vuln-research` on the strong-reasoning tier for a confirmation pass; a non-trivial `SIGNIFICANT` bump does the same when the breaking-change surface warrants it.
- **A test suite `test-baseliner` can run** — every suite its [detection table](../reference/test-suite-detection.md) covers is baselined once at the orchestrator, before the first CVE is worked and on both paths; a polyglot repository has all of its suites baselined. Where some ran and some could not, the run proceeds and each CVE's `Notes` cell names what it did not verify. Where none could, the run asks before it branches or edits anything: supply a test command (used for the baseline and for every later verify), apply the fixes unverified, or cancel. A repository with no tests at all is not asked about.
- **A resolved research report file** — written to a temp path (never inside a repo tree) and passed by path, never pasted, to `vuln-fixer`, `code-review`, and every resume step. An unreadable path at any of those steps is a hard stop for that CVE (marked `BLOCKED` in the Step 4 table), never retried with a freshly re-derived research pass.

## What it produces

Dependency and code fixes applied one CVE at a time, each on its own dedicated fix branch created by `vuln-fixer` **before its first edit** — so a CVE stopped by its own review still has a branch to commit onto — and branched from the base rather than from the previous CVE's branch. The commit, the push, and the pull request are the orchestrator's, at Step 3.9, through [`code-repo-handoff.md`](../../skills/_shared/code-repo-handoff.md), which is also where the `gh` capability probe and the manual-open fallback live, so a host without `gh` reports instructions instead of a pull request that was never opened. The push-and-PR consent choice is asked on the first CVE and reused for the rest of the run — put again only where a later CVE's outcome differs from the one you answered under, in either direction. A Step 4 results table (`CVE | Library | Change | Class | Result | PR | Notes`), a `### Model Routing` section, and a `### Review triage` section naming every finding reviewed and every dismissal's reason for CVEs that reached Opus/strong-reasoning review. The terminal `commit-artifacts` step commits only `$SPECS_PATH`'s bounded session-artifact paths, printed as a `Specs repo:` line — the code repo's own commits, pushes, and pull requests were Step 3.9's, against a different remote, printed as a `Code repo:` line per CVE.

## Gates

Step 3's SIGNIFICANT/HIGH-RISK path dispatches `code-review` before any test run — a `BLOCK` verdict means tests do not run yet. Like every reviewer in this pipeline, `code-review` carries no `model:` pin in its own frontmatter (confirmed: zero of 35 `agents/*.md` files set one) — the orchestrator pins the model at the dispatch call site and records it as `review_model`, resolved from the strong reasoning tier (Opus 5.5/5/4.8/4.7/4.6 for work, GPT-6 Astra/6.1 Sol/6 Sol for review). `vuln/SKILL.md`'s own `model_routing` comments describe this the same way: dispatch-pinned, never frontmatter-pinned. Findings are triaged first ([`finding-triage.md`](../../skills/_shared/finding-triage.md)) before any `review-fixer` dispatch: each finding is verified at the location it names, kept or dismissed with a reason, and the fixer sees survivors only. `BLOCK`/`PASS WITH RECOMMENDATIONS` invokes `review-fixer` for the surviving BLOCKER/MAJOR findings, then one re-review against a freshly refreshed diff; a still-`BLOCK` second verdict stops and escalates. The SIMPLE/MODERATE path has no review gate at all — `vuln-fixer` verifies against the run's baseline and there is no review step. Both paths share that one baseline, captured at the orchestrator: a `MODERATE` CVE is no longer abandoned for want of a runner while a `HIGH-RISK` one proceeds. A `TEST_REGRESSION` result on either path is never auto-resolved: the orchestrator (this skill, in the interactive session — sub-agents cannot prompt) presents the failing tests and asks apply-anyway, revert, or investigate further.

**A suite that could not run is not a regression, and the fix is kept.** When the post-fix verify returns `RUN_FAILED` or `COMMAND_NOT_FOUND`, nothing was compared — that is a fact about the environment at both ends, not about the change — so `vuln-fixer` leaves the fix applied and returns `TESTS_NOT_RUN` rather than reverting it. The CVE is then committed and offered for push like any other, any pull request you choose to open being a **draft** leading with the DO-NOT-MERGE line, and the summary table's `Result` reads `TESTS_NOT_RUN`: `OK` means the comparison happened and found no regression, and nothing else earns it. A test that fails after the fix and that the baseline never recorded is neither — it is named in that CVE's `Notes` cell as a `NEW-FAILURE` and has the same effect on that CVE's pull request. The same cell carries any `CAVEAT` the baseliner marked — a note saying a green result is not what its counts claim. A revert follows only a build that could not be made to pass, or a genuine regression you answer `revert` on. Where any edit followed the review — the resumed verify step, a regression fix — the report says which version the recorded verdict covers.

## Example

    vuln: MGD-2423:CVE-2023-46604 CVE-2024-99999

The run researches both CVEs in parallel, finds the first present in the repo and the second not (`NOT_IN_REPO`, skipped), classifies the first from its research report (say `MODERATE`), fixes it via `vuln-fixer` with a fresh test run, then commits, pushes, and opens a PR for it at Step 3.9, prints the results table with `MGD-2423:CVE-2023-46604` marked `OK` and `CVE-2024-99999` marked `SKIP`, runs `impl-maintenance`, and suggests `/compact` before the next task.

## See also

- [`upgrade:`](upgrade.md) — the sibling non-pipeline workflow for planned version bumps rather than CVE remediation; shares the same per-component classification, strong-reasoning review gate, and `test-baseliner`/`code-review`/`review-fixer` dispatch shape.
- [`finding-triage.md`](../../skills/_shared/finding-triage.md) — how `code-review`'s findings are triaged before `review-fixer` sees them.
- [`context-management.md`](../../skills/_shared/context-management.md) — the read-failure contract behind "never retry by re-deriving the artifact" on an unreadable `research_file`/`claims_file`.
- [`branch-naming.md`](../../skills/_shared/branch-naming.md) — how `vuln-fixer`'s per-CVE fix branch name is resolved.
- [`code-repo-handoff.md`](../../skills/_shared/code-repo-handoff.md) — the commit, push, and pull-request mechanics Step 3.9 runs per CVE.
- [`model-routing.md`](../../skills/_shared/model-routing.md) — the per-CVE classification heuristics and the strong-reasoning fallback chain.
