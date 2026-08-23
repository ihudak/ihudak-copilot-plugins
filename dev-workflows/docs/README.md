# dev-workflows documentation

Twenty keyword-triggered skills for the PM → PA → PE → Dev workflow, plus 34 sub-agents, 4 hooks, and the shared reference docs under `skills/_shared/`. This tree documents all of it — start here.

## I want to…

| I want to… | Go to |
|---|---|
| install this and set it up | [Getting started](getting-started.md) |
| understand the whole pipeline first | [Workflow overview](workflow.md) |
| know what my role is responsible for | [Roles and phases](roles-and-phases.md) |
| turn a raw idea into something actionable | [`idea:`](skills/idea.md) |
| write or refresh a Value Increment | [`create-vi:`](skills/create-vi.md), [`update-vi:`](skills/update-vi.md) |
| record an architecture decision | [`create-ard:`](skills/create-ard.md) |
| break a VI into Epics | [`epics:`](skills/epics.md) |
| write a specification, then a design | [`specify:`](skills/specify.md), [`design:`](skills/design.md) |
| build the thing | [`implement:`](skills/implement.md) |
| document it, then announce it | [`document:`](skills/document.md), [`release-notes:`](skills/release-notes.md) |
| bootstrap or refresh the docs profile `document:` reads | [`docs-profile:`](skills/docs-profile.md) |
| check whether a ticket is really ready | [`ready:`](skills/ready.md) |
| fix a CVE or upgrade a dependency | [`vuln:`](skills/vuln.md), [`upgrade:`](skills/upgrade.md) |
| tell the plugin it got something wrong | [`feedback:`](skills/feedback.md), [`prompt:`](skills/prompt.md), [`prompt-brainstorm:`](skills/prompt-brainstorm.md), [`prompt-grill-me:`](skills/prompt-grill-me.md) |
| review an API spec or app UI against guidelines | [`api-guideline-reviewer:`](skills/api-guideline-reviewer.md), [`guideline-reviewer:`](skills/guideline-reviewer.md) |

Three pages orient you before you touch a skill: [Getting started](getting-started.md) installs the plugin and sets your environment variables; [Workflow overview](workflow.md) shows the whole pipeline as one diagram; [Roles and phases](roles-and-phases.md) says what each role owns and hands off. Every skill below is invoked by a `name:` keyword at the start of your prompt, not a slash command — `/clear`, `/compact`, and `/rename` are the CLI's own host commands and keep their slashes. Every other page documents one skill, or — for [Agents](reference/agents.md) and [References](reference/references.md) — one whole inventory.

## Skills

`skills/` holds the twenty entries below, each a `<name>/SKILL.md`. `skills/_shared/` sits alongside them but is not itself a skill — it is the reference-doc directory the skills draw on; see [References](reference/references.md).

- [`api-guideline-reviewer:`](skills/api-guideline-reviewer.md) — review an OpenAPI spec against the bundled REST API and IAM permission naming guidelines.
- [`create-ard:`](skills/create-ard.md) — author an Architecture Requirements/Decision Document for a VI, or for one Epic inside it, grounded on the mounted implementation repos.
- [`create-vi:`](skills/create-vi.md) — turn a refined `idea.md` plus a user-supplied Jira key into a reviewed Value Increment.
- [`design:`](skills/design.md) — take over a merged `specification.md` and author a reviewed engineering `design.md`, grounded strictly in the mounted implementation code.
- [`docs-profile:`](skills/docs-profile.md) — scan a documentation repository and write or refresh the machine-readable profile `document:` consumes.
- [`document:`](skills/document.md) — read a Jira Value Increment hierarchy, resolve PR diffs, and synthesise product documentation, gated on style-check and Opus review.
- [`epics:`](skills/epics.md) — draft child Epic definitions from a Value Increment, optionally scanning code repos, gated on dt-style-checker and Opus review.
- [`feedback:`](skills/feedback.md) — log a manual note about the plugin itself, for the maintainer to aggregate. Tied to no skill; run any time.
- [`guideline-reviewer:`](skills/guideline-reviewer.md) — review Dynatrace app code and UI against the bundled Experience Standards (GUIDElines).
- [`idea:`](skills/idea.md) — refine one source into a lean `idea.md` through a bounded one-question-at-a-time grill, seeding the future `create-vi:`.
- [`implement:`](skills/implement.md) — classify, branch, plan, implement, test, and Opus-review a code change end to end.
- [`prompt:`](skills/prompt.md) — log a correction you just made to a skill's output, then apply the fix directly.
- [`prompt-brainstorm:`](skills/prompt-brainstorm.md) — log a correction, then hand off to `superpowers:brainstorming` to redesign it together.
- [`prompt-grill-me:`](skills/prompt-grill-me.md) — log a correction, then grill the fix inline with a bounded (≤5-question) interrogation.
- [`ready:`](skills/ready.md) — read a Jira workflow status and verify the ARD/spec/design artifacts justify it, without ever setting it.
- [`release-notes:`](skills/release-notes.md) — draft a release-notes Summary for a Jira ticket, shaped by the destination it resolves to.
- [`specify:`](skills/specify.md) — author an org-standard `specification.md` for one Jira item through a relentless one-question-at-a-time grill.
- [`update-vi:`](skills/update-vi.md) — refresh an existing Value Increment against its Jira source, behind a 3-day freshness gate.
- [`upgrade:`](skills/upgrade.md) — plan and execute a library, framework, runtime, or build-tool upgrade to a specified or latest version.
- [`vuln:`](skills/vuln.md) — research and fix a CVE via NVD, one dependency or code change at a time.

## Reference

- [Agents](reference/agents.md) — the subagent inventory: what each of the 34 helper agents does and which skill calls it.
- [References](reference/references.md) — the reference-doc inventory under `skills/_shared/`, grouped by subtree.
- [Environment](reference/environment.md) — every environment variable the plugin reads, and what it configures.
- [Hooks](reference/hooks.md) — the bundled hooks and what each one does.
- [Model routing](reference/model-routing.md) — the task-complexity classification and model fallback chain skills apply before acting.
- [Session feedback](reference/session-feedback.md) — two different signals about the plugin itself: `feedback:` logs what you tell it, while `prompt:` / `prompt-brainstorm:` / `prompt-grill-me:` capture a bad result, your correction, and the good result that came out of it.
- [Follow-ups](reference/follow-ups.md) — how a skill emits follow-up tasks into your vault.
- [Resume and checkpoints](reference/resume-and-checkpoints.md) — session hygiene: checkpointing state and resuming a long-running skill.
