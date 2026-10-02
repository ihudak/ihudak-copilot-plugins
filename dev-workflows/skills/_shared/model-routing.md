# Model Routing by Task Complexity (Shared Policy)

This document is the **single source of truth** for how the dev-workflows
orchestrators classify tasks and route them to the appropriate model. Every
pipeline orchestrator — `implement:`, `vuln:`, `upgrade:`, `document:`, `epics:`,
`release-notes:`, `docs-profile:`, `idea:`, `create-vi:`, `update-vi:`, `create-ard:`,
`specify:`, `design:`, `ready:` — and their sub-agents MUST load and follow this
policy before doing any planning, implementation, review, or authoring work.

Standalone review orchestrators (`api-guideline-reviewer:`, `guideline-reviewer:`)
and the utility surfaces (`feedback:`, `prompt:`, `prompt-brainstorm:`,
`prompt-grill-me:`) are exempt — they do not classify complexity or route models.

---

## 1. Complexity Classes

Every task MUST be classified into exactly one of:

| Class         | Plain meaning                                                                 |
|---------------|-------------------------------------------------------------------------------|
| `SIMPLE`      | Trivial, mechanical, low blast radius (typo, comment, single-line tweak).     |
| `MODERATE`    | Localized feature/fix in 1–3 files, well-understood, no security implications.|
| `SIGNIFICANT` | Multi-file or cross-cutting, non-trivial design, real correctness risk.       |
| `HIGH-RISK`   | Security-, data-, or contract-sensitive; mistakes cause outages or breaches.  |

### 1.1 Classify as `SIGNIFICANT` or `HIGH-RISK` if **any** of the following apply

- Major framework or library upgrade (any **major** version bump, e.g. Spring Boot 2→3, React 17→18, Java 11→21).
- Vulnerability fix that requires a **major** dependency version bump or **source-code changes** in the repo (API renames, signature changes, deprecation removals, behaviour adaptations). See the "Vulnerability-fix exception" below — a CVE's category alone (RCE, deserialization, auth bypass, etc.) does **not** force this class regardless of which orchestrator (`vuln:`, `implement:`, `upgrade:`) is invoking the rubric; what matters is the size of the actual fix.
- Touches authentication, authorization, sessions, tokens, OAuth/OIDC, JWT, cookies, CSRF, CORS, or permissions.
- Touches database schema, migrations, or data integrity (DDL, foreign keys, indexes, backfills).
- Public API or wire-protocol contract changes (REST/GraphQL/gRPC routes, request/response shape, event schemas, SDK signatures).
- Broad refactoring across multiple modules.
- Concurrency, caching, transactions, locking, retries, idempotency, async/queue processing.
- Payment, billing, audit, compliance, PII, or other security-sensitive logic.
- Changes touching **more than 3–5 non-test files**.
- **Multi-source input** — `implement:` was given more than one code repository, or any directory input (an exported Jira ticket folder, or a spec/design folder). Large multi-source briefs are cross-cutting by nature; this floors the task at `SIGNIFICANT`. See §8 for the fan-out scan this triggers. The floor is overridable at plan approval if the user judges the work genuinely smaller than its input footprint.
- Unclear requirements, large unknowns, or otherwise high blast radius.

`HIGH-RISK` is the same list with an additional severity multiplier — pick it
when the change is **production-critical, security-critical, or data-irreversible**
(e.g. an auth bypass CVE in a public service; a destructive DB migration).

### 1.2 Classify as `MODERATE` when

- 1–3 files; well-scoped feature, bugfix, or refactor; no items from §1.1 apply.

### 1.3 Classify as `SIMPLE` when

- Single trivial edit (typo, formatting, log message, comment, dead-code removal)
  with no behavioural impact.

> **When in doubt, escalate one level.** Misclassifying upward is cheap; the
> only cost is one extra strong-model call. Misclassifying downward can ship bugs.

> **Vulnerability-fix exception — classify by fix size, not CVE category.**
> Two distinct rules apply here:
>
> **(a) Universal — CVE category never forces SIGNIFICANT/HIGH-RISK.** A
> CVE's category (RCE, deserialization, auth bypass, etc.) drives *attention*
> but does **not** by itself force a SIGNIFICANT/HIGH-RISK class, regardless
> of which orchestrator (`vuln:`, `implement:`, `upgrade:`) is invoking the
> rubric. Most CVEs are remediated by a patch or minor dependency bump with
> no source-code changes — those are MODERATE.
>
> **(b) Per-CVE size analysis — `vuln:` orchestrator only.** Only `vuln:`
> performs per-CVE fix-size analysis. In `vuln:`, escalate to SIGNIFICANT
> when the fix requires a major version bump or actual code changes in the
> repo (API renames, signature changes, deprecation removals, behaviour
> adaptations). Escalate to HIGH-RISK when a major bump targets a
> security-critical library (auth/authn frameworks, crypto, deserializers,
> JWT, OAuth, session libs). See `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/vuln/SKILL.md`
> "Step 0 — Classify & Route" for the full vulnerability rubric.
>
> **For `implement:` and `upgrade:` orchestrators**, the standard rubric in §1.1
> applies — there is no per-CVE size analysis available at classification
> time. If the user wants CVE-aware sizing, route the work through `vuln:`.

---

## 2. Strong (reasoning) tier — Anthropic-first, and the default for work

**Two tiers, split by role.** This section is the **work** tier — it runs everything that
*produces*: planning and planning critique, synthesis, delegated authoring, implementation, and
fixes. §2.3 is the **review** tier, which runs the gates that *judge*, and it is OpenAI-first.

The split is deliberate and is the house policy: **Anthropic models do the work, top OpenAI
models review it.** Two different models looking at one artifact catch more than one model
looking twice, and the reviewer having no stake in the authoring is the point of a gate.

Use the first available:

1. `claude-opus-5.5`
2. `claude-opus-5`
3. `claude-opus-4.8`
4. `claude-opus-4.7`
5. `claude-opus-4.6`
6. `claude-opus-4.5`

**Further fallbacks** (only if no Opus is available — announce the degradation in the routing
record and the final report):

7. `claude-sonnet-5.5`
8. `claude-sonnet-5`
9. `claude-sonnet-4.6`
10. `claude-sonnet-4.5`
11. `gemini-3.1-pro-preview`

`gemini-3.1-pro-preview` is the floor; if no model in the list is available, abort the
SIGNIFICANT/HIGH-RISK gates and ask the user how to proceed rather than silently downgrading.

**Selection rule:** prefer the model the **orchestrator is already running under** where it is
one of rows 1–6, otherwise take the first available row in list order. (Preferring the session
model is an economy, not a policy: it avoids paying to switch when the session is already on a
qualifying model.)

---

## 2.1 Detection ("mid-tier / throughput") chain

Some steps are deliberately **not** reasoning-heavy — mechanical detection, repo
scanning, transcription, formatting, mechanical fixes. Pin these to the detection
chain via the `task` tool's `model:` override; do **not** let them inherit the
session model (a strong-tier session would otherwise run "cheap" steps on an
expensive model, defeating the point).

Use the first available:

1. `claude-sonnet-5.5`
2. `claude-sonnet-5`
3. `claude-sonnet-4.6`
4. `claude-sonnet-4.5` (further fallback — note the degradation in the report)

**No GPT row sits here, by policy and by fact.** By policy: detection is work, and §2's split
puts work on Anthropic. By fact: this chain used to end in `gpt-5.4`, which appears in no
current Copilot model list — the 5.x GPT families are `gpt-5.6-<codename>`, and there is no
bare `gpt-5.4`, `gpt-5.5` or `gpt-5.6` at all. `gpt-6-luna` *is* reachable and is the
cost-efficient member of its family, so it is the one GPT model that would fit a cheap tier;
it is left out because §2's role split is the simpler rule to hold, and mixing vendors in the
cheap tier buys nothing a Sonnet row does not already give.

If none is available, fall back to the session model and announce it. Record the
chosen model as `detection_model:` in the `model_routing` block.

**`defect-reporter` runs on this chain too**, under `--skip-feedback` (`run-flags.md` §4),
recorded as `defect_model:`. Telling a defect from friction and confirming the wrong line in
the plugin's source is judgement, not throughput; it takes this chain because it is the tier
`impl-maintenance`, the agent it replaces, runs on. No chain in this file names Haiku;
`run-flags.md` §2 carries the Haiku rows an enforced Haiku value resolves against.

---

## 2.3 Review tier — OpenAI version 6 first

**Every gate that judges an artifact runs here**, not on §2: `code-review`, `doc-reviewer`,
`vi-reviewer`, `ard-reviewer`, `spec-reviewer`, `design-reviewer`, `epic-reviewer`,
`readiness-reviewer`, and any reviewer added later. Use the first available:

1. `gpt-6-astra`
2. `gpt-6.1-sol`
3. `gpt-6-sol`
4. **the §2 chain** (Opus 5.5 → 5 → 4.8 → 4.7 → 4.6 → 4.5, then §2's own further fallbacks)

Rows 1–3 are the version-6 OpenAI models; row 4 is the whole of §2, so a session with no
version-6 model reachable reviews on Anthropic exactly as it did before this split, and that
is **not announced as a degradation** — it is a documented branch of the policy.

**`gpt-6-astra` leads by house preference**, not by measurement in this repository. GitHub
describes Astra as built for "long-horizon, autonomous coding and agentic tasks" and Sol as "a
balanced model for interactive and agentic coding, and a strong all-round choice for
development tasks that benefit from careful, multistep validation" — and *multistep validation*
is arguably the better description of a review gate. The order here is the one the house asked
for; if a measured comparison ever disagrees, change it here and say so, rather than quietly
re-ranking at a call site.

**`gpt-6.1-sol` sits ahead of `gpt-6-sol`** because it is the newer Sol: GitHub's changelog
(2026-09-29) records it completing tasks with "noticeably fewer tokens and steps than earlier
models in the GPT-6 and GPT-5.6 families". Newest-within-a-codename is the rule; Astra-before-Sol
is the house preference above it.

**The selection rule of §2 does NOT apply here.** A review does not prefer the session model,
because the whole purpose of this tier is that the reviewer is not the author. A GPT-6 session
still reviews on §2.3 row 1 and an Opus session still reviews on §2.3 row 1 — the session model
changes nothing about which model judges.

**Models deliberately NOT in this tier**, so nobody reads their absence as an oversight:

- **`gpt-6-luna`** — GitHub's own description is "a lightweight, cost-efficient model for
  smaller, faster tasks and the lowest-cost option in the GPT-6 family". A review gate is the
  one place in this plugin where cost is explicitly subordinate to judgement, so the cheapest
  member of a family is the wrong choice for it. Luna is reachable and unused.
- **`gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`** — superseded. The 6.1 changelog above
  measures the newer model as cheaper *and* better than this family, so there is no position in
  which a 5.6 model is the right answer while any version-6 row or §2 is reachable.

**The ids in this section are exact, and the shape matters.** The GPT-5.6 family is
`gpt-5.6-<codename>`; **there is no bare `gpt-5.6`.** This file previously listed `gpt-5.6`,
`gpt-5.5` and `gpt-5.4` as chain rows, and none of those three appears in any current Copilot
model list — a chain naming an id the harness does not offer fails its dispatch or silently
falls through, which is the same class of defect as passing a full id to a parameter that
accepts only families (§5). Verified against GitHub's changelogs for GPT-6 Astra (2026-09-04),
GPT-6 Sol and Luna (2026-09-22), GPT-6.1 Sol (2026-09-29) and the GPT-5.6 family (2026-07-09).

The list of available models can be inspected from the `task` tool's `model` parameter
documentation. The "currently selected model" is whatever the orchestrator itself is running
under (see `~/.copilot/settings.json` → `model`). Sub-agents inherit it unless the orchestrator
explicitly overrides via the `task` tool's `model` argument (and under §10 every dispatch
overrides it).

---

## 3. Routing rules

### 3.1 SIMPLE / MODERATE

- Continue with the currently selected model.
- Do **not** add mandatory strong-tier gate steps.
- Proceed with normal planning, implementation, testing, and fixes.
- Skip the dedicated strong-tier code review (the standard `risk-planner` consult
  — when called — uses the workflow's default model selection).

### 3.2 SIGNIFICANT / HIGH-RISK — mandatory sequence

The orchestrator MUST execute these steps in order:

1. **Classify** the task and record the decision (see §4).
2. **Plan with the strong tier.** Delegate planning (or planning critique) to a
   sub-agent running on the strongest available reasoning model from §2. See §5
   for the exact `task` invocation pattern.
3. **Implement** with the currently selected model **or** the detection chain
   (fine for raw coding throughput; the strong tier is not required here).
   Sub-agents that do the actual file edits inherit the orchestrator's model
   unless overridden.
4. **Strong-tier code review** of the completed implementation. This is a
   dedicated `code-review` sub-agent invocation pinned to the **§2.3 review tier**. It
   MUST cover every item in the §6 checklist. Tests MUST NOT be run until this
   review completes.
5. **Run tests** (build + test suite per the executor / fixer skill).
6. **Apply review fixes** — fixes flagged by the review may be implemented by the
   currently selected model **or** the detection chain (no strong tier required
   for the fix edits themselves).
7. **Re-run tests** if any review fixes were applied.
8. **Final summary** — include the classification, the models used at each step
   (or the fallback notice), and a one-line outcome per checklist item from §6.

> **Do not use the strong tier for routine implementation steps unless the user
> explicitly requested it.** The strong tier is reserved for planning and the
> dedicated review.

---

## 4. The `model_routing` handoff block

Every orchestrator MUST record its routing decision and pass it to every
sub-agent that reads one — the list below. An agent whose handoff file declares
no `model_routing:` input is not sent one; its tier is pinned by the dispatch's
own `model:` argument. Format:

```yaml
model_routing:
  classification: SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK
  reason: <one-line justification citing the §1 trigger that applied>
  current_model: <e.g. claude-opus-5 or gpt-6-astra>   # the model the orchestrator is running
  planning_model: <e.g. claude-opus-5.5>     # §2 WORK tier; only set for SIGNIFICANT/HIGH-RISK
  review_model:   <e.g. gpt-6-astra>         # §2.3 REVIEW tier -- the gates that JUDGE, never §2.
                                             # Falls back to the whole of §2 (row 4) where no
                                             # version-6 GPT is reachable; that is a documented
                                             # branch, not a degradation. Only set for
                                             # SIGNIFICANT/HIGH-RISK.
  implementation_model: <e.g. claude-sonnet-5.5 or current_model>
  detection_model: <e.g. claude-sonnet-5.5>  # mid-tier steps (§2.1); never the session model
  defect_model:   <e.g. claude-sonnet-5.5>   # §2.1 chain; set only under --skip-feedback
  fixes_model:    <same as implementation_model>
  opus_available: true | false             # true if any §2 row 1-6 (Opus 5.5/5/4.8/4.7/4.6/4.5) is available
  review_tier_vendor: openai | anthropic   # which branch of §2.3 the review_model came from
  enforced_model: <e.g. claude-opus-5.5>   # §10: set only when run_flags.enforced_model is set
  routing: bypassed                        # §10: present only alongside enforced_model
  gate_tests_on_review: true | false   # optional; default false. Only meaningful for SIGNIFICANT/HIGH-RISK.
                                       # When true, the executor/fixer sub-agent stops after the build,
                                       # returns status: AWAITING_REVIEW, and waits for a follow-up call
                                       # with phase: verify-resume to run tests / commit / PR.
  notes: <optional — e.g. "no version-6 GPT reachable; reviews ran on the §2 Anthropic chain (a documented §2.3 branch, not a downgrade)">
```

The `phase` field used to resume an executor/fixer after the strong-tier review
is completed is **`verify-resume`** for both `upgrade-executor` and `vuln-fixer`
(harmonised). The executor/fixer must accept this value and run all remaining
steps (verify tests; for the fixer also commit + PR).

For SIMPLE/MODERATE the `planning_model` and `review_model` fields MAY be omitted
or set to `current_model`.

Sub-agents that receive a `model_routing` block:

- `upgrade-planner`, `vuln-research`: record the block in their output; their
  tier is the `model:` argument on the dispatch, resolved by step nature per §9.
  Both run on the `detection_model`, because each is invoked before its skill's
  per-unit classification exists, so there is nothing yet to escalate on. This
  bullet used to read "use the `planning_model` if present"; no caller does.
- `upgrade-executor`, `vuln-fixer`: **do not run tests** until the orchestrator
  has confirmed the review-tier review has completed (when classification is
  SIGNIFICANT/HIGH-RISK). The orchestrator achieves this by invoking the
  executor/fixer **without** the build+test phase first (apply changes only),
  then running the review, then invoking the executor/fixer again to run tests.
  Equivalently, the orchestrator may invoke a single combined call with a
  `gate_tests_on_review: true` flag — both styles are acceptable.
- `release-notes-writer`: receives the block; behaviour is unchanged by it.
- **A sub-agent whose handoff file declares no `model_routing:` input is sent
  none, and reads no field of one.** Its tier is fixed by the `model:` argument
  on the dispatch — the §2.3 review tier for the reviewers (`code-review`,
  `epic-reviewer`, `doc-reviewer`, `vi-reviewer`, `ard-reviewer`, `spec-reviewer`,
  `design-reviewer`, `readiness-reviewer`), the §2 work tier for `risk-planner`,
  the §2.1 detection chain for `jira-reader`, `code-scanner`, `diff-summarizer`,
  `doc-location-finder`, `docs-style-checker`, `doc-fixer`, `test-baseliner`,
  `test-writer` and `impl-maintenance`, and by classification for the writers
  (`doc-planner`, `doc-writer`, `epic-writer` — strong tier for
  SIGNIFICANT/judgment authoring, detection chain for MODERATE; see §9) — and
  the orchestrator's own `model_routing` record names the chain it resolved.
  Under §10 the dispatch carries the enforced model instead. This list used to
  say the reviewers, `test-baseliner`, `test-writer` and `impl-maintenance`
  "receive the block for reporting"; no dispatch in the plugin sends one to any
  of them, nor does any of their bodies read a field of it.

---

## 5. Delegating to a model via the `task` tool

The CLI's `task` tool accepts an explicit `model:` override. Use it like this:

```
task(
  agent_type: "dev-workflows:risk-planner" | "dev-workflows:code-review" | "general-purpose",
  model:      "claude-opus-5.5", # a WORK dispatch: the highest available row of §2. A REVIEW
                                 # dispatch passes §2.3's pick instead ("gpt-6-astra", ...).
                                 # Under §10, the enforced model. Pass the DISPATCH FORM (below)
  prompt:     "<full self-contained context — sub-agent has no memory>",
  description:"Strong-tier planning critique" | "Strong-tier code review",
  mode:       "sync"               # always sync for plan/review gates
)
```

**The dispatch rule — the record keeps the id, the argument passes what the tool accepts.** The `model_routing` record (§4) keeps the resolved id; it is the record of intent. The `task` tool's `model:` argument passes the **dispatch form** of that id: the id itself where the tool's `model` parameter accepts ids — **which is what this CLI does today**, so every dispatch here passes a full dotted id — and otherwise, on a **family-only harness** whose parameter enumerates only `opus | sonnet | haiku | fable`, that id's family name (`claude-opus-*` → `opus`, and so on). This one rule covers every dispatch in every skill and agent. **A non-Claude peer (`gpt-*`, `gemini-*`) has no family**, so on such a harness it could not be dispatched at all — which is why the rule is stated conditionally rather than converted to families outright.

- For **planning** on SIGNIFICANT/HIGH-RISK tasks, prefer `agent_type: "dev-workflows:risk-planner"`
  with the strong tier, asking it to critique the proposed plan.
- For **post-implementation review** on SIGNIFICANT/HIGH-RISK tasks, use
  `agent_type: "dev-workflows:code-review"` on the **§2.3 review tier**, passing the diff and §6 checklist.
- If `dev-workflows:code-review` is unavailable in the environment, fall back to
  `agent_type: "general-purpose"` with the same strong-tier model and the explicit
  §6 checklist embedded in the prompt.

---

## 6. Mandatory strong-tier code-review checklist (SIGNIFICANT / HIGH-RISK)

The post-implementation review MUST explicitly comment on each of:

1. **Correctness** — does the change actually do what was planned, including all
   listed acceptance criteria and edge cases?
2. **Security impact** — new attack surface, authn/authz changes, secret
   handling, input validation, deserialization, injection vectors, supply chain.
3. **Architectural consistency** — boundaries respected, abstractions intact,
   no leaking concerns, idiomatic for the codebase.
4. **Missed edge cases** — empty/null/zero/negative/very-large inputs, partial
   failures, concurrent access, time-zone / DST / locale, off-by-one, retries.
5. **Migration risks** — schema changes, data backfills, feature flags, ordering
   between deploy and migration, forward/backward compatibility windows.
6. **Dependency risks** — new transitive deps, license changes, abandoned
   packages, known CVEs in the new versions, lockfile drift.
7. **Test adequacy** — does the test suite actually cover the new behaviour?
   Are negative tests and boundary tests present? Are tests deterministic?
8. **Rollback considerations** — how is this change reverted? Are migrations
   reversible? Is there a feature flag? What is the worst-case incident playbook?

The review output MUST include a verdict per item: `OK` / `CONCERN` / `BLOCKER`,
plus a free-text comment for any non-`OK` finding. Before proceeding to tests the
orchestrator MUST **dispose of** every `BLOCKER` — and document the disposition of
each `CONCERN` — where a disposition is either a fix or a dismissal recorded with a
reason that disposes of that finding's own claim, per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/finding-triage.md`. Only survivors are handed to
the fixer; no `BLOCKER` may be left undisposed, and none may be dropped silently.

---

## 7. Reporting

The orchestrator's final report MUST include a `### Model Routing` section:

```
### Model Routing
- Classification: <class>
- Reason: <trigger>
- Planning model: <model>
- Implementation model: <model>
- Review model: <model>  (or "n/a — SIMPLE/MODERATE")
- Strong-tier checklist verdicts:
  - Correctness: OK | CONCERN | BLOCKER
  - Security: ...
  - Architecture: ...
  - Edge cases: ...
  - Migration: ...
  - Dependencies: ...
  - Tests: ...
  - Rollback: ...
- Notes: <degradation, fallbacks, deferred items>
```

For SIMPLE/MODERATE tasks the verdict list MAY be omitted; the classification
and reason are still required.

---

## 8. Large-input scan fan-out

When a scanning step must digest more than a single working tree, a single
explorer subagent on a weak session model comprehends it poorly. This section
is the shared policy for that case. It generalizes the pattern `epics:`
already used; the commands that run §8.2 and those that also adopt §8.5 are
named in §8.5's *Opt-in* paragraph, which is the one list of them.

### 8.1 Trigger (input shape, not measured volume)

Fan out when **any** of these structural facts hold for the invocation:

- more than one code repository is referenced;
- an exported Jira ticket folder is supplied;
- a spec/design folder is supplied.

Counting files or bytes is explicitly **not** used — the trigger is the shape
of the input, which is cheap to detect and easy to explain. A single repo with
inline/`@file` text only does **not** trigger fan-out; the caller keeps its
normal single-explorer path.

### 8.2 The fan-out pattern

1. `jira-reader` reads each ticket folder (read-only) → themes, PR references
   (identifiers only), linked items.
2. Spec/design folders are read inline and folded into the themes.
3. `code-scanner` is fanned out **one instance per repository, in a single
   response, capped at 4 concurrent**. Each instance receives the themes and
   its own repo path; it returns capabilities, gaps, and relevant files.
4. The orchestrator synthesizes the `jira-reader` output, all scanner reports,
   and the spec into one codebase summary that feeds the strong-tier planner.

### 8.3 Model routing inside the fan-out

- `jira-reader` and `code-scanner` are **pinned to the §2.1 detection chain**
  via the `task` tool `model:` override — the same rule as every other mechanical
  step (§2.1, §9.1). Scanning is mechanical filesystem work; it must not inherit
  the session model (a strong-tier session would otherwise burn an expensive
  model on a cheap step), and its tier must not depend on which model the session
  happens to run under.
- Because the trigger floors the task at `SIGNIFICANT` (§1.1), synthesis and
  planning run on the strongest available reasoning model via `risk-planner`
  (§2 chain). That is where reasoning power is applied — the mechanical scan
  that feeds it does not need it.
- **Optional escalation:** if a single repo slice is itself oversized for the
  detection tier to comprehend, the orchestrator MAY pin that one `code-scanner`
  to the strong tier via the `task` tool `model:` override. This is a size-driven,
  judgment-based exception — not session-driven.

### 8.4 Honesty

A referenced directory that is missing, or is neither a recognized folder type
nor a git repository, MUST be surfaced to the user — never silently skipped
(mirrors the `REFRESH_BLOCKED` honesty rule used by the Jira-driven flows).

### 8.5 Broad, then narrow (the seeded second round)

A broad prompt lets each scanner defer to the layer it did not scan. Round 1
asks every repo the same wide question, and a capability spanning two layers can
come back attributed to the *other* layer by both scanners — a pair of confident
answers that together say nothing. Naming a verified anchor removes the escape.

**Round 1** is the §8.2 fan-out unchanged: one `code-scanner` per repository,
broad themes, single response, cap 4 concurrent.

**Inconclusive** describes a round-1 theme whose `classification` is `partial`,
`absent`, or `error`, **or** for which **two or more** scanners' per-theme
`capability_map[].gap_summary` texts point at each other's repo in a cycle, or
at a component/subsystem that no scanned repo covers.

**Round 2** fires for an inconclusive theme when round 1 produced at least one
evidence anchor to seed from. It dispatches the **same** `code-scanner` agent
with a narrowed brief:

- `capability_themes` holds exactly **one** question — not the broad theme, but
  the single thing round 1 failed to settle;
- `search_hints.paths` / `.symbols` / `.keywords` are seeded from round 1's
  verified `evidence[].path` and `.symbols`; where an evidence entry carries
  `lines`, name the anchor as `<path>:<line>` in the round-2 `context` prose,
  since `search_hints` has no line-number field.

No new agent and no input-contract change: the narrowing lives entirely in what
the caller puts in the existing fields.

The narrowed brief changes only those fields: every other field of round 1's
dispatch — **including `refresh:`** — is reused verbatim, so a caller that
pinned a read-only posture in round 1 keeps it in round 2.

**Bounds.** Round 2 is capped at **4 dispatches** and is **one round only**.
There is no round 3. A theme still inconclusive after round 2 is reported
unresolved — never guessed at. **Precedence: mutual deferral and `error` are
unresolved regardless of whether a round-1 evidence anchor existed to seed a
round 2** — a theme with no anchor never gets a round-2 attempt, but the
absence of an attempt is not itself a resolution. A theme confirmed `absent`
— by round 2, or by round 1 when no anchor existed to seed one — is a
**resolved** finding, and the outside-deferral qualifier below is
caller-scoped. For **`implement:`** it is resolved only when that `absent`
carries **no deferral to a repo or layer outside the scanned set**, because
that caller's premise is that the capability lives somewhere across the repos
in scope. For **`idea:`** it is resolved unconditionally — the confirmed repo
set *is* the world the idea grounds against (see the altitude paragraph that
follows) — and it belongs in Section 7's *What's missing*, not in Open
questions. `[NEEDS CLARIFICATION]` (or the caller's equivalent) is for a theme
the scan could not settle — mutual deferral, `error`, or, **for `implement:`
only**, `absent` everywhere scanned **plus** a deferral outside the scanned
set.

The altitude differs by caller. For `idea: --ground-code`, the confirmed repo
set **is** the world the idea is grounding against, so `absent` everywhere
scanned genuinely means missing. For `implement:`'s fan-out, the premise is
that the capability lives *somewhere* across the repos in scope — so `absent`
everywhere scanned **plus** a deferral outside the scanned set means "the scan
could not tell," not "the capability does not exist."

**Opt-in.** §8.5 is a shared procedure a caller adopts by saying so in its own
body. Its consumers are `idea:` (Phase 2.6) and `implement:` (Phase 1.7).
`epics:`, `create-ard:`, `specify:`, and `design:` run §8.2 alone and are
unaffected by this section.

**Round 2 resolves; it does not license a guess.** A caller that adopts §8.5
also owes its downstream consumer the truth about what stayed unresolved. An
inconclusive theme is not a gap: a gap asserts the capability is absent, an
unresolved theme asserts only that the scan could not tell, and flattening the
second into the first hands the next step a confident-looking answer that was
never earned. Name unresolved themes explicitly in whatever the caller passes
on — `idea:` carries them into `[NEEDS CLARIFICATION]`, `implement:` into the
codebase summary's `## Unresolved` section and from there into the plan's
risks.

---

## 9. Per-step routing (every skill)

Steps differ in nature — some judgment-heavy, some mechanical — and a skill
MUST NOT let every step inherit the session model. Apply this policy in every
skill, resolving each model against the §2 (strong) and §2.1 (detection)
chains. The Jira-driven authoring pipelines (`document:` and `epics:`) run long
phase sequences and are the motivating case, not the scope — §9.4 is the
governing rule.

### 9.1 Principle

- **Judgment-heavy authoring / synthesis** steps run on the §2 strong chain —
  escalate to the strong tier even when the session is a detection-tier model.
- **Mechanical detection / throughput / fix** steps run on the §2.1 detection
  chain — de-escalate off the session model even when the session is strong-tier
  (otherwise a strong-tier session burns an expensive model on cheap work).
- **Orchestrator-executed** judgment steps — the inline prose writing and the
  interactive gates, plus the orchestration itself — run on the session model
  and CANNOT be overridden from inside a running command. Handle them with an
  **advisory** (recommend relaunching on the §2 chain), never an override. This
  advisory applies when the task is SIGNIFICANT/HIGH-RISK; for SIMPLE/MODERATE the
  writer runs on its detection pin without a relaunch advisory (per §3.1).

### 9.2 Role → chain map

| Role | Chain |
|------|-------|
| Synthesis / planner (e.g. `doc-planner`) | §2 strong |
| Reader / summarizer / locator / style-checker / fixer / maintenance (`jira-reader`, `diff-summarizer`, `doc-location-finder`, `docs-style-checker`, `doc-fixer`, maintenance agents) | §2.1 detection |
| Domain reviewer (`doc-reviewer`, `epic-reviewer`) | §2.3 review tier — dispatch-pinned to this chain at every call (no agent in this edition carries a `model:` frontmatter field); the orchestrator records it and adds **no** override |
| Delegated writer (`doc-writer` / `epic-writer`) | §2 strong for SIGNIFICANT/judgment writing; §2.1 detection for MODERATE writing |
| Coordination + interactive gates (the orchestrator itself) | session model; narrowed-window advisory for large non-strong-tier runs (§9.1) |

### 9.3 No-strong-tier degradation

When no Opus model is available (§2 rows 1–6), run the work roles on the next
available §2 fallback; a review role that also finds no version-6 GPT model
(§2.3 rows 1–3) is already on §2 by §2.3's own row 4, and follows the same
fallback. In either case, **skip** the relaunch advisory (there is nothing
to relaunch onto), and announce the degradation in the `model_routing` record and
the final report — the same rule as §2.

### 9.4 One rule across commands (`implement:` included)

Routing is by **step nature**, not by pipeline or session: `jira-reader` and
`code-scanner` are mechanical, so they run on the §2.1 detection chain in
**every** command — `implement:`'s fan-out (§8.3), `epics:`, and `document:`
alike. There is no "inherit the session model" for scanning and no per-command
exception. A step's downstream consumer does not change its tier: a mechanical
scan that feeds a strong-tier synthesis (e.g. `implement:`'s `risk-planner`) still
runs on the detection chain — the reasoning power is applied in the synthesis
step, not the scan. The only carve-out is size-driven, not session-driven:
escalate a single oversized repo slice's `code-scanner` to the strong tier (§8.3).

---

## 10. Enforced model

`run_flags.enforced_model` (`run-flags.md`) lets a run pin every subagent dispatch to one model, bypassing this policy's own per-step selection. Classification and the routing rules above are unchanged in what they select — this section changes only which model each selection resolves to.

- **Chain resolution.** When `run_flags.enforced_model` is set, every resolution of §2, §2.1 and §2.3 returns that value instead of walking its own chain. Every `*_model` field of the §4 `model_routing` block that names a **dispatched** step equals it — `planning_model`, `review_model`, `detection_model`, `fixes_model`, `defect_model` — and the block gains `enforced_model: <id>` and `routing: bypassed`. A field that records the orchestrator's own inline work keeps the session model, never the enforced value, because enforcement pins subagent dispatches and not the session: `current_model` always does, and so does `implementation_model` / `authoring_model` wherever a skill codes or authors inline rather than delegating. `opus_available` is still resolved and reported truthfully — it is a property of the environment, not of the enforcement choice.
- **Every dispatch.** Every `task` dispatch passes `model: <enforced>` explicitly, in §5's dispatch form, including agents whose frontmatter pins a tier: the dispatch's `model:` argument overrides the frontmatter pin. Every "frontmatter-pinned … no override" statement at a dispatch site reads "no override unless §10 enforces a model".
- **Nested dispatch.** An agent that itself dispatches another (`docs-style-checker` → `dt-style-checker`; `upgrade-executor` / `vuln-fixer` → `test-baseliner`) receives `enforced_model` in its prompt and passes it on its own dispatch, so enforcement reaches every model a run touches.
- **Steps unchanged.** Classification still runs and still selects the §3 sequence for the task's class. Enforcement changes which model each selected step runs on, never whether the step runs.
- **The orchestrator.** The orchestrator stays on the session model; it cannot be switched from inside a running skill. `run-flags.md` §3 step 7 prints the one relaunch advisory when the two differ.
- **Strong-tier-session gates do not fire.** Every gate or degrade path that tests `current_model` for a strong-tier session does not fire under enforcement — the whole class of them, since each exists to require or prefer a strong-tier session and the user has already chosen the model. Testing the enforced value in a gate's place would let a weak session pass a strong gate, since the inline grill or authoring these gates protect still runs on the session model.
- **Degradation notices are suppressed.** §2's and §9's degradation notices are not emitted under enforcement — there is no fallback to announce. The report carries `Model routing: bypassed — enforced <id> (flag|env)` in place of what that field would otherwise record.
