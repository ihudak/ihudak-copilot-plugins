# Run flags

Two flags change how a run behaves rather than what it produces: `--skip-feedback` and `--enforce-model=<model>`. Each has a persistent environment default — `$WORKFLOWS_SKIP_FEEDBACK`, `$WORKFLOWS_ENFORCE_MODEL` — described in [Environment](environment.md). **A flag beats its environment variable, which beats off**, so a one-off override needs no unsetting.

**There is no `--skip-costs` in this edition.** The Claude edition has a third flag that suppresses its per-run cost entry; this edition has no cost subsystem at all ([`skills/_shared/specs-repo-git.md`](references.md): "no `cost-emission.md`, no `emit-cost`, and no `dev-workflows-cost/` path shape"), so there is nothing for it to turn off. It is not parsed and not reported ignored — a `--skip-costs` token reaches a skill's own argument parse like any other unrecognized word.

A flag may sit anywhere in the argument list, with one exception covered below.

## Which skills each flag applies to

Not every flag applies to every skill, because not every skill does the thing the flag turns off. A flag given to a skill that has at least one applicable flag but not this one prints `Run flags: --<flag> does not apply to /<skill> — ignored` and changes nothing; a skill neither flag applies to does not parse run flags at all; an *environment* default outside its set is ignored silently, so exporting one never alters a skill it does not apply to.

| Flag | Applies to | Does not apply to |
|---|---|---|
| `--skip-feedback` | the 13 skills with an `impl-maintenance` maintenance phase | `docs-profile:` (dispatches none), `feedback:` and the three `prompt` skills (they *are* the feedback surface), the two guideline reviewers |
| `--enforce-model` | those 13 plus `docs-profile:` | `feedback:` and the three `prompt` skills (they dispatch no subagent), the two guideline reviewers |

## `--skip-feedback`

Narrows the end-of-run maintenance pass to bug capture. Instead of `impl-maintenance` and its Lessons Learned report, the run dispatches [`defect-reporter`](agents.md), which returns only real defects — each with a location, the session evidence, and a minimal repro — or none at all. A run with no defects persists nothing.

The run reports `Session feedback: bugs-only (--skip-feedback) — N defect(s) persisted`, or `— no defects`.

**What the flag costs you is the in-session Lessons Learned report**: `defect-reporter` returns defects only — never workflow advice, agent or skill suggestions, or notes about your own project's tooling. Capture-at-block is unaffected and still fires when a run halts on a gap — including, now, a halt over a tool the container image is meant to provide and lacks.

## `--enforce-model`

Pins every subagent the run dispatches to one model, bypassing model routing's own per-step selection — including the agents the caller otherwise always pins to the strong tier. The value is a family alias (`opus`, `sonnet`, `haiku`, `fable`), a versioned form (`opus5.5`), or **any full model id**.

**This edition routes across vendors**, which matters here: `gpt-6-astra` and `gemini-3.1-pro-preview` belong to no `claude-<family>` family, so they are reachable only as full ids and have no alias. Note also that ids in this edition use **dots**, not dashes — `claude-opus-5.5`, not `claude-opus-5-5` — matching what the CLI's `model:` parameter accepts.

**It never moves the orchestrator itself.** A skill cannot switch the model it is running under from inside a run, so enforcement pins the subagents and leaves the session model alone. When the two differ the run says so once. For the same reason, every gate that requires a strong-tier *session* stops firing under enforcement: the inline grill and authoring those gates protect still run on your session model, so pointing them at the enforced model instead would let a weak session pass a strong gate.

Classification is unchanged. A `SIGNIFICANT` task still gets its plan and review gates and a `SIMPLE` one still skips them — enforcement decides which model each selected step runs on, never whether the step runs.

A value that resolves to nothing, or to a model your environment cannot reach, stops the run in Phase 0 — before any write — and emits no feedback entry, because a bad model name in your own invocation is not a gap in the plugin.

## The one placement exception

Three of the skills a run flag applies to take **prose** as an argument — `implement:`, `idea:`, and `document:` in direct mode. (`feedback:` and the three `prompt` skills take prose too, but no run flag applies to them, so nothing is ever stripped from theirs.) Inside that prose, a flag name is just a word, so run flags are stripped only from the *leading* and *trailing* runs of flag tokens and everything between is kept verbatim.

The cost is real and worth knowing: **prose that genuinely ends in a flag name loses it**, and where that flag is `--enforce-model`, the word before it goes too, consumed as its value. Because the trailing run is the longest parsing suffix, this can reach further back than the last word or two. Keep a flag name away from the end of your prose, and you will not meet this.
