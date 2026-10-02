# Changelog

All notable changes to the **dev-workflows** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.
A section headed `— Unreleased` has not been published yet; where more than one of them stands, they all ship together in the next release.

## [2.35.0] — 2026-10-02

### Added
- **`code-review`'s spec/design-conformance dimension reports `exceeds`** — behaviour the change adds that no in-scope requirement and no plan step asks for, judged on the diff only. `MINOR`, or `MAJOR` where it builds what the specification's, the plan's or the design's `Out of scope` names; never escalated onto the spec by `implement:` step 7.5, listed in its Phase 5 report beside the other classes, and — where `MAJOR` — triaged and fixed like any other finding. Upstream spec-kit's converge (#4621) flags code that "exceeds" the stated intent; this plugin's July adoption left that class out without recording why.
- **At the grilling confirmation gate, the agent plays its understanding back** — the intended outcome, the constraints and what success looks like, marking what the user said and what was inferred — and asks for confirmation or correction. The play-back asks no decision, so it spends no slot of a bounded caller's cap. Adapted from superpowers' brainstorming skill. `docs/reference/references.md` describes the play-back.

### Changed
- **`risk-planner`'s step rule is "Unambiguous, not complete"**, replacing *No placeholders*. A step names the file it touches where it touches one, the exact signature of anything new, every value the spec or design pins quoted verbatim, and for a verification step the command and the output that means it passed; the self-review checks both for lines that decide nothing and for steps that write the implementer's code, plus a proportion check on `### Steps` alone. Upstream writing-plans withdrew the *"steps that say what without how"* wording this agent carried, measuring plans at a quarter of the time and a third of the tokens with no loss of planted-defect catches; the verbatim-constraint rule is from spec-kit's tasks template (#4430).
- **"design tree" is "decision tree" everywhere** — `grilling-technique.md` had contradicted itself, *"Walk the decision tree"* in Mechanics against *"Map the design tree"* in Rhythm, and its callers (`idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`) and their docs pages carried the old term, which collides with `design.md`.

### Fixed
- **`diff-summarizer` returned an empty diff for a merged PR on its local strategies.** Strategies 1 and 2 derived the base as `merge-base <target_branch> <head>`, which is `head` itself once the PR has merged — and the default filter takes merged PRs only. Both now test for a landed head and read the merge that landed it, intersecting `rev-list --first-parent` with `rev-list --ancestry-path` (the two flags in one call miss a PR merged through an intermediate branch); a fast-forward falls through to Strategy 3; and a range that changes no file, on any path, `gh` included, is never a resolution. Both also read the target as `origin/<target_branch>` wherever the local branch is absent or behind it: a stale local base read a merged PR as not landed and carried other PRs' work into the diff. Prompted by upstream superpowers' review-package fix for the same class (5bf4e780).
- **No local strategy stated its diff, and the `gh` path's was two-dot.** Strategy 3's *base = `<commit>^1`, head = `<commit>^2`*, read beside the `gh` path's explicit `<base>..<head>`, reads as a two-dot tree diff, which carries the target's own changes since the fork, reversed, as if the PR had made them. Every diff Strategies 1–3 and the `gh` path take is now `<base>...<head>`. Strategy 3 also reads a one-parent commit whose subject the primary pattern matches as a squash commit — never a revert, a body-only match or a title-keyword-only one — and never reads a title-keyword-only merge of the target into a branch as the PR; Strategy 4 skips a matched commit whose `show` prints no change, a Strategy 4 left with no other match counts as a failure, and its partial-resolution sentence widens to the new ways Strategies 1–3 can fail. The handoff's `PARTIAL` row now names the Strategy-4-only case the agent already returned it for.
- **`code-review` dimension 10 classified requirements against the diff alone.** A jira-driven `implement:` run's in-scope IDs are the whole Epic's, so a requirement an earlier run delivered was `missing` (`MAJOR`), sending `review-fixer` after work that existed and writing a spurious `- [ ]` note onto the spec. It now classifies against the code as it stands after the change, searching the codebase before calling anything `missing`, and treats plan tags, an Epic's done status in Jira and an earlier run's report as claims, not evidence.
- **`test-baseliner` could record a failing suite as passing.** Nothing forbade reading a suite's status through `| tail` or `| grep`, whose exit status is the filter's — and for a status-only suite that status is the whole result. Both modes now take the status from the suite's own command, and trim long output through a temp file outside the repository, since a file left in the tree would be swept into the run's commit.
- **The grilling confirmation gate could hold a run with no human turn indefinitely.** Its autonomous rule said only that the gate cannot be self-satisfied, while every caller clears it before writing. It now says the gate does not hold the write there: the caller writes on its recorded open questions and its final report says the understanding was never confirmed. After a section-by-section interview it also plays back once more over the whole artifact, only what changed, before the first reviewer dispatch, handoff or commit — rather than before each of them. `specify:` is named among the section-by-section callers, and `design:` clears the gate before each section.
- **`diff-summarizer`'s `gh` path fell back to `gh pr checkout`**, which switches the working tree, while the agent says that command is never run; a rejected direct-SHA fetch now fetches the PR's head ref (`pull/<pr_id>/head`) instead. **The strategies' placeholders were never mapped to the inputs** — `<target_branch>`, `<issue_key>`, `<title_keyword>`, and Strategy 4's `source_item`, which the inputs did not list; each is now named, and `source_item` is an input in the agent and its handoff. `counterpart-finder`'s summary of when the local strategies run names the new fallback paths.
- **`docs/skills/prompt-grill-me.md` said the specs-repo git guards were the only two hard checkpoints**, omitting the confirmation gate the skill runs before acting on the fix; it now names the gate and its play-back, which spends none of the five questions, and says `commit-artifacts` runs before the grill rather than at the end.

## [2.34.4] — 2026-10-02

Ported from the Claude edition's 2.65.4: `ai-workflows`' retirement of the Haiku-first chain for `defect-reporter` (`workflows-core` 1.9.1).

### Changed

- **`defect-reporter` runs on the §2.1 detection chain, the tier of the `impl-maintenance` it replaces, instead of a cheap chain headed by Haiku.** Under `--skip-feedback` it is the run's only post-session feedback capture (`emit-block` still fires on a halt), and its work is judgement: it applies the defect predicate and its exclusions, then tries to confirm the wrong line in the plugin's source. Haiku saved little on one dispatch per run. `model-routing.md` §2.2 is retired, its `defect-reporter` rule now sits in §2.1, and `defect_model` records a §2.1 resolution. Every skill's `--skip-feedback` dispatch, `run-flags.md` §4, `defect-reporter`'s description and `dev-workflows-shared.instructions.md` say the same.
- **`run-flags.md` §2 now carries the Haiku rows itself.** The `haiku` value used to resolve against `model-routing.md` §2.2; no chain there names Haiku any longer, so `--enforce-model=haiku` resolves exactly as before, against `run-flags.md` §2's own rows, which its family-only reachability rule now names for Haiku too. §2.2's number is not reused, so citations of §2.3 stay valid.

### Fixed

- **`implement:`, `ready:`, `upgrade:`, `vuln:` and `document:`'s direct mode dispatched `impl-maintenance` with no `model:`**, and `implement:`, `ready:` and `document:`'s direct mode dispatched the three maintenance agents beside it (Documentation, Knowledge base, Instructions) with none either, so all of them ran on whatever the session ran on, where every other skill pins them to the §2.1 detection chain as §9 requires. All of them are now pinned, and the `detection_model` comments of `implement:`, `ready:`, `upgrade:` and `vuln:` name them. `document:`'s direct mode also re-dispatched Agent 2 or 3 in Phase 4.5 without naming a model, and dispatched its Phase 2A exploration agent with none; the re-dispatch now reuses Phase 4's model, and the exploration agent is pinned to the §2.1 detection chain, as `implement:`'s Phase 2A exploration is. `docs/skills/upgrade.md` and `docs/skills/vuln.md` no longer list `impl-maintenance` among the agents those skills invoke by bare name, and `vuln.md` quotes `test-baseliner`'s dispatch as `vuln/SKILL.md` now words it.
- **`run-flags.md` §2's family-only rule named only "any older row" as refused**, leaving a version-specific id on no chain, and a Fable id, undefined there; it now refuses all three, as the Claude edition does.
- **`docs-profile:`'s `planning_model` line left out §2's Gemini floor**; it now ends at `gemini-3.1-pro-preview`, as §2 does.
- **`model-routing.md` §2.3 called `gpt-6-astra`'s lead a house preference and argued that Sol suited a review gate better**, which left the order open to re-ranking at a call site. It now states the rule the order follows: capability tier first, Astra above Sol, then the newer version within a tier. `docs/reference/model-routing.md` and `dev-workflows-shared.instructions.md` say the same.
- **`docs-profile:`'s `notes` example said synthesis fell back to `claude-sonnet-4.6`**, skipping the two newer Sonnet rows §2 tries first; it now names `claude-sonnet-5.5`.

## [2.34.3] — 2026-10-02

Ported from the Claude edition's 2.65.3: `ai-workflows`' fix for a `$SPECS_PATH` set inside the specs tree (its issue #70), adapted to this plugin's four specs directories, its Jira-key folder names and its shared Jira front-end. Not ported: that release's trailer fix, since this edition signs a deliverable commit as the fixed Copilot identity, and every part that touches the cost subsystem, which this edition does not have.

### Fixed

- **A `$SPECS_PATH` pointing at `specifications/` itself, at a mount of it, or at a folder inside it found no feature folder for any key, and a command that creates its folder then created `specifications/specifications/<KEY>-<slug>/`.** The existing refusal of a `$SPECS_PATH` holding no specs directory named the wrong cause, offered a per-run "enter the path" override, was not reached by a directory token, `create-vi:` or `update-vi:`, and passed for ever once any run had created a nested tree. `skills/_shared/specs-repo-git.md` gains §8, the `specs-root-check` entry point. `jira-input-resolution.md` runs it before either jira-driven branch, on a JiraID token and a directory token alike; `idea:` and `update-vi:` run it at their own `$SPECS_PATH` check, and `create-vi:` at a step of its own (Phase 0 step 1a) ahead of its `--from-vi` lookup, its idea ladder and its preflight. A path typed at any "Set SPECS_PATH (enter the path)" prompt is tested the same way before it is used. It tests two signals on the filesystem:
  - **(a) `$SPECS_PATH` is, or is inside, a `specifications/` or `ideas/` directory**: `git rev-parse --show-prefix` begins with one of them, whether or not a nested `specifications/` exists, or `$SPECS_PATH` is a directory of that name that is not a work tree's top level. `specs/` and `vis/` are left to (b): the plugin never creates a folder in them, and `<repo>/specs` is as often a specs root inside a larger repository.
  - **(b) `$SPECS_PATH` is, or directly holds, a feature folder**: a directory carrying a key — its import's `jira-import/<K>-index.md`, or a VI or `idea.md` whose `jira_key:` or `vi_key:` is `<K>` — and named `<K>`, `<K>-…` or `<K>_…`, the front-end's own folder-naming rule. The naming test is what keeps a correct root's templates, `README.md` or `docs/` from ever stopping a run; `$SPECS_PATH`'s own name is read physically, and a convenience link back into a specs directory is skipped. This is the signal for the case the original report met: a container mounting a host `SPECS_PATH` that names `<repo>/specifications` at `/workspace/specs`, which no repository prefix reaches.

  Either signal is a hard stop, `SPECS_PATH_INSIDE_TREE`, never a Fallback prompt, and offers no path to enter, since the wrong value lives in the environment. It names the value to set from a physical walk up to a specs directory in the same work tree (a `specs/` or `vis/` one only beside a `specifications/` or `ideas/`, and holding none of its own), says where that value is below its repository's top level that the layout is unsupported, and falls back to a stray-folder form or a two-readings form where no value can be established; a `specs/` or `vis/` `$SPECS_PATH` below its repository's top level that the walk does not accept is read both as a legacy specs directory in a dedicated specs repository and as a specs root. Where misrooted runs left a nested `specifications/` or `ideas/`, or a `dev-workflows-feedback/`, behind, a second line names each and where it belongs, and why it matters: a nested tree's bookkeeping, imports and drafts would be committed in the wrong place by the first run after the variable is fixed, and its folders are out of reach of the key-number folder match from the corrected root. The plugin moves nothing and gives no commands. §1's never-fatal rule says the stop is a deliberate refusal, not a git step failing.
- **A stopped or noticed run wrote its bookkeeping under the misplaced path.** The stop and §3.1's notices now set **`specs_git: misrooted`** for the whole run, as G0 sets `specs_git: blocked`. Under it feedback (`feedback-emission.md` §2), follow-ups (`followup-emission.md` §2, with a notice naming the flag) and `resume.md` (`session-hygiene.md` §1) fall to report-only; the preflight runs no guard and no flush, and switches no branch, though it still fetches and classifies, so `require-on-main` reads a fresh ref and row B still passes a resumed run (a row that would switch prints one line instead); `commit-artifacts` skips with the notice repeated and its own `Specs repo:` row; `phase-handoff.md` §2.1 refuses the handoff, §4.3 prints a line above the unchanged consent array saying so (on `specs_git: blocked` too), and row C offers no repair. Every command's preflight and terminal step names both flags.
- **`commit-artifacts` had two outcomes for one state.** A non-repository `$SPECS_PATH` where §8 finds a signal fails the environment gate and carries the flag; step 1 now tests the flags first, and the misrooted outcome takes precedence over the silent one.
- **`specs-preflight` passed `$SPECS_PATH=<repo>/specifications` silently on an ordinary checkout**, where git finds the repository above it, so a run that resolves no feature folder (`upgrade:`, `vuln:`, `implement:` on a direct prompt, `document:` in direct mode, the four logging commands) filed its bookkeeping inside `specifications/`. Where the gate passes, §3.1 now runs §8's tests and prints the stop's text as a notice. Its "not a repository" notice now names the cause where the path is a `specifications/` directory mounted on its own, and a `$SPECS_PATH` below its repository's top level draws a notice saying a specs tree inside a larger repository is unsupported, because the plugin switches branches and commits in that repository.
- **`require-on-main` read a bare `<ref>:<path>`**, which git resolves from the repository's top level, while its `diff` pathspec resolves from `$SPECS_PATH`; in a specs tree inside a larger repository a resumed run fell to row F and every divergence passed as row A. `phase-handoff.md` §3.2 now takes the path relative to `$SPECS_PATH` and reads `<ref>:./<path>`, and `design:`'s Epic-enumeration ref test does the same. In the supported layout both forms name the same object.
- **`ready:` had no reason for a row-C stop that offered no repair**, on a read-only specs mount before this release and now under `specs_git: misrooted` too: its mapping said row C's prompt had already run. It now has four ⚠ reasons, splitting row C on whether a repair was offered; Phase 3(a) greps a ⚠ artifact only where its file is on disk, tested per artifact, and Phase 3(b) cites Phase 1's list of reasons instead of counting them.
- **`release-notes:`, `epics:`, `document:` and `finish-and-handoff.md` said the terminal step commits their drafts, Epic drafts and archive copies** unconditionally; each now names the two flags under which it commits nothing and the draft stays written and uncommitted.
- **`specs-repo-git.md` §3.7 said G0 was "the only condition that disables the terminal commit"**, which the environment gate already falsified; it now says G0 is the one *guard* that does, and names the flag beside it.
- **The preflight step said it was "Prompt-free and silent when the specs repo is clean and on its default branch"** in seventeen skills, which a misconfigured `$SPECS_PATH` now falsifies; each takes §1 rule 7's wording instead.

### Fixed — documentation

- `docs/reference/environment.md` gains *When it points inside the specs tree*, and its *unreadable* paragraph says the non-repository notice names the misroot cause. `docs/getting-started.md` says to set `SPECS_PATH` to the root of a dedicated specs repository, never to `specifications/`. The session-feedback, follow-ups and resume pages say what a run carrying the flag does, and session-feedback places an unfiled entry at the top of `$SPECS_PATH` rather than "the specs-repo root". The `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:` and `ready:` pages name the stop, the `feedback:` page no longer says the preflight is silent on every clean repository on its default branch, and the references index names the new entry point. The `release-notes:` and `epics:` pages say a run carrying either flag commits no draft, the `feedback:` page that the preflight switches nothing on a misplaced `$SPECS_PATH`, and the root `README.md` where `SPECS_PATH` points. The `document:` page says a Jira-mode run stops on the misplaced variable, and the `release-notes:` page names the check beside its two specs-repo guards. `.github/instructions/dev-workflows-shared.instructions.md` names `specs-root-check` and the flag, calls detached HEAD the one blocking *guard*, and says the stop is not a never-fatal violation; the skill map says a run the check stops runs no preflight.

## [2.34.2] — 2026-10-02

Ported from the Claude edition's 2.65.2.

### Fixed — documentation

- **2.34.1's upgrade note gave advice that keeps G1 firing, and could delete a real idea.** It said to delete an `idea.md` an earlier `specify:` left. Where that file had overwritten a committed `idea:` file it is tracked and modified, and deleting it leaves a dirty deletion: G1 keeps firing, and `create-vi:`'s gate on the file stops on it. An untracked one, on the other hand, may be `idea:`'s own idea whose handoff was declined or, as a `status: draft`, never offered. The 2.34.1 entry now says to restore a modified file (`git -C "$SPECS_PATH" restore -- <folder>/idea.md`), to read an untracked one before deleting it, and how to tell them apart (`git status --short`).
- **`specify:`'s new rationale overstated three things.** The Jira import is in the tree, not necessarily committed yet (a fresh import is committed by the next preflight flush); `source-truth.md` lists `idea.md` under *Ignore* whenever a specification is provided rather than "stops treating it as authoritative"; and an uncommitted restatement is not taken for the idea by `create-vi:`'s ladder — a file on no ref falls through to the next rung — so the 2.34.1 entry no longer claims it was. The skill, its docs page, the skill-map instructions and the 2.34.1 entry now say so, and none of them assumes any `idea.md` already in the folder is `idea:`'s — one an earlier `specify:` left is never touched either.

## [2.34.1] — 2026-10-02

Ported from the Claude edition's 2.65.1, plus one Copilot-only fix.

### Fixed

**`specify:` overwrote `idea:`'s `idea.md`, and left its own uncommitted.** Phase 2 wrote an `idea.md` derived from the Jira text into the feature folder unconditionally. A broad VI-level spec's feature folder is the VI's own folder — the one `idea: <VI-KEY>` writes into — so `idea:` → `create-vi:` → `specify: <VI-KEY>`, taking the broad VI-level spec, silently replaced the idea the user had worked out. The file was also never in Phase 7's `deliverable_paths` and matches no `specs-repo-git.md` §2.1 shape, so it sat uncommitted and fired G1 on every later preflight. Nothing reads it legitimately: the Jira import it restated is in the tree under `jira-import/`, and `source-truth.md` lists `idea.md` under *Ignore* whenever a specification is provided — which the same run writes. **`specify:` now writes no `idea.md`**, and leaves one already in the folder untouched. **Upgrading** (corrected in 2.34.2): check any `idea.md` in a folder an earlier `specify:` ran on with `git -C "$SPECS_PATH" status --short -- <folder>/idea.md`. `M` (modified) means it overwrote a committed `idea:` file: `git -C "$SPECS_PATH" restore -- <folder>/idea.md` brings it back. Deleting it instead turns `M` into `D`, still a dirty path, so G1 keeps firing and `create-vi:`'s gate on that `idea.md` stops on it. `??` (untracked) is either `specify:`'s own Jira restatement or `idea:`'s idea whose handoff was declined or, as a `status: draft`, never offered — read it before deleting anything; only an `idea.md` inside a per-Epic subfolder is certainly `specify:`'s, since `idea:` never writes there. Where `specify:` replaced an uncommitted idea, the idea cannot be recovered.

- **The epic agents cited `epics:`' phases swapped** (Copilot only): `epic-reviewer` named Phase 6.1 as the style check and `epic-writer` named Phase 6.2 as the gate that routes coverage gaps. Phase 6.1 is clarifications and 6.2 the Dynatrace style check, as in the skill.
- **`create-ard:` with no Jira input stops** with `CREATE_ARD_NEEDS_JIRA`, as every other Jira-driven-only skill already did, instead of continuing with no `jira_key`; its docs page says so.
- **`jira-input-resolution.md`:** the several-folders picker no longer marks a row `(Recommended)` when it recommends nothing, and Fallback D's second option reads "Run without an Epic focus" — a directory root need not be a VI.
- **`code-repo-handoff.md` §5** pairs each repo with the reference that governs it: `$SPECS_PATH` with `specs-repo-git.md` and `phase-handoff.md`, a docs repo with `finish-and-handoff.md`.
- **Text:** `specs-repo-git.md` §2.1's comment column is aligned and its Sources line cites `skills/epics/SKILL.md` Phase 6 instead of the skill name; `jira-input-resolution.md`'s over-long lines are rewrapped.

## [2.34.0] — 2026-10-02

### Removed — `$VAULT_PATH`

**The plugin reads and writes one tree, `$SPECS_PATH`.** No skill, agent, reference, hook or documentation page reads `$VAULT_PATH` or names `jira-products/`. Ported from the Claude edition's 2.65.0 (the same design, applied to the Copilot skills).

- **Jira imports live in each feature folder** as `jira-import/` — `jira-workitem-import`'s SPECS mode (`SPECS_PATH="$SPECS_PATH" python src/main.py <KEY>`; its stock `runme.sh` unsets `SPECS_PATH`, so Fallback B prints that command rather than the script). A JiraID resolves to its feature folder's import, searched across every existing `{specs|specifications|vis|ideas}` directory (`<spec-dirs>`); a nested ticket resolves through its parent's import, and a ValueIncrement is never resolved as nested. An import is committed by the next run's `specs-preflight`. Inlined `## Comments` are skipped by `jira-reader` and read by `update-vi:`. Specs resolution never reads `jira-import/`, `epic-drafts/` or `dev-workflows/` as specs.
- **`idea:` writes `idea.md` into its origin's folder and never relocates it** — a PRODFB ticket's (`Product Need` or `Account`) or the VI's. The VI comes first — `idea: PRODUCT-17753 PRODFB-929`, `idea: PRODUCT-17753 <prompt>` — and lands as `vi_key` in the frontmatter; a key later in a prompt is prose. A source with no Jira origin needs a VI key; the old order (`idea: PRODFB-929 PRODUCT-17753`) is detected from the imports and swapped, a first key that is not a VI is asked about, and a VI key with no folder is confirmed before one is created. An un-imported source key stops with the import command and offers to check again. The run is keyed on its origin key: feedback and the resume pointer land in `<origin folder>/dev-workflows/`, and the artifact commit carries that key. The grammar, by example:

  | You type | Meaning | `idea.md` goes to |
  |---|---|---|
  | `idea: PRODUCT-12345 <long prompt>` | an idea for that VI, from a prompt | `PRODUCT-12345…/` |
  | `idea: PRODUCT-12345 @notes/thing.md` | the same, from a file | `PRODUCT-12345…/` |
  | `idea: PRODFB-929` | customer feedback, no VI yet | `PRODFB-929…/` |
  | `idea: PRODUCT-17753 PRODFB-929` | feedback, VI known | `PRODFB-929…/`, with `vi_key: PRODUCT-17753` |
  | `idea: PRODUCT-12345` | rewrite of an existing VI | `PRODUCT-12345…/` |
  | `idea: PRODUCT-NEW PRODUCT-OLD` | a new VI extending or paralleling an old one | `PRODUCT-NEW…/` |
  | `idea: <prompt>` (no key) | stops and asks for the VI key | — |

  The write-path gate, the container rule, `area_proposal`, `vi_disposition` and the mint-a-key offer are gone.
- **`create-vi:` finds the idea** by `--idea <KEY>`, its own folder, `vi_key`, the PRODFB tickets its import links, `@path`, or the same session. It also finds an idea that exists only on an unmerged `idea/*` branch, so it stops on `require-on-main` rows D/E instead of grilling from scratch. When several ideas match, the user is asked which one (or none) — the run never picks, and there is no multi-seed.
- **Prior art searches every feature folder under every `<spec-dirs>` directory** (`specs/`, `specifications/`, `vis/`, `ideas/`) and is renamed (`skills/_shared/prior-art.md`, agent `prior-art-finder`); status comes from each item's own import. It takes `exclude_dirs` — a list — and leaves those folders out of its hits: the run's own folder, and for an rfe idea with a VI or a `create-vi:` run seeded from another folder's idea, that other folder too. A supplied or followed reference still resolves to an excluded folder.
- **A PRODFB ticket's folder lives in `$SPECS_PATH/ideas/`.** The specs repo now holds `ideas/<PRODFB-ID>-<short-name>/` (one folder per product-feedback ticket, its `jira-import/` and its `idea.md`), and `jira-workitem-import` writes `PRODFB-` tickets there and every other ticket to `specifications/`, naming a new folder `<ID>-<slug>` from the ticket's summary. The plugin follows: `ideas/` joins `<spec-dirs>`, `specs-repo-git.md` §2.1's seven shapes and its step-2 classifier, every emitter's tier-1 folder match, `idea:`'s `$SPECS_PATH` check and the prior-art scope. Bare `<KEY>/` folders from earlier imports are still accepted, and the plugin never renames one. `idea:` still creates only VI folders (under `specifications/`); a PRODFB folder is the importer's to create.
- **A bare folder now gets tier 1 in every emitter.** Feedback, follow-up and resume pointers matched `<KEY>-<slug>` only, so a run whose folder was a bare `<KEY>/` fell to the keyless tier. They, and `release-notes:`' draft-phase lookup, now use `jira-input-resolution.md`'s folder-naming rule (the name equals `<KEY>` or begins `<KEY>-` or `<KEY>_`, in any `<spec-dirs>` directory); a handoff branch for a bare folder is `<prefix>/<KEY>`.
- **`create-vi:` finds an idea whose VI is linked to the PRODFB ticket only after importing the VI**, and says so; its lookup also reads the default branch's remote ref by content, because `specs-preflight` never pulls; several matching feature folders ask which one to use.
- **`idea:`** names an unresolved `vi_key` in its confirmation even when no folder is created, asks before replacing a different `vi_key` recorded in an existing `idea.md`, and keeps the reader's status for a prior-art match the finder could not status. To re-refine an `idea.md`, re-run with the same keys. `idea-reader` follows a ticket page's markdown links one level instead of wikilinks.
- **`document:` excludes the default `Doc screenshots/` folder in Phase 1**, before any image is placed in it, and the documented exclude path no longer carries the leading slash that made `git check-ignore` exit 128.
- **Everything that used the vault project folder uses the feature folder**: `document:`'s screenshot staging in `<project_dir>/Doc screenshots/` (`<project_dir>` is the parent of `jira_export_root` — the feature folder, or beside an import outside `$SPECS_PATH`; the default folder is kept out of `git status` through the specs repo's local exclude file, and nothing is staged under `jira-import/`), its image discovery, the implementation-gaps and pull-request drafts, `release-notes:`' non-VI destination; `epics:` drafts go to `<VI folder>/epic-drafts/` and are committed by `commit-artifacts`. Four new `specs-repo-git.md` §2.1 shapes (the Jira import, Epic drafts and two operator drafts) commit them.
- **The vault follow-up flow is deleted** (Obsidian-Tasks lines, tag index, project files, `Tasks.md`, `Journal.md`); follow-ups are a plain checklist in `<VI-dir>/dev-workflows/`. Feedback and resume pointers lose their vault tier.
- **`[[KEY]]` wikilinks in Epic drafts** are now described as the specs tree's required traceability form, not a link that has to resolve — the specs tree is a git repository, not a vault. The ID-grammar rationale names the Jira importer (`jira-workitem-import`) instead of "the vault importer".
- **The residual vault wording is gone** from every "never touches … the vault" list, the temp-file rules ("never the vault"), the `epics:` wording ("vault-internal", "drafts are vault/dir files", "writes into an Obsidian vault"), `document:`'s description of where the Jira hierarchy comes from, `specs-repo-git.md`, the root and plugin READMEs, the docs tree and the instruction files. `$VAULT_PATH` survives only in the root README, as the optional variable `obsidian-llm-wiki` uses.

### Fixed

- **`epics:`' commit sentence** no longer claims the run never commits the `jira-import/` tree, which `specs-repo-git.md` §2.1 and the Phase 8 text commit.
- **`epic-writer` refused the directory-input case `epics:` sends it**: its rule read "NEVER write outside `$VAULT_PATH`" while `epics:` wrote beside the import when `$VAULT_PATH` was unset. It now reads "NEVER write outside `output_dir`".
- **The preload hook told Jira skills they would "use `$VAULT_PATH`-based specs"**, which no skill did.
- **`doc-reviewer` was told to read `<vault_path>/jira-products/<JIRA_KEY>/`**, a path it no longer receives. It reads `jira_export_root`.

### Note for anyone who set `$VAULT_PATH`

Nothing deletes your vault files; the plugin stops reading them. Re-import each ticket you work on into `$SPECS_PATH`. Lost: the Obsidian-Tasks follow-up format, the vault project folder as a drop zone, and vault-wide `[[wikilink]]` resolution in `idea:` sources.

## [2.33.0] — 2026-10-01

### Added — five more `check-docs.sh` checks ported from `ai-workflows`

- **Check 10, identity quarantine**: no page under `docs/` may name this marketplace or its container repo, `getting-started.md` the single sanctioned exception. Fixed two real violations the check found: `dynatrace-docs-frontmatter.md` and `upgrade.md` both hardcoded the marketplace's install path (`~/.copilot/installed-plugins/<marketplace>/...`); both now link the shared files relatively (`../../skills/_shared/...`), as every other docs page does, so check 1 verifies the links resolve.
- **Check 11, merge-clause adoption**, adapted for this edition's `name:` colon-trigger convention (both the row-F caller column and a `choices:` option's command reference) alongside the Claude editions' `/name` and `/plugin:name` forms in the same shared extractor. Like ai-workflows' original it reads `choices:` arrays only, so a prose offer stays a review matter.
- **Check 12** is the former check 10 (choices arity) renumbered to align across editions; stays inert here (`HAS_CHOICE_CAP=0`, now declared explicitly in the edition-config block) since this edition's `ask_user` has no option cap.
- **Check 15, index membership**, adapted to this edition's `name:` triggers; fixed a real gap this check found: `docs/workflow.md`'s own intro prose omitted `dynatrace-docs-frontmatter:` from its list of diagram-exempt, non-pipeline skills even though the README already documents it as one. Only the sentence saying which skills are omitted is read for the exemption; the intro's mention of `idea:`, `document:` and `release-notes:` exempts none of them.
- **Check 17, dispatch authority**, adapted to this edition's bare, lower-case `tools: [..., task]` frontmatter and its own `task` (not `Task`) wording in the NEVER-dispatch anchor sentence; both forms are matched case-insensitively by one shared regex. All three task-carrying agents (`docs-style-checker`, `upgrade-executor`, `vuln-fixer`) already comply.
- **Check 18, published changelog**, scoped to `*/CHANGELOG.md` (this edition's plugins sit one level shallower than `plugins/*/CHANGELOG.md`), armed only by `ASSERT_PUBLISHED=1` — which `.github/workflows/validate-catalog.yml` now sets on pushes to `main` and nowhere else. This changelog's header now states the convention the check enforces.
- Checks 13, 14, 16 and 19 are deliberately not ported, for the same reasons as the Claude editions (vendor-neutrality and loader-contract checks this plugin's branding and single-plugin shape make inapplicable); the numbering gap is explained in `scripts/check-docs.sh`'s edition-config block.
- `--selftest` grew from 35 to 59 passing cases of 70 (11 skipped: 6 cost-only, 5 choices-arity).
- `.github/instructions/dev-workflows-shared.instructions.md` describes all fifteen checks.

### Added — the mermaid diagram gate

- **`scripts/mermaid/check-mermaid.mjs`, ported from ai-workflows as in the Claude editions**, finds every ```` ```mermaid ```` block in every tracked markdown file with a real CommonMark lexer and parses it with mermaid's own parser. CI now runs its `--selftest` and then `--root .` on every push; until now nothing here parsed a diagram, since check 15 reads diagrams only for which skills they name. The parser and lexer are pinned by exact version and a committed lockfile, and installed with `--ignore-scripts`. Every diagram in the tree parses. `.github/copilot-instructions.md` states the label-quoting rule; the evidence is in `docs/maintainers/rationale.md` § mermaid-gate.
- **`scripts/check-id-grammar.sh` no longer walks `scripts/mermaid/node_modules/`**, the git-ignored tree `npm ci` installs the gate's parser into, whose third-party markdown files a local run otherwise scanned. A selftest case pins the exclusion.

### Fixed — `idea:` names the merge before `create-vi:`

- **After either refined branch's §4.3 consent choice, `idea:` now recommends `create-vi: <KEY>` `<merge-clause>`**, ported from ai-workflows as in the Claude editions. It recommended no next skill at all after a handoff, though `create-vi:`'s Phase 0 rung 1 runs `require-on-main` on exactly the `idea.md` whose pull request `idea:` had just opened, and stops on rows D/E while that pull request is open. On a decline or a failed handoff it also offers `create-vi: <KEY> @<path>`: `create-vi: <KEY>` alone finds the relocated file on no ref and goes down an idea ladder whose discover rung searches the vault, not the specs folder the file was moved into.
- **`skills/_shared/next-phase-offer.md` names `idea:` as the sixth adopter**, so check 11 now examines `idea:`'s `choices:` arrays and its writer declaration, which names `idea.md` rather than "the relocated file". The recommendation itself is prose, which check 11 cannot see — like `specify:`'s and `design:`'s, it stays a review matter.
- **The third option of `idea:`'s §4.3 consent choice (*Cancel*) now reports the *Declined by the user* line**, as §4.3 says both declining options do; only the second did. `docs/skills/idea.md` describes the recommendation.

### Fixed — the repository's gates (not shipped in the plugin)

- **Check 11 read a handoff's declared paths past the `title:` token, to the end of the line.** This plugin writes the declaration on one long unwrapped line whose tail routinely names the deliverable again in prose — `idea:`'s ends "`idea.md` is relocated but not on the default branch" — so a declaration reworded to name no path still looked extractable. The span now ends at `title:`. Two selftest cases, one per bound of the span, each confirmed red against an extractor without that bound.
- **`scripts/validate-catalog.py` counted an instructions file's own path as a live `applyTo` match.** An instructions file is a real file, so a glob naming only itself — or two files naming only each other — passed, though such a file applies only while an instructions file is itself being edited, never during the work it governs. A match under `.github/instructions/` no longer counts, and the error says why.
- **Its `scripts/fixtures` exclusion matched the directory name at any depth**, hiding a manifest under any directory called `fixtures` from both directions of the advertisement check. It is now a root-anchored `SKIP_PREFIXES` entry, ported from ai-workflows, which also skips a git worktree copy at `.worktrees/` or `worktrees/`: with a worktree on an older release on disk the gate walked it and reported version drift against the main checkout (measured: 3 errors with a 2.29.0 worktree beside 2.32.0). The `applyTo` loop applies the same exclusion. `--selftest` 18 → 27: two anchoring pairs, four instructions-folder cases and a worktree-only glob, each confirmed red against the code it replaced.

## [2.32.0] — 2026-10-01

### Changed — `release-notes:` writes its draft into the VI's specs folder

- **The default destination is `<VI-dir>/<KEY>-release-notes.md` under `$SPECS_PATH`**, ported from the Claude edition 2.63.0: the VI folder first, the vault project folder where none exists (with the plan saying why), then the path beside the Jira export; never a newly created VI folder. The terminal `commit-artifacts` step commits it — `skills/_shared/specs-repo-git.md` §2.1 gains the single-file shape `<KEY>-release-notes.md` — and never through a branch or pull request. An existing draft there is archived by its last commit, or by a copy under `<VI-dir>/dev-workflows/release-notes/` that is committed too. The implementation-gaps draft stays in the vault.

### Fixed — found reviewing this release

- **Acceptance-criteria and code gaps about the same claim had nothing to match on.** Each discrepancy gap now carries a `claim_id`, the same in both kinds for the same claim, and the skill matches on it.
- **Two `model_routing` examples used the Claude edition's dashed ids** (`claude-opus-5-5`, `claude-sonnet-5-5`) beside this edition's own dotted rule; now `claude-opus-5.5` and `claude-sonnet-5.5`.
- **`implement:` called `code-review` an "Opus gate … never overridden"**, three lines below a routing block that puts it on the §2.3 review tier and lets §10 enforce a model. Now says both.
- The family map in `.github/instructions/dev-workflows-skill-map.instructions.md` names `vuln:`'s and `upgrade:`'s post-review `verify-resume` call; `hooks/test-notify.sh`'s Maven comment warns about hand-written fixtures; `.gitignore` ignores Python bytecode.

### Fixed — workflow contracts and diagrams

- `test-baseliner` accepts matching hinted and declared suite rows at verify, without requiring a detected marker-based suite. The moved-marker heuristic stays detected-only; unusable baselines still stop before execution.
- Release-note criteria contradictions carry draft-versus-criterion evidence and are resolved before code discrepancies. They no longer masquerade as Jira-versus-code gaps or create implementation-gap reports, and an omitted claim is not restored by the code handler.
- `update-vi:` filters its next-step routes before rendering and skips an empty picker while retaining terminal housekeeping. Nonempty menus keep every applicable route and Copilot's native stop/free-text choices, without importing Claude's four-option cap.
- qmd root coverage is independent of global vector counts. An uncovered docs root retains its consented build offer; missing tools, failed probes and local-index shadowing keep distinct fallback reasons. The one exception is an index with documents and **no collections at all**, where the offer stays but *Skip* is recommended and the build option warns it may re-embed what is already indexed (below).
- Workflow diagrams show conditional update routes, optional VI-specification input to Epics, tests written before review, post-review verification, model-gate override/enforcement paths, and specification choices that stop rather than continue the run. Keyword triggers and work/review model routing are preserved; no BRD or documentation-audit workflows are introduced.

### Added — six more test stacks, and the repository's own test command where none is detected

Written in the same change as `ai-workflows` `dev-workflows` 4.4.0 and the Claude edition; the agent body is the same in all three apart from each edition's command naming.

- **`test-baseliner` detects six more stacks: .NET, PHP, Scala (sbt), Elixir (Mix), Dart and Flutter, and C++ (CTest).** Each row was measured against the runner's own output before it was written — .NET SDK 10.0.401, PHPUnit 13.3.6 and Pest 5.2.1 on PHP 8.4.8, sbt 1.11.7 with ScalaTest 3.2.19 and MUnit 1.1.1, Elixir 1.20.4 and 1.18.4, Dart 3.13.5 with `package:test` 1.32.0, Flutter 3.47.5, CMake 4.4.3 — and six of the commands differ from what each tool's documentation would have produced:
  - .NET is one suite per test project, never per solution, because NUnit and MSTest print a test as its bare method name; the qualifier reads the project file for a test package because the MSTest template names only `MSTest`; and a `global.json` selecting Microsoft.Testing.Platform switches the command, since that runner rejects VSTest's `--logger` and exits 5 having run nothing while still printing `total: 0`.
  - PHP runs `vendor/bin/pest` where it exists — `phpunit` over a Pest suite exits 255 — and `--testdox`, which is what names each test.
  - sbt carries `NO_COLOR=1`, because MUnit colours piped output and ignores sbt's `-no-colors`, and reads two count lines, because sbt prints its own for MUnit and not for ScalaTest, which prints its own instead.
  - Mix carries `--trace`, the only way to have passing tests named, and reads both summary formats — Elixir 1.20 prints `Result: 3/4 passed (…)` where 1.18 printed `1 doctest, 4 tests, 1 failure`.
  - Dart asks for the `github` reporter, the one that prints a line per finished test; a Flutter package runs under `flutter test`, since `dart test` over one exits 65; and a package qualifies only with a `*_test.dart` file, since without one the runner exits 65 or 79 instead of reporting zero.
  - CTest builds the configured tree before running `ctest` and never configures one: measured, `ctest` over a stale tree reported `100% tests passed` where a rebuild reported `0%`.
- **Where nothing in the table qualifies, `test-baseliner` runs the test command the repository declares for itself** before returning `COMMAND_NOT_FOUND`. It reads the CI configuration — GitHub Actions, GitLab, CircleCI, Azure Pipelines, Bitbucket Pipelines, Jenkins — then `CONTRIBUTING.md` and `README.md`, stops at the first that yields a command, takes the one line of each step that runs the tests, and refuses a line carrying a CI expression, `sudo`, or an install, deploy or publish. Each is a `declared#<n>` suite, parsed with the table's row where its command names a runner the table knows, and every one carries a `CAVEAT: ` note naming its source. Declared-command discovery fires only during capture where the table matched nothing. Verification replays the captured command from the baseline rather than re-reading a file the change may have edited, and also runs any newly detected suites.

### Changed — with it

- **A suite whose output yields no count or no test name is recorded by its exit status** — one test, `exit status 0` — where it read `RUN_FAILED` with counts of 0 before. That is the `Make` row's best-effort case, a declared suite, and a `command_hint` naming no runner in the table. A `make test` printing no count pattern used to fail at capture, and supplying `make test` as the operator's command hit the same wall; and a suite with counts but no test names could lose every test without verify seeing it, since verify compares identifiers only. What the rule gives up is which test broke, and its note is marked.
- **`test-baseliner` prunes `deps/` and follows no symbolic link**: Mix fetches each dependency, with its own `mix.exs`, into `deps/`, and a Flutter application links each plugin into its platform directories, where two measured plugins would have qualified as suites of the repository.
- **A `Makefile` CMake generated is no `Make` marker**: its `test` target runs `ctest` without building, which is the stale-tree measurement above arriving through the wrapper rule.
- **A test identifier one suite prints more than once is a marked note**, since the lists record it once and a loss of one copy is masked by the other — ordinary on .NET, where two classes of one project naming a method alike print one bare name twice.
- `test-writer` treats a `hinted` or `declared` framework as a command rather than a runner: it writes against the conventions of the tests that command already runs, and writes nothing rather than inventing a framework where it finds none.
- The test-suite-detection page publishes the six rows, what was measured for each, the declared-command fallback and three more known limits: a suite recorded by exit status says that something broke but not what, Mix's `--trace` lifts per-test timeouts, and a test name printed twice is recorded once.

### Changed

- The §2.1 chain-head references in `/implement`, `/ready`, `/upgrade`, `/vuln` and `/design`, and the fallback chain on the model-routing docs page, name `claude-sonnet-5-5` — the current Sonnet, which no routing path could previously select.

### Changed — model routing splits by role

- **Anthropic models do the work; top OpenAI models review it.** `model-routing.md` §2 was one multi-vendor peer set for every reasoning-heavy step. It is now two tiers. **§2 is the work tier** — planning and planning critique, synthesis, delegated authoring, implementation, fixes — Anthropic-first: Opus 5.5 → 5 → 4.8 → 4.7 → 4.6 → 4.5, then Sonnet 5.5 → 5 → 4.6 → 4.5 → Gemini 3.1 Pro Preview as announced degradations. **New §2.3 is the review tier** — every gate that judges (`code-review`, `doc-reviewer`, and the VI, ARD, spec, design, Epic and readiness reviewers) — OpenAI-first: `gpt-6-astra` → `gpt-6.1-sol` → `gpt-6-sol` → the whole of §2. Two different models over one artifact catch more than one model looking twice, and a reviewer with no stake in the authoring is the point of a gate.
- **Row 4 is a documented branch, not a degradation.** A session with no version-6 GPT reachable reviews on Anthropic exactly as before, and the report does not call it a downgrade.
- **A review never prefers the session model.** The work tier does, as an economy — it avoids paying to switch when the session already qualifies. The review tier deliberately does not: a GPT-6 session and an Opus session both review on §2.3 row 1, because the whole purpose of the tier is that the reviewer is not the author.
- **`risk-planner` is on the work tier**, a deliberate boundary call recorded here so it is not silently moved: it produces a plan, and the split is that OpenAI critiques while Anthropic creates. Its two peer labels were retargeted to the work tier while the eight reviewers' sixteen were retargeted to the review tier.
- **The split is wired at the dispatch sites, not only declared in the policy.** All 21 places where a skill records or dispatches `review_model` now resolve it on §2.3, along with §9.2's role→chain row and §10's chain-resolution list; a first pass of this change edited the routing authority and the agents' descriptions but left every dispatch site reading `<§2 Opus chain>`, which would have kept reviews on Opus. The gate is also renamed where it was called by a model: 70 uses of "Opus review", "Opus code review", "Opus reviewer" and "Opus gate" across 24 files now say "review-tier", since a label naming a model the gate no longer runs on is a second, contradictory instruction. `design:`'s and `create-ard:`'s HARD gates are unchanged in behaviour — they already tested for an Opus *session*, which is the work tier and is what inline authoring runs on.
- `model_routing` gains `review_tier_vendor: openai | anthropic`, recording which branch of §2.3 the `review_model` came from, and `review_model`'s example is now a GPT-6 id.

### Fixed — the chains named model ids that do not exist

- **`gpt-5.6`, `gpt-5.5` and `gpt-5.4` appear in no current Copilot model list.** They sat in §2 as peer rows and at the floor of the §2.1 detection chain. The GPT-5.6 family is `gpt-5.6-<codename>` (Sol, Terra, Luna) — **there is no bare `gpt-5.6`** — and a chain row naming an id the harness does not offer fails its dispatch or silently falls through, the same class of defect as passing a full id to a parameter that accepts only families (§5). All three are gone: the detection chain now ends at `claude-sonnet-4.5` and carries no GPT row at all, since detection is work and work is Anthropic. Verified against GitHub's changelogs for GPT-6 Astra (2026-09-04), GPT-6 Sol and Luna (2026-09-22), GPT-6.1 Sol (2026-09-29) and the GPT-5.6 family (2026-07-09).
- **The §2.1 detection chain's inline labels in 13 skills were two generations stale**, reading `claude-sonnet-4.6, fallback claude-sonnet-4.5/gpt-5.4` — omitting Sonnet 5 entirely and ending in a non-existent id. All now read the real chain.
- `gpt-6-luna` and the `gpt-5.6-*` family are named as **reachable and deliberately unused**, with reasons, so their absence is not read as an oversight: Luna is its family's lowest-cost member and a review gate is the one place cost is subordinate to judgement, and the 5.6 family is superseded by a model GitHub measures as cheaper *and* better.

### Fixed — destructive revert, and a fix reported as verified

- **BLOCKER: `vuln-fixer` and `upgrade-executor` reverted a working change when the post-change verify could not run.** Both read `test-baseliner`'s `RUN_FAILED` at the **verify** step as grounds to revert and report `BUILD_FAILED`. Nothing was compared in that state — an unrunnable suite is a fact about the environment at both ends and says nothing about the change — so a completed security fix, or a completed upgrade, was destroyed on evidence that did not bear on it, and labelled with a build failure that had not happened (the build succeeded one step earlier). Both now keep the change and return `TESTS_NOT_RUN`; `PARTIAL` is incompleteness, not a verdict, and does not revert either. The two states that still revert are the two about the change itself. `vuln:` carries `TESTS_NOT_RUN` into `clean_finish: false`, so the fix is committed, offered for push, and its PR is a draft leading with DO-NOT-MERGE.
- **A fix nobody verified would have been reported as verified.** `vuln:`'s summary table showed only `OK` and `SKIP` in its examples and `upgrade:`'s showed `OK` in three of four rows, so an agent filling the cell by pattern-matching writes `OK` for a `TESTS_NOT_RUN` unit. Both vocabularies are now fixed in the skill, and **`OK` means the comparison happened and found no regression — nothing else earns it.**
- **`command_hint` never reached the verify call.** Now an optional input of both agents, passed through to the `capture` and the `verify`, including on a `verify-resume`. Dropping it either finishes a unit `TESTS_NOT_RUN` after the operator supplied a working command, or runs a different command at verify than at capture — every baseline test falls out as **Missing from run** and the verify reports a regression the run manufactured itself.

### Fixed — a recorded review verdict names the version it was taken against

- **The review cap stays, and the verdict now says what it covers.** The one-fix-cycle-plus-one-re-review cap assumes a fix cycle only removes defects. It does not: a fix applied after a review can introduce something a later review would find, and by then the budget is spent — so the run either ships a known defect or fixes it and leaves the final text unreviewed. Either way the verdict on record was reached against a version of the artifact that is no longer the one on disk, and nothing said so. `escalation-rules.md` now carries the rule, and the ten skills that record a review verdict (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `document:`, `implement:`, `vuln:`, `upgrade:`) cite it: where **any** edit followed a verdict, the final report says so and names the edits; where none did, it says that too. Ports `ai-workflows` `74311d6f` (2026-09-09), which earlier harvests missed.
- **Deliberately a reporting rule and not another review cycle**, for the reason upstream recorded: raising the cap trades one unreviewed version for a later one and has no fixed point. An outcome-keyed re-review loop was built on this branch first, across seven gates, and reverted: it replaced only the literal `Cap:` line, leaving each gate saying both "re-review once" and "not capped", and it contradicted a decision upstream had already made and explained. All seven gates are byte-identical to `main` again on that line.

### Fixed — `--enforce-model` was stated in Phase 0 and wired nowhere else

- **Every dispatch site now names the enforced model.** 2.31.0 added the flag to each skill's Phase 0 and to `model-routing.md` §10, but the dispatch lines still read `model: <detection_model — §2.1 detection chain>` and nothing else, and the `model_routing` blocks had no `enforced_model` field to record. In the 14 skills the flag applies to: 16 `model_routing` blocks record `enforced_model` (and the 15 in `--skip-feedback` skills record `defect_model`), 66 `model:` dispatch arguments name it as the §10 alternative to their chain, 16 "no override" statements carry the §10 exception, and a Phase 0 clause covers the dispatches whose line shows no `model:` argument at all.
- **A nested dispatch is pinned.** Three agents dispatch another agent — `vuln-fixer` and `upgrade-executor` (→ `test-baseliner`), `docs-style-checker` (→ `dt-style-checker`) — and none passed a model, so the nested step inherited whatever the agent ran on and an enforced run was silently not enforced there. Each now takes `enforced_model` in its handoff and passes it on, and otherwise pins the nested dispatch to the §2.1 detection chain. `vuln:` and `upgrade:` re-supply the field on every resume; `document:` passes it in both modes.
- **`feedback:` was in the `--enforce-model` set by accident.** The maintainer recipe was `grep -l 'model-routing'`, and that bare word is also a feedback *category* named in `feedback:`'s body — so a skill that dispatches nothing was counted as routed, its Phase 0 validated the value, and a bad `$WORKFLOWS_ENFORCE_MODEL` stopped it. The recipe and the runtime test now name the file `_shared/model-routing.md` (14 skills, not 15); `feedback:` is back to parsing no run flags, like the three `prompt` skills; and the free-text list in `run-flags.md` §3 names only the three prose-taking skills that actually strip.

### Fixed — an audit of upstream's fix history, ported from the Claude edition

Every fix commit upstream made since 2026-08-20 was given a disposition against the Claude edition, and what was needed there was then carried here. Nothing in this section depends on anything this edition lacks.

**Test baseline — `implement:`, `vuln:`, `upgrade:`**

- **A polyglot repository was baselined on whichever stack sat first in a five-row list.** A Java suite beside an Angular one, or a Rails suite beside a JavaScript one, got a baseline from one of them, and a green verify said nothing about the other; Go, Cargo and Xcode had no row at all. `test-baseliner` and its handoff are now upstream's: every marker is collected and qualified, every suite that qualifies runs from its own directory under its own ten-minute bound, identifiers carry their suite's prefix, and the return reports per suite — eleven rows over fourteen markers. A run where some suites produced counts and some did not is `PARTIAL`, and a note whose harm the `Status` cannot show opens with `CAVEAT: `. `implement:` records both in Deferred items, `vuln:`'s summary table gains a `Notes` column, `upgrade:`'s summary gains `Not verified:` and `Caveats:` lines. New page: `docs/reference/test-suite-detection.md`.
- **A test command the operator supplied went nowhere.** `implement:` asked *Specify test command* after the edits; `test-baseliner` took no `command_hint`, no dispatch carried one, and the baseline it would have been compared with had captured nothing. The question moves to Pre-Phase 3.5, where a baseline can still be taken, and the answer is carried as `command_hint` on every later dispatch. A skip drops the tests only — lint and build still run. Two failed commands record the skip as the run's own, which finishes `clean_finish: false`.
- **A verify against a baseline that captured nothing returned `OK`.** With no passing test recorded, nothing could regress or go missing, so a runner the change itself repaired produced a green comparison that never happened. Verify now refuses such a baseline before running anything.
- **A test added since the baseline and already failing moved no `Status`.** `OK` was reachable over a red test. `implement:` sends it to the fix loop; `vuln-fixer` and `upgrade-executor` mark each `NEW-FAILURE: ` and both commands finish `clean_finish: false` on it.
- **`vuln:` took opposite dispositions on the same failed capture, against risk.** A `MODERATE` CVE was abandoned (`BASELINE_FAILED`) while a `HIGH-RISK` one was applied and pushed. One capture now runs at the orchestrator for both paths, and a dead one is put to the operator before anything is branched: supply a command, apply unverified, or cancel. `baseline_tests: run-fresh` and `BASELINE_FAILED` are retired. `upgrade:` asks the same question.
- **`upgrade:`'s `clean_finish` omitted `TESTS_NOT_RUN`** while `code-repo-handoff.md` §2.9 named it for that command, so a batch nothing verified opened an ordinary pull request.
- **`implement:` read an unrunnable suite as a pass.** Phase 3.5 branched on regressions only; `RUN_FAILED` and `COMMAND_NOT_FOUND` now stop for a decision, and an accepted unverified run is not a clean finish.
- **`vuln:`'s gated path had no instruction for a first-call return that is neither `BLOCKED` nor `AWAITING_REVIEW`** (`BUILD_FAILED`), and no resume named `repo:`, which verify takes its root from.

**Git and shell**

- **Git calls ran in the wrong repository or the wrong form.** `code-scanner` and `diff-summarizer` ran bare `git` in the session's directory; `document:` Phase 6.2 and Phase 8.5 did the same; `git switch origin/<name>` exits 128. Every call is `git -C`, and a switch takes the branch name while a read may take the ref (`read-only-repos.md` §3). Vale and its scratch directory run as `builtin cd … && command vale`, `command mktemp`, `command rm`, since the shell carries the user's aliases.
- **The specs-repo git authorities were a month behind upstream.** `--porcelain -z`, so a path with a space or a non-ASCII byte is staged; a dangling `origin/HEAD`; `<default-ref>`; an unevaluable `@{u}`; an eleven-state `require-on-main` gate; a push-target probe before the consent array; *account for every declared path*; an existing-pull-request probe; the host kept for a non-github.com remote. `phase-handoff.md` gains §4.0's four downstream classes and one consent array per class, presented by all eight producers.

**Claims a run could not keep**

- **A push, a pull request, a merge to wait for.** `vuln:`, `upgrade:`, `implement:` and four docs pages asserted a push and a draft pull request outright; both sit behind §2.4's consent choice, and three sections end with no pull request. §2.4's re-ask trigger is symmetric, and `vuln:`'s *"asked on the first CVE and reused"* now carries it.
- **Five next-step offers hardcoded "until the pull request above is merged"** on runs that reach a declined, a push-failed and a nothing-to-commit outcome. They carry `<merge-clause>`, resolved from the run's own `Phase handoff:` line; `next-phase-offer.md` owns the table. `create-ard:` also said `specify:` "architects without" an unmerged ARD — it stops.

**`document:` and `docs-profile:`**

- **The profile had two homes.** `docs-profile:` wrote it at the git top level; `document:` looked in the resolved directory. With the site below the top level every run re-profiled and waited for a file written elsewhere. `document:` takes the resolved directory to its top level; the squash base is the commit profiling hands back, never a `git log --diff-filter=A` lookup; the rename names the old branch.
- **An inline run switched onto a bootstrap branch an earlier run left behind**, and `document:` renamed it into the docs branch. It stops at Phase 0 with `DOCS_PROFILE_BOOTSTRAP_BRANCH_EXISTS`.
- **A refresh rewrote what its scan could not see.** It now builds from the existing profile, changes only where detection found evidence, and *Keep existing, write nothing* writes nothing.
- **Direct mode resolved its toolchain against cwd, not the repository it edits**, and ran its style check there. An ambiguous image policy is settled with the user before the writer runs.
- **A monorepo's site keeps its Vale configuration and lockfile beside itself.** `docs-style-checker` and the toolchain preflight look there first.
- **Render verification.** A build tool that would not run was offered as a skip before its registered fallback was tested; a content `FAILED` could sit behind a skip; a 404 was a render defect in one list and a route miss in the next; `ci_still_checks` promised a CI check the repository may not run; the smoke check booted a server whose tool was missing and waited out the timeout.

**Model routing**

- **Five `release-notes:` dispatches and two in `document:` direct mode carried no tier**, so each inherited the session model. All are pinned.
- **`model-routing.md` listed the reviewers, `test-baseliner`, `test-writer` and `impl-maintenance` as receiving a `model_routing` block no dispatch sends**, routed the research agents to `planning_model` where every caller uses `detection_model`, and scoped §9 to two pipelines where §9.4 says it has no scope.
- **`docs-profile: --inline` re-stripped run flags from a string its caller built**, losing an explicit `--enforce-model`.
- **Seven reviewers defined `PASS` and `PASS WITH RECOMMENDATIONS` so that a lone MINOR matched both.** `PASS` is now *no findings at all*, as upstream's two newest reviewers already read it; `readiness-reviewer`'s `PARTIAL` needs at least one MAJOR.

**Hooks, grounding**

- **The preload hook told the dispatched agent to read its own file**, and named a strong-tier model list two releases stale (`Opus 5/4.8/4.7/4.6 or GPT-5.6/5.5`). It now points at §2 for the planner and §2.3 for the reviewer and names no model.
- **`idea:`, `create-vi:` and `update-vi:` showed the docs-grounding line a phase before they resolved it**, after their first agent.

**Smaller**

- `idea:` relocated into `/specifications/` when `$SPECS_PATH` was unset. `session-hygiene.md` excluded `create-vi:` from the session-name aid "for want of a key" it takes as a mandatory argument, and gave `update-vi:` no disposition. `specification-format.md` taught a story-level `### Open questions` the renderer files under the last criterion. `feedback:`'s category list lacked `environment-defect`. getting-started and the environment page listed `design:` among the commands matching repositories by directory name.

- **Gates.** `check-docs.sh` check 9's count patterns were unanchored, so an unenumerated compound numeral let the bare alternative match its own tail; check 4 accepted a prose mention as a documented hook, skill or reference file; `validate-catalog.py` never asked whether a plugin with a manifest is listed in any catalog; `check-id-grammar.sh` walked a root-level worktree copy. Each new selftest case was run against the unfixed form and fails there. Selftests: docs 33 → 35 of 41, ID grammar 4 → 6, catalog 17 → 18.
- **The instruction files stated counts the tree contradicts.** `dev-workflows-shared.instructions.md` said 33 docs pages with 8 under `reference/` (35 and 10) and 33 of 39 selftest cases; the root README said 34 sub-agents (35). `dev-workflows-skill-map.instructions.md` named `implement:` phases 2.6, 3.7 and 3.8, none of which exists — the baseline is Pre-Phase 3.5 and the tests are Phase 3.5.

**Not ported, by design:** the BRD route, frames, proposals, addressing, the plugin split, the de-brand, the cost subsystem's own fixes, the 2–4-option prompt cap (this edition's `ask_user` has none), the pull-request-vocabulary and Jira-hierarchy retirements, `/docs-init` / `/docs-brand` / `/docs-serve`, the derived readiness phase, and release notes filed in the specs repo. None of those exists in this edition.

### Fixed — field reports, ported from the Claude edition

These nine shipped in the Claude edition's 2.63.0 and were left out of this edition's port of it. None depends on anything this edition lacks.

- **`release-notes:` could destroy the draft that had already been pasted into Jira.** The destination is one persistent file per VI, and from the second run onward Phase 8 offered "Overwrite" against a file whose contents were the record of what was published. The existing file is now archived to `<path>.<timestamp>.bak` **before** the prompt is shown, unconditionally, and the report names the archive.
- **`docs-grounding.md` step 3.5 distinguishes an uncovered root from global index statistics.** Positive global vectors may belong to other documentation roots and do not establish registry corruption. The resolver offers the consented build for an uncovered root regardless of global vector count; a shadowed index falls back without build or refresh. The approval line reports the observed condition rather than a corruption diagnosis. **One narrower state is distinguished**: `qmd collection list` reporting no collections at all while `qmd status` reports indexed documents — the field incident's — where *Skip* is recommended and the build option warns it may re-embed what is already indexed.
- **The `qmd-vector` rung was selected on a boolean test over a proportional fact.** A partly embedded collection passes "has embeddings", so the plan reported full semantic retrieval while vector search returned noise. Partial coverage keeps the rung and names both numbers.
- **`docs-grounder`'s rung 3 now reports the observed retrieval precondition.** The agent and the orchestrator distinguish a missing binary, a failed probe, index shadowing, an uncovered root, an index holding documents but no collections, and a covering collection without embeddings. Neither infers registry corruption from global vector counts.
- **`release-notes-writer`'s source-truth check was gated on `code_repos`**, so a Jira-content-only run had no automated check over any claim. Split into 8a (against the acceptance criteria, always) and 8b (against the code, when repos are given).
- **`release-notes:` resolved contradictory Jira fields silently.** `relevant_for_release_notes: "Yes"` with `change_type: "Not applicable"` now produces a Phase 8 report line naming both values — a report, never a gate.
- **`dt-style-checker` was dispatched bare and its findings applied mechanically.** `release-notes:`, `create-vi:`, `update-vi:` and `epics:` now pass a `known_conventions` block naming what the artifact's own format mandates, so the checker stops raising findings that cannot be applied without failing the plugin's own lint — or, in one measured case, without putting a factual error about a product surface into a customer-facing note.
- **An `[AC#N]` that defeated its own VI's Goal passed every consistency check there was.** `create-vi:` Phase 3 and `vi-reviewer` now test each criterion against `## Goal` itself, and `create-vi:` states that a criterion imported from documentation is evidence about the status quo — inherited or overridden, said explicitly.
- **Three copies of the two claims above still said the old thing.** `update-vi:`'s own statement of the self-consistency check now includes the Goal test; `handoff/release-notes-writer.md`'s `code_repos` comment and `source-truth.md`'s note on the agent now say the acceptance-criteria half of the check runs without `code_repos`.
- `docs/skills/vuln.md` and `docs/skills/upgrade.md` now describe `TESTS_NOT_RUN`, which both skills have returned since the revert fix above; `docs/skills/release-notes.md` describes the archive and the contradictory-fields report.

### Added — stale-downstream-artifact detection

- **`update-vi:` now discovers what the update may INVALIDATE, not only what grounds it.** New Phase 0 step 5a globs for artifacts a later phase already produced — the release-notes draft in the feature folder and under `$VAULT_PATH`, plus any ARD, specification and design — and Phase 1 confirms each with its path and mtime. The next-phase offer is then **conditional**: an artifact the update contradicts is named, recommended and put first; one it does not touch is listed without recommendation; one that does not exist is dropped from the menu. An update once reversed an acceptance criterion a published release-notes draft depended on, turning it into a false customer-facing claim about data retention, and it was caught only because the same session had authored the draft and the orchestrator remembered. A write hook was considered and declined, with the reason recorded.

### Fixed — carried over

- NB-13, NB-14 (the gradle branch's `first()` dropped a failing earlier subproject — a red build could notify as green), NB-15.

## [2.31.0] — 2026-09-30

Ports the run-flags and model-dispatch work from `mgd-claude-plugins` 2.63.0 (itself a harvest of `ai-workflows` `workflows-core` 1.8.0 / 1.8.1), adapted to this edition: two flags, not three, and a multi-vendor strong tier.

### Added — run flags

- **Two run flags, each applicable skill's own body deciding which apply to it: `--skip-feedback` and `--enforce-model=<model>`**, with `$WORKFLOWS_SKIP_FEEDBACK` / `$WORKFLOWS_ENFORCE_MODEL` environment defaults (flag beats env beats off), documented end to end in the new `skills/_shared/run-flags.md` and resolved by its `strip-run-flags` entry point. A flag may sit anywhere in the argument list except inside the prose span of a free-text skill (`feedback:`, `prompt:`, `prompt-brainstorm:`, `prompt-grill-me:`, `implement:`, `idea:`, and `document:` in direct mode), where only the leading and trailing runs of flag tokens are stripped — prose ending in a flag name loses it, documented as a stated cost.
- **`--skip-costs` is deliberately NOT a flag of this edition.** The Claude edition's third flag suppresses its per-run cost entry; this edition has no cost subsystem at all (`specs-repo-git.md:54`), so there is nothing to turn off. It is not parsed and not reported ignored. `check-docs.sh` confirms the asymmetry from the other side — its cost check (8) is skipped in this edition and stayed skipped through this change.
- **The two applicability sets differ, and each skill states its own.** `--skip-feedback`: the 13 skills with an `impl-maintenance` phase. `--enforce-model`: those 13 plus `docs-profile:` (14) — the skills that cite `_shared/model-routing.md`. `docs-profile:` dispatches no maintenance agent; `feedback:` and the three `prompt` skills *are* the feedback surface and dispatch no subagent, so neither flag applies and they do not parse run flags at all. An inapplicable flag is reported ignored and **never validated**, so a bad `$WORKFLOWS_ENFORCE_MODEL` cannot break a skill the flag has nothing to do with.
- **`--skip-feedback` swaps the maintenance dispatch for a bugs-only agent, `defect-reporter`** (view/glob/grep, tier assigned at the call site — the new §2.2 cheap Haiku-first chain, or the run's enforced model). It returns only real defects, each with location, session evidence and a minimal repro, persisted through `feedback-emission.md`'s new `emit-bugs` entry point; a run with no defects persists nothing and never reads `feedback-emission.md`. The in-session Lessons Learned report is the one thing the flag costs.
- **A container-environment defect is now a feedback category, `environment-defect`, on every run.** `feedback-emission.md`'s plugin-facing predicate widened to include it, a new §4.1 states the defect predicate `defect-reporter` applies, and `emit-block` now also fires on a halt over a tool the container image is meant to provide and lacks — never for a tool missing on the user's own machine or from any other container.
- **`--enforce-model` pins every subagent dispatch of a run to one model** (new `model-routing.md` §10), overriding a caller's strong-tier pin, with nested dispatches propagating it. The orchestrator stays on its session model and prints one relaunch advisory when the two differ. Every `current_model` strong-tier-session gate is suppressed rather than re-pointed at the enforced value — the inline grill and authoring those gates protect still run on the session model, so testing the enforced value there would let a weak session pass a strong gate.
- New agent `defect-reporter`, new reference `skills/_shared/run-flags.md`.

### Fixed — model dispatch

- **`model-routing.md` §5 now states the dispatch rule, and states it conditionally.** The `model_routing` record keeps the resolved id; `task`'s `model:` argument passes the full dotted id where the tool accepts ids — **which is what this CLI does today, so behaviour here is unchanged** — and otherwise the id's family name, on a family-only harness such as Claude Code's Agent tool. **A non-Claude peer (`gpt-*`, `gemini-*`) belongs to no family**, so it is reachable only as a full id and would be undispatchable on such a harness; that is why the rule is conditional rather than a wholesale conversion to families, which is how it landed in the Claude edition. Ports `ai-workflows` `workflows-core` 1.8.1, adapted.
- **`claude-sonnet-5.5` was absent from the detection chain.** §2.1 still headed with `claude-sonnet-5`, so no routing path could select the current Sonnet. Added at the head, ahead of Sonnet 5. Not present in `ai-workflows` either — logged there as AW-2.
- `model_routing` block gains `defect_model`, `enforced_model` and `routing: bypassed`.

### Repository

- Docs: new `docs/reference/run-flags.md`, linked from the index and cross-referenced from the session-feedback and model-routing pages; all 15 affected skill pages carry their own applicability line and say plainly that `--skip-costs` is a Claude-edition flag only. Inventories moved with the tree — agents 34 → 35, reference files 97 → 98, environment variables 5 → 7 (two, not three: there is no `WORKFLOWS_SKIP_COSTS` here) — with `references.md`'s arithmetic re-derived against disk rather than incremented.
- `.github/instructions/dev-workflows-shared.instructions.md`: the `run-flags.md` authority, the §5 dispatch rule, §2.2 and §10.

## [2.30.0] — ported from `mgd-claude-plugins` 2.62.0 — 2026-09-26

Bug fixes harvested from `ai-workflows` through `workflows-core` 1.7.7 / `product-workflows` 3.8.4 / `dev-workflows` 4.2.5 / `docs-workflows` 1.3.5, ported here identically to the `mgd-claude-plugins` 2.62.0 edition — same defects, same fixes, applied to this edition's skill/reference layout. Every bullet is verified against this run's working-tree diff.

### Fixed — git and code-repo handoff

- **`handoff-to-main`'s branch-reuse test misread a deleted-on-merge remote ref as "not yet merged," reusing an already-merged branch.** Now resolves `refs/remotes/origin/<name>` when present, else `refs/heads/<name>`, reading a missing ref as merged. Ports ai-workflows 3.21.0.
- **Staging enumeration silently mis-subtracted paths with spaces, quotes, or non-ASCII bytes** — porcelain output lacked `-z`. Added to `code-repo-handoff.md`'s enumeration and every caller's `pre_existing_dirty` capture/comparison. Ports ai-workflows 4.0.4.
- **The base-branch ladder trusted a dangling `origin/HEAD`.** Rung 1 now also requires `rev-parse --verify --quiet origin/<name>`. Ports ai-workflows 4.0.4.
- **`upgrade/SKILL.md`'s "non-default branch" check had no defined base resolution.** Now resolves `<base>` via the same ladder. Ports ai-workflows 4.0.4.

### Fixed — implement, vuln, upgrade

- **BLOCKER: `implement/SKILL.md`'s `code-scanner` dispatch carried no `refresh:` block**, so a scan could move the user's own checkout before the run's branch existed, with no consent. Both dispatches now pin `refresh: {switch_to_default_branch: false, pull: false}`. Ports ai-workflows 3.22.0.
- **`mktemp` templates used four `X`s (BusyBox rejects it) and bare `mktemp`.** All affected SKILLs and `context-management.md`'s shared rule now use `-XXXXXX` and `command mktemp`, removing temp files once unread. Ports ai-workflows dev-workflows 4.0.4 / product-workflows 3.6.0.

### Fixed — PM and PE authoring skills

- **Every `create-vi:` Overwrite lost the prior VI.** Phase 5 now archives to `revisions/<KEY>_<slug>_<YYYYMMDD>.md` first. Ports ai-workflows product-workflows 3.8.3.
- **`create-ard/SKILL.md`'s tiered HARD gate tested `opus_available` instead of the session's own tier.** Now tests `current_model is not Opus-tier`, matching `design:`. Ports ai-workflows product-workflows 3.6.0.
- **`design/SKILL.md`'s and `create-ard/SKILL.md`'s HARD gate always offered a relaunch-on-Opus option, even when none was reachable.** Both drop that choice when `opus_available: false`. Ports ai-workflows dev-workflows 4.0.4.
- **`create-ard/SKILL.md` and `specify/SKILL.md` resolved docs grounding mid-run, after already printing a "resolved" status line.** Both now call `resolve-docs-grounding` in Phase 1. Ports ai-workflows product-workflows 3.7.0.
- **`--docs <path>` was documented as universal but only `idea:` parsed it.** `create-vi`, `update-vi`, `create-ard`, `specify`, `epics` SKILLs now parse and strip it, with Usage lines added. Ports ai-workflows product-workflows 1.1.0.
- **`release-notes/SKILL.md` parsed neither `--no-docs` nor `--docs <path>`** though it consumes `docs-grounding.md`. Both are now stripped first (found during this harvest).
- **`doc_type: vi` sent to `dt-style-checker` was not in its enum.** Now `doc_type: prd`.
- **`idea-format.md` allowed `provenance: doc-grounding`, absent from `vi-format.md`'s enum.** Removed; `pre-lint.md` gained a MAJOR check.
- **`create-vi/SKILL.md` Phase 4 didn't say whether MAJOR findings under a passing verdict must be fixed.** Matches `specify:`: no mandatory fix cycle under `PASS WITH RECOMMENDATIONS`.
- **`epics/SKILL.md` Phase 8 dispatched four maintenance agents with no model tier.** All four now pin `model: <detection_model>`. Ports ai-workflows product-workflows 3.6.0.

### Fixed — idea

- **A boundary the source states explicitly could be lost or silently argued around.** `idea-reader` now returns `stated_scope` (`in[]`/`out[]`, verbatim quote + ref + `firmness: firm|tentative`). Phase 3 seeds `firm` entries as already-settled, confirms `tentative` ones, and checks every recommendation **and its rationale** against `stated_scope` first. Phase 4 writes every entry into `## Rough scope` unless reversed. Ported identically to the mgd fix; also shipped in `ai-workflows` `product-workflows` 3.8.5 / `workflows-core` 1.7.8.

### Fixed — model routing

- **Opus 5.5 was missing from the strong tier's peer list.** `model-routing.md` §2 now lists `claude-opus-5.5` first of what is now **seven** co-equal peers (was six); `docs/reference/model-routing.md` and `document:`/`docs-profile:` examples updated, and the peer label every reviewer agent, skill page, `plugin.json`, `marketplace.json` and the skill-map instructions file carries now reads `Opus 5.5/5/4.8/4.7/4.6 or GPT-5.6/5.5` (32 sites in 23 files). No cost subsystem exists here, so there is no price-table analogue of the mgd fix. **Caveat:** the id `claude-opus-5.5` follows Copilot's dotted convention (`claude-opus-4.8`) but was not confirmed against an actual Copilot model list.

### Fixed — agents

- **`interface-designer` ran `git grep`/`git log` unqualified, against the session's cwd.** Now scopes to `code_context.repo_path` via `git -C`.
- **`docs-grounder`, `counterpart-finder` (backstop + Layer 2), and `diff-summarizer` matched a Jira key as an unanchored substring.** All now use the whole-key ERE form.
- **`vuln-research.md` cited the wrong step (`vuln:` Step 0) for the Opus re-invocation rule**, actually in Step 2. Corrected.
- **`skills/_shared/handoff/test-baseliner.md` documented an unused input field, `model_routing:`.** Removed.

### Fixed — hooks

- **`test-notify.sh` never actually read a test's output** — same stdin/here-document collision as mgd. Parser now captured to a variable, invoked via `python3 -c`. Ports ai-workflows workflows-core `45f3ffc3`.
- **Maven counts were double-counted, and a flaky run silently dropped its failing module.** Anchored per-module line, optional `, Flakes: N`, unanchored fallback. Ports ai-workflows workflows-core `45f3ffc3`/`a5b9223f`.
- **`./mvnw test` never notified.** Added its own gate entry. Ports ai-workflows workflows-core `67cc6b4c`.
- **An unmeasured test count was reported as a measured zero.** Helpers return `None` on no match; an all-`None` family reports `"tests completed"`. Ports ai-workflows workflows-core `a5b9223f`.

### Fixed — document, docs-profile, release-notes and Vale

- **Vale configuration was detected by one file name only, and every run merged in the machine's global configuration.** `docs-style-checker`, `toolchain-preflight.md`, and dt-style-guide's `dt-review-pr`/`dt-review-docs` tested `.vale.ini` alone. Both now find all five names Vale reads and isolate the global config.
- **`dt-review-pr` hardcoded `origin/main` as the base branch.** Now resolves the actual default branch.
- **`toolchain-preflight.md`'s tool detection didn't handle real shell shapes** — leading `cd`/`VAR=` prefixes, alias/function shadowing of `command -v`. Condensed to the load-bearing core rather than the full apparatus `docs-workflows` ported, since this plugin has no subshell-boot consumer to warrant it.
- **`document/SKILL.md`'s two handoff temp files used a 4-`X` template and bare `mktemp`, never removed.** Now `-XXXXXX` + `command mktemp`; Phase 8 removes both once unread.

### Repository

- **`scripts/check-docs.sh`'s body had drifted between the two editions it is shared with.** 2.61.0 (Claude edition) added a sixth cost-only selftest case and check 8's `cost_role_marker`, kept the comment and the `skip` line at five, and never reached the Copilot copy. Both now say six, and the body below the edition-config block is byte-identical again, so the Copilot edition runs 33 of 39 cases and skips 6.
- **`scripts/check-docs.sh` check 6 counted bytes, not characters, under `mawk`.** Fixed with `LC_ALL=C` plus UTF-8 continuation-byte subtraction; mutation-verified.
- **`.github/copilot-instructions.md` had grown past its size budget.** Split into a trimmed always-loaded file plus two path-scoped `.github/instructions/*.instructions.md` files and a never-auto-loaded `docs/maintainers/rationale.md`. `validate-catalog.py` gained a size gate and an `applyTo`-glob liveness check with `--selftest`, wired into CI.

## [2.29.1] — ported from `mgd-claude-plugins` 2.60.1 — 2026-08-31

### Fixed
Multi-agent Opus review of the 2.59.0 + 2.60.0 changes. Four reviewers, 40+ findings, each verified at the location it named before any fix; the git primitives were re-checked empirically in a scratch repo rather than reasoned about.

**Four defects that would have broken a run:**
- **`vuln:` never supplied `vuln-fixer` with the branch name it was told to create.** The input schema had no `branch:` field, neither task prompt passed one, and Step 1 resolved none — while the agent's step 2 said "create the branch the orchestrator supplied". The fixer would have invented a name and Step 3.9 would have pushed a different one. Step 1 gains a per-CVE branch-resolution step, both prompts pass `branch:`, the handoff schema documents it as required, and a missing value is now `BLOCKED` rather than an improvised name.
- **`BLOCKED` meant two opposite things and the Step 3.9 skip list keyed on it.** It is returned by a *first* call (nothing created) and by a *resume* call (branch exists, fix applied), and is also the label written for four orchestrator-side stops — two of which must hand off. A skip keyed on the label stranded an applied fix, which the next CVE's `git switch` then aborted on or carried onto an unrelated branch. The skip is now decided by the **tree** (`git status` against `pre_existing_dirty`), never by the status label.
- **`implement:`'s seven post-branch stop exits all bypassed Phase 4.6** — including a persisting review `BLOCK`, the very state Phase 4.6's own `clean_finish: false` bullet named and could therefore never receive. A branched, written, sometimes fully-reviewed implementation was left uncommitted on exactly the paths where losing it costs most. Every such exit now runs Phase 4.6 with the stop as its blocking fact; the "Abandon and restore" arm is the one documented exception.
- **`upgrade:`'s per-component commit ran with no gate.** The split call was specified as "§2.2–§2.3 only", leaving §2.1 outside it, so a run whose branch creation had failed would commit its whole batch onto the default branch and only discover it at the terminal call — which would then report `NOT committed` over work that was committed, in the wrong place. The split is now §2.1–§2.3; the gate runs every time.

**Git mechanics that were wrong (all verified empirically):**
- **The `OWNER_REPO` parse dropped `ssh://` remotes and stripped the host.** `ssh://git@host/Org/repo.git` passed through unchanged, and a GitHub Enterprise remote yielded a bare `OWNER/REPO` that `gh -R` resolves against **github.com** — potentially an unrelated public repository. Replaced with a host-preserving four-expression parse emitting `gh`'s documented `[HOST/]OWNER/REPO`, verified against nine remote forms. **The same broken parse is fixed at its root in `phase-handoff.md` §2.6**, where it originated and where it had been shipping since that reference was written.
- **The base-branch ladder returned a SHA on rungs 2–4.** `rev-parse` prints a SHA, so `git switch <sha>` detached HEAD and `gh pr create --base <sha>` was rejected. Rungs 2–4 are now existence probes whose output is discarded; the literal name is used.
- **§2.1's default-branch check could never fire.** `symbolic-ref --quiet HEAD` prints `refs/heads/<name>` while the ladder yields the short name, so the comparison never matched on any rung. Now `--short`, plus a new check that HEAD actually equals the caller's `branch` input — without it a commit could land on one branch while the run reported pushing another.
- **The commit body was passed through `commit -m`.** `vuln:` interpolates an NVD CVE description — free text with shell metacharacters — so `$(…)` in a description was command-substituted before git saw it. Now written to a file and committed with `-F`, the rule `phase-handoff.md` §2.7 already applied to PR bodies.
- **The pull-request body file was referenced three times and produced nowhere**, so `gh` would have opened an interactive editor (which the reference forbids) or failed on a missing path. §2.7 now defines it.
- Added: an existing-PR probe (a re-run reported "no PR opened" for a PR that was already open), `--draft` carried into the no-`gh` fallback command (which otherwise handed the user a mergeable PR for blocked work), hook-rejection handling, and a §3.1 table that covers every reachable terminal state instead of five of them.

**Contradictions removed:**
- `git add -A` at repository scope contradicted a hard rule stated in `specs-repo-git.md`, `phase-handoff.md`, and `.github/copilot-instructions.md`. The staging is correct — in a code repo the whole diff is the deliverable — but an undeclared contradiction is a defect regardless. §1 now declares the divergence in both directions, and `.github/copilot-instructions.md` scopes the plugin-wide rule to `$SPECS_PATH`.
- §2.2's staging prompt fired once per unit in a loop (ten CVEs, ten prompts) and offered a "skip the commit" option that contradicted §1 rule 5's unconditional commit. It is now a rule, not a prompt.
- §2.4's cached consent had no re-ask trigger, so declining on a blocked first CVE silently withheld nine clean ones. Two triggers now re-ask.
- §2.11 named `vuln:` as both an example of the split form and a counter-example to it.
- `vuln:`'s terminal step still credited `vuln-fixer` with the code-repo commits and PRs.
- The grilling confirmation gate said both "before writing a section" and "when the frontier is empty"; four of five relentless callers author section-by-section and inherited the contradiction. The gate now fires wherever understanding becomes an artifact.
- The ambiguity taxonomy claimed Impact × Uncertainty orders questions "across rounds", while the frontier rule says dependency alone decides round membership — an agent following it would ask a question before its prerequisites.
- The autonomous-invocation section did not survive the rounds rhythm: the frontier advances on answers, and autonomously none arrive, so a literal reading enumerated only the first round. It now walks the whole tree, treating each recorded open question as provisionally settled.
- **`/idea --deep` would have written `- [ ]` into an `idea.md`.** The open-question notation was keyed on depth, and `--deep` makes `idea:` relentless — but `idea-format.md` knows only `[NEEDS CLARIFICATION]`, so `status` would have computed to `refined` and handed an idea with unresolved decisions to `create-vi:`. The notation is now keyed on the artifact's format, never the depth.

**Docs and record corrections:** the `vuln-fixer` agents.md row listed branch creation last, describing the ordering this release exists to eliminate; both editions' `implement:` page understated its phase count by one; the changelog claimed the `---` separator was not taken while the shipped template contains it, and undercounted the corrected docs pages as five; "still pushed" overstated what §2.4 gates on consent. `vuln-fixer` also gained a branch-collision stop — a re-run after `BUILD_FAILED` hits an existing empty branch, which is the *most likely* second invocation.

**Port-specific fixes** (found by the cross-edition parity review): the port's `handoff/vuln-fixer.md` still told the sub-agent `keep-anyway -> commit & PR`, contradicting the same file's rewritten semantics and the agent's own "never commit" invariant — a consent bypass, since the sub-agent cannot ask §2.4's choice. The port's `implement:` docs diagram enumerates every `## Phase` heading and had no node for Phase 4.6; its Gates section had no failed-gate paragraph; its `design:` docs page described no rhythm at all while its skill description said "round-by-round"; and `.github/copilot-instructions.md` was missing the Phase 4.6 ordering invariant and the grilling rhythm-follows-depth invariant.

### Fixed (second pass)
A mechanical re-audit of all 48 findings against the tree — rather than against memory — caught six that the first fix pass had missed: the port's `agents.md` `vuln-fixer` row still listed branch creation last (the canonical row was fixed, the port's was not); `docs/workflow.md` in the port used a bare code span where a link was needed; `docs/skills/upgrade.md` still described the push and pull request as unconditional when §2.4 gates them on consent; §4 obligation 3 said "exactly once per call" while §3.1 says a split call emits none; there was no outcome row for `gh pr create` exiting 0 with no parseable number or URL (falling back would have told the user to open a second pull request for one that already exists); and the port's `docs/skills/design.md` still described no rhythm. Both editions' `upgrade` docs pages also gained the See-also link to the new reference that the other two code-command pages already carried.

## [2.29.0] — ported from `mgd-claude-plugins` 2.60.0 — 2026-08-31

### Changed
- **The grilling rhythm now follows the grill's depth: relentless skills work in rounds, bounded skills keep asking one question at a time.** Harvested from upstream `mattpocock-skills` 1.2.0 (PR #593), which replaced one-question-at-a-time with a round-by-round frontier — "same 13 questions land in ~3 rounds instead of 13." The upstream change was adopted only where it is safe. A **relentless** grill (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, and `idea: --deep`) now maps the design tree and asks the whole **settled frontier** as one numbered round, recomputing the frontier from the answers until it is empty; a question whose answer depends on another still open in the same round belongs to a later round, which is the rule that keeps a round from being a batch. A **bounded** grill (`idea:` at ≤10, `prompt-grill-me:` at ≤5) is unchanged, because a cap counted in questions is only enforceable one question at a time: a round can spend a ≤5 budget in its first breath, or be truncated mid-frontier and leave a settled parent with its children silently unasked — the exact failure the bound's `[NEEDS CLARIFICATION]` record exists to make visible. The rhythm is therefore **derived from the depth, not chosen per run**, and `--deep` moves both together.
- **`skills/_shared/grilling-technique.md` gains a confirmation gate** (upstream 1.1.0, PR #464). Reaching a shared understanding is the user's call to declare, not the agent's to infer from a quiet turn: before writing a section, and before any caller takes an expensive or outward-facing next step (a reviewer dispatch, a handoff, a commit), the agent states what it believes is settled and gets confirmation via `ask_user`. Previously the file said only "continue until you and the user reach a shared understanding," which left the judgement with the agent. In autonomous / background invocation the gate cannot be self-satisfied — the understanding is reported as unconfirmed.
- **The fact-vs-decision split gains a dispatch rule and a non-blocking rule** (upstream 1.2.0, PR #593). A fact is the agent's to find and never the user's to supply; where the skill has a sub-agent for the lookup (`code-scanner`, `docs-grounder`, `jira-reader`), it dispatches rather than asks. A running lookup is an unsettled prerequisite for the questions downstream of it **and for nothing else** — the rest of the frontier is asked meanwhile, so the interview never idles on a fact.

### Notes
- Four things this reference carries that upstream does not were deliberately preserved rather than overwritten by the harvest: the **bounded vs. relentless depth** axis, the **autonomous / background no-fabrication** rule, the **altitude-aware ambiguity taxonomy**, and **forced terminology precision**. A naive re-sync with upstream would have deleted all four.
- Upstream's em-dash removal was not taken — it is upstream house style and runs against this repo's prose conventions. The numbered `❓ Q1` / `➡️` round template **was** taken, since rounds need referenceable question numbers, and so was the `---` rule between questions that ships with it. (Both are unreleased `.changeset/` entries in the cached 1.2.3 tree, not released 1.2.2/1.2.3 content.) a skill that puts a decision to the user through a `choices:` array keeps doing so.
- `diagnosing-bugs` was checked at the same time (upstream 1.2.3, PR #779): `skills/_shared/bug-diagnosis.md` already carries its redaction section, so there was nothing to port.
- This edition's `.github/copilot-instructions.md` carries no grilling depth/rhythm invariant to update — a pre-existing difference from the Claude edition's `CLAUDE.md`, left as-is rather than widened inside a port.

## [2.28.0] — ported from `mgd-claude-plugins` 2.59.0 — 2026-08-31

### Added
- **`skills/_shared/code-repo-handoff.md` — the code repo's own git finish, which the plugin never had.** `implement:` and `upgrade:` each created a feature branch, wrote into it, ran their gates, and ended — leaving every change uncommitted, with nothing but the user's memory between a finished implementation and a stray `git checkout`. `vuln:` did commit and open a pull request, but specified neither: no `gh` capability probe, no fallback for a host without `gh`, no base-branch resolution. The new reference is the code-repo counterpart of `phase-handoff.md` and is deliberately shaped like it — gate (§2.1), staging with three carve-outs (§2.2), commit (§2.3), consent choice (§2.4), push (§2.5), `gh` probe and fallback (§2.6), base-branch ladder (§2.7), not-clean-finish rule (§2.8), caller inputs (§2.10), the split-call form a per-unit loop uses (§2.11), outcome lines (§3.1), caller contract (§4). One structural inversion from `phase-handoff.md` §1 rule 7, recorded in §1 rule 5: **the commit is prompt-free.** There the deliverable is already safe on disk when consent is asked; here the work is not safe until it is committed, and a prompt that can be answered "no" is the exact failure this file removes. Only the push and the pull request sit behind consent, asked once per run via `ask_user` and reused for every later branch in it.

### Fixed
- **`implement:` never committed the implementation.** New **Phase 4.6**, running after Phase 4 and before the Phase 5 report, executes `finish-code-branch`. The placement is load-bearing, not stylistic: Phase 4's Agents 1–3 write `README.md`, `CHANGELOG.md`, `docs/`, and `.github/copilot-instructions.md` into the same repository, so a commit placed ahead of them ships a partial run. Pre-Phase 3 step 1 now records `stash_ref` and `pre_existing_dirty` — without them Phase 4.6 cannot honour §2.2's carve-outs and would sweep a bystander's uncommitted work into this run's commit. The `Code repo:` outcome line lands in the report's `### Branch` section, and a multi-source run that wrote into a repo it never branched names that repo and its dirty paths there rather than inventing a branch for it. The terminal phase's "the implementation remains uncommitted" claim, and the matching line in `docs/skills/implement.md`, were both false the moment this shipped and are corrected.
- **`upgrade:` never committed the upgrade.** New **step 6.5** commits each component in-loop through §2.11's split-call form as soon as that component's own gates settle, and new **step 7.5** runs the full entry point once for the batch — push, then pull request. Per-component committing is the point: a batch that dies on component three still leaves one and two committed, each with its own message, on a branch that bisects. `upgrade-executor` still commits nothing — that is a division of labour, now stated as one, not a policy that the work goes uncommitted; committing inside the agent would also commit work an `AWAITING_REVIEW` call has deliberately not shown the reviewer yet.
- **`vuln:`'s commit and pull request had no mechanics, and each CVE branched off the previous CVE's branch.** Commit, push, and PR move from `vuln-fixer` to the orchestrator's new **Step 3.9** — the consent choice they sit behind is one a sub-agent cannot ask, since sub-agents dispatched via the `task` tool have no interactive tools. `vuln-fixer` now creates the branch, applies the fix, and stops; its handoff contract drops `pr_url` accordingly. Step 3 now switches back to the base branch before each CVE: every CVE gets its own branch and its own pull request, so a CVE branched off its predecessor shipped that predecessor's fix inside its own diff, its own review, and its own PR. §2.4's choice is asked on the first CVE and reused, so a ten-CVE run asks once rather than ten times.
- **`vuln-fixer` created the fix branch *after* applying the fix, breaking the plugin's own standing invariant and stranding two failure paths.** "Branch created before any file is touched" is a key invariant for all three code-oriented skills; `vuln:` edited on the base branch and branched at the very end. That made the branch nonexistent on exactly the paths where the work most needs saving — an `AWAITING_REVIEW` return whose review then stops at an unresolved `BLOCK` or a `NEEDS HUMAN` `review-fixer` stop. Branch creation moves to step 2, ahead of the edit; the process renumbers to baseline → branch → apply → build → verify → output, and the `verify-resume` / `regression-resume` / `gate_tests_on_review` step numbers move with it. `AWAITING_REVIEW` and `TEST_REGRESSION` now report `branch`. A `BUILD_FAILED` or `REVERTED` CVE leaves an empty branch, which the Step 4 table names rather than leaving as an unexplained ref — the plugin never deletes a branch (§1 rule 3).
- **A run that failed its own gates was the case most likely to lose work, and had the least protection.** An unresolved `BLOCK`, kept regressions, or a `BLOCKED` unit now still commit and still push (§2.8) — unreviewed work that exists can be reviewed later; work that was never committed cannot. Only the pull request changes: opened `--draft`, with `> ⚠ DO NOT MERGE — <the blocking fact>.` as the first line of its body, and as the first line of the manual-open fallback text where `gh` was unavailable. `vuln:`'s two "do not continue to tests, commit, or PR" stops are reworded to match; leaving the fix in a working tree was never what they meant to buy.

### Changed
- `specs-repo-git.md` §Scope and `phase-handoff.md`'s relationship note now name the third reference, so the map — bookkeeping in `$SPECS_PATH`, deliverables in `$SPECS_PATH`, the code repo — is reachable from any of the three.
- `docs/reference/references.md` gains the new file and its arithmetic is re-derived against the tree (96 files → 97; 36 top-level markdown → 37). `docs/skills/implement.md`, `docs/skills/upgrade.md`, `docs/skills/vuln.md`, `docs/workflow.md`, `docs/roles.md`, and `docs/reference/agents.md` each carried a "left uncommitted" or "commits and opens a PR" claim that is now false; all six are corrected.

## [2.27.3] — 2026-08-23

### Added
- **Ported the `dynatrace-docs-frontmatter` skill, closing the port gap 2.27.2 documented (never fixed) at `skills/dynatrace-docs-frontmatter/SKILL.md`.** `docs-profile/SKILL.md:4,17`, `document/SKILL.md`, and the runtime hook message at `hooks/changelog-owners-reminder.py` had all pointed at "the `dynatrace-docs-frontmatter` skill" without it existing in this edition. Adapted from the canonical/mgd editions' skill to this edition's dialect: lowercase `allowed-tools` (`view, edit, bash, glob, grep` — no `create`/`task`/`web_fetch`/`ask_user`, since it neither creates files, dispatches other skills, calls the web, nor prompts interactively), a folded `description: >` block ending in `Activated when the user prompt starts with "dynatrace-docs-frontmatter:"` (mirroring the Claude edition's `user-invocable: true`), and every `${CLAUDE_PLUGIN_ROOT}/references/dynatrace-docs/*` path rewritten to `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/dynatrace-docs/*` — all three cited guideline files (`changelog-guidelines.md`, `managed-owners.txt`, `frontmatter-guidelines.md`) were already bundled there; only the skill wrapper was missing. Added `docs/skills/dynatrace-docs-frontmatter.md` (required by `check-docs.sh` check 4, since `skills/` is this edition's command directory) and linked it from `docs/README.md`'s table and skill list. Updated every site that described the skill as absent — `docs/skills/docs-profile.md`, `docs/reference/hooks.md` (twice), `docs/reference/references.md`'s `## Skills` section, and the hook's own reminder message (now points at running the skill, not just its guideline files) — to describe it as bundled. Re-derived the skill count from 20 to 21 everywhere it's stated: `README.md` (repo-root and plugin), `docs/README.md`, `docs/reference/references.md`, `.plugin/plugin.json` / `.github/plugin/marketplace.json` descriptions, and `.github/copilot-instructions.md`'s 32→33 doc-page count. The census (`scripts/spec-id-baseline.txt`'s `[Uxx]`/`[ACxx]`/`[TCxx]` tripwire) is unaffected — the ported skill introduces no such markers.

### Removed
- **Deleted three dead `skills/<name>/references/` subdirectories** (`upgrade/` — 3 files, `api-guideline-reviewer/` — 25 files, `guideline-reviewer/` — 12 files; 40 files total) — CRLF-only duplicates of `skills/_shared/upgrade/`, `skills/_shared/api-guidelines/`, and `skills/_shared/guidelines/` respectively, left over from the commits that first added those three skills. Re-verified before deleting: no file outside `docs/` referenced any of the three paths; every file's content matched its `skills/_shared/` counterpart byte-for-byte (modulo CRLF/LF); and `agents/upgrade-executor.md` / `upgrade-planner.md`, `agents/guideline-reviewer.md`, and `agents/api-guideline-reviewer.md` all read exclusively from `skills/_shared/`. Removed the now-obsolete `## The three per-skill references/ subdirs` section from `docs/reference/references.md` and the matching `references/` entry from `.github/copilot-instructions.md`'s repository-structure block — no plugin in this marketplace uses that convention anymore.

## [2.27.2] — 2026-08-23

### Fixed
- **`scripts/spec-id-baseline.txt` was stale and its own documented verify command was silently passing on a dirty tree.** Its census counts (`[Uxx]`/`[ACxx]`/`[TCxx]`) were frozen at 19/17/21 while the 2.27.0 docs restructure removed the plugin README's one converge-check sentence carrying all three placeholders but added two replacement mentions — `docs/skills/design.md:46` and `docs/skills/specify.md:56` — netting +1 per form instead of the -1 a straight removal would have produced. The baseline was never regenerated afterward, so the tripwire had gone silently inert. Regenerated to 20/18/22, preserving the header, with a new dated note recording the delta and its cause — never regenerated silently.
- **That file's header claimed all three editions produce its numbers exactly, inverting the tripwire for this edition.** This edition's second scan root (`.github/copilot-instructions.md`) folds in prose canonical and mgd instead split across `CLAUDE.md` and several `docs/reference/*.md` pages, and this edition's skills/docs prose is independently authored, not copied — so a higher or lower raw count than canonical/mgd (18/16/20) is expected here, not drift. Rewrote the header to say so and to state plainly what this file actually guards in this edition: drift within it, between two runs of the regenerate command, with no dated note explaining why.
- **`agents/vault-prior-art-finder.md:4` declared `tools: ["Read", "Glob", "Grep"]`** — Claude-edition capitalized tokens, where all 33 other agents use Copilot CLI's lowercase tokens (`tools: [view, glob, grep]`). Functional, not cosmetic. Fixed the agent; `docs/reference/agents.md` no longer describes the inconsistency as a live "leftover from the port," and its table row for the agent is corrected to match.
- **`dynatrace-docs-frontmatter` was dropped in the port and mis-explained as a nonexistent external dependency.** Canonical and mgd bundle `skills/dynatrace-docs-frontmatter/SKILL.md`; this edition has none, yet `docs/skills/docs-profile.md`, `docs/reference/hooks.md` (twice), `docs/reference/references.md`, and the runtime hook message at `hooks/changelog-owners-reminder.py` all point at "the `dynatrace-docs-frontmatter` skill." `references.md` went further, claiming "no such skill exists in this repo or in any of the marketplace's other three plugins" — mis-diagnosing a port omission as an external dependency that was never real. The skill itself is still out of scope for this edition and was **not** ported. Corrected the explanation at every site to say plainly that this edition does not bundle it (a known port gap, not an external dependency), and changed the runtime hook message to point at the guideline files this edition *does* bundle (`skills/_shared/dynatrace-docs/changelog-guidelines.md`, `managed-owners.txt`) instead of instructing the user to run a skill that does not exist here.
- **`README.md` said "The Claude edition of this plugin calls this same set 20 slash commands"** — the Claude editions have 21 (`/statusline` has no counterpart in this edition). Reworded so the cross-edition count is accurate: 20 of the Claude editions' 21 commands map 1:1 to this edition's skills, and the 21st has no counterpart here.
- **`docs/reference/references.md` said "the twenty pipeline skills" while `docs/reference/model-routing.md` correctly says "fourteen pipeline skills."** Twenty is the total skill count, not the pipeline-skill count — only fourteen of the twenty load `model-routing.md`; the other six (the two guideline reviewers plus the four feedback/utility skills) are exempt. Reworded to state both numbers and what each one counts.
- **`docs/superpowers/specs/2026-08-23-copilot-docs-port-design.md:32,44` scoped a page called `roles-and-phases.md`; the shipped page is `docs/roles.md`.** Corrected the spec to match what shipped (the shorter name reflects the page carrying roles only, with no cost-attribution half to name).

## [2.27.1] — 2026-08-23

### Fixed
- **`update-vi:`'s forward-path offer omitted `epics:`, and was self-contradictory about it.** `skills/_shared/next-phase-offer.md` and `docs/workflow.md` both *claimed* `update-vi:` offers "the same forward paths as `create-vi:`" and then named only three: `release-notes:`, `create-ard:`, and `specify:`; `skills/update-vi/SKILL.md`'s Phase 6 `choices` array and `docs/skills/update-vi.md`'s See-also line carried the same omission without the contradiction. Confirmed with the maintainer: `update-vi:` offers the same four forward paths as `create-vi:`, including `epics:` — `update-vi:` improves a VI that `create-vi:` created, so everything downstream is identical, and the omission was an understatement rather than a deliberate exclusion. Added `epics: <VI>` (PE) alongside the other three in all four sites; the existing "(if one exists)" qualifiers on `create-ard:` and `specify:` are untouched.

## [2.27.0] — 2026-08-23

### Added
- **A 32-page `docs/` tree replaces the plugin README as this edition's human-facing documentation.** `docs/README.md` (the index), `getting-started.md`, `workflow.md`, `roles.md`, 20 skill pages under `docs/skills/`, and 8 reference pages under `docs/reference/`. Ported from the Claude editions' equivalent restructure under the same derivation contract — **a Claude edition's page is a source of topics, never a source of facts** — every claim is re-derived from this edition's own shipped tree (this edition's `agents/`, its own skill triggers and phases, its own env-var reads), never copied across. Two omissions are deliberate, not gaps to fill later: **no `session-cost.md` page**, because this edition has no cost subsystem (`skills/_shared/specs-repo-git.md:54`: "This edition has **no cost subsystem** — there is no `cost-emission.md`, no `emit-cost`, and no `dev-workflows-cost/` path shape"), and **no `statusline` page**, because no such skill exists in this edition. A future reader must not "fix" either omission by adding the page back.
- **`scripts/check-docs.sh`** guards the tree against drift from the shipped plugin — links/anchors resolve; no page is unreachable from `docs/README.md`; the skill/agent/reference-file/hook inventories match the tree in both directions; every plugin-read environment variable is documented and every documented one is actually read; no table cell exceeds 200 characters; `getting-started.md`'s install commands match the repo-root README verbatim (the identity-quarantine pin — no other page under `docs/` may name the marketplace or a container repo); and every prose count matches the tree. This edition's `HAS_COST=0` makes the cost-attribution check and the cost half of the prose-count check inert-and-reported rather than gating, so `--selftest` runs 32 of its 37 defined cases, not 37 — do not read the Claude editions' numbers onto this one. Wired into `.github/workflows/validate-catalog.yml`: `check-docs.sh --selftest` runs immediately before `check-docs.sh --root .`, mirroring the existing `check-id-grammar.sh --selftest` / `--root .` ordering, so a docs gate that has lost the ability to fail turns the build red instead of green.
- **`.github/copilot-instructions.md` now documents the `docs/` tree.** Added to the repository-structure block (alongside the `hooks/` fix already there) and a new convention paragraph covering the tree's shape, the derivation contract, how to run the gate before pushing (CI runs it too), and the identity-quarantine rule.
- **The Dev/Team role collapse, ported from the Claude and mgd editions (their 2.57.0 — team folds into dev; QA retires into dev's readiness check).** `docs/roles.md` and the 20 skill pages already used the collapsed vocabulary; `next-phase-offer.md`, `session-hygiene.md`, `workflow-states.md`, and six SKILL.md next-step/context-hygiene sections still said Team, PE/Team, or `-team`, so the new docs and the old machinery contradicted each other about this plugin's own role vocabulary. Now aligned.
- **The plugin README rewritten as a docs/ pointer, 409 → 53 lines.** Replaced with the same role-indexed pointer table shape the Claude and mgd editions use (PM / PA optional / PE / Dev / three "Anytime" rows) plus a Documentation table linking into the docs/ tree, content derived from this edition (20 skills, colon-keyword invocation, the `ihudak-copilot-plugins` marketplace and `copilot` install/update commands).

### Fixed
- **A false "pinned to a model by its own frontmatter" claim, carried across from the Claude editions along with the skills' prose but never true here.** 23 occurrences across `vuln/SKILL.md` (4), `upgrade/SKILL.md` (6), `document/SKILL.md` (4), `implement/SKILL.md` (5), `epics/SKILL.md` (3), and `skills/_shared/model-routing.md` (1) asserted that `risk-planner`, `code-review`, `doc-reviewer`, and `epic-reviewer` are pinned to Opus by their own agent frontmatter. Confirmed false: 0 of 34 `agents/*.md` files in this edition carry a `model:` field — the Claude editions' agents do, and that is where the phrasing came from at port time. The model is actually pinned by the caller's `task(model:)` at the dispatch call site; reworded every occurrence to "dispatch-pinned", preserving which chain applies and that no dispatch override is ever added on top. The `dev-workflows/docs/skills` pages already described this correctly (`vuln.md` and `upgrade.md` even called out the pre-fix source's wrong-phrasing counts) and needed no change.

## [2.26.3] — 2026-08-23

### Fixed
- **`.github/copilot-instructions.md`'s repository-structure block omitted `hooks/`.** This edition ships four hooks and a `hooks.json`, its README documents them in a `## Hooks` table, and the `hooks.json` is genuinely Copilot-adapted — `${PLUGIN_ROOT}` rather than `${CLAUDE_PLUGIN_ROOT}`, a `bash:` key rather than `command:`, and a comment recording that **Copilot CLI does not support Claude Code's `matcher` field**, so both `PostToolUse` hooks fire on every tool use. Nobody writes that about a system with no hooks. The layout spec was simply stale, which meant the file an agent reads to learn this repo's shape denied the existence of a directory the repo runs. Added, with the matcher limitation stated where an author will hit it.
- **The repo-root README's Prerequisites list omitted `superpowers`.** `prompt-brainstorm:` cedes its Phase 3 to `superpowers:brainstorming`; both Claude editions have listed it as a recommended weak dependency all along and this one never did. Added, along with the distinction that gets the two confused: brainstorming is external, **grilling is not** — that technique is bundled at `dev-workflows/skills/_shared/grilling-technique.md`.

## [2.26.2] — 2026-08-22

### Fixed
- **`api-guideline-reviewer` declared an unused `bash` grant.** The agent reviews OpenAPI specs by
  reading them; it names no executable, and `references/api-guidelines/` holds only markdown and a YAML
  template — there is no script to run. Every other read-only reviewer declares `[view, glob, grep]`, and
  every other `bash` holder either uses it (`code-scanner`, `diff-summarizer`, `docs-grounder`,
  `guideline-reviewer`, `test-baseliner`) or bounds it explicitly (`risk-planner`, `interface-designer`,
  `doc-writer`). This one did neither. Its sibling `guideline-reviewer` keeps `bash`: it genuinely runs
  `references/guidelines/check_guidelines.py`, so the pair now diverges at the agent level for a real
  reason.

## [2.26.1] — 2026-08-22

### Fixed
- **`doc-fixer`'s `NEEDS HUMAN` stop had no consumer anywhere.** The agent has emitted
  `Stop condition flag: [CLEAR | NEEDS HUMAN]` since 1.1.0, and its own hard rules say the caller "reads
  it to decide whether re-running the review is worth doing" and "must surface the deferred BLOCKERs to
  the user and stop the automated cycle". No caller read it: `document:` (both modes) and `epics:` went
  straight from `doc-fixer` to re-invoking the reviewer or the linter. Three unconsumed sites are now
  closed — `document:` Phase 7 (`doc-reviewer`-fed), `document:` Phase 6.4 and direct-mode Phase 3.5
  (`docs-style-checker`-fed, which maps a linter's own blocking failure to `BLOCKER`). The style-cycle
  handlers record the `style_check` row from the user's answer per `skills/_shared/gate-ledger.md`. The
  `epics:` style cycle deliberately gets no handler: `dt-style-checker` caps at `MAJOR`, so `NEEDS HUMAN`
  cannot fire there and a guard would protect a state nothing reaches — `agents/doc-fixer.md` now records
  that reachability map so the absence is not read as an oversight. 2.24.0 fixed exactly this class for
  `review-fixer` across its three callers, but scoped the sweep to `review-fixer` and never asked whether
  the plugin's other fixer emitted the same flag. It did.
- **A `code-review` `BLOCK` caused by an unreadable diff was indistinguishable from a substantive one.**
  2.24.0's read-failure contract had `code-review` return `BLOCK` when the **Diff** evidence input could
  not be read, but gave the verdict no marker — so `implement:`, `vuln:`, and `upgrade:` routed it through
  the ordinary BLOCK branch, triaged a finding that names a capture failure, and handed `review-fixer` a
  finding no fixer can act on, reaching the correct outcome only after spending a fix dispatch and a
  re-review. `code-review` now returns the literal first-line marker `Diff: unreadable at <path>`,
  mirroring `test-writer`'s, and all three skills check that line before acting on the verdict. The
  plugin already treated the three sibling cases this way in these words — an orchestrator bug, not a
  user choice — for `test_diff_file`, `research_file`, and `plan_file`; `review_diff_file` was the
  fourth and was the only one left out.
- **`design:`'s `model_routing` block under-reported its own detection chain.** The `detection_model`
  comment read `# code-scanner` while three agents route on that chain — `code-scanner`,
  `interface-designer` (2.26.0), and `impl-maintenance`. Now names all three.

## [2.26.0] — 2026-08-22

### Added
- **`interface-designer` agent (new).** Produces **one** interface proposal for **one** contested
  interface under **one** named design constraint, read-only, dispatched three times in parallel and
  blind to each other so the takes genuinely diverge instead of converging on what an agent imagines its
  siblings will say. A design's interface is the highest-leverage decision it makes and the hardest to
  walk back once callers depend on it — a single pass tends to anchor on the first workable shape rather
  than surface the trade-off space.
- **`design:` Phase 5 offers a three-take interface fan-out** when the interview reaches an interface
  decision that is **contested** — two or more plausible adapters, a shape spanning a process/network
  boundary, three or more callers sharing it, or two or more recorded candidate shapes with none
  eliminated (`skills/_shared/design-format.md` `## Seams`). The three takes are compared on **depth**
  (behaviour reached per unit of interface a caller must learn), **locality** (where change, bugs, and
  verification concentrate), and **seam placement** (whether the boundary falls where things actually
  vary) — named axes instead of impressions, so the comparison is repeatable. Declining costs nothing:
  the interview continues and `### Alternatives considered` is filled by hand as it always was.
- **`--design-twice`** forces the fan-out even when no contested-interface signal fired: the offer is
  skipped and the three takes are dispatched directly. A user who typed the flag has already given the
  answer the offer would ask for, so re-asking would be a prompt that changes nothing. The offer itself
  carries **no `(Recommended)` marker on either option** — it is shown only once the interface is already
  contested, so no option is safe to recommend across the runs that reach it.
- **`### Alternatives considered` is now unconditional** in `design-format.md`'s
  `## Architecture & components` section — every `design.md` records at least one genuinely rejected alternative and why, whether or
  not the fan-out ran. `risk-planner` already holds plans to this bar ("name at least one alternative
  that was rejected and the reason"); a design was the weaker artifact for not matching it. Making it
  unconditional turns the fan-out into a quality upgrade to a requirement that already fires every time,
  rather than a prerequisite that only exists when the fan-out is chosen — so declining the fan-out never
  reads as skipping a step.
- **Four dependency categories** — `in-process`, `local-substitutable`, `remote-but-owned`,
  `true-external` — now classify each seam in `## Seams` and decide how `## Test strategy` tests it: a
  port with an in-memory adapter for `remote-but-owned`, a mock adapter for `true-external`, no adapter
  needed for the first two. A category implying only one plausible adapter is a hypothetical seam under
  the existing two-adapters heuristic — it should not exist yet.
- **`design-reviewer` gains two checks.** Every named seam's dependency category is cross-checked against
  its test strategy — a `remote-but-owned` seam tested without a port, or a `true-external` dependency
  tested without a mock adapter, is a `MAJOR`; a `MODERATE`+ design with an uncategorized seam is a
  `MINOR`. `### Alternatives considered` must be present **and substantive** — missing is `MAJOR`, and an
  alternative nobody would have shipped ("we considered not having an interface") is `MAJOR` too, because
  it satisfies the check while teaching the reader nothing, which is worse than the check failing openly.
- **The `design:` final report always states the fan-out outcome** — `ran`, `offered and declined`, or
  `not offered — no contested interface`. A run where the signal was too narrow to fire is now visible in
  the report instead of silently indistinguishable from a run where the fan-out was never relevant.

### Fixed
- **The repo README's directory-structure diagram claimed the wrong agent count.** Its `agents/` line read
  `32 sub-agents` — stale by two rounds, and invisible to every count audit run against the spelled-out
  form because it is a bare numeral inside a box-drawing diagram. Now derived from the tree (`34`).

## [2.25.0] — 2026-08-22

### Added
- **Bug-diagnosis evidence gate.** `bug-diagnosis.md` gains a **redaction** section — the discipline has
  you show commands, their output, and captured artifacts, and a HAR file or core dump carries auth
  headers — plus step 1's **completion criterion**: name **one** command you have *already run at least
  once*, showing the invocation and its redacted output. Red-capable, deterministic, fast, agent-runnable.
  *No red-capable command, no step 2.* Flaky bugs get reproduction-rate guidance: raise the rate until the
  bug is debuggable rather than chasing a clean repro.
- **`risk-planner` can now run the repro it reasons about.** It gains ``bash`` for that purpose alone —
  bounded to the repro and read-only commands, never mutating the working tree, index, `HEAD`, or branch
  state. A plan is produced *before* the user has approved any action, so a repro that would itself mutate
  the tree is described rather than run. It must show the repro it ran, or **withhold the ranking** and say
  what it tried; ``implement:`` Phase 2B consumes that with a Help / Proceed-and-record / Cancel choice instead
  of falling through to "Approve & implement now". Ranking a bug's causes without ever observing it reads as
  confident work and is exactly what the criterion exists to prevent.
- **Dispatch bounds on the three agents that hold ``task``.** `docs-style-checker`, `upgrade-executor`,
  and `vuln-fixer` each name their single legitimate target and may never spawn a reviewer. The bound rests
  on **authority, not redundancy**: the caller owns the gate policy, and on some paths it deliberately runs
  no reviewer at all — so a reviewer a worker spawns silently overrides that choice while producing a verdict
  nobody consumes. Each agent cites the mechanism its *own* caller uses — mode for `docs-style-checker`,
  classification for the other two.

### Notes
- `code-review` deliberately does **not** gain ``bash``. Its verdict gates the test run, and its hard rule
  "NEVER modify files" would become unenforceable.
- The upstream rule that reviewers must not route findings through a host findings-reporting tool was
  **considered and dropped**: all eight gating reviewers declare restrictive tool lists, so it could never
  fire. Recorded in `NEXT.md` so it is not re-derived as a gap.

## [2.24.0] — 2026-08-21

### Added
- `skills/_shared/context-management.md` gains a read-failure contract for every input a caller hands over inline or as a path: an unreadable **evidence** input (a diff, a research report, an upgrade plan) is a hard stop that is never regenerated by other means, while an unreadable **context** input degrades to absent and the output records the degradation. Closes a gap where `code-review` could silently re-derive its own `git diff` at the wrong base, or `test-writer` could proceed with no diff at all, both while reporting success. Cited by `implement:`, `vuln:`, and `upgrade:`, and stated by six agents: `risk-planner`, `code-review`, `test-writer`, `review-fixer`, `vuln-fixer`, `upgrade-executor`.
- `code-review`, `doc-reviewer`, and `epic-reviewer` gain an optional `claims_file` input and a final conditional **Claims falsification** dimension (10→11, 17→18, 18→19 dimensions respectively) that runs only after every other dimension is complete and its findings are recorded. The file holds the fixer's or executor's own account of what it changed; the reviewer treats it as testimony, not evidence, and tries to falsify each checkable claim against the diff or files it has already traced independently — so it never reads the account of what the change supposedly did before forming its own view.
- `skills/_shared/finding-triage.md` (new): the orchestrator-run step between an Opus reviewer's findings and a fixer's dispatch. Verifies each finding's claimed consequence at the location it names, keeps or dismisses (recording every dismissal with a reason that disposes of that finding's own claim), and hands the fixer survivors only. Its patch gate blocks a fixer from adding a guard for state the finding did not demonstrate — the most common shape a "fix" for a false positive takes, and the reason it's invisible afterwards (it looks like defensive coding). Attaches only to a reasoned-claim producer feeding a fixer (`code-review`/`doc-reviewer`/`epic-reviewer` → `review-fixer`/`doc-fixer`), never to a style-checker-fed dispatch.
- A triage step citing `finding-triage.md` added to five skills — `implement:`, `document:`, `epics:`, `vuln:`, `upgrade:` — between the reviewer verdict and the fixer dispatch, plus a `### Review triage` section in each final report (findings reviewed, survivors, every dismissal with its reason).
- `skills/_shared/instruction-file-maintenance.md` (new): rules for changing an agent-instruction file (`copilot-instructions.md`, rules files, this plugin's own `skills/_shared/*.md`) — verify every claim against the thing that runs it, itemise a narrowing rewrite as the deletion it is, prefer an observable trigger over one the agent must judge, and require grounds for retirement, never "it looks derivable" or "nothing has failed on it lately". Cited by `impl-maintenance` before it proposes any instruction-file change, and binding on hand edits too — which is where most stale claims originate.

### Changed
- `claims_file` wiring added at the `implement:`, `document:`, and `epics:` re-reviews (passed once a fix cycle produces a Fix Report). At `vuln:` and `upgrade:`, `claims_file` is **relocated** out of the inline review brief: previously `code-review` read the fixer's/executor's account of its own work as part of the same brief everything else came from, before tracing anything. It now arrives as its own temp-file path and is read only in the deferred Claims falsification dimension, after every other dimension is complete.

### Fixed
- `README.md`'s agent table said `code-review` had 8 dimensions and `epic-reviewer` had 9 — both counts were already stale before this round: the actual pre-round counts were 10 (eight base plus the previously-shipped conditional ARD-conformance and spec/design-conformance dimensions) and 18 (the previously-shipped conditional partition-integrity, cross-team-dependency, and team-preserved dimensions among others). Both entries now carry the correct post-round counts (11 and 19); `doc-reviewer`'s entry, which was accurate before this round, moves from 17 to 18.

## [2.23.2] — 2026-08-18

### Fixed
- `ard-resolution.md` now accepts a legacy `### [AD-N]:` heading and emits `AD#N`, matching the
  tolerance `jira-reader` already has. It is a reader, and unlike a VI — which `update-vi:` rewrites —
  an ARD has no `update-ard:` to convert it, so a dash-form ARD authored by a pre-2.53.0 install on
  another machine would never drain. The failure was silent in the worst way: the file still resolves
  `status: found`, but with an empty `invariants` list every consumer's ARD-conformance dimension is
  skipped exactly as if no ARD existed — a binding architecture document enforcing nothing, under a
  run reporting success.
- `scripts/spec-id-baseline.txt` no longer counts `CHANGELOG.md`. Counting it desensitised the
  tripwire — any release note quoting a spec ID shifted the numbers and trained the reader to
  regenerate the baseline instead of investigating. The old header claimed changelog counting was
  what made the three editions comparable; the opposite was true, since the editions keep different
  changelogs. With it excluded, all three editions' baselines are byte-identical, so drift in one is
  now visible as a difference from the other two.

## [2.23.1] — 2026-08-18

### Fixed
- `readiness-reviewer` no longer BLOCKs on a legacy dash-form requirement ID. The previous release
  made it a BLOCKER, which forces a `NOT-SUPPORTED` verdict — but `ready:` reads artifacts it did not
  author, and that same release deliberately left pre-existing artifacts unconverted, to drain as
  `update-vi:` rewrites each one. The rule could therefore only ever fire on the case the design chose
  to tolerate: every canonical VI already under `$SPECS_PATH` would have failed `ready:` on grammar
  alone, while anything freshly authored had already cleared `vi-reviewer` / `ard-reviewer` /
  `epic-reviewer`. It is now a MINOR that never moves the verdict on its own, reported with the fix
  ("convert via `update-vi:`"). The four authoring gates are unchanged and still BLOCK.
- `scripts/check-id-grammar.sh` caught `[US-N]` but missed `[US-n]`, `[AC-x]`, `[SM-Cx]` and bare
  `SM-Cx`: the bracketed branch used the number class `[N0-9]` while the bare branch used `[Nn0-9]`,
  and neither covered the `x` / `X` placeholder. The blind spot had already cost one hand-fix during
  the conversion itself, when `[SM-Cx]` passed the gate green in `vi-reviewer.md`. All four
  alternations now share `[NnXx0-9]`.
- The gate excluded `docs`, `fixtures`, `.remember` and `.superpowers` by bare directory name, so a
  directory with any of those names at any depth — a future `plugins/<name>/docs/` — was silently
  unscanned. The exclusions are now anchored to the scan root.

### Added
- `scripts/check-id-grammar.sh --selftest` asserts the gate's exit code against each fixture, and CI
  runs it before the tree scan. The fixtures shipped in the previous release but nothing executed
  them, so nothing proved the gate could still fail. A new fixture,
  `scripts/fixtures/vi-bad-placeholders.md`, fails *only* on placeholder forms — re-narrowing the
  number class turns the self-test red instead of passing unnoticed.

## [2.23.0] — 2026-08-18

### Changed

- **VI, ARD, and Epic requirement IDs now use `[PREFIX#N]` (`[AC#1]`, `[US#1]`, `[AD#1]`) instead of the dash form `[AC-1]`.** The dash form has the shape of a Jira issue key, so pasting an artifact into Jira auto-linked its criteria to unrelated tickets in any project sharing the prefix, and the vault importer rewrote them into `[[[AC-1]]]` on export. `vi-reviewer`, `ard-reviewer`, `epic-reviewer`, and `readiness-reviewer` now treat a surviving dash-form ID as a BLOCKER (for `readiness-reviewer`, that means a `NOT-SUPPORTED` verdict).
- **`epic-writer`'s `## Covers` now emits bracketed IDs** (e.g. `[US#2]`, `[AC#4]`) instead of the bare `US-2, AC-4` that both Jira and the importer mangled the same way.
- **`jira-reader` accepts both grammars inside requirement-bearing sections and always emits the `#` form,** so a VI already published under the dash form still parses; elsewhere (notably `## References / linked issues`) a `KEY-123` token is still read as a real Jira key, never as a legacy requirement ID.

### Added

- **`skills/_shared/pre-lint.md` gains a `## Jira-key collision` check for VI, ARD, and Epic files.** Flags any `\b[A-Z]{2,10}-[0-9]+\b` token surviving outside a wikilink, a markdown link, or a fenced code block — inline code is deliberately NOT excluded, since there is no tested evidence Jira leaves an inline-code key unlinked. Scans the VI and ARD below their frontmatter (which legitimately carries `jira_key:`/`ref:`/`seeded_from_vi:`/`revision_of:`) and the whole Epic file (no frontmatter there). Every surviving hit falls into one of three branches: a requirement ID is a BLOCKER fixed mechanically under the standard pre-lint contract; a real ticket is a BLOCKER wrapped as a wikilink after confirming the key; a standards or protocol reference such as `ISO-8601` or `RFC-8446` is a MINOR, reported and left exactly as written — never converted, never wrapped. `pre-lint.md`'s contract sentence and the four skills producing those artifacts (`create-vi:`, `update-vi:`, `create-ard:`, `epics:`) name the check explicitly, so it actually runs; `specify:` and `design:` do not, because its scope excludes `specification.md` / `design.md`. Pre-lint itself stays advisory.
- **`scripts/check-id-grammar.sh` (+ `scripts/fixtures/vi-good.md`/`vi-bad.md`) gates this repo against reintroducing the dash form.** `scripts/spec-id-baseline.txt` records a census of the separate, unrelated `specify:`/`design:` numbered-ID namespace (untouched by this change) so a future change can be diffed against it and confirmed to have left that namespace alone. The gate runs on every push via `.github/workflows/validate-catalog.yml`, and `.github/copilot-instructions.md` documents the grammar it enforces.

## [2.22.0] — 2026-08-15

### Breaking changes

- **`create-vi:` no longer relocates `idea.md`.** `idea:` now owns relocation and hands the idea off itself. `create-vi: <KEY>` derives the idea from `specifications/<KEY>-<slug>/idea.md` and requires it on the specs repo's default branch. `create-vi: <KEY> @<path>` is explicitly out-of-contract: it reads the idea where it sits, does not move it, and is not gated. A run that previously passed `@<path>` for a vault idea keeps working; a run that relied on `create-vi:` moving the file must now let `idea:` do it.

### Added

- **New shared reference `skills/_shared/phase-handoff.md`, with two entry points.** `handoff-to-main` (§2, the producer side) resolves or reuses a plugin branch, stages the deliverable by enumeration, commits with a carried `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer, pushes, and opens a pull request via a `gh` capability probe rather than a host-type classification. `require-on-main` (§3, the consumer side) is a ten-state gate — rows H/I/G/A/B/C′/C/D/E/F, first matching row applies — tested against `origin/<default>` by ref rather than by worktree contents. §3.4 carries the row-F delegation table naming each caller's pre-existing absent-input behaviour, so a gate never turns an optional artifact into a hard prerequisite; §4.1 defines the single `Phase handoff:` outcome line every producer emits exactly once; §4.3 defines the three-choice consent array (`Branch + commit + push + open PR` / `Just write the files` / `Cancel`) every producer presents verbatim. It inherits four of `specs-repo-git.md`'s hard rules unchanged and deliberately diverges on three: `require-on-main` is fatal by design (a gate that reports and continues is not a gate), the deliverable commit carries the `Co-authored-by` trailer `specs-repo-git.md` forbids for bookkeeping commits, and `handoff-to-main` runs only behind the caller's own consent choice rather than prompt-free.
- **Eight producers now commit, push, and open a pull request for their deliverable, via `handoff-to-main`.** `idea:` (Phase 5, on a completed handoff — relocating `idea.md` into `$SPECS_PATH` first), `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, a new Phase 4.5 in `implement:` (for the spec/design-conformance notes step 7.5 writes back), and a new handoff step in `ready:`'s Phase 5 (for its `_readiness.md` snapshot).
- **Seven consumers refuse to proceed until the artifact they depend on is on the default branch, via `require-on-main`.** `create-vi:` (its own `idea.md`), `create-ard:` (the VI), `specify:` (the VI), `design:` (`specification.md`, gated at both the flat and per-Epic resolution points), `implement:` (its in-scope `specification.md`/`design.md`), `epics:` (the VI-level `specification.md`), and `ready:` (every `specification.md`/`design.md` in its artifact inventory). An absent optional input still delegates to each command's pre-existing behaviour per §3.4's row F — `idea:` stays optional for `create-vi:`, `create-ard:` still falls back to `jira-reader`, and VI-level `specify:` grounding is still just skipped, never gated. `update-vi:` deliberately never calls `require-on-main` at all: its authoritative base is the Jira import, and gating its read-only secondary grounding would block a legitimate refresh over an unrelated branch.
- **`skills/_shared/ard-resolution.md` gains `status: unmerged`, alongside the existing `found`/`none`.** Reachable only when an ARD file resolves but is not yet on the specs repo's default branch (verified via `phase-handoff.md` §3), carrying the resolved `branch` and any open `pr` through to the caller. Every caller stops on it except `ready:`, which records "ARD authored, not handed off" as a readiness finding capping the verdict at `PARTIAL` — reporting that distinction is the one thing `ready:` exists to do. `status: none` is unchanged: the no-regression rule still guarantees a run with no ARD at all is byte-identical to before this feature.
- **Two new branch prefixes, `idea/` and `ready/`.** `skills/_shared/specs-repo-git.md`'s plugin-owned-branch authority is now `^(idea|vi|ard|spec|design|ready)/` everywhere it is declared — the hard rules (§1 rule 3), §2.2, the G2 stop-notice table row, and the branch-key-extraction list that strips a caller's prefix before matching a run's key set.

### Fixed

- **`design:`'s on-main gate was a worktree file-existence check at both the sites that need it, so a branch carrying an unmerged `specification.md` passed it.** Phase 0 step 3's target resolution now executes `require-on-main` against the resolved path and stops on any non-`pass`/`pass_amending` state; the Epic picker (step 4) now enumerates spec'd Epics with `git cat-file -e "origin/<default>:…"` directly, so an Epic whose `specification.md` exists only on a branch is excluded from the picker (and counted separately, with its own reason) instead of being offered as selectable.
- **`implement:`'s Phase 7.5 spec/design-conformance notes and `ready:`'s `_readiness.md` snapshot previously had no commit path of their own, so they sat uncommitted in the specs repo indefinitely** — tripping `specs-repo-git.md`'s dirty-OTHER-path advisory on every subsequent run instead of ever reaching anyone who could act on them. `implement:` gains a new Phase 4.5 that hands the annotated `specification.md`/`design.md` off via `handoff-to-main`, placed after Phase 4's maintenance and before Phase 6's follow-ups — calling it from inside Phase 3B, where step 7.5 writes the notes, would commit mid-review. `ready:` hands `_readiness.md` off at its Phase 5 step 3, behind the same consent choice, without ever stopping on the outcome itself — an unmerged or missing artifact becomes a readiness finding, never a run-stopping gate, because reporting readiness is `ready:`'s whole function.
- **The "never opens a PR" statements in `finish-and-handoff.md`, `specs-repo-git.md`, and `document:`'s host footer read as a blanket policy; they were only ever a host-capability limit.** Bitbucket — the docs-repo host `finish-and-handoff.md` and `document:` govern — has no CLI that can open a pull request, so that flow still only writes a draft plus a footer instruction. The GitHub-hosted specs repo does have one: `phase-handoff.md` §2.6 opens the pull request there through a capability probe (attempt `gh pr create`, fall back to the manual-open instructions on any failure) rather than a host-type classification, because push authority and pull-request authority can differ for the same account even on the same host.

### Not ported

Ported from `ihudak-claude-plugins` dev-workflows 2.52.0. `.github/copilot-instructions.md` has no per-command "Key invariants" depth for every consumer/producer the source repo's `CLAUDE.md` documents at that granularity (e.g. per-row `phase-handoff.md` §3.3 state citations inside `specify:`/`create-ard:`/`epics:`'s own invariant bullets) — this edition's instructions file covers the shared reference, the six-prefix authority, and the `idea:`/`create-vi:`/`ready:` grammar changes at its own established level of detail, not a line-for-line mirror of the source repo's much longer `CLAUDE.md`.

## [2.21.0] — 2026-08-13

### Fixed

- **`document:` doc-edit mode was documented as running a `doc-reviewer` gate it never dispatches.** `skills/document/SKILL.md`'s shared mode-preamble sentence and `.github/copilot-instructions.md`'s skill-relationships map and doc-edit-mode invariants all described doc-edit mode as sharing `doc-reviewer` with jira mode. Its own phase list (`Phase 0` → `Phase 6`) never dispatches one — the only gate is the mandatory `Phase 3.5` style check plus `doc-fixer`, with no BLOCKER fix cycle and no re-review. All three now say so explicitly.
- **`.github/copilot-instructions.md`'s skill-relationships map and agent ledger were stale in several places**, the same drift class as the source repo's `CLAUDE.md` fix: `upgrade:`'s pipeline line omitted `risk-planner`, even though `skills/upgrade/SKILL.md` dispatches it directly for SIGNIFICANT/HIGH-RISK components; the `test-baseliner` ledger row credited only `upgrade-executor`/`vuln-fixer`, missing that `upgrade:` and `vuln:` also call it directly at their own Phase 1/2; the `risk-planner` row omitted `upgrade:`; the `doc-reviewer` row wrongly credited doc-edit `Phase 3.5` (see above); the `docs-style-checker` row omitted doc-edit mode's own `Phase 3.5` dispatch; and the jira-mode/epics branch-policy bullet still described the old binary `git_repo`/`plain_dir` model instead of the `docs_repo`/`non_docs_repo` split `skills/document/SKILL.md` Phase 0 step 6 already implements. All corrected against the actual dispatch sites.
- **Five more agent/reference "used by" lists carried the same drift.** `skills/_shared/feedback-emission.md` said the automatic maintenance phase covers "twelve" workflow skills when it covers thirteen (missing `update-vi:`); `README.md`'s "Automatic" feedback bullet and its `jira-reader` agent-table row had the same gap plus a missing `create-ard:`/`specify:`/`ready:` set; `agents/risk-planner.md` named `vuln:` as a caller, which never dispatches it; `agents/vi-reviewer.md` omitted `update-vi:` Phase 4; `agents/jira-reader.md` and `agents/diff-summarizer.md`'s callers omitted `create-ard:` and `ready:`; `skills/_shared/grilling-technique.md`'s bounded/relentless lists omitted `prompt-grill-me:`, `update-vi:`, and `create-ard:`; `skills/_shared/jira-input-resolution.md` omitted `idea-reader` as a `resolve-export-for-key` consumer; and `skills/_shared/ard-resolution.md`'s Consumers list gained `ready:`, which resolves an applicable ARD in its own Phase 2.5 and checks artifacts against it.
- **`document:`'s "no refresh" repo-refresh choice did nothing.** Phase 1 offered three choices (`fetch only`, `fetch + pull default branch`, `no refresh`), but the Phase 5 dispatch block hardcoded `fetch: true` regardless of which one was picked. The dispatch now sends `fetch: false` only when "no refresh" was chosen (and `pull: true` only for "fetch + pull"), and the choice label now states its consequence up front.
- **`diff-summarizer`'s GitHub (`gh` CLI) resolver fetched unconditionally, defeating the fix above.** When a PR's head/base commits were missing locally, the resolver always ran `git fetch` (falling back to `gh pr checkout`) regardless of `refresh.fetch` or a read-only mount. It now runs those writes only when `refresh.fetch` is true **and** the mount is not read-only; otherwise it records the PR under `unresolved_prs` with a reason instead.
- **Two SSOT promises overstated what their non-primary producer actually does.** `skills/_shared/read-only-repos.md` said every consuming agent emits its §6 `prep` block, but `docs-grounder` returns a digest, not a `prep` block — narrowed to name `code-scanner` and `diff-summarizer` as the `prep` emitters, with `docs-grounder` following only §1–§4. `skills/_shared/source-truth.md` §4.1 assigned `diff-summarizer` the duty of surfacing enum/schema/constant/label changes in its PR summary — a duty its own agent spec never implements — reassigned to `doc-planner`, which verifies those claims directly against shipped source.
- **`README.md` carried six of its own stale mirrors of corrections already made in the `skills/_shared/` reference files above.** A first pass at this release ported the reference-file fixes but missed that `README.md`'s "Reference docs" catalog and "Environment prerequisites" section restate several of the same claims in prose, and those mirrors drifted independently: the `read-only-repos.md` catalog entry (still claiming `docs-grounder` emits a `prep` block — the exact claim just fixed above, unfixed one line away), the "Follow-up task emission" bullet (omitted `ready:`), the `ard-resolution.md` catalog entry (omitted `ready:`), the `grilling-technique.md` catalog entry (omitted `create-ard:`), the `followup-emission.md` catalog entry (omitted `ready:`), and the "Architecture (ARD) consumption" paragraph (omitted `epics:` and `ready:`, and its BLOCKER language didn't cover an Epic draft or `ready:`'s read-only verdict). All six corrected in a follow-up pass; `README.md`'s "Automatic" feedback bullet and `jira-reader` agent-table row (already listed above) were the only two of the eight canonical `README.md` corrections that landed on the first pass.
- **`ready:` ran its dirty-tree/branch prompt before the preflight that would have cleared the dirt it was warning about.** The specs-repo preflight (which flushes leftover session artifacts and settles the branch) sat after the dirty-tree check in Phase 0, so none of that check's choices could actually resolve state the preflight was about to fix. The preflight now runs immediately after `$SPECS_PATH` resolution, ahead of the dirty-tree check.
- **`release-notes:`'s terminal phases ran in the wrong order.** Phase 9 emitted follow-up tasks and Phase 10 ran feedback — the reverse of every other skill's feedback-then-follow-ups order. The phases are swapped (feedback is now Phase 9, follow-ups plus the resume pointer and `commit-artifacts` are now Phase 10), and `skills/_shared/session-hygiene.md` rule 2 now names the binding "emitter tail" (feedback → follow-ups → `resume.md` → `commit-artifacts`) explicitly, clarifying that a skill's deliverable-side finish may land at any point before that tail without consequence.
- **`idea:`'s round-2 narrow code-scan didn't state its `refresh:` posture, risking a silent default.** Round 2 reused round 1's `capability_themes` and `search_hints` but never named the `refresh:` block, so a round-2 dispatch could pick up default (not-read-only) behavior instead of round 1's pinned read-only posture. `skills/_shared/model-routing.md` §8.5 now states that round 2 reuses round 1's `refresh:` block verbatim, and `skills/idea/SKILL.md`'s own round-2 paragraph says the same.
- **`idea:`'s bounded grill was still capped at ≤5 questions across five citing files**, well under the cap later skills were built to expect. Raised to ≤10 in `skills/idea/SKILL.md`, `skills/_shared/grilling-technique.md`, `skills/_shared/docs-grounding.md`, and `skills/_shared/vault-prior-art.md` (`README.md` never hardcoded the number, so it needed no change). `grilling-technique.md`'s ambiguity-taxonomy sentence now names each caller's own stated bound instead of a specific number, so `prompt-grill-me:`'s still-≤5 bound stays correctly described.
- **§8.5's "outside-deferral" rule was written as a blanket rule but only holds for one caller.** A theme confirmed `absent` was called "resolved" only if nothing was deferred to a repo outside the scanned set — correct for `implement:`, whose premise is that the capability lives somewhere in-scope, but wrong for `idea:`, where the confirmed repo set *is* the whole world it grounds against. `skills/_shared/model-routing.md` §8.5 now scopes the outside-deferral qualifier to `implement:` only; `idea:`'s `absent` findings resolve unconditionally. `skills/_shared/idea-format.md`'s `sources[].provenance` enum also gained the `doc-grounding` value it was missing.
- **`skills/_shared/model-routing.md`'s must-load roster omitted `update-vi:`**, undercounting the pipeline skills that load and follow the policy — corrected 13 → 14, matching `update-vi:`'s own Phase 0 dispatch.
- **`skills/_shared/source-truth.md`'s own "sub-agent that synthesises documentation" sentence was stale by one name.** It listed `doc-planner`, `doc-reviewer`, and `release-notes-writer`, omitting `doc-writer` — which writes the documentation the other three plan, verify, and draft. Added `doc-writer`. `risk-planner` — also a `source-truth.md` consumer (it cites the file's §7 escalation rule while risk-planning code changes for `implement:` and `upgrade:`) — was deliberately left out of this specific sentence: its deliverable is an implementation plan, not documentation, so it falls outside "sub-agent that synthesises documentation."
- **Whole-branch review fix wave (five Minors on live plugin surfaces).** `agents/vi-reviewer.md`'s frontmatter `description` and body opening still said the reviewer is for VIs "authored by `create-vi:`" after an earlier fix corrected only the "Invoked from" line — both now also name `update-vi:`. `agents/risk-planner.md` still said "For upgrade/vuln work," though `vuln:` never dispatches this agent (confirmed via `grep -rl 'risk-planner' skills/*/SKILL.md` → `implement:`, `upgrade:` only) — narrowed to "For upgrade work." `skills/_shared/session-hygiene.md` rule 2 said a deliverable-side finish "may precede the tail," contradicting its own `document:` example (`Phase 8.5 — Finish & handoff` sits *between* feedback and follow-ups) — reworded to "may sit anywhere relative to the tail, including between its members." `.github/copilot-instructions.md` has no equivalent of the canonical-terminal-order clarification the source repo's `CLAUDE.md` needed — checked and left as-is. `agents/diff-summarizer.md` already read "item 2 below" (correct) from its earlier port adaptation — checked and left unchanged.

### Not ported

Ported from `ihudak-claude-plugins` dev-workflows 2.51.0. The source repo's `references/cost-emission.md` and `cost-prices.yaml` fixes (unpriced-model dominance warning, maintainer checklist, `update-vi:` added to the cost-emission roster) have no counterpart on this side — this edition carries no session-cost subsystem at all (see `README.md`'s "Not ported from the Claude Code edition"). The source repo's new `CLAUDE.md` convention bullet on writing an SDD sub-project's verification record last has no structural equivalent here either — `.github/copilot-instructions.md` has no process/conventions section covering plan-verification discipline, only plugin/skill structure. Several other `CLAUDE.md` roster corrections (the VI-creation-flow grill-bound and ARD-consumption invariants, the `$DOCS_PATH` grounding invariants, the bug-report-draft decision-name rename) also have no equivalent section in `.github/copilot-instructions.md`, which documents only the three code orchestrators and `document:`/`epics:` at this level of detail.

## [2.20.0] — 2026-08-12

### Added

- **`implement:` adopts `skills/_shared/model-routing.md` §8.5 — the seeded narrow second scan round.** Phase 1.7's fan-out previously ran one broad `code-scanner` per repo and stopped. A theme its round 1 leaves **inconclusive** — `classification` `partial`/`absent`/`error`, or two or more scanners whose per-theme `capability_map[].gap_summary` texts point at each other's repo in a cycle, or at a component/subsystem no scanned repo covers — now gets one narrow round 2 on the §2.1 detection chain, with `capability_themes` holding a single question and `search_hints` seeded from round 1's verified `evidence[].path`/`.symbols` (and the `<path>:<line>` anchor named in the `context` prose where `lines` is present), when round 1 left at least one anchor to seed from. Cap 4 dispatches, one round only, no round 3. This matters more here than in `idea:`, §8.5's first consumer: `idea:`'s summary feeds a grill with a human in it, while this one feeds `risk-planner`, whose output becomes code.

### Fixed

- **Phase 1.7's synthesis flattened uncertainty into false confidence — including the anchorless case round 2 can never reach.** Step 4 said only to combine the scanner reports into "relevant files, existing capabilities, gaps" — so two scanners each concluding "it must be in the other repo" were folded in as two ordinary **gaps**, and the planner received a summary that looked settled. The summary now carries a `## Unresolved` section naming **every** theme still inconclusive at the end of Phase 1.7, explicitly including one that never entered round 2 for lack of an anchor. A gap asserts the capability is absent with nowhere else it could be; an unresolved theme asserts only that the scan could not tell, and once flattened the two are indistinguishable downstream.
- **`risk-planner` was never told which findings were uncertain.** Phase 2B's dispatch gained an `Unresolved scan themes:` field, but `agents/risk-planner.md`'s `## Inputs` had no bullet for it and its `### Risks considered during planning` template had nowhere for an unresolved theme to go. The agent now declares the field (optional; never a confirmed gap or a confirmed capability) and carries an `Unresolved scan themes` bullet in the risks template, with an explicit "none" form so a brief without the field still satisfies the exact shape.
- **The mutual-deferral trigger assumed exactly two scanners.** `skills/implement/SKILL.md` and `skills/_shared/model-routing.md` §8.5 both defined it as two scanners naming each other's repo or layer, missing a three-or-more-repo deferral cycle and a one-way deferral to a repo outside the scanned set. Both now read "two or more … in a cycle, or at a repo/component no scanned repo covers," and name the per-theme `capability_map[].gap_summary` field explicitly (the schema also has an unrelated top-level `gap_summary`). `skills/idea/SKILL.md`'s own paraphrase of §8.5 carried the same stale wording and is reconciled the same way.
- **`skills/_shared/model-routing.md` §8.5's own consumer list was stale.** Its Opt-in paragraph said `idea:` was "its first and only current consumer" and that `implement:` "runs §8.2 alone and is unaffected"; it now names both consumers, leaving `epics:`, `create-ard:`, `specify:`, and `design:` correctly listed as unaffected. §8.5 also gains a **"Round 2 resolves; it does not license a guess"** rule binding every adopter to name what stayed unresolved in whatever it passes downstream — `idea:` into `[NEEDS CLARIFICATION]`, `implement:` into the summary and the plan's risks.
- **`implement:`'s own invariants list never got the rule it was built to enforce.** Added a `WHEN fan_out is true and a theme stays inconclusive:` line alongside the file's existing per-feature invariant bullets.
- **`agents/code-scanner.md` and `dev-workflows/README.md` carried the same stale claim** — the `code-scanner` description/body credited only `idea:` with "broad-then-narrow per §8.5," and the README's `code-scanner` row didn't mention the round-2 behavior at all; both are reconciled. Ported from `ihudak-claude-plugins` dev-workflows 2.50.0; `.github/copilot-instructions.md` has no structural equivalent for the source repo's `CLAUDE.md` fan-out-policy bullet or multi-source invariant bullets (no jira-reader/multi-source content exists there for `implement:`), so those edits were not ported.

## [2.19.0] — 2026-08-12

### Added

- **`--ground-code [<repo>,…]` on `idea:`, and a new Phase 2.6 — Code grounding (optional).** Bare, the flag derives a repo set from the idea's themes and the directories under `${REPOS_PATH:-/workspace}` behind one confirm gate; given a value, it scans exactly those repos. Round 1 is the standard `code-scanner` fan-out (batches of up to 4 concurrent agents per task message); round 2 applies `skills/_shared/model-routing.md` §8.5 — a seeded narrow follow-up, capped at 4 dispatches, for each theme round 1 left inconclusive, with `search_hints` seeded from round 1's verified `evidence[].path` / `.symbols` (a `lines` anchor is named as `<path>:<line>` in the round-2 `context` prose, since `search_hints` has no line-number field). There is no round 3. Off by default and never auto-triggered: a run that names a mounted repo without the flag gets one inline suggestion line, never a prompt.
- **`skills/_shared/model-routing.md` §8.5 "Broad, then narrow (the seeded second round)"** — the shared, opt-in procedure behind the second round above. `idea:` (Phase 2.6) is its first and only current consumer; `implement:`, `epics:`, `create-ard:`, `specify:`, and `design:` still run §8.2 alone.
- **`## Feasibility grounding` — Section 7 of `skills/_shared/idea-format.md`** (optional; renumbers the former Section 7 `Open questions & assumptions` to 8 and Section 8 `Candidate success signal` to 9). Written only when Phase 2.6 ran and returned at least one finding; opens with each grounded repo as `<repo>@<scanned_ref>`, then up to three optional slots (What exists / What's missing / Reframing), every bullet carrying a `<repo>/<path>:<line>` citation. Section 5 `Signals & evidence` gains a rule that code findings never go there — they belong in Section 7, since that section is demand evidence only.
- **`evidence[].lines`, an optional field on `code-scanner`'s handoff schema and agent instructions** (`skills/_shared/handoff/code-scanner.md`, `agents/code-scanner.md`). Present with the 1-based line numbers when an evidence entry came from a grep hit; absent for a path glob or whole-file read; meaningful only together with `scanned_ref`, since a line number moves with the ref it was read at.
- **`## When a choice list fires` in `skills/_shared/escalation-rules.md`** — a third plugin-wide rule: a choice list blocks whenever shown, a list is shown only when its firing condition holds, a list for a question whose answer is already determined is a defect, and the inline-confirmation form (one line, states the resolution, proceeds without waiting) is the correct shape for an unambiguous case.

### Changed

- **`idea:` Phase 1's single unconditional confirmation became two conditional choice lists plus an inline confirmation**, applying the new "When a choice list fires" rule. Case A fires only when a resolved key's `issue_type` is neither `ValueIncrement` nor `Product Need`. Case B fires only when the argument is path-like (contains `/`, ends in `.md`, or starts with `@`) but resolved to no existing file — fixing a real defect: without this gate the path string fell through to the `prompt` branch and was ingested as the idea's raw text, so a mistyped path became prose. Every other case — a resolving path/wikilink, a key typed `ValueIncrement`/`Product Need`, or plain prose — now gets a one-line inline confirmation instead of a list with one plausible answer.
- **`skills/_shared/escalation-rules.md`'s `## Repo missing (after resolution)` list was replaced.** The old list (`"Stash changes and retry this repo"`, `"Skip this repo"`, `"Cancel"`) had no option for the case its own trigger names — a clone whose `origin` slug doesn't match `repo_url_slug`. The new list (`"Skip this repo"`, `"I'll clone it — wait"`, `"Specify a different absolute path for this repo"`, `"Cancel"`, `"Other… (describe)"`) adds that option and carries no `(Recommended)` marker, since which option is right depends entirely on why the repo is absent. Cited by `document:`, `create-ard:`, `release-notes:`, `epics:`, `specify:` (pre-existing), and — newly — `idea:` (Phase 2.6, which has no earlier check) and `implement:` (Phase 1.7, which previously only surfaced `DIRTY_TREE`/`REFRESH_BLOCKED` as a pair and never named `REPO_MISSING` at all, nor offered a way forward for any of the three — §8.4).

## [2.18.0] — 2026-08-11

### Added

- **`vault-prior-art-finder` agent and `skills/_shared/vault-prior-art.md`.** `idea:` and `create-vi:` now look for prior art on purpose instead of finding it by accident. The read-only agent searches `Projects/Products/**` and `Projects/ideas/**` for tracked initiatives that cover, precede, parallel, or are rewritten by the new work, and returns each match classified by relation, resolved to a Jira status, and summarised — plus reconciliation challenges and a write-path area proposal. There is no retrieval index and no consent gate: the corpus is a few hundred markdown files and retrieval is `glob`/`grep`. Advisory only, never a gate.
- **`resolve-export-for-key` entry point in `skills/_shared/jira-input-resolution.md`.** Locates the export for one exact key at any depth, and takes the most recently modified copy when several exist — the same key can legitimately appear under multiple parents, and those copies can disagree. Distinct from the existing VI-selector rule, which deliberately resolves a nested Epic *up to its parent*; this one never walks upward.
- **`## Prior art` section in `skills/_shared/idea-format.md`.** The durable carrier for what the finder discovered — one bullet per initiative, carrying both a wikilink and a Jira key because a wikilink resolves by file name and dangles the moment a vault item is renamed. Every slot is transcribed from the digest rather than invented.
- **`--no-prior-art` off switch** on `idea:` and `create-vi:`, alongside the existing `--no-docs`.

### Changed

- **Both skills dispatch `docs-grounder` and `vault-prior-art-finder` in a single response at Phase 2.5**, so the two grounding reads run in parallel and neither being off suppresses the other. The grill then ranks both challenge sets into its existing Impact × Uncertainty gap list, where they **compete** for the bounded question slots rather than adding any — `idea:`'s ≤5-question bound is unchanged.
- **`idea-reader` returns a `salient_summary` for every followed wikilink and source reference.** It already read those files; summarising what is in its context saves the orchestrator re-reading them, which is the most expensive place to put a read. A `vi` source additionally returns a `tracked` block carrying the item's `issue_type`, `status`, and `summary`.
- **`idea:`'s write path derives a container from the source's own location** instead of flattening every idea to `Projects/<Products|ideas>/<slug>/`. A source already sitting under a `Projects/Products/` grouper now lands beside its neighbours, matching the convention the vault already follows — with no prior-art match required. On top of that, one assembled gate offers a rewrite target and a high-confidence area proposal when either exists, and records the answer as `vi_disposition`.
- **`create-vi:`'s `Usage:` line names both grounding off switches**, and the README documents vault prior-art grounding in one section-level paragraph beside the `$DOCS_PATH` one.

### Fixed

- **`idea:` classified every Jira key as `rfe`, reading a Value Increment as a demand ticket.** Phase 1 now types the source from the export's `issue_type` frontmatter — `ValueIncrement` → `vi`, `Product Need` → `rfe`, anything else surfaces the actual type and asks — never from the project prefix, which is a coincidence of Jira configuration. A `vi` source is prior art: `idea-reader` distills its problem, goal, and scope instead of mining it for requesters and upvotes that a Value Increment does not have.
- **Key lookup assumed a top-level `jira-products/<KEY>/` directory.** The export tree nests by hierarchy, so a key that exists only as a nested child returned `NOT_FOUND`.
- **The next-phase offer always said "first create an empty Jira workitem".** When the idea rewrites the Value Increment it came from — same goal, different approach, same key — that instructed the user to mint a key they must not mint. The offer is now driven by `vi_disposition`.
- **Classification stripped only `--deep`** while the skill honours four flags, so `--no-prior-art` and the rest landed inside the classified idea text and reached `idea-reader` as though the user had typed them.
- **The `--as` future-work note advertised a `file` source type that never existed** and omitted the new `vi`.
- **The Phase 4 gate's `(Recommended)` marker could name a row absent from the array.** The marker is derived from the top prior-art match's relation, but the rows it can name are conditional — and the gate can fire with no match at all, since a `vi` source alone opens it. Every derivation branch now falls back to row 3, the only always-present destination, so the gate can never render with nothing marked.
- **Several user-facing descriptions still advertised "an exported RFE Jira ticket" as the only Jira source** — the `idea-reader` agent description, the `idea:` skill description, and two README rows — after the widening above made that false.
- **`skills/_shared/workflow-states.md` spelled a status `Use cases defined` where Jira and every export emit `Usecases defined`.** `readiness-reviewer` string-matches against that table, so the rung never matched.

## [2.17.1] — 2026-08-11

### Fixed

- **`epics:` discarded its documentation grounding whenever code scan was off — after asking the user to pay for it.** Phase 4 and Phase 5 both say "If code scan is OFF, skip to Phase 6", and `dispatch-docs-grounder` sat inside Phase 5, so the digest was never produced on those runs even though its own text claimed it "runs even when code scan is OFF". 2.17.0 sharpened the consequence rather than causing it: moving `resolve-docs-grounding` to Phase 2 meant the run could prompt for a one-time index build and then skip the dispatch that would have used it. The dispatch is now its own **Phase 3.6**, before both conditional phases — it only ever needed Phase 3's VI goal and `jira-reader` themes, never the code scan.

## [2.17.0] — 2026-08-11

### Fixed

- `docs-grounder` no longer builds the qmd index. It probes (`qmd status`, `qmd collection list`) and selects a retrieval rung: `qmd-vector` (`qmd search` + `qmd vsearch`, when the collection has embeddings), `qmd-lexical` (`qmd search` alone), or `fallback`. `qmd query` is never invoked — it is the only entry point needing the reranking and query-expansion models, which no cheap probe can prove are cached. Previously the agent was instructed to "self-heal" with `qmd collection add` + `qmd embed`, which on a fresh container means a ~1.3 GB model download and embedding every page in `$DOCS_PATH` on the user's critical path.
- The keyword fallback is bounded — 3–8 keywords, generic keywords dropped above 200 matching files, shortlist capped at 40 — so the qmd fix does not relocate the cost into an unbounded scan.
- `code-scanner` and `diff-summarizer` no longer fail on read-only mounts, where `git switch` and `git fetch` cannot write. They read at `origin/<default>` via `git ls-tree` / `git grep <ref>` / `git show <ref>:<path>` instead of returning `REFRESH_BLOCKED`, and skip the dirty-tree gate, since the working tree is never mutated. Writable mounts are unchanged. Both agents report `prep.read_only`, `prep.scanned_ref`, `prep.ref_committed_at`, and `prep.head_divergence`. Two of the twelve repository clones in the AI container are read-only mounts today.
- `create-ard:` and `release-notes:` gain their first handling for `REPO_MISSING` / `DIRTY_TREE` / `REFRESH_BLOCKED`; `epics:` gains the `docs grounding:` line it never printed.

### Added

- New `skills/_shared/read-only-repos.md`, the single source of truth for read-only mounts: the detection probe, what read-only mode skips, write-free ref resolution and reading, the escalation trigger, and the `prep` output contract. Consumed by `code-scanner`, `diff-summarizer` and `docs-grounder`, and cited by the seven skills that dispatch them.
- New `Read-only mount — ref stale or diverged` escalation, fired only when the ref is more than 14 days old or the working tree is ahead of it, offering a host-side `git fetch` or a read-write re-mount.

### Changed

- Index building and refreshing move into `resolve-docs-grounding` step 3.5, where the user can consent: an existing collection gets a bounded incremental `qmd update`, a missing one gets a one-time build prompt. An agent cannot ask the user; the orchestrator can.
- The `docs grounding:` line now reports the retrieval rung, a stale docs checkout, a capped index refresh, and a project-local `.qmd` index shadowing the user-scope one.

## [2.16.1] — 2026-08-11

### Fixed

- **Four shared references addressed skills in the Claude edition's idiom.** `docs-grounding.md`, `gate-ledger.md`, `repo-verification-gates.md`, and `toolchain-preflight.md` wrote `/document`, `/idea`, `/create-vi` and friends where every other `_shared` reference in this edition writes `document:`, `idea:`, `create-vi:`. Slash-style invocation works here, so nothing was broken — but a reader learning the idiom from these files would learn the wrong one, and `/release-notes`, `/upgrade` and `/feedback` collide with Copilot's own built-ins. 32 references converted (31 backticked, plus one unbackticked inside a YAML comment); `next-phase-offer.md` rule 6 keeps its slash-style citations of Copilot's built-in names, which are correct as they stand.

## [2.16.0] — 2026-08-11

### Fixed

- **The printed-name contract is now stated, before it is needed.** Slash-style invocation works in this edition, so a printed `/release-notes` is not broken — but Copilot registers its own built-in slash commands, and three of them collide with skill names shipped here: `/release-notes`, `/upgrade`, and `/feedback`. In a collision the built-in wins, and `/feedback` is a collision the Claude edition does not have. A sweep of every printed surface — next-step sections, `choices:` arrays, quoted handoffs, inline recommendations, role-handoff hygiene lines, and STOP messages carrying a re-run instruction — found this edition **already** using the `<name>:` idiom throughout, so no printed text needed converting. `skills/_shared/next-phase-offer.md` rule 6 now states the contract explicitly so it stays that way, and records the three colliding names.
- **`update-vi:` cited a routing graph it did not appear in.** `skills/update-vi/SKILL.md` names `skills/_shared/next-phase-offer.md` as the authority for its Phase 6 offer, and that file had never mentioned it. It now appears as a PM re-entry node.
- **`create-vi:` cited the wrong `epics:` phase.** Its Phase 3.5 style check said it mirrored `epics:` Phase 6.1 (*Resolve clarifications*); the style check is Phase 6.2.

## [2.15.0] — 2026-08-10

### Fixed

- **`$SPECS_PATH` is a git repository that no skill ever committed.** Seventeen of the twenty skills write bookkeeping artifacts into it — feedback, follow-ups, resume pointers — and none of them committed those artifacts. The five VI-authoring skills that do run git against the specs repo (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`) commit only their own deliverable, at a handoff phase that fires *before* the artifacts are written, so the artifacts stayed untracked by construction. `skills/_shared/feedback-emission.md` states the purpose outright — feedback reaches the maintainer only if it lands in the committed, pushed specs repo — and nothing in the plugin made that landing happen. New `skills/_shared/specs-repo-git.md` owns two entry points: `specs-preflight` at Phase 0 (flush leftovers onto the current branch, retry an artifact commit whose push failed, settle the branch) and `commit-artifacts` as the run's last action (stage the bounded artifact paths, commit `<KEY|NOISSUE> Add dev-workflows session artifacts (<skill>)`, push). Every git call is `git -C "$SPECS_PATH"` and never a `cd` — the caller is often standing in a different repository when these run (a code repo for `implement:` / `vuln:` / `upgrade:`, a docs repo for `document:`), and a `cd` there would corrupt its git state. Staging is by enumeration, never by glob, and never `git add -A` at repository scope. The plugin manages only branches it created (`vi|ard|spec|design/*`); a detached HEAD is the one blocking state, because a commit made there is reachable from no ref and garbage-collectable, and a run that reported a SHA over it would be a failure that looked like success.
- **Two skills' preflight silently never ran, defeating the detached-HEAD guard on exactly the paths most likely to hit it.** `implement:`'s executable `specs-preflight` citation sat inside `## Phase 0.5 — Readiness pre-flight`, a phase whose own first instruction is "When `mode: direct` this phase is a no-op — skip it entirely" — so every direct-prompt run skipped the preflight while `commit-artifacts` still ran unconditionally at the end. `document:`'s executable citation sat inside Mode A's own Phase 0, but `## Mode detection` dispatches to a mode *before* that phase is reached — so a Mode B (direct doc-edit) run jumped straight past it and never executed the preflight either, while its own `commit-artifacts` still ran. Both meant `specs_git: blocked` could never be set on a detached HEAD along those paths, so the terminal commit's data-loss guard silently did not exist there while the commit itself still fired. Fixed by moving `implement:`'s preflight to the end of the always-run `## Phase 0 — Load and classify inputs`, and `document:`'s to the shared `## Mode detection` section that runs before either mode is entered.
- **Ten skills that write `resume.md` wrote it too early to be captured by the new terminal commit.** The printed `### Context hygiene` block instructed the write at report-composition time — before the follow-up phase, and before any commit step existed at all. All ten (`create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `ready:`, `release-notes:`, `implement:`, `document:`) now write the pointer as the last step of the terminal follow-up phase, immediately before `commit-artifacts` runs, so it ships in the same commit. The five skills that write no `resume.md` at all (`idea:`, `implement:` direct mode, `document:` Mode B, `vuln:`, `upgrade:`) are unaffected — they were already on `session-hygiene.md` §1's skip list.
- **Ninety-eight `NEVER commits` / resume-ordering / push / `description:` sites had to be re-checked against the two new terminal steps; forty-seven needed rewriting and twenty-two needed an added reason.** Swept across four families — commit assertions (nine phrasing variants, including forms that wrap across a line break), `prepare-first (resume.md)` resume-ordering assertions, push assertions, and frontmatter `description:` claims — and reconciled rather than deleted: the protective intent is real, only the scope changed. Twenty-nine sites were already precisely scoped and left untouched.

- **Two routing rules were wrong in ways only a second read found.** `specs-preflight`'s branch matching compared the branch key against a *single* run key, but an Epic-scoped run carries two: `specify: <VI> <Epic>` authors its spec on `spec/<EPIC>-…`, so a following `design: <VI> <Epic>` — whose run key resolves to the VI — matched nothing, took B4, switched to the default branch, and removed the `specification.md` its own Phase 0 gate had just verified. That is the identical failure §3.6 documents for `create-ard:` and warns must never be "simplified away"; it simply was not covered for the skills that take an Epic. The run key is now a **set** (the VI, plus the Epic where the skill takes one), B3 matches any member, and B4 applies only when none do. Separately, eight skills stated that the terminal step "pushes to the specs repo's default branch"; it pushes to the current branch's upstream, and both G2 and B3 deliberately leave runs elsewhere. Those now cite §4 step 5 rather than restating it, per §7 rule 4.
- **The terminal step is not always literally last, and the reference now says so.** `prompt-brainstorm:` hands the session to a brainstorming skill and `prompt-grill-me:` enters an open-ended grill; both commit immediately *before* that hand-off, because a commit after it would never run. §4 and §7 previously admitted no exception, so a future cleanup could have "corrected" the ordering and stranded the artifacts. The carve-out is narrow: it applies only where control genuinely leaves the skill.

### Added

- **`skills/_shared/specs-repo-git.md`** — the bounded write authority (two path shapes, `^(vi|ard|spec|design)/` branches), the three preflight guards and their four-part notice contract, the three-stage resolution, the seven-step commit, and the `Specs repo:` outcome line. Never force-pushes, never `branch -D`, never merges/rebases/resets, never deletes an `index.lock`, and never fails the run. This edition has no cost subsystem — no `cost-emission.md`, no `emit-cost`, no `dev-workflows-cost/` path shape — so the artifact set committed is feedback, follow-ups, and the resume pointer only.
- **A `Specs repo:` outcome line at the end of every in-scope run** — eighteen sites, one per skill plus one per `document:` mode. Where the Final Report is the run's last output the line lives in the report template; where the report is composed before the terminal phases, `commit-artifacts` prints its own block, as the follow-up phase already does.

## [2.14.1] — 2026-08-10

### Fixed

- **Haiku 4.5 was listed as a strong-tier fallback.** `README.md`'s chain read `Opus 4.8 → 4.7 → 4.6 → Haiku 4.5 → GPT-5.5 → …`, so a SIGNIFICANT or HIGH-RISK gate would degrade to the cheapest model in the lineup before trying a strong peer. Removed. The root cause was drift: the edition documented its chain in three places — `skills/_shared/model-routing.md`, `.github/copilot-instructions.md`, and `README.md` — and the three had diverged in three different directions. All three now flatten to one sequence, with `model-routing.md` as the authority.
- **The model references had gone stale.** The strong-tier peer set grows from four to six — `claude-opus-5` first, `gpt-5.6` second, the existing four in their prior relative order. It remains a *peer set*, not a ladder: the "prefer the model the orchestrator is already running under" rule and the never-announced-as-a-downgrade semantics are unchanged. Further fallbacks renumber from 7. The peer label `Opus 4.8/4.7/4.6 or GPT-5.5` becomes `Opus 5/4.8/4.7/4.6 or GPT-5.6/5.5` across nine reviewer agents (frontmatter and body), the preload hook, both READMEs, `copilot-instructions.md`, and both catalogs.

### Added

- **`claude-sonnet-5`, which this edition was missing entirely.** It appeared in neither the strong-tier further-fallbacks list nor the mid-tier detection chain — the canonical edition has carried it for some time and the B-series ports never brought it across, leaving the detection tier topped at Sonnet 4.6. It now sits above `claude-sonnet-4.6` in both.

## [2.14.0] — 2026-08-10

### Fixed

- **The deprecation note was not missed. It was forbidden.** `agents/doc-location-finder.md`'s exclusion rule banned every path under `_content/whats-new/...` as a `release-notes:`-only destination — correct for the 182 automation-generated pages at that prefix, wrong for the 10 hand-authored announcement pages (`end-of-life-announcements.md`, `end-of-support-news.md`, `technology/index.md`) that live under the same prefix and have no automation touching them at all; their git history is human PRs. The rule's exclusion set is now keyed on what's genuinely automation-owned — `meta.content-type: release-notes` frontmatter, `_data/release-notes/**`, `_snippets/release-notes/**` — and gains one named exemption: a page declared in the profile's new `announcement_pages` block (`{postid, path, kinds}`, in `_shared/dynatrace-docs/docs-profile-schema.md` + `.default.yml`) is a valid target, proposed **alongside** the feature-subtree target rather than in place of it. `doc-location-finder`'s two mirrors in `agents/doc-planner.md` change in lock-step — removing one and leaving the others is a failure mode this repo has hit before. A repo with no `announcement_pages` block falls back on the same content-type-keyed heuristic, which is necessary rather than decorative (`end-of-support-news.md` carries no `content-type` at all). `docs-profile:` learns to discover the block.
- **The provenance comments were not improvised. They were mandated.** `agents/doc-writer.md` and `doc-reviewer.md` dimension 12 ("Source traceability") required every claim to cite its Jira key and/or PR URL inline — while three other places in the same plugin (`doc-writer.md`, `doc-planner.md` ×2, `skills/document/SKILL.md`) already stated the opposite: traceability lives in the commit message, not the reader-visible page. The writer emitted provenance and the reviewer endorsed it, both correctly following instructions the plugin itself contradicted. New `_shared/doc-structure-conventions.md` §1 states the boundary once — rendered page carries the customer-facing claim only, the commit message carries the Jira key, the run handoff carries per-claim attribution — and `doc-writer` + `doc-reviewer` now cite it instead of restating it. Dimension 12 **inverts**: a Jira key (bare or as a `[[wikilink]]`), a PR URL, or a `<!-- KEY: … -->` comment appearing anywhere in a written file is now **MAJOR**. The `source-truth.md` §7.6 `<!-- intentional-discrepancy: … -->` marker is unaffected — it's a deliberate, user-decided gap flag, not provenance.
- **`doc-location-finder`'s input contract had a scope gap.** It defined its entire input as `repo_root`, `feature_summary`, `diff_highlights` — no `target_spaces`, no `profile` — so nothing stopped it proposing a SaaS-only path on a Managed-only run. Both are now part of the contract, and `skills/document/SKILL.md` passes them.

### Added

- **Callout scope and adjacency — new `_shared/doc-structure-conventions.md` §2.** A callout that qualifies one option in a mutually exclusive set is placed with that option, immediately beneath it, never as an *unqualified* trailing block after the whole set — a trailing callout that names its own scope in its first clause is §2 rule 3's permitted alternative, and the enforcers carry that carve-out so a page following it is not flagged; a callout that applies to the whole set goes in the lead-in, before the options. `doc-planner` plans placement per option, `doc-writer` writes it, and `doc-reviewer` flags a scope violation at **MAJOR** — a misread scope changes what the customer believes is required or prohibited. The motivating case: an ARM limitation specific to the built-in cluster container registry read as applying to all four registry options on the shipped page, including a customer-owned private registry where it's simply false.
- **Component-pattern fidelity — `doc-structure-conventions.md` §3.** `doc-planner`'s existing 5–10-page sibling sample (already used to classify image policy) gains a second job: recording which content component the area already uses for a recurring content shape, as a `component_patterns` block (`shape`, `component`, `evidence`, `count`). `doc-writer` reuses the dominant component for a matching shape instead of inventing a structure; `doc-reviewer` flags a divergence at **MINOR** (an ad-hoc structure still renders). No component list is vendored — the rule is repo-agnostic and the evidence always comes from whatever repo is in front of it. On the shipped page, 4 of 5 sibling pages used `{{#tabgroup}}` for the same mutually-exclusive-options shape the writer built ad hoc.
- **Images: one phase, two lists.** Phase 5.6 is now the single image step and **always runs**, sourcing a to-add list (unchanged) and a possibly-stale list — every image already present on an `extend-existing` target, listed **per occurrence** (not per URL) with its section and space-gating (`{{#if project='…'}}` or none). Answering "No screenshots needed" no longer skips the phase outright, which is exactly how three stale images — one of them SaaS-gated in a space where the feature doesn't exist — survived a run where the user was asked about screenshots and answered. Stale replacements reuse the existing Phase 6.1 CDN-URL-collection flow, and the writer swaps the existing reference rather than inserting a new one. CDN immutability — every new or replacing screenshot is a new URL; an image is never refreshed in place — is now stated in `docs-profile.default.yml`'s `images.policy`, `docs-profile-schema.md`, and the `doc-writer` image step. `doc-reviewer` dimension 9 extends to swap completeness: every accepted replacement URL must land at every occurrence the review listed, or the stale image stays live and invisible in the diff.
- **New ledger gate `image_review` — `_shared/gate-ledger.md` §4.** Phase 5.6, preconditioned on ≥1 candidate image (to add or possibly-stale). It's an input-side gate rather than an output-verification gate like the other six, but the accountability need is identical. The §4 direct-mode carve-out paragraph is updated in the same edit — direct mode has no Phase 5.6, so the "three registered, N never-appearing" gate count becomes four never-appearing.
- **Anchor conventions — new `_shared/dynatrace-docs/anchor-conventions.md`.** One `{:#id}` per heading — multi-anchor `{:#a #b}` is unsupported (0 occurrences across 1,580 files under `dynatrace/_content` + `managed/_content`); the four verified link forms (`[text](postid)`, `[text](postid#anchor)` — 19,560 occurrences, `[text](#anchor)` — 4,006, `{{#tabgroup anchor='id'}}` — 698); the `pnpm docstack validate-anchors` contract (an anchor link must target a hardcoded id, not a generated one); and the reconciliation rule that a product `dt-url` deep link's anchor wins — a mismatch is recorded as a Phase 5.8 discrepancy, never deferred on an in-session judgment that the syntax "appears unsupported." Consumed by `doc-writer` (authoring), `doc-reviewer` (dimension 5), and `doc-planner` (planning cross-link anchors).
- **Lifecycle dates — a twelfth `source-truth.md` §2 claim class.** End-of-life, end-of-support, shutdown, sunset, and availability dates are now a verified claim type, checked against UI notice strings and banner constants, announcement/config expiry values, feature-flag sunset metadata, and sibling announcement pages that already carry the date. A load-bearing milestone-equivalence rule ships with it: compare the milestone a date denotes, not its surface form — "EOY 2027," "end of 2027," "December 31, 2027," and "stops working on January 1, 2028" all denote one boundary and are not a discrepancy; a discrepancy exists only when the milestones genuinely differ. Without this rule the class would be a false-positive generator. §7.5's `<KEY>-implementation-gaps.md` bug-report trigger widens to `document-as-code`, conditionally: emit a gap only when the Jira phrasing asserts a specific value that **contradicts** the source; skip when it's merely vague or non-committal. The judgment resolves toward over-inclusion — a spurious entry costs a paragraph the user reviews; a miss leaves a wrong customer-facing claim in the ticket indefinitely.
- **`doc-reviewer` grows from 16 to 17 dimensions.** New: **Page structure conventions** (callout scope + component-pattern fidelity, above). Extended: **Structural integrity** (anchor form and the `validate-anchors` contract), **Screenshots** (swap completeness), **Source traceability** (inverted, above). The dimension table and the output-slot headings stay in lock-step, seventeen of each, per the existing "never invent a dimension beyond the ones listed" rule.
- **Phase 8 maintenance agents split into propose and apply.** Agents 2 (knowledge base) and 3 (instructions, incl. `copilot-instructions.md`) stop writing into the target docs repo directly — each now returns a precise proposed edit (file, anchor, replacement text, reason) instead of applying it; Agent 1 (documentation) and Agent 4 (`impl-maintenance`, already suggest-only) are unaffected. A new apply phase — Jira mode Phase 8.6, running after Phase 8.5 has sealed the docs commit; direct mode Phase 4.5, between maintenance and the final report — presents the proposals (`choices: ["Skip — report only (Recommended)", "Apply all", "Choose per proposal", "Cancel"]`) and, on acceptance, re-dispatches the same agent in apply mode. Applied edits are left **uncommitted** by design: because the phase runs after the squash, an accepted `copilot-instructions.md` edit can never ride the docs commit or the docs PR — a governance change needs its own PR on the user's own timing. The Phase 9 / Phase 5 final report gains `### Maintenance applied (uncommitted)` sections and per-proposal `disposition` tagging under the existing Knowledge base / Instructions headings. `skills/document/SKILL.md` and `_shared/finish-and-handoff.md` drop the "Agent 3 (`copilot-instructions.md`) may have edited without committing" clause — nothing uncommitted originates there anymore.

## [2.13.0] — 2026-08-08

### Added

- **`document:` Phase 0 toolchain preflight — new `_shared/toolchain-preflight.md`.** Before anything is written, the run derives the tools its gates will invoke — from the resolved profile (`commands.*`, `commands.per_space.*`, `dev_servers[].command`, `prerequisites`), the repo's config signals (`.vale.ini`, `pnpm-lock.yaml`/`package-lock.json`/`yarn.lock`, `node_modules/`, `.markdownlint.json(c)`, `.remarkrc*`), and the repo's own documented `Prerequisites` section — checks each with `command -v` / `test -d`, and maps every tool to the gates it powers. On a healthy container it contributes one Readiness row and never prompts. When something is missing it states the run's outcome in advance ("with `vale` and `pnpm` missing, `style_check` would be DEGRADED, `build_check` and `render_smoke_check` UNAVAILABLE") and offers Cancel as the recommended option, so a run started in the wrong container stops before writing rather than shipping quieter, worse documentation behind a green CI. Direct mode gets the same check scoped to the style gate, deriving its required set without a profile.
- **Gate ledger — new `_shared/gate-ledger.md`.** Six outcomes — `RAN`, `DEGRADED`, `FAILED`, `UNAVAILABLE`, `SKIPPED_BY_USER`, `NOT_APPLICABLE` — and **none of them is an orchestrator-assignable "skipped"**. Every non-run path terminates in a named missing precondition, a named missing tool, or the user's decision quoted verbatim; `UNAVAILABLE` is explicitly not a resting state and is converted by asking. Each gate appends its row **when it completes**, never reconstructed at report time. `doc-reviewer` gains a **Verification-gate integrity** dimension that BLOCKs on a missing row, an unconverted `UNAVAILABLE`, an unattributed skip, or an underpopulated `DEGRADED`, and Phase 9 prints a `### Verification gates` table naming what CI will check that the run did not.
- **"Choice lists are presented verbatim" in `_shared/escalation-rules.md`** — a phase's options, their order, their wording, and the `(Recommended)` marker are not the orchestrator's to change; an orchestrator that disagrees says so in prose beside the list. Binds every skill. This is the rule a `document:` run broke when it moved `(Recommended)` onto Phase 6.5's Skip option and never exercised the render gate.
- **`commands.per_space` in the docs profile.** `dynatrace-docs` defines `dynatrace:lint`, `managed:lint`, `dynatrace:build`, and `managed:build`; the built-in profile knew only `pnpm dynatrace:lint` and no build command at all. Per-space `lint`/`build`/`format` are now declared, documented in `docs-profile-schema.md`, and detected by `docs-profile:`.
- **Commands and code blocks are a verified claim class.** `_shared/source-truth.md` §2 gains a row for helm/kubectl/pnpm invocations, flags, image references, chart names, registry paths, and YAML keys in fenced blocks, plus a §3.7 technique that checks them against `Chart.yaml`/`values.yaml`/`templates/**`, the release workflow, sibling docs pages, and `--help` output. `doc-reviewer` checks them in **every** run at MAJOR — readers run a documented command verbatim, so an unverified one is a defect even when the rest of the page verified cleanly.
- **`repo_verification_gates` from `doc-planner`.** The repo's own pre-PR checklist — for `dynatrace-docs`, `CONTRIBUTING.md` `## PR checklist` — is now extracted and checked, instead of being discarded by the planner's "ignore operational content" rule. `doc-reviewer` holds the written files against each gate and cites the repo's own section in the finding.

### Fixed

- **`docs-style-checker` climbs the ladder instead of jumping off it.** A failure at any primary rung now continues to the next rung; previously every step-1/2/3 failure jumped straight to `dt-style-checker`, so a repo with a `.vale.ini` but no `vale` binary silently abandoned `pnpm dynatrace:lint` — the linter CI actually runs. Step 2 also becomes space-aware through a new optional `spaces` input, so a Managed-only file set is linted by `managed:lint` rather than the SaaS linter, and a new `primary_attempts` output records every rung tried, which is what fills the ledger's `not_run` and `ci_still_checks`.
- **`_shared/dynatrace-docs/render-verification.md` no longer claims dynatrace-docs has no build command.** That false statement disabled Phase 6.5's gating Step 1 outright; `dynatrace:build` and `managed:build` both exist and now run per space.
- **The render smoke-check boots the protected space, not only the target.** The cross-space invariant has two halves — the delta marker PRESENT in the target render and ABSENT in the protected one — and iterating `target_spaces` alone could never check the second, which is the half the 3a protection depends on. Static conditional analysis is declared necessary but never sufficient: it corroborates the gate and can never satisfy it.
- **`changelog-guidelines.md` has consumers in the write path.** It was cited only by a skill that no agent invokes and `doc-writer` cannot invoke (its tool list has no skill-invocation capability), so `doc-planner`, `doc-writer`, and `doc-reviewer` each worked from two inlined rules. All three now read the reference itself; a non-conforming entry — meta phrasing, a run of "Added", internal jargon such as "Managed-only", a broken period rule — is a MAJOR reviewer finding. No rule text is duplicated.
- **Phase 5.8 tries once more before escalating.** An `AMBIGUOUS`/`NOT_FOUND` verification warning whose repo is resolved in `code_repos` now gets one supplementary direct grep against the local path — **including when `diff-summarizer` returned `REFRESH_BLOCKED`**, since a read-only mount that cannot `git fetch` can still be grepped. Resolving a claim this way records the gate as `DEGRADED`, never a clean `RAN`.
- **`status: NOT_CONFIGURED` stops being a silent proceed, in both modes.** It now maps to an `UNAVAILABLE` ledger row that must be converted by asking the user, rather than a no-op on the way to the reviewer. Jira mode converts it before `doc-reviewer`; direct mode, which has no reviewer gate, converts it before Phase 4.

## [2.12.0] — 2026-08-07

### Changed

- **Release-notes field hygiene — `create-vi:` and `release-notes:` stop asking for Jira dropdowns.** `release_versions`, `change_type`, and `release_notes_category` were filed as PM-authorable VI frontmatter; they are Jira dropdowns the PM sets on the ticket and the importer returns on the round-trip, so they move to the Jira-mirror class in `_shared/vi-format.md`. `create-vi:` no longer asks for any of them and `vi-reviewer` no longer requires or validates them. A dropdown question earns its place only when the answer changes what the plugin generates — deciding it in a chat window costs exactly what deciding it in Jira costs.
- **`_shared/release-note-types.md` rewritten as a destination + shape authority.** Evidence from the shipped `dynatrace-docs` corpus: across 852 `{{#context}}` lines in generated release-note snippets, none carries a change type — the Change Type instead routes the note to `breaking-changes.md`, `feature-updates.md`, or `fixes.md`. And `fixes.md` publishes one bare sentence (1 `{{#context}}` line across 57 files) rather than label + title + prose, so classifying a VI as `Bug fix` used to emit an unpublishable shape. The reference now maps Change Type → destination → draft shape, and adopts the docs team's own per-destination prose rules (breaking: present tense + remediation link; feature update: benefit-led + a docs/blog link; fixes: one past-tense sentence).
- **A deprecation is never classified `Bug fix`.** `fixes.md`'s one-bare-sentence shape has no `{{#context}}` line, no title, and no room for a trailing `> Note:` line — so a deprecation routed there would have nowhere to carry its required end-of-life date. §2's tie-breakers now exclude `Bug fix` outright for a deprecating change: it resolves to `Breaking change` when the customer must act now, else `New technology support` when a new capability supersedes the old one, so the note always lands in a titled destination with room for the §5 deprecation note.
- **The feature-update documentation link is now phase-gated.** `release-notes:` runs twice in a VI's life — once from the PM at VI creation, once from the dev after implementation — and only the second run has a page to link to. The writer resolves `run_phase` from the `specification.md` / `design.md` presence signal under the VI's specs dir: neither file present → `pm`, and the link is omitted entirely (never asked for — the feature isn't built and the docs don't exist yet); either present → `dev`, and the author may supply a redirect short link. No URL is ever invented at either phase.
- **The `{{#context}}` label is now sourced, not guessed.** It is exactly the Dynatrace Solution taxonomy the VI already carries as `release_notes_category` — yet `release-notes-writer` was explicitly forbidden from using it, so it guessed and then asked. The prohibition is gone: the label is the imported `release_notes_category` used verbatim, and the line is omitted when the import carries none.
- **Exactly one Summary per run.** `release_versions` used to emit one Summary block per declared version, but the prose may never name a version — so the blocks were identical. The `(unspecified)` fallback and the `release_version` gap are gone.
- **`release-notes:` is gated on `relevant_for_release_notes`.** An explicit `false` in the *imported* frontmatter stops the run with `RELEASE_NOTES_NOT_RELEVANT` (overridable); an absent value proceeds silently, since the field defaults to true. Previously the check ANDed the flag with `release_versions`, so a VI correctly flagged not-relevant still proceeded whenever a version happened to be set.
- **One question survives, reframed.** A low-confidence *destination* inference is still confirmed — but only when the Jira dropdown is unset, and the options now name each choice's shape and destination file instead of the four opaque enum values.
- **Two long-standing contract defects corrected.** `skills/_shared/handoff/release-notes-writer.md` typed `release_notes_category` with the `change_type` enum (it is a free-text Dynatrace Solution name) and omitted `"note in report"` from `recommended_action`. Both blocks were rewritten by this change.

## [2.11.0] — 2026-08-04

### Changed

- **Branch naming is now repo-rule-first.** 2.10.0 wired the previously-orphaned `$GIT_USER_INITIALS` ladder into all five branch-creating workflows, but left it as the *primary* mechanism — and only `document:` and `docs-profile:` ever read the target repo's own branch-naming convention, so `_shared/branch-naming.md`'s claim that a documented pattern "outranks this ladder" was unenforceable in `implement:`, `upgrade:`, and `vuln:`. The priority is inverted and the gap closed. All five now read the repo's `CONTRIBUTING.md` / `CONTRIBUTION.md` / `README.md` / `DOCUMENTATION-GUIDELINES.md` / `.github/copilot-instructions.md` **first** (§1.1), classify the documented pattern's segments (§1.2), and fill each from its proper source: an **identity** placeholder (`<your-name-or-initials>`, `<user>`, …) from the `$GIT_USER_INITIALS` → `git config user.initials` → existing-branch-inference → prompt ladder, now §2; an **issue-key** segment from the run's already-resolved Jira key (or the documented no-issue literal); the **description** from each workflow's own slug rule (§3). Against `dynatrace-docs`' documented `<your-name-or-initials>/<JIRA-ISSUE-KEY>-<short-branch-name>`, `GIT_USER_INITIALS=iv-gu` now yields `iv-gu/PRODUCT-17753-add-oauth`. The ladder supplies the *whole* prefix only when a repo documents no convention at all (§1.4).
- **A pattern with no identity segment no longer gets one.** Injecting initials into a repo whose documented convention is a plain `feat/<slug>` would violate that convention; §1.2 and §5 now forbid it. Identity inference ignores the generic prefixes, and the §2.5 escalation drops its generic-fallback choice when an identity is being filled.
- **`implement:` composes a compliant name in issue-key repos.** When a documented pattern has no separate issue-key segment but the run resolved a Jira key, the key is prefixed to the slug (`<KEY>-<slug>`).

## [2.10.0] — 2026-08-04

### Added

- **`_shared/branch-naming.md` is now actually wired in.** The shared branch-prefix policy has shipped since 1.6.0 and the README described it, but **no skill ever loaded it** — every branch-creating workflow silently used its own inline `git branch -a` sniff, so `$GIT_USER_INITIALS` had no effect anywhere. All five branch-creating orchestrators now resolve their prefix through the §1 ladder: `implement:` (Phase 3 step 2), `document:` (Phase 6.2 steps 3–4, both modes), `docs-profile:` (Phase 6 step 1), `upgrade:` (Phase 2 prep), and `vuln:`'s "Git Workflow" spec that `vuln-fixer` follows. Setting `GIT_USER_INITIALS=iv-gu` now produces `iv-gu/PRODUCT-17753-add-oauth` instead of `feat/add-oauth`.

### Fixed

- **The prefix ladder rejected hyphenated initials.** §1.3's inference pattern was `^[a-z0-9]+$` while §4's hard rules allowed `[a-z0-9-]`, so existing `iv-gu/…` branches were invisible to inference and the §1.5 prompt told users "alphanumeric". Inference now accepts `[a-z0-9][a-z0-9-]*` and both prompts say `[a-z0-9-]`. (`$GIT_USER_INITIALS` was always taken verbatim, so §1.1 was unaffected.)
- **Reaching the per-workflow fallback was silent.** §1.5 mandated a prompt, but no orchestrator implemented it. The prompt is now registered in `_shared/escalation-rules.md` as "Branch prefix undetected" and referenced from each branch-setup step.
- **`docs-profile:` derived initials from `git config user.name`** in its own ad-hoc way, ignoring `$GIT_USER_INITIALS` entirely. It now uses the shared ladder.

## [2.9.4] — 2026-08-02

### Fixed

- **`vuln:` + `upgrade:` re-review read a stale diff.** After `review-fixer` applied the `BLOCKER`/`MAJOR` fixes, "re-run the Opus review once" re-used the `review_diff_file` captured *before* those fixes, so the second verdict was computed on the pre-fix diff (and a `BLOCK` could never clear). Both paths now overwrite `review_diff_file` with a fresh `git add -N . && git diff` before the re-review — the same correction `implement:` received as a 2.9.2 follow-up but which was not carried into the 2.9.3 siblings.
- **`implement:`'s `test-writer` dispatches told the agent to shell out.** Phase 3.5 step 1 and Phase 3B step 4a embedded the `mktemp` + `git add -N . && git diff` capture *inside* the agent-facing prompt and left it unbracketed; `test-writer` has no `bash` tool, so it could not comply. The capture is now an orchestrator action recorded as `test_diff_file`, and the prompt hands only that path — matching the `document:` + `epics:` handoff pattern.
- **Dispatch substitution brackets carried instructions instead of values.** `vuln:`'s two `vuln-fixer` dispatches and `upgrade:`'s `upgrade-executor` dispatch wrapped the whole "read … from the file at `<handle>`" sentence in `[…]`, which the house convention reads as "substitute the content here" — the opposite of the intent, and enough to defeat the file-handoff. Only the path handle is bracketed now.
- **`vuln:`'s SIMPLE/MODERATE regression-resume was a missed adoption site.** It still said "passing the same CVE input verbatim" while every other `vuln:` resume had moved to `research_file`.
- **`vuln-fixer` + `upgrade-executor` never received the `phase: regression-resume` directive.** The Claude edition's `## Process` "Phase resume" callout tells both agents to skip straight to the test-regression step on `phase: regression-resume`; this edition carried only the `verify-resume` half, so a regression resume would have re-run the baseline/fix/apply steps. Long-standing conversion gap, now ported.
- **`skills/_shared/context-management.md` omitted the load-bearing temp-file guard.** As the authority for "hand off by file, not paste" it did not say the handoff file must be `mktemp`-ed **outside every repo working tree** — the property that keeps a later `git add -N . && git diff` from picking it up.
- **`skills/_shared/handoff/vuln-fixer.md` + `skills/_shared/handoff/upgrade-executor.md` described their report/plan section as inline-only.** Both now state the section may instead arrive as an absolute path to read, matching what the orchestrators have sent since 2.9.3.
- **Claude tool names leaked into agent/skill prose.** Sixteen references instructed agents to use `Read` / `Write` / `Glob` / `Grep` / `LS` — tools this edition never grants; its frontmatter grants `view` / `create` / `edit` / `glob` / `grep` / `bash` / `task` / `web_fetch`. Affected `code-review`, `risk-planner`, `test-writer`, `review-fixer`, `vuln-fixer`, `upgrade-executor`, `epic-writer`, `ready:` Phase 4, and both `skills/_shared/handoff/` docs. Same defect class as the `test-writer` shell-out above: an agent told to use a tool it does not have.
- **Stale sub-agent counts in the manifests.** The marketplace entry said “Thirty-one dispatched sub-agents” and the repo-root `README.md` tree said “30 sub-agents”; there are 32 (matching `dev-workflows/.plugin/plugin.json`'s “32 sub-agents” and the 32-row agent table in `dev-workflows/README.md`). Both corrected.
- **`agents/risk-planner.md`'s requirement-ID example used the wrong form.** `[AC-3]`/`[TC-7]` → `[AC03]`/`[TC07]`, the form `skills/_shared/specification-format.md` defines and `code-review`'s spec/design-conformance dimension traces against.

## [2.9.3] — 2026-08-02

### Changed

- **`vuln:` + `upgrade:` now hand their large dispatch artifacts to sub-agents as temp-file paths instead of pasting them inline.** The `vuln:` research report (to `vuln-fixer`, `code-review`, and the resume steps) and the `upgrade:` planner handoff (to `risk-planner`, `upgrade-executor`, and the resume step), plus each command's `code-review` `git diff`, are written to `mktemp` files — outside every repo working tree, so a captured `git diff` never picks them up — and handed as absolute paths. Extends the `implement:` file-handoff (2.9.2) and the `document:` + `epics:` pattern to the two remaining code-oriented skills; `vuln-fixer` and `upgrade-executor` `## Process` now notes that a field may arrive inline or as a path to `Read`. Behavior-preserving.

## [2.9.2] — 2026-08-02

### Changed

- **`implement:` now hands its large dispatch artifacts to sub-agents as temp-file paths instead of pasting them inline.** The multi-source codebase summary (Phase 1.7 / 2B), the approved plan (Phase 2A / 2B), the review diff (Phase 3B / 3.5), and the code-review report (Phase 3B review-fixer) are written to `mktemp` files — outside every repo working tree, so a captured `git diff` never picks them up — and handed to `risk-planner` / `test-writer` / `code-review` / `review-fixer` as absolute paths. This matches the existing `document:` + `epics:` handoff pattern and keeps the orchestrator's context lean on long runs. Behavior-preserving: each agent receives identical content, and its `## Inputs` now notes that a field may arrive inline or as a path to `Read`.

## [2.9.1] — 2026-08-02

### Fixed

- **`skills/_shared/context-management.md` 4th-strategy consistency.** The wave-3 "Hand off by file, not paste" bullet left the section's trailing "Prefer the cheapest strategy…" summary enumerating only the original three offload strategies. Clarified that "Hand off by file" is orthogonal — applied whenever a sub-agent is dispatched, regardless of the chosen offload strategy. (Whole-branch-review NIT follow-up.)

## [2.9.0] — 2026-08-01

### Added

- **Deferred-backlog sharpeners (wave 3)** (ported from the Claude edition). Six additive, single-location refinements (all additive/conditional):
  - **ADR candidacy filter** — `skills/_shared/ard-format.md`: an `AD-N` earns its place only when the decision is hard-to-reverse AND surprising-without-context AND a real trade-off (else left to `design:`). [Matt `domain-modeling`]
  - **Wide-refactor sequencing exception** — `skills/epics/SKILL.md` Phase 2: expand → migrate-in-batches → contract for blast-radius-wide mechanical changes that cannot be tracer-bulleted. [Matt `to-tickets`]
  - **Prototype-snippet exception** — `skills/_shared/design-format.md`: a narrow decision-encoding-snippet exception to the prose default. [Matt `to-spec`]
  - **Missing-adoption gap** — `agents/code-review.md` dimension 4: an untouched sibling call site that should adopt changed behavior, uncaught by tests. Complements the wave-2 converge gate. [BMAD `lens-verification-gap`]
  - **`resume.md` redaction reminder** — `skills/_shared/session-hygiene.md`. [Matt `handoff`]
  - **Context "hand off by file, not paste"** — `skills/_shared/context-management.md`: a 4th long-run strategy (reference-only; the `implement:` dispatch-prompt refactor is deferred). [superpowers SDD]

## [2.8.0] — 2026-07-29

### Added

- **Upstream-harvest improvements** (ported from the Claude edition). Adapted eight improvements from four upstreams (GitHub SpecKit, Matt Pocock skills, superpowers, BMAD) into the pipeline, all additive and conditional:
  - **Spec→code conformance ("converge").** `code-review` gains a conditional 10th dimension "Spec/design conformance" (active only when a `specification.md`/`design.md` is in scope) that traces every in-scope `[Uxx]`/`[ACxx]`/`[TCxx]` against the shipped diff (satisfied / missing / partial / contradicts). `risk-planner` tags plan steps with the requirement IDs they implement. `implement:` extracts in-scope IDs, passes `applicable_spec` to the Opus review, reports conformance in Phase 5, and escalates unresolved gaps as `- [ ]` notes back onto the spec/design.
  - **Bug-diagnosis discipline.** New `skills/_shared/bug-diagnosis.md` — red-capable repro before hypotheses, 3–5 ranked falsifiable hypotheses, `[DEBUG-xxxx]` instrumentation with a cleanup gate, regression test at a correct seam. Folded into `risk-planner` (`task_shape: bug`) and `implement:` (bug-shape detection + strip-before-review; `code-review` flags leftover `[DEBUG-xxxx]`).
  - **Quality gates.** `test-writer` falsifiability gate + mutation self-check; `review-fixer` `plan-conflict` disposition; `code-review` Fowler 12-smell floor (MINOR/NIT, overridable).
  - **Authoring sharpeners.** `grilling-technique.md` terminology-precision move + altitude-aware `## Ambiguity taxonomy`; `spec-reviewer` NFR-coverage + implicit-enum-branch; `design-format.md` + `design-reviewer` deep-module/seam vocabulary; `risk-planner` "No placeholders"; `vi-format` + `vi-reviewer` counter-metrics (`[SM-C1]`).
  - Renamed the grill's "design tree" → "decision tree".
- Reconciled the marketplace manifest version (was stale at 2.5.0) to the plugin version.

## [2.7.0] — 2026-07-23

### Changed

- **No-hard-wrap prose convention.** New `skills/_shared/prose-formatting.md` — the single source of truth: never hard-wrap prose; write each paragraph/prose block as one unbroken line, since Obsidian and IntelliJ Idea both soft-wrap for reading, and a straight copy-paste into Jira/Grammarly needs no manual cleanup. Consumed by every authoring skill/agent that writes prose: `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `epic-writer`, `doc-writer`, `release-notes-writer`. Ported from the Claude Code edition (dev-workflows 2.37.0).

## [2.6.0] — 2026-07-21

### Added

- **Documentation grounding on `$DOCS_PATH`.** `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, and `specify:` now ground their grill on the product's existing shipped documentation when `$DOCS_PATH` (default `${DOCS_PATH:-/workspace/docs}`) is set and valid; `epics:` and `release-notes:` attach the same docs digest to their writer handoff. New `skills/_shared/docs-grounding.md` — the single source of truth for the `resolve-docs-grounding` resolution gate (read-only, silent non-blocking skip on any miss), the `dispatch-docs-grounder` procedure (`task(agent_type: "dev-workflows:docs-grounder")`), and the two consumption modes (grill-rank for the five grill commands; writer-attach for `epics:` and `release-notes:`). New read-only `docs-grounder` agent (`tools: [view, glob, grep, bash]`) — retrieves via the `qmd` CLI when available (`qmd update`, never `--pull`), falling back to keyword-overlap + `git log --grep` matching. Grounding is **positive-first**: each match is classified by `relation` (`same_feature` / `analogous_precedent` / `building_block`) with extracted `structural_facts`, plus bounded reconciliation `docs_challenges` (`already_documented`, `terminology_mismatch`, `contradicts_documented_behavior`, `diverges_from_precedent`, `adjacent_undocumented`). Advisory only — never a gate, never a reviewer BLOCKER; disable per-run with `--no-docs` or override the root with `--docs <path>`.
- **`document:` docs-repo discovery hint.** `document:` (Jira mode) now prefers `${DOCS_PATH:-/workspace/docs}` as a docs-repo discovery hint (checked between the cwd-with-signals path and the `$REPOS_PATH` search) — a write-target hint only, with no `docs-grounder` consumption.

## [2.5.0] — 2026-07-18

### Added

- **`create-vi:` captures the release-note Change Type + category (write-side).** `_shared/vi-format.md` frontmatter gains optional `change_type` (`Breaking change | New technology support | Bug fix | not applicable`) and `release_notes_category` (the Dynatrace Solution), authored-then-mirrored like `release_versions`. The `create-vi:` grill asks for both only when `relevant_for_release_notes: yes`; dates/deprecation stay out of frontmatter (they belong in the release-notes Summary). `vi-reviewer` validates `change_type` — `MAJOR` if outside the four-value enum, `MINOR` (recommended, not required) when `relevant_for_release_notes: yes` but `change_type` is absent; `release_notes_category` is free text. Completes the write-side of the Change Type sourcing ladder from 2.4.0, so a PM-phase `release-notes:` run can read the authored `change_type` from the specs-draft VI.

## [2.4.0] — 2026-07-17

### Added

- **Release-note Change Type classification (`release-notes:`).** `release-notes-writer` now classifies every draft into one of four Change Types — **Breaking change** / **New technology support** / **Bug fix** / **not applicable** — via a new `_shared/release-note-types.md` source-of-truth reference (taxonomy, classification order, per-type Summary shaping, and the deprecation-note rule). The draft leads with a `Change type:` line above a type-aware Summary (breaking → benefit-led + action plan; bug fix → past-tense, no hedging, no internal terms; new-tech → benefit-led editorial shaping); the label never appears inside the Summary body, and no title or Summary prose names the release version.
- **Deprecation notes.** When a change deprecates something, the Summary carries a deprecation note — end-of-life date (**required**) + end-of-support date (optional). Dates are never invented: a missing required date becomes a `deprecation_eol` gap the `release-notes:` skill asks about, with a `<!-- TODO: end-of-life date -->` placeholder in the draft.
- **Change Type sourcing ladder + VI capture.** `change_type` is sourced, not just inferred — `change_type_hint` → imported VI frontmatter → authored specs-draft VI → infer (first non-null wins; the imported value wins a divergence, recorded non-blocking). `jira-reader` now surfaces `change_type` and `release_notes_category` verbatim from the VI frontmatter into `value_increment` (additive, null when absent); `release_notes_category` is surfaced only, never inferred, and never the `{{#context}}` label.

### Changed

- `release-notes:` Phase report now shows the resolved Change type + Deprecation; the skill resolves a low-confidence `change_type` gap and a `deprecation_eol` gap with the user before writing the draft.

## [2.3.0] — 2026-07-17

### Added

- **New `update-vi:` skill (PM VI refresh).** Refreshes an existing Value Increment — routine refresh or an obstacle-driven re-do. Resolves the VI **Jira-import-first** (a new `_shared/vi-source-resolution.md`: the re-imported `$VAULT_PATH/jira-products/<KEY>` is the source of truth, 3-day freshness gate; the `$SPECS_PATH` draft is secondary), grounds on VI + comments + any ARD/spec/`@transcript`, updates via the grill against `_shared/vi-format.md`, gated by the Opus `vi-reviewer`, and writes **canonical + archived** revisions (`<KEY>_<slug>.md` latest; prior snapshot under `revisions/`). Product-level (no code scan).
- **`create-vi: --from-vi <VI-KEY|path>` seeding.** Author a new VI seeded read-only from a sibling VI (the techFit family pattern), recorded in a new `seeded_from_vi` frontmatter field; resolved Jira-import-first. A bare `create-vi: <existing-VI>` now redirects to `update-vi:`.
- **`vi-reviewer` non-contradiction dimension + `vi-format` internal-consistency rule + `create-vi:` grill self-consistency nudge** — flags a VI that contradicts itself (AC vs Out-of-scope, Goal vs Scope, conflicting US) at product altitude.

### Changed

- **VI filename standardized to `<KEY>_<slug>.md`** (frontmatter-based detection: `issue_type: ValueIncrement`), replacing the documented `<KEY>_ValueIncrement.md` across `create-vi:`, `create-ard:`, `vi-reviewer`, `vi-format`, `pre-lint`, and `ard-format`.

## [2.2.0] — 2026-07-15

### Added
- **`document:` (Jira mode): counterpart-space grounding.** A space-constrained run (`saas`|`managed`) now discovers the OTHER space's existing documentation for the same feature and hands it to the writer as **read-only grounding** — concepts, terminology, and structure to consult, never text to copy and never screenshots to reuse. New `counterpart-finder` agent (in-tree keyword search + `git log --grep`, plus an optional `--counterpart <JiraID|PR-url>` for an unmerged counterpart PR, resolved via the existing diff-summarizer strategies — zero new external API). New Phase 5.6.5; `counterpart_references[]` threads into `doc-planner` (grounding + a "target may already be covered" write-strategy signal) and `doc-writer`; `doc-reviewer` gains a cross-space leak/screenshot-provenance check.

## [2.1.2] — 2026-07-15

### Changed
- **README `specify:` VI-level scope note (docs-only).** The "Workflow overview" role table's `specify: <VI> [<Epic>]` signature already implies the Epic is optional, but the diagram/table collapse that variant into the same PE node, which read as if only `<VI> <Epic>` were real. Added a note under the role table clarifying: `specify: <VI>` is valid and stays in the PE lane; on a VI with ≥2 Epics, Phase 2's picker offers picking one Epic, an explicit "Author one broad VI-level spec instead," or the tool's own recommendation to split into Epics via `epics:` first; on a single-Epic VI it auto-resolves to that Epic; and a broad VI-level spec writes to `spec/<VI>-<vslug>` with its `### Next step` pointing to `epics: <VI>` rather than `design: <VI> <Epic>`.

## [2.1.1] — 2026-07-15

### Changed
- **README overhaul, brought up to the Claude Code edition's documentation depth (docs-only).** Added a `## Workflow overview` section (mermaid PM/PA/PE/Dev/QA role-graph of the `idea:` → `create-vi:` → `create-ard:` → `epics:`/`specify:` → `design:` → `implement:` → `document:` → `release-notes:` pipeline, an annotation table, a "Sources of truth & artifact homes" note, and a "Cross-cutting skills" subsection) and an `implement: workflow` phase-flow mermaid diagram, both adapted to this edition's keyword-trigger skill names, strong-tier (Opus/GPT-5.5) model set, and `task()` dispatch — with no cost/statusline nodes, since those are not ported. Expanded the grouped sub-agent name list into a full 30-row `| Agent | Model | Description |` table, correcting the model column to reflect this edition's reality: sub-agents have no `model:` frontmatter pin — the strong tier is passed by the caller at each `task()` call site. Added a `## Reference docs` catalog of the 38 `skills/_shared/*.md` files, an `## Architecture (ARD) consumption` section, a `## Dependencies & companions` section, a trimmed `## Session feedback` section (no session-cost), and expanded `## Hooks` into a table (4 hooks, including the previously-undocumented `test-notify`).
- Root `README.md` — added a `## Prerequisites` section, an environment-variable configuration step (`VAULT_PATH` / `SPECS_PATH` / `REPOS_PATH`, confirmed load-bearing across `skills/_shared/*.md` but previously undocumented at the marketplace level), and a `## Runtime directories` section, mirroring the sibling `ihudak-claude-plugins` marketplace's root README.

### Fixed
- **Root `README.md` Plugins table described the retired `/impl` / `/fix-vuln` taxonomy (docs-only).** The `dev-workflows` row still read "`/impl` for feature implementation, `/fix-vuln` for CVE remediation, `/upgrade` for dependency upgrades" — the pre-1.4.0 command surface, not the current 19-skill lifecycle. Replaced with an accurate summary; also refreshed the stale `skills/impl/`, `fix-vuln/` example paths in the "Repository structure" tree.

## [2.1.0] — 2026-07-14

### Changed
- **`release-notes-writer` — editorial shaping (enhancement).** The writer no
  longer defaults to a flat "2–4 sentence paragraph" for every entry. Process
  step 3 now instructs conditional shaping grounded in shipped dynatrace-docs
  feature-updates: prose stays the default, but when a feature **enumerates
  discrete options** (e.g. a new dropdown with N selectable values) the writer
  uses a short intro sentence + a **bulleted list** (bold each option); it leads
  with the recommended/new default path and **demotes deprecated or manual-only
  options** to a trailing sentence or an optional `> Note:` line rather than
  presenting them as equal peers; and it uses **bold** for UI/field names and
  inline `code` for filenames, identifiers, and flags. The
  `release-notes-writer` handoff schema's `prose` field description was relaxed
  to match (no longer contradicts the agent by mandating a single paragraph).
  Motivation: a real release note enumerating four container-registry options
  read better as a list with the deprecated option footnoted than as a
  comma-chained paragraph.

## [2.0.1] — 2026-07-14

Port of the upstream Claude Code `dev-workflows` **v2.31.0 audit-fix batch** into
the Copilot edition. The Copilot port was based on Claude v2.30.0 (pre-fix) and had
inherited the same latent defects. Each finding was cross-checked against the
Copilot tree and fixed in a GitHub-Copilot-CLI-compatible way. No behavioural
triggers changed.

### Fixed
- **`test-baseliner` dual-schema (BLOCKER)** — the agent now emits a top-level
  `**Status**:` field in both the capture (`## Test Baseline`) and verify
  (`## Test Verify Report`) blocks, so `vuln-fixer` / `upgrade-executor`
  status-branching is no longer dead.
- **Sub-agent `ask_user` misuse** — `vuln-fixer` and `upgrade-executor` no longer
  claim to prompt the user directly (a sub-agent can't in Copilot CLI). On a test
  regression they now return `status: TEST_REGRESSION` + diagnosis; the orchestrator
  asks the user and re-invokes with `phase: regression-resume` + `regression_decision`
  (mirrors the existing verify-resume handshake). Added the missing "Handling Test
  Failures" section to `upgrade:`.
- **`implement:`** — removed stale `general-purpose` + `model: opus` override prose
  that contradicted the actual dispatch; renamed the mis-labelled "Pre-Phase 2" to
  "Phase 1.6" (it sits between 1.5 and 1.7).
- **`document:`** — renumbered Phase 0 steps (were skipping step 2) and fixed all
  cross-references; repointed dead "Increment 2/3" pointers to concrete phases
  (4.5 / 5.7 / 5.9).
- **`epics:`** — swapped the inverted Phase 6.1 (clarifications) / 6.2 (style-check)
  labels and fixed a residual stale cross-reference.
- **`upgrade-planner`** — corrected a false "pinned to Opus" claim (it runs on the
  detection chain).
- **`doc-writer`** — changelog rule now correctly says "no Jira key"; added `bash`
  to `tools:` so it can copy local screenshots.
- **`doc-fixer`** — finding field aligned to the message-based schema (`message`).
- **`create-ard`** — VI-level `jira-reader` fallback is now a formal `task()` block
  with `depth`; annotated in the model-routing comment.
- **`idea`** — carry-forward now includes `source_refs` / `provenance`.
- **`readiness-reviewer` + `workflow-states`** — `CONCERN` vocabulary unified to `MINOR`.
- **`api-guideline-reviewer`** — removed a self-contradictory "never use a subset"
  instruction.
- **`guideline-reviewer`** — gated the dt-app MCP lookup section on MCP availability
  (the agent's `tools:` grant no MCP).
- **Handoff schema drift** — `jira-reader` (`branch_from`/`branch_to`),
  `impl-maintenance` (Command enum extended to 12: `idea:`, `create-vi:`,
  `create-ard:`, `ready:`), `release-notes-writer` (`code_repos` input +
  `jira_phrasing`/`source_phrasing`/`source_location` gap fields), and the
  `code-scanner` / `diff-summarizer` inline `## Output` sections (now match their
  handoff SSOTs — `prep:` block, per-PR fields).
- **Citations** — normalised bare path references to the full
  `~/.copilot/installed-plugins/…` prefix (`pre-lint.md`,
  `release-notes-writer` handoff) and broadened the `jira-reader` `NOT_FOUND`
  description to cover both resolution forms.

### Skipped (not applicable to Copilot)
- Cost / statusline features (intentionally absent from the Copilot edition).
- The "Skill in allowed-tools" finding — Copilot reads `model-routing.md` via `view`,
  not a Skill-tool invocation.



Major re-sync with the upstream Claude Code `dev-workflows` plugin (v2.30.0),
which had evolved into a full product-development lifecycle while this Copilot
edition fell behind. **Breaking**: triggers flattened and renamed.

### Added
- **Product-development lifecycle skills** ported from Claude Code: `idea:`,
  `create-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `release-notes:`,
  `ready:`, `docs-profile:`, `feedback:`, `prompt:`, `prompt-brainstorm:`,
  `prompt-grill-me:`.
- **11 new sub-agents**: `idea-reader`, `vi-reviewer`, `ard-reviewer`,
  `spec-reviewer`, `design-reviewer`, `readiness-reviewer`, `doc-writer`,
  `epic-writer`, `release-notes-writer`, plus the extracted `api-guideline-reviewer`
  and `guideline-reviewer` review agents (the reviewer skills are now thin
  dispatchers). Total sub-agents: 30.
- **`dynatrace-docs/` reference bundle** and 10 handoff schemas consolidated under
  `skills/_shared/handoff/`.
- **GPT-5.5 added to the strong model tier** as a peer of Opus 4.8/4.7/4.6
  (GPT models were unavailable in Claude Code, so the upstream used Opus only).

### Changed — BREAKING
- **Triggers flattened and renamed**:
  - `impl:code:` / `impl:` → **`implement:`**
  - `impl:docs:` and `impl:jira:docs:` → **`document:`** (dual-mode)
  - `impl:jira:epics:` → **`epics:`**
  - `fix-vuln:` → **`vuln:`**
- Reviewer skills (`api-guideline-reviewer`, `guideline-reviewer`) split into thin
  dispatcher skills + dedicated review agents holding the logic.
- Target/global instruction-file references updated from `CLAUDE.md` /
  `~/.copilot/CLAUDE.md` to `.github/copilot-instructions.md` /
  `~/.copilot/copilot-instructions.md` throughout.

### Removed
- Legacy skills `impl`, `impl-dispatcher`, `impl-docs`, `impl-jira`, `fix-vuln`
  and 9 orphaned sub-agent handoff directories.
- **Session cost reporting** (`/statusline`, `emit-cost`, cost-emission refs) and
  **statusline integration** — intentionally not ported; GitHub Copilot CLI
  exposes no cost/usage API or statusline extension point.

## [1.8.2] — 2026-06-16

### Changed
- **`docs-style-checker` — Vale + `dt-style-checker` now run as a
  COMPLEMENTARY chain, not a fallback-only relationship.** Empirical
  verification on the PRODUCT-14902 docs run showed the two checkers
  catch different classes of issue:

    | Class of finding | Vale catches | `dt-style-checker` catches |
    |---|---|---|
    | Lexical (banned words, contractions, hyphens) | ✅ at scale | partial |
    | Frontmatter completeness (`navigation:`, title length) | ✅ | ❌ |
    | Engineer jargon (`latest-minus-one`, `LTS-1`) | ❌ no rule | ✅ |
    | Cross-page label consistency | ❌ | ✅ |
    | Subject-verb agreement, misplaced modifier | ❌ | ✅ |
    | Plural/singular UI-label mismatch | ❌ | ✅ |

  Running ONLY the primary linter misses the semantic / cross-page class.
  As of v1.8.2, when Vale (or another primary linter) runs successfully,
  `dt-style-checker` ALSO runs as a complementary semantic pass; both
  finding sets are merged with line-level dedupe. When the primary linter
  fails, `dt-style-checker` continues to serve as the fallback (v1.7.0
  behaviour preserved). When the `dt-style-guide` plugin isn't installed,
  the chain degrades cleanly to the primary pass only.
- **`docs-style-checker` output schema v3.** Old fields (`linter`,
  `command`) are renamed to `primary_linter` / `primary_command` and new
  fields are added: `complementary_linter`, `complementary_command`,
  `complementary_error`. Each violation record now carries a `source:`
  field (`primary` | `complementary`) for traceability. Callers that
  parsed the old schema by string-matching `linter:` need to update.
- **`impl-jira` Phase 6.7 and `impl-docs` Phase 3.4 hard-rule text
  expanded** to describe the chained behaviour. Removed a stale
  duplicate `ERROR` heading block in `impl-jira/SKILL.md` that was
  introduced during the v1.7.0 edit.

### Fixed
- **Bug discovered during PRODUCT-14902 Vale-verification round:** when
  Vale was available, `dt-style-checker` was completely skipped — even
  though it catches semantic / cross-page issues Vale doesn't have rules
  for (the v1.7.0 rationale of "fallback only" was based on the wrong
  assumption that Vale was a superset). The chain now ensures
  high-confidence semantic findings (jargon, UI-label consistency,
  subject-verb agreement) are not silently dropped when Vale exists.

## [1.8.1] — 2026-06-16

### Fixed
- **`doc-planner` — no Jira keys in `changelog:` entries.** New hard rule:
  proposed `frontmatter_updates.changelog.entry` text MUST NOT embed the
  Jira key (e.g. `(PRODUCT-14902)` suffix). The Jira reference is carried
  by the commit message and the file diff, not by the customer-visible
  page changelog. Verified against `dynatrace-docs`: fewer than 5 of
  5500+ pre-existing changelog entries cite an issue key — basically
  zero convention support. Caught during PRODUCT-14902 review where
  v1.8.0 added `(PRODUCT-14902)` to 5 changelog entries.
- **`doc-planner` — cross-product reciprocal touches stay product-scoped.**
  New hard rule: when a "minimal touch" target is on an existing page
  belonging to product X but the change is about a feature shipped by
  product Y, the writer's note must be a one-line cross-link to product
  Y's dedicated page — NOT a copy of product Y's implementation detail
  (throttling rules, enum values, precedence, etc.). Caught during
  PRODUCT-14902 review where v1.8.0 added per-pool ActiveGate
  throttling detail to the OneAgent update page (OneAgent has no
  per-pool throttling; readers don't need that depth on the OA page).

## [1.8.0] — 2026-06-16

### Changed (breaking for callers that depended on auto-corrected docs)
- **`_shared/source-truth.md` principle shift: plugin is the analyst,
  user is the decision-maker.** Replaces the v1.7.0 "Implementation >
  Description (code wins, always)" rule with a discrepancy-escalation
  protocol. When source and description disagree, the plugin presents
  the analysis to the user as a table and asks per-discrepancy whether
  to:
    - document as source suggests (match what shipped)
    - document as Jira claims (with an intentional-discrepancy marker
      + bug-report draft so the user can file a defect against the
      implementation team)
    - skip and report (omit from docs + record in bug-report draft)
  The user's PM/sprint/scope context is the deciding factor — not the
  plugin's keyword grep.
- **`doc-planner` no longer rewrites topic notes to match the source.**
  The planner now records both `jira_phrasing` and `source_phrasing`
  in `verification_warnings[]` and leaves the decision to the
  orchestrator + user (per `_shared/source-truth.md` §7). Pre-v1.8.0
  callers that expected the planner to silently correct claims will see
  the original phrasing preserved until Phase 5.8 resolves it.
- **`verification_warnings` schema v2.** Fields renamed/added:
    - `claim` (preserved)
    - `jira_phrasing` (new, verbatim)
    - `source_phrasing` (new, verbatim — "(not verifiable)" when no
      source evidence)
    - `source_location` (replaces `source_checked`)
    - `technique` (added `menu-builder`, `no-source-evidence`)
    - `finding` (added `AMBIGUOUS`; renamed semantic meaning of
      `NOT_FOUND` to specifically signal implementation-gap)
    - `number` (new, stable index for cross-reference)
    - Removed: `correction`, `recommended_action` (decisions are now
      the orchestrator's responsibility, not the planner's)

### Added
- **`impl-jira` Phase 5.8 — Discrepancy analysis & user decision.**
  New phase that runs after doc-planner (Phase 5.7) when there are
  CONTRADICTED / NOT_FOUND / AMBIGUOUS warnings. Presents an analysis
  table to the user, asks for a batch decision OR per-discrepancy
  decisions, builds a `discrepancy_decisions[]` record, and sets
  `bug_report_destination` if any decisions need a bug-report draft.
- **`impl-jira` Phase 6 — bug-report draft output.** When
  `bug_report_destination` is non-null, the writer emits a Markdown
  file at the auto-discovered vault project folder (same destination
  policy as the release-notes draft):
  `<vault-project-folder>/<JIRA_KEY>-implementation-gaps.md`. Format
  defined in `_shared/source-truth.md` §7.5.
- **`doc-reviewer` — intentional-discrepancy marker awareness.** The
  8th review dimension (Source-code accuracy) now recognises an
  `<!-- intentional-discrepancy: ... -->` HTML comment immediately
  before doc prose that describes a Jira claim the source contradicts.
  When the marker is present, the discrepancy is treated as a known
  recorded gap (NOT BLOCKER). When absent, the BLOCKER rule from
  v1.7.0 still applies.
- **`_shared/source-truth.md` §7 — Discrepancy escalation protocol.**
  Comprehensive new section covering the table format, the batch
  and per-discrepancy prompts, the `discrepancy_decisions[]` record,
  the bug-report draft destination + format, and the
  intentional-discrepancy marker format.

### Migration notes
- Local automation that invoked `doc-planner` and expected the topic
  notes to be auto-corrected to source phrasing will now see the
  original (Jira) phrasing in `topics[].notes`. Look at
  `verification_warnings[]` to find each discrepancy and apply the
  decision externally, OR pipe through the new `impl-jira` Phase 5.8.
- Local automation that parsed the old `verification_warnings`
  schema needs to read `jira_phrasing` + `source_phrasing` instead of
  `correction`, and `source_location` instead of `source_checked`.
- doc-reviewer callers (outside the orchestrator) who don't use the
  intentional-discrepancy marker will see BLOCKERs for any documented
  claim that lacks source evidence — same v1.7.0 behaviour. The
  marker only matters when the documentation is intentionally
  describing a gap.

## [1.7.1] — 2026-06-16

### Fixed
- **`doc-planner` — drop changelog-only frontmatter updates.** New hard
  rule: if a target's `topics:` is empty AND `frontmatter_updates.other:`
  is empty AND the only proposed change is a `frontmatter_updates.changelog`
  entry, drop the target from the checklist entirely. A changelog entry
  without a corresponding content change is meaningless — the changelog
  field is meant to summarise *what changed on this page*, and a "page
  unchanged" entry has no value to readers.
  Especially relevant for auto-generated schema-table pages
  (`{{settings-api-table-standalone}}` body) where the schema JSON's own
  `"version":` field tracks field additions; the doc page just re-renders
  it. Convention is verifiable by sampling siblings: when 90%+ of pages
  in the same directory lack a `changelog:`, the planner must respect
  that convention. Caught during PRODUCT-14902 review where v1.6.0
  added a changelog to `builtin-deployment-activegate-updates.md` whose
  body was unchanged (only 1 of 439 sibling schema pages had a changelog
  precedent).

## [1.7.0] — 2026-06-16

### Added
- **`_shared/source-truth.md`** — new shared policy: **Implementation >
  Description**. The source code is what customers see; Jira tickets,
  design specs, and prose descriptions are the *starting point*, not the
  *spec*. Every user-visible claim in generated documentation MUST be
  verified against the implementation (enums, schema JSON, data-source
  classes, UI label constants, defaults, validators) before publication.
  Born from PRODUCT-14902 where the Jira "User Story" listed 3 target-
  version options but the actual source enumerated 4 (Latest / Previous /
  **Older** / specific).
- **`doc-planner` source-verification step (8.5)** — new mandatory pass.
  Accepts `code_repos: [{slug, path}]` input from the orchestrator and
  verifies every user-visible claim (option lists, labels, defaults,
  counts, mode names) against the actual source using the techniques in
  `_shared/source-truth.md` §3. Emits `verification_warnings[]` for any
  claim that cannot be verified OR is contradicted by the source. The
  planner's topic notes MUST reflect the verified phrasing, not the
  description's.
- **`doc-reviewer` 8th review dimension — Source-code accuracy.** Accepts
  the same `code_repos` input. Spot-checks 3–5 user-visible claims per
  file against source. **A documented option/label/count that does NOT
  appear in source is BLOCKER, not CONCERN** — customer-facing wrongness
  blocks publication.
- **`impl-docs` Phase 3.4 — mandatory style check.** Previously, impl-docs
  had no style-check phase; now it invokes `docs-style-checker` before
  Phase 3.5 (doc-reviewer), with the same fix cycle as impl-jira Phase 6.7.

### Changed (breaking for orchestrators that previously skipped style on tool absence)
- **`docs-style-checker` ERROR → fallback path.** Previously, when the
  primary linter (Vale / project lint / markdownlint) errored at runtime
  (missing binary, non-zero exit), the agent returned `status: ERROR`
  without trying the `dt-style-checker` fallback. Now the agent ALWAYS
  tries the fallback before returning ERROR. `NOT_CONFIGURED` is reached
  ONLY when no primary linter is configured AND the `dt-style-guide`
  plugin is not installed. **Some check is better than no check.**
- **`impl-jira` Phase 6.7 is now MANDATORY.** New hard rule at the top of
  Phase 6.7: the orchestrator MUST dispatch `docs-style-checker` and act
  on its return — never skip on its own judgement of which linters are
  installed. The "Proceed to review without style check" choice was
  removed from the ERROR escalation (replaced with "Proceed to
  doc-reviewer" since doc-reviewer still runs).
- **`impl-jira` Phase 5.7 doc-planner input** — `code_repos:` field added
  (array of `{slug, path}`). Required for source-truth verification. When
  omitted, doc-planner emits a `verification_warnings[]` entry per
  user-visible claim.
- **`impl-jira` Phase 7 doc-reviewer input** — `code_repos:` field added
  for the new 8th review dimension.
- **`risk-planner` hard rules** — explicitly forbid recommending "skip
  the style check" as a valid disposition (closes the loophole that let
  v1.6.0 PRODUCT-14902 ship with no style check). Explicitly forbid
  recommending "trust the Jira description" over source code.

### Fixed
- **Vale-missing → silent skip regression.** Pre-v1.7.0, if the agent
  container lacked the Vale binary (common in ephemeral / sandboxed
  setups), the orchestrator silently skipped Phase 6.7 entirely.
  Customer-visible style violations (engineer jargon, inconsistent UI
  labels, contradicting menu paths, plural/singular label mismatches)
  shipped uncaught. v1.7.0's `docs-style-checker` ERROR-fallback path
  closes this — the `dt-style-checker` LLM-based agent always runs as a
  second-chance check when Vale is unavailable.

### Migration notes
- Local automation that invokes `doc-planner` or `doc-reviewer` directly
  (outside the orchestrator) should add `code_repos: [{slug, path}, ...]`
  to the input block. Omitting it is non-breaking but causes
  `verification_warnings` (planner) or "not verifiable" CONCERN entries
  (reviewer) on every user-visible claim — the agents refuse to silently
  emit unverified content.
- `docs-style-checker` callers who depended on the old "ERROR on missing
  Vale binary" behaviour will now see `VIOLATIONS_FOUND` / `OK` /
  `NOT_CONFIGURED` instead (with a note in the `error:` field explaining
  that the fallback ran). Update conditional logic accordingly.

## [1.6.0] — 2026-06-16

### Added
- **`_shared/branch-naming.md`** — new shared policy: every orchestrator that
  creates a git branch (`impl:`, `impl:docs:`, `impl:jira:`, `fix-vuln:`,
  `upgrade:`) now resolves the branch *prefix* via a 4-step algorithm:
  1. `$GIT_USER_INITIALS` env var
  2. `git config --get user.initials`
  3. Sniff `git branch -a` for the dominant `<2–8-char-prefix>/<rest>` pattern
     (≥ 30 % share AND ≥ 3 occurrences)
  4. Workflow-specific fallback (`feat/`, `docs/`, `fix/`, `chore/`), with a
     mandatory `ask_user` escalation when reached
- **`impl:jira:` Phase 1 Q6** — auto-discovered `<vault>/Projects/Products/**/<JIRA_KEY>*/`
  is now used for BOTH the release-notes destination AND the screenshot
  staging directory. The Q6 prompt was reworded to make this explicit.
- **`doc-planner` `screenshot_staging_dir` input field** — orchestrators now
  pass an explicit persistent directory for screenshot staging. doc-planner
  validates it and emits a gap if missing while `image_policy` is
  `cdn_upload_required`.

### Changed (breaking for orchestrators that depend on hard-coded prefixes)
- **`impl:code:` Phase 2.5** — branch-prefix detection now references
  `_shared/branch-naming.md` instead of the previous "check `git branch -a`,
  default to `feat/`" rule.
- **`impl:docs:` Phase 2.5** — same.
- **`impl:jira:` Phase 5.5** — same. Also rewritten to use explicit
  `git -C <docs_repo_root>` form everywhere (clean-tree check, branch sniff,
  checkout). The previous `git checkout -b docs/...` from cwd silently
  created the branch in whichever git repo cwd happened to be — typically
  the wrong repo when the docs repo is a sibling of cwd.
- **`upgrade:`** — branch-prefix detection now references
  `_shared/branch-naming.md` (was: "default to `chore/`"). Combined prefix
  example shifts from `chore/upgrade-springboot-to-3.3.11` (always) to
  `<resolved-prefix>/upgrade-springboot-to-3.3.11` (e.g.
  `ivgu/upgrade-springboot-to-3.3.11` when `GIT_USER_INITIALS=ivgu`).
- **`fix-vuln:`** — same; fallback prefix `fix/` preserved when detection misses.
- **`impl:jira:` repo_root references** — five spots in `impl-jira/SKILL.md`
  that previously said `<cwd's git root>` (Phase 5.6 doc-location-finder,
  Phase 5.7 doc-planner, Phase 6.7 docs-style-checker, Phase 7 doc-fixer ×2)
  now say `<absolute path to the docs repo root — NOT cwd's git root>`. The
  orchestrator's cwd may be a different repo (marketplace, code repo,
  obsidian vault, etc.); the docs target must be passed explicitly.

### Fixed
- **`doc-planner` screenshot staging path** — previously hard-coded to
  `/tmp/<JIRA_KEY>-screenshots/`; this path is wiped on container restart and
  loses staged screenshots before they can be CDN-uploaded. New default is
  the orchestrator-provided `screenshot_staging_dir` (typically the Obsidian
  vault project folder). The agent now refuses to use `/tmp/` even if the
  orchestrator omits the input — it falls back to a persistent sibling of
  the docs repo and flags a gap.
- **`impl:jira:` Phase 5.5 cwd assumption** — the previous spec issued
  `git checkout -b docs/<slug>` without `-C`, which created the branch in
  the cwd's git repo (often the marketplace repo when the agent is run from
  the plugin source tree). Now explicitly `git -C <docs_repo_root> checkout -b ...`.

### Migration notes
- Users with team-specific branch prefix conventions (e.g. `<initials>/`)
  should set `GIT_USER_INITIALS=<initials>` in their shell rc, or run
  `git config --global user.initials <initials>` once. The plugin's behaviour
  for users who do NOT set either is **unchanged** — the workflow-specific
  fallback (`feat/`, `docs/`, `fix/`, `chore/`) is still used.
- Local automation that invokes `doc-planner` directly (outside the
  orchestrator) should add a `screenshot_staging_dir` field to the input
  block if any `image_policy: cdn_upload_required` page is in scope.
  Otherwise the planner emits a gap (no behaviour break — the gap is for the
  caller to resolve).

## [1.5.0] — 2026-06-15

### Added
- **`impl:jira:docs:` — release-notes draft output.** When the VI's frontmatter
  has `relevant_for_release_notes: "Yes"` or a non-empty `release_versions`
  string, the workflow now generates a release-notes draft alongside the
  feature documentation page. The draft is written to a configurable
  destination (auto-discovered Obsidian project folder by default, custom
  path, stdout, or skip — chosen via Phase 1 Q6) — **never** into the
  dynatrace-docs repo, because that path is owned by Jira-driven automation.
  The draft is rendered in the dynatrace-docs `{{#context}}` /
  `{{#internal-note}}` block format so the user can paste it into Jira and
  the existing automation re-emits it into the docs repo.
- **`doc-planner` — `release_notes_block` output field.** New top-level
  output that captures one entry per declared release version with the
  rendered template, citation source list, and assignee/reporter/PE/status
  populated from `value_increment.frontmatter`. `target_format:
  dynatrace-docs-release-notes-v1` lets consumers detect the schema.
- **`jira-reader` — full frontmatter exposure.** `value_increment` and every
  `linked_items[]` entry now carry a `frontmatter:` sub-object containing
  the file's full raw frontmatter. Always-surfaced fields:
  `assignee`, `reporter`, `execution_assignee`, `team`, `project`,
  `fix_versions`, `release_versions`, `relevant_for_release_notes`,
  `owning_program`, `labels`, `resolution`. Any additional fields the file
  declares are passed through verbatim. Existing schema fields unchanged
  (additive only).
- **`jira-reader` — branch-hint extraction.** Scans the `Pull Requests`
  section of each Jira-export file for sub-bullets like
  `- Branch: \`feature/MGD-1127-...\` → \`master\``. When present, exposes
  `branch_hint` and `target_branch_hint` on the matching
  `pull_requests[]` entry.
- **`diff-summarizer` — Strategy 0 branch-hint resolution.** When
  `branch_hint` is present on a PR ref, attempts
  `git rev-parse refs/heads/<hint>` (and `origin/<hint>`) before falling
  through to existing Strategies 1–4. Records `resolved_via: branch_hint`
  on hits.
- **`impl-docs` — Jira-ticket detection.** When `impl:docs: @<file>` loads
  a file with frontmatter `key: <JIRA_KEY>` plus `[[wikilink]]` references
  and a `## Linked Issues` / `## Pull Requests` heading, the skill offers
  to re-route to `impl:jira:docs:` instead of running the lightweight prose
  workflow.
- **`impl-jira` Phase 9 — image-upload reminder.** Final report now lists
  every screenshot staged outside the docs repo (where
  `image_policy: cdn_upload_required`), so the user knows what needs
  manual CDN upload before merging the docs PR.

### Changed (breaking for orchestrators that hardcode `/repos/`)
- **`impl-jira` repo discovery — `$REPOS_PATH`-based.** The hardcoded
  `/repos/<repo>/` path lookup in Phase 4 is replaced with a configurable
  scan rooted at `$REPOS_PATH` (default `/workspace`; colon-separated list
  supported). For each in-scope PR repo URL slug, the orchestrator scans
  candidate directories under `$REPOS_PATH`, runs
  `git remote get-url origin` (5s timeout per dir), and matches by the
  upstream URL's last path segment. When multiple local clones share an
  upstream (e.g. `cluster` + `cluster-repo`), the auto-preferred order is:
  `<slug>-repo` > `<slug>_repo` > `<slug>_fast` > alphabetically last.
  Sub-agents (`diff-summarizer`, `code-scanner`) now receive an absolute
  `repo_path` plus a `repo_url_slug` and reject mismatches via
  `git remote get-url origin` cross-check.
- **Phase 1 Q3 / Q4 wording.** Code-scan and refresh-policy questions now
  refer to `$REPOS_PATH` instead of `/repos/`.
- **Phase 5 error escalation.** `DIRTY_TREE` / `REFRESH_BLOCKED` prompts
  now report the resolved `repo_path` instead of a synthetic `/repos/...`
  string.
- **`doc-planner` topic-list semantics.** "What's new" remains a valid
  topic on a normal documentation target, but the **standalone release
  notes draft is no longer one of the targets** — it is emitted via the
  top-level `release_notes_block` field instead. New hard rule forbids
  proposing release-notes snippet paths as `target_path`.
- **`doc-location-finder` exclusions.** New hard rule: never propose a
  release-notes / what's-new snippet directory as a target (e.g.
  `_snippets/release-notes/`, `_content/whats-new/<product>/sprint-*`).
  Even high keyword-overlap matches in those paths are skipped, because
  the docs repo's release-notes pages are produced by Jira-driven
  automation and a manual write would be overwritten.

### Fixed
- **`diff-summarizer` and `code-scanner` — git fetch/pull timeouts.**
  `git fetch --all --prune` and `git pull --ff-only` are now wrapped in
  `timeout 60`; on timeout, the agent returns `REFRESH_BLOCKED` with the
  reason `"git fetch timed out after 60s"` instead of hanging the workflow.

### Migration notes
- If you have local automation that invokes `diff-summarizer` or
  `code-scanner` directly (outside the orchestrator), update the input
  block: `repo_path` is now an absolute path (any path is acceptable, not
  only `/repos/<name>`), and a new optional `repo_url_slug` enables the
  upstream cross-check.
- If you previously customised the `impl-jira` Phase 4 to point at
  `/repos/`, set `REPOS_PATH=/repos` in your environment to preserve the
  old behaviour.

## [1.4.0] — 2026-06-15

### Breaking changes
- **Sub-agents are now Copilot custom agents, not skills.** The 19 internal
  sub-agents (`risk-planner`, `code-review`, `test-baseliner`, `test-writer`,
  `review-fixer`, `impl-maintenance`, `jira-reader`, `diff-summarizer`,
  `code-scanner`, `doc-reviewer`, `doc-fixer`, `doc-location-finder`,
  `doc-planner`, `docs-style-checker`, `epic-reviewer`, `upgrade-planner`,
  `upgrade-executor`, `vuln-research`, `vuln-fixer`) moved from
  `skills/<name>/SKILL.md` to `agents/<name>.md` with proper Copilot agent
  frontmatter (`name`, `description`, `tools`).
- **`plugin.json` now declares `"agents": "./agents/"`** in addition to
  `"skills": "./skills/"`.
- **Orchestrator dispatch sites updated**: every `task(agent_type: "<bare-name>")`
  call is now `task(agent_type: "dev-workflows:<name>")`. Bare names matched
  neither a Copilot built-in nor a registered custom agent, so 7 of the 9
  distinct dispatches were silently misrouting before this release.
- **Sub-agent `references/` subdirectories preserved** at their original
  locations (`skills/<sub-agent>/references/handoff.md`) — agents read them
  via absolute paths inside `~/.copilot/installed-plugins/...`.

### Added
- Model fallback chain extended with GPT-5.5 (above Sonnet) and GPT-5.4 / Gemini
  3.1 Pro (below Sonnet) — leveraging Copilot's multi-vendor model access.
  Opus 4.8 added at the top of the Claude chain (forward-compatible — currently
  resolves to whichever Opus version the CLI exposes).

### Fixed
- `impl-dispatcher` SKILL.md version string corrected from `1.2.1` → `1.3.0` →
  current `1.4.0`.

## [1.3.0] — 2026-05-15

### Changed
- **Cross-platform sync with Claude Code plugin (v1.3.0).**
  - Ported `check_guidelines.py` and `checklist-template.md` to
    `guideline-reviewer/references/` (added in Claude Code v1.2.0, missing
    from the Copilot port).
  - Version numbers now track 1:1 between Copilot CLI and Claude Code
    plugin repos. Previous version drift: Copilot 1.2.1 / Claude 1.2.0.

## [1.2.1] — 2026-05-15

### Breaking changes
- **`impl:` is now a dispatcher.** Bare `impl:` no longer runs the code-implementation
  workflow — it prints a help page with the command matrix. Use `impl:code:` explicitly.
  Aligns with Claude Code plugin behaviour since v1.1.0.

### Added
- **`impl-dispatcher` skill.** Help / dispatcher triggered by bare `impl:`. Lists all
  `impl:*` variants and related skills (`fix-vuln:`, `upgrade:`), then stops.

### Changed
- **`impl` skill trigger narrowed.** Now only activates on `impl:code:` and `implement:`.
- **Marketplace descriptions enriched.** `dev-workflows` and `dt-style-guide` descriptions
  in `.github/plugin/marketplace.json` now enumerate all skills, sub-agents, and hooks.

## [1.2.0] — 2026-05-12

Copilot CLI port of the Claude Code dev-workflows plugin (v1.1.0).

### Added
- **Namespaced skill layout.** `skills/impl/`, `skills/impl-docs/`, `skills/impl-jira/`
  become the natural-language prefixes `impl:`, `impl:docs:`, `impl:jira:docs:`,
  `impl:jira:epics:` via Copilot CLI's skill discovery.
- **`impl:code:` full workflow.** Structured code-implementation skill: classify →
  optional Opus planning → feature branch → test baseline → implement → test-writing →
  optional Opus review → maintenance → report.
- **`impl:docs:` full workflow.** One-shot doc-editing skill: classify → plan →
  implement → doc-reviewer gate → maintenance → report.
- **`impl:jira:docs:` and `impl:jira:epics:` workflows.** Jira-driven documentation
  and Epic-writing skills with parallel sub-agent invocation, style checking, and
  Opus review gates.
- **15 sub-agent skills.** test-baseliner, test-writer, risk-planner, code-review,
  review-fixer, impl-maintenance, jira-reader, diff-summarizer, code-scanner,
  doc-location-finder, doc-planner, docs-style-checker, doc-reviewer, doc-fixer,
  epic-reviewer.
- **`fix-vuln:` workflow.** Security vulnerability remediation with NVD lookup,
  minimal-version fix strategy, baseline tests, and per-CVE branches/PRs.
- **`upgrade:` workflow.** Component upgrade with before/after test verification.
- **Hooks.** `preload-context.sh` injects git context on skill activation;
  `post-tool-use.sh` tracks tool usage.
- **Shared references.** `_shared/model-routing.md` defines task classification,
  model routing, and the mandatory Opus code-review checklist.

### Changed (vs Claude Code v1.1.0)
- Skills use SKILL.md with YAML frontmatter (not `commands/*.md` / `agents/*.md`).
- Orchestrator skills declare `allowed-tools:` in frontmatter; sub-agent skills do not.
- Path references use `~/.copilot/installed-plugins/...` instead of `${CLAUDE_PLUGIN_ROOT}`.
- Hooks use `${PLUGIN_ROOT}` instead of `${CLAUDE_PLUGIN_ROOT}`.
