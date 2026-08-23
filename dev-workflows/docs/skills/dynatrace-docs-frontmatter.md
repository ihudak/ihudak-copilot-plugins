# dynatrace-docs-frontmatter:

Applies dynatrace-docs frontmatter conventions — changelog entries, managed-docs owners, and the core metadata fields — when a `.md` page under `dynatrace/_content/**` or `managed/_content/**` in the `dynatrace-docs` repo is created or edited.

## Who runs it

`dynatrace-docs-frontmatter:` is not a pipeline step and owns no PM → PA → PE → Dev role — it is a conventions-application skill, invoked the same way as every other skill in this edition (a `name:` colon keyword) but applied *while* editing a dynatrace-docs page rather than as its own workflow stage. `docs-profile:` and `document:` both name it as the owner of changelog and owners rules; their own `frontmatter:` output is pointers only, never a copy of the rule text. A warn-only `PostToolUse` hook, `changelog-owners-reminder`, reminds about the same two checks (changelog date, managed owners) whenever this skill did not fire on an edit to a dynatrace-docs content page — running this skill at edit time keeps that hook silent.

## Synopsis

    dynatrace-docs-frontmatter:

Takes no argument. Apply it against whichever `dynatrace/_content/**` or `managed/_content/**` page you are already creating or editing in the current session.

## What it needs

- **A dynatrace-docs content page** — a `.md` file under `dynatrace/_content/**` (SaaS) or `managed/_content/**` (Managed) that you are creating or have just changed.
- **Whether the page is brand-new or a changed existing page** — a first publish uses the `published` timestamp instead of a changelog entry; only a changed existing page gets a new `changelog:` entry.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/changelog-guidelines.md` — the changelog entry rules and worked examples, read directly rather than restated here.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/managed-owners.txt` — the required owner IDs for a `managed/_content/**` page, one per line.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/frontmatter-guidelines.md` — the full field rules for `title`, `description`, `meta.content-type`, `meta.i18n-priority`, `meta.generation`, and `published`.

## What it produces

Edits to the page's own YAML frontmatter, applied in one pass:

1. **Changelog** (changed existing pages only) — a new entry dated today, prepended as the first `changelog:` list item, within 200 characters, following the period rule (complete sentence → period; phrase/fragment → none).
2. **Owners** (changed `managed/_content/**` pages only) — every required ID from `managed-owners.txt` present in the `owners:` block, added if missing, never removed if already there (union only).
3. **Metadata fields** (all pages) — `title`, `description` (120–160 characters), `meta.content-type` (mandatory on new pages, never `overview`), and the optional fields the neighbourhood already uses, sampled from 2–3 adjacent pages rather than invented.

It never creates a new page on its own and never strips an unknown or pre-existing frontmatter field.

## Gates

None of its own — no reviewer, no branch, no specs-repo commit. It edits the page in place, in whichever repo and branch you are already working in. It does not duplicate the dynatrace-docs repo's own CI (`pnpm dynatrace:lint`); it gets the frontmatter right at edit time so the PR is not bounced later by that lint.

## Example

    dynatrace-docs-frontmatter:

Run after editing `dynatrace/_content/observability/logs/log-management.md`: prepends today's changelog entry (if the page changed), and checks `title`/`description`/`meta.content-type` against the field rules — no owners check, since the page is under `dynatrace/_content/**`, not `managed/_content/**`.

## See also

- [`docs-profile:`](docs-profile.md) — writes `frontmatter:` as pointers only to this skill's guideline files, never copying changelog or owners rule text into the profile.
- [`document:`](document.md) — the Jira-mode skill that authors and edits dynatrace-docs pages this skill's conventions apply to.
- [Hooks](../reference/hooks.md) — `changelog-owners-reminder`, the warn-only backstop for a page this skill didn't fire on.
- [References](../reference/references.md) — the `dynatrace-docs/` reference subtree this skill's three guideline files live in.
