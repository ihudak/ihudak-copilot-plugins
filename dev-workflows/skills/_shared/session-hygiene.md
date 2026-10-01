# Session hygiene (embedded — shared reference)

The plugin-wide contract for **session-hygiene suggestions**: after a big command
finishes (or a long-run command reaches a mid-phase checkpoint), the pipeline first
**flushes resume-critical state to disk**, then **suggests the right context action**
(`/compact` or `/clear`) plus a session **`/rename`** aid. Cited by the pipeline commands
and by `next-phase-offer.md` / `context-management.md`, so the contract lives in ONE
place (the same shape as `next-phase-offer` and the `emit-block` invariant).

Everything here is **guidance-only** — the plugin NEVER auto-invokes `/compact`,
`/clear`, or `/rename`. The goal is to stop relying on a human to keep asking "prepare
for a compact/clear": the pipeline does the prep and prompts the choice itself.

## 1. Prepare-checkpoint (runs FIRST — unconditional for VI-scoped runs)

At command finalization — AFTER the deliverable artifact is saved/committed, AFTER
the terminal feedback and follow-up steps, and BEFORE the terminal `commit-artifacts`
step (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4) — a VI-scoped run writes/overwrites a **resume pointer**. It runs regardless of
which suggestion (or none) fires: **prepare always, suggest adaptively.**

**The write is its own terminal step — not part of the printed suggestion.** The
`### Context hygiene` block in a command's report carries the `/compact` | `/clear` |
`/rename` guidance only. The pointer is written by a **discrete step that runs after
the terminal feedback and follow-up steps and before `commit-artifacts`** — the last
step of the skill's terminal feedback/follow-up phase, never folded into the
feedback- or follow-up-emission procedures themselves. The order is three separate
steps, as §5 rule 2 states: **follow-ups → `resume.md` → `commit-artifacts`**.

Binding the write to the printed block instead would break it twice over: several
commands compose their Final Report *before* their terminal feedback and follow-up
steps run, so the write would land before the follow-up entry it is supposed to
follow, and it would stay uncommitted, since `commit-artifacts` runs after the
terminal feedback and follow-up steps. Prepare-first is still satisfied: the write
happens before the run ends, and therefore before the user can act on the printed
suggestion.

**Skipped** (no VI anchor to write against): `implement:`
**direct** mode, `document:` **doc-edit** mode (Mode B), `vuln:`, `upgrade:`. There the
durable state is the artifact / branch / PR already on disk; no resume pointer is written.

**Location** (mirror `followup-emission.md` §2 resolution):

1. `$SPECS_PATH` resolvable + writable + the VI dir exists → `<VI-dir>/dev-workflows/resume.md`. *[primary]*
2. `$SPECS_PATH` writable but no VI dir matched → skip the file; rely on the printed `### Next step`.
3. No writable `$SPECS_PATH` → skip the file; the suggestion still fires with a one-line
   `⚠ could not persist a resume pointer — set $SPECS_PATH`.

`resume.md` is a **"last known position" pointer, OVERWRITTEN each run** (NOT an append
log). It is intentionally tiny:

```markdown
# Resume — <KEY>[ / <EPIC-KEY>] (<role>)

- **Last completed:** <command> <args> — <phase or 'command complete'> (<ISO datetime>)
- **Artifact:** <relative path to the deliverable just written/committed, or 'none (read-only)'>
- **Next step:** <the exact next command from ### Next step, or 'VI fully processed'>
- **Suggested session name:** <VI-ID>-<slug>-<role>   (omit this line on a run whose own `### Context hygiene` block carries no `/rename` suggestion — that block is this command's own, so the test is decidable from the command being executed and needs no list to look up; §4 names which commands carry the line and why the rest do not)
- **Carry-forward decisions:** <0–N one-line decisions the next phase needs that are NOT already in the artifact; 'none' if none>
```

**Redact before writing.** The `Carry-forward decisions` line may summarize
content pulled from a Jira ticket or the session — redact any secret,
credential, token, or PII. A resume pointer records *what to do next*, never a
sensitive value.

## 2. The suggestion — role-aware (reads next-phase-offer's role labels)

`next-phase-offer.md` already role-labels every next option (PM / PA / PE / Dev). For
each next option the offer names, compare its role to the just-finished command's role:

- **Same role** (e.g. `design: E1 → design: E2`, Dev→Dev) → suggest **`/compact`** —
  context still relevant, keep the thread.
- **Different role** (e.g. `epics:` PE → `design:` Dev) → suggest **`/clear`** as the
  better choice when one person keeps wearing both hats (the prior role's reasoning is
  now noise). `/compact` still works if continuing right away; a genuinely different
  person just starts fresh and re-reads disk.
- Next options **span both** (e.g. `create-vi:` → PM `release-notes:` OR hand to PA/PE) →
  present **both branches**: "continuing as PM → `/compact`; handing off (even to
  yourself) → `/clear`."
- **User is done / ending the session** → suggest nothing.

Do NOT hardcode a per-command compact/clear verdict — read the role labels the command's
own `next-phase-offer` output already carries. The role graph is owned by
`next-phase-offer.md`; it is not duplicated here.

## 3. Mid-phase checkpoints & non-pipeline big commands

- **`implement:` mid-phase checkpoint** (Scope-to-N / per-Epic, per `context-management.md`)
  → suggest **`/compact`** to free budget before continuing (mid-command → no role
  transition → never `/clear`).
- **`vuln:`, `upgrade:`** (big, non-pipeline, no role transition) → a plain end-of-run
  **`/compact`** suggestion only; no `resume.md` (durable state is the branch/PR).

## 4. Session-name aid

**A command prints the aid where its own `### Context hygiene` block carries the line — that block,
not any argument shape, is what settles it.** Read off those blocks, the set is the PA/PE/Dev ladder —
`create-ard:`, `epics:`, `specify:`, `design:`, `ready:`, `implement:`, `document:`,
`release-notes:`. For those, print a suggested `/rename <VI-ID>-<slug>-<role>` line so the user can
relocate the session later (e.g. after going home). `<role>` is the
just-finished command's lane tag (pm / pa / pe / dev). Guidance-only — a command cannot run
`/rename` itself.

**Do not restate that set as "every command that takes a `<VI>`".** Argument shape does not settle
it: `implement:`'s key is optional (absent → the run is **direct**) and `document:`'s Mode B takes
none at all — both of those modes sit in §1's `**Skipped**` list and write no pointer, so the aid
question never reaches them — while `create-vi:` and `update-vi:` take a mandatory key and carry no
line. The block a command carries is the whole of the test.

**`idea:`, `create-vi:` and `update-vi:` are excluded** from the rename aid, and the reason is the
phase rather than the key. `idea:` always has one — its origin key, the VI's or the PRODFB
ticket's whose folder it writes into, which is also where its pointer goes — and `create-vi:` and
`update-vi:` each take a mandatory Jira key as their first argument and refuse without one (`CREATE_VI_NEEDS_KEY`, `UPDATE_VI_NEEDS_KEY`), so the key is in
hand before either writes anything. This section used to give "there is usually no VI-ID to name a
session after" as the reason for `create-vi:` too, and named no disposition for `update-vi:` at all,
which writes a resume pointer and so reached §1's template with nothing to decide the line by. The
exclusion stands because the PM phase is short enough that no label is worth auto-suggesting; the PM
names the session manually if they want one.

## 5. Contract (5 rules)

1. **Guidance-only** — never auto-invokes `/compact`, `/clear`, or `/rename`.
2. **Prepare-first** — the disk flush (resume pointer) always happens before the run
   ends, so acting on the printed suggestion is safe. Prepare is unconditional
   (VI-scoped); only the suggestion is adaptive. The canonical terminal order is:
   **deliverable + handoff → feedback → follow-ups → `resume.md` →
   `commit-artifacts` → the run's last printed output**. What binds every
   skill is the **emitter tail** — feedback → follow-ups → `resume.md` →
   `commit-artifacts`. A skill's deliverable-side finish may sit anywhere
   relative to the tail, including between its members, at whatever point
   suits it: `document:`'s conditional `Phase 8.5 — Finish & handoff` sits
   between feedback and follow-ups — it is the docs-repo git finish, while
   `emit-auto` writes into `$SPECS_PATH`, so the two touch different
   repositories and their relative order carries no consequence
   (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §4).
3. **Role-aware via a single graph** — the compact/clear split reads
   `next-phase-offer.md`'s role labels; the role graph is not duplicated here.
4. **Mode-aware** — direct / doc-edit / non-pipeline runs (no VI anchor) → no
   `resume.md`, no `/rename`, and the suggestion degrades to a plain optional `/compact`
   note (or is omitted, consistent with `next-phase-offer`'s mode-aware omission).
5. **Never blocks** — a nudge appended to the Final Report, exactly like the next-phase offer.

## Surface

A short **`### Context hygiene`** block appended right after the `### Next step` section
at the END of the command's Final Report (guidance-only prose), plus one invariant citing
this reference. `vuln:` + `upgrade:` place the `/compact` line near their
`impl-maintenance` handoff. `implement:` places the mid-phase `/compact` at its Phase 3B
checkpoint.
