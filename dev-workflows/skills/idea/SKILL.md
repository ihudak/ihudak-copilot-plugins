---
name: idea
description: >
  Idea-refinement workflow (PM phase, front of the VI-creation flow). `idea: [<VI-KEY>] <source>` — the VI first — takes one source — an inline prompt, a markdown file (with wikilinks/images), a community post, or an imported Jira ticket (PRODFB product feedback, or an existing Value Increment the idea extends, parallels, or rewrites) — and, through a bounded one-question-at-a-time grill (--deep for relentless), authors a lean one-page idea.md that seeds the future create-vi:. Writes idea.md into its origin's feature folder under $SPECS_PATH — the PRODFB ticket's or the VI's — and never moves it; no Jira write, no code; on a completed handoff opens a pull request for it (`phase-handoff.md` §2).
  Activated when the user prompt starts with "idea:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Refine an idea into `idea.md`: the argument (text following the `idea:` trigger)

`idea:` is the **front door of the VI-creation flow** (PM phase) — upstream of `create-vi:` and
the existing pipeline. It ingests one source, refines it through a grill, and writes a lean one-page
`idea.md` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md`) that seeds the Value Increment. It is
**not** a VI: no Jira write, no code change. It writes `idea.md` straight into its origin's feature folder
under `$SPECS_PATH` — a PRODFB feedback ticket's, or the VI's (Phase 1) — and never moves it; `create-vi:` reads it there.

Flags: `--deep` switches the grill from bounded (≤10 questions) to relentless (until convergence).
`--no-docs` and `--no-prior-art` each turn off one grounding source (see Phase 1).
`--ground-code [<repo>[,<repo>…]]` grounds the idea against mounted code (see Phase 2.6) — bare it derives the repo set, with a value it scans exactly those repos. The token after `--ground-code` is its value **only** when it contains no whitespace and every comma-separated part matches a top-level directory basename under `${REPOS_PATH:-/workspace}`; otherwise the flag is bare and the token is idea text.

---

## Phase 0 — Validate environment + resolve model routing

**Run flags — before anything else in this phase.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. It returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill both `--skip-feedback` and `--enforce-model` apply. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

1. **Validate `$SPECS_PATH`.** **Where it is set, first** execute `specs-root-check` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §8): any signal is its `SPECS_PATH_INSIDE_TREE` hard stop, which sets `specs_git: misrooted`, offers no path to enter, and ends the run before anything below. Then it must be **set**, an **existing directory** holding one of `specs/`, `specifications/`, `vis/`, `ideas/`, and **writable** — `idea.md` is written into a feature folder there, never moved afterwards. If any check fails, STOP and offer:
   ```
   choices: ["Set SPECS_PATH (enter the path)", "Cancel", "Other… (describe)"]
   ```
   Validate an entered path the same way. **NEVER** write into the current working directory (it may be a code repo). This is an environment halt, **not** a plugin-gap halt — do NOT `emit-block`.

2. **Resolve model routing.** Load and follow the model-routing policy at
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then record:
   ```yaml
   model_routing:
     classification: MODERATE          # idea refinement is typically MODERATE
     reason: <one-line>
     current_model: <the model this orchestrator/grill is running under>
     enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
     defect_model: <§2.1 detection chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
     detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # idea-reader
     authoring_model: <= current_model>   # the interactive grill + idea.md authoring (session model, not a delegated subagent)
     opus_available: <true if a §2 Opus model resolved, else false>
     notes: <any §2/§2.1 fallback or degradation>
   ```
   The grill + authoring run inline on `current_model` (the §2 Opus chain — interactive judgment, not a
   delegated subagent). `idea-reader` runs on `detection_model`. If no Opus resolves, **degrade to the
   best available and record the degradation** in `notes` and the final report — do NOT hard-block (a PM
   must not be blocked from capturing an idea by a momentary Opus outage). A `--ground-code` run does
   **not** floor the classification at `SIGNIFICANT`: §1.1's multi-source floor is written for
   `implement:`, and §8.3's purpose — the strongest available model on synthesis — is already met
   here, because the grill and authoring run inline on `current_model` while the scanners run on
   `detection_model`.

**Specs-repo preflight.** Cite
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
and execute its `specs-preflight` entry point (§3) inline: flush any leftover session artifacts
from an earlier run, retry an artifact commit that failed to push, and settle the branch. Prompt-free, and silent unless it acts, a guard fires, or §3.1 reports a misconfigured `$SPECS_PATH`. If a guard fires,
emit its §5 notice; if it returns
`specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1), carry that flag for the whole
run — the terminal `commit-artifacts` step skips on it.

---

## Phase 1 — Classify the source

Classify the argument (text following the `idea:` trigger) **minus every recognised flag** (`--deep`, `--no-docs`, `--no-prior-art`, `--docs <path>` with its value, and `--ground-code` with its optional comma-separated repo value) by precedence. Strip them all before classifying: an unstripped flag lands inside the `prompt` branch's raw idea text and is handed to `idea-reader` as if the user had written it. The token after `--ground-code` is its value **only** when it contains no whitespace and every comma-separated part matches a top-level directory basename under `${REPOS_PATH:-/workspace}`; otherwise the flag is bare and the token is idea text — strip only the flag itself.

**The VI comes first.** The grammar is `idea: [<VI-KEY>] <source>`. When the first remaining token matches the Jira-key regex **and more tokens follow**, it is the Value Increment the idea is for — record it as `vi_key` — and everything after it is the source, classified by the rules below. A key anywhere else is part of the source: a prompt ending "see how we did it in PRODUCT-2345" names no target. When the first token is a key **and the only token**, it is the source itself and `vi_key` comes from the origin rule below (an existing VI is its own target; a PRODFB ticket has none yet).

**The grammar, by example** — carry this table verbatim in Phase 1 (it is the documented form; the docs page and changelog repeat it):

| You type | Meaning | `idea.md` goes to |
|---|---|---|
| `idea: PRODUCT-12345 <long prompt>` | an idea for that VI, from a prompt | `PRODUCT-12345…/` |
| `idea: PRODUCT-12345 @notes/thing.md` | the same, from a file | `PRODUCT-12345…/` |
| `idea: PRODFB-929` | customer feedback, no VI yet | `PRODFB-929…/` |
| `idea: PRODUCT-17753 PRODFB-929` | feedback, VI known | `PRODFB-929…/`, with `vi_key: PRODUCT-17753` |
| `idea: PRODUCT-12345` | rewrite of an existing VI | `PRODUCT-12345…/` |
| `idea: PRODUCT-NEW PRODUCT-OLD` | a new VI extending or paralleling an old one | `PRODUCT-NEW…/` |
| `idea: <prompt>` (no key) | stops and asks for the VI key | — |

**Validate `vi_key`.** When its import exists and its `issue_type` is not `ValueIncrement`, it is not a target: when the source is a key whose import *is* a `ValueIncrement` — the order typed the old way round, `idea: PRODFB-929 PRODUCT-17753` — say so in one line and swap them; otherwise ask `choices: ["Re-enter the VI key", "Cancel", "Other… (describe)"]` (a prompt with no VI key stops anyway, so reading the whole argument as one is no way out). When `vi_key` has no feature folder — a VI just created in Jira, a typo, a prompt that happens to open with a key, or a VI seen only inside another ticket's import — confirm before creating a folder for it; this fires whenever the origin rule below is about to create a folder, whether or not an import exists: `choices: ["Create <root>/<vi_key>-<candidate_slug>/ for this idea (Recommended)", "Re-enter the VI key", "Cancel", "Other… (describe)"]`. **An `rfe` source creates no folder for `vi_key`** — the idea goes into the PRODFB folder — so there is no array there, but an unresolved `vi_key` (no folder, no import) is still named in the one-line confirmation below, as "`<vi_key>` has no folder or import yet — recorded in `idea.md`'s frontmatter only", so a typo is caught before it is written.

`vi_key`'s import is found with `resolve-export-for-key <vi_key>`, and its feature folder by the **matching rule only** of `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md` § JiraID token, step 2 — an immediate child of `<spec-dirs>` named `<vi_key>` or starting `<vi_key>-` / `<vi_key>_`, case-insensitive. No match means no folder, and the folder is created after the confirmation above; step 2's *None* branch (the nested scan) does not apply, because `idea:` writes into a folder and never into another ticket's import. In the last array `<root>` is `$SPECS_PATH/specifications/` — a `vi_key` is a Value Increment, never a `PRODFB-` ticket, so it is where the importer puts it, and so a later import of `vi_key` lands in this folder rather than beside it — and `<candidate_slug>` is a kebab-case slug of the source's subject: for a key source (`PRODUCT-NEW PRODUCT-OLD`), its import's `summary`; for a prompt, its gist; for a file, its name. Phase 4 creates the folder under exactly the name confirmed here, and frontmatter `slug:` records that slug — `idea-reader`'s own `candidate_slug` does not override it.

1. Matches the Jira-key regex `^[A-Z][A-Z0-9_]*-\d+$` → resolve it with `resolve-export-for-key <KEY>`
   (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md`), then type it from the export's
   **`issue_type` frontmatter** — never from the project prefix, which is a coincidence of Jira
   configuration:
   - `ValueIncrement` → **vi** — an existing VI. Prior art the user supplied.
   - `Product Need` or `Account` → **rfe** — product feedback (a PRODFB ticket carries either type), handled as demand evidence exactly as today.
   - anything else → name the actual `issue_type` in the confirmation below and let the user choose;
     **default vi**, since a tracked delivery item is closer to prior art than to demand evidence.

   **Not imported.** `NOT_FOUND` from the entry point — the key has no import anywhere, whether it is the only token or follows a `vi_key` — takes Fallback B of `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md`, with `idea:`'s own array. Say in prose that the ticket has not been imported into the specs repo and give B's SPECS-mode import command, `SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>` in a `jira-workitem-import` checkout (its stock `runme.sh` unsets `SPECS_PATH` and writes elsewhere), then ask `choices: ["I've imported it — check again (Recommended)", "Re-enter the key", "Cancel", "Other… (describe)"]` — B's generic array offers a directory source and a direct-edit mode `idea:` does not have. On *check again*, resolve the key again from the top of this rule. An environment/user halt, never `emit-block`.
2. An existing `.md` path (absolute, or relative to the working directory) → **markdown** (a community post is just a markdown file — the reader tags it `community-post`; to re-refine an existing `idea.md`, re-run with the same keys — Phase 4's existing-file branch refines it in place). A leading `@` (`@notes/thing.md`, the file-mention form) is dropped before the path is tested.
3. Otherwise → **prompt** (the argument text is the raw idea).

**Resolve the origin folder (D1)** — once the type stands, which for a key that case A below asks about means after its answer. It is fixed here and never changes, and the key that names it is the run's **origin key** (the PRODFB key, or `vi_key`):
- **rfe** → the source key's own feature folder (the import created it), with `vi_key` recorded when one was given. No folder of its own — the ticket seen only inside another key's import — → rule 1's **Not imported** prompt, saying where it was seen (`<KEY>` appears in `<K>`'s import, but has no import of its own).
- **vi** as the only token → `vi_key` = the source key — a rewrite in place — and its folder resolves as in the next bullet.
- **vi** after a `vi_key`, **markdown**, **prompt** → `vi_key`'s feature folder; when none exists, create `<root>/<vi_key>-<candidate_slug>/` on the first write (after the confirmation above). **markdown/prompt with no `vi_key` → STOP**: an idea without a Jira origin needs the VI key it is for, typed first — `choices: ["Enter the VI key (create it in Jira first)", "Cancel", "Other… (describe)"]`.
Several folders matching one key → print every one as prose and ask which, in the run-time picker shape of `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md` (§ Fallback prompts, *Run-time pickers*): every folder plus "Cancel" — `ask_user` has no option cap in this edition. Mark and recommend the folder holding the key's import, per § JiraID token step 2. Show `idea.md → <origin folder>/idea.md` in the confirmation line.

**Confirm the classification — conditionally.** Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` ("When a choice list fires"), a list is shown only where the answer genuinely varies. Two cases here do; the rest do not.

**A — the key resolved but its `issue_type` is none of `ValueIncrement`, `Product Need`, `Account`.** Name the actual `issue_type` in prose beside the list, never inside an option:
```
choices: ["Read this as a vi — an existing Value Increment (Recommended)", "Read this as an rfe — product feedback", "Cancel", "Other… (describe)"]
```

**B — the argument is path-like (contains `/`, ends in `.md`, or starts with `@`) but resolved to no existing file.** Without this gate it falls through precedence rule 3 to **prompt** and the path string itself becomes the raw idea text — a mistyped path silently ingested as prose:
```
choices: ["Re-enter the path (Recommended)", "Read the argument as a prompt — the literal text is the idea", "Cancel", "Other… (describe)"]
```

**Everything else** — a `.md` path that resolves, a key typed `ValueIncrement`, `Product Need` or `Account`, and plain prose — is unambiguous. State the resolution in one line that invites correction and **proceed without waiting**; the list would have one plausible answer. (A dedicated `--as prompt|markdown|rfe|vi` override is future work — this inline confirmation covers a mis-detection.)

**Resolve documentation grounding here, then show its line.** Run `resolve-docs-grounding idea` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md` — its step 3.5 index prompt included — and show the `docs grounding:` line from what it returns, in the form that reference fixes — `ON <root> (retrieval: …)` or `OFF (<reason>)` — verbatim, including any index-build, staleness, or shadowing clause it carries (off switch: --no-docs). It runs here, before any agent is dispatched, because step 3.5 asks its one-time index question before the run's real work; this is the run's one resolution (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md`, *Invariants*), and Phase 2.5 dispatches on the state it returns without resolving again.

Show the `prior art:` line in the form `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/prior-art.md` resolved — `ON <specs-root>` or `OFF (<reason>)` — verbatim (off switch: --no-prior-art). Run `resolve-prior-art idea` per that reference to obtain it; it runs exactly once per run.

---

## Phase 2 — Ingest the source (idea-reader)

Dispatch `idea-reader` to read the source and return a structured digest:

→ task(agent_type: "dev-workflows:idea-reader", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Ingest this idea source and return the structured digest:
  >
  > argument:        [the source — the argument after vi_key, with any leading @ dropped]
  > provenance_hint: [prompt | markdown | community-post | rfe | vi from Phase 1]
  > vi_key:          [vi_key or null]"

Wait for the digest. If `status: NOT_FOUND` for a **markdown** source (the file could not be read), surface:
```
choices: ["Re-enter the source", "Cancel", "Other… (describe)"]
```
This is an environment/user halt — do NOT `emit-block`. A key source never takes this halt: Phase 1 resolved it or took its **Not imported** prompt, and a `NOT_FOUND` the reader still returns for a key goes back to that prompt. On `OK`, carry forward `raw_context`,
`stated_scope`, `signals`, `images`, `candidate_title`, `candidate_slug`, `source_refs`, `provenance`, `tracked` (a
`vi` source only), and the followed/broken wikilinks — `source_refs`/`provenance` feed the `sources:`
frontmatter entry in Phase 4, `tracked` seeds `## Prior art`, and `stated_scope` is the settled scope Phase 3 grills against.

---

## Phase 2.5 — Grounding: documentation + prior art (optional)

Dispatch both grounding agents **in a single response** so they run in parallel. Each is independent; either being OFF never suppresses the other.

**Docs.** Phase 1 resolved documentation grounding and showed its line; this phase resolves nothing again. Where it resolved `docs_grounding: ON`, `dispatch-docs-grounder` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md`) with `feature_summary` = the `idea-reader` digest's problem/outcome, `jira_key` = `vi_key` when set, else the origin key (the git-grep backstop matches the docs repo's commit messages, which cite delivery keys rather than feedback tickets), and `themes` = its signals. When OFF, skip silently.

**Prior art.** Using the `resolve-prior-art idea` result already obtained in Phase 1: when `prior_art: ON`, `dispatch-prior-art-finder` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/prior-art.md` with `specs_root:` = the resolved root, `exclude_dirs:` = the origin folder resolved in Phase 1 plus, for an `rfe` source with a `vi_key`, that VI's folder (when it has one), `feature_summary` = the same problem/outcome, `themes` = the digest's signals, and `known_refs` built from the reader's digest: every `wikilinks_followed` path and every filesystem-path `source_refs` ref as `{path, has_summary: true}` (`idea-reader` already summarised them), plus — for a `vi` source — `{jira_key: <KEY>, has_summary: true}`. Passing the key rather than a path is deliberate: the orchestrator does not know which feature folder holds that VI, and resolving it is the finder's job. The supplied VI is then classified and status-resolved by the same code path as a discovered one. When OFF, skip silently.

Carry both digests into Phase 3 with **grill-rank** consumption — challenges from the two compete together for the ≤10 question slots, they do not add slots. Carry the `vi` source's match into Phase 4.

---

## Phase 2.6 — Code grounding (optional)

Runs only when `--ground-code` was given; otherwise take the OFF branch at the end of this phase. Kept separate from Phase 2.5 because the repo gate needs a user answer (which cannot happen inside a parallel dispatch) and because the scan is two-round and therefore sequential.

**1. Resolve the repo set.** The token after `--ground-code` is its value **only** when it contains no whitespace and every comma-separated part matches a top-level directory basename under `${REPOS_PATH:-/workspace}`; otherwise the flag is bare and the token is idea text. Validate each resolved path is a directory; a repo that is not mounted is handled by the `Repo missing (after resolution)` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` — never invented, never silently dropped. A repo the user drops is carried to Phase 5 by name, with the themes it would have grounded left unverified. With `--ground-code <repo>[,<repo>…]`, use exactly those repos and skip the derivation below. Bare, derive them:

- **Cheap discovery.** List the top-level directories under each `${REPOS_PATH:-/workspace}` entry (may be colon-separated) with `ls`. Optionally attach each directory's one-line identity — `timeout 5 git -C <dir> remote get-url origin 2>/dev/null` (slug) or its README's first heading. Do **not** deep-scan to guess relevance.
- **Propose** a candidate set from the `idea-reader` digest's themes.
- **Gate** — this list's answer varies every run, so it fires unconditionally:
  ```
  choices: ["Ground the proposed set (Recommended)", "Ground a different set (you'll be prompted)", "Ground nothing — continue without a code scan", "Cancel", "Other… (describe)"]
  ```
- **Empty proposal — do not show that list.** When no theme matches any mounted repo its first option names a set that does not exist. Escalate instead per the `No repos derivable — epics:` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`. Every option in a shown list must name something that exists.
- **"Ground nothing — continue without a code scan"** ends this phase for the run: no scanner is dispatched, Phase 4 writes no `## Feasibility grounding` section, and the Final report shows `code grounding: declined at the repo gate` — distinct from `code grounding: off`, which means the flag was never given at all.

**2. Round 1 — broad.** Spawn `code-scanner` on the confirmed set in **batches of up to 4 concurrent agents per task message**, on `detection_model` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §8.3. For each repo in the batch:

→ task(agent_type: "dev-workflows:code-scanner", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):
  > "Scan this repo for the brief:
  >
  > repo_path:        <resolved absolute path>
  > capability_themes: <the idea's themes from the idea-reader digest>
  > context:          <3–5 sentences: the idea's problem + desired outcome, and what a finding would change>
  > search_hints:     <symbols/paths/keywords derived from the idea, if any>
  > refresh:          { switch_to_default_branch: false, pull: false }"

Handle every returned status through the list `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` already carries for it — `REPO_MISSING` → *Repo missing (after resolution)*. `prep.read_only: true` is **not** a failure: the scan ran at `prep.scanned_ref`; escalate per *Read-only mount — ref stale or diverged* **only** when `prep.ref_committed_at` is more than 14 days old or `prep.head_divergence.ahead > 0`, and cite evidence at `prep.scanned_ref` either way. With `switch_to_default_branch` and `pull` both false, every repo is scanned read-only as it stands, at `prep.scanned_ref`, without switching branches or pulling — `code-scanner`'s dirty-tree status is gated on `pull: true`, a condition never met here, so this scan never produces it.

**3. Round 2 — narrow.** Apply §8.5 of `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`: for each theme round 1 left **inconclusive** (`classification` `partial` / `absent` / `error`, or **two or more** scanners' per-theme `capability_map[].gap_summary` texts point at each other's repo in a cycle, or at a component/subsystem that no scanned repo covers), and for which round 1 produced at least one evidence anchor, dispatch `code-scanner` again with `capability_themes` holding exactly **one** question and `search_hints.paths` / `.symbols` / `.keywords` seeded from that round's verified `evidence[].path` and `.symbols`; where an evidence entry carries `lines`, name the anchor as `<path>:<line>` in the round-2 `context` prose, since `search_hints` has no line-number field. Round 2 reuses round 1's `refresh:` block verbatim — `switch_to_default_branch: false`, `pull: false` — so the read-only posture and that round's claim that `code-scanner`'s dirty-tree status is gated on `pull: true` and so is never produced here hold for both rounds. Cap **4 dispatches, one round only** — there is no round 3, and a theme still inconclusive is carried to Phase 4 as a `[NEEDS CLARIFICATION]`, never guessed at. A theme confirmed `absent` — by round 2, or by round 1 when no anchor existed to seed a round 2 — is a **resolved** finding: it belongs in Section 7's *What's missing*, not in Open questions. `[NEEDS CLARIFICATION]` is for a theme the scan could not settle — mutual deferral, or `error`.

**OFF branch** (no `--ground-code`). Run one detection and print at most one line. Tokenise the raw argument and the digest's `raw_context`; match tokens case-insensitively against the basenames of the **git repositories** (a `.git` entry present) directly under each `${REPOS_PATH:-/workspace}` entry, excluding `$DOCS_PATH` and `$SPECS_PATH`. Exact token match only — no substring, no stemming. On ≥1 match print:

```
This idea names <repo>; re-run with --ground-code to verify it against the code.
```

and **proceed without waiting** — an inline confirmation per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` ("When a choice list fires"), not a gate. No match ⇒ silent. There is no auto-trigger: grounding is a fan-out across every confirmed repo plus a second seeded round, and starts only on the user's explicit flag.

---

## Phase 3 — Refine via grill

**Interview technique (grilling — embedded; no runtime dependency).** Follow the shared technique in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/grilling-technique.md` — one question at a time, recommend each answer, fact-vs-decision split (look up facts from the `idea-reader` digest / the specs repo, put only decisions to the user), walk the design tree in dependency order, and clear the confirmation gate before writing. **Depth: bounded by default (below) — rhythm stays one-at-a-time, which is what makes the ≤10 bound enforceable; `--deep` = relentless, and switches the rhythm to rounds with it (`grilling-technique.md` `## Rhythm`).**

Scan for gaps against an idea-stage **ambiguity taxonomy**: *problem clarity, target users, desired
outcome/value, scope boundaries, evidence/demand sufficiency, success signal, terminology.* Rank gaps by **Impact × Uncertainty**, ranking every `docs_challenges` and `prior_art_challenges` entry from Phase 2.5 into that same list. Challenges **compete** for the slots below; they never add slots. **Code findings are facts, not questions.** A Phase 2.6 finding answers a gap rather than raising one — look it up, cite it, and do not spend a question on it. The one exception is the finding that **contradicts the idea's premise** (the capability already exists, or the gap is far smaller than the idea assumes): that becomes a challenge ranked into the same Impact × Uncertainty list, competing for a slot exactly like a `docs_challenges` or `prior_art_challenges` entry and never adding one. At most **2** such challenges.

**Source-stated scope is settled before the first question.** Seed the design tree with every `firm` entry of the Phase 2 `stated_scope` as an already-made decision (`grilling-technique.md`, "A decision the source already states is settled"). Those boundaries are not gaps and take no slot. A `tentative` entry is a gap: confirm it with its quote, recommending the source's position. Before putting any question, check its recommended answer **and its rationale** against `stated_scope`. A recommendation that argues from breadth, effort, or overlap the source has excluded (*"this spans cluster + ActiveGate + OneAgent"* when the source excludes ActiveGates) must be rewritten before it is shown. To argue that a stated boundary is wrong, raise that as an explicit challenge quoting it; it competes for a slot like any other challenge. Where a grounding digest (docs, prior art, code) describes a wider surface than the source scopes, that is context for the boundary, not a reason to widen it.

- **Default (bounded):** ask **≤10** questions across the ranked gaps, then stop. Remaining high-impact
  gaps become `- [NEEDS CLARIFICATION: <question>]` in the `idea.md` **Open questions & assumptions**
  section, **capped at 3**; reasonable defaults are recorded as `- **Assumption:** <text>`.
- **`--deep`:** relentless — switches the rhythm to **rounds** too (`grilling-technique.md` `## Depth`) and keeps walking the design tree until you and the user
  reach shared understanding; the cap does not apply.

---

## Phase 4 — Write idea.md

Author `idea.md` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md` into the origin folder resolved in Phase 1, applying the no-hard-wrap prose convention in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/prose-formatting.md`:

- **`## Prior art`:** write the section per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md` when
  Phase 2.5 returned any `prior_art` entry **or** the source is `vi`; omit it entirely otherwise. A `vi`
  source contributes its Phase 2 `tracked` block (key, status, summary) even when prior-art grounding is
  OFF — it is prior art the user handed over, not something the finder discovered — and appears there
  **and** in `sources:`. Merge by Jira key so a supplied VI the finder also matched yields one bullet: the finder's entry wins,
  because it adds `relation`, `match_reason`, and a feature-folder path to `tracked`. When the finder's status for it is `unknown`, keep the reader's `tracked` status instead — the finder found no import page, the reader read one. A
  finder match with `jira_key: null` cannot collide — a supplied VI always has a key.
- **`## Feasibility grounding`:** write the section per
  `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md` when Phase 2.6 ran **and** returned at least one
  finding; omit it entirely otherwise. Head it with each grounded repo as `<repo>@<scanned_ref>`; give
  every bullet a repo-qualified `<repo>/<path>:<line>` citation (the first entry of that evidence's
  `lines`, or `<repo>/<path>` when it has none); write a **Reframing** line only when a finding
  contradicted the idea's premise. A theme still inconclusive after round 2 becomes a
  `[NEEDS CLARIFICATION]` in **Open questions & assumptions**, never a hedged bullet.
- **Existing file:** if `idea.md` already exists in the origin folder, offer:
  ```
  choices: ["Refine the existing idea.md (Recommended)", "Replace it — start the brief over", "Cancel", "Other… (describe)"]
  ```
  On *refine*, re-open it, resolve its open `[NEEDS CLARIFICATION]` items, and append the new source
  (`{provenance, ref}` built from Phase 2's `provenance` and `source_refs`) to `sources`. **When this run has a `vi_key` and the file's frontmatter `vi_key` differs from it** (or is absent), say so in one line naming both, and ask `choices: ["Keep <the file's vi_key>", "Replace it with <this run's vi_key> (Recommended)", "Cancel", "Other… (describe)"]`; when this run has no `vi_key`, keep the file's without asking.
- **`## Rough scope` carries the source's boundaries.** Every `stated_scope` entry is written into **In** or **Out** as the source put it, unless the user reversed it during the grill, in which case write what they decided. The confirmation gate before this section names each source-stated boundary so a lost one is caught before it is written. A boundary is never dropped silently because the grill did not touch it.
- **Frontmatter `vi_key`:** write it when `vi_key` is set (`idea-format.md`). `create-vi:` finds a PRODFB-folder idea by it.
- **Frontmatter `slug`:** the slug Phase 1 confirmed when it created the folder; otherwise `idea-reader`'s `candidate_slug`.
- **`status`:** set frontmatter `status: refined` IFF zero `[NEEDS CLARIFICATION]` markers remain;
  otherwise `status: draft`.

---

## Phase 5 — Handoff: adaptive next-phase offer

Report where `idea.md` was written and its `status`, then offer the next phase — **adapted to status**:

- **`status: refined`** — present `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §4.3's **gated — falling back** array verbatim (`idea.md`'s one §3.4 row is `create-vi:`'s idea ladder, which falls back rather than stops), after that section's push-target probe: `choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git (the next phase does not stop on this, but until this is on main it might not read your copy)", "Cancel"]`. On the first choice, execute `handoff-to-main` (§2) with `prefix: idea`, `feature_folder` = the origin folder, `deliverable_paths` = `idea.md` — repo-relative, as `<origin folder>/idea.md` under `$SPECS_PATH` (e.g. `specifications/PRODFB-929-faster-trace-search/idea.md`), per §2.9 — `title: <origin key> Refine idea for <summary>`, `body_facts` = the idea's Problem/Goal one-liner, its `vi_key` (or "no VI yet"), and any open prior-art matches, then report the §4.1 outcome line. On the second or third choice (both decline it, §4.3 *What each option means*), report the §4.1 declined-outcome line with its falling-back `<next-phase-clause>`.
- **`status: draft`** (N open `[NEEDS CLARIFICATION]`) — **never hand off**, and do not ask. Report the N open items and offer `--deep` (`idea: <the same source and keys> --deep`), or the out-of-contract route (`create-vi: <VI-KEY> @<idea.md path>`, which will grill you on the rest). State explicitly that no branch or pull request was created.

**After a refined run's consent choice — whichever option was taken — recommend `create-vi:` `<merge-clause>`**, resolved from the `Phase handoff:` line §4.1 just emitted per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md`'s resolution table, never written unconditionally, and outside the command's code span:
- `idea.md` in a VI folder → `create-vi: <VI-KEY>`;
- a PRODFB-folder idea with `vi_key` → `create-vi: <vi_key>` (it finds the idea by `vi_key`);
- a PRODFB-folder idea without one → `create-vi: <VI-KEY> --idea <PRODFB-KEY>`, saying in prose that the VI is created in Jira first, and that linking it to the PRODFB ticket in Jira (*is caused by*) and importing the VI (`SPECS_PATH="$SPECS_PATH" python src/main.py <VI-KEY>`) lets `create-vi:` find the idea with no flag.

**The clause is load-bearing, not decoration**: `create-vi:` runs `require-on-main` on exactly this `idea.md`, so while the pull request this run just opened is still open it stops on rows D/E. **On a decline, or where §4.1's *Gate failed* line was emitted, also offer** `create-vi: <VI-KEY> @<the absolute path of idea.md>` — it reads the file where it sits, ungated, and does not wait for it to land.

Also report any prior art found — matched keys with their statuses.

Also report the code grounding when Phase 2.6 ran: the grounded repos with their `scanned_ref`s, any
repo descoped or unmounted with the themes left unverified, any theme still inconclusive after round 2,
and — first, because it is the most consequential thing a run can produce — the **Reframing** line if
one was written. A reframing that changed the idea's Problem section must not be reported only inside
the file.

`create-vi:` is a separate command; this offer is guidance the user acts on — it never auto-invokes
another command. (Per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md` — the plugin-wide
next-phase-offer contract; `idea:` is one reference implementation.)

### Context hygiene

Continuing to `create-vi:` (still the PM phase)? → run **`/compact`** to free context; your
`idea.md` is already on disk at `<origin folder>/idea.md`, under `<origin key>`. The resume pointer is
written in Phase 6 to `<origin folder>/dev-workflows/resume.md` — `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`
§1's tier 1, since the origin folder exists once `idea.md` is in it. No `/rename` label: `idea:` is outside
that reference's §4 rename-aid set, because the PM phase is short, not for want of a key. Guidance only — see
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`.

---

## Phase 6 — Session maintenance & feedback

Terminal phase — runs after Phase 5, NEVER interrupts an earlier phase.

**Capture-at-block invariant.** If an EARLIER phase **halts on a plugin / skill / command / reference
gap** (a capability the run needed but the plugin lacked), `emit-block` (per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) at that halt **before** escalating — so a run
abandoned at the block still records the gap. NEVER `emit-block` for an environment / user halt (bad
`$SPECS_PATH`, source-not-found, cancellation).

**Session-hygiene invariant.** End Phase 5 with a `### Context hygiene` note per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` — a same-role `/compact` suggestion naming the
origin key and folder (the `resume.md` write runs later, in step 3 below — this note prints the guidance
only; no `/rename`: short PM phase, §4). Guidance only, never auto-run.

1. **Invoke `impl-maintenance`** (agent_type: "dev-workflows:impl-maintenance", model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`):

   **Under `--skip-feedback`** (`run_flags.skip_feedback`, `_shared/run-flags.md` §4), this step dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance` — the same compact handoff, plus `Plugin root:` — on `run_flags.enforced_model` when set, else the `_shared/model-routing.md` §2.1 detection chain. Only when it returns at least one defect, persist them through `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, `feedback-emission.md` is not read at all. Report `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`. The in-session Lessons Learned report is what the flag costs. `emit-block` is unaffected and fires exactly as it would without the flag.
   > "Analyse this session and return a Lessons Learned report.
   >
   > Session handoff:
   > - Command run: idea:
   > - What was done: [one-paragraph summary of the idea refined + source type]
   > - Key events: [source-detection corrections, unresolved clarifications, broken wikilinks — or 'none']
   > - Workarounds used: [manual steps not automated by the workflow — or 'none']
   > - Review verdict: N/A (no reviewer in idea:)
   > - Test result: N/A (no tests in idea:)
   > - Project root: [the idea.md folder]"
2. **Persist plugin feedback (automatic).** Cite
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and call its `emit-auto` entry point (§6)
   with the Lessons Learned report, `command: idea:`, `jira_key` = the origin key, the run's `source`, and
   `plugin_version` (read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). It renders only the
   plugin-facing slice (§4), dedupes by stable `id` (§3), resolves the target via the §2 specs-first
   ladder — tier 1, `<origin folder>/dev-workflows/`, since the origin folder exists — and writes silently. Surface the persisted path (or "no plugin-facing signal — nothing
   persisted").
3. **Write the resume pointer.** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 and
   write/overwrite `<origin folder>/dev-workflows/resume.md` (its tier 1) now — after the feedback entry
   above, so the pointer reflects the completed run, and before the commit step below, so it is included
   in it. Omit the session-name line (`idea:` carries no `/rename`, §4) and redact per §1. Silent; the
   printed `### Context hygiene` guidance already appeared in the report.
4. **Commit session artifacts (terminal).** Cite
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`
   and execute its `commit-artifacts` entry point (§4) inline — the LAST action of the run. It stages
   ONLY the §2.1 bounded artifact paths inside `$SPECS_PATH`, commits
   `<origin key> Add dev-workflows session artifacts (idea:)`, and pushes. It NEVER touches a code/docs
   repo or the current working directory; NEVER force-pushes; NEVER fails the run; and skips entirely
   when the run carries `specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1, or §8's `specs-root-check` stop), re-emitting
   that notice. Hold its §6 outcome
   line for the Final report.

ADDITIVE — this phase NEVER fails the run, NEVER commits the deliverable (idea.md itself is handed off separately, before this phase, via `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2, behind Phase 5's §4.3 consent choice; the terminal step above commits only the bounded session-artifact paths in `$SPECS_PATH`), and NEVER writes into a code/docs repo or the current working directory; no user name is ever written.

---

## Final report

Report: the `idea.md` path + `status` (refined / draft with N open clarifications); the source type and
`sources`; the count of `[NEEDS CLARIFICATION]` items and Assumptions; the source-stated scope boundaries (`stated_scope`) and any the grill reversed, with the user's reason; any source-detection correction
or broken wikilinks; the resolved model routing (+ any Opus degradation); the feedback path; the
`Specs repo:` outcome line from `commit-artifacts`
(`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §6),
with any guard notice repeated in full; any prior art found (keys + statuses) and any
`notes` the finder returned; the origin folder and `vi_key` (or "no VI yet"); the code grounding outcome — the grounded
repos with their `scanned_ref`s, any descoped or inconclusive ones, and — first, because it is the most
consequential thing a run can produce — the **Reframing** line if one was written; or, when no scan ran,
`code grounding: off` (no `--ground-code`) or `code grounding: declined at the repo gate`
(`--ground-code` given, "Ground nothing" chosen); and the adaptive next-phase recommendation.
