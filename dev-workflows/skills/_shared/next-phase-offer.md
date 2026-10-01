# Next-phase offer (embedded — shared reference)

The plugin-wide contract for the **next-phase offer**: the guidance every pipeline command
surfaces at the end of its run, naming the natural next command(s). Cited by all pipeline
commands so the routing graph and the offer rules live in ONE place (the same shape as
`emit-block` in `feedback-emission.md`).

## The offer contract (6 rules)

1. **Guidance-only** — the offer NAMES the next command(s); it NEVER auto-invokes anything.
2. **Role-labeled** — it names the concrete command(s) for the next step, tagged with the owning
   role (PM / PA / PE / Dev), even on a handoff — one person may wear several hats and just keep
   going. Never a bare "hand off to PA".
3. **Adaptive to outcome** — a clean run points forward; a BLOCK / incomplete / cancelled run
   recommends resolving THAT first, not advancing.
4. **Mode-aware** — the forward recommendation is a PIPELINE handoff. In a command's direct /
   ad-hoc mode (no VI/Epic context — `implement:` direct, `document:` doc-edit) it is OMITTED,
   not invented.
5. **Epic fan-out** — a command operating at **Epic scope** offers TWO branches:
   - **Depth** — the next command for the SAME Epic (`design: <VI> E1` → `implement: <VI> E1`).
   - **Breadth** — the SAME command for the NEXT Epic under the VI (`design: <VI> E1` →
     `design: <VI> E2`).

   So a team can go `design: E1 → design: E2 → implement: E1 → implement: E2` OR
   `design: E1 → implement: E1 → design: E2 …` — their call. Applies to the per-Epic commands
   only: `create-ard: <VI> <Epic>`, `specify: <VI> <Epic>`, `design: <VI> <Epic>`,
   `implement: <VI> <Epic>`. `document:` and `release-notes:` are VI-level (whole-feature, run
   once after ALL Epics are implemented) and do NOT fan out.
6. **Printed in this edition's invocation idiom** — every skill name the run PRINTS for the user to
   invoke is written `<name>:` (e.g. `release-notes: <VI>`). Slash-style `/<name>` does invoke the
   skill, but it can resolve to a Copilot built-in of the same name instead — Copilot's own
   `/release-notes`, `/upgrade`, and `/feedback` all collide today — so the slash
   form is NEVER printed. Narrative prose that describes the pipeline's shape to a reader of this
   edition's source may keep the short form — but ANY text that tells a reader what to type
   (usage blocks, example invocation tables, quick-starts, tips) is bound by this rule regardless
   of which file it appears in.

**A next-step offer that names a downstream command must also name the merge.** The downstream command executes `require-on-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §3) and stops while this phase's pull request is open, so an offer that reads "next: `create-ard: <KEY>`" without "once the pull request is merged" sends the user into a stop they were not warned about.

**And it must name it truthfully, which means the clause is never unconditional.** A run that staged nothing, or whose handoff the user declined, opened no pull request — and "once the pull request above is merged" then parks the operator waiting for a merge that will never happen, on a run they could often start immediately. The failing outcomes also differ from each other: only some have a branch to name. So an offer carries the clause as the placeholder **`<merge-clause>`**, resolved from the `Phase handoff:` line `phase-handoff.md` §4.1 actually emitted:

| §4.1 outcome | `<merge-clause>` resolves to |
|---|---|
| Committed, pushed, PR opened | `(once the pull request above is merged)` |
| PR already existed | `(once the pull request above is merged)` |
| PR not opened | `(once you open the pull request for <branch> and it is merged)` |
| Push failed | `(once <branch> is pushed, its pull request opened, and merged)` |
| No remote | `(once <branch> is merged into the default branch — this specs repo has no remote, so no pull request will do it)` |
| Nothing to commit | `(its inputs are already on the default branch — you can run it now)` |
| Declined by the user | `(once this run's artifacts reach the default branch — they are written but not there)` |
| Gate failed | `(once this run's artifacts reach the default branch — the handoff did not run)` |
| Anything else, or unresolvable | `(once this phase's artifacts are on the default branch)` |

`Branch name substituted` is an append to another line rather than an outcome of its own — whatever branch the emitted line ends up naming is the branch the clause names. **Three rows name a branch, and which three is the point**: the declined and gate-failed lines carry none, because on those paths `handoff-to-main` committed nothing, so there is no branch in existence to send anyone to — where *No remote* **does** commit, on a branch that nothing in that repository will ever push. The property is *committed something*; the catch-all is for a line that could not be read at all, never for an outcome §4.1 defines.

**Where the placeholder sits.** It never goes inside the code span that carries the command: every value it resolves to is a parenthesised English sentence, so a clause inside the command's span makes the one line an operator copies end in prose. In prose it takes a span of its own after the command's; in a `choices:` option it is plain text after the command and any role or `(Recommended)` label. It is a placeholder, not an instruction to reword an option, so an array carrying it is still presented verbatim per `escalation-rules.md`.

**Where this rule applies: every next-step offer this plugin prints that names a downstream command whose `require-on-main` gate the offering run feeds.** Six offers carry it — `idea:`'s *Handoff: adaptive next-phase offer* phase, `create-vi:`'s and `update-vi:`'s *Next steps* phases, `create-ard:`'s *Next-step offer (adaptive)* phase, and the `### Next step` sections of `specify:` and `design:`. Four of them hardcoded "until the pull request above is merged" on runs that reach outcomes opening no pull request; the fifth, `update-vi:`, named two downstream commands that gate this run's own VI and stated no wait at all; the sixth, `idea:`, recommended no next skill at all after a handoff, though `create-vi:`'s in-contract rung stops on the very `idea.md` whose pull request it had just opened. An offer that names a command waiting on nothing this run wrote — a sibling-Epic fan-out, `release-notes:` — carries no clause. Three of the six name the downstream command in prose rather than in a `choices:` option — `idea:`'s Phase 5 arrays are its handoff consent and Jira-key choices, not the route — which is the form a sweep for arrays does not see: read each command's own offer.

## Surface

The universal minimum is an adaptive **`### Next step`** section at the END of the command's
Final Report (guidance-only prose). A command MAY additionally present a richer interactive
`choices:` offer (the reference commands `idea:`, `create-vi:`, `create-ard:` do) — compatible,
not required.

**Filter before rendering a conditional offer.** When no forward route survives its artifact/outcome conditions, state that no applicable next step was found and omit the interactive picker; continue the skill's remaining housekeeping. Never ask only `Stop here` or `Stop here` plus `Other…`. Otherwise show every surviving route with the skill's native stop/free-text options; do not import Claude's four-option cap.

## The routing graph (role-aware)

**PM — ideation & framing**

- `idea:` — refined → `create-vi: <JIRA-KEY>` (PM); draft → `idea: @<path> --deep` (PM, refine)
  or `create-vi: <JIRA-KEY>` (PM, proceed on a draft — not recommended).
- `create-vi: <JIRA-KEY>` — after the paste-into-Jira + re-import round-trip:
  `release-notes: <VI>` (PM — draft the release note; recommended clear next step); hand to PA
  *(optional)* → `create-ard: <VI>`; or hand to PE → `epics: <VI>` (or `specify: <VI>`).
- `update-vi: <KEY>` — re-entry, not a linear node: reached when `create-vi:` redirects an existing-VI call, or when a later phase forces a VI refresh. After the paste-into-Jira + re-import round-trip it offers conditional re-runs of `release-notes: <VI>` (PM), `create-ard: <VI>` (PA), `epics: <VI>` (PE), and `specify: <VI>` (PE). Every route requires its downstream artifact to exist; changed dependencies are flagged and recommended first, and no surviving route means no picker.

**PA — architecture (optional)**

- `create-ard: <VI>` (VI-level) → PE → `epics: <VI>` (recommended) or `specify: <VI>`.
  *(No `design:` — no Epics yet.)*
- `create-ard: <VI> <Epic>` (Epic-level) → `specify: <VI> <Epic>` (recommended) or Dev →
  `design: <VI> <Epic>`.

**PE — breakdown & specification**

- `specify: <VI>` (VI-level spec) → `epics: <VI>`.
- `epics: <VI>` → `specify: <VI> <Epic>` (per Epic); optional PA → `create-ard: <VI> <Epic>`.
- `specify: <VI> <Epic>` (Epic-level spec) → Dev → `design: <VI> <Epic>`.

**Dev — build, verify & deliver**

- `design: <VI> <Epic>` → optionally `ready: <VI> <Epic>` (verify readiness) →
  `implement: <VI> <Epic>`.
- `ready: <VI> [<Epic>]` → **SUPPORTED** → `implement: <VI> [<Epic>]`; **PARTIAL / NOT-SUPPORTED**
  → resolve the named gaps + update the Jira status, then re-run `ready:`. *(Read-only verifier;
  not itself a linear pipeline node — an optional gate before build.)*
- `implement: <VI> <Epic>` → finish remaining Epics (breadth); once ALL Epics implemented →
  `document: <VI>` → `release-notes: <VI>`. *(Direct mode → no forward offer.)*
- `document: <VI>` (VI-level, after all Epics) → `release-notes: <VI>`. *(Doc-edit mode → no
  forward offer.)*
- `release-notes: <VI>` (VI-level) → leaf/closure: release note drafted; continue any pending
  PA/PE phase, else the VI is fully processed.

## Not pipeline nodes

`vuln:`, `upgrade:`, `feedback:`, `prompt:*`, `docs-profile:`, and the reviewer
commands are NOT part of the linear VI→docs pipeline and carry no next-phase offer.

## Session hygiene co-fires here

The `### Next step` this contract produces is immediately followed by a
`### Context hygiene` block (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`): the compact-vs-clear
choice reads the SAME role labels computed here (same role → `/compact`; role handoff →
`/clear`). This reference owns the role graph; `session-hygiene.md` only reads it.
