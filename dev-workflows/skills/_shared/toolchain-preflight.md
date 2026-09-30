# Toolchain preflight (shared)

Single source of truth for verifying, before a run writes anything, that the tools its gates invoke
are actually present.

Consumed by `document:` (both modes) at Phase 0. Pairs with
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/gate-ledger.md` — the preflight decides whether to start; the ledger
records what actually happened.

---

## 1. Why this runs first

A `document:` run started in a container without `vale` and without `pnpm` still produces a branch, a
commit, and a PR draft. No linter ran and no server booted, so the documentation is worse — but the PR
exists and CI is green, and nothing signals that anything went wrong. The failure is silent, and it is
the run's own environment that caused it.

That is knowable at Phase 0 for the cost of one check per tool (§3). Without a preflight the run
discovers it one gate at a time, at Phase 6.4 and Phase 6.5, after the documentation is written.

## 2. Deriving the required set

Run this **after profile resolution** — the profile is what names the commands. Union three sources;
de-duplicate by binary name.

1. **The resolved profile.** Take the **tool** of every `commands.*` value (including every
   `commands.per_space.<space>.*` value) and every `dev_servers.servers[].command`. **A command's
   tool is its first whitespace-separated token that is neither part of a leading `cd <dir> &&` nor
   a leading `VAR=value` assignment**, set aside in whatever order they lead: `"pnpm dynatrace:lint"`
   ⇒ `pnpm`; `"cd website && pnpm docs:build"` ⇒ `pnpm`; `"NODE_ENV=production pnpm build"` ⇒ `pnpm`.
   The first token alone will not do: `cd` is a shell builtin, so `command -v cd` exits 0 on every
   host and every command it leads would read as runnable. This is the one definition of a
   command's tool; §3 says how each is tested. Add every entry in `profile.prerequisites` as a named
   prerequisite (these are prose, not binaries — record them for reporting, and check them only when
   the prose names a checkable path or binary).
2. **Repo config signals**, checked at `repo_root`, and, where a lockfile is implied by a leading
   `cd <dir> &&` in a profile command (source 1), also checked in that directory, taken relative to
   `repo_root` — that is where the command runs its tool. Where the caller resolved the site to a
   directory below `repo_root`, they are checked in that directory as well: `document:` Jira mode
   passes `docs_repo_resolved` (its Phase 0 step 2). A monorepo's site keeps its Vale configuration,
   lockfile and lint configuration beside itself, not at the top level, and a signal found in either
   directory implies its tool:

   | Signal file | Implies |
   |---|---|
   | a Vale configuration file — any of the five names below | `vale` |
   | `pnpm-lock.yaml` | `pnpm` |
   | `package-lock.json` | `npm` |
   | `yarn.lock` | `yarn` |
   | `.markdownlint.json` / `.markdownlint.jsonc` | `markdownlint` |
   | `.remarkrc*` | `remark` |

   **Vale reads its configuration from five file names, not one** — `.vale.ini`, `_vale.ini`,
   `vale.ini`, `.vale` and `_vale` — the first of them found, in that order, in the working directory
   or any directory above it, then in the home directory (Vale's own CLI docs, *Configuration*;
   `--config` and `VALE_CONFIG_PATH` each override this search outright). So the checks in this
   plugin that decide whether and on what Vale runs — this source, `docs-style-checker`'s first rung
   — look for all five: a site whose only one is `_vale.ini` is linted by Vale all the same, and a
   test for `.vale.ini` alone records that no repository linter is configured.

   **How this plugin runs Vale is defined here too, once: on the repository's configuration, with no
   global configuration file and no `VALE_CONFIG_PATH`, as a clean CI runner has neither.** Vale
   merges the user-level configuration file — found the same way, then in the OS's config directory
   — underneath the repository's, so a rule enabled or disabled only on the machine running the check
   changes what a lint reports, in either direction. `VALE_CONFIG_PATH`, where the environment sets
   it, replaces the repository's configuration outright, read **instead of** searching. `--no-global`
   omits the merged user-level file, but it also drops Vale's default `StylesPath` — Vale adds its
   default path only when `--no-global` is absent, and `VALE_STYLES_PATH` does not bring it back
   (measured against Vale 3.21.0's `internal/core/config.go` in ai-workflows `eb64c75b`) — so a repository
   configuration that sets no `StylesPath` of its own, and instead keeps its synced packages and
   custom styles in Vale's default location (a layout Vale documents as valid), fails with
   `E100 … style '<name>' does not exist on StylesPath` under `--no-global` alone, where a clean
   runner — which has no global file to begin with, and so loses nothing by lacking `--no-global` —
   lints cleanly. So every Vale run, from the directory holding the configuration it is to read, in
   one subshell in one Bash call, takes one of two forms, chosen by whether that file sets
   `StylesPath` (a `StylesPath` key above its first `[section]` header, the one place Vale accepts
   it):

   - **It sets one:** `(builtin cd "<that directory>" >/dev/null && unset VALE_CONFIG_PATH && command vale --no-global <arguments>)`.
   - **It sets none:** `(builtin cd "<that directory>" >/dev/null && unset VALE_CONFIG_PATH && h=$(command mktemp -d) && { XDG_CONFIG_HOME="$h" command vale <arguments>; s=$?; command rm -r -- "$h"; exit $s; })`,
     which hides the user-level file alone — Vale finds it under `XDG_CONFIG_HOME` on Linux and
     macOS — and leaves the default `StylesPath` (from `XDG_DATA_HOME`, or `VALE_STYLES_PATH` where
     set) untouched, so a configuration with no `StylesPath` of its own still finds what `vale sync`
     installed there.

   Both forms run `builtin cd` with its output discarded, and `vale`, `mktemp` and `rm` as `command <name>`.
   The Bash tool's shell carries the user's aliases and shell functions: a `cd` function that prints —
   RVM's and many prompt helpers do — puts its output ahead of Vale's, a `vale` alias adding `--no-exit`
   turns exit 1 into 0, and an `rm -i` alias leaves the temporary directory behind with its prompt in the
   output. It is `builtin` and not `command cd`, which zsh does not run (exit 127).

   The `cd` is there because Vale reads the first configuration it finds in the directory it runs in
   or one above it, never beside the files, and a Bash call starts in the session's directory, which
   need not be the repository's.

   Separately, when any lockfile is present, check `node_modules/` beside it as an
   **installed-dependencies** signal. A present `pnpm` with absent dependencies fails just as
   completely as a missing `pnpm`.
3. **The repo's documented prerequisites.** Grep `repo_root`'s `CONTRIBUTING.md`, `CONTRIBUTION.md`,
   and `README.md` for a heading matching `Prerequisites` (case-insensitive) and read that section.
   Best-effort: extract named tools and minimum versions where stated. Nothing found ⇒ contribute
   nothing. Never fail the preflight on an unparseable Prerequisites section.

**Direct mode has no profile.** `document:` Mode B resolves `repo_root` from **the edit target** — the directory it was given, or an `@file`'s directory — falling back to cwd only where the input names no path at all, and uses
sources **2 and 3 only**. It anchored on cwd unconditionally until a live run showed the consequence: invoked against one repository from inside another, the preflight read the repo it was standing in while the style check ran against the repo it was editing. Source 1 contributes nothing there. `document:` direct mode reads the same guidance files again in the same pass for `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/repo-verification-gates.md` §2 — do both in one read, not two.

## 3. Checking

- **Binaries: `command -v <binary>` — present when exit 0, run from the directory the tool's own
  command runs from** (`repo_root`, or the directory a leading `cd <dir> &&` names under it — §2
  source 1). **A bare `command -v <tool>` in the run's own shell is not proof the binary itself is
  installed**: it also reports an alias or a shell function of that name, which exits 0 there and
  can still exit 127 when the gate actually calls the tool as `command <name>` (as every Vale run in
  this plugin does, §2 source 2) — so a shadowed `vale` reads present here and fails there. Where a
  gate is known to call its tool that way, treat a `command -v` pass as provisional and let the gate
  itself report the failure rather than predicting a pass the alias cannot back. A path-valued tool
  (`node_modules/.bin/vitepress`) is tested with `test -x` on that path from the same directory,
  never from the session's own directory, which need not be the repository's — `command -v`
  resolves a name containing `/` against the directory it runs in, so asking from the wrong one
  reports a present tool missing.
- Directory signals (`node_modules/`): `test -d`.
- Never install anything. Never modify the repo. This step is read-only.

## 4. The `toolchain` block

```yaml
toolchain:
  - tool: <binary name, or a directory signal such as "node_modules">
    status: present | missing
    source: <profile.commands | profile.prerequisites | .vale.ini | pnpm-lock.yaml | CONTRIBUTING.md Prerequisites | …>
    required_by: [<gate ids from gate-ledger.md §4>]
```

`required_by` maps each tool onto the gates it powers, which is what lets the preflight state the
run's outcome before the run:

| Tool | Typically required by |
|---|---|
| the repo's prose linter (`vale`, `markdownlint`, `remark`) | `style_check` |
| the package manager (`pnpm` / `npm` / `yarn`) | `style_check`, `build_check`, `render_smoke_check` |
| `node_modules` present | every gate the package manager powers |
| `git` | `source_truth_verification` |

Derive `required_by` from where the tool came from: a binary that appears only in
`commands.per_space.<space>.build` powers `build_check`; one that appears in a `dev_servers` command
powers `render_smoke_check`. A tool with an empty `required_by` is reported but never blocks.

## 5. Reporting and the prompt

**When every required tool is present, say nothing beyond one line in the caller's readiness output.**
A preflight that prompts on a healthy container becomes one more thing to click through, and dies the
way the Phase 6.4 gate died.

When one or more required tools are **missing**, print the `toolchain` rows (missing first), then the
consequence — each affected gate and the outcome it will record: `DEGRADED` where the gate's
registered fallback (`gate-ledger.md` §4) still runs without the missing tool, and `UNAVAILABLE`
where neither the primary nor the fallback can (`gate-ledger.md` §2) — then ask:

```
choices: ["Cancel — re-run in the docs container (Recommended)", "Continue anyway — record the degraded gates", "Other… (describe)"]
```

Example consequence line:

> With `vale` and `pnpm` missing, this run would record `style_check` **DEGRADED** (only
> `dt-style-checker` runs; the repo's own linter would not),
> `build_check` **UNAVAILABLE** (its fallback, the dev-server boot, runs `pnpm` too), and
> `render_smoke_check` **DEGRADED** (no server boots, and every affected page goes to the manual
> pages-to-visit table, the fallback that needs no tool).

**`build_check`'s fallback is predicted per space, by the test `document:` Phase 6.5 Step 1 makes.**
A space's build whose own tool is missing keeps its fallback — and predicts `DEGRADED` — where the
tool of that same space's dev-server command is present, never on the strength of another space's
server, which compiles another space. A package manager whose `node_modules/` is missing counts as
missing, for a build and a server alike, so a never-installed dependency tree still predicts
`UNAVAILABLE`. A prediction made over every server's tool at once says `UNAVAILABLE` for a run that
then records `DEGRADED`, or the reverse.

- **"Cancel"** → stop the run. Nothing has been written.
- **"Continue anyway"** → for each gate named in the consequence line, **pre-seed** its ledger row's
  expected outcome and carry the user's choice verbatim, so that when the gate is reached its row
  records `SKIPPED_BY_USER` (or `DEGRADED` where a fallback does run) with `user_decision` already
  attributed. A pre-seeded row is still overwritten by what actually happens — a tool that turns out
  to work records `RAN`.

The preflight is itself a ledger gate: `toolchain_preflight`, phase 0, no fallback. Record its own row
(`RAN` when the check completed, whatever the findings; `FAILED` only if the check itself could not be
performed).

## 6. Location reporting

The caller has already resolved its target repo. The preflight does not re-resolve it — it reports
`repo_root`, and when `repo_root` differs from cwd it says so on its own line. **A divergence by
itself never prompts**: writing into `${DOCS_PATH:-/workspace/docs}` from a different working
directory is the normal AI-container case.

## 7. Hard rules

- NEVER install, upgrade, or configure a tool. Report and ask.
- NEVER modify any file under `repo_root`.
- NEVER prompt when every required tool is present.
- NEVER move the `(Recommended)` marker off "Cancel" in §5 — the "Choice lists are presented verbatim"
  rule in `escalation-rules.md` binds this prompt.
- NEVER fail the run because a `Prerequisites` section could not be parsed; source 3 is best-effort.
- NEVER treat a tool with an empty `required_by` as blocking.
