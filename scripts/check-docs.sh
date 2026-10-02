#!/usr/bin/env bash
# Guards the plugin's docs/ tree against the drift that splitting prose invites.
#
# Splitting one README into a multi-page tree multiplies the places drift can hide. Every
# check below exists because a specific failure was observed -- in this plugin, or
# in the two restructures this one follows (dynatrace-managed-mcp#214,
# ai-containers#78).
#
# FIFTEEN checks, numbered 1-12, 15, 17 and 18 -- numbers 13, 14, 16 and 19 are deliberately
# absent (ai-workflows' vendor-neutrality and loader-contract checks; see the edition-config
# block's notes for why). The number is written here and nowhere else in this file, and
# nothing gates it -- re-derive it with `grep -oE '\bfail [0-9]+ ' "$0" | awk '{print $2}' |
# sort -un` -- the numbers a fail() call can actually report -- rather than trusting this
# sentence, and update it in the commit that adds a check.
#
# --selftest mutates a copy of the passing fixture once per check and asserts the
# gate rejects it. Without that, the fixtures are decorative: a gate that cannot
# be shown to fail proves nothing when it passes. ai-containers' equivalent gate
# passed vacuously on its first run, examining nothing, because its file list came
# from `git ls-files` while the new pages were still untracked.
set -uo pipefail

# ---------------------------------------------------------------- edition config
# THE ONLY PART OF THIS FILE THAT DIFFERS BETWEEN EDITIONS. Never copy it across.
# Everything below is byte-identical in ihudak-claude-plugins, mgd-claude-plugins
# and ihudak-copilot-plugins, so a fix to the gate ports by plain `cp` of the body.
PLUGIN_REL="dev-workflows"           # claude: plugins/dev-workflows -- no plugins/ level here
CMD_DIR="skills"                     # claude: commands
CMD_SUFFIX="/SKILL.md"               # claude: .md
CMD_EXCLUDE="_shared"                # claude: (none)
REF_DIR="skills/_shared"             # claude: references
REF_FLAT_EXTRA=""                    # claude: model-routing -- there, references/model-routing/*.md
                                     # is a subtree of reference FILES; here it is "" because this
                                     # edition's model-routing.md is a FLAT file directly in _shared,
                                     # not a subtree
DOC_CMD_DIR="skills"                 # claude: commands
CLI="copilot"                        # claude: claude
CLI_VERBS="marketplace add|install|update"   # claude: marketplace add|marketplace update|install|update
CLI_REQUIRED="marketplace add|update"   # claude: marketplace add|marketplace update|update -- the verb
                                     # phrases getting-started.md must carry inline. A subset
                                     # of CLI_VERBS; differs per edition because Copilot
                                     # updates with `plugin update --all`, not a marketplace verb.
HAS_COST=0                           # claude: 1 -- no cost subsystem exists here (skills/_shared/specs-repo-git.md section 2.1's closing note)
HAS_CHOICE_CAP=0                     # claude/mgd: 1 -- this edition's ask_user takes any number of
                                     # choices and its own allowFreeform; AskUserQuestion's 4-option
                                     # cap does not apply here
CHANGELOG_GLOB="*/CHANGELOG.md"      # claude/mgd: plugins/*/CHANGELOG.md -- this edition's plugins
                                     # sit one level shallower (no plugins/ directory)

# Checks 13 (vendor tokens), 14 (foreign identity) and 19 (edition-forbidden denylist) in
# ai-workflows enforce THAT edition's vendor-neutral, de-branded corpus -- a public mirror
# that must never print the internal organisation's name or any customer/vendor token. Both
# editions here are the opposite by design: this plugin is written FOR Dynatrace Managed,
# names itself, its Jira projects and its container repo throughout its own docs on purpose,
# and a check enforcing silence about them would be fighting the plugin's own subject matter.
# Nothing is ported for 13/14/19 -- the gap in the numbering is this comment, not an omission.
# (For the sibling check this file DOES port under a different number -- "a page under docs/
# must not name the MARKETPLACE or the CONTAINER REPO it ships from, getting-started.md
# excepted" -- see check 10 below. That one survives porting because it guards identity
# LEAKAGE TO A FORK, not vendor neutrality; this edition still must not point a fork at
# ITS OWN marketplace slug from a page a fork keeps verbatim.)
#
# Check 16 (loader contract) in ai-workflows validates a cross-plugin reference-loading
# skill (workflows-core:reference) that lets a dependent plugin read a shared corpus living
# in a DIFFERENT plugin. This edition ships exactly one plugin -- its corpus and its call
# sites are the same tree, reached by ${CLAUDE_PLUGIN_ROOT} path alone -- so there is no
# loader skill, no cross-plugin boundary, and nothing for that check to assert. Not ported;
# the gap in the numbering is this comment.

# RUNTIME_VARS is a SILENCER: every name in it kills both directions of check 5 (env-var doc
# agreement) for that variable, permanently -- no mutation of the fixture tree can reveal a
# missing entry, so changing this list is a deliberate, reviewed act. Each edition's host and
# hooks inject differently-named runtime variables, so this pair is edition identity, not
# shared body. Each current entry here is justified:
#   BASH_REMATCH BASH_SOURCE OSTYPE -- runtime/shell, not user-settable
#   MODEL_ROUTING -- hook-local shell variable (hooks/preload-context.sh:52)
#   OWNER_REPO    -- template placeholder in $REF_DIR/phase-handoff.md
#   PLUGIN_ROOT   -- host-injected plugin-root path (hooks/hooks.json); this edition's
#                    equivalent of claude/mgd's CLAUDE_PLUGIN_ROOT
#   ROOT          -- hook-local shell variable (hooks/changelog-owners-reminder.sh)
RUNTIME_VARS="BASH_REMATCH BASH_SOURCE MODEL_ROUTING OSTYPE OWNER_REPO PLUGIN_ROOT ROOT"
                                      # claude/mgd: CLAUDE_PLUGIN_ROOT ARGUMENTS OSTYPE
                                      # BASH_SOURCE BASH_REMATCH ROOT OWNER_REPO -- reads
                                      # ARGUMENTS, which this edition does not
# NOTE: this tripwire is self-referential -- it guards a constant in THIS file, and --selftest
# only ever mutates a copy of the fixture tree, never the script. It is therefore verified
# out-of-band (mutate a copy of this script, run it against any tree, see check 5 fail).
# Frozen (sorted) copy -- check_env_vars() asserts RUNTIME_VARS still sorts to exactly this,
# so a silent edit to the list above fails check 5 instead of passing quietly.
RUNTIME_VARS_FROZEN="BASH_REMATCH BASH_SOURCE MODEL_ROUTING OSTYPE OWNER_REPO PLUGIN_ROOT ROOT"

FAILURES=0

fail() { printf 'FAIL check %s: %s\n' "$1" "$2" >&2; FAILURES=$((FAILURES + 1)); }
note() { printf '  %s\n' "$1" >&2; }

# ---------------------------------------------------------- shared: command enumeration
# A "command" is $CMD_DIR/<name>$CMD_SUFFIX. When $CMD_SUFFIX names a path (it contains a
# slash -- e.g. copilot's "/SKILL.md"), each command is a DIRECTORY holding that file, so
# enumeration walks directories and excludes $CMD_EXCLUDE (a directory that is not a
# command, e.g. copilot's "_shared"). Otherwise $CMD_SUFFIX is a flat filename suffix and
# enumeration globs files directly -- $CMD_EXCLUDE plays no role there, since a bare
# directory never matches the glob.
cmd_names() { # <plugin-dir> -> one command name per line
  local p="$1" b
  case "$CMD_SUFFIX" in
    */*) ls -d "$p/$CMD_DIR"/*/ 2>/dev/null | sed 's|/*$||; s|.*/||' | grep -vxF "${CMD_EXCLUDE:-__none__}" ;;
    *)   ls "$p/$CMD_DIR"/*"$CMD_SUFFIX" 2>/dev/null | while IFS= read -r b; do
           b="$(basename "$b")"; printf '%s\n' "${b%$CMD_SUFFIX}"
         done ;;
  esac
}
cmd_file() { printf '%s/%s/%s%s\n' "$1" "$CMD_DIR" "$2" "$CMD_SUFFIX"; } # <plugin-dir> <name> -> its file path

# ---------------------------------------------------------------- check 1 + 2
# Every relative link resolves, and every #anchor resolves to a real heading in
# whichever file it names. A bare `#anchor` names no file, so a file-existence
# check cannot see it -- that is why check 2 is separate. ai-containers' split
# broke 24 anchors this way.
# GitHub KEEPS non-ASCII letters in an anchor and lowercases them, and disambiguates a
# repeated heading as name, name-1, name-2. Neither is expressible in `tr`/`sed` without a
# UTF-8 locale -- in a C/ASCII locale those letters are deleted outright, so a CORRECT link
# fails check 2. python3 casefolds and classifies Unicode regardless of locale, and it is
# already a hard requirement of this repo's CI (scripts/validate-catalog.py runs in the same
# job), so this adds no dependency. The shell path is kept only for a bare environment with
# no python3, and it announces its own limitation instead of mis-resolving in silence.
strip_fences() { # drop fenced code blocks: an illustrative link inside a ```markdown
                 # block is not a real link, and a `#` line inside one is not a heading.
                 # check 6 has always stripped fences; checks 1 and 2 did not, which made
                 # them fail on correct content AND accept anchors that do not exist.
  awk '/^[ \t]*(```|~~~)/ { infence = !infence; next } !infence' "$1"
}

HAVE_PY=0; command -v python3 >/dev/null 2>&1 && HAVE_PY=1

slug_list() { # <markdown file> -> one GitHub anchor per heading, in document order
  if [ "$HAVE_PY" = 1 ]; then
    strip_fences "$1" | grep -E '^#{1,6} ' | sed -E 's/^#{1,6} //' | python3 -c '
import sys
seen = {}
for line in sys.stdin:
    h = line.rstrip("\n").replace("`", "").lower()
    s = "".join(c for c in h if c.isalnum() or c in " _-").replace(" ", "-")
    n = seen.get(s, 0); seen[s] = n + 1
    print(s if n == 0 else "%s-%d" % (s, n))
'
  else
    strip_fences "$1" | grep -E '^#{1,6} ' | sed -E 's/^#{1,6} //' \
      | tr '[:upper:]' '[:lower:]' \
      | sed -E 's/`//g; s/[^a-z0-9 _-]//g; s/ /-/g' \
      | awk '{ c = seen[$0]++; if (c == 0) print; else print $0 "-" c }'
  fi
}

check_links_and_anchors() {
  local root="$1" f target anchor path abs heading_file
  while IFS= read -r f; do
    while IFS= read -r link; do
      target="${link%%#*}"
      anchor="${link#*#}"
      [ "$anchor" = "$link" ] && anchor=""
      if [ -n "$target" ]; then
        path="$(dirname "$f")/$target"
        abs="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")"
        if [ ! -e "$abs" ]; then
          fail 1 "$f -> $target (no such file)"
          continue
        fi
        heading_file="$abs"
      else
        heading_file="$f"
      fi
      if [ -n "$anchor" ] && [ -f "$heading_file" ]; then
        # Collect first, match second. `... | grep -qx` would exit on the first
        # match, SIGPIPE the producer, and `pipefail` would report that as a
        # failure -- turning a VALID anchor into a check-2 error. Same defect
        # ai-containers#78 caught in its own new gate.
        local slugs
        case "$heading_file" in *.md) ;; *) continue ;; esac  # only markdown has headings;
                                                             # a .sh file's `# comment` is not one
        slugs=$(slug_list "$heading_file" 2>/dev/null)
        if ! grep -qx -- "$anchor" <<<"$slugs"; then
          fail 2 "$f -> ${target:-(this file)}#$anchor (no such heading)"
        fi
      fi
    done < <(strip_fences "$f" | grep -oE '\]\([^)#][^)]*\)|\]\(#[^)]*\)' \
             | sed -E 's/^\]\(//; s/\)$//; s/[[:space:]]+"[^"]*"$//; s/^<//; s/>$//' \
             | grep -vE '^(https?|mailto):')
  done < <({ find "$root/$PLUGIN_REL/docs" -name '*.md' 2>/dev/null
             [ -f "$root/$PLUGIN_REL/README.md" ] && printf '%s\n' "$root/$PLUGIN_REL/README.md"
             [ -f "$root/README.md" ] && printf '%s\n' "$root/README.md"; })
}

# ------------------------------------------------------------------- check 3
# No orphan pages. Reachability is transitive from docs/README.md, so a page
# linked only from another orphan is still an orphan.
check_orphans() {
  local root="$1" docs="$1/$PLUGIN_REL/docs" seen frontier next f target abs
  [ -f "$docs/README.md" ] || { fail 3 "docs/README.md is missing -- nothing to reach from"; return; }
  seen="$(cd "$docs" && pwd)/README.md"
  [ -f "$1/$PLUGIN_REL/README.md" ] && seen="$seen
$(cd "$1/$PLUGIN_REL" && pwd)/README.md"
  frontier="$seen"
  while [ -n "$frontier" ]; do
    next=""
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      while IFS= read -r target; do
        abs="$(cd "$(dirname "$f")" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
        [ -f "$abs" ] || continue
        case "$seen" in *"$abs"*) continue ;; esac
        seen="$seen
$abs"
        next="$next
$abs"
      done < <(grep -oE '\]\([^)#][^):]*\.md[^)]*\)' "$f" | sed -E 's/^\]\(//; s/\)$//; s/#.*$//')
    done < <(printf '%s\n' "$frontier")
    frontier="$next"
  done
  while IFS= read -r f; do
    case "$seen" in *"$f"*) ;; *) fail 3 "orphan page (unreachable from docs/README.md): ${f#$root/}" ;; esac
  done < <(cd "$docs" && find . -name '*.md' -exec sh -c 'cd "$(dirname "$1")" && printf "%s/%s\n" "$(pwd)" "$(basename "$1")"' _ {} \;)
}

# ------------------------------------------------------------------- check 4
# Inventory agrees in BOTH directions, over reference FILES not reference
# markdown -- in the edition this was found in, the reference dir ($REF_DIR) held 98
# files of which 5 were not markdown, and one of those (cost-prices.yaml) is
# user-overridable and therefore user-facing.
# Every inventory is derived from the edition being checked, never from a number
# written into a page.
check_inventory() {
  local root="$1" p="$1/$PLUGIN_REL" d="$1/$PLUGIN_REL/docs" n

  # commands <-> docs/$DOC_CMD_DIR/
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    [ -f "$d/$DOC_CMD_DIR/$n.md" ] || fail 4 "command '$n' has no page at docs/$DOC_CMD_DIR/$n.md"
  done < <(cmd_names "$p")
  while IFS= read -r n; do
    [ -f "$(cmd_file "$p" "$n")" ] || fail 4 "docs/$DOC_CMD_DIR/$n.md names no real command"
  done < <(ls "$d/$DOC_CMD_DIR"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||')

  # agents <-> docs/reference/agents.md
  while IFS= read -r n; do
    grep -q "\`$n\`" "$d/reference/agents.md" 2>/dev/null || fail 4 "agent '$n' is absent from reference/agents.md"
  done < <(ls "$p/agents"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||')
  while IFS= read -r n; do
    [ -f "$p/agents/$n.md" ] || fail 4 "reference/agents.md names '$n', which is not an agent"
  done < <(grep -oE '^\| `[a-z-]+`' "$d/reference/agents.md" 2>/dev/null | tr -d '|` ')

  # reference FILES <-> docs/reference/references.md
  while IFS= read -r n; do
    grep -qE "^[|-] .*\`$n\`" "$d/reference/references.md" 2>/dev/null || fail 4 "reference file '$n' has no row/entry in reference/references.md (a prose mention is not one)"
  done < <({ ls "$p/$REF_DIR"/*.md 2>/dev/null; ls "$p/$REF_DIR"/*.yaml 2>/dev/null; \
             [ -n "$REF_FLAT_EXTRA" ] && ls "$p/$REF_DIR/$REF_FLAT_EXTRA"/*.md 2>/dev/null; } | sed 's|.*/||')
  while IFS= read -r n; do
    [ -f "$p/$REF_DIR/$n" ] || { [ -n "$REF_FLAT_EXTRA" ] && [ -f "$p/$REF_DIR/$REF_FLAT_EXTRA/$n" ]; } \
      || fail 4 "reference/references.md names '$n', which is not a reference file"
  done < <(grep -oE '`[A-Za-z0-9_.-]+\.(md|yaml)`' "$d/reference/references.md" 2>/dev/null | tr -d '`')

  # reference subtree counts -- *.md only: these subtrees also carry vendored
  # non-markdown data/templates that are not user-facing reference pages, so
  # counting everything would fail this check on files docs/ never claims.
  # Derived from the tree, never hardcoded: a hardcoded list cannot see a NEW subtree,
  # which is how a whole directory of reference docs would ship undocumented.
  # model-routing/ is excluded deliberately -- its *.md are inventoried file-by-file above.
  local dir count claimed
  for dir in $(ls -d "$p/$REF_DIR"/*/ 2>/dev/null | sed 's|/*$||; s|.*/||'); do
    [ -n "$REF_FLAT_EXTRA" ] && [ "$dir" = "$REF_FLAT_EXTRA" ] && continue
    count=$(find "$p/$REF_DIR/$dir" -name '*.md' | wc -l | tr -d ' ')
    claimed=$(grep -oE "\`$dir/\` \(([0-9]+)\)" "$d/reference/references.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ "$claimed" = "$count" ] || fail 4 "reference/references.md says $dir/ has '${claimed:-nothing}', tree has $count"
  done
  # ...and the reverse: a subtree the page claims but the tree no longer has. Without this,
  # `rm -rf $REF_DIR/upgrade/` passes while the page still advertises `upgrade/` (3).
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -d "$p/$REF_DIR/$dir" ] || fail 4 "reference/references.md claims subtree $dir/, which does not exist"
  done < <(grep -oE '`[a-z][a-z0-9-]*/` \([0-9]+\)' "$d/reference/references.md" 2>/dev/null | sed 's|`||g; s|/.*||')

  # hooks <-> docs/reference/hooks.md
  while IFS= read -r n; do
    grep -qE "^[|-] .*\`$n\`" "$d/reference/hooks.md" 2>/dev/null || fail 4 "hook '$n' has no row/entry in reference/hooks.md (a prose mention is not one)"
  done < <(ls "$p/hooks"/*.sh 2>/dev/null | sed 's|.*/||; s|\.sh$||')
  while IFS= read -r n; do
    [ -f "$p/hooks/$n.sh" ] || fail 4 "reference/hooks.md names '$n', which is not a hook"
  done < <(grep -oE '^\| `[a-z-]+`' "$d/reference/hooks.md" 2>/dev/null | tr -d '|` ')

  # skills <-> docs/reference/references.md -- the FORWARD direction (every skills/
  # directory must be documented as a skill) is inert where $CMD_DIR IS "skills": there,
  # skills/ holds this edition's COMMANDS (already covered by the command inventory
  # above) plus $CMD_EXCLUDE (a reference directory, not a skill), so demanding each be
  # documented as a skill would be false. The REVERSE direction (a documented skill must
  # be real) stays active in every edition -- it catches a stale/phantom claim in
  # references.md regardless of what skills/ holds, and the command inventory does not
  # cover that direction.
  if [ "$CMD_DIR" = "skills" ]; then
    note "check 4 skills forward-check not applicable: skills/ is this edition's \$CMD_DIR, already covered by the command inventory above"
  else
    while IFS= read -r n; do
      grep -qE "^[|-] .*\`$n\`" "$d/reference/references.md" 2>/dev/null || fail 4 "skill '$n' has no row/entry in reference/references.md (a prose mention is not one)"
    done < <(ls -d "$p/skills"/*/ 2>/dev/null | sed 's|/*$||; s|.*/||')
  fi
  while IFS= read -r n; do
    [ -d "$p/skills/$n" ] || fail 4 "reference/references.md names skill '$n', which is not a skill"
  done < <(grep -oE '^\| `[a-z-]+`' "$d/reference/references.md" 2>/dev/null | tr -d '|` ')
}

# ------------------------------------------------------------------- check 5
# Environment variables agree in both directions. The scan covers the command
# dir ($CMD_DIR), agents/, the reference dir ($REF_DIR), hooks/, and the literal
# skills/ -- narrowing it to the first three would let a variable only a hook
# reads look documented-but-unread. The
# runtime-exclusion list is written in, so a SEVENTH user-settable variable fails
# this check rather than passing silently. That silent pass is exactly how
# GIT_USER_INITIALS and DEV_WORKFLOWS_COST_PRICES came to be missing from the
# section named after them (defect D4).
check_env_vars() {
  local root="$1" p="$1/$PLUGIN_REL" d="$1/$PLUGIN_REL/docs" v
  local now; now=$(printf '%s\n' $RUNTIME_VARS | sort | tr '\n' ' ' | sed 's/ $//')
  [ "$now" = "$RUNTIME_VARS_FROZEN" ] \
    || fail 5 "RUNTIME_VARS changed -- every entry silences check 5 for that variable; justify it in the comment above and update RUNTIME_VARS_FROZEN in the same edit"
  local read_vars documented
  # `skills` stays a literal fifth root: in editions where CMD_DIR is not "skills"
  # there is still a skills/ tree to scan, and in editions where it is, sort -u
  # dedupes. Dropping it is invisible until someone adds a $VAR only under skills/.
  read_vars=$(grep -rhoE '\$\{?[A-Z][A-Z0-9_]{2,}\}?' \
                "$p/$CMD_DIR" "$p/agents" "$p/$REF_DIR" "$p/hooks" "$p/skills" 2>/dev/null \
              | tr -d '${}' | sort -u)
  for v in $read_vars; do
    case " $RUNTIME_VARS " in *" $v "*) continue ;; esac
    grep -qw "$v" "$d/reference/environment.md" 2>/dev/null \
      || fail 5 "\$$v is read by the plugin but absent from reference/environment.md"
    grep -qw "$v" "$d/getting-started.md" 2>/dev/null \
      || fail 5 "\$$v is read by the plugin but absent from getting-started.md"
  done
  documented=$(grep -oE '^#+ `\$?[A-Z][A-Z0-9_]{2,}`|\*\*`\$?[A-Z][A-Z0-9_]{2,}`\*\*' \
                 "$d/reference/environment.md" 2>/dev/null | sed 's/^#* //' | tr -d '*`$')
  for v in $documented; do
    grep -qx -- "$v" <<<"$read_vars" \
      || fail 5 "reference/environment.md documents \$$v, which the plugin never reads"
  done
}

# ------------------------------------------------------------------- check 6
# No table cell over 200 characters. This is the readability invariant the whole
# restructure exists to establish, and the one a future edit will silently
# violate: the README this replaced carried a single cell of 2,066 characters.
check_table_cells() {
  local root="$1" files hits h
  files=$( { find "$root/$PLUGIN_REL/docs" -name '*.md' 2>/dev/null
             [ -f "$root/$PLUGIN_REL/README.md" ] && printf '%s\n' "$root/$PLUGIN_REL/README.md"
             [ -f "$root/README.md" ] && printf '%s\n' "$root/README.md"; } )
  [ -n "$files" ] || return 0
  hits=$(while IFS= read -r f; do
           [ -n "$f" ] || continue
           # LC_ALL=C + subtracting UTF-8 continuation bytes counts CHARACTERS the same way under
           # gawk and mawk. A bare length() counts bytes under mawk (Debian/Ubuntu's default awk),
           # so a 199-character cell carrying a few arrows or em dashes read as over 200.
           # Assumes well-formed UTF-8: a stray continuation byte with no lead byte is subtracted too.
           LC_ALL=C awk -v FILE="${f#$root/}" '
             /^[ \t]*(```|~~~)/ { infence = !infence; next }
             infence   { next }
             /^[[:space:]]*\|/ {
               n = split($0, cells, "|")
               last = ($0 ~ /\|[[:space:]]*$/) ? n - 1 : n   # no trailing pipe => the final field IS a cell
               for (i = 2; i <= last; i++) {
                 c = cells[i]; gsub(/^ +| +$/, "", c)
                 t = c; len = length(c) - gsub(/[\200-\277]/, "", t)
                 if (len > 200)
                   printf "%s:%d cell is %d chars (max 200)\n", FILE, NR, len
               }
             }' "$f"
         done <<<"$files")
  [ -n "$hits" ] || return 0
  while IFS= read -r h; do [ -n "$h" ] && fail 6 "$h"; done <<<"$hits"
}

# ------------------------------------------------------------------- check 7
# getting-started.md carries the install and update commands INLINE rather than
# linking out, because a getting-started page whose first step is a link has
# failed at its one job. That makes it the only page under docs/ carrying edition
# identity, so it is pinned to the repo-root README.
#
# It is a SUBSET pin, not equality: the root README documents the whole
# marketplace, while this page documents ONE plugin and should install only what
# that plugin actually needs. (dev-workflows references `dt-style-guide` 32 times;
# `acli` zero, and `$REF_DIR/followup-emission.md` states outright that it has no
# runtime dependency on `obsidian-llm-wiki`.) So every line HERE must appear verbatim
# in the root README -- which is what catches a drifted marketplace name or command
# form -- but the root README may list more.
check_install_block() {
  local root="$1" a b extra line
  a=$(grep -oE "^$CLI plugin ($CLI_VERBS) .*" "$root/README.md" 2>/dev/null | sort -u)
  b=$(grep -oE "^$CLI plugin ($CLI_VERBS) .*" "$root/$PLUGIN_REL/docs/getting-started.md" 2>/dev/null | sort -u)
  if [ -z "$a" ]; then fail 7 "repo-root README.md has no '$CLI plugin ...' command lines to pin against"; return; fi
  if [ -z "$b" ]; then fail 7 "getting-started.md has no '$CLI plugin ...' command lines -- it must carry them inline"; return; fi

  extra=$(comm -13 <(printf '%s\n' "$a") <(printf '%s\n' "$b"))
  if [ -n "$extra" ]; then
    fail 7 "getting-started.md carries install commands the repo-root README does not"
    while IFS= read -r line; do [ -n "$line" ] && note "only in getting-started: $line"; done <<<"$extra"
  fi

  # The required verbs are the edition identity itself -- a reader who follows this
  # page must be able to perform them from it alone. CLI_REQUIRED is pipe-separated;
  # split on it without leaking the IFS change past this loop.
  local _saved_ifs="$IFS"
  IFS='|'
  for line in $CLI_REQUIRED; do
    IFS="$_saved_ifs"
    [ -n "$line" ] || continue   # guards a doubled '|' in a hand-edited CLI_REQUIRED,
                                  # which would otherwise yield one empty-string split
                                  # field and grep for a malformed pattern
    grep -q "^$CLI plugin $line " <<<"$b" \
      || fail 7 "getting-started.md is missing its '$CLI plugin $line' line"
  done
  IFS="$_saved_ifs"
  grep -q "^$CLI plugin install ${PLUGIN_REL##*/}@" <<<"$b" \
    || fail 7 "getting-started.md does not install ${PLUGIN_REL##*/} itself"
}

# ------------------------------------------------------------------- check 8
# Cost attribution agrees in BOTH directions: every command that hands emit-cost a
# fixed phase/role pair has a row in $REF_DIR/cost-emission.md section 7 carrying
# those same two values, and every section-7 row names a real command. Defect D2 --
# /update-vi emitting `phase: vi-update, role: pm` with no section-7 row -- was found
# by a one-off inline grep and defended by nothing afterwards, which is how it had
# survived since the command shipped. `/document` is the shape that defeats a naive
# grep: it calls emit-cost twice, as `/document (Jira mode)` and `/document (direct
# mode)`, against a single `/document` row.
# A command earns a section-7 row two ways: it calls emit-cost itself, or it CEDES
# the session and records a section-13 intent that a later run replays on its
# behalf. Both declare the same triple. A file doing NEITHER must not match --
# otherwise ordinary prose that happens to have the call site's shape satisfies
# the check, which is exactly how the two deferring commands first passed it: they
# contain no `emit-cost` at all, and their intent-record bullet matched the regex
# by coincidence. Rewording that bullet then turned the build red with a message
# blaming the section-7 table.
# Whitespace is normalised before matching: these files are hard-wrapped prose, so
# the phrase routinely straddles a newline and a line-oriented grep misses it.
cost_role_marker() { # <file> -> emit | defer | (empty)
  local flat; flat=$(tr '\n' ' ' < "$1" | tr -s ' ')
  if grep -q 'emit-cost' "$1"; then printf 'emit\n'
  elif printf '%s' "$flat" | grep -q '13.1 intent record'; then printf 'defer\n'
  fi
}
emit_cost_calls() { # <plugin-dir>  ->  lines of  <command>|<phase>|<role>
  local p="$1" f n
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    f=$(cmd_file "$p" "$n")
    [ -f "$f" ] || continue
    [ -n "$(cost_role_marker "$f")" ] || continue
    tr '\n' ' ' < "$f" | tr -s ' ' \
      | grep -oE '`command: /[a-z-]+( \([A-Za-z]+ mode\))?`, `phase: [a-z-]+`, `role: [a-z]+`' \
      | sed -E 's/`command: //; s/ \([A-Za-z]+ mode\)//; s/`, `phase: /|/; s/`, `role: /|/; s/`$//'
  done < <(cmd_names "$p") | sort -u
}

check_cost_attribution() {
  [ "$HAS_COST" = 1 ] || { note "check 8 not applicable: this edition has no cost subsystem"; return; }
  local root="$1" p="$1/$PLUGIN_REL" table calls line cmd phase role want
  table=$(sed -n '/^## 7\./,/^## 8\./p' "$p/$REF_DIR/cost-emission.md" 2>/dev/null \
          | grep -oE '^\| `/[a-z-]+` \| [^|]+ \| [^|]+ \|' \
          | sed -E 's/^\| `//; s/` \| /|/; s/ \| /|/; s/ *\|$//; s/\*//g; s/ *\| */|/g')
  [ -n "$table" ] || { fail 8 "$REF_DIR/cost-emission.md has no section-7 attribution table"; return; }
  calls=$(emit_cost_calls "$p")
  [ -n "$calls" ] || { fail 8 "no emit-cost call site found in $CMD_DIR/ -- the extractor has stopped matching"; return; }

  while IFS='|' read -r cmd phase role; do
    [ -n "$cmd" ] || continue
    want=$(grep -F "$cmd|" <<<"$table" | head -1)
    if [ -z "$want" ]; then
      fail 8 "$cmd emits phase/role '$phase'/'$role' but has no row in cost-emission.md section 7"
    elif [ "$want" != "$cmd|$phase|$role" ]; then
      fail 8 "$cmd emits '$phase'/'$role'; cost-emission.md section 7 says '${want#*|}'"
    fi
  done <<<"$calls"

  while IFS='|' read -r cmd phase role; do
    [ -n "$cmd" ] || continue
    grep -qF "$cmd|" <<<"$calls" \
      || fail 8 "cost-emission.md section 7 attributes $cmd, which neither passes emit-cost a phase/role pair nor records a section-13 intent"
  done <<<"$table"

  # Extractor-coverage assertion. Every command file that calls emit-cost OR records a
  # section-13 intent must yield a triple; otherwise a reworded call site makes this check
  # go QUIET, and the message above would blame the table for what is really an extractor
  # miss. `/document` is the live example -- it calls emit-cost twice under parenthesised
  # names.
  local f n cn
  while IFS= read -r cn; do
    [ -n "$cn" ] || continue
    f=$(cmd_file "$p" "$cn")
    [ -f "$f" ] || continue
    [ -n "$(cost_role_marker "$f")" ] || continue
    n="/$cn"
    grep -qF "$n|" <<<"$calls" \
      || fail 8 "$CMD_DIR/$cn$CMD_SUFFIX calls emit-cost (or records a section-13 intent) but no phase/role triple matched -- the EXTRACTOR has drifted, not the table; fix the regex, never the row"
  done < <(cmd_names "$p")
}

# ------------------------------------------------------------------- check 9
# Prose counts. check 4 gates the INVENTORIES in both directions, but not the sentences
# that state their size. A 22nd command with a page and an index link passes check 4 while
# `$PLUGIN_REL/README.md` still says "twenty-one slash commands" -- and a reader
# meets the sentence before the table. Same for the agent, reference-file, hook, skill and
# environment-variable totals.
_word2num() {
  case "$1" in
    one) echo 1 ;; two) echo 2 ;; three) echo 3 ;; four) echo 4 ;; five) echo 5 ;;
    six) echo 6 ;; seven) echo 7 ;; eight) echo 8 ;; nine) echo 9 ;; ten) echo 10 ;;
    eleven) echo 11 ;; twelve) echo 12 ;; thirteen) echo 13 ;; fourteen) echo 14 ;;
    fifteen) echo 15 ;; sixteen) echo 16 ;;
    twenty-one) echo 21 ;; thirty-four) echo 34 ;; ninety-eight) echo 98 ;;
    *) echo "$1" ;;
  esac
}

check_prose_counts() {
  local root="$1" p="$1/$PLUGIN_REL" d="$1/$PLUGIN_REL/docs"
  local raw claimed actual label file pat

  _one() { # <label> <file> <extended-regex whose match STARTS with the numeral> <actual>
    label="$1"; file="$2"; pat="$3"; actual="$4"
    [ -f "$file" ] || return 0
    # -i, and lowercase the captured numeral: a count sentence may open a sentence
    # ("Thirteen commands emit ...") or sit mid-sentence ("twenty-one slash commands").
    raw=$(grep -ohEi "$pat" "$file" 2>/dev/null | head -1 | awk '{print tolower($1)}')
    if [ -z "$raw" ]; then
      fail 9 "$label: no count sentence found in ${file#$root/} -- the wording drifted, so nothing is being checked"
      return 0
    fi
    claimed=$(_word2num "$raw")
    [ "$claimed" = "$actual" ] \
      || fail 9 "$label: ${file#$root/} says $raw ($claimed), tree has $actual"
  }

  # Left-anchored, on EVERY alternation below without exception: without a boundary, an
  # unenumerated compound like "twenty-five" would let the bare alternative "five" match its own
  # tail and silently compare the wrong numeral instead of failing loudly -- "twenty-five slash
  # commands" over a tree of five passed. (^|[^[:alnum:]_-]) keeps the match from starting
  # mid-word or mid-compound; a captured boundary character is whitespace in every real sentence,
  # so it disappears when `awk '{print $1}'` splits the extracted match.
  _one "commands"        "$p/README.md"                  '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) slash commands'    "$(cmd_names "$p" | wc -l | tr -d ' ')"
  _one "agents"          "$d/reference/agents.md"        '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) agents'           "$(ls "$p/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  _one "reference files" "$d/reference/references.md"    '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) files'           "$(find "$p/$REF_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')"
  _one "hooks"           "$d/reference/hooks.md"         '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) hooks'                   "$(ls "$p/hooks"/*.sh 2>/dev/null | wc -l | tr -d ' ')"
  # Inert where $CMD_DIR IS "skills" (see check 4's skills forward-check, same reason):
  # ls -d "$p/skills"/*/ would count this edition's commands plus $CMD_EXCLUDE, not
  # bundled skills -- there is no separate "N bundled skills" sentence to state there.
  if [ "$CMD_DIR" = "skills" ]; then
    note "check 9 skills-count assertion not applicable: skills/ is this edition's \$CMD_DIR, already counted by the commands assertion above"
  else
    _one "skills"          "$d/README.md"                  '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) bundled skills'           "$(ls -d "$p/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')"
  fi

  # The user-settable total is derived the same way check 5 derives its scan, so the two
  # can never disagree about what "user-settable" means.
  local read_vars n_settable v
  read_vars=$(grep -rhoE '\$\{?[A-Z][A-Z0-9_]{2,}\}?' \
                "$p/$CMD_DIR" "$p/agents" "$p/$REF_DIR" "$p/hooks" "$p/skills" 2>/dev/null \
              | tr -d '${}' | sort -u)
  n_settable=0
  for v in $read_vars; do
    case " $RUNTIME_VARS " in *" $v "*) continue ;; esac
    n_settable=$((n_settable + 1))
  done
  _one "environment variables" "$d/reference/environment.md" '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|twenty-one|thirty-four|ninety-eight|[0-9]+) user-settable' "$n_settable"

  # The size of the cost-emitting set is prose too, and it is the count that went stale the
  # moment /prompt and /feedback started emitting. Derived from the same extractor check 8 uses.
  if [ "$HAS_COST" = 1 ]; then
    local n_emit
    n_emit=$(emit_cost_calls "$p" | cut -d'|' -f1 | sort -u | grep -c . || true)
    _one "cost-emitting commands" "$d/reference/session-cost.md" \
         '(^|[^[:alnum:]_-])(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|twenty-one|thirty-four|ninety-eight|[0-9]+) commands emit a cost entry' "$n_emit"
  else
    note "check 9 cost-emitting-commands assertion not applicable: this edition has no cost subsystem"
  fi
}

# ------------------------------------------------------------------ check 10
# Identity quarantine. No page under docs/ may name the marketplace this plugin ships from
# or the repository that contains it -- getting-started.md is the single sanctioned
# exception, because installing the plugin requires naming both. CLAUDE.md has stated this
# rule in prose since the docs/ split; nothing enforced it until this check.
#
# WHY: a fork renames the marketplace and the container repo, and keeps every other docs
# page verbatim -- that is the whole point of forking. A page elsewhere that hardcodes
# either name is now wrong in the fork, silently, because nothing short of a full read
# would catch it. getting-started.md is exempt because a fork edits it anyway (it is where
# the fork's own marketplace add/install lines live); every other page should never have
# needed to know either name in the first place.
#
# TOKENS are derived from the repo-root README's own `$CLI plugin ...` lines -- the
# marketplace add target, the install target's `@marketplace` suffix, and the marketplace
# update target -- never hardcoded, so a fork with a renamed marketplace is checked against
# ITS OWN name, not this one's. `sed 'p; s|.*/||'` emits the slug and its bare repo name,
# since a page can name either form.
#
# BOUNDARY, not substring: `[A-Za-z0-9_-]` word-boundary match. An unanchored substring
# search over a short marketplace name fires on every unrelated page that happens to share
# the string (measured on ai-workflows: renaming its marketplace to `workflows` produced 38
# failures on correct, unmodified pages, because `dev-workflows` contains it). The boundary
# class excludes `@`, `/` and `.` deliberately: the marketplace is named as
# `<plugin>@<marketplace>` and the container repo as `github.com/<owner>/<repo>/...`, and a
# boundary class containing either character would miss both forms.
check_identity_quarantine() {
  local root="$1" d="$1/$PLUGIN_REL/docs" tokens t f hit pat
  tokens=$( { grep -oE "^$CLI plugin marketplace add [^[:space:]]+" "$root/README.md" 2>/dev/null \
                | sed -E "s|^$CLI plugin marketplace add ||; s|/+\$||" | sed 'p; s|.*/||'
              grep -oE "^$CLI plugin install [^[:space:]]+@[^[:space:]]+" "$root/README.md" 2>/dev/null \
                | sed -E 's/.*@//'
              grep -oE "^$CLI plugin marketplace update [^[:space:]]+" "$root/README.md" 2>/dev/null \
                | sed -E "s|^$CLI plugin marketplace update ||"; } \
            | grep -vE '^[[:space:]]*$' | sort -u)
  if [ -z "$tokens" ]; then
    fail 10 "no marketplace or container-repo token could be derived from the repo-root README's '$CLI plugin ...' lines -- this check would examine nothing"
    return
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$f" = "$d/getting-started.md" ] && continue   # the single sanctioned exception
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      pat=$(printf '%s' "$t" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
      hit=$(grep -nE "(^|[^A-Za-z0-9_-])$pat([^A-Za-z0-9_-]|\$)" "$f" 2>/dev/null | head -1)
      [ -n "$hit" ] && fail 10 "${f#$root/}:${hit%%:*} names '$t' -- no page under $PLUGIN_REL/docs/ may name the marketplace this plugin ships from or the repository that contains it (getting-started.md is the only exception); a fork of this repo inherits the wrong one"
    done <<<"$tokens"
  done < <(find "$d" -name '*.md' 2>/dev/null | sort)
}

# ------------------------------------------------------------------ check 11
# Merge-clause adoption, single-plugin form. ai-workflows binds this rule to a NAMED
# command family (a `<plugin>:<family>*` glob read off next-phase-offer.md's own scope
# line) because several plugins there share one corpus and the rule binds only some of
# each plugin's commands. This edition ships one plugin and its scope line says so in
# prose -- "every next-step offer this plugin prints" -- naming no glob at all, which is
# correct for a single-plugin edition and not a defect to fix: $PLUGIN_REL IS the family,
# so the glob is unconditionally `*` here and `scope_family`'s glob-extraction (and the
# cross-plugin HANDOFF_PLUGIN_RELS membership check it feeds in ai-workflows, which has no
# meaning where there is only one plugin to be a member of anything) are both skipped.
#
# An offer that names a downstream command whose Phase 0 `require-on-main` gate targets an
# artifact THIS run writes must carry the `<merge-clause>` placeholder, because that command
# stops while this phase's pull request is open. The placeholder and its resolution table
# live in $REF_DIR/next-phase-offer.md; the row-F target table lives in
# $REF_DIR/phase-handoff.md §3.4.
#
# THREE RELATIONS, every one derived:
#   targets -- what each command runs `require-on-main` against, read out of
#              phase-handoff.md's §3.4 table (the `Input` column's backticked *.md, by
#              basename). A prose target with no backticked .md token (e.g. "the ARD") is
#              not a candidate -- the extractor is selective by construction, not a claim
#              that every row names a decidable artifact.
#   writers -- what each command declares it hands off, read out of its own
#              `deliverable_paths` = ... `title:` span (same basename form).
#   offers  -- every `choices:` option a command prints, and whether it carries
#              `<merge-clause>`.
# An offer is REQUIRED to carry the clause when writers(offerer) and targets(offered)
# intersect. Any relation coming up empty is a FAILURE, not a skip -- a reworded handoff
# sentence or a renamed family turns the build red instead of quietly narrowing coverage.
check_merge_clause() {
  local root="$1" p="$1/$PLUGIN_REL"
  local ref="$p/$REF_DIR/next-phase-offer.md" ph="$p/$REF_DIR/phase-handoff.md"
  local targets writers offers route_n=0 req_n=0
  local y f ln has t need needt prose_artifact

  [ -f "$ref" ] || { fail 11 "$PLUGIN_REL/$REF_DIR/next-phase-offer.md is missing -- it owns the <merge-clause> placeholder and its resolution table"; return; }
  [ -f "$ph" ]  || { fail 11 "$PLUGIN_REL/$REF_DIR/phase-handoff.md is missing -- its §3.4 table is where each command's require-on-main target is declared"; return; }

  # targets: one `<command>|<artifact-basename>` line per §3.4 table cell. Column 2 (Input)
  # only -- column 3 (pre-existing absent behaviour) routinely cites files that are not gate
  # targets, the same drift ai-workflows' row-F extractor guards against on column 3 there.
  targets=$(awk -F'|' '
    /^\| `?[\/a-zA-Z]/ {
      c1 = $2; c2 = $3; n = 0
      while (match(c2, /`[^`]*\.md`/)) {
        t = substr(c2, RSTART + 1, RLENGTH - 2); sub(/.*\//, "", t); tg[++n] = t
        c2 = substr(c2, RSTART + RLENGTH)
      }
      if (n == 0) next
      # Caller names appear as `/name` (claude/mgd) or `name:` (copilot); strip either marker.
      while (match(c1, /\/[a-zA-Z][a-zA-Z0-9-]*|[a-zA-Z][a-zA-Z0-9-]*:/)) {
        cmd = substr(c1, RSTART, RLENGTH); c1 = substr(c1, RSTART + RLENGTH)
        gsub(/^\/|:$/, "", cmd)
        for (i = 1; i <= n; i++) print cmd "|" tg[i]
      }
    }' "$ph" | sort -u)
  [ -n "$targets" ] || { fail 11 "$PLUGIN_REL/$REF_DIR/phase-handoff.md's §3.4 table yielded no require-on-main target -- the EXTRACTOR has drifted, not the table; fix the parser, never the rows"; return; }

  # FAMILY, single-plugin form. ai-workflows reads the family off a `<plugin>:<family>*`
  # glob on next-phase-offer.md's scope line; this edition's scope line names no glob at
  # all -- it says, in prose, "every next-step offer this plugin prints", and immediately
  # follows with the one sentence that actually enumerates who that is today: "Six offers
  # carry it -- `/idea`'s *Handoff: adaptive next-phase offer* phase, `/create-vi`'s and
  # `/update-vi`'s *Next steps* phases, `/create-ard`'s *Next-step offer (adaptive)* phase,
  # and the `### Next step` sections of `/specify` and `/design`." (Copilot's edition names
  # the same six with its own `name:` trigger form.) That sentence, not a glob, IS this
  # edition's family declaration, and it is read from there rather than hand-copied here so
  # a future adopter is one sentence edit away from being covered, exactly as adding a glob
  # would be in the multi-plugin form -- which is how `/idea`, the sixth, was added.
  local adopt_sentence family
  adopt_sentence=$(grep -oE '[A-Z][a-z]+ offers? carr(y|ies) it — [^.]*\.' "$ref" | head -1)
  [ -n "$adopt_sentence" ] \
    || { fail 11 "$PLUGIN_REL/$REF_DIR/next-phase-offer.md's scope paragraph no longer names its adopting commands in the one sentence this check reads (\"<N> offers carry it — ...\") -- with no family, this check would examine no offer at all"; return; }
  family=$(printf '%s' "$adopt_sentence" | grep -oE '`/?[a-zA-Z][a-zA-Z0-9-]*:?`' | tr -d '`:/' | sort -u)
  [ -n "$family" ] \
    || { fail 11 "$PLUGIN_REL/$REF_DIR/next-phase-offer.md's adopting-commands sentence names no command this check can parse -- the EXTRACTOR has drifted or the sentence was reworded; fix the parser, never the sentence"; return; }

  while IFS= read -r y; do
    [ -n "$y" ] || continue
    grep -qxF -- "$y" <<<"$family" || continue
    f=$(cmd_file "$p" "$y"); [ -f "$f" ] || continue
    route_n=$((route_n + 1))
    # offers: one `<line>|<offered-command>|<0|1 carries the placeholder>` per choices option,
    # scoped to the command's own NEXT-STEP SECTION (the last heading matching
    # `Next step(s)` or `Next-step offer`, to end of file) -- a mid-run choices array
    # (an escalation, a validation refusal) routinely NAMES a pipeline command in its option
    # text without OFFERING it as this run's forward route, and scanning the whole file
    # mistakes that mention for an offer. Five of this edition's six adopting commands
    # name their forward route under exactly such a heading; `/idea`'s sits under its
    # Phase 5 *Handoff: adaptive next-phase offer* heading, which this pattern does not
    # match, so `/idea` takes the whole-file fallback below. That fallback can only widen
    # what is examined, never narrow it -- a false positive, never a missed offer.
    section=$(awk '
      /^##[#]?[[:space:]]+.*[Nn]ext[-[:space:]][Ss]teps?/ { buf = ""; from = NR; next }
      { if (from) buf = buf $0 "\n" }
      END { printf "%s", buf }
    ' "$f")
    [ -n "$section" ] || section=$(cat "$f")   # no such heading: fall back to the whole file
                                                 # rather than silently examining nothing
    offlineno=$(awk '/^##[#]?[[:space:]]+.*[Nn]ext[-[:space:]][Ss]teps?/{n=NR} END{print n+0}' "$f")

    # writers: the `deliverable_paths` = ... `title:` span's backticked *.md basenames.
    # Capture begins AFTER the `deliverable_paths` token itself, on the line it appears on:
    # that line routinely also carries an earlier reference-file citation (e.g.
    # ``${CLAUDE_PLUGIN_ROOT}/references/phase-handoff.md` `) which is not a deliverable and
    # must not be read as one. And it ends AT the `title:` token, not at the end of the line
    # carrying it: this edition writes the declaration on one long unwrapped line whose tail
    # routinely names the deliverable again in prose, which would keep a reworded
    # declaration looking extractable.
    writers=$(awk '
      /`deliverable_paths`[[:space:]]*=/ {
        span = 1; k = 0
        line = $0
        p = index(line, "`deliverable_paths`"); line = substr(line, p)
        if ((q = index(line, "`title:")) > 0) line = substr(line, 1, q - 1)
        while (match(line, /`[^`]*\.md`/)) {
          w = substr(line, RSTART + 1, RLENGTH - 2); sub(/.*\//, "", w); print w
          line = substr(line, RSTART + RLENGTH)
        }
        if ($0 ~ /`title:/ || ++k > 20) span = 0
        next
      }
      span {
        line = $0
        if ((q = index(line, "`title:")) > 0) line = substr(line, 1, q - 1)
        while (match(line, /`[^`]*\.md`/)) {
          w = substr(line, RSTART + 1, RLENGTH - 2); sub(/.*\//, "", w); print w
          line = substr(line, RSTART + RLENGTH)
        }
        if ($0 ~ /`title:/ || ++k > 20) span = 0
      }' "$f" | sort -u)

    # offers: one `<line>|<offered-command>|<0|1 carries the placeholder>` per choices option.
    # Bracket-depth-bounded, quote-aware -- same discipline as check_choices_arity's parser,
    # and for the same reason: a naive scan with no closing bound keeps reading past the
    # array's `]` into unrelated prose later on the same (often very long, unwrapped) line,
    # and a quoted command mentioned there is misread as an offered option.
    offers=$(awk -v Y="$y" -v OFF="$offlineno" '
      {
        s = $0
        while ((p = index(s, "choices: [")) > 0) {
          rest = substr(s, p + 10)
          depth = 1; inq = 0; buf = ""; opts_n = 0; j = 1; L = length(rest)
          while (j <= L && depth > 0) {
            c = substr(rest, j, 1)
            if (inq) {
              if (c == "\\") { buf = buf c substr(rest, j+1, 1); j += 2; continue }
              else if (c == "\"") { inq = 0; opts_n++; opt[opts_n] = buf; buf = "" }
              else buf = buf c
            } else {
              if (c == "\"") inq = 1
              else if (c == "[") depth++
              else if (c == "]") depth--
            }
            j++
          }
          for (k = 1; k <= opts_n; k++) {
            optv = opt[k]
            tmp = optv
            # Two command-reference forms coexist across editions: a leading-slash form
            # (`/name`, `/plugin:name`) and a bare colon-trigger form with no slash at all
            # (`name:`, the Copilot edition form) -- both are scanned for in one pass so
            # the shared body does not need an edition switch here.
            while (match(tmp, /\/[a-zA-Z][a-zA-Z0-9:_-]*|[a-zA-Z][a-zA-Z0-9-]*:/)) {
              cand = substr(tmp, RSTART, RLENGTH)
              gsub(/^\//, "", cand)      # /name or /plugin:name -> name or plugin:name
              if (cand ~ /:.+/) sub(/^[^:]*:/, "", cand)   # plugin:name -> name (colon NOT at the end)
              sub(/:$/, "", cand)        # name: -> name (bare trailing colon)
              tmp = substr(tmp, RSTART + RLENGTH)
              if (cand != "" && cand != Y) {
                has = (index(optv, "<merge-clause>") > 0) ? 1 : 0
                print (NR + OFF) "|" cand "|" has
              }
            }
          }
          s = substr(rest, j)
        }
      }' <<<"$section")

    # writers-empty guard, scoped to avoid a false positive this edition's real tree
    # actually has: three of the six family members (create-vi, create-ard, update-vi)
    # declare a `deliverable_paths` = that is DELIBERATELY prose ("the VI file", "the ARD
    # file(s)", "the canonical VI file ...") because their deliverable's filename is
    # templated (`<KEY>_<slug>.md`, `*_ARD.md`) and has no fixed basename for an extractor
    # to find -- and phase-handoff.md's own table names both only as `the VI` / `the ARD`
    # prose for the same reason, so neither ever appears as a literal target either. That is
    # a real, inspectable authoring convention (grep the three files for `the (VI|ARD)` in
    # their own `deliverable_paths` = span), not a guess, and it is what `prose_artifact`
    # below tests -- a command whose span matches it is exempt from this guard entirely.
    # A command whose span matches NEITHER convention (a genuine rewording, like replacing
    # `deliverable_paths` = with `deliverable_paths` lists) still falls through to the fail
    # below, which is the defect this guard exists to catch: an offer silently dropping out
    # of coverage because its writer set no longer extracts.
    prose_artifact=0
    awk '
      /`deliverable_paths`[[:space:]]*=/ {
        line = $0; p = index(line, "`deliverable_paths`"); line = substr(line, p)
        if (line ~ /= the ([a-zA-Z]+ )?(VI|ARD)( file| dir)?/) { print "prose"; exit }
      }' "$f" | grep -q prose && prose_artifact=1

    if [ -z "$writers" ] && [ "$prose_artifact" != 1 ]; then
      fail 11 "$CMD_DIR/$y$CMD_SUFFIX makes a choices: offer but its \`deliverable_paths\` = ... \`title:\` span yields no path -- the EXTRACTOR has drifted or the handoff sentence was reworded, and every offer this command makes has stopped being checked; fix the parser or restore the declaration, never the offers"
      continue
    fi

    while IFS='|' read -r ln x has; do
      [ -n "$ln" ] || continue
      need=0; needt=""
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        grep -qxF -- "$t" <<<"$writers" && { need=1; needt="$t"; break; }
      done < <(grep -F "$x|" <<<"$targets" | sed 's/^[^|]*|//')
      [ "$need" = 1 ] || continue
      req_n=$((req_n + 1))
      [ "$has" = 1 ] || fail 11 "$CMD_DIR/$y$CMD_SUFFIX:$ln offers /$x with no <merge-clause>, and this run writes '$needt' -- the artifact /$x's require-on-main gate targets, so that command stops while this phase's pull request is open ($PLUGIN_REL/$REF_DIR/next-phase-offer.md owns the placeholder and its resolution table)"
    done <<<"$offers"
  done < <(cmd_names "$p")

  [ "$route_n" -gt 0 ] || fail 11 "$PLUGIN_REL/$REF_DIR/next-phase-offer.md binds the <merge-clause> rule to a family that matches no command in $CMD_DIR/ -- the family was renamed or retired and this check now examines nothing"
  # NOT a req_n > 0 vacuity guard (unlike the multi-plugin form): on this tree today, every
  # family offer whose target has a LITERAL filename (specify's and design's `/implement`
  # family and `/epics`/`/design` targets, and idea's `/create-vi` -> `idea.md`) is prose,
  # which "a sweep for arrays does not see" by the reference's own words, and every family
  # offer that IS a `choices:` array
  # (create-vi's, create-ard's, update-vi's) names a target with no literal filename at all
  # (the VI, the ARD -- both templated, never a fixed basename). req_n legitimately comes up
  # 0 under that shape, and asserting it be nonzero would fail a tree with no violation in
  # it. What is NOT skipped: every offer this loop DOES find with a decidable (literal,
  # intersecting) target still has its clause checked above, loudly, per-offer.
}

# ------------------------------------------------------------------ check 12
# Every `choices:` array the plugin writes is an AskUserQuestion call, and that
# tool's schema is `minItems: 2, maxItems: 4` with "There should be no 'Other'
# option, that will be provided automatically". A five-option array is not a long
# prompt -- it is a tool call rejected at validation, so the run cannot present it
# at all, while `escalation-rules.md` simultaneously requires the array be shown
# verbatim. That contradiction shipped here until 2.63.0: a convention stated in
# fifteen command files ("last choice is always \"Other... (describe)\"") authored
# 121 duplicate options across 26 files and pushed 29 arrays past the cap.
#
# The parser is bracket-matched and quote-aware, NOT a non-greedy regex. A naive
# `choices:\s*\[(.*?)\]` stops at the first `]` -- including one inside an option
# string ("Use <dir> [+ <sub>]") -- and silently skips that array. A checker that
# cannot see the worst offenders is worse than none, so this one matches brackets.
#
# CHANGELOG.md is excluded: it quotes retired arrays as history.
#
# What this CANNOT see, stated so nobody mistakes green for safe: an array built
# at run time -- the Epic picker `/specify`, `/design` and `/implement` share, or
# /idea's write-path gate assembled from a table of rows -- has no literal options
# to count. Its cap lives in `references/jira-input-resolution.md` (*The cap*) and
# `references/escalation-rules.md` §0, and is held by review, not by this gate.
check_choices_arity() {
  local root="$1" hits
  [ "$HAS_CHOICE_CAP" = 1 ] || return 0
  [ "$HAVE_PY" = 1 ] || { note "python3 not found; check 12 (choices arity) skipped"; return 0; }
  hits=$(python3 - "$root/$PLUGIN_REL" <<'PYEOF'
import re, sys, io, glob, os
root = sys.argv[1]
START = re.compile(r'choices:\s*\[')
def arrays(text):
    for m in START.finditer(text):
        i = m.end() - 1
        depth = 0; j = i; inq = False; esc = False; opts = []; cur = None
        while j < len(text):
            c = text[j]
            if inq:
                if esc: esc = False; cur.append(c)
                elif c == '\\': esc = True
                elif c == '"': inq = False; opts.append(''.join(cur)); cur = None
                else: cur.append(c)
            else:
                if c == '"': inq = True; cur = []
                elif c == '[': depth += 1
                elif c == ']':
                    depth -= 1
                    if depth == 0:
                        yield (m.start(), opts); break
                elif text[j:j+2] == '\n\n': break
            j += 1
for f in sorted(glob.glob(os.path.join(root, '**', '*.md'), recursive=True)):
    if os.path.basename(f) == 'CHANGELOG.md': continue
    s = io.open(f, encoding='utf-8').read()
    rel = os.path.relpath(f, os.path.dirname(root.rstrip('/')))
    for start, opts in arrays(s):
        if not opts: continue
        n = s[:start].count('\n') + 1
        if len(opts) > 4:
            print("%s:%d has %d options (AskUserQuestion renders at most 4)" % (rel, n, len(opts)))
        if len(opts) < 2:
            print("%s:%d has %d option(s) (AskUserQuestion needs at least 2)" % (rel, n, len(opts)))
        for o in opts:
            if o.strip().lower().startswith('other'):
                print("%s:%d authors its own \"%s\" option (the harness supplies it)" % (rel, n, o[:40]))
PYEOF
)
  [ -n "$hits" ] || return 0
  local h; while IFS= read -r h; do [ -n "$h" ] && fail 12 "$h"; done <<<"$hits"
}

# Checks 13 (vendor tokens) and 14 (foreign identity) sit here in ai-workflows' numbering;
# not ported here -- see the edition-config block's note at the top of this file.

# ------------------------------------------------------------------ check 15
# Index membership. Every command must be reachable from THREE surfaces: the docs index
# (docs/README.md), the plugin README's role table, and the workflow diagram
# (docs/workflow.md's mermaid graph) -- and the diagram is asserted separately from the
# page's prose, because the prose below a diagram is where a command lands when someone
# adds it in a hurry. A review once removed a command from all three surfaces at once and
# the gate passed -- which is the shape every check here protects against: one surface
# standing in for all three lets a real omission hide behind the two that still mention it.
#
# A node may be written bare (`/idea`) or namespaced (`plugin:name`) or as a bare colon
# trigger (`name:`, the Copilot edition form) -- the boundary class `(/|:)` before the
# name and `([^a-zA-Z0-9_-]|$)` after it covers all three without matching a longer name
# that merely starts with this one's (the same prefix hazard check 9 guards elsewhere).
#
# DIAGRAM EXEMPTION: a command the diagram's OWN preceding prose (the text above the
# ```mermaid fence in workflow.md) names as omitted is exempt from the DIAGRAM assertion
# only. Names are read from the SENTENCE that says they are omitted -- one containing the
# word "omitted" -- never from the whole intro: an intro routinely mentions pipeline
# commands too ("`/document` and `/release-notes` close it out"), and reading every
# backticked name in it exempted exactly the commands the diagram exists to show. Read
# from there, per edition, rather than from a shared
# reference, because whether a diagram omits its maintenance/anytime commands at all is
# itself an edition's own documented choice (mgd's and ai-workflows' own dev-workflows
# diagrams omit nothing and say so; this edition's diagram is drawn strictly from the
# pipeline routing graph and says so). A command still must appear in the docs index and
# the README role table; only diagram membership is relaxed, and only for a name that
# prose actually names -- never a blanket skip. Two forms are read: a literal backticked
# name (`vuln:`, `/vuln`) and the generic phrase "guideline reviewer(s)", which resolves to
# every command whose own name contains `guideline-reviewer` -- this edition's prose names
# the two reviewers generically rather than by name, and a literal-only reading would miss
# them both.
check_index_membership() {
  local root="$1" p="$1/$PLUGIN_REL" n f diagram notnode intro
  diagram=$(awk '/^```mermaid/{f=1;next} /^```/{f=0} f' "$p/docs/workflow.md" 2>/dev/null)
  [ -n "$diagram" ] \
    || { fail 15 "docs/workflow.md holds no mermaid diagram -- this check would examine nothing"; return; }
  # The intro's sentences, split at a full stop followed by a space; only those saying
  # their names are omitted are read. A period inside a code span (`next-phase-offer.md`)
  # is followed by a letter, not a space, so it does not split a sentence.
  intro=$(awk '/^```mermaid/{exit} {print}' "$p/docs/workflow.md" 2>/dev/null \
    | tr '\n' ' ' | awk '{ n = split($0, s, /\. /); for (i = 1; i <= n; i++) if (s[i] ~ /omitted/) print s[i] }')
  notnode=$(printf '%s' "$intro" | grep -oE '`/?[a-zA-Z][a-zA-Z0-9*-]*:?\*?`' | tr -d '`:*/' | sort -u)
  if grep -qiE 'guideline reviewers?' <<<"$intro"; then
    notnode=$(printf '%s\n%s\n' "$notnode" "$(cmd_names "$p" | grep 'guideline-reviewer')" | sort -u)
  fi
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    # Two name-reference forms coexist across editions: a leading marker (`/name`,
    # `plugin:name`) and a bare trailing colon trigger with no leading marker at all
    # (`name:`, the Copilot edition form) -- matched by requiring EITHER a `/` or `:`
    # immediately before the name OR a `:` immediately after it.
    grep -qE "((/|:)$n([^a-zA-Z0-9_-]|\$)|(^|[^a-zA-Z0-9_-])$n:)" "$p/docs/README.md" || fail 15 "$n is not listed in docs/README.md"
    grep -qE "((/|:)$n([^a-zA-Z0-9_-]|\$)|(^|[^a-zA-Z0-9_-])$n:)" "$p/README.md"      || fail 15 "$n is not listed in $PLUGIN_REL/README.md"
    grep -qxF -- "$n" <<<"$notnode" && continue   # diagram exemption -- see header
    printf '%s' "$diagram" | grep -qE "((/|:)$n([^a-zA-Z0-9_-]|\$)|(^|[^a-zA-Z0-9_-])$n:)" \
      || fail 15 "$n does not appear in docs/workflow.md's diagram, which says it shows every command (prose below it does not count -- that is where the last one went missing)"
  done < <(cmd_names "$p")
}

# Check 16 (loader contract) sits here in ai-workflows' numbering; not ported here -- see
# the edition-config block's note at the top of this file.

# ------------------------------------------------------------------ check 17
# Dispatch authority. Every agent whose tool list grants `Task` must carry a NEVER-dispatch
# rule naming its one sanctioned subagent -- the anchor sentence "NEVER dispatch any
# subagent other than `<name>`. That one dispatch is your entire `Task` authority." -- so an
# agent that CAN dispatch is never silent about what it is allowed to dispatch. The reverse
# direction matters too: an agent carrying the sentence but granted no `Task` is stale prose
# claiming an authority the harness would refuse.
#
# SCOPE is agents/ only, one flat directory, under $PLUGIN_REL -- commands/skills carry
# their own `allowed-tools:` frontmatter but are outside this check's finding. The tool-list
# key is read as either `tools:` or `allowed-tools:`, whichever the frontmatter uses.
#
# VACUITY GUARD: if the scan finds not one agent carrying `Task`, that is the frontmatter
# parsing having silently stopped matching, not a tree with nothing to dispatch -- fail
# loudly rather than pass.
check_dispatch_authority() {
  local root="$1" p="$1/$PLUGIN_REL/agents" f frontmatter toolsline has_task has_rule seen=0 rp
  # The anchor sentence and the tool-list token are both case-sensitive to the EDITION's own
  # frontmatter convention: Claude/mgd quote capitalised tool names (`"Task"`) and the
  # anchor's own prose says "Task"; Copilot's `tools: [...]` list is bare and lower-case
  # (`task`) and its own anchor prose says "task" to match. Both are matched
  # case-insensitively so the one shared regex covers either convention without an edition
  # switch.
  local anchor='NEVER dispatch any subagent other than `[^`]+`\. That one dispatch is your entire `[Tt]ask` authority\.'
  [ -d "$p" ] || { fail 17 "$PLUGIN_REL/agents does not exist -- this check would examine nothing"; return; }
  for f in "$p"/*.md; do
    [ -e "$f" ] || continue
    rp="${f#$root/}"
    frontmatter=$(awk 'NR==1 && $0=="---"{infm=1;next} infm && $0=="---"{exit} infm{print}' "$f")
    toolsline=$(grep -E '^(tools|allowed-tools):' <<<"$frontmatter" | head -1)
    has_task=0
    case "$toolsline" in
      *'"Task"'*|*'"task"'*) has_task=1 ;;
      *)
        # Bare, unquoted bracket-list form (`tools: [view, glob, grep, bash, task]`): a
        # whole array ELEMENT equal to "task", word-bounded so a tool named e.g. "tasker"
        # does not match.
        case ",$(printf '%s' "$toolsline" | tr -d '[:space:][]')," in
          *,[Tt]ask,*) has_task=1 ;;
        esac
      ;;
    esac
    has_rule=0
    grep -qiE -- "$anchor" "$f" && has_rule=1

    if [ "$has_task" = 1 ]; then
      seen=$((seen + 1))
      [ "$has_rule" = 1 ] \
        || fail 17 "$rp carries \`Task\`/\`task\` in its tool list but no NEVER-dispatch rule naming its sanctioned subagent (the anchor sentence: \"NEVER dispatch any subagent other than \`<name>\`. That one dispatch is your entire \`Task\` authority.\") -- a Task-carrying agent with no sanctioned set stated is exactly how a mis-dispatch happens"
    fi
    if [ "$has_rule" = 1 ] && [ "$has_task" != 1 ]; then
      fail 17 "$rp carries a NEVER-dispatch rule naming a sanctioned subagent but its tool list grants no \`Task\`/\`task\` -- it declares a dispatch authority the harness would refuse, which is stale and will mislead a reader"
    fi
  done
  [ "$seen" -gt 0 ] \
    || fail 17 "no agent under $PLUGIN_REL/agents carries \`Task\`/\`task\` in its tool list -- this check would examine nothing, which means the frontmatter scan has drifted rather than the tree having nothing left to dispatch"
}

# ------------------------------------------------------------------ check 18
# CHECK 18 gates the one claim a changelog makes about ITSELF: a section headed `— Unreleased`
# says that it "has not been published yet" (dev-workflows' changelog header states that
# convention; no other plugin's changelog here carries such a section today). On the
# default branch that is false by construction -- the CLI fetches from main, so everything on
# main IS what users install. The section is published the moment the push lands.
#
# WHY IT IS NOT ON BY DEFAULT: on a feature branch an `— Unreleased` section is the CORRECT
# authoring state. So it runs only where the claim is actually false: ASSERT_PUBLISHED=1,
# which .github/workflows/validate-catalog.yml sets on a push to the default branch and
# nowhere else. The env var rather than a flag composes with the selftest's expect_*_env
# helpers, so the case that proves the gate STAYS QUIET without it can be written at all.
#
# SCOPE is every `plugins/*/CHANGELOG.md` in this edition's layout (one directory level
# above each plugin) -- every plugin in the catalog publishes from the same ref.
#
# WHAT IT DOES NOT MATCH: the bare Keep-a-Changelog `## [Unreleased]` form, nor a labelled
# historical section such as `### [Unreleased] (pre-plugin-split)`, which is correct content
# recording work predating a restructure.
check_published_changelog() {
  local root="$1" f rp seen=0 hit line n
  [ "${ASSERT_PUBLISHED:-}" = 1 ] || return 0
  for f in "$root"/$CHANGELOG_GLOB; do
    [ -e "$f" ] || continue
    seen=$((seen + 1))
    rp="${f#$root/}"
    # `##`-or-deeper heading, a bracketed version, an em dash or hyphen, then Unreleased.
    # An alternation, never a bracket expression: `[—-]` is a set of BYTES in a C/POSIX
    # locale (a container with LANG unset), where the three-byte em dash can never match it
    # and the check went silently inert on the form this repo actually writes.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      n="${line%%:*}"
      hit="${line#*:}"
      fail 18 "$rp:$n is headed \`${hit# }\` on a ref that publishes it -- an \`— Unreleased\` section says it \"has not been published yet\", and everything on the default branch is what gets installed. Date it with the day of the push that publishes it"
    done <<EOF
$(grep -nE '^#{2,}[[:space:]]+\[[^]]+\][[:space:]]*(—|-)[[:space:]]*Unreleased[[:space:]]*$' "$f" || true)
EOF
  done
  [ "$seen" -gt 0 ] \
    || fail 18 "no $CHANGELOG_GLOB found at all -- this check would examine nothing, which means the glob has drifted rather than the marketplace having shipped no changelog"
}

# Check 19 (edition-forbidden denylist) sits here in ai-workflows' numbering; not ported
# here -- see the edition-config block's note at the top of this file.

# ------------------------------------------------------------------ selftest
# One passing fixture tree; each check gets a mutation of a fresh copy. Asserting
# the exit code alone would let a mutation that trips a DIFFERENT check register
# as success, so each case also asserts which check fired.
selftest() {
  local here fixture tmp rc=0
  here=$(cd "$(dirname "$0")" && pwd)
  fixture="$here/fixtures/docs/pass"
  [ -d "$fixture" ] || { echo "SELFTEST FAIL: fixture tree missing at $fixture" >&2; exit 2; }
  # Check 18's arming flag is neutralised here so each case controls it explicitly, and the
  # two that need it armed set it through expect_fail_env / expect_pass_after_env. Without
  # this the selftest inherits the caller's own value, and the case proving the gate STAYS
  # QUIET off a publishing ref fails spuriously for whoever runs --selftest with
  # ASSERT_PUBLISHED=1 already exported -- found by doing exactly that.
  export ASSERT_PUBLISHED=""

  expect_pass() {
    tmp=$(mktemp -d); cp -R "$fixture/." "$tmp/"
    if "$0" --root "$tmp" >/dev/null 2>&1; then printf 'ok    %s\n' "$1"
    else printf 'FAIL  %s: expected exit 0\n' "$1"; rc=1; fi
    rm -rf "$tmp"
  }
  expect_pass_after() { # <description> <mutation-shell> -- the mutation must leave every check passing
    tmp=$(mktemp -d); cp -R "$fixture/." "$tmp/"
    ( cd "$tmp" && eval "$2" )
    if "$0" --root "$tmp" >/dev/null 2>&1; then printf 'ok    %s\n' "$1"
    else printf 'FAIL  %s: expected exit 0\n' "$1"; rc=1; fi
    rm -rf "$tmp"
  }
  expect_fail() { # <description> <check-number> <mutation-shell>
    tmp=$(mktemp -d); cp -R "$fixture/." "$tmp/"
    ( cd "$tmp" && eval "$3" )
    local out; out=$("$0" --root "$tmp" 2>&1); local got=$?
    # The colon is load-bearing: fail() prints "FAIL check <n>: <message>", and without it
    # "FAIL check 1" would also match a "FAIL check 10" line, letting a check-10 failure
    # satisfy a check-1 case. Every check number past 9 makes that collision reachable.
    if [ "$got" -eq 1 ] && grep -q "FAIL check $2:" <<<"$out"; then
      printf 'ok    %s (check %s fired)\n' "$1" "$2"
    else
      printf 'FAIL  %s: expected exit 1 with "FAIL check %s", got exit %s\n' "$1" "$2" "$got"; rc=1
    fi
    rm -rf "$tmp"
  }
  expect_fail_env() { # <description> <check-number> <env-assignments> <mutation-shell>
    tmp=$(mktemp -d); cp -R "$fixture/." "$tmp/"
    ( cd "$tmp" && eval "$4" )
    local out; out=$(eval "export $3"; "$0" --root "$tmp" 2>&1); local got=$?
    if [ "$got" -eq 1 ] && grep -q "FAIL check $2:" <<<"$out"; then
      printf 'ok    %s (check %s fired)\n' "$1" "$2"
    else
      printf 'FAIL  %s: expected exit 1 with "FAIL check %s", got exit %s\n' "$1" "$2" "$got"; rc=1
    fi
    rm -rf "$tmp"
  }
  expect_pass_after_env() { # <description> <env-assignments> <mutation-shell>
    tmp=$(mktemp -d); cp -R "$fixture/." "$tmp/"
    ( cd "$tmp" && eval "$3" )
    if ( eval "export $2"; "$0" --root "$tmp" ) >/dev/null 2>&1; then printf 'ok    %s\n' "$1"
    else printf 'FAIL  %s: expected exit 0\n' "$1"; rc=1; fi
    rm -rf "$tmp"
  }

  expect_pass "the unmutated fixture passes every check"
  expect_fail "a broken relative link is rejected"  1 "sed -i.bak 's|(reference/hooks.md)|(reference/nope.md)|' $PLUGIN_REL/docs/README.md"
  expect_fail "a broken link in the plugin README is rejected" 1 "sed -i.bak 's|(docs/README.md)|(docs/NOPE.md)|' $PLUGIN_REL/README.md"
  expect_fail "a broken anchor is rejected"         2 "sed -i.bak 's|(getting-started.md#install)|(getting-started.md#no-such-heading)|' $PLUGIN_REL/docs/README.md"
  expect_fail "an orphan page is rejected"          3 "printf '# Orphan\n\nUnreachable.\n' > $PLUGIN_REL/docs/orphan.md"
  expect_fail "an undocumented command is rejected" 4 "mkdir -p $(dirname $(cmd_file $PLUGIN_REL delta)) 2>/dev/null; printf -- '---\nname: delta\n---\n' > $(cmd_file $PLUGIN_REL delta)"
  expect_fail "a drifted subtree count is rejected" 4 "sed -i.bak 's|\`handoff/\` (2)|\`handoff/\` (3)|' $PLUGIN_REL/docs/reference/references.md"
  expect_fail "an undocumented skill is rejected"    4 "mkdir -p $PLUGIN_REL/skills/epsilon && printf -- '---\nname: epsilon\n---\n' > $PLUGIN_REL/skills/epsilon/SKILL.md"
  expect_fail "an undocumented env var is rejected" 5 "printf 'Reads \$NEW_SETTABLE_VAR here.\n' >> $(cmd_file $PLUGIN_REL alpha)"
  expect_pass_after "a 190-character cell of multibyte characters is accepted (check 6 counts characters, not bytes)" \
    "printf '\\n| a | %s |\\n|---|---|\\n| b | c |\\n' \"\$(printf '\\342\\206\\222%.0s' \$(seq 190))\" >> $PLUGIN_REL/docs/reference/hooks.md"
  expect_fail "an over-long table cell is rejected" 6 "awk 'BEGIN{s=\"\"; while(length(s)<260) s=s \"x\"; printf \"\\n| a | %s |\\n|---|---|\\n| b | c |\\n\", s}' >> $PLUGIN_REL/docs/reference/hooks.md"
  expect_fail "a drifted install block is rejected" 7 "sed -i.bak 's|$CLI plugin install ${PLUGIN_REL##*/}@fixture-plugins|$CLI plugin install ${PLUGIN_REL##*/}@drifted|' $PLUGIN_REL/docs/getting-started.md"
  expect_fail "a documented nonexistent skill is rejected" 4 "printf '\n| \`ghost-skill\` | Yes | fixture mutation |\n' >> $PLUGIN_REL/docs/reference/references.md"
  expect_fail "a broken link in the ROOT README is rejected" 1 "sed -i.bak 's|($PLUGIN_REL/README.md)|($PLUGIN_REL/NOPE.md)|' README.md"
  expect_fail "a broken bare #anchor is rejected"   2 "printf '\n[self](#no-such-heading-here)\n' >> $PLUGIN_REL/docs/README.md"
  expect_fail "a documented nonexistent agent is rejected"     4 "printf '\n| \`ghost-agent\` | fixture |\n' >> $PLUGIN_REL/docs/reference/agents.md"
  expect_fail "a documented nonexistent hook is rejected"      4 "printf '\n| \`ghost-hook\` | fixture |\n' >> $PLUGIN_REL/docs/reference/hooks.md"
  expect_fail "a documented nonexistent reference file is rejected" 4 "printf '\n- \`ghost-ref.md\`\n' >> $PLUGIN_REL/docs/reference/references.md"
  expect_fail "a claimed-but-absent subtree is rejected"       4 "rm -rf $PLUGIN_REL/$REF_DIR/handoff"
  expect_fail "an undocumented NEW subtree is rejected"        4 "mkdir -p $PLUGIN_REL/$REF_DIR/brandnew && printf '# x\n' > $PLUGIN_REL/$REF_DIR/brandnew/x.md"
  expect_fail "a documented-but-unread env var is rejected"    5 "printf '\n**\`\$PHANTOM_VAR\`** — never read anywhere.\n' >> $PLUGIN_REL/docs/reference/environment.md"
  expect_fail "an over-long cell in the ROOT README is rejected" 6 "awk 'BEGIN{s=\"\"; while(length(s)<260) s=s \"x\"; printf \"\n| a | %s |\n|---|---|\n| b | c |\n\", s}' >> README.md"
  # ${CLI_VERBS##*|} is the LAST verb in the alternation -- every edition has one by
  # construction ("update" in both editions) -- so this is extracted by
  # check 7 in every edition, regardless of which verbs exist there. The target names
  # a line absent from the root README, so it is extracted AND counts as extra.
  expect_fail "an install line absent from the root README is rejected" 7 "printf '\n$CLI plugin ${CLI_VERBS##*|} ${PLUGIN_REL##*/}@extra-fixture-target\n' >> $PLUGIN_REL/docs/getting-started.md"
  expect_fail "a drifted prose count is rejected"              9 "mkdir -p $(dirname $(cmd_file $PLUGIN_REL gamma)) 2>/dev/null; printf -- '---\nname: gamma\n---\n' > $(cmd_file $PLUGIN_REL gamma) && printf -- '# /gamma\n\nPage.\n' > $PLUGIN_REL/docs/$DOC_CMD_DIR/gamma.md && sed -i.bak 's|($DOC_CMD_DIR/alpha.md)|($DOC_CMD_DIR/alpha.md), [\`/gamma\`]($DOC_CMD_DIR/gamma.md)|' $PLUGIN_REL/docs/README.md"
  # The agents direction was row-anchored; its three siblings (reference files, hooks, skills)
  # accepted a prose mention as "documented". This case pins the fix for the hook direction.
  expect_fail "a hook row replaced by a prose mention is rejected" 4 \
    "F=$PLUGIN_REL/docs/reference/hooks.md; h=\$(grep -oE '^\| \`[a-z-]+\`' \$F | head -1 | tr -d '|\` '); sed -i.bak \"/^| \\\`\$h\\\`/d\" \$F; printf 'The \`%s\` hook is described here in prose.\\n' \"\$h\" >> \$F"
  # The anchor's own case. The fixture has ONE command, and "forty-one" is a compound the
  # alternation does NOT enumerate whose tail is the true count: unanchored, the bare "one"
  # matches inside it and the wrong sentence passes (1 == 1); anchored, nothing matches at a
  # word boundary and check 9 fires with "no count sentence found". An ENUMERATED compound
  # ("twenty-one") would not discriminate -- leftmost-longest reads it whole either way.
  expect_fail "an unenumerated compound numeral is not read as its own tail" 9 "sed -i.bak 's|one slash commands|forty-one slash commands|' $PLUGIN_REL/README.md"
  expect_fail "a count sentence reworded away is rejected"     9 "sed -i.bak 's|one slash commands|a handful of slash commands|' $PLUGIN_REL/README.md"
  expect_fail "a wrong non-ASCII anchor is rejected"           2 "printf '\n[bad](#uber-config)\n' >> $PLUGIN_REL/docs/$DOC_CMD_DIR/alpha.md"
  expect_fail "a wrong duplicate-heading index is rejected"    2 "printf '\n[bad](#notes-2)\n' >> $PLUGIN_REL/docs/$DOC_CMD_DIR/alpha.md"
  expect_fail "a titled link to a missing file is rejected"    1 "printf '\n[bad](nope.md \"T\")\n' >> $PLUGIN_REL/docs/$DOC_CMD_DIR/alpha.md"
  expect_fail "an angle-bracket link to a missing file is rejected" 1 "printf '\n[bad](<nope.md>)\n' >> $PLUGIN_REL/docs/$DOC_CMD_DIR/alpha.md"
  expect_fail "an over-long INDENTED table cell is rejected"   6 "awk 'BEGIN{s=\"\"; while(length(s)<260) s=s \"q\"; printf \"\n  | a | %s |\n  |---|---|\n\", s}' >> $PLUGIN_REL/docs/reference/agents.md"
  expect_fail "a missing marketplace-add line is rejected"     7 "sed -i.bak '/$CLI plugin marketplace add/d' $PLUGIN_REL/docs/getting-started.md"
  expect_fail "a missing second required-verb line is rejected" 7 "sed -i.bak '/$CLI plugin ${CLI_REQUIRED##*|}/d' $PLUGIN_REL/docs/getting-started.md"
  expect_fail "getting-started not installing the plugin itself is rejected" 7 "sed -i.bak '/$CLI plugin install ${PLUGIN_REL##*/}@/d' $PLUGIN_REL/docs/getting-started.md"

  # Check 10 -- identity quarantine. Both mutations derive the offending token from the
  # fixture's own repo-root README, so the cases port to a fixture with a different
  # marketplace name rather than pinning this one.
  expect_fail "a container-repo URL on a docs page is rejected" 10 \
    "slug=\$(grep -oE '^$CLI plugin marketplace add [^ ]+' README.md | awk '{print \$NF}' | head -1); printf -- '\n[sibling plugin](https://github.com/%s/tree/main/plugins/extra-plugin)\n' \"\$slug\" >> $PLUGIN_REL/docs/reference/hooks.md"
  expect_fail "a marketplace name on a docs page is rejected" 10 \
    "mkt=\$(grep -oE '^$CLI plugin install [^ ]+@[^ ]+' README.md | sed 's/.*@//' | head -1); printf -- '\nInstall the sibling with \`$CLI plugin install extra-plugin@%s\`.\n' \"\$mkt\" >> $PLUGIN_REL/docs/reference/agents.md"
  # ...and the boundary itself: a LONGER identifier that merely contains the marketplace
  # name is not naming it, and must stay green.
  expect_pass_after "a longer identifier merely containing the marketplace name is accepted" \
    "mkt=\$(grep -oE '^$CLI plugin install [^ ]+@[^ ]+' README.md | sed 's/.*@//' | head -1); printf -- '\nThe mirror repository is called sub-%s-mirror and is not this marketplace.\n' \"\$mkt\" >> $PLUGIN_REL/docs/reference/agents.md"
  # ...and the vacuity guard: with no install block to derive from, check 10 has no token
  # set and must go RED rather than pass every page. (Check 7 fires on this mutation too;
  # the case asserts check 10 specifically.)
  expect_fail "an underivable identity token set is rejected" 10 \
    "sed -i.bak '/^$CLI plugin /d' README.md"

  # Check 11 -- merge-clause adoption, single-plugin form. The fixture's one family command
  # (`alpha`, named in next-phase-offer.md's adopting-commands sentence) offers
  # `/dev-workflows:omega`, whose phase-handoff.md row gates `alpha-deliverable.md` --
  # which alpha's own `deliverable_paths` declares.
  expect_fail "an offer that drops <merge-clause> is rejected" 11 \
    "sed -i.bak 's| <merge-clause>||' $(cmd_file $PLUGIN_REL alpha)"
  expect_fail "a family command whose handoff declares no path is rejected" 11 \
    "sed -i.bak 's|\`deliverable_paths\` = |\`deliverable_paths\` lists |' $(cmd_file $PLUGIN_REL alpha)"
  # The span ends AT `title:`, not at the end of the line carrying it. This edition writes
  # the declaration on one long unwrapped line whose tail routinely names the deliverable
  # again in prose (`/idea`: "`idea.md` is relocated but not on the default branch"); read
  # to end of line, that mention kept a reworded declaration looking extractable.
  expect_fail "a path named only after the title: token is not a declared path" 11 \
    "sed -i.bak 's|\`deliverable_paths\` = \`alpha-deliverable.md\`,|\`deliverable_paths\` = the fixture file, \`title: fixture handoff\`, which writes \`alpha-deliverable.md\`,|' $(cmd_file $PLUGIN_REL alpha)"
  # ...and it STARTS at the `deliverable_paths` token, not at the start of its line: the line
  # routinely cites a reference file first, which is not a deliverable.
  expect_fail "a path cited before the deliverable_paths token is not a declared path" 11 \
    "sed -i.bak 's|with \`deliverable_paths\` = \`alpha-deliverable.md\`,|per \`alpha-deliverable.md\`, with \`deliverable_paths\` = the fixture file,|' $(cmd_file $PLUGIN_REL alpha)"
  # The two vacuity guards. Each leaves the tree otherwise valid and makes the check examine
  # nothing, which must be RED.
  expect_fail "a reworded adopting-commands sentence is rejected" 11 \
    "sed 's|One offer carries it — .*section\\.|Nothing in this file names an adopter.|' $PLUGIN_REL/$REF_DIR/next-phase-offer.md > np.tmp && mv np.tmp $PLUGIN_REL/$REF_DIR/next-phase-offer.md"
  expect_fail "a row-F table with no gated artifact is rejected" 11 \
    "sed '/alpha-deliverable.md/d; /elsewhere.md/d' $PLUGIN_REL/$REF_DIR/phase-handoff.md > ph.tmp && mv ph.tmp $PLUGIN_REL/$REF_DIR/phase-handoff.md"

  # The cost subsystem (check 8, and check 9's cost-emitting-commands sentence) does not
  # exist in every edition -- check_cost_attribution and that half of check_prose_counts
  # both return immediately when HAS_COST=0, so a mutation that only a cost check can see
  # would never trip a failure there and would falsely report this selftest case itself as
  # broken. Skip the six cases that depend on the cost subsystem being active -- ALL FIVE
  # check-8 cases (including the emit-cost-call-site field-reorder, which check 8's
  # extractor-coverage assertion alone can see) plus the one check-9 cost-emitting-count case.
  if [ "$HAS_COST" = 1 ]; then
    expect_fail "a drifted emit-cost call site is rejected" 8 "sed -i.bak 's|\`command: /alpha\`, \`phase: fixture-phase\`, \`role: pm\`|\`command: /alpha\`, \`role: pm\`, \`phase: fixture-phase\`|' $(cmd_file $PLUGIN_REL alpha)"
    expect_fail "an unattributed emit-cost call is rejected" 8 "mkdir -p $(dirname $(cmd_file $PLUGIN_REL zeta)) 2>/dev/null; printf -- '---\nname: zeta\n---\n\nCall \`emit-cost\` with \`command: /zeta\`, \`phase: fixture-phase\`, \`role: pm\`, done.\n' > $(cmd_file $PLUGIN_REL zeta) && printf -- '# /zeta\n\nFixture page.\n' > $PLUGIN_REL/docs/$DOC_CMD_DIR/zeta.md && sed -i.bak 's|($DOC_CMD_DIR/alpha.md)|($DOC_CMD_DIR/alpha.md), [\`/zeta\`]($DOC_CMD_DIR/zeta.md)|' $PLUGIN_REL/docs/README.md"
    expect_fail "a section-7 row backed only by look-alike prose is rejected" 8 \
      "sed -i.bak 's|Call \`emit-cost\` with |Recorded as |' $(cmd_file $PLUGIN_REL alpha)"
    expect_fail "a drifted attributed role is rejected"      8 "sed -i.bak 's;| \`/alpha\` | fixture-phase | pm |;| \`/alpha\` | fixture-phase | pe |;' $PLUGIN_REL/$REF_DIR/cost-emission.md"
    expect_fail "a section-7 row for a non-emitting command is rejected" 8 "sed -i.bak 's;| \`/alpha\` | fixture-phase | pm |;| \`/alpha\` | fixture-phase | pm |\n| \`/omega\` | fixture-phase | pm |;' $PLUGIN_REL/$REF_DIR/cost-emission.md"
    expect_fail "a drifted cost-emitting count is rejected"  9 "sed -i.bak 's|One commands emit a cost entry|Five commands emit a cost entry|' $PLUGIN_REL/docs/reference/session-cost.md"
  else
    printf 'skip  6 cost cases (this edition has no cost subsystem)\n'
  fi

  # Check 10 -- one case per failure mode, plus the bracket-matching pair that is the whole
  # reason this check parses rather than regexes: a naive non-greedy `\[(.*?)\]` stops at the
  # `]` inside the option text and skips the array, so it passes the over-long case and the
  # legal case below for the same wrong reason.
  if [ "$HAS_CHOICE_CAP" = 1 ]; then
    expect_fail "a five-option choices array is rejected" 12 \
      "printf -- '\nchoices: [\"One\", \"Two\", \"Three\", \"Four\", \"Five\"]\n' >> $(cmd_file $PLUGIN_REL alpha)"
    expect_fail "a one-option choices array is rejected" 12 \
      "printf -- '\nchoices: [\"Only one\"]\n' >> $(cmd_file $PLUGIN_REL alpha)"
    expect_fail "an authored Other option is rejected" 12 \
      "printf -- '\nchoices: [\"One\", \"Two\", \"Other… (describe)\"]\n' >> $(cmd_file $PLUGIN_REL alpha)"
    expect_fail "an over-long array whose option text contains brackets is rejected" 12 \
      "printf -- '\nchoices: [\"Use <dir> [+ <sub>]\", \"Two\", \"Three\", \"Four\", \"Five\"]\n' >> $(cmd_file $PLUGIN_REL alpha)"
    expect_pass_after "a four-option array whose option text contains brackets is accepted" \
      "printf -- '\nchoices: [\"Use <dir> [+ <sub>]\", \"Two\", \"Three\", \"Four\"]\n' >> $(cmd_file $PLUGIN_REL alpha)"
  else
    printf 'skip  5 choices-arity cases (this edition'"'"'s prompt tool has no option cap)\n'
  fi

  # Check 15 -- index membership. The fixture ships one command (`alpha`), listed in
  # docs/README.md, the plugin README's role table, and docs/workflow.md's diagram. Each
  # mutation deletes or renames the line/token naming it, by matching the bare word rather
  # than a hardcoded leading-slash or trailing-colon form, so the cases port unchanged
  # across editions.
  expect_fail "a command missing from the plugin README is rejected" 15 \
    "sed -i.bak '/alpha/Id' $PLUGIN_REL/README.md"
  expect_fail "a command missing from the docs index is rejected" 15 \
    "sed -i.bak '/alpha/Id' $PLUGIN_REL/docs/README.md"
  expect_fail "a command missing from the workflow DIAGRAM is rejected" 15 \
    "sed -i.bak 's|alpha|removed|I' $PLUGIN_REL/docs/workflow.md"
  expect_fail "a workflow page with no diagram at all is rejected" 15 \
    "sed -i.bak 's|^\`\`\`mermaid\$|text|' $PLUGIN_REL/docs/workflow.md"
  # ...and the diagram exemption: a command the diagram's own intro prose names as omitted
  # must NOT be required in the diagram, but still must appear in the other two surfaces
  # (already true for alpha without any mutation, so the green case names alpha itself
  # rather than inventing a second command -- which would also have to be registered in
  # check 9's count sentence, a different check's surface this case is not about).
  expect_pass_after "a command the diagram's own intro prose exempts is not required in it" \
    "sed -i.bak 's|alpha|zzz-placeholder|I; s|Every command shown here\\.|Every command shown here, except \`/alpha\` (\`alpha:\`), which is not a pipeline node and is omitted below.|' $PLUGIN_REL/docs/workflow.md"
  # ...and its red twin: naming a command in the intro is not exempting it. Only the
  # sentence that says its names are omitted counts -- an intro that merely mentions a
  # command ("`/document` and `/release-notes` close it out") exempted both until this
  # case existed.
  expect_fail "a command the intro merely mentions is still required in the diagram" 15 \
    "sed -i.bak 's|alpha|zzz-placeholder|I; s|Every command shown here\\.|Every command shown here. \`/alpha\` (\`alpha:\`) opens the pipeline.|' $PLUGIN_REL/docs/workflow.md"

  # Check 17 -- dispatch authority. `beta` carries Task + the NEVER-dispatch rule naming
  # `eta`; `eta` carries neither.
  expect_fail "an agent granted Task with no NEVER-dispatch rule is rejected" 17 \
    "sed -i.bak '/NEVER dispatch any subagent other than/d' $PLUGIN_REL/agents/beta.md"
  expect_fail "an agent carrying the NEVER-dispatch rule without Task is rejected" 17 \
    "printf -- '\n- NEVER dispatch any subagent other than \`beta\`. That one dispatch is your entire \`Task\` authority.\n' >> $PLUGIN_REL/agents/eta.md"
  # THE DISCRIMINATOR: a decoy paragraph naming both "dispatch" and a literal quoted
  # \`"Task"\` must not be misread as a tools: grant by a whole-file grep.
  expect_pass_after "prose naming dispatch and a quoted \"Task\" grants no authority" \
    "printf -- '\nA reviewer might dispatch this agent expecting it to \`\"Task\"\` itself out eventually; it never does, and it invokes no subagent either.\n' >> $PLUGIN_REL/agents/eta.md"
  expect_fail "no agent carrying Task at all is rejected" 17 \
    "sed -i.bak 's|\"Task\"|\"Read\"|; s/, task]/, view]/' $PLUGIN_REL/agents/beta.md"

  # Check 18. The RED case and its GREEN TWIN are the whole point: the identical mutation
  # is a failure with ASSERT_PUBLISHED=1 and a PASS without it.
  expect_fail_env "an Unreleased changelog section on a publishing ref is rejected" 18 \
    "ASSERT_PUBLISHED=1" \
    "sed -i.bak 's|^## \[1.1.0\] — 2026-09-22|## [1.1.0] — Unreleased|' $PLUGIN_REL/CHANGELOG.md"
  expect_pass_after "the same Unreleased section is accepted off a publishing ref" \
    "sed -i.bak 's|^## \[1.1.0\] — 2026-09-22|## [1.1.0] — Unreleased|' $PLUGIN_REL/CHANGELOG.md"
  # A dated tree must still PASS with the gate armed.
  expect_pass_after_env "a fully dated changelog passes with the gate armed" \
    "ASSERT_PUBLISHED=1" \
    "true"
  expect_fail_env "a tree with no changelog at all is rejected when armed" 18 \
    "ASSERT_PUBLISHED=1" \
    "rm -f $PLUGIN_REL/CHANGELOG.md"

  if [ "$rc" -eq 0 ]; then echo "SELFTEST PASS"; else echo "SELFTEST FAIL"; fi
  exit "$rc"
}

# ---------------------------------------------------------------------- main
[ "${1:-}" = "--selftest" ] && selftest

ROOT="."
if [ "${1:-}" = "--root" ]; then
  [ $# -lt 2 ] && { echo "Usage: $0 [--root <dir>] | --selftest" >&2; exit 2; }
  ROOT="$2"
fi
[ -d "$ROOT" ] || { echo "Usage: $0 [--root <dir>] | --selftest" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
[ -d "$ROOT/$PLUGIN_REL/docs" ] || { fail 4 "$PLUGIN_REL/docs does not exist"; echo "FAIL: $FAILURES problem(s)" >&2; exit 1; }

[ "$HAVE_PY" = 1 ] || note "python3 not found; falling back to ASCII slugs -- anchors whose heading contains a non-ASCII letter cannot be verified here"
check_links_and_anchors "$ROOT"
check_orphans           "$ROOT"
check_inventory         "$ROOT"
check_env_vars          "$ROOT"
check_table_cells       "$ROOT"
check_install_block     "$ROOT"
check_cost_attribution  "$ROOT"
check_prose_counts      "$ROOT"
check_identity_quarantine "$ROOT"
check_merge_clause      "$ROOT"
check_choices_arity     "$ROOT"
check_index_membership  "$ROOT"
check_dispatch_authority "$ROOT"
check_published_changelog "$ROOT"

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES problem(s) under $PLUGIN_REL" >&2
  exit 1
fi
echo "PASS: docs are consistent with the plugin under $PLUGIN_REL"
