#!/usr/bin/env python3
"""Validate every plugin manifest and marketplace catalog in this repository.

Guards the three defects that have actually shipped from this repo more than
once:

  1. An over-long plugin ``description``. GitHub Copilot CLI rejects a
     marketplace whose ``plugins[i].description`` exceeds 1024 characters, and
     it rejects the WHOLE catalog -- every plugin in the marketplace then fails
     to install or update, not just the offending one. Claude Code enforces no
     such limit, so the Claude editions can drift far past it with no local
     symptom and then break the Copilot edition at port time. Trimmed by hand
     three times in the Copilot edition before this check existed; each trim
     reset the length without stopping the growth that caused it.

  2. Version drift between a plugin's own ``plugin.json`` and the marketplace
     catalog entry that advertises it. They are independent files kept in sync
     by hand; a release that bumps one and forgets the other ships a catalog
     pointing at the wrong version. Has shipped four times.

Note on what is deliberately NOT checked: the ``description`` in a catalog
entry and in the matching ``plugin.json`` are not required to be identical.
They are independently authored in practice -- Copilot's ``dt-style-guide``
blurbs, for instance, share no wording at all -- so an equality check would
fail on correct content. The half-fix it might have caught (Copilot's
marketplace trimmed to 964 while its plugin.json stayed at 2091) is already
caught by applying the length check to both files.

It also enforces the repo-root instruction budget: ``.github/copilot-instructions.md``
fails above 40,000 characters and warns above 36,000, and each
``.github/instructions/*.instructions.md`` warns above 20,000. And it checks that every
``.github/instructions/**/*.instructions.md`` file declares a non-empty ``applyTo``
frontmatter string (a comma-separated glob string -- Copilot's own syntax, not a YAML
list) whose every comma-separated glob matches at least one file, so a file that would
never apply to anything, or a glob left dead by a rename, fails the build instead of
surviving unnoticed.

Usage:
    python3 scripts/validate-catalog.py [REPO_ROOT ...]
    python3 scripts/validate-catalog.py --selftest

With no arguments, validates the repository containing this script. Exits 0
when everything passes, 1 on any error. Warnings alone do not fail the run.

``--selftest`` builds a minimal catalog in a temporary directory, mutates it once
per failure mode, and asserts both the exit status and WHICH error was reported.
Asserting the message rather than the exit code alone is deliberate: every mutation
here trips a non-zero exit, so exit status alone would let a mutation that broke a
DIFFERENT rule register as success.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# GitHub Copilot CLI's hard schema limit. Applied to every edition, not just
# the Copilot one: canonical is the source the Copilot blurb is ported from, so
# letting canonical grow past the limit is what reloads the gun.
DESCRIPTION_MAX = 1024

# Growth in this field is a ratchet -- each release has historically appended a
# sentence and removed nothing (259 chars at inception, 2788 by 2.52.0). Warn
# with enough headroom that trimming happens as routine maintenance instead of
# as an outage.
DESCRIPTION_WARN = 900

# The repo-root copilot-instructions.md loads into every Copilot CLI session in this
# repository. It reached 42,659 characters by accretion before the 2026-09-26 split moved
# path-specific rules to .github/instructions/*.instructions.md (loaded only for a matching
# file, via the applyTo frontmatter) and evidence to docs/maintainers/rationale.md (never
# loaded). Characters, not bytes or lines: the budget is context, and the file is unwrapped
# paragraphs, so a line count means nothing. Same 40,000/36,000 hard/warn budget as the
# Claude editions' CLAUDE.md, so a fix to one gate's threshold is a fix to review against
# both, even though the two gates check different file names.
INSTRUCTIONS_MD_MAX = 40_000
INSTRUCTIONS_MD_WARN = 36_000
INSTRUCTIONS_FILE_WARN = 20_000

SKIP_DIRS = {".git", "node_modules", ".superpowers", ".idea"}


def find_files(root: Path, name: str) -> list[Path]:
    """Locate every file with this name, at any depth.

    Deliberately unbounded: Copilot keeps its catalog at
    ``.github/plugin/marketplace.json`` (depth 3) while Claude editions use
    ``.claude-plugin/marketplace.json`` (depth 2). A depth-limited search
    reported "Copilot has no catalog" once and shipped a stale one as a result.
    """
    return sorted(
        p
        for p in root.rglob(name)
        if not any(part in SKIP_DIRS for part in p.parts)
    )


def load(path: Path) -> dict | None:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"  ERROR {path}: cannot parse -- {exc}")
        return None


def check_description(label: str, description: str) -> tuple[int, int]:
    """Return (errors, warnings) for one description field."""
    size = len(description)
    if size > DESCRIPTION_MAX:
        print(
            f"  ERROR {label}: description is {size} chars, "
            f"limit is {DESCRIPTION_MAX} "
            f"(Copilot rejects the entire catalog, breaking every plugin in it)"
        )
        return 1, 0
    if size > DESCRIPTION_WARN:
        print(
            f"  WARN  {label}: description is {size} chars, "
            f"nearing the {DESCRIPTION_MAX} limit -- trim it now, "
            f"and move release detail to CHANGELOG.md"
        )
        return 0, 1
    return 0, 0


def check_instruction_sizes(root: Path) -> tuple[int, int]:
    """Return (errors, warnings) for the repo-root instruction tiers' size budget."""
    errors = warnings = 0
    top = root / ".github" / "copilot-instructions.md"
    if top.is_file():
        size = len(top.read_text(encoding="utf-8"))
        if size > INSTRUCTIONS_MD_MAX:
            print(
                f"  ERROR .github/copilot-instructions.md is {size} characters, limit is "
                f"{INSTRUCTIONS_MD_MAX} -- move a path-specific rule to a narrower "
                f".github/instructions/<name>.instructions.md, and evidence to "
                f"docs/maintainers/rationale.md"
            )
            errors += 1
        elif size > INSTRUCTIONS_MD_WARN:
            print(
                f"  WARN  .github/copilot-instructions.md is {size} characters, nearing the "
                f"{INSTRUCTIONS_MD_MAX} limit -- move evidence to docs/maintainers/rationale.md now"
            )
            warnings += 1
    for inst_file in sorted((root / ".github" / "instructions").rglob("*.instructions.md")):
        size = len(inst_file.read_text(encoding="utf-8"))
        if size > INSTRUCTIONS_FILE_WARN:
            rel = inst_file.relative_to(root)
            print(
                f"  WARN  {rel} is {size} characters, past {INSTRUCTIONS_FILE_WARN} -- split "
                f"it by a narrower applyTo glob, or move evidence to "
                f"docs/maintainers/rationale.md"
            )
            warnings += 1
    return errors, warnings


def _parse_apply_to(text: str) -> tuple[str | None, bool]:
    """Return (applyTo value or None, malformed frontmatter flag) for one instructions file's text.

    Copilot's own frontmatter shape: ``applyTo`` is a single comma-separated STRING value on
    its own line -- ``applyTo: "<glob>[,<glob>]"`` -- never a YAML block list. A quoted or bare
    scalar are both accepted; a block-list form (the Claude-edition ``paths:`` shape) is
    deliberately NOT parsed here, so writing one by habit is reported as no ``applyTo`` at all
    rather than silently accepted as something else.
    """
    lines = text.splitlines()
    if not lines or lines[0].rstrip() != "---":
        return None, True
    try:
        close = 1 + lines[1:].index("---")
    except ValueError:
        return None, True
    frontmatter = lines[1:close]
    for line in frontmatter:
        stripped = line.strip()
        if not stripped.startswith("applyTo:"):
            continue
        value = stripped[len("applyTo:"):].strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        return value, False
    return None, False


def check_instructions_apply_to(root: Path) -> tuple[int, int]:
    """Return (errors, warnings): every .github/instructions/**/*.instructions.md must declare a
    non-empty `applyTo` frontmatter string, and every comma-separated glob in it must match at
    least one file under root.

    Parser limits: `applyTo` must be a top-level (unindented) `key: value` line in the
    frontmatter; the value is read as a single string and split on commas -- an inline YAML
    list (`applyTo: [a, b]`) is read as one glob whose literal text is `[a, b]` and will
    correctly fail to match anything, since Copilot's own schema never accepts that form
    either. Globs go through pathlib, which has no brace expansion, so a `{a,b}` glob matches
    nothing and is reported dead; write each alternative as its own comma-separated entry.
    """
    errors = warnings = 0
    inst_dir = root / ".github" / "instructions"
    if not inst_dir.is_dir():
        return errors, warnings

    no_apply_to = (
        "no non-empty applyTo: string -- without one this file never applies to any file "
        "Copilot works with, which defeats the point of putting it here"
    )

    for inst_file in sorted(inst_dir.rglob("*.instructions.md")):
        rel = inst_file.relative_to(root)
        text = inst_file.read_text(encoding="utf-8")
        value, malformed = _parse_apply_to(text)

        if malformed:
            print(f"  ERROR {rel}: {no_apply_to} (frontmatter missing or never closed)")
            errors += 1
            continue
        if not value:
            print(f"  ERROR {rel}: {no_apply_to} (no applyTo: key, or its value is empty)")
            errors += 1
            continue

        globs = [g.strip() for g in value.split(",") if g.strip()]
        if not globs:
            print(f"  ERROR {rel}: {no_apply_to} (applyTo: value has no non-empty glob)")
            errors += 1
            continue

        for glob in globs:
            candidates = set(root.glob(glob))
            if glob == "**" or glob.endswith("/**"):
                candidates.update(root.glob(glob + "/*"))
            matches = [
                p for p in candidates
                if p.is_file() and not any(part in SKIP_DIRS for part in p.parts)
            ]
            if not matches:
                print(f"  ERROR {rel}: applyTo glob {glob!r} matches no file under {root}")
                errors += 1

    return errors, warnings


def validate_repo(root: Path) -> tuple[int, int]:
    print(f"\n=== {root}")
    errors = 0
    warnings = 0

    # Index every plugin manifest by the directory that holds the plugin, so a
    # catalog entry can be matched against the manifest it advertises.
    manifests: dict[str, tuple[Path, dict]] = {}
    for manifest_path in find_files(root, "plugin.json"):
        data = load(manifest_path)
        if data is None:
            errors += 1
            continue
        name = data.get("name")
        if not name:
            print(f"  ERROR {manifest_path}: no 'name' field")
            errors += 1
            continue
        manifests[name] = (manifest_path, data)
        rel = manifest_path.relative_to(root)
        e, w = check_description(str(rel), data.get("description", ""))
        errors += e
        warnings += w

    catalogs = find_files(root, "marketplace.json")
    if not catalogs:
        print("  ERROR no marketplace.json found in this repository")
        errors += 1

    for catalog_path in catalogs:
        data = load(catalog_path)
        if data is None:
            errors += 1
            continue
        rel = catalog_path.relative_to(root)
        entries = data.get("plugins", [])
        if not entries:
            print(f"  ERROR {rel}: catalog lists no plugins")
            errors += 1
            continue

        for index, entry in enumerate(entries):
            name = entry.get("name", f"<unnamed #{index}>")
            label = f"{rel} plugins[{index}] ({name})"

            e, w = check_description(label, entry.get("description", ""))
            errors += e
            warnings += w

            if name not in manifests:
                print(
                    f"  ERROR {label}: catalog advertises a plugin with no "
                    f"plugin.json anywhere in this repository"
                )
                errors += 1
                continue

            manifest_path, manifest = manifests[name]
            manifest_rel = manifest_path.relative_to(root)

            catalog_version = entry.get("version")
            manifest_version = manifest.get("version")
            if catalog_version != manifest_version:
                print(
                    f"  ERROR {label}: catalog says version "
                    f"{catalog_version!r} but {manifest_rel} says "
                    f"{manifest_version!r}"
                )
                errors += 1

    e, w = check_instruction_sizes(root)
    errors += e
    warnings += w

    e, w = check_instructions_apply_to(root)
    errors += e
    warnings += w

    if errors == 0 and warnings == 0:
        print("  OK")
    return errors, warnings


def _selftest() -> int:
    """Build a passing catalog, mutate it once per rule, assert what was reported."""
    import tempfile

    def build(root: Path, *, version: str = "1.0.0", catalog_version: str | None = None,
              description: str = "A fixture plugin.",
              top_instructions: str | None = None,
              instructions_files: dict[str, str] | None = None) -> None:
        plugin_dir = root / "fixture-plugin"
        (plugin_dir / ".plugin").mkdir(parents=True)
        (plugin_dir / ".plugin" / "plugin.json").write_text(json.dumps(
            {"name": "fixture-plugin", "version": version, "description": description}),
            encoding="utf-8")
        (root / ".github" / "plugin").mkdir(parents=True)
        (root / ".github" / "plugin" / "marketplace.json").write_text(json.dumps({
            "name": "fixture-plugins",
            "plugins": [{"name": "fixture-plugin", "source": "fixture-plugin",
                          "version": catalog_version or version, "description": description}],
        }), encoding="utf-8")
        if top_instructions is not None:
            (root / ".github").mkdir(parents=True, exist_ok=True)
            (root / ".github" / "copilot-instructions.md").write_text(
                top_instructions, encoding="utf-8")
        for rel, text in (instructions_files or {}).items():
            path = root / ".github" / "instructions" / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    rc = 0

    def case(desc: str, want_ok: bool, needle: str, **kw) -> None:
        nonlocal rc
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build(root, **kw)
            import io as _io
            import contextlib
            buf = _io.StringIO()
            with contextlib.redirect_stdout(buf):
                errors, _ = validate_repo(root)
            out = buf.getvalue()
            ok = (errors == 0)
            if ok != want_ok:
                print(f"FAIL  {desc}: expected {'no errors' if want_ok else 'an error'}, "
                      f"got {errors}")
                rc = 1
            elif needle and needle not in out:
                print(f"FAIL  {desc}: the right outcome, but the report never said "
                      f"{needle!r} -- a different rule may have fired")
                rc = 1
            else:
                print(f"ok    {desc}")

    case("a consistent catalog passes", True, "OK")
    case("version drift between catalog and manifest is rejected", False,
         "but fixture-plugin/.plugin/plugin.json says", catalog_version="9.9.9")
    case("an over-long description is rejected", False, "ERROR",
         description="x" * (DESCRIPTION_MAX + 1))
    case("a description past the warning threshold is reported", True, "WARN",
         description="x" * (DESCRIPTION_WARN + 1))
    case("a repository with no copilot-instructions.md passes", True, "OK")

    # The instruction-file budget. Characters, not bytes: every `→` and `—` is three bytes,
    # so a byte count would fail a file that is under the budget -- the multi-byte case below
    # passes only if the gate counts characters.
    case("copilot-instructions.md at the limit passes", True,
         f"WARN  .github/copilot-instructions.md is {INSTRUCTIONS_MD_MAX} characters",
         top_instructions="x" * INSTRUCTIONS_MD_MAX)
    case("copilot-instructions.md one character over the limit is rejected", False,
         f"copilot-instructions.md is {INSTRUCTIONS_MD_MAX + 1} characters",
         top_instructions="x" * (INSTRUCTIONS_MD_MAX + 1))
    case("copilot-instructions.md of multi-byte characters under the limit passes", True,
         f"WARN  .github/copilot-instructions.md is {INSTRUCTIONS_MD_MAX - 1} characters",
         top_instructions="→" * (INSTRUCTIONS_MD_MAX - 1))
    case("copilot-instructions.md past the warning threshold is reported", True,
         "WARN  .github/copilot-instructions.md",
         top_instructions="x" * (INSTRUCTIONS_MD_WARN + 1))
    case("an instructions file past its threshold is reported", True,
         "WARN  .github/instructions/area.instructions.md",
         instructions_files={"area.instructions.md":
                              '---\napplyTo: "fixture-plugin/**/*.json"\n---\n\n'
                              + "x" * (INSTRUCTIONS_FILE_WARN + 1)})

    # check_instructions_apply_to: applyTo frontmatter and live globs. "fixture-plugin/
    # .plugin/plugin.json" is the one file every fixture build() call creates, so every glob
    # below is checked against a real, always-present path two directories deep.
    case("an instructions file whose applyTo matches a file in the fixture passes", True,
         "OK",
         instructions_files={"good.instructions.md":
                              '---\napplyTo: "fixture-plugin/**/*.json"\n---\n\nA rule.\n'})
    case("an instructions file whose applyTo matches nothing is rejected", False,
         "fixture-plugin/does-not-exist/**",
         instructions_files={"bad.instructions.md":
                              '---\napplyTo: "fixture-plugin/does-not-exist/**"\n---\n\nA rule.\n'})
    case("an instructions file with no frontmatter is rejected", False, "no non-empty applyTo:",
         instructions_files={"noheader.instructions.md": "A rule with no frontmatter at all.\n"})
    case("an instructions file with an empty applyTo: value is rejected", False,
         "(no applyTo: key, or its value is empty)",
         instructions_files={"empty.instructions.md": '---\napplyTo: ""\n---\n\nA rule.\n'})
    case("an instructions file with no applyTo: key at all is rejected", False,
         "(no applyTo: key, or its value is empty)",
         instructions_files={"nokey.instructions.md": '---\ndescription: x\n---\n\nA rule.\n'})
    # The comma-separated-string form, with more than one glob -- Copilot's own syntax, never
    # a YAML list. Both globs target the same real file, so a pass here also proves the
    # comma-split itself works, not just single-glob matching.
    case("an instructions file with two comma-separated globs, both live, passes", True,
         "OK",
         instructions_files={"multi.instructions.md":
                              '---\napplyTo: "fixture-plugin/**/*.json,fixture-plugin/.plugin/**"\n'
                              '---\n\nA rule.\n'})
    case("one dead glob among two comma-separated globs is still rejected", False,
         "fixture-plugin/nope/**",
         instructions_files={"multibad.instructions.md":
                              '---\napplyTo: "fixture-plugin/**/*.json,fixture-plugin/nope/**"\n'
                              '---\n\nA rule.\n'})

    print("SELFTEST PASS" if rc == 0 else "SELFTEST FAIL")
    return rc


def main(argv: list[str]) -> int:
    if len(argv) > 1 and argv[1] == "--selftest":
        return _selftest()

    roots = (
        [Path(a).resolve() for a in argv[1:]]
        if len(argv) > 1
        else [Path(__file__).resolve().parent.parent]
    )

    total_errors = 0
    total_warnings = 0
    for root in roots:
        if not root.is_dir():
            print(f"ERROR {root}: not a directory")
            total_errors += 1
            continue
        errors, warnings = validate_repo(root)
        total_errors += errors
        total_warnings += warnings

    print(
        f"\n{total_errors} error(s), {total_warnings} warning(s) "
        f"across {len(roots)} repo(s)."
    )
    return 1 if total_errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
