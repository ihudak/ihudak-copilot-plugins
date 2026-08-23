# feedback:

Logs a manual note about the dev-workflows plugin itself — friction you hit, or an improvement you want — for the maintainer to aggregate across engineers.

## Who runs it

`feedback:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `feedback:` alongside `vuln:`, `upgrade:`, the `prompt:` family, `docs-profile:`, and the two guideline reviewers as skills that carry no next-phase offer. It is tied to no other skill and can be run any time, about any friction you hit or improvement you want — see [Workflow overview](../workflow.md) for where it and its three siblings sit relative to the pipeline. This is one of the four skills that make the plugin better over time — use it whenever something is off, not only when it's dramatic; a small annoyance logged now is easier for the maintainer to act on than one nobody ever wrote down.

## Synopsis

    feedback: [<note>]

The argument (everything after the `feedback:` trigger) is the note text — the friction you hit and the improvement you want, in your own words. Leave it empty and Phase 1 asks for it directly; it never guesses at content you didn't express.

## What it needs

- **The note itself** — friction plus a suggested improvement. The skill lightly tidies wording but never invents content you didn't say.
- **Confirmed metadata**, resolved in one grouped prompt: `command` (inferred from recent context, or `n/a`), `category` (a controlled, reuse-first vocabulary from [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) §1), and `impact` (`blocker | friction | polish`).
- **`$SPECS_PATH`** — the specs-preflight step at Phase 0 settles the branch before anything is written; it is silent when the repo is already clean and on its default branch.

## What it produces

An `origin: manual` entry appended to the plugin's per-VI feedback file — see [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) for the exact entry format and the specs-first ladder that resolves where the file lands; `feedback:` doesn't restate that logic here. The terminal `commit-artifacts` step then commits and pushes it, printed as a `Specs repo:` outcome line. This skill never commits into a docs/code repo, the vault, or your current working directory — only `$SPECS_PATH`'s bounded artifact paths ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) §2.1).

## Gates

No reviewer and no branch of its own. The only two checkpoints are the specs-repo git guards — `specs-preflight` at the start, `commit-artifacts` at the end ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md)) — and a manual entry is never silently skipped: an `id` collision appends with a numeric suffix and a warning rather than dropping the note.

## Example

    feedback: "The specify: grill re-asked a question I'd already answered in the ticket description"

The skill confirms the inferred `command` (`specify:`) and `category`, appends the entry to that VI's feedback file, and commits it to the specs repo.

## See also

- [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) — the entry format, the controlled category vocabulary, and the specs-first ladder that resolves where a note lands.
- [`prompt:`](prompt.md), [`prompt-brainstorm:`](prompt-brainstorm.md), and [`prompt-grill-me:`](prompt-grill-me.md) — the three sibling skills that log a corrective interaction (`origin: prompt`) rather than a standalone note.
- [Workflow overview](../workflow.md) — where these four skills sit relative to the pipeline.
- [`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) — the `specs-preflight` and `commit-artifacts` entry points every one of these four skills runs.
