# Jira-input resolution (shared front-end)

Shared input-resolution mechanics for the Jira-driven commands `implement:`,
`document:`, `epics:`, `specify:`, `release-notes:`, `create-ard:`, `design:`, and
`ready:`. (`idea:` uses only the `resolve-export-for-key` sub-procedure, not the
whole front-end.) The command's Phase 0 **cites this
file and executes these steps inline** — the orchestrator owns every prompt. The
commands parse the trigger argument identically and consume the normalized output
contract (§ Output contract); each then layers its own downstream work. `epics:`,
`specify:`, `release-notes:`, `create-ard:`, `design:`, and `ready:` are **jira-driven
only**: they consume
`{mode, source, jira_key, jira_export_root}`, ignore `specs` / `direct_prompt` /
`direct_files`, and **reject** `mode: direct` (they have no non-Jira behavior —
stop with a clear error).

## Input grammar

The trigger argument (the text following the command trigger) is a whitespace-separated token list. Classify each token:

- **JiraID** — matches `^[A-Z][A-Z0-9]+-[0-9]+`.
- **Path** — a `@path` token, or a bare path that exists on disk (a directory; or,
  in direct mode, a file).
- **Command-specific trailing option** — consumed by the command *after* this
  resolution (`document:`: an optional `saas` | `managed` token). Not resolved here.
- **Free-text** — anything else (the direct-mode prompt).

## Mode decision

- **`jira-driven`** — at least one JiraID token, **or** at least one directory that
  inspects as a **jira-export** (contains `<KEY>-index.md`).
- **`direct`** — no Jira input: only free-text and/or a file token.

## Resolution

### jira-driven — JiraID token (requires `$SPECS_PATH`)

`<spec-dirs>` = every existing directory among `$SPECS_PATH/{specs|specifications|vis}/`. Every
later mention of the specs directories means exactly this — all of them are searched, because the
importer writes only under `specifications/` while `create-vi:` may have used another.

1. Resolve `$SPECS_PATH` (env). Unset, or not a directory → **Fallback A** (set the path). A
   directory holding none of `specs/`, `specifications/`, `vis/` → **Fallback A** too, saying the
   importer needs a `specifications/` directory there.
2. **Feature folder** = an immediate child of any `<spec-dirs>` directory whose name equals
   `<KEY>` or begins `<KEY>-` or `<KEY>_` (case-insensitive) — `jira-workitem-import`'s rule
   (`<KEY>` or `<KEY>-…`, under `specifications/` only), widened to tolerate `_` and the `specs/`
   and `vis/` directories, so a bare folder an import created and a slugged one `create-vi:`
   created both match. **None** → go to the nested scan in step 3. **Several** (in one directory
   or across several) → list every one as prose and ask which to use (never pick; never rename one). Mark the
   one holding `jira-import/<KEY>-index.md` and recommend it; if none holds one, say so and
   recommend nothing; if several do, list each with its import date and recommend the newest.
   Say that the importer itself stops when several folders match, so the user should merge them.
   The array follows the run-time picker shape (§ Fallback prompts, last paragraph):
   `choices: ["<recommended folder> (Recommended)", "<other folders…>", "Cancel"]`.
3. If the folder holds `jira-import/<KEY>-index.md`, `jira_export_root` = `<feature
   folder>/jira-import`, `jira_key` = `<KEY>`, `focus_key = null`. Otherwise the key has no import
   of its own — **nested scan**: every `<spec-dirs>/*/jira-import/<KEY>/<KEY>.md`, skipping
   folders whose own key equals `<KEY>`. Read the matched page's `issue_type`. A `ValueIncrement`
   is **never** resolved as nested → **Fallback B**, saying in prose where it was seen ("`<KEY>`
   appears in `<K>`'s import, but has no import of its own"). Any other type nests under any
   parent: **exactly one** match → a nested item (`jira_export_root` = that folder's
   `jira-import`, `jira_key` = that folder's key — taken from its `<K>-index.md` file name, not
   the folder name — and `focus_key` = `<KEY>`); **several** → **Fallback E**; **zero** →
   **Fallback B**. If the folder the user chose in step 2 has no import but a same-key sibling
   does (the scan skips same-key folders), do not report "not imported": say so, name the
   sibling, and re-offer step 2's choice — the importer stops on several matches, so
   re-importing will not help until the folders are merged.
4. `source = specs`.
5. Resolve `specs` (§ Specs resolution).

**Note:** the VI-selector rule below applies the same split to a single JiraID — keyed on an
*import* (`jira-import/<KEY>-index.md`), never on a bare folder, because a folder `create-vi:`
made before any import is not an import — and it never nests a `ValueIncrement`.

### jira-driven — directory token (works *without* `$SPECS_PATH`)

Inspect-classify each path token **by content, not by name** (this is the same
classification `implement:` performs for `@dir`):

- **jira-export** — a directory containing `<KEY>-index.md` (or ticket-key
  subdirectories each containing `<KEY>.md`). `jira_export_root` = this directory;
  `jira_key` = `<KEY>` derived from the `<KEY>-index.md` basename / the nested
  `<KEY>/` subdirectory name; `source = directory`.
- **spec-folder** — a directory containing `prompt.md` and/or a `*-design.md`.
  Contributes to `specs`.
- **other** — surface to the user (never silently skip): ask whether to continue
  without it or stop.

Exactly one jira-export is expected; **≥ 2 → Fallback C**. Additional spec-folders
merge into `specs`. A JiraID **and** a spec-folder directory may be given together
(`PRODUCT-123 @/path/to/specs`): the JiraID fixes the hierarchy, the spec-folder
contributes/overrides `specs`.

### VI selector + optional focus Epic (two-key grammar)

The first positional is a **VI selector** — either a **VI JiraID** (resolved to its feature folder's
`jira-import/`; requires `$SPECS_PATH`) or a **jira-export directory** (content-classified as a
jira-export; used directly as `jira_export_root`; **no `$SPECS_PATH` needed**). An optional
**focus Epic** (a JiraID) may follow either form.

- **Single VI JiraID** — its own folder holding `jira-import/<KEY>-index.md` → a VI or stand-alone
  item (`jira_export_root = <its folder>/jira-import`, `source = specs`, `focus_key = null`);
  otherwise the nested scan of § JiraID token step 3 over
  `<spec-dirs>/*/jira-import/<KEY>/<KEY>.md`: a `ValueIncrement` is never nested (→ Fallback B);
  any other type with **exactly one** match → a **nested item** (`jira_export_root` = that
  folder's `jira-import`, `jira_key` = that folder's key, `focus_key = <KEY>`); **several** →
  Fallback E (a ticket can sit in a VI's import and in a feedback ticket's at once); **zero** →
  Fallback B (not imported — B delivers the import command).
- **jira-export directory** — `jira_export_root` = the dir, `source = directory`, no `$SPECS_PATH`.
  This is what Fallback A already points users to.
- **Optional focus Epic** (second positional JiraID) — binds to whichever import resolved: validate
  `<jira_export_root>/<Epic>/<Epic>.md` → `focus_key = <Epic>`; missing → Fallback D.

| Input | Root | `$SPECS_PATH`? | `focus_key` |
|---|---|---|---|
| `<VI-Key>` | `<VI folder>/jira-import` | required | null |
| `<Epic-Key>` | the parent's `jira-import` (auto-resolved) | required | the Epic |
| `<VI-Key> <Epic-Key>` | `<VI folder>/jira-import` | required | the Epic |
| `<dir>` | `<dir>` | not needed | null |
| `<dir> <Epic-Key>` | `<dir>` | not needed | the Epic |

Directory tokens stay **content-classified** (jira-export vs spec-folder), so `<dir> <Epic-Key>` never
collides with the existing `<VI-Key> @spec-folder` form (a spec-folder feeds `specs`, not the root).

### direct

Collect free-text prose into `direct_prompt` and any file tokens into
`direct_files`. No Jira/specs resolution.

## Specs resolution (jira-driven)

`SPECS_PATH` is an AI-Containers environment variable — host-provided, mounted into the container
(at `/workspace/specs` in Ai-Containers; an arbitrary directory on a host).

**Never a spec, at any depth** — in any step below, including a passed directory: anything under
a `jira-import/`, `epic-drafts/` or `dev-workflows/` directory; `jira_export_root` itself
whatever it is named (a passed import directory need not be called `jira-import/`); and a feature
folder's operator drafts `<KEY>-release-notes.md`, `<KEY>-implementation-gaps.md` and
`<KEY>-pr-draft.md`. `jira-import/` is the Jira import itself (read by `jira-reader`), `epic-drafts/`
holds `epics:`' drafts, `dev-workflows/` the plugin's own bookkeeping; `jira_export_root` by name
covers an import passed from elsewhere, and the three drafts are operator output; a VI with forty imported Stories would
otherwise hand forty ticket pages to `implement:` as specs.

Resolve in order:

1. **`$SPECS_PATH` set →** search every `<spec-dirs>` directory, resolving by **matching folders
   on the Jira key-number** (tolerate `-`/`_` separators, a trailing slug, or neither — a bare
   `<key>/` folder, which the importer creates, matches too):
   - **`focus_key` set →** prefer the nested per-Epic home: under the VI folder
     matching `jira_key` (`<VI>`, `<VI>{-|_}<vslug>/`), the Epic folder matching `focus_key`
     (`<focus_key>`, `<focus_key>{-|_}<eslug>/`), holding `specification.md`, `design.md`, and any
     other `.md`. If that nested Epic folder does not exist, **fall back** to the
     VI-flat resolution below (so nothing pre-foundation breaks).
   - **`focus_key` null →** the VI-flat resolution: a `<jira_key>`-prefixed folder
     (`<jira_key>`, `<jira_key>{-|_}<slug>/…/*.md`) holding the `.md` specs/plans — for a
     stand-alone item, a broad VI-level slice, or a legacy pre-foundation layout.
2. **Directory case →** a passed spec-folder (a directory token that points at an import yields
   no specs — the never-a-spec rule excludes `jira_export_root` entirely).
3. **None found →** `specs: []`. The **consuming command** applies its policy:
   `implement:` (jira-driven) prompts the user where the specs are
   (required-with-override); `document:` proceeds (additive).

## Fallback prompts (orchestrator-owned)

- **A — JiraID but no usable `$SPECS_PATH`:** unset or not a directory → say so and offer to
  set it;
  a directory with none of `specs/`, `specifications/`, `vis/` → say the importer needs
  `specifications/` there. Either way
  `choices: ["Set SPECS_PATH (enter the path)", "Pass an imported-Jira directory instead", "Cancel"]`
- **B — JiraID-shaped but no `<feature folder>/jira-import/<KEY>-index.md`, and no nested import
  either (or a `ValueIncrement` seen only inside another ticket's import):** say in prose
  that the ticket has not been imported into the specs repo and give the
  command — `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>` in a `jira-workitem-import`
  checkout (its stock `runme.sh` unsets `SPECS_PATH` and writes elsewhere) — then
  `choices: ["I've imported it — check again (Recommended)", "Pass an imported-Jira directory instead", "Treat the text as a direct edit instead", "Cancel"]`.
  A jira-driven-only command (`epics:`, `specify:`, `release-notes:`, `create-ard:`, `design:`,
  `ready:`) has no direct mode, so its third option is "Re-enter the Jira key" instead. A re-typed
  key can also arrive through the free-text answer.
- **C — multiple jira-export directories:** print every one as prose, then the run-time picker
  shape below:
  `choices: ["<first> (Recommended)", "<other directories…>", "Cancel"]`
- **D — Epic key given explicitly as a second key (or under a directory root) but not found:**
  `<jira_export_root>/<Epic>/` missing;
  `choices: ["Re-enter the Epic key", "Run on the VI without an Epic focus", "Cancel"]`
- **E — key found in several feature folders' imports:** print every candidate folder as prose
  above the prompt, marking each one's issue type and import date. Recommend the `ValueIncrement`
  candidate when exactly one is a VI, else the most recently imported — "a VI candidate" means a
  folder whose **own** root ticket (named by its `<K>-index.md`) is a `ValueIncrement`, since
  every candidate's matched page is the same `<KEY>`. Run-time picker shape below:
  `choices: ["<recommended folder> (Recommended)", "<other folders…>", "Cancel"]`

**Run-time pickers (C, E and JiraID step 2).** The array is built at run time. Print every candidate
as prose above the prompt, then list every candidate plus "Cancel" — `ask_user` has no option cap in
this edition, so no remainder option is needed. A typed answer is resolved against the listed
candidates only, never parsed into a path.

## Output contract

The resolution yields one normalized shape; each command reads only the fields it
needs:

```
mode:             jira-driven | direct
source:           specs | directory | none
jira_key:         <KEY> | null
jira_export_root: <abs path to the ticket export dir> | null   # → jira-reader (jira_export_root input)
focus_key:        <EPIC key> | null    # Epic to center on within jira_export_root; null for a bare VI/stand-alone/dir
specs:            [<abs paths>]    # specs/plans; may be []
direct_prompt:    <free-text> | null
direct_files:     [<abs paths>]
```

## Entry point — `resolve-export-for-key <KEY>`

Locates the export for **one exact key**, in every feature folder's import. Distinct from the
VI-selector rule above, which deliberately resolves a nested Epic *up to its parent VI*; this one
never walks upward. Consumed by `idea:` (source typing), `idea-reader` (export
location for `rfe`/`vi` sources), and `vault-prior-art-finder` (status
resolution) — none of them wants a parent.

1. `candidates` = every `<spec-dirs>/*/jira-import/<KEY>/<KEY>.md` — a key recurs under
   several feature folders, because every import carries the tickets its root links.
2. **none** → `NOT_FOUND`.
3. **exactly one** → that file.
4. **several** → the **most recently modified**. Copies genuinely disagree: one
   `PRODUCT-1234` export reads `Post GA` and another `Release Preparation`, and
   `PRODUCT-1235` has three copies of which two still carry its pre-rewrite summary.
   Picking arbitrarily reports a stale identity.

Returns `{ path, issue_type, status, summary, export_date }`, read from the file's
frontmatter; `export_date` is the file's modification date.

**Additive.** This adds an entry point; it changes no caller of the others. The resolution
itself (the JiraID steps, the VI-selector rule, the fallback prompts) now reads imports under
`<spec-dirs>`, and the output contract's `source` is `specs | directory | none`.

## Progress-aware Epic picker (opt-in per command)

For an **Epic-unit** command given a top-level key with `focus_key = null`, first determine the item's
type from a cheap `jira-reader depth: vi-plus-epics` read, then:

- **The item is itself an Epic** (stand-alone/top-level) → no picker; proceed for it directly.
- **VI with exactly 1 Epic** → no picker; auto-proceed for that Epic.
- **VI with ≥2 Epics** → render a status-aware picker. Status comes from the command's own output
  artifact (its **done-predicate**), one row per Epic:
  - **○ not started** — no artifact → selectable.
  - **◐ in progress** — a resume file exists but no final artifact → selectable as resume.
  - **● done** — artifact exists → shown greyed, not default-selectable; selecting offers revise.
  Default cursor = first actionable (in-progress before not-started). Include an explicit
  "Author one broad VI-level artifact instead" choice. After finishing one, offer
  "Next Epic? [picker] / Stop here". Resume stacks across sessions (VI picker + the command's own
  per-item resume file).
- **VI with 0 Epics** → the command's no-Epics policy (e.g. split with `epics:` first, or a broad
  VI-level artifact).

This pattern is **policy-neutral in the resolver** — it is invoked by Epic-unit commands only; VI-level
commands (`epics:`, `document:`, `release-notes:`) never use it and must keep working for un-split VIs.
