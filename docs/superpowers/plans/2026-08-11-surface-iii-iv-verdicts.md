# Surfaces iii/iv/vi/vii — classification verdicts

## Copilot edition

Task 7 of the 2026-08-11 printed-output-correctness plan. Same table shape as the canonical
edition's Task 3 file (`/workspace/ihudak-claude-plugins/docs/superpowers/plans/2026-08-11-surface-iii-iv-verdicts.md`).

**Result: zero QUALIFY.** Every candidate line surfaced by the six greps below (the brief's two
surface-iii/iv patterns, plus the coordinator-supplied vi-a / vi-b / vii-a / vii-b patterns for
the two surfaces discovered after the brief's own surface list was written) is a marker-grep false
positive — a `/`-prefixed file path or a compound noun, never a printed invocation target. This is
a genuine count difference from the brief's expectation ("Copilot's real work in this step is
surfaces iii and iv only"), reported per the standing instruction to STOP and report a count
mismatch rather than force one. It reconciles cleanly with the earlier Claude-to-Copilot port
(`docs/superpowers/plans/2026-07-13-claude-to-copilot-port.md`): that port already wrote every
role-handoff, context-hygiene, and STOP-message line in the `<name>:` idiom, so this dialect never
accumulated the bare-slash printed-offer debt the canonical edition had at the start of Task 3.

Greps run (from `dev-workflows/skills`, `CMDS` as specified in the brief / task prompt):

- surfaces iii/iv candidates (brief Step 3, two patterns)
- vi-a — role-handoff / context-hygiene lines beside `/compact` or `/clear`
- vi-b — annotated offer bullets whose first token is a command name
- vii-a — bare name within 3 lines after a quoted/italic literal opener
- vii-b — run / re-run instruction or `NAMED_ERROR:` code carrying a bare command

| Site | Text (truncated) | Surface | Verdict | Reason |
|---|---|---|---|---|
| `docs-profile/SKILL.md:194` | `git -C <repo-root> commit -m "docs: add/refresh .dev-workflows/docs-profile.yml"` | iii/iv | LEAVE (false positive) | grep matched `/docs-profile` inside the `.yml` filename, not a command mention |
| `document/SKILL.md:475` | `find "<specs_dir>" \( -path "*/epics/*" -o -path "*/spec/*" -o … \)` | iii/iv | LEAVE (false positive) | grep matched `/epics` and `/spec` inside directory-name globs, not command mentions |
| `implement/SKILL.md:720` | "…extract its in-scope IDs, pass `applicable_spec` to `code-review`… escalate unresolved `missing`/`contradicts`… on the spec/design — never silently" | iii/iv | LEAVE (false positive) | grep matched `/design` inside `specification.md`/`design.md` — "spec/design" is a compound noun (document-type shorthand), not an invocation |
| — | (vi-a: role-handoff/context-hygiene beside `/compact`/`/clear`) | vi-a | — (no candidates) | already in `<name>:` form throughout (e.g. `idea/SKILL.md:158`, `epics/SKILL.md:632-633`, `create-vi/SKILL.md:223-224`) — confirmed by manual re-grep of every `/compact`\|`/clear` site; none of the neighboring skill names are slash-style |
| — | (vi-b: annotated offer bullets) | vi-b | — (no candidates) | none found |
| — | (vii-a: multi-line quoted/italic offers) | vii-a | — (no candidates) | none found |
| — | (vii-b: run/re-run/`NAMED_ERROR:` lines) | vii-b | — (no candidates) | all `*_NEEDS_*` / `PROFILE_REQUIRED` messages already print `<name>:` (e.g. `create-vi/SKILL.md:23` `CREATE_VI_NEEDS_KEY: create-vi: needs a Jira key … re-run 'create-vi: <KEY> @<idea.md>'`; `document/SKILL.md:85` `run docs-profile: or switch to a profiled repo`) — confirmed by manual re-grep of every `NEEDS_JIRA`/`NEEDS_KEY`/`PROFILE_REQUIRED`/`re-run` site |

## Tally

- Candidate lines surfaced by the six greps: **3** (all in surfaces iii/iv; vi-a/vi-b/vii-a/vii-b
  returned 0 raw hits)
- **QUALIFY**: **0**
- **LEAVE (false positive)**: **3**
- Total sites edited in this step: **0** — Step 3's work is fully absorbed; no `SKILL.md` printed
  surface required a slash-to-`<name>:` conversion. Copilot's actual Step 3 deliverable is this
  verdicts record itself, establishing that the sweep ran and found nothing to fix.
