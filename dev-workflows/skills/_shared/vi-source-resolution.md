# Resolving an existing VI (Jira-import-first — shared reference)

The authoritative text of an **existing** Value Increment lives in **Jira**, not in the `$SPECS_PATH`
markdown. `create-vi:` writes the VI to `$SPECS_PATH` as the *initial* draft; once it is pasted into
Jira it is edited by people (and gains comments) there, while the specs draft stays frozen. Any workflow
that consumes an existing VI — `update-vi:` (its base) and `create-vi: --from-vi` (its seed) — MUST read
the re-imported Jira VI first.

This is an **adjacent** policy to `_shared/source-truth.md` (which governs code-vs-docs verification):
this file governs *which artifact holds the current VI text*, not code truth. Do not conflate them.

## Procedure — `resolve-existing-vi <KEY>`

1. **Validate** `<KEY>` against `^[A-Z][A-Z0-9_]*-\d+$`. Malformed → stop and report.
2. **Jira import first.** Look for `<feature folder>/jira-import/<KEY>/<KEY>.md` (the feature folder
   resolved as `jira-input-resolution.md` § JiraID token step 2 does). Confirm the frontmatter is
   `issue_type: ValueIncrement`. This import — the page body **and its inlined `## Comments` section** —
   is the **authoritative base**. (An import made before the flat layout may still carry a sibling
   `<KEY>-comments.md`; read it when present.)
3. **Not imported →** STOP. Ask the user to import it, then re-run:
   `choices: ["Import <KEY> now with the workitem-importer, then I'll re-run (Recommended)", "Cancel", "Other… (describe)"]`.
   Cite the importer and its SPECS-mode command: `https://github.com/ivan-gudak/jira-workitem-import`,
   `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>` (its stock `runme.sh` unsets `SPECS_PATH`). Never fall back to the frozen
   specs draft as the base.
4. **Imported but stale →** if the import file's mtime is older than **3 days**
   (`find "<feature folder>/jira-import/<KEY>" -name "<KEY>.md" -mtime +3`), show the import date and offer:
   `choices: ["Re-import <KEY> now — I'll wait (Recommended)", "Proceed with the current import", "Cancel", "Other… (describe)"]`.
5. **Secondary grounding (read-only; never the base):** the frozen `$SPECS_PATH` specs draft (glob
   `<KEY>_*.md`, `issue_type: ValueIncrement`), any `*_ARD.md`, `specification.md`, and — for
   `update-vi:` — a user-supplied `@transcript` / notes path. These enrich the grill; they never override
   the Jira import.

Product-level only — this reads markdown/comments; it mounts no repos and runs no code scan.
