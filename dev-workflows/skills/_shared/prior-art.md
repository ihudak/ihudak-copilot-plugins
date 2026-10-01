# Prior-art discovery (shared reference)

An idea rarely starts on empty ground. The specs repo already holds initiatives that cover the same capability, precede it, parallel it in the other product, or *are* it under a different description. Reaching that prior art **before** authoring changes what gets authored; reaching it afterwards changes only how much gets rewritten.

Prior art arrives two ways and this file governs both. **Supplied** — the user hands `idea:` a Value Increment key. **Discovered** — `prior-art-finder` searches the specs repo. Both produce the same digest, resolve status the same way, and land in the same `## Prior art` section.

Consumers: `idea:` (grill-rank, `## Prior art`, handoff) and `create-vi:` (grill-rank). **Read-only** — neither ever writes into a matched item. **Advisory only** — never a gate, never a reviewer BLOCKER. Every miss is a silent, non-blocking skip.

## Procedure — `resolve-prior-art <command-name>`

1. **Flags first.** `--no-prior-art` → return `prior_art: OFF`, `reason: "disabled with --no-prior-art"`.
2. **Resolve the root.** `specs_root = $SPECS_PATH`. No default — it is the plugin's write root.
3. **Validity gate — ON only when all hold** (else `OFF` with a one-line reason): `$SPECS_PATH` is non-empty, an existing readable directory, and holds `specifications/` (or `specs/` / `vis/`).
4. **Return** `{ prior_art, specs_root, reason }`.

There is deliberately **no index, no cache, and no consent prompt**. The corpus is a few hundred markdown files and retrieval is `Glob` + `Grep`, so this file has no analogue of `docs-grounding.md` step 3.5 — and none should be added.

## Plan-approval line

One line, surfaced in the command's plan/approval step. This reference owns the format; consumer commands quote it. It reports **resolution only** — the match count is not known until after dispatch, so no form promises one.

```
prior art: ON <specs-root>
prior art: OFF (<reason>)
```

The off switch (`--no-prior-art`) is stated by the consumer command beside the line, not inline.

## Dispatch — `dispatch-prior-art-finder`

Run only when `prior_art: ON`. Dispatch in the **same response** as `dispatch-docs-grounder` so the two grounding reads run in parallel.

```
→ task(agent_type: "dev-workflows:prior-art-finder", model: <detection_model>):
  > "Find tracked prior art for this idea and return the digest:
  >
  > specs_root:      <specs_root>
  > origin_dir:      <abs path of the run's origin/feature folder, or null>
  > feature_summary: <2–4 sentences: the problem + desired outcome>
  > themes:          [capability themes, or []]
  > known_refs:      [{path: <abs path> | jira_key: <KEY>, has_summary: true|false}, …]"
```

A `known_refs` entry carries **either** a `path` **or** a `jira_key`. A supplied `vi` source has only a key — the caller does not know which feature folder holds it, and resolving that is the finder's job. A followed wikilink has only a path.

Wait for the digest. On `status: ERROR` or any dispatch failure, treat as `prior_art: OFF` and proceed (record one line in the final report). On `status: EMPTY`, proceed; the digest simply adds nothing.

## Search scope and exclusions

Root: `<spec-dirs>/*/` under `<specs_root>` (`<spec-dirs>` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/jira-input-resolution.md`) — one **item** per feature folder. Read, per item: its phase deliverables (`idea.md`, the VI `<KEY>_<slug>.md`, `*_ARD.md`, `specification.md`, `design.md`) and its own root ticket page `jira-import/<KEY>/<KEY>.md` (summary, description and status — never the import's other tickets, which belong to their own folders).

A **search hit** is excluded when its folder is the run's own origin folder (`origin_dir`) — a run is never prior art for itself; a `known_refs` entry still resolves to the origin folder, so a supplied VI keeps its status and its `supersedes_self` classification. A folder is also **excluded** from search when its root ticket's `issue_type` is `Value Pack`; or when it lies under an `_archive/` segment. `epic-drafts/`, `dev-workflows/` and `Doc screenshots/` are never read.

## Status resolution

An item's Jira key is its folder's key (`^([A-Z][A-Z0-9_]*-\d+)`). Its status is the `status:` frontmatter of `jira-import/<KEY>/<KEY>.md` → `status_source: jira-import`, with the file's modification date as `status_date`. No import → `tracked_status: unknown`, `status_source: none`. One source, so there is no disagreement to report.

## Vocabulary

The closed term sets. `idea-format.md` and `prior-art-finder` both cite this section; it is defined here once so the two cannot drift.

**`relation`** — how a match stands to the new work.

| Term | Meaning |
|---|---|
| `same_capability` | The item covers this very capability. |
| `predecessor_phase` | This idea is the next phase of that item. |
| `analogous_precedent` | A **parallel** initiative to model this one on — typically the same capability in the other product (an existing SaaS Value Increment ↔ a new Managed one on the 2gen UI). It produces no contradiction by itself; the question is where alignment is required and where divergence is deliberate. |
| `supersedes_self` | This idea **rewrites the very item it came from**, in place: same goal, different approach, same Jira key. |
| `adjacent_initiative` | Related but distinct work. |

**`kind`** — the reconciliation question a challenge puts to the author.

| Term | Meaning |
|---|---|
| `already_tracked` | An initiative already covers this at status X; how is this different? |
| `phase_continuation` | This looks like the next phase of `<KEY>`; author it as such? |
| `precedent_alignment` | The precedent does X (scope shape, altitude, permissions, naming, UX). Should this match it, and where must it diverge? Name the divergence deliberately. |
| `rewrite_delta` | The item currently specifies X and this idea proposes Y. Is the **goal** unchanged, and which existing content is superseded rather than extended? |
| `superseded` | The match is `Closed` / `Cancelled` / `Post GA`; does that resolve the problem, or is this a revival? |
| `adjacent_scope_boundary` | Related work in flight; where is the boundary? |

## Consumption

**`grill-rank`** (`idea:`, `create-vi:`) — feed `prior_art` to the grill as positive grounding. **Rank** each `prior_art_challenges` entry into the command's existing Impact × Uncertainty gap list together with `docs_challenges`; do **not** append. A challenge competes for attention (a question slot only where the caller's grill is capped) and never adds one — this preserves `idea:`'s ≤10-question bound.

**`## Prior art`** (`idea:`) — the durable carrier, written per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/idea-format.md`. Fed from both directions: discovered matches and a supplied `vi` source alike.

**Handoff** (`idea:` Phase 5) — matched keys with statuses.

## Bounding

| Bound | Value |
|---|---|
| Directory enumeration | ≤ 500 |
| Keywords | 3–8 |
| Keyword drop threshold | > 60 files |
| Shortlist | ≤ 40 files |
| Feature folders read | ≤ 8 |
| `prior_art[]` | ≤ 5 |
| `prior_art_challenges[]` | ≤ 4 |
| `salient_summary` | ≤ 150 words |

## Invariants

- Read-only; never writes into a matched item.
- Never blocks; every failure is a silent, non-blocking skip. Advisory only — never a gate, never a reviewer BLOCKER.
- `$SPECS_PATH` has **no default** — it is the plugin's write root.
- No retrieval index, no cache, no model download, and therefore no consent gate. Do not add one.
- Value Packs are never read, reported, or acted on.
- A `known_ref` whose path no longer resolves is **dropped with a `notes` line** — never an error, never fabricated. Feature folders get renamed, so this is ordinary input. When the dropped entry carried a Jira key, re-resolve it by key.
- `supersedes_self` is reachable only for `discovered_by: source` — a search hit is by definition a different item.
- `resolve-prior-art` runs **exactly once per run**, at the earliest phase that shows the `prior art:` line; any later invocation in that run consumes the cached result.
