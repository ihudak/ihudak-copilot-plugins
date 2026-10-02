---
name: vuln
description: >
  Security vulnerability fix workflow. Researches CVEs via NVD, applies dependency and code fixes one at a time, runs review-tier code review, and verifies with tests.
  Activated when the user prompt starts with "vuln:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Fix security vulnerabilities: the argument (text following the `vuln:` trigger)

Each argument token is either `JIRA-ID:CVE-ID` (e.g. `MGD-2423:CVE-2023-46604`) or a bare `CVE-ID` (e.g. `CVE-2023-46604`). Parse and filter each token, research all CVEs first, then fix them one at a time.

---

## Step 0 — Classify & Route (mandatory)

**Run flags — before anything else in this phase.** Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/run-flags.md` and execute its `strip-run-flags` entry point on the argument string. It returns `run_flags` and the **stripped** arguments; every parsing step below reads only what it leaves behind. For this skill both `--skip-feedback` and `--enforce-model` apply. **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip — so it is neither parsed nor reported ignored. A malformed or unreachable `--enforce-model` stops the run here, before `specs-preflight` and before any write, and emits no feedback entry. Print the `Run flags:` line when either flag is non-default, and repeat it in the final report. **Under `--enforce-model`** (`run_flags.enforced_model`; `_shared/model-routing.md` §10), **every** subagent dispatch in this run passes `model:` explicitly, in §5's dispatch form — including a dispatch whose line below shows no `model:` argument and one described as dispatch-pinned to a chain — and every handoff to an agent that itself dispatches another carries `enforced_model:` so the nested dispatch is pinned too. The final report's model-routing line then reads `Model routing: bypassed — enforced <id> (flag|env)` in place of any degradation note.

Load and follow the model-routing policy at `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then classify **per CVE**, based on the size of the required repository change — not the CVE category alone.

Default heuristics:

| Required fix (from research output) | Classification |
|---|---|
| Patch or same-major minor bump, no source-code changes expected | `MODERATE` |
| Major version bump, or code changes required to adopt the new version | `SIGNIFICANT` |
| Major bump of a security-critical library, or code changes in auth/session/token/permission/payment/audit paths | `HIGH-RISK` |

Because the required fix is not known up front, start with a provisional `MODERATE` routing block for research, then finalize the classification from the research report **before** fix application begins.

**Specs-repo preflight.** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` and execute its `specs-preflight` entry point (§3) inline: flush any leftover session artifacts from an earlier run, retry an artifact commit that failed to push, and settle the branch. This runs against `$SPECS_PATH` only — `git -C "$SPECS_PATH"`, never a `cd`, so the code repo this run is about to branch and fix is untouched (§1 rule 1). Prompt-free, and silent unless it acts, a guard fires, or §3.1 reports a misconfigured `$SPECS_PATH`. If a guard fires, emit its §5 notice; if it returns `specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1), carry that flag for the whole run — the terminal `commit-artifacts` step skips on it.

---

## Step 1 — Prepare

1. **Parse** — Extract Jira ID (optional) and CVE ID from each token.
2. **Determine NOJIRA placeholder** — Scan recent branch names and commit history for `NOJIRA` / `NO-JIRA`; use the project convention when a Jira ID is missing.
3. **Filter** — Skip non-CVE IDs (`CWE-*`, OWASP patterns) with a warning.
4. **Snapshot repo context** — Note the repo path and, when obvious, the primary ecosystem so the research agent can disambiguate detection.
5. **Resolve the branch name per CVE** — Apply the "Git Workflow → Branch naming" section below now, once per CVE token, and record each result as that CVE's `branch`. This is the **only** place a branch name is produced: `vuln-fixer` creates the branch it is handed and never derives one, and Step 3.9 pushes the same value. A run that reaches the fixer without a `branch` in its prompt is a defect — the agent would invent a name, the orchestrator would push a different one, and §2.1 check 4 would fail the gate on the mismatch.

---

## Step 2 — Research (parallel)

Invoke one research task per valid CVE. Use a single agent message for the batch.

```
task(
  agent_type: "dev-workflows:vuln-research",
  model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`,
  description: "Research CVE",
  prompt: "## Vuln Research Request
  repo: [absolute repo path]
  cves:
    - id: [CVE-ID]
      jira: [optional Jira key]
  ecosystem_hint: [optional]
  model_routing:
    classification: MODERATE
    reason: <one-line>
    current_model: <the model this orchestrator is running under>
    enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
    defect_model: <§2.2 cheap chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
    detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # vuln-research; vuln-fixer (SIMPLE/MODERATE); review-fixer
    planning_model: <§2 Opus chain>   # vuln-fixer escalates here only if HIGH-RISK
    review_model:  <§2.3 review tier>    # code-review (dispatch-pinned to this chain; recorded, no override unless §10 enforces a model)
    opus_available: <true if a §2 Opus model resolved, else false>
    gate_tests_on_review: false
    notes: <any §2 / §2.1 fallback or degradation>"
)
```

Collect all reports:
- `READY` → candidate for fixing
- `NOT_IN_REPO` → notify and skip
- `LOOKUP_FAILED` → warn and offer retry or skip
- `SKIP_NON_CVE` → already filtered; no further action

Finalize the per-CVE classification from the research output. If the finalized class is `HIGH-RISK`, re-run `vuln-research` on Opus for a confirmation pass. If it is `SIGNIFICANT`, re-run on Opus when the major bump or breaking-change surface is non-trivial.

---

## Step 3 — Fix (sequential)

Process `READY` CVEs one at a time to avoid conflicting edits to the same dependency files.

**Record the tree state once, before anything is applied.** On the first CVE, run `git -C "<repo>" status --porcelain -z --untracked-files=all` and record the result as `pre_existing_dirty`; carry it unchanged through every CVE in the run. `-z` is required: without it, a path carrying a space, a `"`, a `\`, or a non-ASCII byte is quoted and octal-escaped, breaking the set comparison Step 3.9 and `code-repo-handoff.md` §2.2 carve-out 1 rely on. `vuln:` never stashes, so `stash_ref` is always `null`. This capture is what lets Step 3.9 keep a bystander's work out of the commit (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.2 carve-out 1) — `vuln:` offers no dirty-tree prompt, so the capture is the whole safeguard and must happen before the first edit.

**Start each CVE from the base branch, not from the previous CVE's.** After the capture, resolve the base per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.8 and run `git -C "<repo>" switch <base>` when HEAD is not already there. Every CVE gets its own branch and its own pull request, so a CVE that branches off its predecessor ships that predecessor's fix inside its own diff, its own review, and its own PR.

Three rules make that switch safe:

- **Confirm before leaving a branch the user chose.** On the **first** CVE, if HEAD is already on a non-default branch, do not switch silently — the user may be deliberately working there. Ask: `choices: ["Switch to <base> and branch each CVE from it (Recommended)", "Branch each CVE from <current> instead", "Cancel"]`. On later CVEs the branch HEAD sits on is one this run created, so switch without asking.
- **A failed switch stops the run, it does not proceed.** `git switch` aborts when a tracked file differs between the two branches. Report the abort and the paths git named, and stop — continuing would branch this CVE off whatever HEAD happens to be, which is the contamination this rule exists to prevent.
- **Verify the tree before the next CVE, rather than trusting the previous CVE's status.** Re-run the porcelain command; anything present that is not in `pre_existing_dirty` is residue the previous CVE left behind (a partial revert — `BUILD_FAILED` reverts the files the research report named, which for a lockfile ecosystem is not all of them). Surface it and stop rather than carrying it onto the next CVE's branch.

### Capture the test baseline — once, before the first CVE is worked

It runs after the base-branch switch above has settled, on the base tree — the tree every CVE branches from, so one capture is what every CVE's verify compares against and a second would measure the same tree again. Dispatch `test-baseliner` in `capture` mode with `model: <detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>` and `Project root: [absolute repo path]` — the same path this Step sends every `vuln-fixer` dispatch as `repo:`, and the root `vuln-fixer` step 5's verify call names in turn, because `### Suites` records each marker as a path relative to whatever root a call scanned, so two roots make every marker path disagree between the calls (`dev-workflows:test-baseliner` capture step 1, measured there). **Keep the returned `## Test Baseline` block whole** — it is re-supplied as `baseline_block` on every dispatch below, because its `### Suites` rows are what let verify tell a suite that regressed from one that could not run at either end; `passing_count` and `passing_tests` are re-keyed from it, never in place of it.

**This is the run's only test-baseline capture, and it is the orchestrator's on both paths.** `vuln-fixer` never takes one of its own: the question a failed capture raises is one only the orchestrator can put — subagents have no interactive tools — so a capture taken privately inside the agent is one the operator was never offered a say in. That is why `baseline_tests: run-fresh` is retired from the handoff rather than left standing as a second way in (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/handoff/vuln-fixer.md`), and why `BASELINE_FAILED` is retired with it: that status existed to report a capture this command no longer delegates.

Act on the returned `Status` before dispatching anything:

- `OK` or `NO_TESTS` → proceed. **A `NO_TESTS` capture is not a failure and is not asked about**: every suite ran cleanly and the repository holds no tests (`dev-workflows:test-baseliner` capture step 4), so nothing was lost and no CVE's finish is marked down for it.
- `PARTIAL` → proceed, and name the suites `### Suites` does not mark `OK` or `NO_TESTS`, each with the command that failed, in **every** CVE's `Notes` cell in the Step 4 table — the capture is the run's, so a suite it could not cover is uncovered for every CVE in it. A runner that is not installed for one language is not a reason to leave a CVE in another unfixed.
- `RUN_FAILED` or `COMMAND_NOT_FOUND` → **nothing was captured, and what to do about it is the operator's decision rather than this command's.** Surface the block's `### Suites` rows and its `### Notes` lines first — a hint has an answer to give wherever a note names the runner's own command — then ask:

  `choices: ["Specify test command to use", "Apply the fixes unverified (every pull request opens as a draft carrying the DO-NOT-MERGE banner)", "Cancel this run"]`

  - **Specify test command to use** → take free text, record it as `test_command_hint`, and re-dispatch the capture **immediately**, adding the line `command_hint: [the answer]` to the prompt. Act on the returned `Status` by this same list. Ask at most twice in a run; after that record `baseline_unverified` with the last capture failure as its reason and proceed as the option below does.
  - **Apply the fixes unverified** → record `baseline_unverified` and work every CVE. Each that reaches its verify finishes `clean_finish: false` at Step 3.9, so each pull request is a draft the banner says not to merge.
  - **Cancel this run** → stop here. No branch was cut and no file edited, so there is nothing to hand off and no CVE is reported worked. **Say where the tree is left**, though, and read it rather than asserting it: the base-branch switch above has already run **unless the first-CVE question was answered *Branch each CVE from `<current>` instead***, on which no switch was issued and HEAD is still where the operator put it. Name the branch they started on and the one they are on now.

**The question is asked once per run and its answer reused, for the same reason §2.4's consent choice is**: a baseline is a property of the repository, this command works one repository throughout, and re-asking per CVE would put the same question to the same tree.

**Where `test_command_hint` was recorded, every later `test-baseliner` call in this run carries it** — which here means every `vuln-fixer` dispatch carries it as `command_hint:`, because the verify calls are the agent's and not this command's (step 5). **A verify over a different set of suites is not a comparison**, and dropping the hint does not merely lose the verification, it manufactures a wrong answer in both directions: a hint that matched no detected suite leaves a verify with nothing to detect, returning `COMMAND_NOT_FOUND` and finishing every CVE `TESTS_NOT_RUN` after the operator supplied a command that worked; and a hint that named a working alternative to a broken runner leaves its `command_hint#<n>` row with no counterpart, so every baseline test of it falls out as **Missing from run** and the verify reports `REGRESSIONS` — putting `revert` on the menu for a security fix against a regression nothing caused (`dev-workflows:test-baseliner` verify step 2's `gone since the baseline` bullet). `implement:` states the same rule for its own dispatches; this command's hint has one extra boundary to cross, which is the whole of the difference.

**`baseline_unverified` does not distinguish its two provenances, and that is a deliberate divergence from `implement:` rather than an oversight.** There the operator's own *"Skip tests for this run"* is honoured without penalty while the run's own record after two failed `command_hint` attempts sets `clean_finish: false` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.9). Here both finish `false`: what ships unverified is a security remediation, `clean_finish: false` changes only the pull request — a draft carrying the banner — and whether §2.4's choice is put again (Step 3.9), and this state already finished `false` before the question existed — an uncovering baseline still returns `RUN_FAILED` at verify, which `vuln-fixer` step 5 turns into `TESTS_NOT_RUN` (`dev-workflows:test-baseliner` verify's pre-step gate). Honouring the answer by clearing the flag would be a loosening, not a symmetry.

**And carry every `### Notes` line the block opens with `CAVEAT: ` into every CVE's `Notes` cell whatever the `Status` was**, `OK` included: a marked line says the baseline is not what its counts claim — a qualifying suite nothing ran, counts a `Make` indirection may have summed twice, a `Make` fold's identifiers unattributed to what printed them — none of which the `Status` or the `### Suites` rows can be read off (`dev-workflows:test-baseliner` capture step 5). The mark is the agent's, so nothing here judges which note matters; an unmarked note records where a command ran and is not carried.

For each `READY` CVE, before invoking the fixer, write its research report to a temp file (`command mktemp -t dw-vuln-research-XXXXXX`, never inside a repo tree) and record its absolute path as `research_file`; the fixer, code-review, and resume steps below receive this path instead of the pasted report. Remove it with `command rm -f -- "<research_file>"` once the CVE's commit (or its BLOCKED/skip disposition) is recorded and no later step reads it.

### SIMPLE / MODERATE path

Invoke `vuln-fixer` with the run's baseline:

```
task(
  agent_type: "dev-workflows:vuln-fixer",
  model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>`,
  description: "Fix CVE",
  prompt: "## Vuln Fix Request
  repo: [absolute repo path]
  phase: full
  enforced_model: [run_flags.enforced_model, or omit]   # §10 — the agent passes it on its own test-baseliner dispatch
  branch: [the branch name Step 1 resolved for this CVE]
  baseline_tests: provided
  baseline_block: |
    [the captured ## Test Baseline block, verbatim and whole]
  baseline_passing: [captured count]
  baseline:
    passing_tests:
      - [captured test ids]
  command_hint: [the recorded `test_command_hint` — include this line only where the baseline step recorded one; it must reach step 5's verify call]
  jira_placeholder: [NOJIRA or omit]
  model_routing:
    classification: [MODERATE]
    reason: <one-line>
    current_model: <the model this orchestrator is running under>
    enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
    defect_model: <§2.2 cheap chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
    detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # vuln-research; vuln-fixer (SIMPLE/MODERATE); review-fixer
    planning_model: <§2 Opus chain>   # vuln-fixer escalates here only if HIGH-RISK
    review_model:  <§2.3 review tier>    # code-review (dispatch-pinned to this chain; recorded, no override unless §10 enforces a model)
    opus_available: <true if a §2 Opus model resolved, else false>
    gate_tests_on_review: false
    notes: <any §2 / §2.1 fallback or degradation>

  read the single READY research report from the file at [`research_file`]"
)
```

If the fixer returns `status: BLOCKED`, the research report at `research_file` could not be
read — an orchestrator bug, not a user choice: report the unreadable path to the user, mark
this CVE `BLOCKED` in the Step 4 summary table, and stop working this CVE. Do not retry with
a fresh research pass — that would re-derive the evidence instead of surfacing the failure.

**Read the fixer's `notes` on whatever it returns, not only on a stop.** The run's own capture above already accounts for what the *baseline* could not cover; what only the fixer can report is what its **verify** met — a suite the baseline did cover and this verify could not run, which a verify `PARTIAL` returns as `status: SUCCESS` with those suites named in `notes`; every `NEW-FAILURE: ` line it marked, which no status carries at all; and every `CAVEAT: ` line that report carried, which no status gates either (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/handoff/vuln-fixer.md`). Carry them into this CVE's `Notes` cell in the Step 4 table. A `SUCCESS` whose `notes` nobody read is a CVE reported fixed with a stack silently unverified.

Otherwise, if the fixer returns `status: TEST_REGRESSION`, follow "Handling Test Failures"
below, then re-invoke `vuln-fixer` with `phase: regression-resume` (and the same `enforced_model:` and the same `repo:` the first dispatch carried) + the chosen
`regression_decision`, the same `baseline_block` and the same `command_hint:` where one was recorded, passing the same CVE input with the original research report
re-supplied from `research_file`.

If the resumed agent returns `status: BLOCKED`, the re-supplied file path could not be read:
report the named path to the user and stop this CVE. Do NOT retry, and do NOT reconstruct
the artifact — a resume that re-derives its own input is the failure
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/context-management.md`'s read-failure contract exists to
prevent.

### SIGNIFICANT / HIGH-RISK path

1. **The baseline is the run's** — the block captured once above, before the first CVE. Do not capture again: a second capture per CVE measures the same base tree, and one taken after an earlier CVE's branch was cut would not be a baseline for this one.
2. **Invoke `vuln-fixer` with review gating enabled**:

```
task(
  agent_type: "dev-workflows:vuln-fixer",
  model: `<detection_model for SIGNIFICANT; planning_model (§2 Opus chain) only if HIGH-RISK; under §10, run_flags.enforced_model>`,
  description: "Apply CVE fix before review",
  prompt: "## Vuln Fix Request
  repo: [absolute repo path]
  phase: full
  enforced_model: [run_flags.enforced_model, or omit]   # §10 — the agent passes it on its own test-baseliner dispatch
  branch: [the branch name Step 1 resolved for this CVE]
  baseline_tests: provided
  baseline_block: |
    [the captured ## Test Baseline block, verbatim and whole]
  baseline_passing: [captured count]
  baseline:
    passing_tests:
      - [captured test ids]
  command_hint: [the recorded `test_command_hint` — include this line only where the baseline step recorded one; it must reach step 5's verify call]
  jira_placeholder: [NOJIRA or omit]
  model_routing:
    classification: [SIGNIFICANT | HIGH-RISK]
    reason: <one-line>
    current_model: <the model this orchestrator is running under>
    enforced_model: <run_flags.enforced_model, or omit>   # §10: when set, every dispatched-step *_model below equals it, and `routing: bypassed` is recorded
    defect_model: <§2.2 cheap chain — only under --skip-feedback; under §10, run_flags.enforced_model>   # defect-reporter, in place of impl-maintenance
    detection_model: <§2.1 detection chain: claude-sonnet-5.5, fallback claude-sonnet-5/4.6/4.5>   # vuln-research; vuln-fixer (SIMPLE/MODERATE); review-fixer
    planning_model: <§2 Opus chain>   # vuln-fixer escalates here only if HIGH-RISK
    review_model:  <§2.3 review tier>    # code-review (dispatch-pinned to this chain; recorded, no override unless §10 enforces a model)
    opus_available: <true if a §2 Opus model resolved, else false>
    gate_tests_on_review: true
    notes: <any §2 / §2.1 fallback or degradation>

  read the single READY research report from the file at [`research_file`]"
)
```

3. **Handle a `vuln-fixer` stop.** If the fixer returns `status: BLOCKED`, the research report at `research_file` could not be read — an orchestrator bug, not a user choice: report the unreadable path to the user, mark this CVE `BLOCKED` in the Step 4 summary table, and stop working this CVE (do not retry with a fresh research pass, and do not proceed to review-tier review). **Any other first-call return on this path stops this CVE short of the review, and is not run through it** — `BUILD_FAILED` is the reachable one, the fixer having reverted its own change — so record the returned status in the Step 4 table, let Step 3.9 decide the handoff by its own tree test rather than by the label, and move to the next CVE. It used to fall out of this step with no instruction at all. **`AWAITING_REVIEW` is the only return this path's review dispatch fires on**; when the fixer returns it, run review-tier code review before tests:
   - Capture the diff to a temp file: write `git add -N . && git diff` to `command mktemp -t dw-vuln-diff-XXXXXX` (never inside a repo tree) and record its path as `review_diff_file`
   - Write the fixer output to a temp file (`command mktemp -t dw-vuln-claims-XXXXXX`, never inside a repo tree) and record its path as `claims_file`. Invoke `code-review` with the CVE summary, the research handoff (from `research_file`), the diff (from `review_diff_file`), and `claims_file: [the path]` (dispatch-pinned to Opus; recorded as `review_model` above, no `model:` override needed)
   - **Check the review's first line before acting on the verdict.** If it is `Diff: unreadable at <path>`, the orchestrator's own `review_diff_file` could not be read — an orchestrator bug, not a user choice: surface the unreadable path to the user and stop working this CVE, marking it `BLOCKED` in the Step 4 summary table. Do NOT triage the finding and do NOT dispatch `review-fixer`: the finding names a capture failure no fixer can act on, and running the cycle would spend a fix dispatch and a re-review to arrive back here.
   - **Triage sub-step** (before any fixer dispatch): follow `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md`. For each finding, verify its claimed consequence at the location it names; keep or dismiss; record every dismissal with a reason that disposes of that finding's own claim. Hand the fixer **survivors only**, and carry the dismissal list into this run's report.
   - If review returns `BLOCK` or `PASS WITH RECOMMENDATIONS`, invoke `review-fixer` with model: `<detection_model — §2.1 detection chain; under §10, run_flags.enforced_model>` for the surviving `BLOCKER` and `MAJOR` findings
   - **Handle a `review-fixer` stop.** If its `Stop condition flag` is `NEEDS HUMAN`, do NOT re-run the review: surface the deferred BLOCKER(s) to the user with the reason `review-fixer` gave, mark this CVE `BLOCKED` in the Step 4 summary table, and stop working this CVE — do not continue to tests, and do not re-review. Then run Step 3.9 with `clean_finish: false`: the fix is on disk and stopping the CVE is not a reason to leave it in a working tree, so it is committed, pushed behind §2.4's consent choice, and any pull request that choice opens is a draft carrying the DO-NOT-MERGE banner (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2.9). Only when the flag is `CLEAR` do you **overwrite `review_diff_file`** with a fresh `git add -N . && git diff` and re-run the review-tier review once against that refreshed path — so the re-review reads the post-fix diff, not the stale pre-fix capture
   - If the second verdict is still `BLOCK`, stop and escalate; do not continue to tests. Run Step 3.9 with `clean_finish: false` — same reasoning as the `NEEDS HUMAN` stop above: the work is committed, pushed behind §2.4's consent choice, and any pull request that choice opens is a draft the banner says not to merge
   - **The recorded verdict names the version it was taken against.** Both the resumed verify step below and any regression fix that follows it change the tree after the review that produced this verdict, so the run's report states what the verdict covers and names the edits that followed it, per the `A recorded verdict names the version it was taken against` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`. Where nothing followed it, it says that too.

4. **Resume the fixer after review** — Re-invoke `vuln-fixer` with `phase: verify-resume` (and the same `enforced_model:` where the first dispatch carried one), **the same `repo:` this CVE's first dispatch carried**, the same `baseline_block`, the same `command_hint:` where one was recorded, and the original research report re-supplied from `research_file`. **`repo:` and `command_hint:` are not optional on a resume**: this is the call that reaches the verify step, which takes its `Project root:` from `repo:` — so a resume that omits it leaves verify rooted wherever the shell happens to be — and must run the command the capture ran. If the resumed agent returns `status: BLOCKED`, the re-supplied file path could not be read: report the named path to the user and stop this CVE. Do NOT retry, and do NOT reconstruct the artifact — a resume that re-derives its own input is the failure `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/context-management.md`'s read-failure contract exists to prevent.

5. **If the fixer returns `status: TEST_REGRESSION`** (from step 4's resumed verify), follow
   "Handling Test Failures" below, then re-invoke `vuln-fixer` with `phase: regression-resume` (and the same `enforced_model:` where the first dispatch carried one) +
   the chosen `regression_decision`, the same `repo:`, the same `baseline_block`, the same `command_hint:` where one was recorded, and the original research report
   re-supplied from `research_file`. If the resumed agent returns `status: BLOCKED`, the re-supplied file path could not be read: report the named path to the user and stop this CVE. Do NOT retry, and do NOT reconstruct the artifact — a resume that re-derives its own input is the failure `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/context-management.md`'s read-failure contract exists to prevent.

### Step 3.9 — Code-repo handoff (both paths, once per CVE)

`vuln-fixer` creates the fix branch **before** its first edit and leaves the change on it, uncommitted; the commit, the push, and the pull request are the orchestrator's, because the consent choice they sit behind is one only the orchestrator can ask (sub-agents dispatched via the `task` tool run in a separate context and have no interactive tools). The branch-first ordering is what makes this step reachable on the paths where the fixer never runs to completion — an `AWAITING_REVIEW` return whose review then stops the CVE still has a branch to commit onto.

Runs after the fixer's last return for this CVE — after the `verify-resume` call on the SIGNIFICANT / HIGH-RISK path, after the `regression-resume` call where one happened. Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` and execute the full `finish-code-branch` entry point (§2) inline, with the §2.11 inputs:

- `repo` and `branch` — the repo, and the branch name Step 1 resolved and the fixer created.
- `pre_existing_dirty` — as recorded at the top of Step 3; `stash_ref: null`.
- `commit_template` — the "Commit message" template in this skill's Git Workflow section below. `vuln:` is the one caller with a template of its own, so §2.3 uses it verbatim rather than deriving a subject from the repo's log.
- `title` — `fix(deps): <library> upgrade to remediate <CVE-ID>`, with ` [<JIRA-ID>]` appended when the CVE has one.
- `body_facts` — the CVE summary, the vulnerable range, the version change applied, the classification, the review-tier review verdict and triage where the CVE went through review, and the test counts before and after.
- `clean_finish` — `false` when the CVE ended `BLOCKED` or `TESTS_NOT_RUN`, when its review is still `BLOCK`, when the user chose `keep-anyway` on a regression, or when any `notes` this CVE's fixer returned carries a line prefixed `NEW-FAILURE: `; `true` otherwise. **That last condition is not a status test and cannot be made one**: a New failure moves no `test-baseliner` `Status`, so the CVE reaches here as `SUCCESS` with a red suite behind it (`dev-workflows:test-baseliner` verify step 6, and `vuln-fixer` step 5, which marks each one in `notes` for exactly this read). **Test the prefix, not the prose** — `notes` is free text also carrying auto-fix descriptions, uncovered-suite names and a regression diagnosis, and the mark is what makes this decidable, exactly as `CAVEAT: ` is. **Read every return this CVE made, not only its last**: on a `regression-resume` the resumed call runs no verify (`vuln-fixer`'s Phase resume note), so a New failure met at the first verify is absent from the return that ends the CVE. It is the mildest of the five — nothing says the fix caused it — and it still withholds an ordinary mergeable pull request, because what the flag asks is whether this diff is safe to merge unexamined and a failing suite answers no. Per §2.9 the flag never suppresses either half: the commit is prompt-free and the push is still **offered** under §2.4's choice, and what the flag itself changes is only the pull request (draft, DO-NOT-MERGE banner). What it can change is whether that choice is put again — the paragraph below, which is where this command differs from `implement:`.

§2.4's choice is asked on the **first** CVE and reused for every later one (`code_handoff_choice`) — a ten-CVE run asks once, not ten times — **save on §2.4's re-ask triggers, and this is the caller its first one was written for.** A CVE whose `clean_finish` differs from the one the recorded answer was given under puts that choice again, naming the trigger, **and it fires in both directions**: a CVE ending `false` under an answer given at `true`, because the user authorised pushing reviewed work and not blocked work; and a clean CVE under an answer given at `false`, because otherwise a decline given on one blocked CVE governs every good fix behind it and withholds them all without saying so. *"Neither — the commit stays on this machine"* is a real answer in either case rather than an anomaly: where it is given the push does **not** happen — the commit still does, prompt-free — and where the re-asked choice is answered the other way, this CVE is pushed under its own answer rather than under the earlier one. (§2.4's second trigger, a change of `repo`, cannot fire here: `vuln:` works one repository for the whole run.) Emit the §3.1 `Code repo:` line per CVE and carry its pull-request number into the Step 4 table's `PR` column.

**What to hand off is decided by the tree, never by the status label.** Before skipping any CVE, run `git -C "<repo>" status --porcelain -z --untracked-files=all` and compare it against `pre_existing_dirty` (captured the same way, so the comparison is between two raw, NUL-terminated path sets rather than a raw set against a quoted one):

- **Anything of this run's is present** ⇒ run Step 3.9. It does not matter which status the CVE carries.
- **Nothing of this run's is present** ⇒ skip, and say why in the Step 4 table.

This is deliberately not keyed on `status`, because **`BLOCKED` means two opposite things**. It is returned by the *first* fixer call when the research report cannot be read — nothing was created, nothing changed — and by a **resume** call (Step 3's SIMPLE/MODERATE path and steps 4 and 5 of the SIGNIFICANT path) when the re-supplied path cannot be read, at which point the branch exists and the fix is already applied to it. It is also the label this command writes into the Step 4 table for four orchestrator-side gate stops, two of which (`NEEDS HUMAN`, a persisting review `BLOCK`) are explicitly required below to hand off. A skip list keyed on the label would strand an applied fix on a branch, and the next CVE's `git switch` would then either abort or carry it onto an unrelated branch.

For orientation, the states that normally reach each outcome: a first-call `BLOCKED` changed nothing; `SKIPPED_BY_USER` never invoked the fixer; `BUILD_FAILED` and `REVERTED` reverted their own change and normally leave the step-2 branch in place and empty — the plugin never deletes a branch (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §1 rule 3), so name the stray ref in the Step 4 table rather than leaving it unexplained. Each of these is still confirmed against the tree, not assumed.

**Never skipped for a CVE that failed a gate.** A CVE stopped at an unresolved review `BLOCK` or at `NEEDS HUMAN` **is** handed off with `clean_finish: false`: its fix is applied and sitting on a branch that exists precisely because the fixer created it before the first edit, and §2.8 is exactly the case for it.

---

## Step 4 — Summarise

After all CVEs are processed, remove each CVE's now-unread temp files — `command rm -f -- "<research_file>" "<review_diff_file>" "<claims_file>"` per CVE, skipping any path a `BLOCKED` disposition above still cites in its own report. Then print a result table:

```
| CVE            | Library         | Change         | Class        | Result  | PR  | Notes                                      |
|----------------|-----------------|----------------|--------------|---------|-----|--------------------------------------------|
| CVE-2023-46604 | activemq-broker | 5.15.5→5.15.16 | MODERATE     | OK      | #42 | not verified: RSpec (`bin/rspec`)          |
| CVE-2024-99999 | (not in repo)   | —              | —            | SKIP    | —   |                                            |
```

**The `Result` vocabulary is fixed here, not inferred from the example rows above.** It is
exactly `OK`, `TESTS_NOT_RUN`, `SKIP`, `BLOCKED`, `BUILD_FAILED`, `REVERTED`,
`REGRESSION_KEPT`. **`OK` means the comparison happened and found no regression, and nothing
else earns it** — a fix whose post-fix verify could not run is **`TESTS_NOT_RUN`**, never `OK`
with the qualification pushed into a note. Filling the cell by pattern-matching the examples is
how a fix nobody verified gets reported as verified: they show only `OK` and `SKIP`, and `OK` is
the nearer of the two for a fix that applied cleanly and built.

**The `Notes` column is where a suite this run did not verify is named, and it is filled on both paths from the same two sources.** A CVE can otherwise be reported `OK` with a whole stack unverified, which is exactly what this column exists to prevent. The sources differ in scope rather than by path, which is what the run-level capture made true of both:

- **The run's own baseline** (Step 3's capture) — every suite its `### Suites` does not mark `OK` or `NO_TESTS`, with the command that failed. It is captured once, so whatever it could not cover is uncovered for **every** CVE in the run and goes in every row's cell, not just the first.
- **That CVE's own `vuln-fixer` `notes`** — read on **every** return and not only on a stop, because a verify `PARTIAL` comes back as `status: SUCCESS` with its suites named there (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/handoff/vuln-fixer.md`'s own `SUCCESS` gloss). This is the only source for a suite the baseline **did** cover and this CVE's verify could not run — a suite can stop being runnable between the two calls, and the baseline cannot know that.

Name each suite and its command, or leave the cell empty where the run verified everything it detected — never a bare "partial", which says a stack was missed without saying which. **Every `CAVEAT: ` line either source carried goes in this cell too, verbatim and whatever the status was.** That mark is the baseliner's own on a note whose harm the `Status`, the counts and the test lists do not show, so it is carried without being judged here, and it is what puts a CVE green at both ends into this cell at all — every other source named above needs a suite the run could not cover. An unmarked note records where a command ran and is not carried. **Every `NEW-FAILURE: ` line the fixer marked goes in this cell as well**, named test by test and taken from every return this CVE made rather than only its last: it is the one entry here that is not about coverage — the suite ran and something in it is red — and it is also the one that moved this CVE's `clean_finish` to `false`. **Where the run's own capture and the fixer's `notes` name the same uncovered suite, write it once**: on a `PARTIAL` baseline both sources carry it by design, the capture because it is the run's and the fixer because its own step 1 read the same block, and this cell is a report rather than a tally.

**Where the run recorded `baseline_unverified`, state it once above the table** — the capture failure that produced it, whether it was the operator's own answer or the run's own record after two failed `command_hint` attempts, and that every CVE below therefore finished unverified. That line is the flag's only reader and its whole purpose: `clean_finish` reaches `false` through `TESTS_NOT_RUN` without consulting it, so without this the run would have recorded a decision nothing ever surfaces, and the table would show a column of `TESTS_NOT_RUN` with no statement of why.

Append a `### Model Routing` section summarising the per-CVE classification, why it was chosen, the models used, and any review-tier review verdicts.

Append a `### Review triage` section with one line per CVE that went through review-tier review: - **Review triage:** [N findings reviewed, M survived] — dismissals: [one line per dismissal, `finding — reason`; or "none"] — or "N/A (SIMPLE / MODERATE path, no review-tier review)" for CVEs that never reached review.

Then invoke `impl-maintenance` with a compact session handoff covering the CVEs fixed, notable regressions, workarounds, and overall outcome. **Always pass `Command run: vuln:`** in that handoff — omitting it makes `impl-maintenance` default to `implement:`, mislabeling the run.

**Under `--skip-feedback`** (`run_flags.skip_feedback`, `_shared/run-flags.md` §4), this step dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance` — the same compact handoff, plus `Plugin root:` — on `run_flags.enforced_model` when set, else the `_shared/model-routing.md` §2.2 cheap chain. Only when it returns at least one defect, persist them through `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, `feedback-emission.md` is not read at all. Report `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`. The in-session Lessons Learned report is what the flag costs. `emit-block` is unaffected and fires exactly as it would without the flag.

**Context hygiene.** This was a large run — consider **`/compact`** to free context before your next task (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §3 — non-pipeline, so `/compact` only; guidance only).

**Then persist plugin feedback (automatic).** After `impl-maintenance` returns, project its plugin-facing slice into the specs repo by citing `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and calling its `emit-auto` entry point (§6). Pass the Lessons Learned report, `command: vuln:`, the run's `jira_key` (or `null`) and `source`, and `plugin_version` (read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). `emit-auto` renders only the report's **Command workflow improvements**, **New agents / skills**, and plugin **Reference docs** sections plus the **Key observations** that triggered them (§4 plugin-facing predicate) — never target-project `copilot-instructions.md`/hook advice — as `origin: auto` entries, dedupes by stable `id` (§3), resolves the target via the §2 specs-first ladder, and writes silently. List the persisted path (or "no plugin-facing signal — nothing persisted") after the lessons-learned report. ADDITIVE — the impl-maintenance report still appears in the output; this step NEVER fails the run, NEVER commits (still true — the assertion is scoped to *this step*, which only writes the feedback file; those writes are committed by the separate terminal `commit-artifacts` step, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §4), and NEVER writes into the code repo or the current working directory.

**Then commit session artifacts (terminal).** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` and execute its `commit-artifacts` entry point (§4) inline — the LAST action of the run. It stages ONLY the §2.1 bounded artifact paths inside `$SPECS_PATH`, commits `<KEY> Add dev-workflows session artifacts (vuln:)` — or `NOISSUE …` when the run resolved no Jira key — and pushes per §4 step 5. It NEVER touches the code repo this run just fixed: that repo's branches and commits, and whatever push and pull request §2.4's consent choice allowed, were Step 3.9's, through a different reference and against a different remote. It NEVER force-pushes, NEVER fails the run, and skips entirely when the run carries `specs_git: blocked` (§3.3 G0) or `specs_git: misrooted` (§3.1, or §8's `specs-root-check` stop), re-emitting that notice. Print its §6 outcome line after the feedback path, prefixed `Specs repo:`, with any guard notice repeated in full. No `resume.md` is written for `vuln:` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §1 skip list — the durable state is the branch and PR).

---

## Handling Test Failures

`vuln-fixer` cannot prompt the user directly — sub-agents dispatched via the `task` tool run
in a separate context and have no access to interactive tools, even when one is listed in their
`tools:`. When it returns `status: TEST_REGRESSION` (previously-green tests now failing, not
auto-fixable), the **orchestrator** (this skill, running in the interactive session) handles the
decision:

- Present the failing tests clearly (from the fixer's `failing_tests` / `diagnosis`).
- Ask via `ask_user` — no option is safe to recommend across arbitrary regressions, so this list carries no `(Recommended)` marker and the qualifying condition sits in the option's own description (per the marker rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md`):
  ```
  choices: ["Apply the fix anyway and flag the failures in the PR — for flaky tests", "Revert this fix and skip it", "Investigate further"]
  ```
- **"Investigate further"** → show more detail (the diff, full failure output) and re-ask
  the same choices — this loops here at the orchestrator until the user picks apply or revert.
- Map the final choice to `regression_decision: keep-anyway | revert` and re-invoke
  `vuln-fixer` with `phase: regression-resume` (see Step 3).

**`status: TESTS_NOT_RUN` is a different return and takes no `regression_decision`.** It means the
verify call compared nothing — no failing tests to show, and nothing about this CVE's tests known either
way. The fix stays on its branch. Report the reason the fixer recorded, mark the CVE unverified in the
Step 4 table, and hand it off through Step 3.9 with `clean_finish: false`. Never map it onto `revert`:
rolling a security fix back because a suite could not be started is a decision taken on no evidence at all.

---

## Git Workflow

### Branch naming

Resolve the branch name per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md` — **the repo's own documented convention wins**. The orchestrator reads the repo's `CONTRIBUTING.md`, `CONTRIBUTION.md`, `README.md`, `DOCUMENTATION-GUIDELINES.md`, `.github/copilot-instructions.md` (+ `.github/`) for a branch-naming section (§1.1), fills its segments (§1.2) — **identity** from the §2 ladder (`$GIT_USER_INITIALS` → `git config user.initials` → inference → the §2.5 prompt), **issue key** from the CVE's Jira ID when present (else the documented no-issue literal, or the `NOJIRA` placeholder detected in Step 1), **description** from the CVE ID — and hands the resolved name to `vuln-fixer`. Never add an identity segment the pattern does not ask for.

When the repo documents no convention (§1.4), `<prefix>` comes from the §2 ladder with fallback `fix/`:

- With Jira ID: `<prefix>/JIRA-ID-CVE-XXXX-XXXXX`
- Without Jira ID: `<prefix>/NOJIRA-CVE-XXXX-XXXXX` (or `<prefix>/CVE-XXXX-XXXXX` if the project omits placeholders)

### Commit message

Use the project's existing style. Default template:

**With Jira ID:**
```
fix(deps): upgrade <library> to <version> to remediate <CVE-ID>

Resolves <JIRA-ID>
Fixes <CVE-ID> - <one-line CVE description>

Vulnerable range: <range>
Safe version: <version>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

**Without Jira ID:**
```
fix(deps): upgrade <library> to <version> to remediate <CVE-ID>

Fixes <CVE-ID> - <one-line CVE description>

Vulnerable range: <range>
Safe version: <version>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Commit, push, and PR

All three are Step 3.9's, through `finish-code-branch` (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` §2) — never `vuln-fixer`'s. The commit-message template above is passed as that step's `commit_template` and used verbatim (§2.3).

- Base branch: resolved per §2.8's ladder — `origin/HEAD`, then `origin/main`, `origin/master`, `origin/develop`. Never assumed.
- Title: `fix(deps): <library> upgrade to remediate <CVE-ID>` (append ` [<JIRA-ID>]` when present)
- Body: CVE summary, vulnerable range, version change made, classification, review verdict and triage where the CVE went through review, and test results (pass count before vs. after)
- Opened with `gh` behind §2.6's capability probe; on any failure the run falls back to §3.2's manual-open text rather than reporting a pull request that does not exist. A `clean_finish: false` CVE gets a draft plus the DO-NOT-MERGE banner (§2.9).

---

## Invariants (always enforced)

- ALWAYS `emit-block` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) before escalating a halt caused by a **plugin / skill / command / reference gap** (a capability the run needed but the plugin lacked) — so a run abandoned at the block still records it. NEVER for a work-quality review BLOCK or an environment / user halt (repo-missing, dirty-tree, jira-not-found, cancellation)
- ALWAYS classify **per CVE** after research
- NEVER use Opus for a `MODERATE` fix unless the user explicitly asks for it
- NEVER run tests for a `SIGNIFICANT` / `HIGH-RISK` CVE before the review-tier review returns a non-BLOCK verdict
- ALWAYS capture the test baseline once, at the orchestrator, before the first CVE — on both paths; `vuln-fixer` never captures one, and a capture that returns `RUN_FAILED` or `COMMAND_NOT_FOUND` is put to the operator before anything is branched or edited
- NEVER read a verify report as a pass while its `### New failures` list is non-empty — a New failure moves no `test-baseliner` `Status`, so `OK` and `PARTIAL` are both reachable with a red suite (`dev-workflows:test-baseliner` verify step 6). The list is read **beside** the `Status`, never instead of it: the `Status` arm's own return stands, the failures are named test by test in the Step 4 `Notes` cell, and the CVE finishes `clean_finish: false`
- ALWAYS pass the whole captured `baseline_block` — and the `command_hint` where one was recorded — to `vuln-fixer` on every dispatch, `phase: verify-resume` and `phase: regression-resume` included
- ALWAYS run Step 3.9 (`finish-code-branch`, per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md`) after a CVE's last fixer return — the commit is prompt-free (§1 rule 5), §2.4's choice is asked once and reused for every later CVE **except where one of §2.4's own two triggers re-asks it**, and a CVE whose fix is on disk is never left uncommitted
- NEVER let `vuln-fixer` commit, push, or open a pull request — it creates the branch and applies the fix; the orchestrator owns the handoff, because the consent choice behind it is one a sub-agent cannot ask
- NEVER push the **code repo** directly to `main` / `master` — always use the dedicated fix branch (`agents/vuln-fixer.md`), one per CVE, branched from the base and not from the previous CVE's branch (Step 3). This binds the code repo only: the specs-repo steps above push `$SPECS_PATH`'s bounded artifact paths to the specs repo's own branch (`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md` §3.4 / §4), and never force-push (§1 rule 4)
- ALWAYS run `specs-preflight` at Step 0 and `commit-artifacts` as the run's last action (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/specs-repo-git.md`) — bounded to `$SPECS_PATH`'s artifact paths (§2.1) and to plugin-created branches (§2.2), always `git -C "$SPECS_PATH"` and never a `cd` (§1 rule 1), never force-pushing, and never failing the run
- After the run, suggest **`/compact`** (a big non-pipeline run) per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` §3 — compact-only, no clear/resume pointer; guidance only, never auto-run.
