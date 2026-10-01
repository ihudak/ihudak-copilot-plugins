# Maintainer rationale

This page is evidence and history for rules stated elsewhere in this repository's instruction
tiers (`.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`). Nothing in
this repository loads it automatically — no skill, agent, hook, or CI step reads it as part of a
run. It exists so a rule can be re-derived and checked without carrying its supporting evidence
into every session that loads the rule itself. Read a rule's linked section here before proposing
to change that rule.

## selftest-case-count

`.github/instructions/dev-workflows-shared.instructions.md`'s `_shared/` directory catalogue used
to state that `./scripts/check-docs.sh --selftest` "runs 32 cases, not 37" for this edition. Both
halves of that sentence were wrong for the tree as it stands on 2026-09-26.

Measured directly:

```
$ ./scripts/check-docs.sh --selftest | grep -c '^ok'
33
```

For comparison, the Claude edition (`/workspace/mgd-claude-plugins`) was measured the same way on
the same date:

```
$ cd /workspace/mgd-claude-plugins && ./scripts/check-docs.sh --selftest | grep -c '^ok'
39
```

The two numbers reconcile once the scripts do. `check-docs.sh`'s body below the edition-config block is meant to be byte-identical across editions, and it had drifted: `mgd-claude-plugins` 2.61.0 added a sixth cost-only selftest case ("a section-7 row backed only by look-alike prose") and the `cost_role_marker` helper to check 8, and neither reached this edition, while both copies still said "five" cost cases. The shared body was re-synced on 2026-09-26, so this edition now runs 33 cases and prints `skip  6 cost cases`, and 33 + 6 = 39, the Claude edition's count. Re-derive both numbers against the tree rather than trusting this page if either is restated.

## mermaid-gate

The rule exists because GitHub draws each ```` ```mermaid ```` block as a diagram and shows
*"Unable to render rich display"* where it does not parse. Until
`scripts/mermaid/check-mermaid.mjs` was ported from ai-workflows in dev-workflows 2.33.0,
nothing in this repository parsed mermaid: `check-docs.sh` check 15 extracts a diagram only to
test which skills appear in it. ai-workflows had shipped a workflow diagram that failed to
render across several releases — five unquoted edge labels carrying bracketed requirement IDs,
which mermaid reads as the start of a node shape — and a person found it by opening the page.
Every diagram in this tree parsed when the gate first ran here, so the port closed a blind spot
rather than a live break.

The gate finds diagrams with a real CommonMark lexer (`marked`), not a hand-rolled fence
scanner: ai-workflows' first version used one, and a release review found three kinds of diagram
GitHub draws that it never saw — inside a blockquote, on a list-marker line, and after a line
opening with a backtick code span. Each diagram is parsed with mermaid's own parser; both are
pinned by exact version and a committed lockfile, and installed with `--ignore-scripts`. It
reads tracked files only, which is what GitHub renders, and skips its own fixture tree,
`scripts/fixtures/mermaid/`. A failure is located by content, because mermaid numbers its errors
from text it has already rewritten. It parses and does not render, so a diagram that parses and
then fails at layout passes, and a mermaid fence inside a raw HTML block is outside it.
