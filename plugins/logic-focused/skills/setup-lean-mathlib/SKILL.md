---
name: setup-lean-mathlib
description: >
  Set up and manage Lean 4 projects that use Mathlib via a shared system-wide installation.
  Use this skill whenever the user wants to create a new Lean 4 project, add Mathlib as a
  dependency, work with Lean theorem proving, or update their Mathlib installation. Also use
  when you detect a Lean project with Mathlib issues (toolchain mismatch, missing manifest,
  slow dependency resolution). Triggers: "new lean project", "add mathlib", "lean4 setup",
  "update mathlib", "prove in lean", "formalize in lean", working in any directory with
  lean-toolchain or lakefile.lean/lakefile.toml files that reference mathlib.
---

# Lean 4 + Mathlib Project Management

This skill manages Lean 4 projects that depend on Mathlib through a shared system-wide clone.
The shared clone avoids re-downloading and recompiling Mathlib (~700k lines, hours to build)
for every project.

## Critical Rules

These exist because Lake's default behavior wastes enormous time when a shared clone is available:

1. **Never run `lake update`** in a project using shared Mathlib. It re-clones all transitive
   dependencies from GitHub every time, ignoring both `--packages` overrides and
   `package-overrides.json`. Use the bundled manifest generator instead.

2. **Never use `lake new <name> math`** to create projects. The `math` template clones Mathlib
   as a git dependency, bypassing the shared clone entirely. Use `lake init` + path require.

3. **Never lock `.lake/build/` read-only.** Lake writes small `.olean.hash` files (16 bytes,
   idempotent) for rebuild checking. Making the directory read-only causes build failures.

4. **Always read the toolchain from the shared clone.** Never hardcode a Lean version. The
   project's `lean-toolchain` must exactly match the shared Mathlib's toolchain — mismatch is
   the most common build failure.

5. **Always use fully expanded absolute paths** in `lakefile.toml`/`lakefile.lean` require
   statements. Lake does not expand `~`, `$HOME`, or any shell/environment variables.

## Locating the Shared Clone

The shared Mathlib clone lives at `~/.lean/mathlib4`. Before proceeding with any operation,
verify it exists:

```bash
MATHLIB_ROOT="$(cd ~/.lean/mathlib4 2>/dev/null && pwd)" || echo "NOT FOUND"
```

If not found, see [First-Time Installation](#first-time-installation) below.

The clone contains:
- `lean-toolchain` — authoritative toolchain version
- `lake-manifest.json` — authoritative dependency revisions (input to the manifest generator)
- `lakefile.lean` — Mathlib's own lakefile
- `.lake/build/` — pre-built `.olean` files (must stay writable)
- `.lake/packages/` — source checkouts of all transitive dependencies

## Creating a New Project

### Step 1: Read the toolchain and init

```bash
MATHLIB_ROOT="$(cd ~/.lean/mathlib4 && pwd)"
TOOLCHAIN=$(cat "$MATHLIB_ROOT/lean-toolchain")
lake +"$TOOLCHAIN" init <ProjectName>
```

Then ensure the project's `lean-toolchain` matches:

```
lean-toolchain contents: exactly what $MATHLIB_ROOT/lean-toolchain contains
```

### Step 2: Add Mathlib require

Append to `lakefile.toml`:

```toml
[[require]]
name = "mathlib"
path = "<MATHLIB_ROOT expanded to absolute path>"
```

Or if the project uses `lakefile.lean`:

```lean
require mathlib from "<MATHLIB_ROOT expanded to absolute path>"
```

### Step 3: Generate the manifest

Run the bundled manifest generator from the project root:

```bash
python3 <this-skill-dir>/scripts/generate_manifest.py <ProjectName>
```

This reads `$MATHLIB_ROOT/lake-manifest.json` and rewrites every dependency as a path entry
pointing at the shared clone's local checkouts. No network access needed.

The `MATHLIB_ROOT` environment variable can override the default `~/.lean/mathlib4` location.

### Step 4: Build

```bash
LAKE_ARTIFACT_CACHE=true lake build
```

No `lake exe cache get` needed — the oleans are already in the shared clone's build directory.
`LAKE_ARTIFACT_CACHE=true` enables cross-project olean deduplication by content hash (Lean 4.22+).

## Updating the Shared Clone

When the user wants a newer Mathlib version:

```bash
cd ~/.lean/mathlib4
git fetch --tags
git tag -l 'v*' | grep -v rc | sort -V | tail -5   # list recent stable tags
git checkout <chosen-tag>
lake exe cache get                                    # download pre-built oleans
```

Then for each project using the shared clone:
1. Update `lean-toolchain` to match `~/.lean/mathlib4/lean-toolchain`
2. Re-run the manifest generator
3. `lake build`

## First-Time Installation

If no shared clone exists at `~/.lean/mathlib4`:

```bash
mkdir -p ~/.lean && cd ~/.lean
git clone https://github.com/leanprover-community/mathlib4.git
cd mathlib4
# Check out latest stable tag
git tag -l 'v*' | grep -v rc | sort -V | tail -1 | xargs git checkout
# Download pre-built oleans (this is the expensive one-time step)
lake exe cache get
```

Prerequisite: `elan` must be installed (https://github.com/leanprover/elan). It manages Lean
toolchain versions like rustup manages Rust. If `elan` is not installed:

```bash
curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
```

On Windows, download `elan-init.exe` from the elan GitHub releases page instead.

## Troubleshooting

**Build fails with version/toolchain errors:**
The project's `lean-toolchain` doesn't match the shared Mathlib's. Fix:
```bash
cp ~/.lean/mathlib4/lean-toolchain ./lean-toolchain
```

**Build fails with "unknown package" or missing imports:**
The `lake-manifest.json` is missing or stale. Regenerate it:
```bash
python3 <this-skill-dir>/scripts/generate_manifest.py <ProjectName>
```

**Build fails with permission denied on `.olean.hash`:**
Someone locked the shared build directory. Fix:
```bash
chmod -R u+w ~/.lean/mathlib4/.lake/build
```

**Build is downloading/compiling Mathlib from scratch:**
You likely ran `lake update` or used the `math` template. Delete `.lake/` and
`lake-manifest.json`, then redo steps 2-4 from [Creating a New Project](#creating-a-new-project).

**`lake exe cache get` is slow or fails:**
The `.ltar` download cache at `~/.cache/mathlib/` may be stale. Safe to delete and re-run:
```bash
rm -rf ~/.cache/mathlib && cd ~/.lean/mathlib4 && lake exe cache get
```

## Recommended Hook

To prevent accidentally running `lake update` in projects using shared Mathlib, suggest the
user add this hook to their `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -q 'lake update'; then if [ -f lakefile.toml ] && grep -q 'path.*mathlib4' lakefile.toml 2>/dev/null || [ -f lakefile.lean ] && grep -q 'mathlib' lakefile.lean 2>/dev/null; then echo 'BLOCKED: lake update re-clones all deps. Use the manifest generator instead.' >&2; exit 1; fi; fi; exit 0"
          }
        ]
      }
    ]
  }
}
```

## Glossary

Read `references/glossary.md` if you need background on Lean tooling terminology (elan, lake,
oleans, ltars, etc.).
