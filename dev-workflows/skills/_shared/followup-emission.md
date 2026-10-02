# Follow-up Task Emission — Shared Reference

Single source of truth for the dev-workflows follow-up emitter. A terminal
"Emit follow-up tasks" phase in `document:`, `release-notes:`, `epics:`,
`implement:`, and `ready:` cites this file and executes its steps inline — the orchestrator
owns every prompt.

**Self-contained.** No runtime dependency on any other plugin; follow-ups are a plain markdown checklist in the specs repo.

## 1. Task-line format

    - [ ] <Description> — [<KEY>](<base>/browse/<KEY>) · added <YYYY-MM-DD>

- **Description** — one imperative line naming the out-of-scope action.
- **Jira link** — when the item carries a key; `<base>` is read from the run's own import (the `**Jira Link:**` line of `<jira_export_root>/<KEY>/<KEY>.md`); with no import, the bare `<KEY>` as plain text.
- **added** — the creation date, always.

## 2. Where follow-ups land

At the start of the phase, resolve the write target by walking the ladder,
most-durable first.

**Before tier 1: the run carries `specs_git: misrooted`** (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §3.1, or its §8 `specs-root-check` stop) → **report-only**, as in tier 3, whether or not a VI dir or an import resolved, with its own notice (below). `$SPECS_PATH` is set but misplaced, so a write under it lands where the next run, with the variable corrected, never looks, and a tier-2 write would file follow-ups for a run whose specs tree is in doubt.

1. **`$SPECS_PATH` VI dir exists** — the dir matched by
   `$SPECS_PATH/{specs|specifications|vis|ideas}/…/<KEY>{-|_}<slug>/…`, per the folder-naming rule of `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md` § JiraID token, step 2 (a name equal to `<KEY>` or beginning `<KEY>-` or `<KEY>_`, in any `<spec-dirs>` directory — a bare folder counts) →
   `<VI-dir>/dev-workflows/<KEY>-followups.md` (§2.1), verbose detail inlined
   as a section of that file and linked from the task line. Durable,
   VI-scoped, git-tracked (the specs repo), and NOT a code repo. *[primary]*
2. **`source = directory`** (an import outside `$SPECS_PATH`) →
   `<parent-of-jira_export_root>/<KEY>-followups.md` (the imported
   hierarchy's parent — the same area under which epics: and release-notes:
   place their drafts for such an import).
3. **None resolvable** → **report-only.** Keep the follow-ups in the Final
   Report and emit the notice. **NEVER** write into the current working
   directory — it may be a code repository.

In every tier the follow-ups ALSO remain in the Final Report (zero regression)
and the pipeline never fails.

- **Notice**: tier 2: `⚠ N follow-ups written to <path>`; tier 3:
  `⚠ No specs dir — N follow-ups kept in this report only; set $SPECS_PATH to persist them`;
  under `specs_git: misrooted`:
  `⚠ SPECS_PATH is misplaced (specs_git: misrooted) — N follow-ups kept in this report only.`
- **Interactive escape** (folds into the §5 batch preview, mirroring Fallback A
  in `jira-input-resolution.md`): at tier 2 only (the `source = directory` tier — tier 3 has no path to offer), show the resolved
  fallback path and offer
  `choices: ["Save to <resolved path>", "Keep in report only"]`,
  default = save.
- **Write fails mid-insert** (read-only mount / permission) → drop to the next
  tier, same notice.

### 2.1 Shared per-VI artifact area under `$SPECS_PATH`

`<VI-dir>/dev-workflows/` (a subdir of the VI's `$SPECS_PATH` spec dir) is the
home for dev-workflows per-VI artifacts. This feature writes
`<KEY>-followups.md` there; session feedback and resume
pointers share the same directory. This keeps the VI spec dir uncluttered and
groups all dev-workflows output for a VI in one place.

## 3. Idempotency / dedupe

Pipelines re-run. Before inserting, READ the existing tasks in the target
file and SKIP any whose stable key already appears. **Stable key** = the
finding's identity: `jira_key` + (file path | gap-id | signal-type). Report a
match as `SKIP — already exists`; never re-insert.

## 4. Qualifying predicate — what becomes a follow-up

Emit a task ONLY for signals whose action lands OUTSIDE the current change or
requires a MANUAL human step:

- Files/pages owned by others (non-allowlisted, override-copy, owner surfaced).
- Implementation gaps (Jira vs source; the `<KEY>-implementation-gaps.md`
  draft) → the task links the draft; verbose context → a section of the follow-ups file (§2).
- Manual publish steps: screenshots to upload (CDN), "paste release notes into
  Jira", "create these Epics in Jira manually", open-the-PR-by-hand.
- SPEC-VS-JIRA ("update the Jira ticket to match the spec").
- Unresolved PRs on unsupported hosts (must be documented manually).

DO NOT emit tasks for in-scope items the report/draft already tracks: deferred
review BLOCKERs, skipped tests, in-draft `<!-- TODO -->` markers. Those belong
to the current task and are already carried in the Final Report.

**If no signal qualifies after this filter, the phase is a no-op:** resolve no
target, show no preview or path prompt, write nothing, and end silently —
the run is byte-identical to one where this phase did not exist.

## 5. Interaction model — batch preview at end-of-run

NO mid-run interruption. After the Final Report
is composed, present the qualifying follow-ups as a batch preview GROUPED BY
TARGET FILE, then act on one confirmation:

    choices: ["approve-all", "select", "cancel"]

- **approve-all** → insert every previewed row.
- **select** → let the user pick a subset by row number, then insert those.
- **cancel** → write nothing; the follow-ups remain in the Final Report only.

Each preview row shows: the source signal, the target file, and the
rendered task line. Nothing is written to the specs repo (or a fallback file)
without one confirmation.

## 6. Caller contract (what a wiring command passes in)

The calling phase provides:

- `follow_up_items` — the qualifying signals it already aggregated in its Final
  Report follow-up sections.
- `jira_key` — the run's resolved key, or `null`.
- `source` — `specs | directory | none` from `jira-input-resolution.md`.

The phase applies §4 (filter) → §2 (resolve target) → §1 (render + place) →
§3 (dedupe) → §5 (confirm), then writes. It is ADDITIVE: the follow-ups always
also remain in the Final Report, the phase NEVER commits, and it NEVER writes
into a docs/code repo or the current working directory. Follow-ups written
into `$SPECS_PATH` are committed later, once, by the run's terminal
`commit-artifacts` step (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
§4); a follow-ups file beside an import outside `$SPECS_PATH` stays the
user's own sync responsibility.
