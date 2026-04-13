---
name: setup-lean-project
description: >
  Create a thin Lean 4 project in the current working directory that references the shared
  system-wide Mathlib clone. Use this before running formalize-in-lean or prove-with-lean
  when no Lean project exists in the working directory yet. Triggers: "set up lean project",
  "create lean project", "initialize lean for this repo", or when another skill detects that
  thoughts/lean/ does not exist.
user-invocable: true
argument-hint: "[optional: target directory, default: thoughts/lean]"
---

# Setup Lean Project

Create a thin Lean 4 project at `thoughts/lean/` (or a caller-specified path) in the current
working directory. The project references the shared `~/.lean/mathlib4` clone via a path
require — no Mathlib re-download or recompilation needed.

## Prerequisites

Verify the shared Mathlib clone exists:

```bash
MATHLIB_ROOT="$(cd ~/.lean/mathlib4 2>/dev/null && pwd)" || echo "NOT FOUND"
```

If not found, tell the user to run the `setup-lean-mathlib` skill first and stop.

## Step 1: Determine Target Directory

Use the caller-supplied path, or default to `thoughts/lean` relative to CWD:

```bash
LEAN_PROJECT="${1:-thoughts/lean}"
mkdir -p "$LEAN_PROJECT/Proofs"
```

## Step 2: Write Project Files

**`lakefile.lean`** — package declaration with path require to shared Mathlib:

```lean
import Lake
open Lake DSL

package Proofs where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib Proofs where

require mathlib from "<MATHLIB_ROOT — expand to absolute path>"
```

**`Proofs.lean`** — root module (empty is fine):

```lean
-- Lean project for formal proofs. Files go in Proofs/.
```

**`Proofs/.gitkeep`** — keep the directory tracked if empty.

## Step 3: Copy Toolchain

```bash
cp "$MATHLIB_ROOT/lean-toolchain" "$LEAN_PROJECT/lean-toolchain"
```

The project's toolchain must exactly match the shared clone's — mismatch is the most common
build failure.

## Step 4: Generate Manifest

Run from inside the project directory:

```bash
cd "$LEAN_PROJECT"
python3 ${CLAUDE_SKILL_DIR}/../setup-lean-mathlib/scripts/generate_manifest.py Proofs
```

This rewrites all transitive Mathlib dependencies as path entries pointing at the shared
clone's local checkouts. No network access needed.

## Step 5: Build

```bash
cd "$LEAN_PROJECT" && LAKE_ARTIFACT_CACHE=true lake build
```

No `lake exe cache get` needed — oleans are pre-built in the shared clone.

## Output

A built Lean project at `${LEAN_PROJECT}/` with:
- `lakefile.lean` — path-requires shared Mathlib
- `lean-toolchain` — matches shared clone
- `lake-manifest.json` — all deps as local path entries
- `Proofs/` — directory for proof files
- `.lake/build/` — compiled oleans (from shared clone via symlink/cache)

Proof files written by `formalize-in-lean` and `prove-with-lean` go in `Proofs/`.
