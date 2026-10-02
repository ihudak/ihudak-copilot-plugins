# Run Flags — Shared Reference

Single source of truth for the run flags every applicable skill accepts, their environment defaults, the model aliases, and the `run_flags` record. Skills execute `strip-run-flags` in Phase 0.

**This edition ships two of the three flags.** `--skip-feedback` and `--enforce-model=<model>` are here; **`--skip-costs` is not a flag of this edition at all** — there is no cost subsystem to skip (`specs-repo-git.md`: "no `cost-emission.md`, no `emit-cost`, and no `dev-workflows-cost/` path shape"). It is not parsed, not reported ignored, and carries no environment default: a `--skip-costs` token reaches a skill's own argument parse like any other unrecognized token. Do not add it here without adding the subsystem it would turn off.

## 1. The flags

| Flag | Env default | Values |
|---|---|---|
| `--skip-feedback` | `$WORKFLOWS_SKIP_FEEDBACK` | bare = `true`; `--skip-feedback=true\|false` |
| `--enforce-model=<m>` | `$WORKFLOWS_ENFORCE_MODEL` | alias, full model id, or `routing` |

**Precedence: flag > env > off.** A flag given on the command line always wins over the corresponding environment variable, and an unset flag with an unset environment variable resolves to off (`skip_feedback: false`, `enforced_model: null`).

**Boolean grammar for `--skip-feedback`, stated explicitly because nothing elsewhere in this plugin parses a flag this way:** the bare form (no `=`) resolves to `true`; `--skip-feedback=false` resolves to `false`, with `false` matched case-insensitively; any other `=value` (`=1`, `=yes`, `=anything-else`) resolves to `true`.

**Env boolean** (`$WORKFLOWS_SKIP_FEEDBACK`): `1`, `true` or `yes`, matched case-insensitively, resolve to on; every other value, and an unset variable, resolves to off.

**A set-but-empty environment variable is unset.** `WORKFLOWS_ENFORCE_MODEL=""` is treated exactly as if the variable were not set — source `default`, no enforcement, never a missing-value `RUN_FLAGS_BAD_MODEL`.

**`--enforce-model` takes two equivalent forms:** `--enforce-model=<value>`, and the two-token pair `--enforce-model <value>`. **The pair form always consumes the very next token as its value, whatever that token looks like** — so `/implement --enforce-model PRODUCT-12` treats `PRODUCT-12` as the requested model, never as a positional argument, and the run stops `RUN_FLAGS_BAD_MODEL` once it fails every form in §2. A bare trailing `--enforce-model` with no token after it, and `--enforce-model=` with nothing after the `=`, are both a missing value; each stops `RUN_FLAGS_BAD_MODEL` — but only once §3's applicability step has confirmed the flag applies to the running skill. `--enforce-model=routing`, `$WORKFLOWS_ENFORCE_MODEL=routing`, and an unset flag with an unset variable all resolve to no enforcement; `routing` is matched case-insensitively.

**Flags may appear anywhere in the argument list** — except inside the prose of a free-text skill (§3 step 1).

## 2. Model values

**This edition routes across vendors** (`model-routing.md` §2 is Anthropic-first for work and §2.3 OpenAI-first for review, with Gemini at §2's floor), which is why the alias table below is not simply a family map: `gpt-6-astra` and `gemini-3.1-pro-preview` belong to no `claude-<family>` family and are reachable only as full ids.

| Value form | Resolves to |
|---|---|
| `opus` | the highest reachable Opus row of `model-routing.md` §2 |
| `sonnet` | the highest reachable Sonnet row of `model-routing.md` §2.1 |
| `haiku` | the highest reachable of the Haiku rows below |
| `fable` | the reachable `claude-fable-…` id highest by version number — no chain names one |
| `<family><major>` / `<family><major>.<minor>` | `claude-<family>-<major>` / `claude-<family>-<major>.<minor>` |
| any full model id | itself, unchanged — `claude-opus-5.5`, `gpt-6-astra`, `gemini-3.1-pro-preview` |

`family` ∈ `opus | sonnet | haiku | fable`. The alias rows are matched case-insensitively; a full id is taken as written. **Note this edition's id form uses dots, not dashes** (`claude-opus-5.5`, not `claude-opus-5-5`) — matching what the CLI's `model:` parameter accepts. Anything matching none of the rows above stops the run with `RUN_FLAGS_BAD_MODEL`, naming the rejected value verbatim (or `(missing)`) together with its source — `(from --enforce-model)` or `(from WORKFLOWS_ENFORCE_MODEL)` — and listing the accepted forms. **Where the rejected value is itself a run-flag token the pair form consumed**, the message also says so: `--enforce-model took '<token>' as its value; write --enforce-model=<model>, or put <token> before it`.

**The Haiku rows**, newest first — what the `haiku` value resolves against, and what Reachability below reads for a Haiku value. No `model-routing.md` chain names Haiku, since no chain selects it (`defect-reporter` runs on `model-routing.md` §2.1), so these rows serve an enforced Haiku value only, and wherever this file speaks of a family's chain or its newest chain row, these rows are Haiku's:

1. `claude-haiku-4.5`

**Reachability** is read the way `model-routing.md` §2 already reads it — from the `task` tool's `model` parameter documentation, never assumed — and what it can prove depends on what that parameter enumerates.

- **Where the parameter accepts model ids** — which is what this edition's CLI does today — a resolved id that is not reachable stops the run with `RUN_FLAGS_MODEL_UNAVAILABLE`, naming the resolved id with its source tag and the reachable peers. A bare `fable` against a parameter listing no `claude-fable-…` id stops the same way.
- **Where a parameter enumerates only family names** (`opus`, `sonnet`, `haiku`, `fable` — a **family-only harness**, which this edition's CLI is *not*, but a future one could be), no id is ever listed, so reachability is decided per family and the harness picks the version: a bare family alias is reachable iff its family is listed and is recorded as the family; a version-specific form is honoured only when its resolved id is its family's newest chain row (for Haiku, the first of the Haiku rows above), and is then passed as the family name; any other version-specific form — an older row, an id on no chain, or a Fable id, since `fable` has no chain — stops `RUN_FLAGS_MODEL_UNAVAILABLE` saying `this harness selects models by family only; use --enforce-model=<family>`. **A non-Claude peer (`gpt-*`, `gemini-*`) has no family at all**, so on such a harness it is unreachable by construction, and the message lists the families the parameter enumerates instead.

**Every validation in this section applies only to an `--enforce-model` that §3's applicability step has already found applicable.** An inapplicable one is never parsed, never reachability-checked and never stopped on.

**Both stops happen in Phase 0, before `specs-preflight` and before any write, and emit no feedback entry** — a bad model name is a defect in the user's own invocation, not a gap in the plugin.

## 3. `strip-run-flags` entry point

1. **Strip the tokens, capturing whatever raw value each carries without judging it yet.** Remove every token matching `^--skip-feedback(=.*)?$`. For `--enforce-model`, remove either a token matching `^--enforce-model=(.*)$` (the captured group is the raw value, possibly empty) or the bare token together with the single token immediately following it, consumed as a pair regardless of what it looks like — and where a bare trailing `--enforce-model` has no token after it, remove just that one token, carrying no value forward. Nothing is judged yet; that is step 4's job, and only for a flag step 3 found applicable.

   **Free-text skills strip run flags only outside the prose span.** A **free-text skill** is one whose own body says (part of) its argument is prose kept verbatim rather than parsed into further positional arguments — tested against the *running skill's own body*, already in the executing agent's context, never by grep. Today's members among the skills that run this entry point are `/implement`, `/idea`, and `/document` (direct mode only) — the four feedback-surface skills also take prose, but no run flag applies to them, so they never strip. Stated as today's members, never as the definition.

   For a free-text skill, the **prose span** begins at the first token the skill's own parse does not recognize as a run flag (with its value), one of its own flags (with its value), its key/address, or — for `/implement` only — an `@path` token. For `/implement`, the test runs from the very start of the argument string. For `/idea`, the leading region runs up to and including the key. For `/document`, the test decides which mode's rules apply: after the leading run of run-flag tokens, the next token is tested against the VI key grammar — a hit means the keyed mode, which is not free-text at all and takes an ordinary strip; a miss puts the run on the free-text rule.

   Separately, the **trailing run** is the longest suffix that parses left to right as complete tokens of the running skill's own recognized grammar — its own flags and run flags alike, plus an `@path` token for `/implement`. The pair form consumes its next token as one unit.

   Strip only the **run-flag** tokens found before the prose span begins, or inside the trailing run; the skill's own flags in either place are left for its own parse. Every token inside the prose span that is not part of the trailing run is prose, kept verbatim even where it is a flag name.

   **The cost, stated plainly:** prose that genuinely ends in a flag name loses it to the trailing-run strip — and where that flag is `--enforce-model`, the word before it is lost too, consumed as its value before either is judged. Because the trailing run is the *longest* parsing suffix, this can reach further back than the prose's last word or two. There is no placement that fully avoids it; keeping a flag name away from the prose's end avoids the cases above.
2. **Determine each flag's raw source, resolving nothing yet.** `flag` when step 1 found an explicit token; else `env` when the corresponding variable is set to a non-empty value; else `default`.
3. **Applicability — resolved before anything is validated.** Test each flag against the *running skill's own body*, already in the executing agent's context, never by shelling out: a `grep -l … dev-workflows/skills/*/SKILL.md` does not resolve at runtime, since the agent's cwd is the user's project and the installed tree lives under `~/.copilot/installed-plugins/`. The runtime test: `--skip-feedback` applies iff the running skill's own body cites `impl-maintenance`; `--enforce-model` applies iff it cites the file `_shared/model-routing.md` — the file, never the bare word `model-routing`, which is also a feedback *category* and appears in `/feedback`'s body without that skill routing anything. A maintainer re-deriving the sets from outside a live run uses the greps instead, kept here as **that recipe and nothing more**: `grep -l 'impl-maintenance' dev-workflows/skills/*/SKILL.md` (13) and `grep -l '_shared/model-routing\.md' dev-workflows/skills/*/SKILL.md` (14).

   **In this edition the two sets are, today:** `--skip-feedback` — `/idea`, `/create-vi`, `/update-vi`, `/create-ard`, `/specify`, `/design`, `/implement`, `/ready`, `/epics`, `/document`, `/release-notes`, `/upgrade`, `/vuln` (13). `--enforce-model` — those 13 plus `/docs-profile` (14). `/feedback`, `/prompt`, `/prompt-brainstorm` and `/prompt-grill-me` dispatch no subagent and have no maintenance phase, so **neither flag applies to them and none of them runs `strip-run-flags` at all** — their argument reaches their own parse untouched, and an exported default changes nothing. A census for a reader, not the test.

   A flag given **explicitly** to a skill whose own body fails its test prints `Run flags: --<flag> does not apply to /<skill> — ignored` and resolves to that flag's default for this run, **unvalidated** — step 4 never looks at its raw value, so a malformed or unreachable one on an inapplicable skill stops nothing. An env default whose flag fails its test is silently treated as unset, so an environment default never stops, warns on or alters a skill it does not apply to.
4. **Resolve every flag step 3 found applicable, and only those.** `skip_feedback` resolves per §1. `enforce_model` resolves per §2: a missing, empty or unmatched value stops `RUN_FLAGS_BAD_MODEL`; a resolved-but-unreachable one stops `RUN_FLAGS_MODEL_UNAVAILABLE`.
5. **Build the record:**
   ```yaml
   run_flags:
     skip_feedback: <bool>
     enforced_model: <id|family>|null
     requested: <raw --enforce-model value as written>|null
     source:
       skip_feedback: flag|env|default
       enforce_model: flag|env|default
   ```
   For a flag step 3 found inapplicable, its `source` is always `default`.
6. **Report when non-default.** Print one line: `Run flags: skip-feedback=<on|off>(<source>) enforce-model=<id|routing>(<source>)`. When both are default, print nothing.
7. **Report an orchestrator/session-model mismatch.** When `enforced_model` is set and differs from the model the orchestrator is itself running under, print `Run flags: orchestrator runs on <session-model>; relaunch after selecting <model> to enforce it there too`, and continue unchanged.

Return `run_flags` and the stripped argument string — every later parsing step reads only what this entry point leaves behind.

## 4. Skip-feedback

Under `run_flags.skip_feedback`, the skill's maintenance phase dispatches `dev-workflows:defect-reporter` in place of `impl-maintenance`, with the same compact session handoff, plus `Plugin root:`, on `model: run_flags.enforced_model` when set, else the `model-routing.md` §2.1 detection chain, the tier `impl-maintenance` runs on. When `defect-reporter` returns at least one defect, persist them with `feedback-emission.md`'s `emit-bugs` entry point in place of `emit-auto`; when it returns none, load `feedback-emission.md` not at all. `emit-block` is unaffected. **What the user loses under this flag: the in-session Lessons Learned report** — `defect-reporter` returns defects only, never workflow advice, agent/skill suggestions, or target-project tooling notes.

## 5. Reporting

Three report lines, each printed only where the step that produces it fires:

- `Run flags: …` — §3 step 6 (non-default flags) and/or §3 step 7 (orchestrator/session-model mismatch).
- `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted` or `— no defects` — the maintenance phase, under `run_flags.skip_feedback` (§4).
- `Model routing: bypassed — enforced <id> (flag|env)` — wherever a skill's final report would otherwise state its model-routing degradation. `<id>` is what the dispatches were actually passed, followed — where that differs from `run_flags.requested` — by a parenthesis saying so: `enforced claude-opus-5.5 (from opus) (flag)`.

**There is no `Session cost:` line in this edition**, because there is no cost phase to report on.

**The final report repeats the `Run flags:` line** whenever §3 printed one during the run.
