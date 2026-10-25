#!/usr/bin/env python3
"""Catches contract tests that reach for a field or method that no longer exists.

The suite drives production code through Object.set()/get()/call() with string
names:

    game.set("_peer_last_state_position", {2: Vector3.ZERO})
    _check(bool(game.get("_round_resolving")), "...")

Godot's set() on an unknown property is a silent no-op, so renaming a private
field in scripts/ does not break the parse - it quietly guts the test's setup
and leaves it asserting against defaults. That is a passing test protecting
nothing, which is worse than a failing one.

This walks every string-addressed name in tests/ and fails if it is not
declared anywhere under scripts/. It deliberately does not try to resolve which
object each call targets: the failure mode worth catching is "this name is gone
from the codebase", and a repo-wide symbol table catches that with no false
positives from mistaken receivers.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"
TESTS = ROOT / "tests"

# Declarations in production code.
DECL_PATTERNS = (
    re.compile(r"^\s*(?:@onready\s+|@export[^\s]*\s+)?(?:static\s+)?var\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*const\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*signal\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)"),
)

# String-addressed access in tests.
#
# set()/get() are checked only for underscore-prefixed names. Dictionary shares
# the get() spelling - `blueprint.get("footprint_gu")` is a dictionary lookup,
# not property access - and this codebase never uses a leading underscore for a
# dictionary key, so the prefix cleanly separates the two. That is also exactly
# the risky set: private fields are the ones renamed without a second thought.
PROPERTY_PATTERN = re.compile(r"\.(set|get)\(\s*\"(_\w+)\"")

# Dictionary has no call(), so every string here is a real method name.
METHOD_PATTERN = re.compile(r"\.(call|call_deferred)\(\s*\"([^\"]+)\"")


def declared_symbols() -> set[str]:
    symbols: set[str] = set()
    for path in SCRIPTS.rglob("*.gd"):
        for line in path.read_text(encoding="utf-8").splitlines():
            for pattern in DECL_PATTERNS:
                match = pattern.match(line)
                if match:
                    symbols.add(match.group(1))
                    break
    return symbols


def main() -> int:
    symbols = declared_symbols()
    if not symbols:
        print("error: no declarations found under scripts/", file=sys.stderr)
        return 2

    failures: list[str] = []
    for path in sorted(TESTS.rglob("*.gd")):
        relative = path.relative_to(ROOT)
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for pattern in (PROPERTY_PATTERN, METHOD_PATTERN):
                for accessor, name in pattern.findall(line):
                    if name not in symbols:
                        failures.append(f'{relative}:{number}: .{accessor}("{name}") - not declared in scripts/')

    if failures:
        print(f"{len(failures)} stale reference(s) in tests/:\n", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        print(
            "\nThese resolve to nothing at runtime. Object.set() on an unknown "
            "property is silent,\nso the test still passes while protecting nothing.",
            file=sys.stderr,
        )
        return 1

    print(f"test introspection OK ({len(symbols)} symbols declared in scripts/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
