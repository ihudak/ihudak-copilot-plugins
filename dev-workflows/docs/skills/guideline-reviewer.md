# guideline-reviewer:

Reviews Dynatrace app code and UI against the bundled Dynatrace Experience Standards (GUIDElines) — AppHeader, DataTable, FilterField, Connections, Permissions, Settings, Dashboards, accessibility/WCAG, terminology, and Grail naming.

## Who runs it

`guideline-reviewer:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists "the reviewer commands" alongside `vuln:`, `upgrade:`, `feedback:`, the `prompt:` family, and `docs-profile:` as skills that carry no next-phase offer. It is a standalone review tool, tied to no VI, Epic, or other pipeline artifact — run it against any app code or UI, any time.

## Synopsis

    guideline-reviewer: <files-or-components> [<files-or-components> ...]

The argument — everything after the `guideline-reviewer:` trigger — is the file or component set to review. Empty, and the skill asks which files or components to review rather than guessing.

## What it needs

- **The files or components to review** — the argument itself, or supplied when asked.
- **The relevant bundled guideline(s)**, loaded from [`skills/_shared/guidelines/`](../../skills/_shared/guidelines/) — only the ones needed for the components actually found (never the whole set), per the agent's own quick-reference table: `appheader.md` for navigation/tabs/help menu, `datatable.md` for rows/columns/sorting/selection, `filterfield.md` for filtering/query syntax, `connections.md` for OAuth/API-key setup, `permissions.md` for access-denied flows, `settings.md` for schema/preferences, `dashboards.md` for tiles, `alerting-terminology.md` for "alert" vs "notification", `grail-naming.md` for table/view naming, and `accessibility.md` for WCAG/keyboard/screen-reader compliance.
- **`check_guidelines.py`** ([`skills/_shared/guidelines/check_guidelines.py`](../../skills/_shared/guidelines/check_guidelines.py)) — run automatically before the manual review pass, optionally scoped to one guideline (`--guideline appheader`).

## What it produces

A structured review at the requested depth — a **Quick Review** (pass/fail per guideline plus critical issues only), a **Detailed Review** (full component inventory, per-guideline compliance status, line-referenced violations, and remediation suggestions), or, on request, a **Design Team Report**: a shareable `GUIDEline-review-XX.md` file in the project root with an executive summary, detailed checklists, code snippets, priority action items, and sign-off sections. Findings carry one of three severities — **Critical** (violates a mandatory rule, blocks compliance), **Warning** (deviates from a recommendation), or **Info** (a suggestion). This skill makes no file edits on its own; the Design Team Report is the only file it writes, and only when the user asks for it.

## Gates

There is no reviewer of the reviewer, and no fix cycle — the review verdict itself is the deliverable. The workflow is five steps inside the dispatched agent: identify which components are in play, load only the relevant guideline(s), check compliance (DO rules must be implemented, DON'T rules must be avoided, scenarios matched to the correct case), report findings by severity, and — for a formal review — generate a checklist from [`skills/_shared/guidelines/checklist-template.md`](../../skills/_shared/guidelines/checklist-template.md). An optional `dt-app` MCP server, if the calling environment has separately configured and granted one, supplements implementation-detail lookups beyond the reference files — but the reference files remain authoritative regardless, and a missing MCP is skipped silently, never reported as a gap. The dispatched `guideline-reviewer` agent carries no `model:` pin in its own frontmatter, and unlike this pipeline's Opus/strong-reasoning reviewers, the `task()` call in `guideline-reviewer/SKILL.md` sets no `model:` override either — the review runs on whatever model the calling session is already using.

## Example

    guideline-reviewer: src/components/SettingsPage.tsx src/components/AppNav.tsx

The skill dispatches the `guideline-reviewer` agent against both files, identifies `AppHeader` and `Settings` as the components in play, loads only `appheader.md` and `settings.md`, runs the automated checker, checks DO/DON'T compliance for each, and returns a Detailed Review — for example, flagging a missing mandatory help-menu entry in `AppNav.tsx` as Critical and an inconsistent icon order as a Warning.

## See also

- [`api-guideline-reviewer:`](api-guideline-reviewer.md) — the sibling standalone review skill, for OpenAPI specs rather than app code and UI.
- [`skills/_shared/guidelines/`](../../skills/_shared/guidelines/) — the full vendored Dynatrace Experience Standards set this skill's agent loads from, plus the automated checker script and the checklist template.
