# Specs-repo git — Shared Reference

Single source of truth for the two git entry points the plugin runs against the
**specs repo** (`$SPECS_PATH`), and for `specs-root-check` (§8), which guards them. Every command that writes a bookkeeping artifact
there cites this file and executes its steps inline. The orchestrator owns any
printed output; this reference owns the gates, the bounded write authority, the
branch policy, and the failure discipline — the same shape as
`feedback-emission.md` and `followup-emission.md`.

**Purpose.** The per-VI `dev-workflows/` area exists so feedback,
follow-ups, and the resume pointer reach the **plugin maintainer**. They reach
the maintainer only if they are committed and pushed. The emitters deliberately
never commit — they run mid-run, often from inside someone else's repository,
and must never touch git. This reference supplies the two steps that close the
loop: a **run-start** flush and branch disposition (`specs-preflight`, §3) and a
**terminal** commit (`commit-artifacts`, §4). A third entry point, `specs-root-check` (§8),
refuses a `$SPECS_PATH` set inside the specs tree before a command looks up any folder
there, and §3.1 runs its tests at run start for every command.

**Scope.** ONLY the bounded artifact paths of §2.1, ONLY inside `$SPECS_PATH`. Nothing here ever touches a code repo, a docs repo, or the current working directory. The code repo a run just changed is finished by `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/code-repo-handoff.md` — a different repository, a different remote, and its own `Code repo:` outcome line. Neither entry point here opens a pull request: `specs-preflight` and `commit-artifacts` are prompt-free bookkeeping steps, and opening a pull request is outward-facing. Deliverable handoff — including `gh pr create` where the host supports it — lives in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2.6, behind that reference's consent choice. `git push` here is git-protocol, already sanctioned by `finish-and-handoff.md` §3.

## 1. Hard rules

1. **`git -C` always; `cd` never.** Every invocation is
   `git -C "$SPECS_PATH" …`. The working directory is NEVER changed. Most
   callers are running inside a *different* repository when these entry points
   fire; a `cd` would corrupt their git state.
2. **Bounded paths.** Only §2.1 paths are ever staged. `git add -A` is never
   issued at repository scope — always `git add -A -- <literal paths>`.
3. **Bounded branches.** Only branches matching `^(idea|vi|ard|spec|design|ready)/`
   are the plugin's to switch away from or delete (§2.2).
4. **Never destructive.** No `push --force`, no `push -f`, no `branch -D`, no
   `merge`, no `rebase`, no `reset`, and never delete an `index.lock`.
5. **Never fatal.** Every failure is reported and the run continues. The run
   never fails because of a git step here. §8's `specs-root-check` falls
   outside this rule: its stop is not a git step failing, but a deliberate
   refusal of a misplaced `$SPECS_PATH`, taken before any write.
6. **No `Co-Authored-By` trailer.** These are plugin-generated bookkeeping
   files, not authored content, and each artifact already carries its own
   `author:` field (`feedback-emission.md` §1).
7. **Prompt-free.** No entry point here asks the user anything. `specs-preflight`
   is silent unless it acts, a guard fires, or §3.1 reports a misconfigured
   `$SPECS_PATH`; `commit-artifacts` emits one outcome line (§6).

## 2. Bounded write authority

### 2.1 Paths

Exactly seven shapes: two directories derived from the emission ladders, the Jira import and the
Epic drafts a feature folder holds, and three files skills write for the operator. Nothing outside
this set is ever staged.

```
<specs-root>/{specs|specifications|vis|ideas}/**/dev-workflows/**              # tier 1: feedback, follow-ups, resume.md, release-notes archive copies
<specs-root>/dev-workflows-feedback/**                                         # feedback-emission.md §2 tier 2 (keyless runs)
<specs-root>/{specs|specifications|vis|ideas}/**/<KEY>-release-notes.md        # the release-notes: draft (that skill's Phase 8)
<specs-root>/{specs|specifications|vis|ideas}/**/jira-import/**                # a jira-workitem-import SPECS-mode import (jira-input-resolution.md)
<specs-root>/{specs|specifications|vis|ideas}/**/epic-drafts/**                # epics: drafts
<specs-root>/{specs|specifications|vis|ideas}/**/<KEY>-implementation-gaps.md  # source-truth.md §7.5 draft
<specs-root>/{specs|specifications|vis|ideas}/**/<KEY>-pr-draft.md             # finish-and-handoff.md pull-request draft
```

**The release-notes shape names a file, never its folder, and that distinction is the safety
property.** The draft sits in the VI's feature folder, beside the phase deliverables (the VI,
the ARD, `specification.md`, `design.md`, `idea.md`, `_readiness.md`), which are
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md`'s to commit behind its own consent choice. A shape widened to
the folder would sweep them into a prompt-free bookkeeping commit and take that choice away.
The file had to become a shape the day the draft moved into the folder: otherwise step 2
classifies it OTHER, step 3 never stages it, and it sits dirty for ever — firing §3.3's G1 on
every later preflight of every caller. Anything a run writes into the feature folder and
expects committed needs a shape here first.

**`jira-import/` and `epic-drafts/` are directory shapes, and that is safe for the reason the
release-notes shape is a file.** Neither directory ever holds a phase deliverable: `jira-import/` is
written only by `jira-workitem-import` and regenerated on every re-import, and `epic-drafts/` only
by `epics:`. A fresh import is therefore committed by the next run's `specs-preflight` flush,
prompt-free — the import is shared team state, not one machine's cache. **A screenshot `document:`
stages is not a shape**: it is a temporary copy kept until the operator uploads it, so `document:`
keeps it out of `git status` through the repository's local exclude file instead (its Phase 6 writer
step).

Sources: `feedback-emission.md` §2 tiers 1–2, `followup-emission.md` §2.1 (the shared per-VI area),
`session-hygiene.md` §1 (resume tier 1), `jira-input-resolution.md` (the import),
`skills/epics/SKILL.md` Phase 6 (drafts), `source-truth.md` §7.5 (gaps draft),
`finish-and-handoff.md` §5 (pull-request draft). This edition has **no cost subsystem** — there is
no `cost-emission.md`, no `emit-cost`, and no `dev-workflows-cost/` path shape.

**Staging is by enumeration, not by glob.** Pathspec glob magic (`:(glob)`) is
fragile to express and to review. The procedure is:

1. `git -C "$SPECS_PATH" status --porcelain -z --untracked-files=all`
   `--untracked-files=all` is **required** — the default collapses an untracked
   directory to a single `?? dir/` line, which would hide which files are being
   staged. `-z` is **required** too: without it git wraps any path carrying a
   space, a `"`, a `\` or a non-ASCII byte in double quotes and octal-escapes the
   non-ASCII bytes, and step 2's regexes are anchored at `^`, so the leading `"`
   alone puts such a path in OTHER. It is not a hypothetical shape: a feature
   folder is `<KEY>-<slug>` and `<slug>` is a kebab of a title, so a
   non-English title gives `specifications/PRODUCT-1234-zahlungsauslösung/`, under
   which every bookkeeping file this section owns was classified OTHER, never
   staged, and left permanently dirty — firing §3.3's G1 on every later preflight
   of every caller. Under `-z` each record is terminated by a NUL and the path is
   emitted raw: strip the two status bytes and the space and the remainder is the
   path. A **rename or copy** record carries a second NUL-terminated field, the
   original path, straight after it (`R  <new>\0<old>\0`) — consume it with the
   record it belongs to, never as a record of its own. `-c core.quotepath=false`
   is not a substitute: it suppresses only the octal escaping, and a path with a
   space is still quoted.
2. Classify each reported path: **ARTIFACT** if it matches
   `^(specs|specifications|vis|ideas)/.+/dev-workflows/` or `^dev-workflows-feedback/` or
   `^(specs|specifications|vis|ideas)/.+/[A-Z][A-Z0-9_]*-[0-9]+-release-notes\.md$` or
   `^(specs|specifications|vis|ideas)/.+/jira-import/` or
   `^(specs|specifications|vis|ideas)/.+/epic-drafts/` or
   `^(specs|specifications|vis|ideas)/.+/[A-Z][A-Z0-9_]*-[0-9]+-(implementation-gaps|pr-draft)\.md$`
   — exactly the seven §2.1 shapes, and a phase deliverable never matches; **OTHER**
   otherwise.
3. Stage the literal ARTIFACT paths only:
   `git -C "$SPECS_PATH" add -A -- <path> [<path>…]`.

`-A` is used deliberately: the user may delete a feedback or follow-up file
between runs, and that deletion must be staged. `-A` states that intent
explicitly, and it was strictly required before git 2.0, where `git add <path>`
did not stage a deletion. On git ≥ 2.0 a plain `git add -- <path>` stages a
deletion for a literal path too — verified empirically — so keep `-A` for
explicitness and for older git, but do not justify it by claiming plain
`git add` cannot stage the deletion.

### 2.2 Branches

**The plugin manages only branches it created.** A branch is plugin-owned when
its name matches `^(idea|vi|ard|spec|design|ready)/`.

Any other **named** branch — the user's own work, a hand-made branch — is left
alone and never switched away from (§3.3 G2). The run's artifacts are still
committed there, because a named branch cannot be lost.

A **detached HEAD** is not a branch. It is handled separately and far more
strictly (§3.3 G0, §3.7): nothing is committed at all.

## 3. `specs-preflight` — run start

Runs as early as `$SPECS_PATH` is known — Phase 0 in most commands. A run that §8's
`specs-root-check` stops before its preflight runs none. Prompt-free.
Silent when the repository is already clean and on the default branch and §3.1 finds
`$SPECS_PATH` well placed; it emits a block only when it acts or when a guard fires, and a
notice only where §3.1 reports a misconfigured `$SPECS_PATH`. That notice is one line, plus one more
line naming anything a misrooted run left behind. On a run carrying `specs_git: misrooted`, §3.5 adds
one line where it stays on a branch it would otherwise have left.

### 3.1 Gate

All of: `$SPECS_PATH` is set and is an existing directory;
`git -C "$SPECS_PATH" rev-parse --git-dir` succeeds; and the resolved `.git`
directory is **writable**. Test `.git` specifically, not just the worktree —
`commit` and `fetch` both write there, and a read-only specs mount is a normal
state in this container setup.

**A failed gate is not one disposition but two, and conflating them is what made a misconfiguration indistinguishable from a supported state.**

- **`$SPECS_PATH` is unset, or `.git` resolves but is not writable → silent no-op**, exactly as before. The artifacts are going to a report-only tier the plugin does not manage, and a read-only specs mount is a normal state in this container setup. Saying nothing is correct here: there is nothing for the operator to fix.
- **`$SPECS_PATH` is set to a path that is not a directory, or `rev-parse --git-dir` fails there → emit a notice**, one line naming the variable and the path, then continue. This is **never** a supported state: a set-but-not-a-repository `$SPECS_PATH` is a typo, a missing mount, or a path that was right in another container. Under the old blanket silence it looked identical to the read-only case, so a run would write its deliverables, commit nothing, open no pull request, and end on a terminal gate-failed line that named none of it — the operator's first clue being an empty specs tree some time later. **Where the path is a directory and §8's `specs-root-check` finds a signal there, the same line also says which one, and names the value to set and the clause §8's stop adds. Where that stop has a second line, naming what a misrooted run left behind, the notice adds that line too.** A `specifications/` directory mounted on its own fails `rev-parse` in exactly this way, because the repository's git directory sits above the mount point; a host `SPECS_PATH` naming `<repo>/specifications`, which a container mounts at `/workspace/specs`, is that state. A command that resolves no feature folder never reaches §8's stop; where this notice fires, it is how such a command learns the cause.

**A passing gate is tested once more, for a `$SPECS_PATH` set inside the specs tree.** On an ordinary checkout, `$SPECS_PATH=<repo>/specifications` meets all three conditions, because git finds the repository above it. A run that resolves no feature folder would then file its bookkeeping inside `specifications/` with nothing said. Examples are `upgrade:`, `vuln:`, `implement:` on a direct prompt, `document:` in direct mode, and the four logging commands (`feedback:`, `prompt:`, `prompt-brainstorm:`, `prompt-grill-me:`). So **where the gate passes, run the tests of §8 `specs-root-check`**, exactly as that section defines them, its exclusions included. Where a signal holds, emit a notice naming the variable, its value, which signal holds and the value to set, **set `specs_git: misrooted` for the whole run**, then continue. The notice is the stop's own text. It is one line, with the unsupported-layout clause where that applies, plus one more line naming anything a misrooted run left behind and where it belongs. Like the stop, it moves nothing and gives no commands. A run that resolves no feature folder learns all of it here, and only `commit-artifacts` repeats it, verbatim, at the end of the run (§4 step 1, §6). On an ordinary checkout, `$SPECS_PATH=<repo>/specifications` prints the prefix `specifications/`, which §8's first test catches whether or not an earlier run left a nested `specifications/` behind. **It stays quiet at a correct root.** A correct root's own key-bearing files, such as a `templates/` folder, a `README.md` or a `docs/` page, fail §8 (b)'s naming test, whether or not `specifications/` exists yet. A `$SPECS_PATH` like `<repo>/specs` holding `specs/specifications/` prints `specs/`, matches no signal, and draws the notice below instead. A specs repository nothing has been written into yet matches nothing. §8 records two unsupported layouts, each with its own reason. The specs root that is itself a subdirectory named `specifications` or `ideas` draws this notice on every run. The specs tree inside a larger repository draws the notice below.

**A `$SPECS_PATH` below its repository's top level.** `$SPECS_PATH` names the root of a dedicated specs repository, the directory that holds `specifications/`. **A specs tree inside a larger repository is unsupported**, because this plugin switches branches and commits in the repository `$SPECS_PATH` belongs to. On a correct root, §3.5 settles and switches its branch at run start, `commit-artifacts` (§4) commits on it, and `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md` §2 cuts a branch there and commits a deliverable. In a repository that also holds code, each of those would move the checkout of everything else that repository holds, so none of them switches or commits under the flag this notice sets. So where the gate passes and `git -C "$SPECS_PATH" rev-parse --show-prefix` prints a non-empty prefix, emit one notice line, **set `specs_git: misrooted` for the whole run**, then continue (§1). The line names the variable, its value and the repository's top level (`git -C "$SPECS_PATH" rev-parse --show-toplevel`), and says that a specs tree inside a larger repository is unsupported because the plugin switches branches and commits there. This is a misconfigured `$SPECS_PATH` in §1 rule 7's sense. **Skip it where the inside-tree notice above already fired this run.** That notice names the same path and what to set instead, and, where the value it names is below its repository's top level, that the layout is unsupported. **What a run that stops on `specs-root-check` prints depends on its order.** A command whose `specs-root-check` runs before its preflight (§8, *Who runs it*) stops there and runs no preflight, so it prints neither notice, only the stop. A command that runs `specs-preflight` first (`document:` does, ahead of its shared front-end) prints the inside-tree notice here and then stops at its resolution, so the operator sees the notice and then the stop, which name the same cause.

Still **never fatal** (§1): each notice reports and the run continues. **Where the path is a directory and `specs-root-check` finds a signal there, the non-repository notice above sets `specs_git: misrooted` too.**

**`specs_git: misrooted` is the run-wide record that `$SPECS_PATH` is misplaced.** It is set by either notice above, or by §8's stop where it ends the run. Under it, every emitter of the tail falls to its report-only tier, so the tail writes nothing under a path the run has found wrong. That covers feedback (`feedback-emission.md` §2), follow-ups (`followup-emission.md` §2) and `resume.md` (`session-hygiene.md` §1). Writing there would only add files §2.1's classifier puts in OTHER, or artifact paths that cannot be staged from `$SPECS_PATH` and that the first run after the variable is fixed would commit in the wrong place: and G1 fires on every run after the variable is corrected.

**The preflight itself performs no write under the flag**: no leftover flush, no push retry, no branch switch, creation or deletion, no pull, no commit and no push. Where the gate passed, it still reads, because `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/phase-handoff.md`'s `require-on-main` runs on what it reads. §3.2 runs in full, its best-effort fetch included, which refreshes the remote-tracking refs every `<default-ref>` test reads and moves no checkout. §3.5 classifies the branch, and a row that would switch stays and reports instead. §3.3's guards and §3.4's flush do not run, and each section says why. §4's `commit-artifacts` skips, as it does on `specs_git: blocked`. `phase-handoff.md` §2.1's `handoff-to-main` refuses the handoff, its §4.3 says so above the consent array, and its row C offers no repair. **So none of `specs-preflight`, `commit-artifacts`, `handoff-to-main` and `require-on-main` switches a branch or commits under the flag.** That bound is those four entry points', not the run's. A command that changes code still cuts its own branch and commits on it in the code repository it changed (`code-repo-handoff.md`), and `document:` does the same in its docs repository. Where the specs tree sits inside that same repository, that branch moves the specs checkout too, which is one reason that layout is unsupported.

**What the flag leaves alone is what the command itself writes.** A run a notice let continue still writes its deliverable where the command puts it, and any of §2.1's operator files it writes beside it: the `<KEY>-release-notes.md` draft, `<KEY>-pr-draft.md` or `<KEY>-implementation-gaps.md`. They stay there, written and uncommitted, for the operator to move or commit once `$SPECS_PATH` is right. A run stopped by §8 writes nothing under the path at all. What changes is that the condition is now *said*.

### 3.2 Resolution inputs

**Default branch:** `git -C "$SPECS_PATH" symbolic-ref --quiet refs/remotes/origin/HEAD`,
then strip the `refs/remotes/origin/` prefix. It counts only where
`git -C "$SPECS_PATH" rev-parse --verify --quiet origin/<name> >/dev/null` succeeds for the name it
yields: a remote that renamed its default branch, fetched with `--prune`, leaves `origin/HEAD`
naming a branch the remote deleted, and every test below would then name a ref that does not
exist. If unset, or naming a ref that does not exist, fall back to `main`,
then `master`, then the current branch — in which case no branch switching
occurs at all.

**Default ref — which ref *represents* that branch.** The name above is a branch name; every ancestry and presence test needs a ref. Probe `git -C "$SPECS_PATH" remote get-url origin`: exit 0 with a non-empty URL → `<default-ref>` is `origin/<default>`; anything else → `<default-ref>` is the local `refs/heads/<default>`.

**The two cases are not one weakened into the other.** With a remote configured, its tracking ref is the only trustworthy record of what merged — the local branch can be stale or ahead, so testing against it would assert something the shared history does not support. With **no remote at all** there is no remote state to be uncertain about: the local default branch *is* the default branch, and testing against it is the correct application of the check rather than a relaxation of it. The producer side works the same way — `phase-handoff.md` §2.1's push-target probe runs before the consent choice and is never gated on, and a repository with no `origin` is deliberately not a gate failure there — and this makes the consumer side agree. **Every test below, and `phase-handoff.md` §3's, uses `<default-ref>`; none names `origin/<default>` literally.**

**Freshness:** best-effort `git -C "$SPECS_PATH" fetch origin <default>` before
the ancestry test, skipped entirely when there is no remote. On failure (offline, auth), use the existing local
`<default-ref>` and note `offline — ancestry checked against the
last-fetched ref`. Never fatal.

**Run key set:** every Jira key the run is scoped to, taking each key already
resolved at the call site. A VI-scoped run contributes its VI key. A run invoked
as `<VI> <Epic>` (`create-ard:`, `specify:`, `design:`, `ready:`) contributes
**both** — the Epic is as much this run's key as the VI is, and §3.5 must
recognise a branch named for either (§3.6). When no key is resolved at the call
site the set is empty and the run is **keyless**. Both are correct behaviour —
no command needs to defer its preflight in order to obtain a key. `create-vi:`
is structurally keyless here (its key is minted by the Jira round-trip in a
later phase), and keyless is the right classification for it: a new VI must not
stack on another VI's branch.

**This run key set is the preflight's, and only the preflight's.** It exists to
match branches in §3.5 and is resolved at the *start* of the run.
`commit-artifacts` resolves its own key independently — a single key, at the
*end* of the run (§4 step 4) — by which point a command that started keyless may
well have one. A run that is keyless here is not thereby committing under
`NOISSUE`.

### 3.3 Stage 1 — guards

Not run on a run carrying `specs_git: misrooted` (§3.1). Each guard's notice tells the operator what this run's `commit-artifacts` will or will not commit, and under that flag it commits nothing, whatever a guard would find; §3.1's notice has already said why. A detached HEAD is still caught: `commit-artifacts` and `handoff-to-main` refuse on the flag, and `phase-handoff.md` §3.3 row I tests the state itself. The preflight goes on from §3.2 to §3.5's classification, skipping §3.4 too.

**Any match ends the preflight; the run proceeds.** Every guard emits the §5
notice, never a quiet line.

| # | State | Action |
|---|---|---|
| G0 | **HEAD is detached** | **Hand off, and set `specs_git: blocked` for the whole run** — `commit-artifacts` (§4) must also skip. §5 notice at **blocking** severity. See §3.7. |
| G1 | Any dirty **OTHER** path (§2.1) | **Hand off** — no commit, no branch switch, no push. §5 notice at **advisory** severity, listing the paths. Those files are not the plugin's, and switching branches would carry them. **This does NOT set `specs_git: blocked`**: the terminal `commit-artifacts` still runs, because it stages only artifact paths and is safe beside unrelated dirt. Losing the artifacts to protect files the step never touches would be the worse failure. |
| G2 | On a **named** branch that is neither the default branch nor a match for `^(idea\|vi\|ard\|spec\|design\|ready)/` | **Leave it; stay on it.** §5 notice at **advisory** severity, naming the branch, so the user knows where this run's artifacts will land. The commit is safe — a named branch cannot be lost — so `commit-artifacts` proceeds. The plugin manages only branches it created (§2.2). |

### 3.4 Stage 2 — flush leftovers

Always runs when stage 1 matched nothing **and the run does not carry `specs_git: misrooted`** (§3.1). Under that flag it does not run at all, so there is no flush and no push retry, and the preflight goes on to §3.5, which switches nothing under the flag. A flush there would `git add` paths that porcelain prints relative to the repository's top level and that do not exist from `$SPECS_PATH`, which fails with exit 128 on every run. Where `$SPECS_PATH` is a correct root holding a stray folder, it would commit and push while the notice says the run wrote nothing.

- **Dirty ARTIFACT paths exist** → commit them **onto the current branch** (they
  belong to the run that wrote them) and push, per §4 steps 2–6.
- **No dirty ARTIFACT path** → check whether the current branch is **ahead of
  the branch it would push to** and every ahead-commit touches only §2.1 artifact
  paths. If so, **retry the push**.

  **Do not phrase that test as `@{u}`.** A failed `push -u` sets no upstream, so
  `git rev-parse --abbrev-ref '@{u}'` and `git rev-list --count '@{u}..HEAD'` both
  exit 128 with `fatal: no upstream configured` — the condition is not false but
  *unevaluable*, and precisely in the state the retry exists for. Resolve the
  comparison base instead: the upstream where one is configured, else
  `refs/remotes/origin/<branch>` where that ref exists, else — a local-only branch
  a failed `push -u` leaves behind — treat the branch as **entirely ahead** and
  retry the push, which is the case that strands an artifact commit with nothing
  to retry it. Without this, a push that failed in a previous run leaves
  a local commit that nothing ever retries — the original defect, re-created one
  layer up.

Either way, continue to stage 3 with a clean tree.

### 3.5 Stage 3 — branch disposition

First matching row applies.

| # | State | Action |
|---|---|---|
| B1 | On the default branch | Nothing further. |
| B2 | Plugin branch, and `git -C "$SPECS_PATH" merge-base --is-ancestor HEAD <default-ref>` succeeds (already merged upstream) | Switch to default, `git -C "$SPECS_PATH" pull --ff-only`, `git -C "$SPECS_PATH" branch -d <branch>`. If `-d` fails, report and skip — **never `-D`**. If `pull --ff-only` fails (the local default branch has diverged), report and continue on default **without** pulling — never merge, rebase, or reset. |
| B3 | Plugin branch, unmerged, branch key matches **any** key in the run key set (§3.2) | **Stay on it.** See §3.6. |
| B4 | Plugin branch, unmerged, branch key matches **no** key in the set, or the set is empty (keyless run) | Switch to default, `git -C "$SPECS_PATH" pull --ff-only`. **Leave the branch and its pull request alone.** Report the branch name. |

**Under `specs_git: misrooted` (§3.1) the table classifies and moves nothing.** Take the first matching row exactly as above: §3.2's fetch has already refreshed `<default-ref>` for B2's ancestry test, and the branch key extraction below resolves B3 and B4 unchanged. Then act on that row without writing. B1 and B3 stay where they are, as they always do. B2 and B4 stay too, with no `switch`, no `pull --ff-only` and no `branch -d`. Each prints one line in place of its action: `Specs preflight: staying on <branch> — specs_git: misrooted, so no branch is switched (it would have <switched to <default> and deleted it, as it is merged | switched to <default>, as no key of this run names it>)`. A B3 here keeps the checkout on the caller's own branch exactly as it does on a correct `$SPECS_PATH`, so `phase-handoff.md` §3.3 row B still passes a resumed run. Where HEAD is on no plugin branch, no row applies here, as always.

**Branch key extraction:** strip the `idea/`, `vi/`, `ard/`, `spec/`, `design/`,
or `ready/` prefix, then take the leading token matching
`[A-Z][A-Z0-9_]*-[0-9]+`. No match → treat as matching no key in the set (B4).

**No auto-merge, deliberately.** No row above creates a merge commit or merges a
branch into the default branch, and none should be added. The routing here
already resolves every case, and an auto-merge would push an unreviewed VI or
ARD past the very pull request the command opened for it one phase earlier. B2
handles the only case where a merge would otherwise be needed — a branch already
merged upstream — with cleanup instead. If auto-merge is ever wanted, it slots
into B4 as `merge --ff-only → push → branch -d`, with B3 unchanged.

### 3.6 Why B3 exists — do not "simplify" it away

B3 looks redundant next to B4 and is the obvious candidate for a future simplification into "always return to the default branch." **That simplification is a bug.**

B3 now exists for two reasons.

**First, same-phase resume.** `phase-handoff.md`'s `require-on-main` (§3) has a state — row B — that *passes* when the artifact is on the default branch but the worktree copy differs because the current branch is one this run itself owns: `design:` amends `specification.md` on its own `design/<EPIC>-<eslug>` branch, so a re-run of `design:` legitimately finds that copy has diverged from what merged earlier. B3 is what keeps the repo on that branch in the first place, and that is what makes row B reachable at all. If the preflight instead fell through to B4 and switched to the default branch, `design:`'s in-progress amendments would be left behind on a branch nobody is standing on, and row B — built to pass on exactly this divergence — would never see the case it exists for.

**Second, `ready:`'s explicit checkout.** The user may choose to proceed on the current checkout rather than switch to the default branch. Switching off it mid-run while the readiness report still claims that checkout is the one that was read would make the report false.

**The same shape reaches Epic-scoped runs — which is why §3.2 resolves a key *set*, not a single key.** `specify: <VI> <Epic>` authors `specification.md` on `spec/<EPIC>-<eslug>`, a branch keyed by the **Epic**. The follow-up `design: <VI> <Epic>` run resolves the VI as its primary key, so a single-key comparison would read branch key ≠ run key, fall through to B4, and switch away from the branch holding the very `specification.md` `design:`'s resume depends on — the same reachability loss described above, one key earlier in the chain. Matching the branch key against **any** key in the set keeps B3 in force for the `<VI> <Epic>` invocations (`create-ard:`, `specify:`, `design:`, `ready:`) exactly as it holds for VI-scoped ones.

The failure this section used to defend against — `create-ard:` continuing silently against the wrong source when the authored VI file existed only on an unmerged branch — is now caught loudly instead: `phase-handoff.md` §3.3 rows D and E stop that run rather than letting it proceed, so the defense moved there.

B3 keeps the working tree containing the artifact the run is about to read or amend. The cost is that the follow-up command's own branch is cut from the earlier branch rather than from the default — a stacked branch. That is correct: an ARD genuinely depends on its VI and a design on its spec, and stacking is the honest representation.

### 3.7 Detached HEAD is blocking, not merely skipped

G0 is the one guard that refuses to commit, and it is a data-loss guard
rather than a courtesy. (`specs_git: misrooted`, §3.1, also stops `commit-artifacts`
and `phase-handoff.md`'s deliverable commit, but it is set by §3.1's notices or §8's
stop, not by a guard.)

A commit made on a detached HEAD is reachable from no ref. Nothing points at it,
`git branch` will not list it, and it is eligible for garbage collection. If
`commit-artifacts` committed there, the run would report a short SHA and a
success line while the artifacts were already on their way to being
unrecoverable — the worst possible failure shape, because it looks like success.

So G0 propagates: it sets `specs_git: blocked` for the whole run,
`commit-artifacts` gates on that flag (§4 step 1), and the §5 notice fires at
**blocking** severity at both ends of the run. The artifacts stay in the working
tree, uncommitted and intact, and the notice gives the exact command to attach
them to a branch.

**Of the three guards, this is the only one that disables the terminal commit** — `commit-artifacts` step 1's gate also no-ops silently where §3.1's environment conditions fail on a run carrying neither flag, and skips with a notice on a run carrying `specs_git: misrooted`, so *the only condition* full stop, which this sentence used to claim, is wider than the guards it is about. In particular
G1 does not — see the note in its row.

## 4. `commit-artifacts` — terminal step

Runs as the **last action of the run**, after `resume.md` is written (where the
command writes one) and before or as the run's last printed output (§6).

**The one exception — a phase that cedes control.** Where a later phase hands the
session to another skill, or opens an open-ended interactive stretch, this step
runs immediately **before** that hand-off instead, and prints its §6 outcome line
there. `prompt-brainstorm:` (whose Phase 3 hands off to the brainstorming skill)
and `prompt-grill-me:` (whose Phase 3 is a long interactive grill) are the cases.
"Last" is protective only while the run still reaches its own end: a commit
placed after control has left the command never executes, and the artifacts it
was meant to persist are stranded uncommitted — the exact loss this reference
exists to prevent. The exception is deliberately narrow. It applies where control
genuinely leaves the command, never as a convenience to commit early, and it
never licenses splitting the step across more than one invocation.

**A run that refuses before it has written anything still runs this tail, and
each member settles for itself what it does there.** A Phase 0 refusal — an
unresolvable key, a missing argument, an input the skill cannot use —
ordinarily ends the run before it has a deliverable, a branch or a handoff (the
exception is named below), and nothing above said whether feedback, follow-ups
and `resume.md` still fire. The answer is each member's own rather than a new
condition here:

- **Feedback writes nothing.** `feedback-emission.md`'s `emit-auto` is called
  by a skill's maintenance phase, which a refused run never reaches, and
  `emit-block` fires at the halt rather than here and excludes an environment
  or operator halt by its own predicate — which every Phase 0 refusal is.

- **Follow-ups are a no-op.** No signal qualifies, so that phase resolves no
  target, writes nothing and ends silently (`followup-emission.md` §4).

- **`resume.md` is NOT written.** `session-hygiene.md` §1 defines it as the
  last *completed* position — the phase just finished and the exact next
  skill from the run's own `### Next step` — and a Phase 0 refusal completed
  no phase and printed no such block. It is overwritten rather than appended,
  so writing one here would replace a live pointer to a real position with a
  run that did nothing, and what it replaced cannot be recovered.

- **This step runs, and ordinarily finds nothing new to stage.** This edition
  has no cost entry, so no member above writes on a refusal. Where the refusal
  was §8's stop, the run carries `specs_git: misrooted`, and step 1's gate skips
  the step with the stop repeated. Where the refusal
  came before `$SPECS_PATH` was resolved, step 1's gate no-ops it silently;
  where nothing is dirty, step 3's `nothing to commit` line stands; and where
  an earlier run left artifacts behind, it commits them exactly as any run
  would.

**It is scoped to a refusal taken before the run has a deliverable, a branch or
a handoff**, which is what most Phase 0 stops are, never all: a Phase 0 stop
taken after the run cut a branch is outside it — `document:` in Jira mode is
one, its Phase 0 having cut a docs-repository branch and committed the generated
profile on it wherever it profiled that repository inline, before its later
Phase 0 stops. Such a run, like one that stops in a later phase, has written
something, and what its tail does is that skill's to state.

1. **Gate.** All of §3.1's environment conditions, **plus** the run must not
   carry `specs_git: blocked` from §3.3 G0 or `specs_git: misrooted` from §3.1.
   **Test the two flags first, and a flag's outcome below takes precedence
   over an environment failure**, so each state has one outcome.
   `specs_git: misrooted` is often set where an environment condition fails
   too: §3.1's non-repository notice sets it where `specs-root-check` finds a
   signal, as on a `specifications/` directory bind-mounted on its own, and
   §8's stop sets it on a path no `rev-parse` reaches. Such a
   run takes the misrooted outcome, never the silent one. `specs_git: blocked`
   is set only behind a passing gate (§3.3 G0), so it never meets one.
   - Carries `specs_git: blocked` → **not silent**: re-emit the §5 blocking
     notice. The repo *is* managed; the plugin is deliberately refusing to
     commit, and the user must know.
   - Carries `specs_git: misrooted` → **not silent**: re-emit the §3.1 notice,
     or §8's stop, that set it, whether or not §3.1's
     environment conditions hold. Nothing is committed, and the tail's
     emitters wrote nothing under `$SPECS_PATH` (§3.1). What the command
     itself wrote there — a noticed run's deliverable, or one of §2.1's operator
     files such as `<KEY>-pr-draft.md` — stays written and uncommitted, and
     what was already there sits where this run found it wrong.
   - Carries neither, and fails on path / repo / permission grounds →
     **silent no-op**, matching the emission ladders' silent-skip discipline.
     Nothing committed, nothing reported, run unaffected.
2. **Enumerate and stage** per §2.1. OTHER paths are never staged.
3. **Nothing staged** (the gate passed but no artifact path is dirty) → no
   commit; emit the §6 `nothing to commit` outcome line. This is distinct from
   step 1's silence — here the specs repo *is* managed and simply had nothing
   new.
4. **Commit.** Message:
   `<KEY> Add dev-workflows session artifacts (<command>)` — e.g.
   `PRODUCT-13950 Add dev-workflows session artifacts (create-vi:)` — or
   `NOISSUE Add dev-workflows session artifacts (<command>)` when the run
   resolved no key. This matches the
   specs repo's own `<KEY|NOISSUE> <summary>` convention. **No
   `Co-Authored-By` trailer** (§1 rule 6).
5. **Push** to the current branch's upstream. If the branch has no upstream:
   `git -C "$SPECS_PATH" push -u origin <branch>`.
6. **Failure at any step is reported, never fatal.**
   - No remote / auth failure → report; the commit stays local. §3.4 retries the
     push on the next run.
   - **Non-fast-forward rejection** → report; **never force-push**, never
     auto-rebase mid-run. The commit stays local; §3.4 retries.
   - **`index.lock` present** (a concurrent session holds the repo) → report and
     skip; **never delete a lock file**. The artifacts stay in the working tree
     and the next run's preflight flushes them.
7. **Emit the §6 outcome line**, plus the full §5 notice repeated verbatim when
   a guard fired at §3.3.

### 4.1 Where the commit lands

- **A command that opened a specs-repo branch at handoff** (`idea:`, `create-vi:`, `update-vi:`, `create-ard:`, `specify:`, `design:`, `implement:`, `ready:`) — on that `idea|vi|ard|spec|design|ready/*` branch, so the push updates the pull request already open. Two commits on one branch: the deliverable, then the artifacts.
- **The same command when the user declined git at handoff** ("just write the
  files — I'll handle git") — the repo is still on the default branch and the
  deliverable is uncommitted there. `commit-artifacts` still runs and commits
  **only** the bookkeeping paths; the uncommitted deliverable is untouched,
  because it is an OTHER path. This is deliberate: "I'll handle git" refers to
  the deliverable, and the bookkeeping still has to reach the maintainer. The
  outcome line states plainly that the deliverable remains uncommitted.
- **Every other command** — on the default branch, unless §3.3 G2 left the run
  on a branch the plugin does not manage, or §3.5 B3 kept it on a plugin branch
  keyed to this run. The commit follows the branch the preflight settled on; it
  never switches.

## 5. Notice contract — the guards must be impossible to overlook

A guard fires precisely when the plugin has decided **not** to do something the
user is relying on. A single dim line in a long run is how that becomes a silent
loss, so every guard emits a structured block rather than a sentence, at both
the point of detection and again in the run's last printed output.

Every notice carries four parts, in this order:

1. **What was found** — the concrete state, with the branch name, the file
   count, or the path list. Never "an issue was detected".
2. **What the plugin did NOT do** — stated as the consequence for the user's
   data.
3. **The exact commands to resolve it**, ready to paste, with `$SPECS_PATH`
   already substituted.
4. **What happens if it is ignored** — one clause.

Severities: **blocking** (G0 — the terminal commit will not run) and **advisory**
(G1, G2 — the commit still runs, but somewhere the user should know about). Both
use the same four-part shape; only the wording of part 2 differs.

The `Specs repo:` emission (§6) **repeats the notice in full** when a guard
fired. A notice printed only at Phase 0 of a long run is a notice the user has
scrolled past by the time the run ends.

**G0 — blocking:**

```
⚠ SPECS REPO — THIS RUN'S ARTIFACTS WILL NOT BE COMMITTED

Found:    <SPECS_PATH> is on a detached HEAD (<sha7>), not on a branch.
Not done: this run's feedback, follow-ups, and resume pointer will NOT be
          committed and will NOT reach the plugin maintainer. A commit made here
          would be reachable from no branch and eligible for deletion by git's
          garbage collector, so the plugin refuses to make one.
Fix:      git -C "<SPECS_PATH>" switch -c rescue/<YYYY-MM-DD>
          # or, to rejoin an existing branch:
          git -C "<SPECS_PATH>" switch <branch>
If ignored: the artifacts stay in your working tree, uncommitted and intact; the
          next run's preflight picks them up once HEAD is on a branch.
```

**G1 — advisory:**

```
⚠ SPECS REPO — UNCOMMITTED FILES THAT ARE NOT THE PLUGIN'S

Found:    <SPECS_PATH> has <N> uncommitted change(s) outside the plugin's
          artifact area: <path list>
Not done: the preflight did not commit, switch branches, or push. Those files
          are yours, and switching branches would carry them along. This run's
          own artifacts WILL still be committed at the end of the run —
          commit-artifacts stages only the §2.1 artifact paths.
Fix:      git -C "<SPECS_PATH>" status
          git -C "<SPECS_PATH>" add <path list> && git -C "<SPECS_PATH>" commit
If ignored: nothing is lost — your files stay uncommitted, and this run's
          artifacts are committed alongside them. But the preflight ends here
          on EVERY later run too, so the leftover flush and the branch
          settle (stages 2-3) stay skipped until these paths are committed
          or removed.
```

**G2 — advisory:**

```
⚠ SPECS REPO — ON A BRANCH THIS PLUGIN DID NOT CREATE

Found:    <SPECS_PATH> is on branch `<branch>`, which is neither the default
          branch (`<default>`) nor a plugin branch (idea/ vi/ ard/ spec/
          design/ ready/).
Not done: the preflight did not switch away from it — the plugin manages only
          branches it created. This run's artifacts WILL be committed, on
          `<branch>`.
Fix:      # only if that is the wrong place for them:
          git -C "<SPECS_PATH>" switch <default>
If ignored: the artifacts land on `<branch>` and reach the maintainer when that
          branch is merged or pushed.
```

## 6. The outcome line

`commit-artifacts` step 7 emits exactly one of these, prefixed `Specs repo:`.
The caller places it per its own contract (§7) — inside its final report where
the report is the run's last output, or as its own terminal block where the
report was composed earlier.

| Case | Line |
|---|---|
| Committed and pushed | `Specs repo: committed <sha7> (<N> files) on <branch> — pushed` |
| Committed, push failed | `Specs repo: committed <sha7> (<N> files) on <branch> — push FAILED (<reason>); the commit is local and the next run retries it` |
| Nothing to commit | `Specs repo: no session artifacts to commit` |
| Locked | `Specs repo: skipped — another session holds the repo (index.lock); the next run picks the artifacts up` |
| Blocked (G0) | `Specs repo: NOT COMMITTED — see the notice below`, followed by the §5 G0 block verbatim |
| Misrooted (§3.1), whether or not the environment conditions hold | `Specs repo: NOT COMMITTED — SPECS_PATH is misplaced; see the notice below`, followed by the §3.1 notice, or §8's stop, verbatim |
| Gate failed on environment, on a run carrying neither flag | *(no line at all — silent no-op)* |

When a guard fired at §3.3 G1 or G2, the outcome line is followed by that
guard's §5 block, repeated verbatim.

When the deliverable is still uncommitted because the user declined git at
handoff (§4.1), append to the line:
`; the deliverable at <path> remains uncommitted, as you asked`.

## 7. Caller contract

A command that writes anything into `$SPECS_PATH` must do all four of these.
Omitting any one of them is a defect, not a style choice.

1. **Cite and execute `specs-preflight` (§3)** as early as `$SPECS_PATH` is
   known — Phase 0 in most commands; a run §8 stops before it runs none. Carry
   any returned `specs_git: blocked` or `specs_git: misrooted` flag for the
   whole run, and `specs_git: misrooted` from §8's stop where it ended the run
   before any preflight.
2. **Cite and execute `commit-artifacts` (§4)** as the last action of the run,
   after `resume.md` (where one is written) and after the terminal feedback and
   follow-up steps — or, where a later phase cedes control to another skill or to
   an open-ended interactive stretch, immediately before that hand-off (§4's
   exception).
3. **Emit the §6 outcome line exactly once**, wherever `commit-artifacts`
   ran — at the end of the run, or immediately before the hand-off in the
   cede-control case above.
4. **Never restate this reference's rules** — cite the section number. A rule
   copied into a command is a rule that goes stale.

**And one more, for a command that looks up or creates a feature folder under `$SPECS_PATH`:**
it runs §8's `specs-root-check` before its first lookup, and stops on any signal. §8 says where each
such command runs it.

## 8. `specs-root-check` — a `$SPECS_PATH` set inside the tree

**Refuse a `$SPECS_PATH` that points inside the tree.** Every feature folder this plugin reads or
creates is an immediate child of one of `$SPECS_PATH`'s specs directories — `specifications/`,
`ideas/`, and the older `specs/` and `vis/` (`<spec-dirs>`, `jira-input-resolution.md` § JiraID
token) — or an Epic subfolder of one. A `$SPECS_PATH` set to `specifications/` itself, to a mount of
it, or to a folder inside it therefore finds no feature folder for any key. A command that creates the
folder it did not find would then create `<that path>/specifications/<KEY>-<slug>/` inside the tree,
and once one has, later runs find folders only in that nested tree.

**Why the checks that already exist are not enough.** `jira-input-resolution.md` § JiraID token step 1
and `idea:` Phase 0 step 1 refuse a `$SPECS_PATH` holding none of the four specs directories, which a
`$SPECS_PATH` set to `specifications/` is. That refusal names the wrong cause ("the importer needs a
`specifications/` directory there") and offers a per-run "enter the path" override, which leaves the
environment wrong for the next run and for every command that resolves no feature folder. It is not
reached by a directory token, by `create-vi:` or by `update-vi:`, each of which creates or resolves
`$SPECS_PATH/specifications/<KEY>-<slug>/` on a `$SPECS_PATH` that is merely set. And once any of
those has created a nested `specifications/`, it passes, and every later run reads the nested tree.

**Who runs it, and when.** It runs only where `$SPECS_PATH` is set, and always before the caller's
first folder lookup:
- **`jira-input-resolution.md`** runs it first in its `## Resolution`, before either jira-driven
  branch, on a JiraID token and on a directory token alike. That covers every command that takes its
  input through that front-end: `create-ard:`, `design:`, `document:` in Jira mode, `epics:`,
  `implement:`, `ready:`, `release-notes:` and `specify:`. A run whose input resolves `direct` (no
  Jira input) runs none here.
- **`idea:`** runs it at Phase 0 step 1, before it validates `$SPECS_PATH`'s specs directories.
- **`create-vi:`** runs it at Phase 0 step 1a, before step 2a's `--from-vi` lookup and every later
  one.
- **`update-vi:`** runs it at Phase 0 step 2.

**A path entered at a `Set SPECS_PATH (enter the path)` option** — `jira-input-resolution.md`'s
Fallback A, or a command's own unset-`SPECS_PATH` stop — becomes the run's `$SPECS_PATH`, and is
tested the same way before the caller's first use of it; a signal is the same hard stop. Each of those
prompts says so.

A run that resolves no feature folder never meets the stop below. It learns the cause from §3.1's
notice, which runs these same tests.

**Why a directory token is tested too.** A set-but-misrooted variable is a misconfiguration on every
run, whichever form the operator typed. A directory-token run that passed Phase 0 untested would meet
the same misroot later, after its expensive work: at `ard-resolution.md`'s VI-folder match, which
finds nothing and returns `none`, so the caller goes on without the ARD it should have enforced, or at
a command's own `$SPECS_PATH/specifications/<KEY>-<slug>/`, which it then creates in the wrong place.

**What it tests, and where.** Two signals are tested, (a) by either of two tests, each against the
filesystem and none by parsing a name:

- **(a) `$SPECS_PATH` is, or is inside, a `specifications/` or `ideas/` directory.** Either of two
  tests shows it:
  - **`git -C "$SPECS_PATH" rev-parse --show-prefix` prints a prefix whose first segment is
    `specifications/` or `ideas/`**, i.e. it is one of those directories directly under a git work
    tree's top level, or any directory inside one, a folder of any name included. **This test runs
    whether or not `$SPECS_PATH/specifications/` exists.** One that does is the damage a run made
    before this check existed, which created its folders at `specifications/specifications/`. A
    precondition that skipped it would keep the plugin reading the nested tree forever, and the
    users it would skip are exactly the ones who already met the misroot.
  - **`[ "$SPECS_PATH/../specifications" -ef "$SPECS_PATH" ]` or `[ "$SPECS_PATH/../ideas" -ef
    "$SPECS_PATH" ]`, where `$SPECS_PATH` is not itself a git work tree's top level.** Where
    `git -C "$SPECS_PATH" rev-parse --show-prefix` succeeds, it must print a non-empty prefix. A
    specs repository cloned into a directory that happens to be named `specifications` is a
    repository root, not a directory inside one, whether or not it holds a `specifications/` yet.
    This test too runs whether or not `$SPECS_PATH/specifications/` exists. It catches the same
    misroot below a directory that is not a repository's top level (`<repo>/specs/specifications`),
    and a `specifications/` directory mounted on its own under that name, including one a run
    already wrote a nested `specifications/` into. Neither has a repository prefix for the first
    test to read.
  - **Why those two of the four.** They are the two directories folders are created in: `idea:` and
    `create-vi:` create VI folders under `specifications/`, and `jira-workitem-import` writes a
    `PRODFB-` ticket's folder under `ideas/` and every other ticket's under `specifications/`.
    `specs/` and `vis/` are older names the plugin still reads and never creates a folder in, and a
    directory named `specs` is as often a specs root inside a larger repository (`<repo>/specs`),
    which §3.1's notice reports and this check must not stop. Either of those two holding a feature
    folder is (b)'s.
- **(b) `$SPECS_PATH` is, or directly holds, a feature folder.** Either `$SPECS_PATH` itself carries
  a key, or an immediate subdirectory does. **A directory carries the key `<K>`** where it holds
  `jira-import/<K>-index.md`, the import `jira-workitem-import` writes, with `<K>` read from that
  file's name as `jira-input-resolution.md` § JiraID token step 3 reads a folder's key; or where a
  `.md` file directly inside it has a top-level frontmatter `jira_key:` or `vi_key:` of `<K>`, as the
  VI does (`vi-format.md`) and as `idea.md` does in a VI folder `idea:` created (`idea-format.md`).
  **It counts only where the directory's own name passes the folder-naming rule against that key**:
  the name equals `<K>` or begins `<K>-` or `<K>_`, case-insensitive (`jira-input-resolution.md`
  § JiraID token, step 2). **`$SPECS_PATH`'s own name is tested physically** (`cd -P`), so a
  `$SPECS_PATH` reached through a symlink is judged by the folder it reaches, never by the name of
  the link. **A subdirectory is tested by its own name**, and **one whose physical path resolves
  inside one of `$SPECS_PATH`'s specs directories is skipped**. A convenience link at a correct
  root, such as `current -> specifications/PRODUCT-1234-a`, points into the tree rather than out of
  it, and must not stop every run. The test applies whether or not `$SPECS_PATH/specifications/`
  exists. Every folder the plugin or the importer creates is named by its key, so a folder the tree
  holds passes the test. A key-bearing file that is no feature folder does not: a `templates/` copy
  of a VI, or a `README.md` or `docs/` page carrying `jira_key:`. Those never stop a run, at a fresh
  root or a populated one. A nested `specifications/` that a misrooted run already wrote therefore
  cannot hide this signal. This is the signal for a `specifications/` directory mounted under
  another name — the `/workspace/specs` mount a container makes of a host `SPECS_PATH` naming
  `<repo>/specifications` — whose parent (a) cannot see, and for a `$SPECS_PATH` that is itself a VI
  folder reached under its own name, a symlink to one included, since its physical name is read. An
  Epic folder carries no key by this test (`specification.md` and `design.md` assert none), so
  inside a repository only (a) catches a `$SPECS_PATH` pointing at one. Stop testing at the first that qualifies; the
  stray-folder form of the stop below finishes the loop and names every subdirectory that qualifies.
  **What neither signal sees, as a class: a `$SPECS_PATH` outside any work tree's top-level
  `specifications/` or `ideas/` where neither it nor any immediate subdirectory passes (b)'s test.**
  Inside a repository, (a)'s first test catches every such path under those two by its prefix.
  Outside one, a mount passes unseen where it is a specs directory whose folders carry no import and
  no keyed VI or `idea.md` (an empty one, or a legacy `specs/` or `vis/` one), a VI folder mounted
  under a name that is not its own, or any Epic folder. (a)'s second test still catches a mount named
  `specifications` or `ideas`.

A specs repository nothing has been written into yet has no specs directory and prints an empty
prefix, so it matches nothing and is never a stop. A `$SPECS_PATH` below its repository's top level
that holds `specifications/` (`<repo>/specs`) prints another prefix and is not stopped here either.
It is the first of the two unsupported layouts below, which §3.1 reports in a notice, and this check
does not try to tell it apart.

**The value to set.** Walk up from `$(cd -P -- "$SPECS_PATH" && pwd)`, starting with that directory
itself and going at most three levels above it: a feature folder sits one level below its specs
directory, an Epic subfolder two, and a subdirectory of either, such as `jira-import/` or
`dev-workflows/`, three. Take the first directory `D` that **is a specs directory** — `[
"$D/../<name>" -ef "$D" ]` holds for `<name>` one of `specifications`, `ideas`, `specs` and `vis`,
and where that name is `specs` or `vis`, `D`'s parent also holds `specifications/` or `ideas/` and
`D` itself holds none of the four, since a directory of either name with no such sibling, or with a
specs directory of its own, is as often a specs root inside a larger repository as a legacy specs
directory — **and** for which `git -C "$D"
rev-parse --show-toplevel` succeeds and prints the same path as `git -C "$D/.." rev-parse
--show-toplevel`. **The value the walk found** is `$(cd -P -- "$D/.." && pwd)`. Below and in the stop
it is always written `<the value the walk found>`, and `<value>` always means `$SPECS_PATH` as set:
the two are different paths in every case this check stops. The walk takes all four names, though
(a) tests two: by the time it runs a signal has already fired, and a legacy `specs/` or `vis/`
directory beside a `specifications/` or `ideas/` one, holding none of its own, is a specs directory
whose parent is the value to set. **The walk cannot tell a dedicated specs repository from a code
repository that happens to hold a top-level specs directory**, any more than §3.1 can: it names the
directory a specs directory sits in, and `$SPECS_PATH` names the root of a dedicated specs repository
(§3.1), which is the operator's to know.
**Both halves of the test are required.**
- **`-P`**: a `$SPECS_PATH` reached through a symlink (`H/specs → R/specifications`) resolves `..`
  logically to `H` without it. Setting `SPECS_PATH=H` would then pass this check and send the next
  creating command to `H/specifications/`.
- **The work-tree test**: a `specifications/` directory bind-mounted at `/workspace/specifications`
  has `/workspace` as its parent, which is not a repository. Naming it would send the operator from
  this stop straight to §3.1's "not a repository" notice, which is the very symptom this check exists
  to prevent.

The value the walk found is `R` for an ordinary repository, through a symlink too, and for a VI or
Epic folder inside one. Where `git -C "<the value the walk found>" rev-parse --show-prefix` prints a
non-empty prefix, as it does for `<repo>/specs` when `$SPECS_PATH` is `<repo>/specs/specifications`,
the stop still names it, since that is where the specs directory sits. It does not present it as a
supported configuration, though: it adds that a specs tree inside a larger repository is
unsupported, so following it ends this stop and draws §3.1's notice instead. Where no directory on
the walk passes, as with a mount of either kind, no path can be established, and the stop says *the root of
your specs repository, the directory that holds its specs directories* instead.

**Any signal is a hard stop, printed as `SPECS_PATH_INSIDE_TREE`**, so no caller proceeds past it.
It is never one of `jira-input-resolution.md`'s Fallback prompts, and no caller maps it onto *no
folder found* or `none`. **The stop also sets `specs_git: misrooted` for the whole run**, as §3.3 G0
sets `specs_git: blocked`. A stopped run still runs its emitter tail (§4), and under that flag every
emitter falls to its report-only tier: feedback (`feedback-emission.md` §2), follow-ups (`followup-emission.md` §2) and `resume.md`
(`session-hygiene.md` §1). `commit-artifacts` skips with the stop repeated, so the run writes nothing
under `$SPECS_PATH`.

**The stop is one line**, naming the variable, its value, the signal and the value to set, plus the
unsupported-layout clause where it applies. **Where only (b)'s second half fired and the walk found
no value**, that one-line form has nothing true to name, because the folder that fired sits beside
`$SPECS_PATH`'s tree rather than above it. The stop takes one of two other forms instead, chosen in
this order. Where the walk did find a value, `$SPECS_PATH` lies at or below a specs directory and the
form above is right, whichever signal fired. **Wherever a form below sends a folder into
`specifications/`, a `PRODFB-` ticket's folder goes into `ideas/` instead**, where the importer puts
one, and the stop says so in a parenthesis.

- **The stray-folder form**, where `git -C "$SPECS_PATH" rev-parse --show-prefix` succeeds and either
  prints nothing, so `$SPECS_PATH` is a work tree's top level, or `$SPECS_PATH` holds one of the four
  specs directories and is not itself named `specs` or `vis`. The variable names the right directory, and feature folders sit beside the
  specs directories rather than in one. The stop names no value to set. It finishes (b)'s loop and
  names every subdirectory that qualifies, with `<value>/specifications/` as where they belong, and
  nothing else, plus the unsupported-layout clause where `--show-prefix` is not empty: `<repo>/product-specs`
  holding `product-specs/specifications/` and a hand-placed `product-specs/PRODUCT-9-x/` is that
  case.
- **The two-readings form** everywhere else: where `rev-parse` fails; where `$SPECS_PATH` is below
  its repository's top level and holds no specs directory; and where it is below its top level and
  itself named `specs` or `vis`, whatever it holds. Nothing on disk tells the two layouts
  apart. `$SPECS_PATH` may be a specs directory under another name: a `specifications/` directory
  mounted on its own, or a directory in a repository that holds folders the way `specifications/`
  does. Its own nested `specifications/`, where there is one, is then what a misrooted run left. Or
  it may be a specs root whose folders belong in a `specifications/` below it. The stop states both
  readings and what each needs, and the operator chooses. **The first reading always names the
  `specifications/` the folders end up in and sets `$SPECS_PATH` to that directory's parent**, never
  merely *the directory that holds it*: for `M/notes` holding VI folders directly, where `notes` is
  no specs directory name, that parent is `M`, which holds no `specifications/` yet, so every key
  would come back not found and a creating command would make `M/specifications/…` unstopped. Where
  `rev-parse` succeeds, the folders move into a `specifications/` beside `$SPECS_PATH` and the value
  is `$SPECS_PATH`'s parent. Where it fails, the path is a mount of some specs directory, which only
  the operator can name, and the value is that directory's parent, mounted whole. Where `rev-parse`
  fails, the second reading also needs `$SPECS_PATH` made a repository's top level, since §3.1
  reports a non-repository `$SPECS_PATH` on every run. Where it succeeds, the second reading carries
  the unsupported-layout clause. **Where `rev-parse` succeeds and `$SPECS_PATH` is itself named
  `specs` or `vis`, the first reading is a legacy specs directory in a dedicated specs repository
  rather than a specs directory under another name**: its folders are already where they belong, a
  nested `specifications/` or `ideas/` inside it is what a misrooted run left, and the value to set is
  its parent, with no move. The reading says *in a dedicated specs repository* because a `specs/`
  directory in a code repository reads the same way, and setting `SPECS_PATH` to that repository
  would put the plugin's branches and commits there; where the parent is below its repository's top
  level, the reading also carries the unsupported-layout clause. Where `rev-parse`
  fails, the name proves nothing (a container mounts whatever it mounts at `/workspace/specs`), and
  the first reading stays the mount's.

**Where a run made while misrooted left anything behind, it adds one more line naming it.** That
covers a nested specs directory — `$SPECS_PATH/specifications/`, or `$SPECS_PATH/ideas/`, where an
import run on the misplaced variable put a `PRODFB-` ticket's folder — and the folders in it, and `$SPECS_PATH/dev-workflows-feedback/` where it exists.
**It is never added in the stray-folder form**: there the specs directories and those bookkeeping
directories are where they belong. In the two-readings form it is added under the first reading only, and the line says so,
because under the second those directories are where they belong too. Each item is named with where
it belongs: the folders of a nested specs directory in the directory of the same name under `<the
value the walk found>`, and each bookkeeping directory at the same path under `<the value the walk
found>`. Where the walk found no value, they belong in *the specs repository's* directory of the same
name and at *its top level*.

What each one costs is not the same. §2.1's classifier never stages a `dev-workflows-feedback/` left at that depth, so G1 fires on every later run. **A nested specs directory is worse, because part of it is committed in the
wrong place.** Seen from the repository's top level, which is where porcelain prints from, every
path under it begins `specifications/` or `ideas/`. Its bookkeeping matches §2.1's
`^(specs|specifications|vis|ideas)/.+/dev-workflows/` shape, its `jira-import/` and `epic-drafts/`
match theirs, and a release-notes, gaps or pull-request draft in a nested folder matches its
single-file shape, so the classifier takes all of them for artifacts. **While `$SPECS_PATH` stays
misrooted they are never committed**: `git -C "$SPECS_PATH" add` names a path that does not exist
from there, which fails. **The first run after the variable is fixed commits them, in the wrong
place, unless they are moved first.** A deliverable in a nested folder is OTHER and fires G1 on every
run instead. A nested tree left in place is also out of reach of the key-number folder match every
lookup by key uses (`jira-input-resolution.md` § JiraID token, step 2), which takes only immediate
children of a specs directory, so from the corrected root a key whose folder only that tree holds is
not found, and a command that creates its folder makes a second one at the right depth. The line says so for each, and each has to be moved like the rest. **The
plugin moves nothing and gives no commands**: a move has to be right in every state the repository
might be in, and only the operator can see that state:

`SPECS_PATH_INSIDE_TREE: SPECS_PATH is <value>, which <is itself the <specifications | ideas>/ directory | is inside the <specifications | ideas>/ directory | is itself a feature folder, carrying key <key> | holds the feature folder <subdirectory> directly> — every feature folder lives in a specs directory (specifications/, ideas/, specs/ or vis/) directly under $SPECS_PATH, so this run would look for and create folders in the wrong place; it wrote nothing under that path, and its feedback is reported here instead. Set SPECS_PATH to <the value the walk found | the root of your specs repository, the directory that holds its specs directories> where it is set — it must be the root of a dedicated specs repository — and re-run.[ <the value the walk found> is not the top level of its repository (<that repository's top level>), and a specs tree inside a larger repository is unsupported: this plugin switches branches and commits in that repository.]`
`[stray-folder form: SPECS_PATH_INSIDE_TREE: SPECS_PATH is <value>, <the top level of its repository | which holds the specs directory <value>/<that directory>/>, and holds the feature folder(s) <subdirectory>[, <subdirectory>…] outside its specs directories, where every feature folder lives. SPECS_PATH names the right directory; move <subdirectory>[, <subdirectory>…] into <value>/specifications/[ (a PRODFB- folder into <value>/ideas/)] yourself, commit the move, then re-run — the plugin moves nothing. This run wrote nothing under <value>, and its feedback is reported here instead.[ <value> is not the top level of its repository (<that repository's top level>), and a specs tree inside a larger repository is unsupported: this plugin switches branches and commits in that repository.]]`
`[two-readings form: SPECS_PATH_INSIDE_TREE: SPECS_PATH is <value>, which holds the feature folder <subdirectory> directly, and nothing on disk says whether <value> is <a legacy specs directory | a specs directory under another name> or a specs root. <If it is a legacy specs directory in a dedicated specs repository, its folders are where they belong: set SPECS_PATH to <the parent of <value>> where it is set[, though <the parent of <value>> is not the top level of its repository (<that repository's top level>), and a specs tree inside a larger repository is unsupported: this plugin switches branches and commits in that repository]. | If it is a specs directory under another name, its folders belong in a directory named specifications/, and SPECS_PATH names that directory's parent: <move them into <the parent of <value>>/specifications/[ (a PRODFB- folder into <the parent of <value>>/ideas/)] yourself, commit the move, and set SPECS_PATH to <the parent of <value>> | set SPECS_PATH to the parent of the specs directory <value> is a mount of, and mount that parent whole rather than the directory alone>, where it is set.> If it is a specs root, move <subdirectory> and every other feature folder beside it into <value>/specifications/[ (a PRODFB- folder into <value>/ideas/)] yourself and commit the move<, and make <value> the top level of a git repository, which it is not | ; <value> is not the top level of its repository (<that repository's top level>), and a specs tree inside a larger repository is unsupported: this plugin switches branches and commits in that repository>. Then re-run — the plugin moves nothing. This run wrote nothing under that path, and its feedback is reported here instead.]`
`[<in the two-readings form only: If <value> is <a legacy specs directory in a dedicated specs repository | a specs directory under another name>, m|M>isrooted runs left: <value>/<specifications | ideas>/ (<folder>, …), which belongs in <the value the walk found>/<the same directory>/ | the specs repository's <same directory>/, and which no folder lookup reaches from the corrected root while the first run after SPECS_PATH is fixed commits bookkeeping from it, in the wrong place, unless it is moved first; <value>/<bookkeeping directory>/, which belongs at <the value the walk found>/<bookkeeping directory>/ | the same path at the specs repository's top level; … Move them yourself, commit the move, then re-run — the plugin moves nothing.]`

**It offers no "enter the path" option**, unlike `jira-input-resolution.md`'s Fallback A and every
command's unset-`SPECS_PATH` stop. The wrong value lives in the environment, so a per-run override
would leave the next run, and every command that resolves no feature folder, pointed at the same
place. A command that runs `specs-preflight` ahead of its resolution (`document:`) would also already
have run it against the wrong path. No signal holding → the caller goes on to its own `$SPECS_PATH`
checks and its resolution, unchanged.

**Two layouts this does not support, each for its own reason.**
- **A specs tree inside a larger repository**: `$SPECS_PATH` below its repository's top level, as
  `<repo>/specs` holding `specs/specifications/` is. **The reason is git.** This plugin switches
  branches and commits in the repository `$SPECS_PATH` belongs to, and in one that also holds
  anything else, that moves the checkout of everything it holds. This check does not stop it; §3.1
  reports it in a notice and states the rule.
- **A specs root that is itself a subdirectory named `specifications` or `ideas`**:
  `<repo>/specifications`, holding its tree at `<repo>/specifications/specifications/`. **The reason
  is detection.** It prints the prefix `specifications/` and is byte-for-byte the damaged tree that
  (a)'s first test exists to catch, so it stops on every run, with its own `specifications/` or
  without one. §2.1's classifier accepts the shape, but the stop's remedies, setting
  `SPECS_PATH=<repo>` and moving the tree up a level, turn it into the ordinary layout. Being below
  its repository's top level, it is also an instance of the first layout.

§3.1 runs these same signals at run start, exactly as defined here, sets the same
`specs_git: misrooted` flag, and reports them in a notice that never stops the run: one line, plus
one more line naming anything a misrooted run left behind, exactly as the stop's. That notice is how
a run that resolves no feature folder learns the cause.
