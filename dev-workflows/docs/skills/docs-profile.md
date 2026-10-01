# docs-profile:

Scans a documentation repository and writes or refreshes the machine-readable `.dev-workflows/docs-profile.yml` (plus complementary `.github/copilot-instructions.md` guidance) that [`document:`](document.md) (Jira mode) consumes, delivered as a reviewable PR — branch, commit, and a drafted PR message, never pushed or auto-merged.

## Who runs it

`docs-profile:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `docs-profile:` alongside `vuln:`, `upgrade:`, `feedback:`, the `prompt:` family, and the two guideline reviewers as skills that carry no next-phase offer. It bootstraps or refreshes an input [`document:`](document.md)'s Jira mode reads at Phase 0, so it is closer to that skill's own maintenance tooling than to any PM/PA/PE/Dev artifact.

## Synopsis

    docs-profile: [<repo-path>] [--inline] [--enforce-model=<model>]

[Run flags](../reference/run-flags.md): only `--enforce-model` applies — this skill dispatches no `impl-maintenance`, so `--skip-feedback` is reported ignored. It has an environment default (`$WORKFLOWS_ENFORCE_MODEL`) that an explicit flag overrides. `--skip-costs` is a Claude-edition flag only — this edition has no cost subsystem, so it is not parsed here at all.

The argument's first token is the target repo path; empty defaults to the current working directory. A `--inline` token, in any position, switches the run to **inline mode** — this is how `document:` (Jira mode) invokes this skill from its own Phase 0 case (c), skipping the standalone branch-name prompt, PR draft, and final report so control returns cleanly to the caller, to which it hands back the branch it cut and the commit it made. Where a bootstrap branch is already there, left by an earlier inline run that stopped after profiling, an inline run stops with `DOCS_PROFILE_BOOTSTRAP_BRANCH_EXISTS` before scanning anything, naming the branch, its base and where it forked, rather than switch onto it; delete or merge that branch, then re-run. Phase 0 then validates the resolved path is a writeable git work tree (`NOT_A_GIT_WORKTREE` / `REPO_NOT_WRITEABLE` stop otherwise) and checks for at least one docs-repo signal (`package.json` doc scripts, `.docstack/`, `.vale.ini`, a `*/_content/` directory, or a `_snippets/` directory) — zero signals asks before continuing rather than refusing outright.

## What it needs

- **A writeable git work tree** at the resolved repo path — validated at Phase 0 before anything else runs.
- **Model routing** (Phase 1) — profiling is classified **SIGNIFICANT** (its output steers every later `document:` run), recorded in a `model_routing` block that pins Phase 2's detection pass to the detection chain and Phase 3's synthesis pass to the strong-reasoning chain, both via the `task` tool's `model:` override at the call site. Neither dispatch names a `dev-workflows:<agent>` — both spawn a generic `agent_type: "general-purpose"` (a Copilot CLI built-in agent type, not one of the plugin's own 35) with the model pinned at dispatch, so this skill has zero direct `dev-workflows:` agent dispatches and carries no `## How it runs` diagram.
- **Confirmation for every field the synthesis marked `needs-confirmation`** (Phase 4) — exact build/start commands, prerequisites, ambiguous space mappings, branch-naming convention — each via a `choices` array with a recommended default, never guessed.
- **An idempotent-refresh check** — before writing, Phase 4 checks whether `.dev-workflows/docs-profile.yml` already exists; if so it shows a field-level diff and confirms before overwriting rather than silently replacing it. A refresh proposes a change only where this run's detection found evidence for one and carries everything else forward, never deleting what its scan cannot see; answering "Keep existing, write nothing" writes nothing at all — no branch, no commit. The profile is read and written at the work tree's top level — its one home, where every path it records is rooted and every command it records runs — even where the given path is a site below it.

## What it produces

`.dev-workflows/docs-profile.yml` in the **target repo** (never the plugin), conforming to [`skills/_shared/dynatrace-docs/docs-profile-schema.md`](../../skills/_shared/dynatrace-docs/docs-profile-schema.md) — `spaces[]`, `dev_servers`, `commands` (plus a per-space `commands.per_space` when the repo exposes per-space scripts), `cross_space_override` + `shared_registries` only for a detected multi-space/docstack repo, detected `tokens`, `internal_links`/`branch_naming`/`images`/`prerequisites`, and an `announcement_pages[]` list (explicitly `[]` when none are found, never omitted). `frontmatter:` is **pointers only** to the `dynatrace-docs-frontmatter` skill — changelog and owners rules are never copied into the profile. Complementary `.github/copilot-instructions.md` additions are written alongside it, scoped to conventions the frontmatter skill doesn't already cover. Both land on a new branch with one commit; standalone mode drafts a copy-paste-ready PR title and body for whichever host the target repo's remote indicates. **Never pushed, never auto-merged** — the user pushes and opens the PR themselves.

## Gates

No reviewer agent — the Phase 4 confirmation loop **is** the gate: every field the Phase 3 synthesis could not ground in the Phase 2 detection report is asked about explicitly, using `choices` arrays with a recommended default first and `"Other… (describe)"` last. Format/lint runs automatically on the written files when the target repo has one configured (skipped silently otherwise). Inline mode skips the standalone report and PR-draft prompt, returning the confirmed profile to `document:` (Jira mode), which owns the single consolidated PR draft for the whole run.

## Example

    docs-profile: /workspace/dynatrace-docs

The run validates the repo, detects it as a multi-space/docstack repo (via `dev_servers`, `docstack.jsonc`, and multiple `*/_content` roots), synthesises a draft profile on the strong-reasoning chain, confirms a handful of `needs-confirmation` fields (branch-naming convention, a prerequisite `.docstack` shim), writes `.dev-workflows/docs-profile.yml` plus `.github/copilot-instructions.md` additions on a new branch, and prints the branch name and a drafted PR title/body for the user to push and open themselves.

## See also

- [`document:`](document.md) — the Jira-mode skill whose Phase 0 preflight-discovers this profile, bootstrapping it on demand via this skill when absent.
- [`dynatrace-docs-frontmatter:`](dynatrace-docs-frontmatter.md) — owns changelog-entry and managed-docs-owners conventions this skill's `frontmatter:` pointers defer to, never re-specifying them.
- [`model-routing.md`](../../skills/_shared/model-routing.md) — the detection-chain / strong-reasoning-chain split Phase 1 records and Phases 2–3 apply via `task(model:)`.
