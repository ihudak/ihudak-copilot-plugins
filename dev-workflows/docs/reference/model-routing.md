# Model routing reference

Every pipeline skill classifies its own task before doing real work, and that classification decides how much planning, authoring, and review rigor the rest of the run applies — and, for two skills, which model the session itself must be running on. This page covers the four things a user can observe or influence about that; the full policy — including the mechanics agents don't need restated here — lives in `model-routing.md` under `skills/_shared/` and is linked at the end.

## What gets classified

| Class | Plain meaning |
|---|---|
| `SIMPLE` | Trivial, mechanical, low blast radius — a typo, a comment, a single-line tweak. |
| `MODERATE` | A localized feature or fix in 1–3 files, well-understood, no security implications. |
| `SIGNIFICANT` | Multi-file or cross-cutting, non-trivial design, real correctness risk. |
| `HIGH-RISK` | Security-, data-, or contract-sensitive — a mistake here causes an outage or a breach. |

All fourteen pipeline skills that load this policy run this classification as an early step and state their class plus a one-line reason: `implement:`, `document:`, `epics:`, `release-notes:`, `vuln:`, `upgrade:`, `docs-profile:`, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, and `ready:`. Each skill has a typical class for its own kind of work (a Value Increment authoring run is typically `MODERATE`, Jira-driven feature docs are typically `SIGNIFICANT`) but escalates when the task in front of it warrants it. What over-escalating costs differs by skill — from an extra strong-tier planner call to a hard stop requiring a strong-tier session (`## What classification changes` below has the breakdown) — while misclassifying downward can ship bugs regardless of which skill you're running, so the policy's own rule is to escalate one level whenever in doubt. One rubric carve-out belongs here too: a CVE's category (RCE, deserialization, auth bypass, …) never by itself forces `SIGNIFICANT`/`HIGH-RISK` — most CVEs patch with no source-code change and stay `MODERATE`; only `vuln:` performs the finer per-CVE fix-size analysis that can escalate one.

## What classification changes

`SIMPLE` and `MODERATE` continue on whatever model the session is already running, with nothing extra added on their account.

`SIGNIFICANT` and `HIGH-RISK` change different things depending on which skill you're running, because three distinct patterns share this classification:

- **`implement:` and `upgrade:`** delegate planning (or a planning critique) to a dedicated strong-tier sub-agent (`risk-planner`) before implementation starts, then add a separate strong-tier `code-review` gate afterward, before tests run; at `SIMPLE`/`MODERATE` neither one is dispatched at all.
- **The reviewer-gated authoring and documentation skills** — `create-vi:`, `create-ard:`, `specify:`, `design:`, `document:`, `epics:`, and `ready:` among them — already run their own reviewer agent on the strong tier by convention, regardless of classification — with one exception: `document:`'s direct mode runs no reviewer at all, and is deliberately gated by a style check alone. Apart from `document:`, which dispatches the delegated planner `doc-planner`, there is no separate delegated planner sub-agent in this pattern. What classification changes here is grill depth and authoring rigor, not whether the review runs on the strong tier — **none of these reviewer agents carries a `model:` frontmatter pin in this edition; the caller pins the tier at the `task()` call site** — [Agents reference](agents.md) carries the complete list of which agents the caller always pins to the strong tier, and which skills dispatch them.
- **`vuln:`** is a third: it runs the same strong-tier `code-review` gate, triage, and `review-fixer` cycle at `SIGNIFICANT`/`HIGH-RISK`, but dispatches no `risk-planner` and has no caller-pinned authoring reviewer of its own.
- **`design:` and `create-ard:` add a further, stricter gate:** at `SIGNIFICANT`/`HIGH-RISK` neither will author against a weaker model — both require the session itself to already be running on an Opus model (`current_model` is Opus-tier) — the work tier, since inline authoring is work, because their authoring happens inline rather than through a delegated sub-agent; environment reachability (`opus_available`) is a separate condition and never what the gate tests. If `current_model` isn't Opus-tier, the run stops; when an Opus model is also reachable (`opus_available: true`) it offers to relaunch on one, and when none is reachable that option is dropped — either way there's an explicit override to proceed anyway that gets logged in the final report. `specify:` and `create-vi:` don't gate this way on the same classification — they degrade to the best available model and record the degradation instead of stopping.

## What floors a classification

`implement:` has one classification floor beyond the ordinary triggers: **multi-source input**. Handing it more than one code repository, or any directory input (an exported Jira ticket folder, or a spec/design folder), floors the run at `SIGNIFICANT` even if nothing else about the change looks that size — a large multi-source brief is cross-cutting by nature, and it also triggers a parallel per-repo scan fan-out documented in the full policy below. The floor is overridable at plan approval if you judge the work genuinely smaller than its input footprint suggests.

## Anthropic does the work, top OpenAI models review it

This is the sharpest edition difference from the Claude version of this page. Instead of one peer set for all reasoning-heavy steps, there are **two tiers split by role**.

**The work tier** runs everything that *produces* — planning and planning critique, synthesis, delegated authoring, implementation, fixes — and is Anthropic-first:

1. `claude-opus-5.5`
2. `claude-opus-5`
3. `claude-opus-4.8`
4. `claude-opus-4.7`
5. `claude-opus-4.6`
6. `claude-opus-4.5`

**The review tier** runs the gates that *judge* — `code-review`, `doc-reviewer`, and the VI, ARD, spec, design, Epic and readiness reviewers — and is OpenAI-first:

1. `gpt-6-astra`
2. `gpt-6.1-sol`
3. `gpt-6-sol`
4. the whole work tier above

Two different models looking at one artifact catch more than one model looking twice, and a reviewer with no stake in the authoring is the point of a gate. A session with no version-6 model reachable reviews on Anthropic exactly as it did before, and that is **not** reported as a degradation — it is row 4, a documented branch of the policy.

**A review never prefers the session model.** The work tier does prefer whichever of its rows the orchestrator is already running under, as an economy — it avoids paying to switch when the session already qualifies. The review tier deliberately does not: a GPT-6 session and an Opus session both review on `gpt-6-astra`, because the whole purpose of the tier is that the reviewer is not the author.

**Further fallbacks for the work tier** (only if no Opus is available — announced as a degradation):

7. `claude-sonnet-5.5`
8. `claude-sonnet-5`
9. `claude-sonnet-4.6`
10. `claude-sonnet-4.5`
11. `gemini-3.1-pro-preview`

`gemini-3.1-pro-preview` is the floor, except where you enforce one model ([`--enforce-model`](run-flags.md)), which bypasses this list altogether. If nothing in the list is available, the run stops and asks how to proceed rather than silently downgrading.

Separately, a **detection (mid-tier) chain** — `claude-sonnet-5.5` → `claude-sonnet-5` → `claude-sonnet-4.6` → `claude-sonnet-4.5` — pins mechanical steps (repo scanning, format detection, mechanical fixes) so a strong-tier session doesn't burn an expensive model on cheap work; it never inherits the session model. It carries no GPT row: detection is work, and work is Anthropic.

**Two OpenAI models are reachable and deliberately unused.** `gpt-6-luna` is its family's lightweight, lowest-cost member, and a review gate is the one place where cost is explicitly subordinate to judgement. The `gpt-5.6-*` family is superseded — GitHub measures GPT-6.1 Sol as using fewer tokens and steps than both the GPT-6 and GPT-5.6 families — so no position exists in which a 5.6 model is the right answer.

You never pick a model for any of this yourself — the orchestrator resolves every chain automatically against what your environment has available, and every downgrade from the top of a chain is announced in the run's own report rather than happening quietly.

---

The full policy — the classification triggers in detail, the `model_routing` handoff block, the detection chain's role map, the mandatory strong-tier code-review checklist, and the large-input scan fan-out — is authoritative in [`../../skills/_shared/model-routing.md`](../../skills/_shared/model-routing.md). This page is a summary of it, not a substitute for it.

To bypass this policy for one run and pin every dispatched subagent to a model you choose, see [`--enforce-model`](run-flags.md). It changes which model each selected step runs on, never which steps run — and never the model the orchestrator itself is on. Because the strong tier here spans vendors, a non-Claude peer (`gpt-*`, `gemini-*`) has no family alias and is named by its full id.
