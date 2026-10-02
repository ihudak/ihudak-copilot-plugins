# Follow-ups

A follow-up is a checklist line written into the specs repo for something a skill's run surfaced but could not finish itself — a manual publish step, a file owned by someone else, a Jira ticket that needs updating to match a spec. `document:`, `release-notes:`, `epics:`, `implement:`, and `ready:` each carry a terminal "Emit follow-up tasks" phase that applies the same rules described here. Nothing is ever written without you seeing it first — every qualifying follow-up is shown as a batch preview at the very end of the run, and only a single confirmation actually commits any of it to disk.

## The task line

A follow-up renders as one plain markdown checklist line:

```
- [ ] <Description> — [<KEY>](<base>/browse/<KEY>) · added <YYYY-MM-DD>
```

`Description` is one imperative line naming the out-of-scope action. When the follow-up is tied to a Jira key, the line links it to `<base>/browse/<KEY>`, with `<base>` read from the `**Jira Link:**` line of the run's own import; with no import, the bare key appears as plain text. The creation date is always added.

## Where it lands

Resolution is deterministic — there is no interactive "pick a location" prompt for a single task. The write target degrades through a fallback ladder, most-durable option first:

1. **`$SPECS_PATH` VI directory exists** → `<VI-dir>/dev-workflows/<KEY>-followups.md`, the primary case. Any verbose note — a table, a paste-ready draft, multi-step detail — is inlined as a section of that same file and linked from the task line.
2. **The run's source was an imported Jira directory outside `$SPECS_PATH`** → `<parent-of-import>/<KEY>-followups.md`, beside the import.
3. **Nothing resolvable** → report-only: the follow-ups stay in the run's Final Report and nothing is written anywhere. The plugin never writes into your current working directory on this path, since it may be a code repository. The run says so with a notice asking you to set `$SPECS_PATH` to persist them.

On a run carrying `specs_git: misrooted`, meaning the run found `$SPECS_PATH` misplaced in any of the cases [Environment](environment.md) describes (`skills/_shared/specs-repo-git.md` §3.1 is the authority on them), the follow-ups stay in the Final Report instead, whatever else resolves, so nothing is written under a path the run found wrong. The run says so with a notice naming the flag.

Every tier also keeps the follow-ups visible in the Final Report, so a degraded write location never means lost information — only a less durable one, flagged with a notice naming the fallback path used.

## What qualifies as a follow-up

Only a signal whose action lands **outside the current change** or needs a **manual human step** becomes a follow-up: a file or page owned by someone else, a manual publish step (uploading a screenshot, pasting release notes into Jira, creating Epics in Jira by hand), a spec-versus-Jira mismatch that needs the ticket updated to match, or an unresolved PR on a host the plugin can't reach and so must be documented by hand. It deliberately does **not** fire for anything the run's own report or draft already tracks in scope — a deferred review BLOCKER, a skipped test, an in-draft `<!-- TODO -->` marker — since those belong to the current task and duplicating them as a separate task would just create two places tracking the same thing. If nothing in a run qualifies after this filter, the whole phase is a silent no-op: no preview, no prompt, nothing written, and the run looks exactly as if the phase didn't exist.

Before anything is inserted, the target file is checked for a follow-up with the same stable key — `jira_key` plus the file path, gap id, or signal type that identifies it — and a match is skipped and reported rather than re-inserted, so re-running a pipeline over the same ground never duplicates a task that's already there.

## Reviewing before anything is written

Follow-ups never interrupt a run mid-flight. Once the Final Report is composed, every qualifying follow-up is shown together as one batch preview, grouped by the file it would land in, each row naming the triggering signal, the target file, and the exact task line that would be written. You act on all of them with a single choice — approve every previewed row, select a subset by row number, or cancel and leave everything in the report only. Nothing reaches the specs repo, or any fallback location, without that one confirmation.
