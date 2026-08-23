# prompt-grill-me:

Logs a corrective interaction — a dev-workflows skill produced something wrong and you're fixing it — as plugin feedback, then grills the fix inline with a bounded (≤5-question) one-question-at-a-time interrogation, following the embedded grilling technique.

## Who runs it

`prompt-grill-me:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `prompt:*` alongside `vuln:`, `upgrade:`, `feedback:`, `docs-profile:`, and the two guideline reviewers as skills that carry no next-phase offer. Of the three skills that capture a corrective interaction, `prompt-grill-me:` is the one that interrogates the fix inline rather than applying it directly ([`prompt:`](prompt.md)) or handing off to explore it together ([`prompt-brainstorm:`](prompt-brainstorm.md)). It is **self-contained** — its Phase 3 grill owns the interrogation itself, with no plugin dependency.

## Synopsis

    prompt-grill-me: <corrective request>

The argument — everything after the `prompt-grill-me:` trigger — is the corrective request itself, captured **verbatim** as the User-prompt block, never paraphrased. Phase 1 infers which command's output you're correcting from recent session context, asking only if genuinely ambiguous (one grouped prompt, last choice `"Other… (describe)"`); if no command applies, it records `n/a`.

## What it needs

- **The argument itself, verbatim** — the correction to interrogate, and the corrective-triple's User-prompt block.
- **Recent session context**, to infer the target `command` (or ask once if ambiguous).
- **`$SPECS_PATH`** — for the feedback entry and the `specs-preflight`/`commit-artifacts` bookkeeping.

## What it produces

Appends an `origin: prompt` entry — Friction, User prompt verbatim, Resolution (fixed as `Grilled the fix inline`) — via [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md)'s `emit-prompt` entry point (§6) and the same specs-first ladder [`feedback:`](feedback.md) uses; it doesn't restate that logic here. The terminal `commit-artifacts` step then commits and pushes it — run **before** Phase 3's grill, which is interactive and may run long, so a commit placed after it risks never executing — printed as a `Specs repo:` outcome line. This skill never commits into a docs/code repo, the vault, or your current working directory — only `$SPECS_PATH`'s bounded artifact paths ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) §2.1).

## Gates

No reviewer and no separate fix cycle — the Phase 3 grill **is** the gate, interrogating the correction itself rather than reviewing an artifact. It follows [`skills/_shared/grilling-technique.md`](../../skills/_shared/grilling-technique.md) at **bounded** depth — a capped set of at most 5 of the highest Impact×Uncertainty questions about the fix, then stop, recording any leftover high-impact gaps — the same mechanics document names `prompt-grill-me:` as its one explicitly bounded, non-authoring caller alongside `idea:`'s default depth. Mechanics: one question at a time, a recommended answer offered with each, the fact-vs-decision split (facts resolved by the skill itself, only genuine decisions put to the user), and dependency order (a parent decision resolved before what depends on it). The only two hard checkpoints are the specs-repo git guards — `specs-preflight` at the start, `commit-artifacts` at the end ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md)) — and a `prompt` entry is never silently skipped, exactly as a manual [`feedback:`](feedback.md) entry is not.

## Example

    prompt-grill-me: "specify: accepted an acceptance criterion with no measurable threshold — I fixed it by hand but want to check the fix covers the general case"

The skill infers the target command (`specify:`), logs the corrective triple to the VI's feedback file, commits the session artifacts to the specs repo, then interrogates the fix inline — at most 5 questions, one at a time, each with a recommended answer — to confirm the correction generalises rather than just patching the one instance.

## See also

- [`feedback:`](feedback.md) — logs a standalone note with no corrective triple and no fix; its "## See also" names the other two corrective-interaction skills.
- [`prompt:`](prompt.md) — logs the same corrective triple but applies the fix directly instead of interrogating it.
- [`prompt-brainstorm:`](prompt-brainstorm.md) — logs the same corrective triple but hands off to `superpowers:brainstorming` to explore the fix together instead of grilling it inline.
- [`skills/_shared/grilling-technique.md`](../../skills/_shared/grilling-technique.md) — the bounded-depth mechanics this skill's Phase 3 follows, embedded so this skill carries no runtime dependency.
- [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) — the entry format, the `emit-prompt` entry point, and the specs-first ladder that resolves where a note lands.
- [`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) — the `specs-preflight` and `commit-artifacts` entry points this skill runs.
