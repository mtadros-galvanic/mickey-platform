#!/usr/bin/env python3

import argparse
import json
import pathlib
import re
import sys


PARENT_RE = re.compile(r'^parentFileNameHint="(?P<name>.+)"$')
EXTENT_RE = re.compile(r'^(?:RW|RDONLY|NOACCESS)\s+\d+\s+\S+\s+"(?P<name>.+)"$')


def parse_descriptor(path: pathlib.Path) -> tuple[str | None, list[str]]:
    parent = None
    extents: list[str] = []

    with path.open(encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()

            parent_match = PARENT_RE.match(line)
            if parent_match:
                parent = parent_match.group("name")
                continue

            extent_match = EXTENT_RE.match(line)
            if extent_match:
                extents.append(extent_match.group("name"))

    return parent, extents


def resolve_chain(descriptor: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path]]:
    chain: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    current = descriptor.resolve()

    while True:
        if current in seen:
            raise ValueError(f"detected descriptor loop at {current}")
        if not current.exists():
            raise FileNotFoundError(f"descriptor not found: {current}")

        seen.add(current)
        chain.append(current)

        parent, _ = parse_descriptor(current)
        if parent is None:
            break

        current = (current.parent / parent).resolve()

    ordered_descriptors = list(reversed(chain))
    ordered_files: list[pathlib.Path] = []
    added: set[pathlib.Path] = set()

    for descriptor_path in ordered_descriptors:
        _, extents = parse_descriptor(descriptor_path)

        for candidate in [descriptor_path, *(descriptor_path.parent / name for name in extents)]:
            resolved = candidate.resolve()
            if not resolved.exists():
                raise FileNotFoundError(f"referenced VMDK extent not found: {resolved}")
            if resolved not in added:
                ordered_files.append(resolved)
                added.add(resolved)

    return ordered_descriptors, ordered_files


def relpath(path: pathlib.Path, root: pathlib.Path) -> str:
    return str(path.resolve().relative_to(root.resolve()))


def build_summary(descriptor: pathlib.Path) -> dict:
    descriptors, files = resolve_chain(descriptor)
    source_dir = descriptor.resolve().parent

    return {
        "source_dir": str(source_dir),
        "target_descriptor": descriptor.name,
        "descriptor_chain": [relpath(path, source_dir) for path in descriptors],
        "files": [relpath(path, source_dir) for path in files],
        "descriptor_count": len(descriptors),
        "file_count": len(files),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resolve a VMware VMDK descriptor chain and emit the required files."
    )
    parser.add_argument("descriptor", help="Path to the child VMDK descriptor to import.")
    parser.add_argument(
        "--chain",
        action="store_true",
        help="Print the descriptor chain, one relative path per line, from base to target.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print every required file, one relative path per line.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    descriptor = pathlib.Path(args.descriptor)

    try:
        summary = build_summary(descriptor)
    except (FileNotFoundError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.chain:
        sys.stdout.write("\n".join(summary["descriptor_chain"]))
        sys.stdout.write("\n")
        return 0

    if args.list:
        sys.stdout.write("\n".join(summary["files"]))
        sys.stdout.write("\n")
        return 0

    json.dump(summary, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
