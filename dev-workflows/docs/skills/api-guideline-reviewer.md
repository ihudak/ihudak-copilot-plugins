# api-guideline-reviewer:

Reviews OpenAPI specification files against the bundled Dynatrace REST API and IAM permission naming guidelines — version consistency, required elements, naming conventions, IAM scope format, HTTP status codes, and schema composition.

## Who runs it

`api-guideline-reviewer:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists "the reviewer commands" alongside `vuln:`, `upgrade:`, `feedback:`, the `prompt:` family, and `docs-profile:` as skills that carry no next-phase offer. It is a standalone review tool, tied to no VI, Epic, or other pipeline artifact — run it against any OpenAPI spec, any time.

## Synopsis

    api-guideline-reviewer: <spec-file-path> [<spec-file-path> ...]

The argument — everything after the `api-guideline-reviewer:` trigger — is the OpenAPI spec file path (or paths) to review. Empty, and the skill asks which file(s) to review rather than guessing.

## What it needs

- **One or more OpenAPI spec file paths** — the argument itself, or supplied when asked.
- **The bundled guideline set**, loaded in full before reviewing — never a partial subset — from [`skills/_shared/api-guidelines/`](../../skills/_shared/api-guidelines/): the REST API guidelines (`Introduction`, `General Structure`, `OpenAPI`, `API Versioning`, `Authentication`, `Standard Methods`, `Custom Methods`, `Conventions`, `Common Datatypes`, `Common Schemas`, `Design Patterns`, `Filtering And Sorting`), the permission guidelines (`Introduction`, `General Mapping`), and the reference template (`api-guidelines/template/openapi-template.yaml`).

## What it produces

A structured review — `## Review Summary`, `## Mistakes` (MUST/MUST NOT violations, each with Issue / Guideline / Location / Current / Fix), `## Potential Improvements` (SHOULD/SHOULD NOT deviations, same format), and `## Correctly Implemented` — surfaced directly to the user. This skill makes no file edits and opens no PR; it is read-only review, not a fixer.

## Gates

There is no reviewer of the reviewer, and no fix cycle — the review verdict itself is the deliverable. Two review passes run inside the dispatched agent: **Pass 1** (comprehensive analysis across version consistency, required elements, naming conventions, IAM scope validation, HTTP status codes, and schema composition) and **Pass 2** (detailed verification of edge cases — exact field/header spelling, universal security specifications, no `snake_case` field names, version-number consistency across all three locations). A MUST violation classifies as a Mistake; a SHOULD deviation classifies as a Potential Improvement — the two are never conflated. The dispatched `api-guideline-reviewer` agent carries no `model:` pin in its own frontmatter, and unlike this pipeline's Opus/strong-reasoning reviewers, the `task()` call in `api-guideline-reviewer/SKILL.md` sets no `model:` override either — the review runs on whatever model the calling session is already using.

## Example

    api-guideline-reviewer: openapi/settings-service-v2.yaml

The skill dispatches the `api-guideline-reviewer` agent against the named spec file, which loads every REST API and permission guideline, runs both review passes, and returns a Mistakes / Potential Improvements / Correctly Implemented report — for example, flagging a `servers.url` major-version mismatch against `info.version` as a Mistake, and a missing `operationId` on one endpoint as a second.

## See also

- [`guideline-reviewer:`](guideline-reviewer.md) — the sibling standalone review skill, for Dynatrace app code and UI compliance rather than OpenAPI specs.
- [`skills/_shared/api-guidelines/`](../../skills/_shared/api-guidelines/) — the full vendored REST API and IAM permission guideline set this skill's agent loads before reviewing.
