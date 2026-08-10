# Changelog

All notable changes to the **dev-workflows** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [2.15.0] — 2026-08-10

### Fixed

- **`$SPECS_PATH` is a git repository that no skill ever committed.** Seventeen of the twenty skills write bookkeeping artifacts into it — feedback, follow-ups, resume pointers — and none of them committed those artifacts. The five VI-authoring skills that do run git against the specs repo (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`) commit only their own deliverable, at a handoff phase that fires *before* the artifacts are written, so the artifacts stayed untracked by construction. `skills/_shared/feedback-emission.md` states the purpose outright — feedback reaches the maintainer only if it lands in the committed, pushed specs repo — and nothing in the plugin made that landing happen. New `skills/_shared/specs-repo-git.md` owns two entry points: `specs-preflight` at Phase 0 (flush leftovers onto the current branch, retry an artifact commit whose push failed, settle the branch) and `commit-artifacts` as the run's last action (stage the bounded artifact paths, commit `<KEY|NOISSUE> Add dev-workflows session artifacts (<skill>)`, push). Every git call is `git -C "$SPECS_PATH"` and never a `cd` — the caller is often standing in a different repository when these run (a code repo for `implement:` / `vuln:` / `upgrade:`, a docs repo for `document:`), and a `cd` there would corrupt its git state. Staging is by enumeration, never by glob, and never `git add -A` at repository scope. The plugin manages only branches it created (`vi|ard|spec|design/*`); a detached HEAD is the one blocking state, because a commit made there is reachable from no ref and garbage-collectable, and a run that reported a SHA over it would be a failure that looked like success.
- **Two skills' preflight silently never ran, defeating the detached-HEAD guard on exactly the paths most likely to hit it.** `implement:`'s executable `specs-preflight` citation sat inside `## Phase 0.5 — Readiness pre-flight`, a phase whose own first instruction is "When `mode: direct` this phase is a no-op — skip it entirely" — so every direct-prompt run skipped the preflight while `commit-artifacts` still ran unconditionally at the end. `document:`'s executable citation sat inside Mode A's own Phase 0, but `## Mode detection` dispatches to a mode *before* that phase is reached — so a Mode B (direct doc-edit) run jumped straight past it and never executed the preflight either, while its own `commit-artifacts` still ran. Both meant `specs_git: blocked` could never be set on a detached HEAD along those paths, so the terminal commit's data-loss guard silently did not exist there while the commit itself still fired. Fixed by moving `implement:`'s preflight to the end of the always-run `## Phase 0 — Load and classify inputs`, and `document:`'s to the shared `## Mode detection` section that runs before either mode is entered.
- **Ten skills that write `resume.md` wrote it too early to be captured by the new terminal commit.** The printed `### Context hygiene` block instructed the write at report-composition time — before the follow-up phase, and before any commit step existed at all. All ten (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `ready:`, `release-notes:`, `implement:`, `document:`) now write the pointer as the last step of the terminal follow-up phase, immediately before `commit-artifacts` runs, so it ships in the same commit. The five skills that write no `resume.md` at all (`idea:`, `implement:` direct mode, `document:` Mode B, `vuln:`, `upgrade:`) are unaffected — they were already on `session-hygiene.md` §1's skip list.
- **Ninety-eight `NEVER commits` / resume-ordering / push / `description:` sites had to be re-checked against the two new terminal steps; forty-seven needed rewriting and twenty-two needed an added reason.** Swept across four families — commit assertions (nine phrasing variants, including forms that wrap across a line break), `prepare-first (resume.md)` resume-ordering assertions, push assertions, and frontmatter `description:` claims — and reconciled rather than deleted: the protective intent is real, only the scope changed. Twenty-nine sites were already precisely scoped and left untouched.

### Added

- **`skills/_shared/specs-repo-git.md`** — the bounded write authority (two path shapes, `^(vi|ard|spec|design)/` branches), the three preflight guards and their four-part notice contract, the three-stage resolution, the seven-step commit, and the `Specs repo:` outcome line. Never force-pushes, never `branch -D`, never merges/rebases/resets, never deletes an `index.lock`, and never fails the run. This edition has no cost subsystem — no `cost-emission.md`, no `emit-cost`, no `dev-workflows-cost/` path shape — so the artifact set committed is feedback, follow-ups, and the resume pointer only.
- **A `Specs repo:` outcome line at the end of every in-scope run** — eighteen sites, one per skill plus one per `document:` mode. Where the Final Report is the run's last output the line lives in the report template; where the report is composed before the terminal phases, `commit-artifacts` prints its own block, as the follow-up phase already does.

## [2.14.1] — 2026-08-10

### Fixed

- **Haiku 4.5 was listed as a strong-tier fallback.** `README.md`'s chain read `Opus 4.8 → 4.7 → 4.6 → Haiku 4.5 → GPT-5.5 → …`, so a SIGNIFICANT or HIGH-RISK gate would degrade to the cheapest model in the lineup before trying a strong peer. Removed. The root cause was drift: the edition documented its chain in three places — `skills/_shared/model-routing.md`, `.github/copilot-instructions.md`, and `README.md` — and the three had diverged in three different directions. All three now flatten to one sequence, with `model-routing.md` as the authority.
- **The model references had gone stale.** The strong-tier peer set grows from four to six — `claude-opus-5` first, `gpt-5.6` second, the existing four in their prior relative order. It remains a *peer set*, not a ladder: the "prefer the model the orchestrator is already running under" rule and the never-announced-as-a-downgrade semantics are unchanged. Further fallbacks renumber from 7. The peer label `Opus 4.8/4.7/4.6 or GPT-5.5` becomes `Opus 5/4.8/4.7/4.6 or GPT-5.6/5.5` across nine reviewer agents (frontmatter and body), the preload hook, both READMEs, `copilot-instructions.md`, and both catalogs.

### Added

- **`claude-sonnet-5`, which this edition was missing entirely.** It appeared in neither the strong-tier further-fallbacks list nor the mid-tier detection chain — the canonical edition has carried it for some time and the B-series ports never brought it across, leaving the detection tier topped at Sonnet 4.6. It now sits above `claude-sonnet-4.6` in both.

## [2.14.0] — 2026-08-10

### Fixed

- **The deprecation note was not missed. It was forbidden.** `agents/doc-location-finder.md`'s exclusion rule banned every path under `_content/whats-new/...` as a `release-notes:`-only destination — correct for the 182 automation-generated pages at that prefix, wrong for the 10 hand-authored announcement pages (`end-of-life-announcements.md`, `end-of-support-news.md`, `technology/index.md`) that live under the same prefix and have no automation touching them at all; their git history is human PRs. The rule's exclusion set is now keyed on what's genuinely automation-owned — `meta.content-type: release-notes` frontmatter, `_data/release-notes/**`, `_snippets/release-notes/**` — and gains one named exemption: a page declared in the profile's new `announcement_pages` block (`{postid, path, kinds}`, in `_shared/dynatrace-docs/docs-profile-schema.md` + `.default.yml`) is a valid target, proposed **alongside** the feature-subtree target rather than in place of it. `doc-location-finder`'s two mirrors in `agents/doc-planner.md` change in lock-step — removing one and leaving the others is a failure mode this repo has hit before. A repo with no `announcement_pages` block falls back on the same content-type-keyed heuristic, which is necessary rather than decorative (`end-of-support-news.md` carries no `content-type` at all). `docs-profile:` learns to discover the block.
- **The provenance comments were not improvised. They were mandated.** `agents/doc-writer.md` and `doc-reviewer.md` dimension 12 ("Source traceability") required every claim to cite its Jira key and/or PR URL inline — while three other places in the same plugin (`doc-writer.md`, `doc-planner.md` ×2, `skills/document/SKILL.md`) already stated the opposite: traceability lives in the commit message, not the reader-visible page. The writer emitted provenance and the reviewer endorsed it, both correctly following instructions the plugin itself contradicted. New `_shared/doc-structure-conventions.md` §1 states the boundary once — rendered page carries the customer-facing claim only, the commit message carries the Jira key, the run handoff carries per-claim attribution — and `doc-writer` + `doc-reviewer` now cite it instead of restating it. Dimension 12 **inverts**: a Jira key (bare or as a `[[wikilink]]`), a PR URL, or a `<!-- KEY: … -->` comment appearing anywhere in a written file is now **MAJOR**. The `source-truth.md` §7.6 `<!-- intentional-discrepancy: … -->` marker is unaffected — it's a deliberate, user-decided gap flag, not provenance.
- **`doc-location-finder`'s input contract had a scope gap.** It defined its entire input as `repo_root`, `feature_summary`, `diff_highlights` — no `target_spaces`, no `profile` — so nothing stopped it proposing a SaaS-only path on a Managed-only run. Both are now part of the contract, and `skills/document/SKILL.md` passes them.

### Added

- **Callout scope and adjacency — new `_shared/doc-structure-conventions.md` §2.** A callout that qualifies one option in a mutually exclusive set is placed with that option, immediately beneath it, never as an *unqualified* trailing block after the whole set — a trailing callout that names its own scope in its first clause is §2 rule 3's permitted alternative, and the enforcers carry that carve-out so a page following it is not flagged; a callout that applies to the whole set goes in the lead-in, before the options. `doc-planner` plans placement per option, `doc-writer` writes it, and `doc-reviewer` flags a scope violation at **MAJOR** — a misread scope changes what the customer believes is required or prohibited. The motivating case: an ARM limitation specific to the built-in cluster container registry read as applying to all four registry options on the shipped page, including a customer-owned private registry where it's simply false.
- **Component-pattern fidelity — `doc-structure-conventions.md` §3.** `doc-planner`'s existing 5–10-page sibling sample (already used to classify image policy) gains a second job: recording which content component the area already uses for a recurring content shape, as a `component_patterns` block (`shape`, `component`, `evidence`, `count`). `doc-writer` reuses the dominant component for a matching shape instead of inventing a structure; `doc-reviewer` flags a divergence at **MINOR** (an ad-hoc structure still renders). No component list is vendored — the rule is repo-agnostic and the evidence always comes from whatever repo is in front of it. On the shipped page, 4 of 5 sibling pages used `{{#tabgroup}}` for the same mutually-exclusive-options shape the writer built ad hoc.
- **Images: one phase, two lists.** Phase 5.6 is now the single image step and **always runs**, sourcing a to-add list (unchanged) and a possibly-stale list — every image already present on an `extend-existing` target, listed **per occurrence** (not per URL) with its section and space-gating (`{{#if project='…'}}` or none). Answering "No screenshots needed" no longer skips the phase outright, which is exactly how three stale images — one of them SaaS-gated in a space where the feature doesn't exist — survived a run where the user was asked about screenshots and answered. Stale replacements reuse the existing Phase 6.1 CDN-URL-collection flow, and the writer swaps the existing reference rather than inserting a new one. CDN immutability — every new or replacing screenshot is a new URL; an image is never refreshed in place — is now stated in `docs-profile.default.yml`'s `images.policy`, `docs-profile-schema.md`, and the `doc-writer` image step. `doc-reviewer` dimension 9 extends to swap completeness: every accepted replacement URL must land at every occurrence the review listed, or the stale image stays live and invisible in the diff.
- **New ledger gate `image_review` — `_shared/gate-ledger.md` §4.** Phase 5.6, preconditioned on ≥1 candidate image (to add or possibly-stale). It's an input-side gate rather than an output-verification gate like the other six, but the accountability need is identical. The §4 direct-mode carve-out paragraph is updated in the same edit — direct mode has no Phase 5.6, so the "three registered, N never-appearing" gate count becomes four never-appearing.
- **Anchor conventions — new `_shared/dynatrace-docs/anchor-conventions.md`.** One `{:#id}` per heading — multi-anchor `{:#a #b}` is unsupported (0 occurrences across 1,580 files under `dynatrace/_content` + `managed/_content`); the four verified link forms (`[text](postid)`, `[text](postid#anchor)` — 19,560 occurrences, `[text](#anchor)` — 4,006, `{{#tabgroup anchor='id'}}` — 698); the `pnpm docstack validate-anchors` contract (an anchor link must target a hardcoded id, not a generated one); and the reconciliation rule that a product `dt-url` deep link's anchor wins — a mismatch is recorded as a Phase 5.8 discrepancy, never deferred on an in-session judgment that the syntax "appears unsupported." Consumed by `doc-writer` (authoring), `doc-reviewer` (dimension 5), and `doc-planner` (planning cross-link anchors).
- **Lifecycle dates — a twelfth `source-truth.md` §2 claim class.** End-of-life, end-of-support, shutdown, sunset, and availability dates are now a verified claim type, checked against UI notice strings and banner constants, announcement/config expiry values, feature-flag sunset metadata, and sibling announcement pages that already carry the date. A load-bearing milestone-equivalence rule ships with it: compare the milestone a date denotes, not its surface form — "EOY 2027," "end of 2027," "December 31, 2027," and "stops working on January 1, 2028" all denote one boundary and are not a discrepancy; a discrepancy exists only when the milestones genuinely differ. Without this rule the class would be a false-positive generator. §7.5's `<KEY>-implementation-gaps.md` bug-report trigger widens to `document-as-code`, conditionally: emit a gap only when the Jira phrasing asserts a specific value that **contradicts** the source; skip when it's merely vague or non-committal. The judgment resolves toward over-inclusion — a spurious entry costs a paragraph the user reviews; a miss leaves a wrong customer-facing claim in the ticket indefinitely.
- **`doc-reviewer` grows from 16 to 17 dimensions.** New: **Page structure conventions** (callout scope + component-pattern fidelity, above). Extended: **Structural integrity** (anchor form and the `validate-anchors` contract), **Screenshots** (swap completeness), **Source traceability** (inverted, above). The dimension table and the output-slot headings stay in lock-step, seventeen of each, per the existing "never invent a dimension beyond the ones listed" rule.
- **Phase 8 maintenance agents split into propose and apply.** Agents 2 (knowledge base) and 3 (instructions, incl. `copilot-instructions.md`) stop writing into the target docs repo directly — each now returns a precise proposed edit (file, anchor, replacement text, reason) instead of applying it; Agent 1 (documentation) and Agent 4 (`impl-maintenance`, already suggest-only) are unaffected. A new apply phase — Jira mode Phase 8.6, running after Phase 8.5 has sealed the docs commit; direct mode Phase 4.5, between maintenance and the final report — presents the proposals (`choices: ["Skip — report only (Recommended)", "Apply all", "Choose per proposal", "Cancel"]`) and, on acceptance, re-dispatches the same agent in apply mode. Applied edits are left **uncommitted** by design: because the phase runs after the squash, an accepted `copilot-instructions.md` edit can never ride the docs commit or the docs PR — a governance change needs its own PR on the user's own timing. The Phase 9 / Phase 5 final report gains `### Maintenance applied (uncommitted)` sections and per-proposal `disposition` tagging under the existing Knowledge base / Instructions headings. `skills/document/SKILL.md` and `_shared/finish-and-handoff.md` drop the "Agent 3 (`copilot-instructions.md`) may have edited without committing" clause — nothing uncommitted originates there anymore.

## [2.13.0] — 2026-08-08

### Added

- **`document:` Phase 0 toolchain preflight — new `_shared/toolchain-preflight.md`.** Before anything is written, the run derives the tools its gates will invoke — from the resolved profile (`commands.*`, `commands.per_space.*`, `dev_servers[].command`, `prerequisites`), the repo's config signals (`.vale.ini`, `pnpm-lock.yaml`/`package-lock.json`/`yarn.lock`, `node_modules/`, `.markdownlint.json(c)`, `.remarkrc*`), and the repo's own documented `Prerequisites` section — checks each with `command -v` / `test -d`, and maps every tool to the gates it powers. On a healthy container it contributes one Readiness row and never prompts. When something is missing it states the run's outcome in advance ("with `vale` and `pnpm` missing, `style_check` would be DEGRADED, `build_check` and `render_smoke_check` UNAVAILABLE") and offers Cancel as the recommended option, so a run started in the wrong container stops before writing rather than shipping quieter, worse documentation behind a green CI. Direct mode gets the same check scoped to the style gate, deriving its required set without a profile.
- **Gate ledger — new `_shared/gate-ledger.md`.** Six outcomes — `RAN`, `DEGRADED`, `FAILED`, `UNAVAILABLE`, `SKIPPED_BY_USER`, `NOT_APPLICABLE` — and **none of them is an orchestrator-assignable "skipped"**. Every non-run path terminates in a named missing precondition, a named missing tool, or the user's decision quoted verbatim; `UNAVAILABLE` is explicitly not a resting state and is converted by asking. Each gate appends its row **when it completes**, never reconstructed at report time. `doc-reviewer` gains a **Verification-gate integrity** dimension that BLOCKs on a missing row, an unconverted `UNAVAILABLE`, an unattributed skip, or an underpopulated `DEGRADED`, and Phase 9 prints a `### Verification gates` table naming what CI will check that the run did not.
- **"Choice lists are presented verbatim" in `_shared/escalation-rules.md`** — a phase's options, their order, their wording, and the `(Recommended)` marker are not the orchestrator's to change; an orchestrator that disagrees says so in prose beside the list. Binds every skill. This is the rule a `document:` run broke when it moved `(Recommended)` onto Phase 6.5's Skip option and never exercised the render gate.
- **`commands.per_space` in the docs profile.** `dynatrace-docs` defines `dynatrace:lint`, `managed:lint`, `dynatrace:build`, and `managed:build`; the built-in profile knew only `pnpm dynatrace:lint` and no build command at all. Per-space `lint`/`build`/`format` are now declared, documented in `docs-profile-schema.md`, and detected by `docs-profile:`.
- **Commands and code blocks are a verified claim class.** `_shared/source-truth.md` §2 gains a row for helm/kubectl/pnpm invocations, flags, image references, chart names, registry paths, and YAML keys in fenced blocks, plus a §3.7 technique that checks them against `Chart.yaml`/`values.yaml`/`templates/**`, the release workflow, sibling docs pages, and `--help` output. `doc-reviewer` checks them in **every** run at MAJOR — readers run a documented command verbatim, so an unverified one is a defect even when the rest of the page verified cleanly.
- **`repo_verification_gates` from `doc-planner`.** The repo's own pre-PR checklist — for `dynatrace-docs`, `CONTRIBUTING.md` `## PR checklist` — is now extracted and checked, instead of being discarded by the planner's "ignore operational content" rule. `doc-reviewer` holds the written files against each gate and cites the repo's own section in the finding.

### Fixed

- **`docs-style-checker` climbs the ladder instead of jumping off it.** A failure at any primary rung now continues to the next rung; previously every step-1/2/3 failure jumped straight to `dt-style-checker`, so a repo with a `.vale.ini` but no `vale` binary silently abandoned `pnpm dynatrace:lint` — the linter CI actually runs. Step 2 also becomes space-aware through a new optional `spaces` input, so a Managed-only file set is linted by `managed:lint` rather than the SaaS linter, and a new `primary_attempts` output records every rung tried, which is what fills the ledger's `not_run` and `ci_still_checks`.
- **`_shared/dynatrace-docs/render-verification.md` no longer claims dynatrace-docs has no build command.** That false statement disabled Phase 6.5's gating Step 1 outright; `dynatrace:build` and `managed:build` both exist and now run per space.
- **The render smoke-check boots the protected space, not only the target.** The cross-space invariant has two halves — the delta marker PRESENT in the target render and ABSENT in the protected one — and iterating `target_spaces` alone could never check the second, which is the half the 3a protection depends on. Static conditional analysis is declared necessary but never sufficient: it corroborates the gate and can never satisfy it.
- **`changelog-guidelines.md` has consumers in the write path.** It was cited only by a skill that no agent invokes and `doc-writer` cannot invoke (its tool list has no skill-invocation capability), so `doc-planner`, `doc-writer`, and `doc-reviewer` each worked from two inlined rules. All three now read the reference itself; a non-conforming entry — meta phrasing, a run of "Added", internal jargon such as "Managed-only", a broken period rule — is a MAJOR reviewer finding. No rule text is duplicated.
- **Phase 5.8 tries once more before escalating.** An `AMBIGUOUS`/`NOT_FOUND` verification warning whose repo is resolved in `code_repos` now gets one supplementary direct grep against the local path — **including when `diff-summarizer` returned `REFRESH_BLOCKED`**, since a read-only mount that cannot `git fetch` can still be grepped. Resolving a claim this way records the gate as `DEGRADED`, never a clean `RAN`.
- **`status: NOT_CONFIGURED` stops being a silent proceed, in both modes.** It now maps to an `UNAVAILABLE` ledger row that must be converted by asking the user, rather than a no-op on the way to the reviewer. Jira mode converts it before `doc-reviewer`; direct mode, which has no reviewer gate, converts it before Phase 4.

## [2.12.0] — 2026-08-07

### Changed

- **Release-notes field hygiene — `create-vi:` and `release-notes:` stop asking for Jira dropdowns.** `release_versions`, `change_type`, and `release_notes_category` were filed as PM-authorable VI frontmatter; they are Jira dropdowns the PM sets on the ticket and the importer returns on the round-trip, so they move to the Jira-mirror class in `_shared/vi-format.md`. `create-vi:` no longer asks for any of them and `vi-reviewer` no longer requires or validates them. A dropdown question earns its place only when the answer changes what the plugin generates — deciding it in a chat window costs exactly what deciding it in Jira costs.
- **`_shared/release-note-types.md` rewritten as a destination + shape authority.** Evidence from the shipped `dynatrace-docs` corpus: across 852 `{{#context}}` lines in generated release-note snippets, none carries a change type — the Change Type instead routes the note to `breaking-changes.md`, `feature-updates.md`, or `fixes.md`. And `fixes.md` publishes one bare sentence (1 `{{#context}}` line across 57 files) rather than label + title + prose, so classifying a VI as `Bug fix` used to emit an unpublishable shape. The reference now maps Change Type → destination → draft shape, and adopts the docs team's own per-destination prose rules (breaking: present tense + remediation link; feature update: benefit-led + a docs/blog link; fixes: one past-tense sentence).
- **A deprecation is never classified `Bug fix`.** `fixes.md`'s one-bare-sentence shape has no `{{#context}}` line, no title, and no room for a trailing `> Note:` line — so a deprecation routed there would have nowhere to carry its required end-of-life date. §2's tie-breakers now exclude `Bug fix` outright for a deprecating change: it resolves to `Breaking change` when the customer must act now, else `New technology support` when a new capability supersedes the old one, so the note always lands in a titled destination with room for the §5 deprecation note.
- **The feature-update documentation link is now phase-gated.** `release-notes:` runs twice in a VI's life — once from the PM at VI creation, once from the dev after implementation — and only the second run has a page to link to. The writer resolves `run_phase` from the `specification.md` / `design.md` presence signal under the VI's specs dir: neither file present → `pm`, and the link is omitted entirely (never asked for — the feature isn't built and the docs don't exist yet); either present → `dev`, and the author may supply a redirect short link. No URL is ever invented at either phase.
- **The `{{#context}}` label is now sourced, not guessed.** It is exactly the Dynatrace Solution taxonomy the VI already carries as `release_notes_category` — yet `release-notes-writer` was explicitly forbidden from using it, so it guessed and then asked. The prohibition is gone: the label is the imported `release_notes_category` used verbatim, and the line is omitted when the import carries none.
- **Exactly one Summary per run.** `release_versions` used to emit one Summary block per declared version, but the prose may never name a version — so the blocks were identical. The `(unspecified)` fallback and the `release_version` gap are gone.
- **`release-notes:` is gated on `relevant_for_release_notes`.** An explicit `false` in the *imported* frontmatter stops the run with `RELEASE_NOTES_NOT_RELEVANT` (overridable); an absent value proceeds silently, since the field defaults to true. Previously the check ANDed the flag with `release_versions`, so a VI correctly flagged not-relevant still proceeded whenever a version happened to be set.
- **One question survives, reframed.** A low-confidence *destination* inference is still confirmed — but only when the Jira dropdown is unset, and the options now name each choice's shape and destination file instead of the four opaque enum values.
- **Two long-standing contract defects corrected.** `skills/_shared/handoff/release-notes-writer.md` typed `release_notes_category` with the `change_type` enum (it is a free-text Dynatrace Solution name) and omitted `"note in report"` from `recommended_action`. Both blocks were rewritten by this change.

## [2.11.0] — 2026-08-04

### Changed

- **Branch naming is now repo-rule-first.** 2.10.0 wired the previously-orphaned `$GIT_USER_INITIALS` ladder into all five branch-creating workflows, but left it as the *primary* mechanism — and only `document:` and `docs-profile:` ever read the target repo's own branch-naming convention, so `_shared/branch-naming.md`'s claim that a documented pattern "outranks this ladder" was unenforceable in `implement:`, `upgrade:`, and `vuln:`. The priority is inverted and the gap closed. All five now read the repo's `CONTRIBUTING.md` / `CONTRIBUTION.md` / `README.md` / `DOCUMENTATION-GUIDELINES.md` / `.github/copilot-instructions.md` **first** (§1.1), classify the documented pattern's segments (§1.2), and fill each from its proper source: an **identity** placeholder (`<your-name-or-initials>`, `<user>`, …) from the `$GIT_USER_INITIALS` → `git config user.initials` → existing-branch-inference → prompt ladder, now §2; an **issue-key** segment from the run's already-resolved Jira key (or the documented no-issue literal); the **description** from each workflow's own slug rule (§3). Against `dynatrace-docs`' documented `<your-name-or-initials>/<JIRA-ISSUE-KEY>-<short-branch-name>`, `GIT_USER_INITIALS=iv-gu` now yields `iv-gu/PRODUCT-17753-add-oauth`. The ladder supplies the *whole* prefix only when a repo documents no convention at all (§1.4).
- **A pattern with no identity segment no longer gets one.** Injecting initials into a repo whose documented convention is a plain `feat/<slug>` would violate that convention; §1.2 and §5 now forbid it. Identity inference ignores the generic prefixes, and the §2.5 escalation drops its generic-fallback choice when an identity is being filled.
- **`implement:` composes a compliant name in issue-key repos.** When a documented pattern has no separate issue-key segment but the run resolved a Jira key, the key is prefixed to the slug (`<KEY>-<slug>`).

## [2.10.0] — 2026-08-04

### Added

- **`_shared/branch-naming.md` is now actually wired in.** The shared branch-prefix policy has shipped since 1.6.0 and the README described it, but **no skill ever loaded it** — every branch-creating workflow silently used its own inline `git branch -a` sniff, so `$GIT_USER_INITIALS` had no effect anywhere. All five branch-creating orchestrators now resolve their prefix through the §1 ladder: `implement:` (Phase 3 step 2), `document:` (Phase 6.2 steps 3–4, both modes), `docs-profile:` (Phase 6 step 1), `upgrade:` (Phase 2 prep), and `vuln:`'s "Git Workflow" spec that `vuln-fixer` follows. Setting `GIT_USER_INITIALS=iv-gu` now produces `iv-gu/PRODUCT-17753-add-oauth` instead of `feat/add-oauth`.

### Fixed

- **The prefix ladder rejected hyphenated initials.** §1.3's inference pattern was `^[a-z0-9]+$` while §4's hard rules allowed `[a-z0-9-]`, so existing `iv-gu/…` branches were invisible to inference and the §1.5 prompt told users "alphanumeric". Inference now accepts `[a-z0-9][a-z0-9-]*` and both prompts say `[a-z0-9-]`. (`$GIT_USER_INITIALS` was always taken verbatim, so §1.1 was unaffected.)
- **Reaching the per-workflow fallback was silent.** §1.5 mandated a prompt, but no orchestrator implemented it. The prompt is now registered in `_shared/escalation-rules.md` as "Branch prefix undetected" and referenced from each branch-setup step.
- **`docs-profile:` derived initials from `git config user.name`** in its own ad-hoc way, ignoring `$GIT_USER_INITIALS` entirely. It now uses the shared ladder.

## [2.9.4] — 2026-08-02

### Fixed

- **`vuln:` + `upgrade:` re-review read a stale diff.** After `review-fixer` applied the `BLOCKER`/`MAJOR` fixes, "re-run the Opus review once" re-used the `review_diff_file` captured *before* those fixes, so the second verdict was computed on the pre-fix diff (and a `BLOCK` could never clear). Both paths now overwrite `review_diff_file` with a fresh `git add -N . && git diff` before the re-review — the same correction `implement:` received as a 2.9.2 follow-up but which was not carried into the 2.9.3 siblings.
- **`implement:`'s `test-writer` dispatches told the agent to shell out.** Phase 3.5 step 1 and Phase 3B step 4a embedded the `mktemp` + `git add -N . && git diff` capture *inside* the agent-facing prompt and left it unbracketed; `test-writer` has no `bash` tool, so it could not comply. The capture is now an orchestrator action recorded as `test_diff_file`, and the prompt hands only that path — matching the `document:` + `epics:` handoff pattern.
- **Dispatch substitution brackets carried instructions instead of values.** `vuln:`'s two `vuln-fixer` dispatches and `upgrade:`'s `upgrade-executor` dispatch wrapped the whole "read … from the file at `<handle>`" sentence in `[…]`, which the house convention reads as "substitute the content here" — the opposite of the intent, and enough to defeat the file-handoff. Only the path handle is bracketed now.
- **`vuln:`'s SIMPLE/MODERATE regression-resume was a missed adoption site.** It still said "passing the same CVE input verbatim" while every other `vuln:` resume had moved to `research_file`.
- **`vuln-fixer` + `upgrade-executor` never received the `phase: regression-resume` directive.** The Claude edition's `## Process` "Phase resume" callout tells both agents to skip straight to the test-regression step on `phase: regression-resume`; this edition carried only the `verify-resume` half, so a regression resume would have re-run the baseline/fix/apply steps. Long-standing conversion gap, now ported.
- **`skills/_shared/context-management.md` omitted the load-bearing temp-file guard.** As the authority for "hand off by file, not paste" it did not say the handoff file must be `mktemp`-ed **outside every repo working tree** — the property that keeps a later `git add -N . && git diff` from picking it up.
- **`skills/_shared/handoff/vuln-fixer.md` + `skills/_shared/handoff/upgrade-executor.md` described their report/plan section as inline-only.** Both now state the section may instead arrive as an absolute path to read, matching what the orchestrators have sent since 2.9.3.
- **Claude tool names leaked into agent/skill prose.** Sixteen references instructed agents to use `Read` / `Write` / `Glob` / `Grep` / `LS` — tools this edition never grants; its frontmatter grants `view` / `create` / `edit` / `glob` / `grep` / `bash` / `task` / `web_fetch`. Affected `code-review`, `risk-planner`, `test-writer`, `review-fixer`, `vuln-fixer`, `upgrade-executor`, `epic-writer`, `ready:` Phase 4, and both `skills/_shared/handoff/` docs. Same defect class as the `test-writer` shell-out above: an agent told to use a tool it does not have.
- **Stale sub-agent counts in the manifests.** The marketplace entry said “Thirty-one dispatched sub-agents” and the repo-root `README.md` tree said “30 sub-agents”; there are 32 (matching `dev-workflows/.plugin/plugin.json`'s “32 sub-agents” and the 32-row agent table in `dev-workflows/README.md`). Both corrected.
- **`agents/risk-planner.md`'s requirement-ID example used the wrong form.** `[AC-3]`/`[TC-7]` → `[AC03]`/`[TC07]`, the form `skills/_shared/specification-format.md` defines and `code-review`'s spec/design-conformance dimension traces against.

## [2.9.3] — 2026-08-02

### Changed

- **`vuln:` + `upgrade:` now hand their large dispatch artifacts to sub-agents as temp-file paths instead of pasting them inline.** The `vuln:` research report (to `vuln-fixer`, `code-review`, and the resume steps) and the `upgrade:` planner handoff (to `risk-planner`, `upgrade-executor`, and the resume step), plus each command's `code-review` `git diff`, are written to `mktemp` files — outside every repo working tree, so a captured `git diff` never picks them up — and handed as absolute paths. Extends the `implement:` file-handoff (2.9.2) and the `document:` + `epics:` pattern to the two remaining code-oriented skills; `vuln-fixer` and `upgrade-executor` `## Process` now notes that a field may arrive inline or as a path to `Read`. Behavior-preserving.

## [2.9.2] — 2026-08-02

### Changed

- **`implement:` now hands its large dispatch artifacts to sub-agents as temp-file paths instead of pasting them inline.** The multi-source codebase summary (Phase 1.7 / 2B), the approved plan (Phase 2A / 2B), the review diff (Phase 3B / 3.5), and the code-review report (Phase 3B review-fixer) are written to `mktemp` files — outside every repo working tree, so a captured `git diff` never picks them up — and handed to `risk-planner` / `test-writer` / `code-review` / `review-fixer` as absolute paths. This matches the existing `document:` + `epics:` handoff pattern and keeps the orchestrator's context lean on long runs. Behavior-preserving: each agent receives identical content, and its `## Inputs` now notes that a field may arrive inline or as a path to `Read`.

## [2.9.1] — 2026-08-02

### Fixed

- **`skills/_shared/context-management.md` 4th-strategy consistency.** The wave-3 "Hand off by file, not paste" bullet left the section's trailing "Prefer the cheapest strategy…" summary enumerating only the original three offload strategies. Clarified that "Hand off by file" is orthogonal — applied whenever a sub-agent is dispatched, regardless of the chosen offload strategy. (Whole-branch-review NIT follow-up.)

## [2.9.0] — 2026-08-01

### Added

- **Deferred-backlog sharpeners (wave 3)** (ported from the Claude edition). Six additive, single-location refinements (all additive/conditional):
  - **ADR candidacy filter** — `skills/_shared/ard-format.md`: an `AD-N` earns its place only when the decision is hard-to-reverse AND surprising-without-context AND a real trade-off (else left to `design:`). [Matt `domain-modeling`]
  - **Wide-refactor sequencing exception** — `skills/epics/SKILL.md` Phase 2: expand → migrate-in-batches → contract for blast-radius-wide mechanical changes that cannot be tracer-bulleted. [Matt `to-tickets`]
  - **Prototype-snippet exception** — `skills/_shared/design-format.md`: a narrow decision-encoding-snippet exception to the prose default. [Matt `to-spec`]
  - **Missing-adoption gap** — `agents/code-review.md` dimension 4: an untouched sibling call site that should adopt changed behavior, uncaught by tests. Complements the wave-2 converge gate. [BMAD `lens-verification-gap`]
  - **`resume.md` redaction reminder** — `skills/_shared/session-hygiene.md`. [Matt `handoff`]
  - **Context "hand off by file, not paste"** — `skills/_shared/context-management.md`: a 4th long-run strategy (reference-only; the `implement:` dispatch-prompt refactor is deferred). [superpowers SDD]

## [2.8.0] — 2026-07-29

### Added

- **Upstream-harvest improvements** (ported from the Claude edition). Adapted eight improvements from four upstreams (GitHub SpecKit, Matt Pocock skills, superpowers, BMAD) into the pipeline, all additive and conditional:
  - **Spec→code conformance ("converge").** `code-review` gains a conditional 10th dimension "Spec/design conformance" (active only when a `specification.md`/`design.md` is in scope) that traces every in-scope `[Uxx]`/`[ACxx]`/`[TCxx]` against the shipped diff (satisfied / missing / partial / contradicts). `risk-planner` tags plan steps with the requirement IDs they implement. `implement:` extracts in-scope IDs, passes `applicable_spec` to the Opus review, reports conformance in Phase 5, and escalates unresolved gaps as `- [ ]` notes back onto the spec/design.
  - **Bug-diagnosis discipline.** New `skills/_shared/bug-diagnosis.md` — red-capable repro before hypotheses, 3–5 ranked falsifiable hypotheses, `[DEBUG-xxxx]` instrumentation with a cleanup gate, regression test at a correct seam. Folded into `risk-planner` (`task_shape: bug`) and `implement:` (bug-shape detection + strip-before-review; `code-review` flags leftover `[DEBUG-xxxx]`).
  - **Quality gates.** `test-writer` falsifiability gate + mutation self-check; `review-fixer` `plan-conflict` disposition; `code-review` Fowler 12-smell floor (MINOR/NIT, overridable).
  - **Authoring sharpeners.** `grilling-technique.md` terminology-precision move + altitude-aware `## Ambiguity taxonomy`; `spec-reviewer` NFR-coverage + implicit-enum-branch; `design-format.md` + `design-reviewer` deep-module/seam vocabulary; `risk-planner` "No placeholders"; `vi-format` + `vi-reviewer` counter-metrics (`[SM-C1]`).
  - Renamed the grill's "design tree" → "decision tree".
- Reconciled the marketplace manifest version (was stale at 2.5.0) to the plugin version.

## [2.7.0] — 2026-07-23

### Changed

- **No-hard-wrap prose convention.** New `skills/_shared/prose-formatting.md` — the single source of truth: never hard-wrap prose; write each paragraph/prose block as one unbroken line, since Obsidian and IntelliJ Idea both soft-wrap for reading, and a straight copy-paste into Jira/Grammarly needs no manual cleanup. Consumed by every authoring skill/agent that writes prose: `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epic-writer`, `doc-writer`, `release-notes-writer`. Ported from the Claude Code edition (dev-workflows 2.37.0).

## [2.6.0] — 2026-07-21

### Added

- **Documentation grounding on `$DOCS_PATH`.** `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, and `specify:` now ground their grill on the product's existing shipped documentation when `$DOCS_PATH` (default `${DOCS_PATH:-/workspace/docs}`) is set and valid; `epics:` and `release-notes:` attach the same docs digest to their writer handoff. New `skills/_shared/docs-grounding.md` — the single source of truth for the `resolve-docs-grounding` resolution gate (read-only, silent non-blocking skip on any miss), the `dispatch-docs-grounder` procedure (`task(agent_type: "dev-workflows:docs-grounder")`), and the two consumption modes (grill-rank for the five grill commands; writer-attach for `epics:` and `release-notes:`). New read-only `docs-grounder` agent (`tools: [view, glob, grep, bash]`) — retrieves via the `qmd` CLI when available (`qmd update`, never `--pull`), falling back to keyword-overlap + `git log --grep` matching. Grounding is **positive-first**: each match is classified by `relation` (`same_feature` / `analogous_precedent` / `building_block`) with extracted `structural_facts`, plus bounded reconciliation `docs_challenges` (`already_documented`, `terminology_mismatch`, `contradicts_documented_behavior`, `diverges_from_precedent`, `adjacent_undocumented`). Advisory only — never a gate, never a reviewer BLOCKER; disable per-run with `--no-docs` or override the root with `--docs <path>`.
- **`document:` docs-repo discovery hint.** `document:` (Jira mode) now prefers `${DOCS_PATH:-/workspace/docs}` as a docs-repo discovery hint (checked between the cwd-with-signals path and the `$REPOS_PATH` search) — a write-target hint only, with no `docs-grounder` consumption.

## [2.5.0] — 2026-07-18

### Added

- **`create-vi:` captures the release-note Change Type + category (write-side).** `_shared/vi-format.md` frontmatter gains optional `change_type` (`Breaking change | New technology support | Bug fix | not applicable`) and `release_notes_category` (the Dynatrace Solution), authored-then-mirrored like `release_versions`. The `create-vi:` grill asks for both only when `relevant_for_release_notes: yes`; dates/deprecation stay out of frontmatter (they belong in the release-notes Summary). `vi-reviewer` validates `change_type` — `MAJOR` if outside the four-value enum, `MINOR` (recommended, not required) when `relevant_for_release_notes: yes` but `change_type` is absent; `release_notes_category` is free text. Completes the write-side of the Change Type sourcing ladder from 2.4.0, so a PM-phase `release-notes:` run can read the authored `change_type` from the specs-draft VI.

## [2.4.0] — 2026-07-17

### Added

- **Release-note Change Type classification (`release-notes:`).** `release-notes-writer` now classifies every draft into one of four Change Types — **Breaking change** / **New technology support** / **Bug fix** / **not applicable** — via a new `_shared/release-note-types.md` source-of-truth reference (taxonomy, classification order, per-type Summary shaping, and the deprecation-note rule). The draft leads with a `Change type:` line above a type-aware Summary (breaking → benefit-led + action plan; bug fix → past-tense, no hedging, no internal terms; new-tech → benefit-led editorial shaping); the label never appears inside the Summary body, and no title or Summary prose names the release version.
- **Deprecation notes.** When a change deprecates something, the Summary carries a deprecation note — end-of-life date (**required**) + end-of-support date (optional). Dates are never invented: a missing required date becomes a `deprecation_eol` gap the `release-notes:` skill asks about, with a `<!-- TODO: end-of-life date -->` placeholder in the draft.
- **Change Type sourcing ladder + VI capture.** `change_type` is sourced, not just inferred — `change_type_hint` → imported VI frontmatter → authored specs-draft VI → infer (first non-null wins; the imported value wins a divergence, recorded non-blocking). `jira-reader` now surfaces `change_type` and `release_notes_category` verbatim from the VI frontmatter into `value_increment` (additive, null when absent); `release_notes_category` is surfaced only, never inferred, and never the `{{#context}}` label.

### Changed

- `release-notes:` Phase report now shows the resolved Change type + Deprecation; the skill resolves a low-confidence `change_type` gap and a `deprecation_eol` gap with the user before writing the draft.

## [2.3.0] — 2026-07-17

### Added

- **New `update-vi:` skill (PM VI refresh).** Refreshes an existing Value Increment — routine refresh or an obstacle-driven re-do. Resolves the VI **Jira-import-first** (a new `_shared/vi-source-resolution.md`: the re-imported `$VAULT_PATH/jira-products/<KEY>` is the source of truth, 3-day freshness gate; the `$SPECS_PATH` draft is secondary), grounds on VI + comments + any ARD/spec/`@transcript`, updates via the grill against `_shared/vi-format.md`, gated by the Opus `vi-reviewer`, and writes **canonical + archived** revisions (`<KEY>_<slug>.md` latest; prior snapshot under `revisions/`). Product-level (no code scan).
- **`create-vi: --from-vi <VI-KEY|path>` seeding.** Author a new VI seeded read-only from a sibling VI (the techFit family pattern), recorded in a new `seeded_from_vi` frontmatter field; resolved Jira-import-first. A bare `create-vi: <existing-VI>` now redirects to `update-vi:`.
- **`vi-reviewer` non-contradiction dimension + `vi-format` internal-consistency rule + `create-vi:` grill self-consistency nudge** — flags a VI that contradicts itself (AC vs Out-of-scope, Goal vs Scope, conflicting US) at product altitude.

### Changed

- **VI filename standardized to `<KEY>_<slug>.md`** (frontmatter-based detection: `issue_type: ValueIncrement`), replacing the documented `<KEY>_ValueIncrement.md` across `create-vi:`, `create-ard:`, `vi-reviewer`, `vi-format`, `pre-lint`, and `ard-format`.

## [2.2.0] — 2026-07-15

### Added
- **`document:` (Jira mode): counterpart-space grounding.** A space-constrained run (`saas`|`managed`) now discovers the OTHER space's existing documentation for the same feature and hands it to the writer as **read-only grounding** — concepts, terminology, and structure to consult, never text to copy and never screenshots to reuse. New `counterpart-finder` agent (in-tree keyword search + `git log --grep`, plus an optional `--counterpart <JiraID|PR-url>` for an unmerged counterpart PR, resolved via the existing diff-summarizer strategies — zero new external API). New Phase 5.6.5; `counterpart_references[]` threads into `doc-planner` (grounding + a "target may already be covered" write-strategy signal) and `doc-writer`; `doc-reviewer` gains a cross-space leak/screenshot-provenance check.

## [2.1.2] — 2026-07-15

### Changed
- **README `specify:` VI-level scope note (docs-only).** The "Workflow overview" role table's `specify: <VI> [<Epic>]` signature already implies the Epic is optional, but the diagram/table collapse that variant into the same PE node, which read as if only `<VI> <Epic>` were real. Added a note under the role table clarifying: `specify: <VI>` is valid and stays in the PE lane; on a VI with ≥2 Epics, Phase 2's picker offers picking one Epic, an explicit "Author one broad VI-level spec instead," or the tool's own recommendation to split into Epics via `epics:` first; on a single-Epic VI it auto-resolves to that Epic; and a broad VI-level spec writes to `spec/<VI>-<vslug>` with its `### Next step` pointing to `epics: <VI>` rather than `design: <VI> <Epic>`.

## [2.1.1] — 2026-07-15

### Changed
- **README overhaul, brought up to the Claude Code edition's documentation depth (docs-only).** Added a `## Workflow overview` section (mermaid PM/PA/PE/Dev/QA role-graph of the `idea:` → `create-vi:` → `create-ard:` → `epics:`/`specify:` → `design:` → `implement:` → `document:` → `release-notes:` pipeline, an annotation table, a "Sources of truth & artifact homes" note, and a "Cross-cutting skills" subsection) and an `implement: workflow` phase-flow mermaid diagram, both adapted to this edition's keyword-trigger skill names, strong-tier (Opus/GPT-5.5) model set, and `task()` dispatch — with no cost/statusline nodes, since those are not ported. Expanded the grouped sub-agent name list into a full 30-row `| Agent | Model | Description |` table, correcting the model column to reflect this edition's reality: sub-agents have no `model:` frontmatter pin — the strong tier is passed by the caller at each `task()` call site. Added a `## Reference docs` catalog of the 38 `skills/_shared/*.md` files, an `## Architecture (ARD) consumption` section, a `## Dependencies & companions` section, a trimmed `## Session feedback` section (no session-cost), and expanded `## Hooks` into a table (4 hooks, including the previously-undocumented `test-notify`).
- Root `README.md` — added a `## Prerequisites` section, an environment-variable configuration step (`VAULT_PATH` / `SPECS_PATH` / `REPOS_PATH`, confirmed load-bearing across `skills/_shared/*.md` but previously undocumented at the marketplace level), and a `## Runtime directories` section, mirroring the sibling `ihudak-claude-plugins` marketplace's root README.

### Fixed
- **Root `README.md` Plugins table described the retired `/impl` / `/fix-vuln` taxonomy (docs-only).** The `dev-workflows` row still read "`/impl` for feature implementation, `/fix-vuln` for CVE remediation, `/upgrade` for dependency upgrades" — the pre-1.4.0 command surface, not the current 19-skill lifecycle. Replaced with an accurate summary; also refreshed the stale `skills/impl/`, `fix-vuln/` example paths in the "Repository structure" tree.

## [2.1.0] — 2026-07-14

### Changed
- **`release-notes-writer` — editorial shaping (enhancement).** The writer no
  longer defaults to a flat "2–4 sentence paragraph" for every entry. Process
  step 3 now instructs conditional shaping grounded in shipped dynatrace-docs
  feature-updates: prose stays the default, but when a feature **enumerates
  discrete options** (e.g. a new dropdown with N selectable values) the writer
  uses a short intro sentence + a **bulleted list** (bold each option); it leads
  with the recommended/new default path and **demotes deprecated or manual-only
  options** to a trailing sentence or an optional `> Note:` line rather than
  presenting them as equal peers; and it uses **bold** for UI/field names and
  inline `code` for filenames, identifiers, and flags. The
  `release-notes-writer` handoff schema's `prose` field description was relaxed
  to match (no longer contradicts the agent by mandating a single paragraph).
  Motivation: a real release note enumerating four container-registry options
  read better as a list with the deprecated option footnoted than as a
  comma-chained paragraph.

## [2.0.1] — 2026-07-14

Port of the upstream Claude Code `dev-workflows` **v2.31.0 audit-fix batch** into
the Copilot edition. The Copilot port was based on Claude v2.30.0 (pre-fix) and had
inherited the same latent defects. Each finding was cross-checked against the
Copilot tree and fixed in a GitHub-Copilot-CLI-compatible way. No behavioural
triggers changed.

### Fixed
- **`test-baseliner` dual-schema (BLOCKER)** — the agent now emits a top-level
  `**Status**:` field in both the capture (`## Test Baseline`) and verify
  (`## Test Verify Report`) blocks, so `vuln-fixer` / `upgrade-executor`
  status-branching is no longer dead.
- **Sub-agent `ask_user` misuse** — `vuln-fixer` and `upgrade-executor` no longer
  claim to prompt the user directly (a sub-agent can't in Copilot CLI). On a test
  regression they now return `status: TEST_REGRESSION` + diagnosis; the orchestrator
  asks the user and re-invokes with `phase: regression-resume` + `regression_decision`
  (mirrors the existing verify-resume handshake). Added the missing "Handling Test
  Failures" section to `upgrade:`.
- **`implement:`** — removed stale `general-purpose` + `model: opus` override prose
  that contradicted the actual dispatch; renamed the mis-labelled "Pre-Phase 2" to
  "Phase 1.6" (it sits between 1.5 and 1.7).
- **`document:`** — renumbered Phase 0 steps (were skipping step 2) and fixed all
  cross-references; repointed dead "Increment 2/3" pointers to concrete phases
  (4.5 / 5.7 / 5.9).
- **`epics:`** — swapped the inverted Phase 6.1 (clarifications) / 6.2 (style-check)
  labels and fixed a residual stale cross-reference.
- **`upgrade-planner`** — corrected a false "pinned to Opus" claim (it runs on the
  detection chain).
- **`doc-writer`** — changelog rule now correctly says "no Jira key"; added `bash`
  to `tools:` so it can copy local screenshots.
- **`doc-fixer`** — finding field aligned to the message-based schema (`message`).
- **`create-ard`** — VI-level `jira-reader` fallback is now a formal `task()` block
  with `depth`; annotated in the model-routing comment.
- **`idea`** — carry-forward now includes `source_refs` / `provenance`.
- **`readiness-reviewer` + `workflow-states`** — `CONCERN` vocabulary unified to `MINOR`.
- **`api-guideline-reviewer`** — removed a self-contradictory "never use a subset"
  instruction.
- **`guideline-reviewer`** — gated the dt-app MCP lookup section on MCP availability
  (the agent's `tools:` grant no MCP).
- **Handoff schema drift** — `jira-reader` (`branch_from`/`branch_to`),
  `impl-maintenance` (Command enum extended to 12: `idea:`, `create-vi:`,
  `create-ard:`, `ready:`), `release-notes-writer` (`code_repos` input +
  `jira_phrasing`/`source_phrasing`/`source_location` gap fields), and the
  `code-scanner` / `diff-summarizer` inline `## Output` sections (now match their
  handoff SSOTs — `prep:` block, per-PR fields).
- **Citations** — normalised bare path references to the full
  `~/.copilot/installed-plugins/…` prefix (`pre-lint.md`,
  `release-notes-writer` handoff) and broadened the `jira-reader` `NOT_FOUND`
  description to cover both resolution forms.

### Skipped (not applicable to Copilot)
- Cost / statusline features (intentionally absent from the Copilot edition).
- The "Skill in allowed-tools" finding — Copilot reads `model-routing.md` via `view`,
  not a Skill-tool invocation.



Major re-sync with the upstream Claude Code `dev-workflows` plugin (v2.30.0),
which had evolved into a full product-development lifecycle while this Copilot
edition fell behind. **Breaking**: triggers flattened and renamed.

### Added
- **Product-development lifecycle skills** ported from Claude Code: `idea:`,
  `create-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `release-notes:`,
  `ready:`, `docs-profile:`, `feedback:`, `prompt:`, `prompt-brainstorm:`,
  `prompt-grill-me:`.
- **11 new sub-agents**: `idea-reader`, `vi-reviewer`, `ard-reviewer`,
  `spec-reviewer`, `design-reviewer`, `readiness-reviewer`, `doc-writer`,
  `epic-writer`, `release-notes-writer`, plus the extracted `api-guideline-reviewer`
  and `guideline-reviewer` review agents (the reviewer skills are now thin
  dispatchers). Total sub-agents: 30.
- **`dynatrace-docs/` reference bundle** and 10 handoff schemas consolidated under
  `skills/_shared/handoff/`.
- **GPT-5.5 added to the strong model tier** as a peer of Opus 4.8/4.7/4.6
  (GPT models were unavailable in Claude Code, so the upstream used Opus only).

### Changed — BREAKING
- **Triggers flattened and renamed**:
  - `impl:code:` / `impl:` → **`implement:`**
  - `impl:docs:` and `impl:jira:docs:` → **`document:`** (dual-mode)
  - `impl:jira:epics:` → **`epics:`**
  - `fix-vuln:` → **`vuln:`**
- Reviewer skills (`api-guideline-reviewer`, `guideline-reviewer`) split into thin
  dispatcher skills + dedicated review agents holding the logic.
- Target/global instruction-file references updated from `CLAUDE.md` /
  `~/.copilot/CLAUDE.md` to `.github/copilot-instructions.md` /
  `~/.copilot/copilot-instructions.md` throughout.

### Removed
- Legacy skills `impl`, `impl-dispatcher`, `impl-docs`, `impl-jira`, `fix-vuln`
  and 9 orphaned sub-agent handoff directories.
- **Session cost reporting** (`/statusline`, `emit-cost`, cost-emission refs) and
  **statusline integration** — intentionally not ported; GitHub Copilot CLI
  exposes no cost/usage API or statusline extension point.

## [1.8.2] — 2026-06-16

### Changed
- **`docs-style-checker` — Vale + `dt-style-checker` now run as a
  COMPLEMENTARY chain, not a fallback-only relationship.** Empirical
  verification on the PRODUCT-14902 docs run showed the two checkers
  catch different classes of issue:

    | Class of finding | Vale catches | `dt-style-checker` catches |
    |---|---|---|
    | Lexical (banned words, contractions, hyphens) | ✅ at scale | partial |
    | Frontmatter completeness (`navigation:`, title length) | ✅ | ❌ |
    | Engineer jargon (`latest-minus-one`, `LTS-1`) | ❌ no rule | ✅ |
    | Cross-page label consistency | ❌ | ✅ |
    | Subject-verb agreement, misplaced modifier | ❌ | ✅ |
    | Plural/singular UI-label mismatch | ❌ | ✅ |

  Running ONLY the primary linter misses the semantic / cross-page class.
  As of v1.8.2, when Vale (or another primary linter) runs successfully,
  `dt-style-checker` ALSO runs as a complementary semantic pass; both
  finding sets are merged with line-level dedupe. When the primary linter
  fails, `dt-style-checker` continues to serve as the fallback (v1.7.0
  behaviour preserved). When the `dt-style-guide` plugin isn't installed,
  the chain degrades cleanly to the primary pass only.
- **`docs-style-checker` output schema v3.** Old fields (`linter`,
  `command`) are renamed to `primary_linter` / `primary_command` and new
  fields are added: `complementary_linter`, `complementary_command`,
  `complementary_error`. Each violation record now carries a `source:`
  field (`primary` | `complementary`) for traceability. Callers that
  parsed the old schema by string-matching `linter:` need to update.
- **`impl-jira` Phase 6.7 and `impl-docs` Phase 3.4 hard-rule text
  expanded** to describe the chained behaviour. Removed a stale
  duplicate `ERROR` heading block in `impl-jira/SKILL.md` that was
  introduced during the v1.7.0 edit.

### Fixed
- **Bug discovered during PRODUCT-14902 Vale-verification round:** when
  Vale was available, `dt-style-checker` was completely skipped — even
  though it catches semantic / cross-page issues Vale doesn't have rules
  for (the v1.7.0 rationale of "fallback only" was based on the wrong
  assumption that Vale was a superset). The chain now ensures
  high-confidence semantic findings (jargon, UI-label consistency,
  subject-verb agreement) are not silently dropped when Vale exists.

## [1.8.1] — 2026-06-16

### Fixed
- **`doc-planner` — no Jira keys in `changelog:` entries.** New hard rule:
  proposed `frontmatter_updates.changelog.entry` text MUST NOT embed the
  Jira key (e.g. `(PRODUCT-14902)` suffix). The Jira reference is carried
  by the commit message and the file diff, not by the customer-visible
  page changelog. Verified against `dynatrace-docs`: fewer than 5 of
  5500+ pre-existing changelog entries cite an issue key — basically
  zero convention support. Caught during PRODUCT-14902 review where
  v1.8.0 added `(PRODUCT-14902)` to 5 changelog entries.
- **`doc-planner` — cross-product reciprocal touches stay product-scoped.**
  New hard rule: when a "minimal touch" target is on an existing page
  belonging to product X but the change is about a feature shipped by
  product Y, the writer's note must be a one-line cross-link to product
  Y's dedicated page — NOT a copy of product Y's implementation detail
  (throttling rules, enum values, precedence, etc.). Caught during
  PRODUCT-14902 review where v1.8.0 added per-pool ActiveGate
  throttling detail to the OneAgent update page (OneAgent has no
  per-pool throttling; readers don't need that depth on the OA page).

## [1.8.0] — 2026-06-16

### Changed (breaking for callers that depended on auto-corrected docs)
- **`_shared/source-truth.md` principle shift: plugin is the analyst,
  user is the decision-maker.** Replaces the v1.7.0 "Implementation >
  Description (code wins, always)" rule with a discrepancy-escalation
  protocol. When source and description disagree, the plugin presents
  the analysis to the user as a table and asks per-discrepancy whether
  to:
    - document as source suggests (match what shipped)
    - document as Jira claims (with an intentional-discrepancy marker
      + bug-report draft so the user can file a defect against the
      implementation team)
    - skip and report (omit from docs + record in bug-report draft)
  The user's PM/sprint/scope context is the deciding factor — not the
  plugin's keyword grep.
- **`doc-planner` no longer rewrites topic notes to match the source.**
  The planner now records both `jira_phrasing` and `source_phrasing`
  in `verification_warnings[]` and leaves the decision to the
  orchestrator + user (per `_shared/source-truth.md` §7). Pre-v1.8.0
  callers that expected the planner to silently correct claims will see
  the original phrasing preserved until Phase 5.8 resolves it.
- **`verification_warnings` schema v2.** Fields renamed/added:
    - `claim` (preserved)
    - `jira_phrasing` (new, verbatim)
    - `source_phrasing` (new, verbatim — "(not verifiable)" when no
      source evidence)
    - `source_location` (replaces `source_checked`)
    - `technique` (added `menu-builder`, `no-source-evidence`)
    - `finding` (added `AMBIGUOUS`; renamed semantic meaning of
      `NOT_FOUND` to specifically signal implementation-gap)
    - `number` (new, stable index for cross-reference)
    - Removed: `correction`, `recommended_action` (decisions are now
      the orchestrator's responsibility, not the planner's)

### Added
- **`impl-jira` Phase 5.8 — Discrepancy analysis & user decision.**
  New phase that runs after doc-planner (Phase 5.7) when there are
  CONTRADICTED / NOT_FOUND / AMBIGUOUS warnings. Presents an analysis
  table to the user, asks for a batch decision OR per-discrepancy
  decisions, builds a `discrepancy_decisions[]` record, and sets
  `bug_report_destination` if any decisions need a bug-report draft.
- **`impl-jira` Phase 6 — bug-report draft output.** When
  `bug_report_destination` is non-null, the writer emits a Markdown
  file at the auto-discovered vault project folder (same destination
  policy as the release-notes draft):
  `<vault-project-folder>/<JIRA_KEY>-implementation-gaps.md`. Format
  defined in `_shared/source-truth.md` §7.5.
- **`doc-reviewer` — intentional-discrepancy marker awareness.** The
  8th review dimension (Source-code accuracy) now recognises an
  `<!-- intentional-discrepancy: ... -->` HTML comment immediately
  before doc prose that describes a Jira claim the source contradicts.
  When the marker is present, the discrepancy is treated as a known
  recorded gap (NOT BLOCKER). When absent, the BLOCKER rule from
  v1.7.0 still applies.
- **`_shared/source-truth.md` §7 — Discrepancy escalation protocol.**
  Comprehensive new section covering the table format, the batch
  and per-discrepancy prompts, the `discrepancy_decisions[]` record,
  the bug-report draft destination + format, and the
  intentional-discrepancy marker format.

### Migration notes
- Local automation that invoked `doc-planner` and expected the topic
  notes to be auto-corrected to source phrasing will now see the
  original (Jira) phrasing in `topics[].notes`. Look at
  `verification_warnings[]` to find each discrepancy and apply the
  decision externally, OR pipe through the new `impl-jira` Phase 5.8.
- Local automation that parsed the old `verification_warnings`
  schema needs to read `jira_phrasing` + `source_phrasing` instead of
  `correction`, and `source_location` instead of `source_checked`.
- doc-reviewer callers (outside the orchestrator) who don't use the
  intentional-discrepancy marker will see BLOCKERs for any documented
  claim that lacks source evidence — same v1.7.0 behaviour. The
  marker only matters when the documentation is intentionally
  describing a gap.

## [1.7.1] — 2026-06-16

### Fixed
- **`doc-planner` — drop changelog-only frontmatter updates.** New hard
  rule: if a target's `topics:` is empty AND `frontmatter_updates.other:`
  is empty AND the only proposed change is a `frontmatter_updates.changelog`
  entry, drop the target from the checklist entirely. A changelog entry
  without a corresponding content change is meaningless — the changelog
  field is meant to summarise *what changed on this page*, and a "page
  unchanged" entry has no value to readers.
  Especially relevant for auto-generated schema-table pages
  (`{{settings-api-table-standalone}}` body) where the schema JSON's own
  `"version":` field tracks field additions; the doc page just re-renders
  it. Convention is verifiable by sampling siblings: when 90%+ of pages
  in the same directory lack a `changelog:`, the planner must respect
  that convention. Caught during PRODUCT-14902 review where v1.6.0
  added a changelog to `builtin-deployment-activegate-updates.md` whose
  body was unchanged (only 1 of 439 sibling schema pages had a changelog
  precedent).

## [1.7.0] — 2026-06-16

### Added
- **`_shared/source-truth.md`** — new shared policy: **Implementation >
  Description**. The source code is what customers see; Jira tickets,
  design specs, and prose descriptions are the *starting point*, not the
  *spec*. Every user-visible claim in generated documentation MUST be
  verified against the implementation (enums, schema JSON, data-source
  classes, UI label constants, defaults, validators) before publication.
  Born from PRODUCT-14902 where the Jira "User Story" listed 3 target-
  version options but the actual source enumerated 4 (Latest / Previous /
  **Older** / specific).
- **`doc-planner` source-verification step (8.5)** — new mandatory pass.
  Accepts `code_repos: [{slug, path}]` input from the orchestrator and
  verifies every user-visible claim (option lists, labels, defaults,
  counts, mode names) against the actual source using the techniques in
  `_shared/source-truth.md` §3. Emits `verification_warnings[]` for any
  claim that cannot be verified OR is contradicted by the source. The
  planner's topic notes MUST reflect the verified phrasing, not the
  description's.
- **`doc-reviewer` 8th review dimension — Source-code accuracy.** Accepts
  the same `code_repos` input. Spot-checks 3–5 user-visible claims per
  file against source. **A documented option/label/count that does NOT
  appear in source is BLOCKER, not CONCERN** — customer-facing wrongness
  blocks publication.
- **`impl-docs` Phase 3.4 — mandatory style check.** Previously, impl-docs
  had no style-check phase; now it invokes `docs-style-checker` before
  Phase 3.5 (doc-reviewer), with the same fix cycle as impl-jira Phase 6.7.

### Changed (breaking for orchestrators that previously skipped style on tool absence)
- **`docs-style-checker` ERROR → fallback path.** Previously, when the
  primary linter (Vale / project lint / markdownlint) errored at runtime
  (missing binary, non-zero exit), the agent returned `status: ERROR`
  without trying the `dt-style-checker` fallback. Now the agent ALWAYS
  tries the fallback before returning ERROR. `NOT_CONFIGURED` is reached
  ONLY when no primary linter is configured AND the `dt-style-guide`
  plugin is not installed. **Some check is better than no check.**
- **`impl-jira` Phase 6.7 is now MANDATORY.** New hard rule at the top of
  Phase 6.7: the orchestrator MUST dispatch `docs-style-checker` and act
  on its return — never skip on its own judgement of which linters are
  installed. The "Proceed to review without style check" choice was
  removed from the ERROR escalation (replaced with "Proceed to
  doc-reviewer" since doc-reviewer still runs).
- **`impl-jira` Phase 5.7 doc-planner input** — `code_repos:` field added
  (array of `{slug, path}`). Required for source-truth verification. When
  omitted, doc-planner emits a `verification_warnings[]` entry per
  user-visible claim.
- **`impl-jira` Phase 7 doc-reviewer input** — `code_repos:` field added
  for the new 8th review dimension.
- **`risk-planner` hard rules** — explicitly forbid recommending "skip
  the style check" as a valid disposition (closes the loophole that let
  v1.6.0 PRODUCT-14902 ship with no style check). Explicitly forbid
  recommending "trust the Jira description" over source code.

### Fixed
- **Vale-missing → silent skip regression.** Pre-v1.7.0, if the agent
  container lacked the Vale binary (common in ephemeral / sandboxed
  setups), the orchestrator silently skipped Phase 6.7 entirely.
  Customer-visible style violations (engineer jargon, inconsistent UI
  labels, contradicting menu paths, plural/singular label mismatches)
  shipped uncaught. v1.7.0's `docs-style-checker` ERROR-fallback path
  closes this — the `dt-style-checker` LLM-based agent always runs as a
  second-chance check when Vale is unavailable.

### Migration notes
- Local automation that invokes `doc-planner` or `doc-reviewer` directly
  (outside the orchestrator) should add `code_repos: [{slug, path}, ...]`
  to the input block. Omitting it is non-breaking but causes
  `verification_warnings` (planner) or "not verifiable" CONCERN entries
  (reviewer) on every user-visible claim — the agents refuse to silently
  emit unverified content.
- `docs-style-checker` callers who depended on the old "ERROR on missing
  Vale binary" behaviour will now see `VIOLATIONS_FOUND` / `OK` /
  `NOT_CONFIGURED` instead (with a note in the `error:` field explaining
  that the fallback ran). Update conditional logic accordingly.

## [1.6.0] — 2026-06-16

### Added
- **`_shared/branch-naming.md`** — new shared policy: every orchestrator that
  creates a git branch (`impl:`, `impl:docs:`, `impl:jira:`, `fix-vuln:`,
  `upgrade:`) now resolves the branch *prefix* via a 4-step algorithm:
  1. `$GIT_USER_INITIALS` env var
  2. `git config --get user.initials`
  3. Sniff `git branch -a` for the dominant `<2–8-char-prefix>/<rest>` pattern
     (≥ 30 % share AND ≥ 3 occurrences)
  4. Workflow-specific fallback (`feat/`, `docs/`, `fix/`, `chore/`), with a
     mandatory `ask_user` escalation when reached
- **`impl:jira:` Phase 1 Q6** — auto-discovered `<vault>/Projects/Products/**/<JIRA_KEY>*/`
  is now used for BOTH the release-notes destination AND the screenshot
  staging directory. The Q6 prompt was reworded to make this explicit.
- **`doc-planner` `screenshot_staging_dir` input field** — orchestrators now
  pass an explicit persistent directory for screenshot staging. doc-planner
  validates it and emits a gap if missing while `image_policy` is
  `cdn_upload_required`.

### Changed (breaking for orchestrators that depend on hard-coded prefixes)
- **`impl:code:` Phase 2.5** — branch-prefix detection now references
  `_shared/branch-naming.md` instead of the previous "check `git branch -a`,
  default to `feat/`" rule.
- **`impl:docs:` Phase 2.5** — same.
- **`impl:jira:` Phase 5.5** — same. Also rewritten to use explicit
  `git -C <docs_repo_root>` form everywhere (clean-tree check, branch sniff,
  checkout). The previous `git checkout -b docs/...` from cwd silently
  created the branch in whichever git repo cwd happened to be — typically
  the wrong repo when the docs repo is a sibling of cwd.
- **`upgrade:`** — branch-prefix detection now references
  `_shared/branch-naming.md` (was: "default to `chore/`"). Combined prefix
  example shifts from `chore/upgrade-springboot-to-3.3.11` (always) to
  `<resolved-prefix>/upgrade-springboot-to-3.3.11` (e.g.
  `ivgu/upgrade-springboot-to-3.3.11` when `GIT_USER_INITIALS=ivgu`).
- **`fix-vuln:`** — same; fallback prefix `fix/` preserved when detection misses.
- **`impl:jira:` repo_root references** — five spots in `impl-jira/SKILL.md`
  that previously said `<cwd's git root>` (Phase 5.6 doc-location-finder,
  Phase 5.7 doc-planner, Phase 6.7 docs-style-checker, Phase 7 doc-fixer ×2)
  now say `<absolute path to the docs repo root — NOT cwd's git root>`. The
  orchestrator's cwd may be a different repo (marketplace, code repo,
  obsidian vault, etc.); the docs target must be passed explicitly.

### Fixed
- **`doc-planner` screenshot staging path** — previously hard-coded to
  `/tmp/<JIRA_KEY>-screenshots/`; this path is wiped on container restart and
  loses staged screenshots before they can be CDN-uploaded. New default is
  the orchestrator-provided `screenshot_staging_dir` (typically the Obsidian
  vault project folder). The agent now refuses to use `/tmp/` even if the
  orchestrator omits the input — it falls back to a persistent sibling of
  the docs repo and flags a gap.
- **`impl:jira:` Phase 5.5 cwd assumption** — the previous spec issued
  `git checkout -b docs/<slug>` without `-C`, which created the branch in
  the cwd's git repo (often the marketplace repo when the agent is run from
  the plugin source tree). Now explicitly `git -C <docs_repo_root> checkout -b ...`.

### Migration notes
- Users with team-specific branch prefix conventions (e.g. `<initials>/`)
  should set `GIT_USER_INITIALS=<initials>` in their shell rc, or run
  `git config --global user.initials <initials>` once. The plugin's behaviour
  for users who do NOT set either is **unchanged** — the workflow-specific
  fallback (`feat/`, `docs/`, `fix/`, `chore/`) is still used.
- Local automation that invokes `doc-planner` directly (outside the
  orchestrator) should add a `screenshot_staging_dir` field to the input
  block if any `image_policy: cdn_upload_required` page is in scope.
  Otherwise the planner emits a gap (no behaviour break — the gap is for the
  caller to resolve).

## [1.5.0] — 2026-06-15

### Added
- **`impl:jira:docs:` — release-notes draft output.** When the VI's frontmatter
  has `relevant_for_release_notes: "Yes"` or a non-empty `release_versions`
  string, the workflow now generates a release-notes draft alongside the
  feature documentation page. The draft is written to a configurable
  destination (auto-discovered Obsidian project folder by default, custom
  path, stdout, or skip — chosen via Phase 1 Q6) — **never** into the
  dynatrace-docs repo, because that path is owned by Jira-driven automation.
  The draft is rendered in the dynatrace-docs `{{#context}}` /
  `{{#internal-note}}` block format so the user can paste it into Jira and
  the existing automation re-emits it into the docs repo.
- **`doc-planner` — `release_notes_block` output field.** New top-level
  output that captures one entry per declared release version with the
  rendered template, citation source list, and assignee/reporter/PE/status
  populated from `value_increment.frontmatter`. `target_format:
  dynatrace-docs-release-notes-v1` lets consumers detect the schema.
- **`jira-reader` — full frontmatter exposure.** `value_increment` and every
  `linked_items[]` entry now carry a `frontmatter:` sub-object containing
  the file's full raw frontmatter. Always-surfaced fields:
  `assignee`, `reporter`, `execution_assignee`, `team`, `project`,
  `fix_versions`, `release_versions`, `relevant_for_release_notes`,
  `owning_program`, `labels`, `resolution`. Any additional fields the file
  declares are passed through verbatim. Existing schema fields unchanged
  (additive only).
- **`jira-reader` — branch-hint extraction.** Scans the `Pull Requests`
  section of each Jira-export file for sub-bullets like
  `- Branch: \`feature/MGD-1127-...\` → \`master\``. When present, exposes
  `branch_hint` and `target_branch_hint` on the matching
  `pull_requests[]` entry.
- **`diff-summarizer` — Strategy 0 branch-hint resolution.** When
  `branch_hint` is present on a PR ref, attempts
  `git rev-parse refs/heads/<hint>` (and `origin/<hint>`) before falling
  through to existing Strategies 1–4. Records `resolved_via: branch_hint`
  on hits.
- **`impl-docs` — Jira-ticket detection.** When `impl:docs: @<file>` loads
  a file with frontmatter `key: <JIRA_KEY>` plus `[[wikilink]]` references
  and a `## Linked Issues` / `## Pull Requests` heading, the skill offers
  to re-route to `impl:jira:docs:` instead of running the lightweight prose
  workflow.
- **`impl-jira` Phase 9 — image-upload reminder.** Final report now lists
  every screenshot staged outside the docs repo (where
  `image_policy: cdn_upload_required`), so the user knows what needs
  manual CDN upload before merging the docs PR.

### Changed (breaking for orchestrators that hardcode `/repos/`)
- **`impl-jira` repo discovery — `$REPOS_PATH`-based.** The hardcoded
  `/repos/<repo>/` path lookup in Phase 4 is replaced with a configurable
  scan rooted at `$REPOS_PATH` (default `/workspace`; colon-separated list
  supported). For each in-scope PR repo URL slug, the orchestrator scans
  candidate directories under `$REPOS_PATH`, runs
  `git remote get-url origin` (5s timeout per dir), and matches by the
  upstream URL's last path segment. When multiple local clones share an
  upstream (e.g. `cluster` + `cluster-repo`), the auto-preferred order is:
  `<slug>-repo` > `<slug>_repo` > `<slug>_fast` > alphabetically last.
  Sub-agents (`diff-summarizer`, `code-scanner`) now receive an absolute
  `repo_path` plus a `repo_url_slug` and reject mismatches via
  `git remote get-url origin` cross-check.
- **Phase 1 Q3 / Q4 wording.** Code-scan and refresh-policy questions now
  refer to `$REPOS_PATH` instead of `/repos/`.
- **Phase 5 error escalation.** `DIRTY_TREE` / `REFRESH_BLOCKED` prompts
  now report the resolved `repo_path` instead of a synthetic `/repos/...`
  string.
- **`doc-planner` topic-list semantics.** "What's new" remains a valid
  topic on a normal documentation target, but the **standalone release
  notes draft is no longer one of the targets** — it is emitted via the
  top-level `release_notes_block` field instead. New hard rule forbids
  proposing release-notes snippet paths as `target_path`.
- **`doc-location-finder` exclusions.** New hard rule: never propose a
  release-notes / what's-new snippet directory as a target (e.g.
  `_snippets/release-notes/`, `_content/whats-new/<product>/sprint-*`).
  Even high keyword-overlap matches in those paths are skipped, because
  the docs repo's release-notes pages are produced by Jira-driven
  automation and a manual write would be overwritten.

### Fixed
- **`diff-summarizer` and `code-scanner` — git fetch/pull timeouts.**
  `git fetch --all --prune` and `git pull --ff-only` are now wrapped in
  `timeout 60`; on timeout, the agent returns `REFRESH_BLOCKED` with the
  reason `"git fetch timed out after 60s"` instead of hanging the workflow.

### Migration notes
- If you have local automation that invokes `diff-summarizer` or
  `code-scanner` directly (outside the orchestrator), update the input
  block: `repo_path` is now an absolute path (any path is acceptable, not
  only `/repos/<name>`), and a new optional `repo_url_slug` enables the
  upstream cross-check.
- If you previously customised the `impl-jira` Phase 4 to point at
  `/repos/`, set `REPOS_PATH=/repos` in your environment to preserve the
  old behaviour.

## [1.4.0] — 2026-06-15

### Breaking changes
- **Sub-agents are now Copilot custom agents, not skills.** The 19 internal
  sub-agents (`risk-planner`, `code-review`, `test-baseliner`, `test-writer`,
  `review-fixer`, `impl-maintenance`, `jira-reader`, `diff-summarizer`,
  `code-scanner`, `doc-reviewer`, `doc-fixer`, `doc-location-finder`,
  `doc-planner`, `docs-style-checker`, `epic-reviewer`, `upgrade-planner`,
  `upgrade-executor`, `vuln-research`, `vuln-fixer`) moved from
  `skills/<name>/SKILL.md` to `agents/<name>.md` with proper Copilot agent
  frontmatter (`name`, `description`, `tools`).
- **`plugin.json` now declares `"agents": "./agents/"`** in addition to
  `"skills": "./skills/"`.
- **Orchestrator dispatch sites updated**: every `task(agent_type: "<bare-name>")`
  call is now `task(agent_type: "dev-workflows:<name>")`. Bare names matched
  neither a Copilot built-in nor a registered custom agent, so 7 of the 9
  distinct dispatches were silently misrouting before this release.
- **Sub-agent `references/` subdirectories preserved** at their original
  locations (`skills/<sub-agent>/references/handoff.md`) — agents read them
  via absolute paths inside `~/.copilot/installed-plugins/...`.

### Added
- Model fallback chain extended with GPT-5.5 (above Sonnet) and GPT-5.4 / Gemini
  3.1 Pro (below Sonnet) — leveraging Copilot's multi-vendor model access.
  Opus 4.8 added at the top of the Claude chain (forward-compatible — currently
  resolves to whichever Opus version the CLI exposes).

### Fixed
- `impl-dispatcher` SKILL.md version string corrected from `1.2.1` → `1.3.0` →
  current `1.4.0`.

## [1.3.0] — 2026-05-15

### Changed
- **Cross-platform sync with Claude Code plugin (v1.3.0).**
  - Ported `check_guidelines.py` and `checklist-template.md` to
    `guideline-reviewer/references/` (added in Claude Code v1.2.0, missing
    from the Copilot port).
  - Version numbers now track 1:1 between Copilot CLI and Claude Code
    plugin repos. Previous version drift: Copilot 1.2.1 / Claude 1.2.0.

## [1.2.1] — 2026-05-15

### Breaking changes
- **`impl:` is now a dispatcher.** Bare `impl:` no longer runs the code-implementation
  workflow — it prints a help page with the command matrix. Use `impl:code:` explicitly.
  Aligns with Claude Code plugin behaviour since v1.1.0.

### Added
- **`impl-dispatcher` skill.** Help / dispatcher triggered by bare `impl:`. Lists all
  `impl:*` variants and related skills (`fix-vuln:`, `upgrade:`), then stops.

### Changed
- **`impl` skill trigger narrowed.** Now only activates on `impl:code:` and `implement:`.
- **Marketplace descriptions enriched.** `dev-workflows` and `dt-style-guide` descriptions
  in `.github/plugin/marketplace.json` now enumerate all skills, sub-agents, and hooks.

## [1.2.0] — 2026-05-12

Copilot CLI port of the Claude Code dev-workflows plugin (v1.1.0).

### Added
- **Namespaced skill layout.** `skills/impl/`, `skills/impl-docs/`, `skills/impl-jira/`
  become the natural-language prefixes `impl:`, `impl:docs:`, `impl:jira:docs:`,
  `impl:jira:epics:` via Copilot CLI's skill discovery.
- **`impl:code:` full workflow.** Structured code-implementation skill: classify →
  optional Opus planning → feature branch → test baseline → implement → test-writing →
  optional Opus review → maintenance → report.
- **`impl:docs:` full workflow.** One-shot doc-editing skill: classify → plan →
  implement → doc-reviewer gate → maintenance → report.
- **`impl:jira:docs:` and `impl:jira:epics:` workflows.** Jira-driven documentation
  and Epic-writing skills with parallel sub-agent invocation, style checking, and
  Opus review gates.
- **15 sub-agent skills.** test-baseliner, test-writer, risk-planner, code-review,
  review-fixer, impl-maintenance, jira-reader, diff-summarizer, code-scanner,
  doc-location-finder, doc-planner, docs-style-checker, doc-reviewer, doc-fixer,
  epic-reviewer.
- **`fix-vuln:` workflow.** Security vulnerability remediation with NVD lookup,
  minimal-version fix strategy, baseline tests, and per-CVE branches/PRs.
- **`upgrade:` workflow.** Component upgrade with before/after test verification.
- **Hooks.** `preload-context.sh` injects git context on skill activation;
  `post-tool-use.sh` tracks tool usage.
- **Shared references.** `_shared/model-routing.md` defines task classification,
  model routing, and the mandatory Opus code-review checklist.

### Changed (vs Claude Code v1.1.0)
- Skills use SKILL.md with YAML frontmatter (not `commands/*.md` / `agents/*.md`).
- Orchestrator skills declare `allowed-tools:` in frontmatter; sub-agent skills do not.
- Path references use `~/.copilot/installed-plugins/...` instead of `${CLAUDE_PLUGIN_ROOT}`.
- Hooks use `${PLUGIN_ROOT}` instead of `${CLAUDE_PLUGIN_ROOT}`.
