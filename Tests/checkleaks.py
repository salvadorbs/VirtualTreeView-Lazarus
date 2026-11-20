#!/usr/bin/env python3

"""Check an FPC heaptrc dump for leaks.

The FPCUnit project is built with -gh (heaptrc) and run with

    HEAPTRC="log=Tests/artifacts/heaptrc.txt" Tests/lib/x86_64-linux/Tests --all

heaptrc then writes one "Call trace for block" section per block that was still
allocated when the program exited.

A leaked block counts as ours when one of its frames names a source file of this
repository (Source/*.pas or Tests/*.pas). Only those fail the check: leaks in the
LCL, the widgetsets or the RTL are printed for the upstream projects (a clean
heaptrc run is expected there, so they are worth a bug report) but do not block
this repository.

Exit code: 0 when the project code is clean, 1 when it is not or when the dump
is missing/malformed.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from collections import Counter

BLOCK_RE = re.compile(r"^Call trace for block \$[0-9A-Fa-f]+ size (\d+)")
FRAME_FILE_RE = re.compile(r",\s+line\s+.*?\s+of\s+(.+)$")
UNFREED_RE = re.compile(r"^(\d+) unfreed memory blocks")

SOURCE_PATTERNS = ("Source/**/*.pas", "Tests/**/*.pas")


def project_sources(root: str) -> set[str]:
    """Lowercase basenames of the Pascal sources that belong to this repository."""

    names: set[str] = set()
    for pattern in SOURCE_PATTERNS:
        for path in glob.glob(os.path.join(root, pattern), recursive=True):
            names.add(os.path.basename(path).lower())
    return names


def frame_file(frame: str) -> str | None:
    """Source file named by a heaptrc frame line, or None when it has no line info."""

    match = FRAME_FILE_RE.search(frame)
    if not match:
        return None
    name = match.group(1).strip()
    if name in ("", "?"):
        return None
    return os.path.basename(name).lower()


def parse(log: str) -> tuple[int | None, list[dict]]:
    """Return the reported number of unfreed blocks and the parsed traces."""

    total: int | None = None
    blocks: list[dict] = []
    current: dict | None = None

    with open(log, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")

            match = UNFREED_RE.match(line)
            if match:
                total = int(match.group(1))
                current = None
                continue

            match = BLOCK_RE.match(line)
            if match:
                current = {"size": int(match.group(1)), "frames": [], "ours": False}
                blocks.append(current)
                continue

            # A frame line starts with its address, e.g.
            #   $000000000040109E  TVIRTUALSTRINGTREE__CREATE,  line 123 of virtualtrees.pas
            if current is not None and line.lstrip().startswith("$"):
                current["frames"].append(line.strip())

    return total, blocks


def classify(blocks: list[dict], sources: set[str]) -> None:
    for block in blocks:
        for frame in block["frames"]:
            name = frame_file(frame)
            if name is not None and name in sources:
                block["ours"] = True
                break


def report(blocks: list[dict], max_blocks: int) -> None:
    for block in blocks[:max_blocks]:
        print(f"  leaked block of {block['size']} bytes:")
        for frame in block["frames"]:
            print(f"    {frame}")

        if len(block["frames"]) == 0:
            print("    (no call trace: the block was allocated without line info)")

    if len(blocks) > max_blocks:
        print(f"  ... and {len(blocks) - max_blocks} more blocks in the heap trace")


def origins(blocks: list[dict]) -> Counter:
    result: Counter = Counter()
    for block in blocks:
        name = frame_file(block["frames"][0]) if block["frames"] else None
        result[name or "(no line info)"] += 1
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Check an FPC heaptrc dump for leaks.")
    parser.add_argument("log", help="heaptrc output file (HEAPTRC=log=...)")
    parser.add_argument(
        "--project-root",
        default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        help="repository root the traces are matched against (default: the parent of this script)",
    )
    parser.add_argument(
        "--max-blocks",
        type=int,
        default=10,
        help="how many traces per group to print (default: 10)",
    )
    parser.add_argument(
        "--fail-on-external",
        action="store_true",
        help="also fail for leaks outside the project code (LCL, widgetset, RTL)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.log):
        print(f"ERROR: heap trace not found: {args.log}", file=sys.stderr)
        print('Build the tests with -gh and run them with HEAPTRC="log=<file>".', file=sys.stderr)
        return 1

    total, blocks = parse(args.log)
    if total is None:
        print(f"ERROR: {args.log} is not a heaptrc dump.", file=sys.stderr)
        return 1
    if total != len(blocks):
        print(
            f"WARNING: heaptrc reports {total} unfreed blocks but {len(blocks)} traces were found.",
            file=sys.stderr,
        )

    classify(blocks, project_sources(args.project_root))

    ours = [block for block in blocks if block["ours"]]
    external = [block for block in blocks if not block["ours"]]

    if total == 0:
        print("heaptrc: no unfreed memory blocks")
        print("OK: the project code does not leak")
        return 0

    print(f"heaptrc: {total} unfreed memory block(s)")

    if ours:
        print(f"FAIL: {len(ours)} of them come from the project code:")
        report(ours, args.max_blocks)
    else:
        print("OK: no unfreed block comes from the project code")

    if external:
        print(f"WARNING: {len(external)} leaked block(s) come from outside this project:")
        first = origins(external)
        for name, count in first.most_common(10):
            print(f"  {count:5d} x {name}")
        report(external, args.max_blocks)
        if args.fail_on_external:
            print("FAIL: external leaks are treated as errors (--fail-on-external)")
            return 1

    return 1 if ours else 0


if __name__ == "__main__":
    sys.exit(main())
