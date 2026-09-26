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
