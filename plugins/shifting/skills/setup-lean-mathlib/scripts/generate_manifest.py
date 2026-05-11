#!/usr/bin/env python3
"""
Generate lake-manifest.json pointing all Mathlib deps at the shared system-wide clone.

Reads the shared clone's lake-manifest.json (which lists transitive dependencies as git
entries) and rewrites every entry as a path-type entry pointing at the local checkout.
This avoids `lake update`, which would re-clone everything from GitHub.

Usage:
    python3 generate_manifest.py <project-name> [--mathlib-root PATH] [--output PATH]

Environment:
    MATHLIB_ROOT  Override the shared clone location (default: ~/.lean/mathlib4)

Cross-platform: uses os.path for all path handling, no shell dependencies.
"""

import argparse
import json
import os
import sys


def find_mathlib_root(override: str | None = None) -> str:
    """Locate the shared Mathlib clone, preferring explicit override > env var > default."""
    candidates = [
        override,
        os.environ.get("MATHLIB_ROOT"),
        os.path.join(os.path.expanduser("~"), ".lean", "mathlib4"),
    ]
    for candidate in candidates:
        if candidate and os.path.isdir(candidate):
            return os.path.realpath(candidate)

    default = os.path.join("~", ".lean", "mathlib4")
    print(f"error: shared Mathlib clone not found at {default}", file=sys.stderr)
    print("Install with: git clone https://github.com/leanprover-community/mathlib4 ~/.lean/mathlib4", file=sys.stderr)
    sys.exit(1)


def load_source_manifest(mathlib_root: str) -> dict:
    """Load and validate the shared clone's lake-manifest.json."""
    manifest_path = os.path.join(mathlib_root, "lake-manifest.json")
    if not os.path.isfile(manifest_path):
        print(f"error: {manifest_path} not found", file=sys.stderr)
        print("Run `lake exe cache get` in the shared clone first.", file=sys.stderr)
        sys.exit(1)

    with open(manifest_path, encoding="utf-8") as f:
        return json.load(f)


def build_path_entries(mathlib_root: str, source_manifest: dict) -> list[dict]:
    """Convert all dependency entries to path-type pointing at local checkouts."""
    pkgs_dir = os.path.join(mathlib_root, ".lake", "packages")

    # Mathlib itself
    entries = [{
        "type": "path",
        "name": "mathlib",
        "dir": mathlib_root,
        "inherited": False,
        "scope": "",
        "configFile": "lakefile.lean",
        "manifestFile": "lake-manifest.json",
    }]

    # Each transitive dependency
    for pkg in source_manifest.get("packages", []):
        pkg_name = pkg["name"]
        pkg_path = os.path.join(pkgs_dir, pkg_name)

        if not os.path.isdir(pkg_path):
            print(f"warning: {pkg_name} not found at {pkg_path}, skipping", file=sys.stderr)
            continue

        entries.append({
            "type": "path",
            "name": pkg_name,
            "dir": pkg_path,
            "inherited": pkg.get("inherited", False),
            "scope": pkg.get("scope", ""),
            "configFile": pkg.get("configFile", "lakefile.toml"),
            "manifestFile": "lake-manifest.json",
        })

    return entries


def main():
    parser = argparse.ArgumentParser(
        description="Generate lake-manifest.json for a project using shared Mathlib."
    )
    parser.add_argument("project_name", help="Project name (must match lakefile.toml)")
    parser.add_argument("--mathlib-root", default=None, help="Path to shared Mathlib clone")
    parser.add_argument("--output", default="lake-manifest.json", help="Output path (default: lake-manifest.json)")
    args = parser.parse_args()

    mathlib_root = find_mathlib_root(args.mathlib_root)
    source = load_source_manifest(mathlib_root)
    entries = build_path_entries(mathlib_root, source)

    manifest = {
        "version": source.get("version", "1.1.0"),
        "packagesDir": ".lake/packages",
        "packages": entries,
        "name": args.project_name,
        "lakeDir": ".lake",
    }

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)

    dep_count = len(entries) - 1
    print(f"{args.output}: {len(entries)} path entries (mathlib + {dep_count} deps)")
    print(f"  mathlib root: {mathlib_root}")
    print(f"  manifest version: {source.get('version', '1.1.0')}")


if __name__ == "__main__":
    main()
