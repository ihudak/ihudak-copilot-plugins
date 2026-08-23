# prompt:

Logs a corrective interaction — a skill produced something wrong and you're fixing it — as plugin feedback, then applies the correction directly.

## Who runs it

`prompt:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `prompt:*` alongside `vuln:`, `upgrade:`, `feedback:`, `docs-profile:`, and the reviewer skills as carrying no next-phase offer. Of the three skills that capture a corrective interaction, `prompt:` is the one that just applies the fix — no hand-off to a brainstorming skill, no inline interrogation. Run it whenever you correct a skill's output yourself; logging the correction is what turns a one-off fix into signal the maintainer can act on for every other engineer hitting the same thing.

## Synopsis

    prompt: <corrective request>

The argument — everything after the `prompt:` trigger — is the corrective request itself, captured **verbatim** as the User prompt block, never paraphrased. Phase 1 infers which skill's output you're correcting from recent context, asking only if genuinely ambiguous (one grouped prompt, last choice `"Other… (describe)"`); if no skill applies, it records `n/a`.

## What it needs

- **The argument itself, verbatim** — the correction to apply, and the corrective-triple's User prompt block.
- **Recent session context**, to infer the target `command` (or ask once if ambiguous).
- **`$SPECS_PATH`** — for the feedback entry and the `specs-preflight`/`commit-artifacts` bookkeeping; the correction itself is applied to your target files directly, wherever they are, never to the specs repo.

## What it produces

Performs the correction directly against your target files (Phase 2) — those edits are never staged or committed by this skill. It then appends an `origin: prompt` entry — Friction, User prompt verbatim, Resolution (a one-line summary of the fix just applied) — via [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md)'s `emit-prompt` entry point (§6) and the same specs-first ladder [`feedback:`](feedback.md) uses; it doesn't restate that logic here. The terminal `commit-artifacts` step then commits and pushes it, printed as a `Specs repo:` outcome line. This skill never commits into a docs/code repo, the vault, or your current working directory — only `$SPECS_PATH`'s bounded artifact paths ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) §2.1).

## Gates

No reviewer and no fix cycle — `prompt:` **is** the fix, applied once, directly, with nothing downstream to re-check it. The only two checkpoints are the specs-repo git guards — `specs-preflight` at the start, `commit-artifacts` at the end ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md)) — and a `prompt` entry is never silently skipped, exactly as a manual `feedback:` entry is not.

## Example

    prompt: "design.md skipped the Alternatives considered section — add it back, listing the constraint each declined take optimised for"

The skill applies the fix directly, confirms the inferred `command` (`design:`), and logs the corrective triple — Friction, your verbatim request, and the one-line Resolution — to the VI's feedback file.

## See also

- [`feedback:`](feedback.md) — logs a standalone note with no corrective triple and no fix; its "## See also" names the other two corrective-interaction skills, which log the same triple but explore or interrogate the fix instead of applying it directly.
- [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) — the entry format, the `emit-prompt` entry point, and the specs-first ladder that resolves where a note lands.
- [Workflow overview](../workflow.md) — where `prompt:` and its siblings sit relative to the pipeline.
- [`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) — the `specs-preflight` and `commit-artifacts` entry points this skill runs.
