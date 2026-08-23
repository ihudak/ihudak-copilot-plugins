# Copilot Docs Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Copilot edition of `dev-workflows` a 32-page documentation tree gated by the same `check-docs.sh` all three editions run, with the script byte-identical everywhere and only a per-edition config block differing.

**Architecture:** Two phases. Phase A parameterises the existing gate and lands it in the two Claude editions, where a known-good docs tree proves the parameterisation changed no behaviour. Phase B builds Copilot's tree against that proven gate. Phase A is independently mergeable — three PRs — and must merge before Phase B's final task.

**Tech Stack:** Bash (the gate), Python 3 (the catalog validator, already a CI dependency), GitHub Actions, markdown.

**Spec:** `docs/superpowers/specs/2026-08-23-copilot-docs-port-design.md` — read it first; it carries the evidence for every deliberate omission.

## Global Constraints

- **The Claude pages are a source of topics, never a source of facts.** Every claim on a Copilot page is derived from *this* edition's files. The original restructure found six defects precisely because it worked this way.
- **`check-docs.sh` is byte-identical in all three editions.** Only the config block at the top differs. Verify with `diff` against the canonical copy, ignoring that block.
- **The config block is an identity file.** Never copy it between editions.
- **20 skills, not 21.** `statusline` does not exist here. `_shared` is not a skill.
- **No cost subsystem.** No `session-cost.md` page, no cost half of `roles-and-phases.md`, no §7 attribution table. `HAS_COST=0`.
- **5 user-settable env vars:** `VAULT_PATH`, `SPECS_PATH`, `REPOS_PATH`, `DOCS_PATH`, `GIT_USER_INITIALS`. `MODEL_ROUTING` and `PLUGIN_ROOT` are runtime (`MODEL_ROUTING` is assigned at `hooks/preload-context.sh:52`).
- **`/clear`, `/compact`, `/rename` keep their slashes.** 61 occurrences. Only the 20 skill names take the `name:` form.
- **Runtime path references inside prose** use this edition's convention — `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/<file>` — never `${CLAUDE_PLUGIN_ROOT}/...`. Doc-to-doc *links* stay relative (`../../skills/_shared/x.md`); the absolute form is for prose that tells the agent where to read at runtime.
- **Reference root is `skills/_shared/`** — 36 top-level `.md`, 6 subtrees (`api-guidelines`, `dynatrace-docs`, `fix-vuln`, `guidelines`, `handoff`, `upgrade`), and **`model-routing.md` is a flat file here**, not a subtree as in canonical.
- Every task ends with all available gates passing: `check-docs.sh --selftest`, `check-docs.sh --root .`, `check-id-grammar.sh` both modes, `validate-catalog.py`, and the spec-ID census.

---

# PHASE A — the shared gate

## Task 1: Config block + parameterise the checks (canonical)

**Files:**
- Modify: `/workspace/ihudak-claude-plugins/scripts/check-docs.sh:16` and every site listed below

**Interfaces:**
- Produces: config variables `PLUGIN_REL`, `CMD_DIR`, `CMD_SUFFIX`, `CMD_EXCLUDE`, `REF_DIR`, `REF_FLAT_EXTRA`, `DOC_CMD_DIR`, `CLI`, `CLI_VERBS`, `HAS_COST` — consumed by Tasks 2, 3, 5.

- [ ] **Step 1: Record the baseline the change must not alter**

```bash
cd /workspace/ihudak-claude-plugins
./scripts/check-docs.sh --selftest > /tmp/baseline-selftest.txt 2>&1
./scripts/check-docs.sh --root .   > /tmp/baseline-root.txt 2>&1
grep -c '^ok' /tmp/baseline-selftest.txt   # expect 36
```

- [ ] **Step 2: Insert the config block immediately after `PLUGIN_REL`**

```bash
# ---------------------------------------------------------------- edition config
# THE ONLY PART OF THIS FILE THAT DIFFERS BETWEEN EDITIONS. Never copy it across.
# Everything below is byte-identical in ihudak-claude-plugins, mgd-claude-plugins
# and ihudak-copilot-plugins, so a fix to the gate ports by plain `cp` of the body.
PLUGIN_REL="plugins/dev-workflows"   # copilot: dev-workflows
CMD_DIR="commands"                   # copilot: skills
CMD_SUFFIX=".md"                     # copilot: /SKILL.md
CMD_EXCLUDE=""                       # copilot: _shared
REF_DIR="references"                 # copilot: skills/_shared
REF_FLAT_EXTRA="model-routing"       # canonical: references/model-routing/*.md is a
                                     # subtree of reference FILES; copilot: "" (its
                                     # model-routing.md is a flat file in _shared)
DOC_CMD_DIR="commands"               # copilot: skills
CLI="claude"                         # copilot: copilot
CLI_VERBS="marketplace add|marketplace update|install|reinstall"   # copilot: marketplace add|install|update
HAS_COST=1                           # copilot: 0 -- no cost subsystem exists there
```

- [ ] **Step 3: Replace each hardcoded site**

Exact substitutions (line numbers from the pre-edit file):
- `:143,:144,:146,:147` — `commands` → `$CMD_DIR`, `docs/commands` → `docs/$DOC_CMD_DIR`, `.md` name-stripping → honour `$CMD_SUFFIX`. **Wire `$CMD_EXCLUDE` here**: the enumeration becomes `ls -d "$p/$CMD_DIR"/*/ | sed 's|/*$||; s|.*/||' | grep -vxF "${CMD_EXCLUDE:-__none__}"` when `$CMD_SUFFIX` is a path, and the flat `ls *.md` form otherwise. Without this, Copilot's `_shared/` is enumerated as a skill and check 4 demands a page for it.
- `:160,:161,:163,:164` — `references` → `$REF_DIR`; the `model-routing` glob becomes `[ -n "$REF_FLAT_EXTRA" ] && ls "$p/$REF_DIR/$REF_FLAT_EXTRA"/*.md`
- `:174,:176,:177,:184` — subtree loops → `$REF_DIR`
- `:233,:418` — env-var scan roots → `"$p/$CMD_DIR" "$p/agents" "$p/$REF_DIR" "$p/hooks"`
- `:294–:312` — `claude plugin` → `$CLI plugin`, verb alternation → `$CLI_VERBS`
- `:326,:364` — emit-cost extractor → `$CMD_DIR`, and wrap the whole of `check_cost_attribution` in `[ "$HAS_COST" = 1 ] || { note "check 8 not applicable: this edition has no cost subsystem"; return; }`
- `:408–:412` — prose-count file paths → config-driven
- The check-9 cost-emitting assertion → same `HAS_COST` guard, with its own `note`

- [ ] **Step 4: Prove behaviour is unchanged**

```bash
./scripts/check-docs.sh --selftest > /tmp/after-selftest.txt 2>&1
./scripts/check-docs.sh --root .   > /tmp/after-root.txt 2>&1
diff /tmp/baseline-selftest.txt /tmp/after-selftest.txt && echo "selftest identical"
diff /tmp/baseline-root.txt   /tmp/after-root.txt   && echo "root run identical"
```
Expected: both `diff`s empty. **A single differing line means the parameterisation changed behaviour — stop and fix before proceeding.**

- [ ] **Step 5: Commit**

```bash
git add scripts/check-docs.sh
git commit -m "refactor(scripts): parameterise check-docs.sh for a shared, cross-edition gate"
```

## Task 2: Parameterise the selftest mutations

**Files:**
- Modify: `/workspace/ihudak-claude-plugins/scripts/check-docs.sh` — the 36 `expect_fail` lines

**Interfaces:**
- Consumes: Task 1's config variables.
- Produces: a selftest body that adapts to whichever config is loaded — required by Task 5, where the fixture is in Copilot layout.

- [ ] **Step 1: Replace every hardcoded fixture path in the mutation strings**

Each `expect_fail` mutation currently hardcodes `plugins/dev-workflows/...`. Replace with `$PLUGIN_REL/...`, `$CMD_DIR`, `$DOC_CMD_DIR`, `$CMD_SUFFIX` and `$CLI` as appropriate. Example, the undocumented-command case:

```bash
# before
expect_fail "an undocumented command is rejected" 4 "printf -- '---\nname: delta\n---\n' > plugins/dev-workflows/commands/delta.md"
# after
expect_fail "an undocumented command is rejected" 4 "mkdir -p $PLUGIN_REL/$CMD_DIR/delta 2>/dev/null; printf -- '---\nname: delta\n---\n' > $PLUGIN_REL/$CMD_DIR/delta$CMD_SUFFIX"
```

The `mkdir -p` is required because `$CMD_SUFFIX` may be `/SKILL.md`, which needs its parent directory to exist. It is a harmless no-op when the suffix is `.md`.

- [ ] **Step 2: Guard the two cost cases**

The three check-8 cases and the one check-9 cost case must not run when `HAS_COST=0`. Wrap them:

```bash
if [ "$HAS_COST" = 1 ]; then
  expect_fail "an unattributed emit-cost call is rejected" 8 "..."
  expect_fail "a drifted attributed role is rejected"      8 "..."
  expect_fail "a section-7 row for a non-emitting command is rejected" 8 "..."
  expect_fail "a drifted cost-emitting count is rejected"  9 "..."
else
  printf 'skip  4 cost cases (this edition has no cost subsystem)\n'
fi
```

- [ ] **Step 3: Verify the count is unchanged in this edition**

```bash
./scripts/check-docs.sh --selftest | tail -3
grep -c '^ok' <(./scripts/check-docs.sh --selftest 2>&1)   # expect 36
```
Expected: `SELFTEST PASS`, 36 ok lines — identical to Task 1's baseline.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-docs.sh
git commit -m "refactor(scripts): make the selftest mutations config-driven too"
```

## Task 3: Land the shared gate in mgd

**Files:**
- Modify: `/workspace/mgd-claude-plugins/scripts/check-docs.sh`

- [ ] **Step 1: Copy the body, keep mgd's config block**

mgd's config is identical to canonical's (same layout), so a whole-file copy is correct here — but verify rather than assume:

```bash
cd /workspace/mgd-claude-plugins && git switch -c iv-gu/shared-gate
cp /workspace/ihudak-claude-plugins/scripts/check-docs.sh scripts/check-docs.sh
diff <(sed -n '/edition config/,/^HAS_COST/p' scripts/check-docs.sh) \
     <(sed -n '/edition config/,/^HAS_COST/p' /workspace/ihudak-claude-plugins/scripts/check-docs.sh) \
  && echo "config blocks identical -- correct for mgd, which shares the Claude layout"
```

- [ ] **Step 2: Run every gate**

```bash
./scripts/check-docs.sh --selftest | tail -1        # SELFTEST PASS
./scripts/check-docs.sh --root .   | tail -1        # PASS
./scripts/check-id-grammar.sh --selftest | tail -1  # SELFTEST PASS
./scripts/check-id-grammar.sh --root .   | tail -1  # PASS
python3 scripts/validate-catalog.py | tail -1       # 0 error(s)
```

- [ ] **Step 3: Commit and push both editions**

```bash
git add scripts/check-docs.sh && git commit -m "refactor(scripts): adopt the shared, parameterised docs gate"
git push -u origin iv-gu/shared-gate
```

**Phase A gate: both PRs must merge before Task 16.**

---

# PHASE B — the Copilot tree

## Task 4: Copilot config block and fixture

**Files:**
- Create: `/workspace/ihudak-copilot-plugins/scripts/check-docs.sh` (body copied, config written)
- Create: `/workspace/ihudak-copilot-plugins/scripts/fixtures/docs/pass/` — Copilot-layout fixture

- [ ] **Step 1: Copy the body and write Copilot's config**

```bash
cd /workspace/ihudak-copilot-plugins && git switch -c iv-gu/docs-port
cp /workspace/ihudak-claude-plugins/scripts/check-docs.sh scripts/check-docs.sh
```
Then set: `PLUGIN_REL="dev-workflows"`, `CMD_DIR="skills"`, `CMD_SUFFIX="/SKILL.md"`, `CMD_EXCLUDE="_shared"`, `REF_DIR="skills/_shared"`, `REF_FLAT_EXTRA=""`, `DOC_CMD_DIR="skills"`, `CLI="copilot"`, `CLI_VERBS="marketplace add|install|update"`, `HAS_COST=0`.

- [ ] **Step 2: Build the fixture in Copilot layout**

Mirror `scripts/fixtures/docs/pass/` from canonical but in this edition's shape: `dev-workflows/skills/alpha/SKILL.md`, `dev-workflows/skills/_shared/gamma.md`, `dev-workflows/agents/beta.md`, `dev-workflows/hooks/notify-fixture.sh`, `dev-workflows/docs/{README.md,getting-started.md,skills/alpha.md,reference/{agents,environment,hooks,references}.md}`, plus a root `README.md` carrying `copilot plugin` lines. Include the six legal constructs the canonical fixture carries (non-ASCII heading, duplicate headings, titled link, angle link, `~~~` fenced table, indented row) — they guard checks 1, 2 and 6 in both directions.

- [ ] **Step 3: Verify the gate runs and reports the inert checks**

```bash
./scripts/check-docs.sh --root scripts/fixtures/docs/pass | tail -3
./scripts/check-docs.sh --selftest | tail -3
```
Expected: fixture PASSes; selftest prints `skip  5 cost cases (this edition has no cost subsystem)` and `SELFTEST PASS` with **32** ok lines — 37 total minus the 5 cost-dependent cases. (Task 2 added a case, and its review established that five cases depend on the cost subsystem, not four: the three `emit-cost` check-8 cases, the section-7-row case, and the check-9 cost-emitting count.)

- [ ] **Step 4: Prove the body never diverged**

```bash
diff <(sed '/edition config/,/^HAS_COST/d' scripts/check-docs.sh) \
     <(sed '/edition config/,/^HAS_COST/d' /workspace/ihudak-claude-plugins/scripts/check-docs.sh) \
  && echo "bodies identical -- the invariant holds"
```
Expected: empty diff. **This is the plan's central invariant; a non-empty diff here fails the task.**

- [ ] **Step 5: Commit**

```bash
git add scripts/ && git commit -m "feat(scripts): Copilot edition of the shared docs gate, with its own fixture"
```

## Task 5: `docs/README.md` and `docs/getting-started.md`

**Files:**
- Create: `dev-workflows/docs/README.md`, `dev-workflows/docs/getting-started.md`

**Interfaces:**
- Produces: the index every other page is reached from (check 3 roots reachability here), and the install block check 7 pins to the repo-root README.

- [ ] **Step 1: Write `docs/README.md`**

An "I want to…" lookup table, then a Skills section listing all 20 with a one-line description each, then a Reference section listing the 8 pages. Derive each description from that skill's own `SKILL.md` frontmatter `description:` — not from the Claude page. Use the `name:` invocation form throughout.

- [ ] **Step 2: Write `docs/getting-started.md`**

Sections: Install (marketplace add + the two `copilot plugin install` lines, inline), Update (`copilot plugin update --all`), What you set on your machine (the **5** variables), Your first run (`idea:`). Include the `superpowers` weak-dependency paragraph and the note that grilling is bundled. **No status-line section** — this edition has none.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1-9]|PASS|FAIL'
```
Expected: check 7 passes (install lines match the root README); check 3 will still report the not-yet-written pages as absent — that is expected until Task 12.

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs && git commit -m "docs(dev-workflows): index and getting-started"
```

## Task 6: `docs/workflow.md` and `docs/roles.md`

**Files:**
- Create: `dev-workflows/docs/workflow.md`, `dev-workflows/docs/roles-and-phases.md`

- [ ] **Step 1: Write `workflow.md`**

A Mermaid pipeline diagram with role subgraphs (PM / PA / PE / Dev), using `name:` invocation labels. Derive edges from `skills/_shared/next-phase-offer.md`, not from the Claude diagram. Include the direct `create-vi: → specify:` VI-level path. Add the Roles table and Artifact homes. **Omit** the three-name collision note — that is a Claude Code concern.

- [ ] **Step 2: Write `roles-and-phases.md`**

The handover model and the four role sections (PM, PA, PE, Dev) **only**. No "Cost-attribution phases" half — this edition has none. State plainly near the top that cost attribution does not exist here, so a reader coming from the Claude docs is not left hunting for it.

- [ ] **Step 3: Verify and commit**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -cE 'check 2'   # expect 0 -- all anchors resolve
git add dev-workflows/docs && git commit -m "docs(dev-workflows): workflow overview and roles"
```

## Task 7: Skill pages — PM

**Files:**
- Create: `dev-workflows/docs/skills/idea.md`
- Create: `dev-workflows/docs/skills/create-vi.md`
- Create: `dev-workflows/docs/skills/update-vi.md`
- Create: `dev-workflows/docs/skills/feedback.md`

**Interfaces:**
- Consumes: `docs/roles.md`'s heading anchors from Task 6 — `#pm-product-management`, `#pa-product-architecture`, `#pe-product-engineering`, `#dev-build-verify-and-deliver`, `#the-handover-model`. Link to these exact slugs; check 2 fails on any other.
- Produces: four pages `docs/README.md` already links to.

The four skills in this task: `idea:`, `create-vi:`, `update-vi:`, `feedback:`.

Each page carries these sections, in this order:

1. `## Who runs it` — role only. **No cost phase, no role label from a §7 table** — none exists.
2. `## Synopsis` — the invocation form (`<name>: <args>`) and argument resolution, derived from the skill's own `SKILL.md`.
3. `## How it runs` — only when the skill dispatches ≥2 distinct `dev-workflows:<agent>` agents for which `agents/<agent>.md` exists. Mermaid phase diagram, node labels quoted **verbatim** from the skill's own `## Phase N` headings.
4. `## What it needs` · 5. `## What it produces` · 6. `## Gates` · 7. `## Example` · 8. `## See also`

- [ ] **Step 1 (each task): Derive, do not translate**

For each of the four skills, read `dev-workflows/skills/<name>/SKILL.md` in full first. Count its `## Phase` headings and its distinct `dev-workflows:<agent>` tokens before writing any count into the page.

- [ ] **Step 2: Write the four pages**

Worked shape, using `idea` as the model — every page follows it:

```markdown
# idea:

<one sentence, derived from skills/idea/SKILL.md's own description field>

## Who runs it

`idea:` runs in the **PM** role. This edition records no cost attribution, so
there is no phase or role label on the run's output.

## Synopsis

    idea: <prompt | @file | community-post URL | VI key> [--deep] [--ground-code]

<argument resolution, derived from the skill's own Phase 0>

## How it runs

<included ONLY if the skill dispatches >=2 distinct dev-workflows:<agent> tokens
 for which agents/<agent>.md exists. Mermaid node labels quoted VERBATIM from the
 skill's own `## Phase N` headings.>

## What it needs      ## What it produces      ## Gates
## Example            ## See also
```

Before writing each page run, for that skill:

```bash
S=dev-workflows/skills/<name>/SKILL.md
grep -cE '^## Phase' $S                                     # phase count for the page
grep -oE 'dev-workflows:[a-z-]+' $S | sort -u | while read a; do
  n=${a#dev-workflows:}; [ -f dev-workflows/agents/$n.md ] && echo "$n"; done | wc -l
```
The second number decides whether `## How it runs` gets a diagram, and is the number the page may state. Command self-references and skill invocations do not count.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1246]' ; echo "---"
grep -c '/design\|/implement\|/specify' dev-workflows/docs/skills/*.md   # expect 0 -- colon form only
grep -c '/clear\|/compact\|/rename' dev-workflows/docs/skills/*.md       # these MAY appear -- host commands
```

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs/skills && git commit -m "docs(dev-workflows): skill pages — <group>"
```


## Task 8: Skill pages — PA and PE

**Files:**
- Create: `dev-workflows/docs/skills/create-ard.md`
- Create: `dev-workflows/docs/skills/epics.md`
- Create: `dev-workflows/docs/skills/specify.md`
- Create: `dev-workflows/docs/skills/prompt.md`

**Interfaces:**
- Consumes: `docs/roles.md`'s heading anchors from Task 6 — `#pm-product-management`, `#pa-product-architecture`, `#pe-product-engineering`, `#dev-build-verify-and-deliver`, `#the-handover-model`. Link to these exact slugs; check 2 fails on any other.
- Produces: four pages `docs/README.md` already links to.

The four skills in this task: `create-ard:`, `epics:`, `specify:`, `prompt:`.

Each page carries these sections, in this order:

1. `## Who runs it` — role only. **No cost phase, no role label from a §7 table** — none exists.
2. `## Synopsis` — the invocation form (`<name>: <args>`) and argument resolution, derived from the skill's own `SKILL.md`.
3. `## How it runs` — only when the skill dispatches ≥2 distinct `dev-workflows:<agent>` agents for which `agents/<agent>.md` exists. Mermaid phase diagram, node labels quoted **verbatim** from the skill's own `## Phase N` headings.
4. `## What it needs` · 5. `## What it produces` · 6. `## Gates` · 7. `## Example` · 8. `## See also`

- [ ] **Step 1 (each task): Derive, do not translate**

For each of the four skills, read `dev-workflows/skills/<name>/SKILL.md` in full first. Count its `## Phase` headings and its distinct `dev-workflows:<agent>` tokens before writing any count into the page.

- [ ] **Step 2: Write the four pages**

Worked shape, using `idea` as the model — every page follows it:

```markdown
# idea:

<one sentence, derived from skills/idea/SKILL.md's own description field>

## Who runs it

`idea:` runs in the **PM** role. This edition records no cost attribution, so
there is no phase or role label on the run's output.

## Synopsis

    idea: <prompt | @file | community-post URL | VI key> [--deep] [--ground-code]

<argument resolution, derived from the skill's own Phase 0>

## How it runs

<included ONLY if the skill dispatches >=2 distinct dev-workflows:<agent> tokens
 for which agents/<agent>.md exists. Mermaid node labels quoted VERBATIM from the
 skill's own `## Phase N` headings.>

## What it needs      ## What it produces      ## Gates
## Example            ## See also
```

Before writing each page run, for that skill:

```bash
S=dev-workflows/skills/<name>/SKILL.md
grep -cE '^## Phase' $S                                     # phase count for the page
grep -oE 'dev-workflows:[a-z-]+' $S | sort -u | while read a; do
  n=${a#dev-workflows:}; [ -f dev-workflows/agents/$n.md ] && echo "$n"; done | wc -l
```
The second number decides whether `## How it runs` gets a diagram, and is the number the page may state. Command self-references and skill invocations do not count.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1246]' ; echo "---"
grep -c '/design\|/implement\|/specify' dev-workflows/docs/skills/*.md   # expect 0 -- colon form only
grep -c '/clear\|/compact\|/rename' dev-workflows/docs/skills/*.md       # these MAY appear -- host commands
```

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs/skills && git commit -m "docs(dev-workflows): skill pages — <group>"
```


## Task 9: Skill pages — Dev

**Files:**
- Create: `dev-workflows/docs/skills/design.md`
- Create: `dev-workflows/docs/skills/implement.md`
- Create: `dev-workflows/docs/skills/document.md`
- Create: `dev-workflows/docs/skills/ready.md`

**Interfaces:**
- Consumes: `docs/roles.md`'s heading anchors from Task 6 — `#pm-product-management`, `#pa-product-architecture`, `#pe-product-engineering`, `#dev-build-verify-and-deliver`, `#the-handover-model`. Link to these exact slugs; check 2 fails on any other.
- Produces: four pages `docs/README.md` already links to.

The four skills in this task: `design:`, `implement:`, `document:`, `ready:`.

Each page carries these sections, in this order:

1. `## Who runs it` — role only. **No cost phase, no role label from a §7 table** — none exists.
2. `## Synopsis` — the invocation form (`<name>: <args>`) and argument resolution, derived from the skill's own `SKILL.md`.
3. `## How it runs` — only when the skill dispatches ≥2 distinct `dev-workflows:<agent>` agents for which `agents/<agent>.md` exists. Mermaid phase diagram, node labels quoted **verbatim** from the skill's own `## Phase N` headings.
4. `## What it needs` · 5. `## What it produces` · 6. `## Gates` · 7. `## Example` · 8. `## See also`

- [ ] **Step 1 (each task): Derive, do not translate**

For each of the four skills, read `dev-workflows/skills/<name>/SKILL.md` in full first. Count its `## Phase` headings and its distinct `dev-workflows:<agent>` tokens before writing any count into the page.

- [ ] **Step 2: Write the four pages**

Worked shape, using `idea` as the model — every page follows it:

```markdown
# idea:

<one sentence, derived from skills/idea/SKILL.md's own description field>

## Who runs it

`idea:` runs in the **PM** role. This edition records no cost attribution, so
there is no phase or role label on the run's output.

## Synopsis

    idea: <prompt | @file | community-post URL | VI key> [--deep] [--ground-code]

<argument resolution, derived from the skill's own Phase 0>

## How it runs

<included ONLY if the skill dispatches >=2 distinct dev-workflows:<agent> tokens
 for which agents/<agent>.md exists. Mermaid node labels quoted VERBATIM from the
 skill's own `## Phase N` headings.>

## What it needs      ## What it produces      ## Gates
## Example            ## See also
```

Before writing each page run, for that skill:

```bash
S=dev-workflows/skills/<name>/SKILL.md
grep -cE '^## Phase' $S                                     # phase count for the page
grep -oE 'dev-workflows:[a-z-]+' $S | sort -u | while read a; do
  n=${a#dev-workflows:}; [ -f dev-workflows/agents/$n.md ] && echo "$n"; done | wc -l
```
The second number decides whether `## How it runs` gets a diagram, and is the number the page may state. Command self-references and skill invocations do not count.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1246]' ; echo "---"
grep -c '/design\|/implement\|/specify' dev-workflows/docs/skills/*.md   # expect 0 -- colon form only
grep -c '/clear\|/compact\|/rename' dev-workflows/docs/skills/*.md       # these MAY appear -- host commands
```

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs/skills && git commit -m "docs(dev-workflows): skill pages — <group>"
```


## Task 10: Skill pages — delivery and maintenance

**Files:**
- Create: `dev-workflows/docs/skills/release-notes.md`
- Create: `dev-workflows/docs/skills/vuln.md`
- Create: `dev-workflows/docs/skills/upgrade.md`
- Create: `dev-workflows/docs/skills/docs-profile.md`

**Interfaces:**
- Consumes: `docs/roles.md`'s heading anchors from Task 6 — `#pm-product-management`, `#pa-product-architecture`, `#pe-product-engineering`, `#dev-build-verify-and-deliver`, `#the-handover-model`. Link to these exact slugs; check 2 fails on any other.
- Produces: four pages `docs/README.md` already links to.

The four skills in this task: `release-notes:`, `vuln:`, `upgrade:`, `docs-profile:`.

Each page carries these sections, in this order:

1. `## Who runs it` — role only. **No cost phase, no role label from a §7 table** — none exists.
2. `## Synopsis` — the invocation form (`<name>: <args>`) and argument resolution, derived from the skill's own `SKILL.md`.
3. `## How it runs` — only when the skill dispatches ≥2 distinct `dev-workflows:<agent>` agents for which `agents/<agent>.md` exists. Mermaid phase diagram, node labels quoted **verbatim** from the skill's own `## Phase N` headings.
4. `## What it needs` · 5. `## What it produces` · 6. `## Gates` · 7. `## Example` · 8. `## See also`

- [ ] **Step 1 (each task): Derive, do not translate**

For each of the four skills, read `dev-workflows/skills/<name>/SKILL.md` in full first. Count its `## Phase` headings and its distinct `dev-workflows:<agent>` tokens before writing any count into the page.

- [ ] **Step 2: Write the four pages**

Worked shape, using `idea` as the model — every page follows it:

```markdown
# idea:

<one sentence, derived from skills/idea/SKILL.md's own description field>

## Who runs it

`idea:` runs in the **PM** role. This edition records no cost attribution, so
there is no phase or role label on the run's output.

## Synopsis

    idea: <prompt | @file | community-post URL | VI key> [--deep] [--ground-code]

<argument resolution, derived from the skill's own Phase 0>

## How it runs

<included ONLY if the skill dispatches >=2 distinct dev-workflows:<agent> tokens
 for which agents/<agent>.md exists. Mermaid node labels quoted VERBATIM from the
 skill's own `## Phase N` headings.>

## What it needs      ## What it produces      ## Gates
## Example            ## See also
```

Before writing each page run, for that skill:

```bash
S=dev-workflows/skills/<name>/SKILL.md
grep -cE '^## Phase' $S                                     # phase count for the page
grep -oE 'dev-workflows:[a-z-]+' $S | sort -u | while read a; do
  n=${a#dev-workflows:}; [ -f dev-workflows/agents/$n.md ] && echo "$n"; done | wc -l
```
The second number decides whether `## How it runs` gets a diagram, and is the number the page may state. Command self-references and skill invocations do not count.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1246]' ; echo "---"
grep -c '/design\|/implement\|/specify' dev-workflows/docs/skills/*.md   # expect 0 -- colon form only
grep -c '/clear\|/compact\|/rename' dev-workflows/docs/skills/*.md       # these MAY appear -- host commands
```

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs/skills && git commit -m "docs(dev-workflows): skill pages — <group>"
```


## Task 11: Skill pages — review and feedback

**Files:**
- Create: `dev-workflows/docs/skills/api-guideline-reviewer.md`
- Create: `dev-workflows/docs/skills/guideline-reviewer.md`
- Create: `dev-workflows/docs/skills/prompt-brainstorm.md`
- Create: `dev-workflows/docs/skills/prompt-grill-me.md`

**Interfaces:**
- Consumes: `docs/roles.md`'s heading anchors from Task 6 — `#pm-product-management`, `#pa-product-architecture`, `#pe-product-engineering`, `#dev-build-verify-and-deliver`, `#the-handover-model`. Link to these exact slugs; check 2 fails on any other.
- Produces: four pages `docs/README.md` already links to.

The four skills in this task: `api-guideline-reviewer:`, `guideline-reviewer:`, `prompt-brainstorm:`, `prompt-grill-me:`.

Each page carries these sections, in this order:

1. `## Who runs it` — role only. **No cost phase, no role label from a §7 table** — none exists.
2. `## Synopsis` — the invocation form (`<name>: <args>`) and argument resolution, derived from the skill's own `SKILL.md`.
3. `## How it runs` — only when the skill dispatches ≥2 distinct `dev-workflows:<agent>` agents for which `agents/<agent>.md` exists. Mermaid phase diagram, node labels quoted **verbatim** from the skill's own `## Phase N` headings.
4. `## What it needs` · 5. `## What it produces` · 6. `## Gates` · 7. `## Example` · 8. `## See also`

- [ ] **Step 1 (each task): Derive, do not translate**

For each of the four skills, read `dev-workflows/skills/<name>/SKILL.md` in full first. Count its `## Phase` headings and its distinct `dev-workflows:<agent>` tokens before writing any count into the page.

- [ ] **Step 2: Write the four pages**

Worked shape, using `idea` as the model — every page follows it:

```markdown
# idea:

<one sentence, derived from skills/idea/SKILL.md's own description field>

## Who runs it

`idea:` runs in the **PM** role. This edition records no cost attribution, so
there is no phase or role label on the run's output.

## Synopsis

    idea: <prompt | @file | community-post URL | VI key> [--deep] [--ground-code]

<argument resolution, derived from the skill's own Phase 0>

## How it runs

<included ONLY if the skill dispatches >=2 distinct dev-workflows:<agent> tokens
 for which agents/<agent>.md exists. Mermaid node labels quoted VERBATIM from the
 skill's own `## Phase N` headings.>

## What it needs      ## What it produces      ## Gates
## Example            ## See also
```

Before writing each page run, for that skill:

```bash
S=dev-workflows/skills/<name>/SKILL.md
grep -cE '^## Phase' $S                                     # phase count for the page
grep -oE 'dev-workflows:[a-z-]+' $S | sort -u | while read a; do
  n=${a#dev-workflows:}; [ -f dev-workflows/agents/$n.md ] && echo "$n"; done | wc -l
```
The second number decides whether `## How it runs` gets a diagram, and is the number the page may state. Command self-references and skill invocations do not count.

- [ ] **Step 3: Verify**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep -E 'check [1246]' ; echo "---"
grep -c '/design\|/implement\|/specify' dev-workflows/docs/skills/*.md   # expect 0 -- colon form only
grep -c '/clear\|/compact\|/rename' dev-workflows/docs/skills/*.md       # these MAY appear -- host commands
```

- [ ] **Step 4: Commit**

```bash
git add dev-workflows/docs/skills && git commit -m "docs(dev-workflows): skill pages — <group>"
```


## Task 12: Reference pages — `agents.md`, `references.md`

**Files:**
- Create: `dev-workflows/docs/reference/agents.md`
- Create: `dev-workflows/docs/reference/references.md`

**Interfaces:**
- Consumes: nothing from sibling tasks.
- Produces: pages `docs/README.md`'s Reference section already links to.

Covers the 34 agents, and the reference inventory: 36 flat `_shared` files, its 6 subtrees with counts, the 3 per-skill `references/` subdirs, and the 20 skills.

**Derive every inventory from the tree, never from a Claude page or from a number written into another page:**

```bash
ls dev-workflows/agents/*.md | wc -l
ls dev-workflows/skills/_shared/*.md | wc -l
for d in $(find dev-workflows/skills/_shared -mindepth 1 -maxdepth 1 -type d); do
  printf "%s %s\n" "$(basename $d)" "$(find $d -name '*.md' | wc -l)"; done
ls dev-workflows/hooks/*.sh | wc -l
```

**`session-cost.md` is NOT created** — this edition has no cost subsystem (spec §2).

- [ ] **Step 1: Derive the inventories with the commands above, before writing prose**
- [ ] **Step 2: Write the pages**
- [ ] **Step 3: Verify both directions of check 4**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep 'check 4' || echo "inventories agree both ways"
```

- [ ] **Step 4: Commit**

## Task 13: Reference pages — `environment.md`, `hooks.md`

**Files:**
- Create: `dev-workflows/docs/reference/environment.md`
- Create: `dev-workflows/docs/reference/hooks.md`

**Interfaces:**
- Consumes: nothing from sibling tasks.
- Produces: pages `docs/README.md`'s Reference section already links to.

Covers the **5** user-settable variables, and the 4 hooks — `hooks.md` **must** state that Copilot CLI does not support Claude Code's `matcher` field, so both `PostToolUse` hooks fire on every tool use; the Claude page has no such note.

**Derive every inventory from the tree, never from a Claude page or from a number written into another page:**

```bash
ls dev-workflows/agents/*.md | wc -l
ls dev-workflows/skills/_shared/*.md | wc -l
for d in $(find dev-workflows/skills/_shared -mindepth 1 -maxdepth 1 -type d); do
  printf "%s %s\n" "$(basename $d)" "$(find $d -name '*.md' | wc -l)"; done
ls dev-workflows/hooks/*.sh | wc -l
```

**`session-cost.md` is NOT created** — this edition has no cost subsystem (spec §2).

- [ ] **Step 1: Derive the inventories with the commands above, before writing prose**
- [ ] **Step 2: Write the pages**
- [ ] **Step 3: Verify both directions of check 4**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep 'check 4' || echo "inventories agree both ways"
```

- [ ] **Step 4: Commit**

## Task 14: Reference pages — `model-routing.md`, `session-feedback.md`, `follow-ups.md`, `resume-and-checkpoints.md`

**Files:**
- Create: `dev-workflows/docs/reference/model-routing.md`
- Create: `dev-workflows/docs/reference/session-feedback.md`
- Create: `dev-workflows/docs/reference/follow-ups.md`
- Create: `dev-workflows/docs/reference/resume-and-checkpoints.md`

**Interfaces:**
- Consumes: nothing from sibling tasks.
- Produces: pages `docs/README.md`'s Reference section already links to.

Covers the classification tiers and fallback chain, the two feedback signals, the follow-up ladder, and session hygiene.

**Derive every inventory from the tree, never from a Claude page or from a number written into another page:**

```bash
ls dev-workflows/agents/*.md | wc -l
ls dev-workflows/skills/_shared/*.md | wc -l
for d in $(find dev-workflows/skills/_shared -mindepth 1 -maxdepth 1 -type d); do
  printf "%s %s\n" "$(basename $d)" "$(find $d -name '*.md' | wc -l)"; done
ls dev-workflows/hooks/*.sh | wc -l
```

**`session-cost.md` is NOT created** — this edition has no cost subsystem (spec §2).

- [ ] **Step 1: Derive the inventories with the commands above, before writing prose**
- [ ] **Step 2: Write the pages**
- [ ] **Step 3: Verify both directions of check 4**

```bash
./scripts/check-docs.sh --root . 2>&1 | grep 'check 4' || echo "inventories agree both ways"
```

- [ ] **Step 4: Commit**

## Task 15: Register the tree in `copilot-instructions.md`

**Files:**
- Modify: `/workspace/ihudak-copilot-plugins/.github/copilot-instructions.md`

- [ ] **Step 1: Add `docs/` to the repository-structure block** (it already gained `hooks/` in a prior fix — keep that).

- [ ] **Step 2: Add the convention bullet** carrying the derivation contract, the check list with `HAS_COST=0`'s two inert checks named, the pre-push command, and the identity-quarantine rule.

- [ ] **Step 3: Commit**

## Task 16: CI, versions, changelog, final verification

**Files:**
- Modify: `.github/workflows/validate-catalog.yml`, `dev-workflows/.plugin/plugin.json`, `.github/plugin/marketplace.json`, `dev-workflows/CHANGELOG.md`, `scripts/spec-id-baseline.txt`

- [ ] **Step 1: Wire the gate into CI, self-test first**

```yaml
      - name: Self-test the docs gate
        run: ./scripts/check-docs.sh --selftest

      - name: Check docs against the plugin tree
        run: ./scripts/check-docs.sh --root .
```

- [ ] **Step 2: Bump the version and write the changelog entry**, recording the two deliberate omissions with their evidence so a later reader does not "fix" them.

- [ ] **Step 3: Regenerate the spec-ID census if and only if it drifted**

```bash
grep -rhoE '\[U0[0-9]+\]|\[AC0[0-9]+\]|\[TC0[0-9]+\]|\[Uxx\]|\[ACxx\]|\[TCxx\]' \
  --include='*.md' --exclude='CHANGELOG.md' dev-workflows/ 2>/dev/null | sort | uniq -c \
  | diff <(grep -v '^#' scripts/spec-id-baseline.txt) -
```
If it drifted, record the delta and the reason in the file's header before regenerating.

- [ ] **Step 4: Full verification**

```bash
./scripts/check-docs.sh --selftest | tail -1        # SELFTEST PASS (32 ok, 4 skipped)
./scripts/check-docs.sh --root .   | tail -1        # PASS
./scripts/check-id-grammar.sh --selftest | tail -1
./scripts/check-id-grammar.sh --root .   | tail -1
python3 scripts/validate-catalog.py | tail -1
find dev-workflows/docs -name '*.md' | wc -l        # expect 32
diff <(sed '/edition config/,/^HAS_COST/d' scripts/check-docs.sh) \
     <(sed '/edition config/,/^HAS_COST/d' /workspace/ihudak-claude-plugins/scripts/check-docs.sh)
```
Expected: all pass, 32 pages, empty diff.

- [ ] **Step 5: Commit and push**
