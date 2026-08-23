# Copilot docs port — design

**Goal.** Give the Copilot edition of `dev-workflows` the same human-readable documentation tree the Claude editions got in 2.57.0 — grounded on *this* edition's code, not translated from theirs.

**Status.** Approved in chat 2026-08-23. Implementation not started.

---

## 1. Why this is not a copy

The Claude tree assumes a content model this edition does not have. The mapping:

| Canonical (Claude) | Copilot |
|---|---|
| `plugins/dev-workflows/` | `dev-workflows/` — no `plugins/` level |
| `commands/` — 21 `.md` | `skills/` — **20** `<name>/SKILL.md` + `_shared/` |
| `references/` — 98 files | `skills/_shared/` — 96 files, **plus 3 per-skill `references/` subdirs** |
| `agents/` — 34 | `agents/` — 34 ✅ identical |
| `hooks/` — 4 | `hooks/` — 4 ✅ identical |
| `.claude-plugin/marketplace.json` | `.github/plugin/marketplace.json` |
| `.claude-plugin/plugin.json` | `.plugin/plugin.json` |
| `CLAUDE.md` | `.github/copilot-instructions.md` |
| `/specify` | `specify:` — **760** slash refs across the 34 source pages |
| `claude plugin install …@ihudak-plugins` | `copilot plugin install …@ihudak-copilot-plugins`; update is `copilot plugin update --all` |

## 2. Capability divergences — the part that changes the page count

Verified against this edition's own files, not assumed.

**No cost subsystem.** `skills/_shared/specs-repo-git.md:54` states it outright: *"no cost subsystem — there is no `cost-emission.md`, no `emit-cost`"*. There is no `cost-emission.md` and no `cost-prices.yaml`. Consequences:
- `docs/reference/session-cost.md` **is not created.**
- `roles.md` carries **roles only**. Its Claude counterpart, `roles-and-phases.md`, has an entire second half of ten cost-attribution phases; none of that exists here, hence the shorter shipped name.
- All 20 skill pages open on role/phase in the Claude tree. Here they are **rewritten**, not translated.
- `DEV_WORKFLOWS_COST_PRICES` does not exist → **5** user-settable variables (`MODEL_ROUTING` and `PLUGIN_ROOT` are *not* among them: `MODEL_ROUTING` is assigned as a hook-local shell variable at `hooks/preload-context.sh:52`, the same shape as canonical's `ROOT`) (`VAULT_PATH`, `SPECS_PATH`, `REPOS_PATH`, `DOCS_PATH`, `GIT_USER_INITIALS`), not 6.

**No statusline skill.** `skills/statusline/` does not exist — the Claude command installs a Claude Code status line, and this edition has no equivalent surface. `docs/skills/statusline.md` **is not created** → 20 skill pages.

**Hooks DO run here.** Established by evidence, against an initial assumption they were vestigial: `hooks/hooks.json` uses `${PLUGIN_ROOT}` (not `${CLAUDE_PLUGIN_ROOT}`) and a `bash:` key (not `command:`), and carries a comment recording that *Copilot CLI does not support Claude Code's `matcher` field, so both `PostToolUse` scripts fire on every tool use*. That is a statement about a working hook system. `docs/reference/hooks.md` **is created**, and must state the no-matcher limitation, which the Claude page does not.

**These two omissions are deliberate.** A later reader must not "fix" them by porting the missing pages. That is why they are recorded here with their evidence.

## 3. Scope — 32 pages

- 4 orientation: `docs/README.md`, `getting-started.md`, `workflow.md`, `roles.md` (roles only)
- 20 skill pages under `docs/skills/` — one per `skills/<name>/`, `_shared` excluded
- 8 reference pages under `docs/reference/`: `agents.md`, `references.md`, `environment.md`, `hooks.md`, `model-routing.md`, `session-feedback.md`, `follow-ups.md`, `resume-and-checkpoints.md`

## 4. The gate

One `check-docs.sh`, **byte-identical across all three editions**, driven by a config block at the top. The body never diverges, so a future fix to the gate ports by plain `cp` — the failure mode being avoided is a constraint enforced in one edition only, which breaks there forever while the others refill it.

```
PLUGIN_REL   plugins/dev-workflows | dev-workflows
CMD_DIR      commands              | skills
CMD_SUFFIX   .md                   | /SKILL.md
CMD_EXCLUDE  (none)                | _shared
REF_DIR      references            | skills/_shared
DOC_CMD_DIR  commands              | skills
CLI          claude                | copilot
CLI_VERBS    marketplace add|marketplace update|install|reinstall | marketplace add|install|update  (no `reinstall` verb in this CLI; update takes `--all`)
RUNTIME_VARS CLAUDE_PLUGIN_ROOT …  | PLUGIN_ROOT MODEL_ROUTING ROOT OWNER_REPO OSTYPE BASH_*
HAS_COST     1                     | 0
```

`HAS_COST=0` makes **check 8** and **check 9's cost-emitting count** *inert and reported* — the run prints why they did not apply. It does not silently drop them: a gate that quietly runs fewer checks in one edition is indistinguishable from a gate that is broken there.

The config block is itself an **identity file**: it is the one part of the script that legitimately differs per edition, and it must never be copied between them.

## 5. Transformation rules

1. **Invocation form.** The 20 skill names convert `/<name>` → `<name>:`. **`/clear`, `/compact` and `/rename` stay slashes** — 61 occurrences; they are host commands, not plugin skills. A blind `sed` over `/[a-z-]+` corrupts all three.
2. **Doc-to-doc links** stay relative. `../../references/x.md` → `../../skills/_shared/x.md`.
3. **Runtime path references inside prose** follow this edition's convention: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/<file>`.
4. **Every claim is re-derived from this edition's files.** The Claude pages are a source of topics, never a source of facts — the same rule that governed the original restructure, and the reason it found six defects.

## 6. Identity files — never copied between editions

`README.md` (repo root and plugin), `CHANGELOG.md`, `LICENSE`, `.plugin/plugin.json`, `docs/getting-started.md`, and `check-docs.sh`'s config block. `getting-started.md` earns its place because it carries the install commands inline and check 7 pins them to the repo-root README — a straight copy from a Claude edition puts the wrong CLI and marketplace into this one. That is exactly what the gate caught on its first run during the mgd port.

## 7. Out of scope

- **`session-cost.md`, `statusline.md`** — §2, with evidence.
- **Retro-fitting the parameterised gate into canonical and mgd** — owed as one follow-up PR each. Until those land, three editions run two versions of the script, which is the state this design exists to end.
- **The two bugs found while scoping** — already fixed on their own branches: the layout spec that omitted `hooks/`, and the missing `superpowers` weak dependency.

## 8. Verification

The port is done when, in this edition: `check-docs.sh --selftest` passes; `check-docs.sh --root .` passes; `check-id-grammar.sh` passes both modes; `validate-catalog.py` passes; the spec-ID census matches its baseline; and the fixture tree exercises the Copilot config block rather than the Claude one — a fixture that only ever tests one edition's config leaves the other's untested.
