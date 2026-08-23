# prompt-brainstorm:

Logs a corrective interaction — a dev-workflows skill produced something wrong and the correction needs exploration rather than a one-shot fix — as plugin feedback, then hands off to `superpowers:brainstorming` to redesign the correction together.

## Who runs it

`prompt-brainstorm:` runs outside the PM → PA → PE → Dev pipeline. This edition records no cost attribution, so there is no phase or role label on the run's output at all — not even an inferred one. [`skills/_shared/next-phase-offer.md`](../../skills/_shared/next-phase-offer.md)'s own "Not pipeline nodes" section lists `prompt:*` alongside `vuln:`, `upgrade:`, `feedback:`, `docs-profile:`, and the two guideline reviewers as skills that carry no next-phase offer. Of the three skills that capture a corrective interaction, `prompt-brainstorm:` is the one that explores the fix through `superpowers:brainstorming` rather than applying it directly ([`prompt:`](prompt.md)) or interrogating it inline ([`prompt-grill-me:`](prompt-grill-me.md)). Run it whenever a correction is big enough to need design exploration, not just a quick patch.

## Synopsis

    prompt-brainstorm: <corrective request>

The argument — everything after the `prompt-brainstorm:` trigger — is the corrective request itself, captured **verbatim** as the User-prompt block, never paraphrased. Phase 1 infers which command's output you're correcting from recent session context, asking only if genuinely ambiguous (one grouped prompt, last choice `"Other… (describe)"`); if no command applies, it records `n/a`.

## What it needs

- **The argument itself, verbatim** — the correction to explore, and the corrective-triple's User-prompt block.
- **Recent session context**, to infer the target `command` (or ask once if ambiguous).
- **`$SPECS_PATH`** — for the feedback entry and the `specs-preflight`/`commit-artifacts` bookkeeping. This skill applies no fix itself — `superpowers:brainstorming` takes over the session at Phase 3, and whatever it produces is never committed by this skill.

## What it produces

Performs no correction itself — that's the point of handing off. It appends an `origin: prompt` entry — Friction, User prompt verbatim, Resolution (fixed as `Handed off to superpowers:brainstorming to redesign the correction.`) — via [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md)'s `emit-prompt` entry point (§6) and the same specs-first ladder [`feedback:`](feedback.md) uses; it doesn't restate that logic here. The terminal `commit-artifacts` step then commits and pushes it — run **before** Phase 3's hand-off, since the brainstorming skill takes over the session there and a commit placed after it would never execute — printed as a `Specs repo:` outcome line. This skill never commits into a docs/code repo, the vault, or your current working directory — only `$SPECS_PATH`'s bounded artifact paths ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) §2.1).

## Gates

No reviewer and no fix cycle of its own — `prompt-brainstorm:` logs, then cedes control. The only two checkpoints are the specs-repo git guards — `specs-preflight` at the start, `commit-artifacts` at the end ([`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md)) — and a `prompt` entry is never silently skipped, exactly as a manual [`feedback:`](feedback.md) entry is not. The `superpowers:brainstorming` hand-off is a direct skill use with **no declared install-time dependency**: `prompt-brainstorm:` simply invokes the skill if it's present. `superpowers` is not one of the four plugins this marketplace ships (`dev-workflows`, `dt-style-guide`, `obsidian-llm-wiki`, `acli` — [`.github/plugin/marketplace.json`](../../../.github/plugin/marketplace.json)); it is a recommended external companion ([`skills/_shared/dependencies.md`](../../skills/_shared/dependencies.md)) with a documented fallback when absent ([Getting started](../getting-started.md)): without it installed, the Phase 3 hand-off has nowhere to go, but every other skill — including `prompt:` and `prompt-grill-me:` — runs unaffected. Unlike `docs-grounder`'s `qmd` CLI dependency, that fallback is not documented inside `prompt-brainstorm/SKILL.md` itself.

## Example

    prompt-brainstorm: "design: kept collapsing three distinct failure modes into one Alternatives-considered bullet — I want to explore how to keep them separate without bloating the section"

The skill infers the target command (`design:`), logs the corrective triple to the VI's feedback file, commits the session artifacts to the specs repo, then hands off to `superpowers:brainstorming` to explore the redesign with the user.

## See also

- [`feedback:`](feedback.md) — logs a standalone note with no corrective triple and no fix; its "## See also" names the other two corrective-interaction skills.
- [`prompt:`](prompt.md) — logs the same corrective triple but applies the fix directly instead of exploring it.
- [`prompt-grill-me:`](prompt-grill-me.md) — logs the same corrective triple but interrogates the fix inline (bounded, ≤5 questions) instead of handing off.
- [`skills/_shared/feedback-emission.md`](../../skills/_shared/feedback-emission.md) — the entry format, the `emit-prompt` entry point, and the specs-first ladder that resolves where a note lands.
- [`skills/_shared/specs-repo-git.md`](../../skills/_shared/specs-repo-git.md) — the `specs-preflight` and `commit-artifacts` entry points this skill runs, and the §4 rule that a commit before a session-ceding hand-off runs immediately before it.
