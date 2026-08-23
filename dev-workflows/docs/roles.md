# Roles

[Workflow overview](workflow.md) shows where each skill sits in the pipeline. This page says what each role is accountable for and what it hands over at each seam.

**This edition has no cost-attribution phases.** [`skills/_shared/specs-repo-git.md`](../skills/_shared/specs-repo-git.md) states outright that this edition carries no cost subsystem — no `cost-emission.md`, no `emit-cost`, and no `dev-workflows-cost/` path shape. If you came from a Claude edition's "Roles and phases" page looking for the phase list that normally sits alongside the roles below, it does not exist here: a run's output here carries no `phase:` / `role:` cost label at all, and this page covers roles only.

## The handover model

Every phase ends the same way: a producing skill lands its deliverable on the specs repo's default branch via `handoff-to-main` — not merely written to disk, and not merely committed to a branch of its own ([`skills/_shared/phase-handoff.md`](../skills/_shared/phase-handoff.md) §2). The next skill in the chain runs `require-on-main` (§3) before it does any real work, and what happens next depends on which state that check finds:

- **The artifact is on the default branch** — the common, unremarkable case. The consuming skill proceeds, except when it is resuming on its own in-progress branch that already amends the artifact (§3.3 row B) — `design:` resumed on its own `design/<EPIC>-<eslug>` branch, amending the `specification.md` that same branch gates, is the load-bearing case that rule exists for.
- **The artifact exists but sits on an unmerged branch** — a pull request open, or one that never got opened. The consuming skill stops cold and names the branch (and the open PR, if there is one) rather than reading content that might still change underneath it.
- **The artifact does not exist on any branch at all.** The consuming skill treats it as absent and falls back to whatever it already did before this gate existed — an absent optional input is never promoted into a new prerequisite (§3.4). `design:`'s `specification.md` is the one exception across the whole pipeline: it is not optional, and its absence is a hard stop.

`ready:` is the one caller allowed to keep going past a stop like this: because its whole job is to report on readiness, an artifact it cannot verify becomes a finding that caps its verdict at `PARTIAL` rather than a reason to halt (§3.3, §3.7).

## PM (Product Management)

- **Owns:** turning a raw prompt, community post, RFE, or existing VI into a refined idea, then into a well-formed Value Increment, and keeping an existing VI current.
- **Runs:** `idea:`, `create-vi:`, `update-vi:`; also the early run of `release-notes:`, before any specification or design exists yet.
- **Consumes:** a prompt, file, community post, RFE, or existing VI as its source; then a refined `idea.md` plus a user-supplied Jira key.
- **Produces:** `idea.md` in `$VAULT_PATH` before a Jira key exists, then the VI written to `$SPECS_PATH/specifications/<KEY>-<slug>/`; an early release-notes draft.
- **Hands over at the seam:** `idea:` relocates and lands `idea.md`, and `create-vi:` / `update-vi:` land the VI, each onto the specs repo's default branch. `create-ard:` and `specify:` each gate on the VI there — an absent VI falls back to reading the Jira export directly instead of stopping (reported, not silent), and the hard stop is an unmerged VI, never a missing one. `epics:` reads the VI unconditionally through `jira-reader`, with no VI gate at all — see PE below for the input it does gate. `update-vi:` is deliberately the one PM skill that never calls `require-on-main` at all: its authoritative base is the Jira import (a 3-day freshness gate decides whether to trust the frozen draft instead), and gating its advisory ARD/spec grounding would block a legitimate refresh over an unrelated branch — it reports an unmerged grounding source instead of stopping on it.

## PA (Product Architecture)

- **Owns:** architecture decisions for a VI, or for one Epic inside it — an optional role in the pipeline (`create-ard:` is the skill that "introduces the pa role").
- **Runs:** `create-ard:`.
- **Consumes:** the VI (and the Epic, when scoped), grounded on the mounted implementation repos it discovers under `$REPOS_PATH` — architect-driven discovery, never a pull-request read.
- **Produces:** `<VI>_ARD.md`, or `<EPIC>_ARD.md` / `<EPIC>-<area>_ARD.md` for an Epic-level or area-split ARD, written into the same specs feature folder as the VI.
- **Hands over at the seam:** `create-ard:` gates on the VI — an absent VI falls back to reading the Jira export directly instead of stopping (reported, not silent), and the hard stop is an unmerged VI, never a missing one. `create-ard:` then lands the ARD the same way, and `epics:`, `specify:`, `design:`, `implement:`, and `ready:` each resolve it once it is there ([`skills/_shared/ard-resolution.md`](../skills/_shared/ard-resolution.md)).

## PE (Product Engineering)

- **Owns:** breaking a VI into Epics, and writing an org-standard specification for one item — an Epic, or, for a small VI, the whole VI.
- **Runs:** `epics:`, `specify:`.
- **Consumes:** the VI, plus the ARD when one exists and any Epics already drafted.
- **Produces:** Epic drafts under `$VAULT_PATH/jira-drafts/<VI-KEY>/` (or a derived `epic-drafts/<jira_key>/` dir when `$VAULT_PATH` is unset); `specification.md`, landed on the specs repo's default branch.
- **Hands over at the seam:** `specify:` gates on the VI the same way `create-ard:` does — an absent VI falls back to the Jira export and is reported rather than silent, and the hard stop is an unmerged VI, never a missing one. `epics:` has no VI gate at all, but it does gate two other inputs: an optional VI-level `specification.md`, whose absence is a silent skip (`vi_spec_present: false`), and the applicable ARD, where an unmerged ARD stops the run like every caller but `ready:`. `specify:` lands `specification.md` onto the specs repo's default branch, and `design:` refuses to start until it finds that specification there.

## Dev (Build, Verify, and Deliver)

- **Owns:** the engineering design, the implementation, and the documentation of the shipped feature — plus verifying that a declared Jira status is actually justified by the artifacts on record, which this role checks but never sets.
- **Runs:** `design:`, `implement:`, `document:`, `ready:`; also the final run of `release-notes:`, once a specification or design already exists.
- **Consumes:** the merged `specification.md` (plus the ARD, when one exists), then the merged `design.md`, then the code under `$REPOS_PATH`; `ready:` additionally consumes the declared Jira workflow status for the VI or Epic in question.
- **Produces:** `design.md`, landed on the specs repo's default branch; code on a feature branch in `$REPOS_PATH`, left uncommitted for you to review; product documentation in the external docs repo; the final release-notes draft; and, from `ready:`, a `SUPPORTED` / `PARTIAL` / `NOT-SUPPORTED` verdict plus an optional `_readiness.md` snapshot, committed and handed off only behind your consent.
- **Hands over at the seam:** `design:` is the one hard exception to the optional-input rule above — it stops outright if `specification.md` is not found on the specs repo's default branch. It then lands `design.md` the same way. `implement:` gates its own in-scope `specification.md` / `design.md` the same way `create-ard:` and `specify:` gate the VI — an unmerged one is a hard stop, but an absent one is not: the run behaves exactly as it did before this gate existed, and a direct-prompt run (which resolves no in-scope spec/design at all) is unaffected either way. `ready:` is the opposite extreme, and the exception named [above](#the-handover-model): it is the sole caller that keeps running past a stop another skill would treat as fatal, turning an unmerged or missing artifact into a finding that caps its verdict at `PARTIAL` instead of halting.

**Why there is no separate verification role.** `ready:` reads a status and reports on it. Its `_readiness.md` is a record rather than a handoff — the one skill that reads it, `implement:` at its own Phase 0.5, only softens a non-blocking recommendation — and it is normally run by the same person who just wrote the design or is about to start the implementation. Giving it a lane of its own would suggest a handover that does not happen, so it sits in Dev, the role that already owns everything it verifies.
