---
name: create-vi
description: >
  VI-creation workflow (PM phase, sub-project 2 of the VI-creation flow). Turns a refined idea.md + a user-supplied JIRA-KEY into a high-quality Value Increment document (spine + adapt-in profiles: --lean|--hybrid|--full), authored via a relentless grill against _shared/vi-format.md, gated by the Opus vi-reviewer, written to $SPECS_PATH/specifications/<KEY>-<slug>/ and published to Jira by paste + re-import. Product-level (no code scan). Offers release-notes: and create-ard: as next steps.
  Activated when the user prompt starts with "create-vi:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Author a Value Increment for the Jira item: the argument (text following the `create-vi:` trigger)

`create-vi:` is **sub-project 2 of the VI-creation flow** (PM phase) — it consumes the `idea.md` from
`idea:` and a **user-supplied `JIRA-KEY`** (an empty Jira workitem the user created to get the ID) and
authors a high-quality **Value Increment** that feeds the downstream pipeline. The VI is **product-level**
(a PRD): what / why / for-whom, not how. Zero Jira API — the VI is authored as markdown in the specs
repo and published to Jira by paste + re-import.

Usage: `create-vi: <JIRA-KEY> [@idea.md] [--from-vi <VI-KEY|path>] [--lean|--hybrid|--full] [--no-docs | --docs <path>] [--no-prior-art]` (default `--hybrid`; `--no-docs` turns off documentation grounding, `--docs <path>` overrides `$DOCS_PATH` for this run, and `--no-prior-art` turns off vault prior-art grounding — see Phase 1).

---

## Phase 0 — Resolve inputs

**Run flags — before anything else in this phase.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. It returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill both `--skip-feedback` and `--enforce-model` apply. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

1. **`JIRA-KEY` (mandatory).** Strip every recognised flag first — `--from-vi <value>`, `--lean`/`--hybrid`/`--full`, `--no-docs`, `--docs <path>` (consumes the token after it), and `--no-prior-art` — so an unstripped flag or its value is never mistaken for the key or the `@idea.md` token. Parse the first remaining non-flag token; validate `^[A-Z][A-Z0-9_]*-\d+$`. If absent or malformed, **stop gracefully**: `CREATE_VI_NEEDS_KEY: create-vi: needs a Jira key — create an empty Jira workitem first to get the ID, then re-run 'create-vi: <KEY> @<idea.md>'.` (Format only — zero Jira API, so existence is not verified.)
2. **Profile.** `--lean | --hybrid | --full`; default `--hybrid`.
2a. **`--from-vi <VI-KEY|path>` (optional seed).** When present, this run authors a **new** VI (the positional `<JIRA-KEY>`) seeded read-only by another VI. Resolve the seed via `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vi-source-resolution.md` (`resolve-existing-vi` — Jira-import-first, 3-day freshness) for a key, or read the given path directly. The seed is **grounding, not content** (Phase 3 adapts it; it is never copied wholesale).

**Specs-repo preflight.** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` and execute its `specs-preflight` entry point (§3) inline: flush any leftover session artifacts from an earlier run, retry an artifact commit that failed to push, and settle the branch. Prompt-free and silent when the specs repo is clean and on its default branch. If a guard fires, emit its §5 notice; if it returns `specs_git: blocked` (§3.3 G0), carry that flag for the whole run — the terminal `commit-artifacts` step skips on it.

*(The preflight runs here, before the gate below, because `require-on-main` performs **no** `fetch` of its own — §3.2 — and relies on this step's best-effort one. Gating first would test never-fetched refs: a just-merged artifact would be missed on `origin/<default>` while the stale remote-tracking ref for its deleted branch still carries it, producing a false row D/E stop. `specs-preflight` self-gates on `$SPECS_PATH`, so it is safe this early.)*

3. **Resolve `idea.md` (ladder — stop at first hit):**
   1. **in-contract** — `specifications/<KEY>-<slug>/idea.md`, resolved from `<KEY>`. Execute `require-on-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §3) against it, mapping its §3.7 return value by `stopped` first, never by `on_main` alone. Any stopping state → stop per §4.4. Otherwise (`stopped: false`): on `pass`/`pass_amending`, use it — **do not relocate**, `idea:` already did; on `absent`, fall through to rung 2 — likewise on `unmanaged`: this ladder runs before step 4 validates `$SPECS_PATH`, so `unmanaged` (the §3.1 gate could not run) is reachable here, and it behaves as `absent` because there is nothing to verify; step 4 still stops immediately afterward on an unset `$SPECS_PATH`, so nothing is lost by not stopping here;
   2. **out-of-contract `@path`** — explicit `@path` argument; read the idea where it sits, **never move it**, and do not gate it. Report once: *"out-of-contract: reading `<path>` in place; it will not be relocated or gated."*;
   3. **same-session** — if `idea:` ran earlier in this session, use its recorded output path (confirm with the user) — out-of-contract, as rung 2;
   4. **discover** — `find "$VAULT_PATH/Projects" -type f -name idea.md` (recent first); if any, present a picker — out-of-contract, as rung 2;
   5. prompt for a path, or — last resort — proceed with **no idea** and grill the VI from scratch. **`idea:` is not a prerequisite for `create-vi:`** — an `absent` in-contract idea must reach this rung, never a stop.
4. **`$SPECS_PATH` (required).** If unset, stop naming `SPECS_PATH` (`choices: ["Set SPECS_PATH (enter the path)", "Cancel"]`).
5. **Feature folder.** `<SPECS_PATH>/specifications/<KEY>-<slug>/` — `<slug>` from the idea title (else a kebab of the VI summary). Honor an existing dir matched by key-number (tolerate a stray `-`/`_` and a human-adjusted slug). Auto-created by the first write (Phase 5).
6. **Prior VI (frontmatter-based).** Glob `<feature-folder>/<KEY>_*.md` and confirm frontmatter `issue_type: ValueIncrement` (tolerant of any slug). If a VI is found, this is an **existing VI** — `create-vi:` is greenfield-only, so **redirect** (see Phase 1) to `update-vi: <KEY>` unless `--from-vi` is present.

`create-vi:` is **cwd-agnostic** and needs **no repos mounted** (product-level; no code scan).

---

## Phase 1 — Configure

Use `choices` arrays; the last choice is always `"Other… (describe)"`.

1. **Confirm** the feature folder, the profile, and the resolved `idea.md` (or "none — grill from scratch").
   - **Resolve documentation grounding here, then show its line.** Run `resolve-docs-grounding create-vi` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md` — its step 3.5 index prompt included — and show the `docs grounding:` line from what it returns, in the form that reference fixes — `ON <root> (retrieval: …)` or `OFF (<reason>)` — verbatim, including any index-build, staleness, or shadowing clause it carries (off switch: --no-docs). It runs here, before any agent is dispatched, because step 3.5 asks its one-time index question before the run's real work; this is the run's one resolution (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md`, *Invariants*), and Phase 2.5 dispatches on the state it returns without resolving again.
   - Show the `prior art:` line in the form `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vault-prior-art.md` resolved — `ON <vault-root>` or `OFF (<reason>)` — verbatim (off switch: --no-prior-art). Run `resolve-prior-art create-vi` per that reference to obtain it; it runs exactly once per run.
2. **Existing-VI handling** (only if Phase 0 step 6 found a VI for `<KEY>`, frontmatter `issue_type: ValueIncrement`):
   - **No `--from-vi`** → `create-vi:` is greenfield-only; **redirect**:
     ```
     choices: ["Switch to update-vi: <KEY> to refresh it (Recommended)", "Overwrite as a fresh VI (archives the current one)", "Cancel", "Other… (describe)"]
     ```
   - **`--from-vi` present** → "create new (seeded)" conflicts with "a VI already exists here":
     ```
     choices: ["Update the existing <KEY> instead — update-vi: <KEY> (seed ignored) (Recommended)", "Overwrite <KEY> as a new seeded VI (archives the current one)", "Cancel", "Other… (describe)"]
     ```
3. **Draft idea → warn-and-fold.** If `idea.md` is `status: draft` (open `[NEEDS CLARIFICATION]`), note that the grill resolves those items — do **not** hard-block.

---

## Phase 1.5 — Classify + model routing

Load and follow the model-routing policy at
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then record:

```yaml
model_routing:
  classification: MODERATE        # typical; SIGNIFICANT for large/cross-cutting VIs
  reason: <one-line>
  current_model: <the model this orchestrator/grill is running under>
  enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
  defect_model: <§2.2 cheap chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
  detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # impl-maintenance
  review_model:    <§2.3 review tier>     # vi-reviewer (caller-pinned via `task(model:)`; recorded)
  authoring_model: <= current_model>   # the interactive grill + VI authoring (session model, not a delegated subagent)
  opus_available: <true if a §2 Opus model resolved, else false>
  notes: <any §2/§2.1 fallback or degradation>
```

The grill + authoring run inline on `current_model` (the §2 Opus chain — interactive judgment, not a delegated subagent). If no Opus resolves, **degrade to best-available + record** in `notes` and the final report — do not hard-block.

**Profile nudge (complex VIs).** If `classification` is **SIGNIFICANT** (a
complex / cross-cutting VI) and the chosen profile is `--lean` or `--hybrid`
(so `[FR#N]` is unavailable — it is full-only), surface a one-line **non-blocking**
recommendation before Phase 2:
> "This VI classifies SIGNIFICANT — consider `--full` so Functional Requirements
> (`[FR#N]`) and richer Use Cases (`[UC#N]`) are available for stronger, more
> traceable downstream Epic coverage."

Offer `choices: ["Switch to --full", "Keep <profile>", "Other… (describe)"]`. On
"Keep", proceed unchanged. For a SIMPLE / MODERATE classification, or when the
profile is already `--full`, this nudge does **not** fire.

---

## Phase 2 — Read the seed

Read the resolved `idea.md` **directly** (it is the plugin's own format — `idea-reader` is for arbitrary external sources and is not used here). Extract Problem / Who / desired outcome & value / rough scope / signals & evidence / candidate success signal, plus any open `[NEEDS CLARIFICATION]`. Carry the idea's `sources[]` forward to **propagate** into the VI frontmatter (the real provenance — each `sources` entry exactly as `idea.md` recorded it, `provenance` and `ref` alike), and record `derived_from` = the idea's own resolved path — read here from `idea.md`'s own frontmatter, never from a relocation, since `create-vi:` no longer moves it.

Optionally ground in the idea's cited sources and any strategy/vision docs the user points to. **No code scan; no repos.**

If `--from-vi` was resolved (Phase 0 step 2a), also read the **seed VI** (body + comments) as read-only grounding — structure, personas, scope shape, and metrics to *adapt* (never copy) to the new VI.

If there is no idea (Phase 0 ladder exhausted), grill the VI from scratch.

---

## Phase 2.5 — Grounding: documentation + vault prior art (optional)

Dispatch both grounding agents **in a single response** so they run in parallel. Each is independent; either being OFF never suppresses the other.

**Docs.** Phase 1 resolved documentation grounding and showed its line; this phase resolves nothing again. Where it resolved `docs_grounding: ON`, `dispatch-docs-grounder` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md`) with `feature_summary` = the idea's problem/goal + VI themes, `jira_key` = `<KEY>`, and `themes` from the idea. When OFF, skip silently.

**Prior art.** Using the `resolve-prior-art create-vi` result from Phase 1: when `prior_art: ON`, `dispatch-prior-art-finder` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vault-prior-art.md` with `feature_summary` = the idea's problem/goal, `themes` from the idea, and `known_refs` = every filesystem path in the idea's `sources[]` as `{path, …}`, every Jira key in `sources[]` as `{jira_key, …}`, and the Jira key of each `## Prior art` bullet as `{jira_key, …}` — all with `has_summary: false`, since this command reads `idea.md` directly and holds no summaries of its own. Take the **key**, not the wikilink, from a `## Prior art` bullet: a wikilink resolves by file name and dangles the moment a vault item is renamed, which is exactly why the bullet carries both. Recorded `sources[]` paths may dangle for the same reason; the finder drops what it cannot resolve. When OFF, skip silently.

Carry both digests into Phase 3 with **grill-rank** consumption. When both are OFF the VI is authored exactly as today.

---

## Phase 3 — Author via grill

**Interview technique (grilling — embedded; no runtime dependency).** Conduct a **relentless** interview per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/grilling-technique.md` — **rounds** rhythm (the relentless depth's, per that file's `## Rhythm`): map the design tree, ask the whole settled frontier as one numbered round, recompute from the answers, repeat until the frontier is empty. Recommend each answer, fact-vs-decision split (look up facts from the idea/sources; put only decisions to the user, and never idle a round on a lookup that only later questions depend on), and clear the confirmation gate before writing each section. Rank every `docs_challenges` and `prior_art_challenges` entry from Phase 2.5 into the grill's question order; a challenge competes for attention, it never suspends the spine below.

Author `<KEY>_<slug>.md` live against `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vi-format.md` for the selected profile, applying the no-hard-wrap prose convention in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/prose-formatting.md`. Walk the **spine** in dependency order:

1. Frontmatter — `relevant_for_release_notes` (defaults to `yes`; ask only to confirm a `no`); `sources` (propagated), `derived_from`, `seeded_from_vi` (only when `--from-vi` was used), `jira_key`. Do NOT ask for `release_versions`, `change_type`, or `release_notes_category` — they are Jira dropdowns the PM sets on the ticket and the importer returns on the round-trip (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vi-format.md`); `release-notes:` reads them from the import. Dates and deprecation details also stay out of frontmatter — they belong in the release-notes Summary.
2. **Problem**
3. **Goal** (crisp 2–3 sentences)
4. **Target audience** (personas)
5. **User Stories** (`[US#N]`)
6. **Acceptance Criteria** (`[AC#N]` per story)
7. **Scope** (In / Out)
8. **Success Metrics** (`[SM#N]`)

Then author the profile's **adapt-in clusters**, each **pulled only when the idea warrants it** (never an empty section). **For a complex VI (`classification` SIGNIFICANT), actively author the `[FR#N]` (full) and `[UC#N]` (hybrid/full) clusters** within the chosen profile — lower the bar for pulling them in, because ID'd functional requirements and use cases feed a finer downstream `epics:` `_coverage.md` (traceability to `[FR#N]`/`[UC#N]`, not only `US`/`AC`/`SM`); still never an empty section. Fold the idea's open `[NEEDS CLARIFICATION]` into the grill; resolve to zero where possible, leaving genuinely-unresolvable ones under `## Assumptions & open questions` (hybrid/full). Keep the VI **product-level** — no implementation detail. **Self-consistency check:** before writing each section, check it against the already-settled sections — a new `[AC#N]` must not deliver an Out-of-scope behaviour, the `## Goal` must not assert a scope the `## Scope` contradicts, and `[US#N]`s must not conflict. **Test every criterion against the `## Goal` too, not only against `## Scope` and its siblings** — an `[AC#N]` can be perfectly consistent with every other criterion and still defeat the outcome the VI was written to deliver, which no sibling comparison catches.

**Docs grounding is evidence about the status quo, never a requirement.** Where a criterion is derived from a `docs_challenges` entry or any other grounding digest, the documented behaviour describes **what the product does today**. A VI that exists to *change* that behaviour must state explicitly, per imported constraint, whether it is being **inherited or overridden** — importing one unexamined inverts the feature's own value. The measured case: a VI whose entire purpose was to let customers override default update behaviour transcribed the platform's documented version-pruning rule straight into an acceptance criterion, which then contradicted the Goal, a use case, and another criterion — the document retained a build it then refused to offer. Treat a documented rule as an input to the grill, and ask which side of it this VI is on. Resolve any contradiction inline with the user, or record it under `## Assumptions & open questions` — never leave it implicit (the `vi-reviewer` gate flags a silently-baked contradiction).

---

## Phase 3.5 — Dynatrace style check

Run a corporate style check on the authored VI **before** the review gate. This
is a **quality enhancement, not a gate** — it never blocks the handoff.
`vi-reviewer` (Phase 4) judges content; style / terminology is checked here
(mirrors `epics:` Phase 6.2).

→ task(agent_type: "dt-style-guide:dt-style-checker", model: <detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>):
  > "Run the style check for this brief:
  >
  > files:    [absolute path to <KEY>_<slug>.md]
  > doc_type: prd
  > emphasis: terminology and customer-facing captions, labels, messages, and text
  >
  > known_conventions:
  >   - the section headings mandated verbatim by `_shared/vi-format.md` and matched
  >     literally by `pre-lint.md`'s required-heading grep — sentence-casing them fails the
  >     plugin's own lint
  >   - the `&` in `## Use cases & user journey` and `## Assumptions & open questions`,
  >     mandated verbatim by `vi-format.md`'s adapt-in table and parsed literally by
  >     `jira-reader.md` on Jira re-import — expanding it to "and" breaks the round-trip
  >   - spaced em dashes, the house convention in every plugin-authored artifact in the
  >     specs repo
  >   - bracketed requirement IDs (`[AC#1]`, `[US#1]`, `[SM#1]`, `[UC#1]`, `[FR#1]`)
  >   - wikilinked tracker keys
  >   - this is an internal planning document, exempt from the trademark/(R) rule"

Act on the return:
- **`OK`** — proceed to Phase 4.
- **`VIOLATIONS_FOUND`** — the orchestrator/grill applies the **MAJOR** fixes
  **inline** (no delegated writer — consistent with Phase 4's inline-fix model),
  then re-runs `dt-style-checker` **once**. Remaining MINOR/NIT are recorded in
  the final report.
- **`ERROR`** — surface the reason and proceed to Phase 4 (non-gating).

If `dt-style-checker` is unavailable (agent not found — the `dt-style-guide`
plugin is not installed), **skip this phase gracefully** and note
`SKIPPED (dt-style-checker unavailable)` in the final report.

---

## Phase 3.6 — Structural pre-lint

Before the review gate, run the deterministic checks in
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/pre-lint.md` against the drafted `<KEY>_<slug>.md`: the
**Universal checks**, the **Jira-key collision** check (run on the VI body below the frontmatter),
and the **VI** block. Surface every finding; inline-fix the mechanical ones
(renumber a duplicate `[US#N]`/`[AC#N]`/`[SM#N]`, delete a stray placeholder token); leave content gaps
(missing section, unresolved `[NEEDS CLARIFICATION]`) for the grill/author. **Advisory** — never blocks;
proceed to Phase 4 once findings are surfaced. `vi-reviewer` remains the gate.

## Phase 4 — Review gate

Dispatch `vi-reviewer` (Opus, caller-pinned via `task(model:)`; recorded as `review_model`):

→ task(agent_type: "dev-workflows:vi-reviewer", model: <review_model — §2.3 review tier; under §10, run_flags.enforced_model>):
  > "Review the Value Increment:
  >
  > VI path: [absolute path to <KEY>_<slug>.md]
  > Profile: [lean | hybrid | full]"

Act on the verdict (mirrors `specify:`):
- **`BLOCK`** — fix the BLOCKER findings inline (the orchestrator/grill edits the VI — no delegated writer) and re-review **once**. If still `BLOCK`, escalate per the `Review verdict BLOCK` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` for each unresolved BLOCKER (`choices: ["Provide manual fix notes", "Defer to a follow-up issue", "Override and accept", "Cancel", "Other… (describe)"]`).
- **`MAJOR` / `MINOR` / `NIT`** (surfaced under `PASS WITH RECOMMENDATIONS`) — defer to the final report; no mandatory fix cycle.
- **`PASS` / `PASS WITH RECOMMENDATIONS`** — proceed. Cap: one fix cycle + one re-review.

**The recorded verdict names the version it was taken against** — where any edit followed it, the final report says so and names the edits, per the `A recorded verdict names the version it was taken against` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`. Where none did, it says that too.

---

## Phase 5 — Handoff

**Archive before overwrite (only when Phase 0 step 6 found an existing VI and Phase 1 step 2's
"Overwrite" choice was taken).** Before writing `<KEY>_<slug>.md`, archive the current canonical VI to
`<feature-folder>/revisions/<KEY>_<slug>_<YYYYMMDD>.md` — same naming and same-day suffixing as
`update-vi:` Phase 5 step 1 (`-2`, `-3`, … on a same-day second archive). A greenfield run (no prior VI
found in Phase 0) skips this step — there is nothing to archive.

Write the feature folder: `<KEY>_<slug>.md`. The in-contract `idea.md` is already there, committed by `idea:`; an out-of-contract idea stays where it is. Then **offer** (commit-when-asked — never automatic), presenting `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §4.3's **gated — falling back** array verbatim (every §3.4 row naming the VI falls back — `create-ard:` to the Jira export, `specify:` by skipping a confirmation), after that section's push-target probe:

```
choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase does not stop on this, but until this is on main it might not read your copy)", "Cancel"]
```

On the first choice, execute `handoff-to-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2) with `prefix: vi`, `feature_folder` as resolved in Phase 0, `deliverable_paths` = the VI file, `title: <KEY> Add Value Increment — <summary>`, and `body_facts` = the resolved profile (`--lean`/`--hybrid`/`--full`), the adapt-in clusters pulled, the user-story and acceptance-criteria counts, any `[NEEDS CLARIFICATION]` markers carried in, and the `vi-reviewer` verdict; emit its §4.1 outcome line in the Final report.

### Jira round-trip (document to the user — they will otherwise miss it)

1. **Paste** the VI body (below the frontmatter) into the Jira workitem `<KEY>`.
2. **Re-import** the VI into its feature folder — `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>` in a `jira-workitem-import` checkout (its stock `runme.sh` unsets `SPECS_PATH`) (via `https://github.com/ivan-gudak/jira-workitem-import`) so the downstream pipeline sees it.

Without these steps the pipeline cannot read the VI.

---

## Phase 6 — Next steps

Offer these — clearly labeling the role handoff:

```
choices: ["Draft the release note now — release-notes: <KEY> (PM) (Recommended)", "Hand to a Product Architect — create-ard: <KEY> (PA, optional) <merge-clause>", "Hand to a Product Engineer — epics: <KEY> (PE)", "Stop here", "Other… (describe)"]
```

- **`release-notes: <KEY>`** (PM) — draft the customer-facing release note now.
- **`create-ard: <KEY>`** (PA, **optional**) — hand to a Product Architect to author the grounded architecture document; it gates this VI on the specs repo's default branch (its own Phase 0), so it stops where this VI reached a branch and falls back to the Jira export — reported, never silently — where it reached none. `<merge-clause>` is the placeholder `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md` owns, resolved from this run's own `Phase handoff:` outcome line (§4.1) and never written as the unconditional "once the pull request above is merged": a declined handoff, a failed push and a nothing-to-commit run each leave a different wait, and two of them open no pull request to wait on. It is a placeholder, not an instruction to reword an option, so the array is still presented verbatim per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`.
- **`epics: <KEY>`** (PE) — hand to a Product Engineer to split the VI into Epics (or author a VI-level spec → `specify: <KEY>`).

Guidance only — never auto-invokes another command. Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md`.

### Context hygiene

The resume pointer is written in the terminal maintenance phase (Phase 7), per
`session-hygiene.md` §1 — and `create-vi:` is outside that reference's §4 rename-aid
set, so it **omits the session-name line**. Not for want of a key: Phase 0 refuses this
run without one. The PM phase is simply short enough that no label is auto-suggested;
name the session manually if useful. Then:

- **Continuing as PM (`release-notes: <VI>` after the round-trip)?** → run **`/compact`**.
- **Handing to PA (`create-ard: <VI>`) or PE (`epics: <VI>`), even yourself?** → run **`/clear`** for a clean slate.

Guidance only — nothing is auto-run. See `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`.

---

## Phase 7 — Session maintenance & feedback

Terminal phase — runs after Phase 6, NEVER interrupts an earlier phase.

**Capture-at-block invariant.** If an EARLIER phase **halts on a plugin / skill / command / reference gap** (a capability the run needed but the plugin lacked), `emit-block` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) at that halt **before** escalating. NEVER `emit-block` for an environment / user halt (missing key, unset `$SPECS_PATH`, cancellation) or a work-quality review BLOCK.

**Session-hygiene invariant.** End Phase 6 with a `### Context hygiene` block per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` — prepare-first (the
`resume.md` write runs later, as step 3 of this terminal phase, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 — this block prints
the guidance only),
then a span suggestion (PM continue → `/compact`; PA/PE handoff → `/clear`). No `/rename`
label — not for want of a key, since Phase 0 refuses this run without one, but because the
PM phase is short (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §4). Guidance only, never auto-run.

1. **Invoke `impl-maintenance`** (agent_type: "dev-workflows:impl-maintenance", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`) with a compact handoff: command `create-vi:`; what was authored (VI + profile); key events (source-ladder friction, unresolved clarifications, BLOCK reviews — or 'none'); workarounds; the `vi-reviewer` verdict; test result N/A; project root = the feature folder.

   **Under `--skip-feedback`** (`run_flags.skip_feedback`, `_shared/run-flags.md` §4), this step dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance` — the same compact handoff, plus `Plugin root:` — on `run_flags.enforced_model` when set, else the `_shared/model-routing.md` §2.2 cheap chain. Only when it returns at least one defect, persist them through `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, `feedback-emission.md` is not read at all. Report `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`. The in-session Lessons Learned report is what the flag costs. `emit-block` is unaffected and fires exactly as it would without the flag.
2. **Persist plugin feedback (automatic).** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and call its `emit-auto` entry point (§6) with the Lessons Learned report, `command: create-vi:`, the run's `jira_key`, `source`, and `plugin_version` (read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). Surface the persisted path (or "no plugin-facing signal — nothing persisted").
3. **Write the resume pointer.** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 and write/overwrite `<VI-dir>/dev-workflows/resume.md` now — after the feedback entry above, so the pointer reflects the completed run, and before the commit step below, so it is included in it. Redact per §1. Silent; the printed `### Context hygiene` guidance already appeared in the report.
4. **Commit session artifacts (terminal).** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` and execute its `commit-artifacts` entry point (§4) inline — the LAST action of the run. It stages ONLY the §2.1 bounded artifact paths inside `$SPECS_PATH`, commits `<KEY> Add dev-workflows session artifacts (create-vi:)` — or `NOISSUE …` when the Jira round-trip has not yet minted a key — with no `Co-Authored-By` trailer, and pushes to the branch this run's handoff phase created (§4.1). It NEVER touches a code repo, a docs repo, the vault, or the current working directory; NEVER force-pushes; NEVER fails the run; and skips entirely when the run carries `specs_git: blocked` (§3.3 G0), re-emitting that notice. Hold its §6 outcome line for the Final report.

ADDITIVE — this phase NEVER fails the run, NEVER commits the deliverable (git for the deliverable is offered only in Phase 5; the terminal step above commits only the bounded session-artifact paths in `$SPECS_PATH`), and NEVER writes into a code/docs repo or the current working directory; no user name is ever written.

---

## Final report

Report: the VI path + profile; US/AC/SM counts + which adapt-in clusters were included; open-question count; the `vi-reviewer` verdict; the Dynatrace style-check outcome (`OK` | `N fixed, M remaining` | `SKIPPED`); the `Phase handoff:` outcome line from `handoff-to-main` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §4.1); the Jira round-trip reminder; resolved model routing (+ any Opus degradation); the feedback path; the `Specs repo:` outcome line from `commit-artifacts` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §6), with any guard notice repeated in full; and the next-step recommendations.
