# Grilling technique (embedded — shared reference)

The interview technique the authoring skills (`idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`) and `prompt-grill-me:` use to
refine an artifact. Embedded here so callers have **no runtime dependency**;
technique adapted from mattpocock grill-me/grilling. Each caller cites this file and states its own
**depth** and **stage list**; this reference owns the mechanics, and derives the **rhythm** from the depth.

## Mechanics (both rhythms)

- For every question, give your **recommended answer**, so the user reacts to a proposal, not a blank prompt.
- **Fact-vs-decision split.** A **fact** is yours to find, never the user's: if the artifact, the code, the Jira export, or the filesystem can answer it, answer it yourself and never ask. A **decision** is the user's: put it to them and wait. Where the caller has a subagent for the lookup (`code-scanner`, `docs-grounder`, `jira-reader`), dispatch it rather than asking.
- **A running lookup blocks only what depends on it.** An unfinished exploration is an unsettled prerequisite for the questions downstream of it and for nothing else — ask everything else meanwhile. Never idle the interview waiting on a fact.
- **Force terminology precision.** When a term is overloaded or fuzzy (e.g. "user" vs. "buyer" vs. "payer"; "enable" vs. "install"), name the ambiguity and make the user pick a precise meaning before building on it.
- **Walk the decision tree in dependency order** — resolve a parent decision before the choices that depend on it.
- **The confirmation gate.** Reaching a shared understanding is the user's call to declare, not yours to infer from a quiet turn. The gate fires **wherever understanding is about to become an artifact or an irreversible step** — before writing a section, and again before a reviewer dispatch, a handoff, or a commit. It is therefore *not* a single end-of-interview event: a caller that authors its artifact section by section as the interview settles it (`create-vi:`, `create-ard:`, `design:`, `update-vi:`) closes the gate for each section as it goes, over the part that is settled, and the frontier keeps turning afterwards. Confirming a section is not confirming the whole design.

## Rhythm (follows the depth, never the caller's taste)

- **One question at a time** — used by the **bounded** callers. Ask exactly **ONE**; wait for the answer; then the next. A bound counted in questions is only enforceable one question at a time: a round can spend a ≤5 budget in its first breath, or be truncated mid-frontier, which leaves a settled parent with its children silently unasked — the precise failure the bound's `[NEEDS CLARIFICATION]` record exists to make visible.
- **Rounds** — used by the **relentless** callers. Map the design tree, then work the **frontier**: every decision whose prerequisites are already settled, i.e. the questions answerable *now* without guessing at answers you have not heard. Ask the whole frontier in one numbered round, then wait. Each set of answers reshapes the tree — settled decisions push the frontier outward and unblock what depended on them — so recompute the frontier and ask the next round. **A question whose answer depends on another question still open in this round belongs to a later round**, never this one; that rule is what keeps a round from being a batch. The interview is done when the frontier is empty. The confirmation gate above has by then fired once per section written; a final one covers the artifact as a whole.

Number the questions in a round so the user can answer them by reference:

```
❓ **Q1 — <question title>**: <question body; may run to several paragraphs, and may offer choices>

➡️ <your recommended answer>

---

❓ **Q2 — <question title>**: <question body>

➡️ <your recommended answer>
```

A caller that already puts a decision to the user through a `choices:` array keeps doing so — the array *is* the question body's choices; the numbering and the recommended answer are what this template adds.

## Autonomous / background invocation

When the command runs with **no human turn available** to answer (autonomous or background
invocation), do NOT fabricate answers to genuine **decision** questions. The fact-vs-decision split
still holds — facts you resolve yourself — but a genuine decision that would otherwise go to the user
is **recorded as an open question** rather than self-answered. Never grill yourself into a fabricated
decision. The confirmation gate cannot be self-satisfied either: with no human turn the understanding
is unconfirmed, and the caller reports it as such.

**Under the rounds rhythm, keep walking the tree anyway.** The frontier advances on *answers*, and
autonomously none arrive — so a literal reading would ask round 1, receive nothing, and stop, leaving
every decision below the first frontier never even generated, therefore never recorded. That is the
opposite of the intent. Instead treat each recorded open question as **provisionally settled for the
purpose of computing the next frontier**, and continue until the frontier is empty. The output is the
whole tree enumerated as open questions, which is what a human resuming the run needs; a single
first-round snapshot is not.

**Which notation is used is the artifact's choice, not the depth's.** Use whatever the caller's own
format authority defines: `[NEEDS CLARIFICATION]` for `idea.md` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md`)
— including under `--deep`, which changes the depth and the rhythm but never the file format — and `- [ ]`
for the VI / ARD / spec / design artifacts whose formats define it. Keying the notation on depth was a
defect: `idea: --deep` is the one caller whose depth changes at runtime, and writing `- [ ]` into an
`idea.md` would leave zero `[NEEDS CLARIFICATION]` markers, compute `status: refined`, and hand an idea
with unresolved decisions to `create-vi:`.

## Depth (the caller chooses; the rhythm follows)

- **Bounded** — a capped set of the highest Impact×Uncertainty questions, then stop; unresolved high-impact gaps are recorded (e.g. `[NEEDS CLARIFICATION]`). Rhythm: **one question at a time**. Used by `idea:` (≤10) and `prompt-grill-me:` (≤5).
- **Relentless** — keep walking the tree until convergence, no cap. Rhythm: **rounds**. Used by `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`.
- `idea: --deep` switches depth to relentless, and therefore switches rhythm to rounds with it. The two move together by construction: the cap is what one-at-a-time exists to enforce, so dropping the cap drops the reason.

## Ambiguity taxonomy (gap-categories, altitude-aware)

Categories the grill scans to *find* gaps — they feed the existing **Impact × Uncertainty** ranking of what to ask. In the rounds rhythm the ranking orders the questions **within** a round and nothing more: round membership is decided by dependency alone (`## Rhythm`), so ranking must never pull a question into an earlier round than its prerequisites allow — that is precisely the "guessing at answers you have not heard" the frontier rule forbids. Under rounds the ranking also stops being a *selection* device, because nothing is dropped; it decides presentation order only. Under the bounded rhythm it still selects, because there the cap means questions genuinely go unasked. This is **not** a user-facing menu and adds **no** mandatory questions: bounded callers still cap at their stated bound; relentless callers still stop at convergence. Scale the categories to the caller's altitude:

- **All altitudes:** overloaded/fuzzy **terminology**; **pre-mortem / assumption audit** (which unstated assumption, if wrong, breaks this?); **second-order effects** (what does this change downstream?).
- **Product altitude** (`idea:`, `create-vi:`): unstated **quality expectations** (implied latency, scale, availability, or compliance expectations) framed as product outcomes — not engineering NFRs.
- **Engineering altitude** (`specify:`, `design:`): the full **NFR** set (performance, scalability, reliability, observability, security/compliance); **integration / external-dependency** gaps; **implicit enum branch** (a field with N values where only some are specified — the rest are an untested branch).
