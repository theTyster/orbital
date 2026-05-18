---
name: setup-lean-project
description: >
  Project scaffolding for the Lean-based proof stage, NOT a pipeline stage. Initializes a thin Lean 4 project at `thoughts/lean/` referencing the shared Mathlib clone at `~/.lean/mathlib4`. Satisfies the `lean_project_built` environment requirement of `prove-invariants` (the project must exist with `.lake/build/` populated). Run once before `prove-invariants` if no project exists. Triggered by: "set up/create lean project", "initialize lean", or when `thoughts/lean/` is missing.
user-invocable: true
model: opus
effort: medium
argument-hint: "[optional: target directory, default: thoughts/lean]"
---

# setup-lean-project

This skill is **project scaffolding for the Lean-based proof stage**, not a pipeline stage. It
creates a thin Lean 4 project at `thoughts/lean/` (or a caller-specified path) that references the
shared `~/.lean/mathlib4` clone via a path require — no Mathlib re-download or recompilation
needed. It satisfies the `lean_project_built` environment requirement of `prove-invariants`:
the project must exist at `thoughts/lean/` with `.lake/build/` populated before any theorem can be
checked. Invoke it once to provision the project skeleton, then `prove-invariants` writes its
theorems into `Proofs/`. It does not appear in the linear pipeline flow.

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

**`lakefile.lean`** — package declaration with path requires to shared Mathlib
and the plugin's Ontology scaffold:

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
require Ontology from "<ONTOLOGY_ROOT — expand to absolute path of plugins/shifting/lean>"
```

`<ONTOLOGY_ROOT>` is the absolute path to `plugins/shifting/lean/` inside
the installed plugin (under Claude Code plugin runtime, this is
`${CLAUDE_PLUGIN_ROOT}/lean` — `lake` does not expand environment variables,
so substitute the absolute path at file-write time the same way
`<MATHLIB_ROOT>` is substituted). The scaffold has no dependencies of its own
beyond `Lean`, so the require is cheap; emitted proof files use
`import Ontology.Prelude` to access the `exhaust` / `witnesses` macros, the
`Ontology.Origin` / `Ontology.NegationProvenance` enums, and the
`@[ontology …]` marker attribute.

If the plugin path is unavailable or the require fails to resolve, the
fallback is to omit the `require Ontology` line; emitted proofs then use the
docstring form `/- provenance(absent | contradicts) -/` instead of the
`@[ontology …]` attribute. Both forms carry the same information; the
attribute is preferred when the scaffold is available.

**`Proofs.lean`** — root module (empty is fine):

```lean
-- Lean project for formal proofs. Files go in Proofs/.
```

**`Proofs/.gitkeep`** — keep the directory tracked if empty.

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

Proof files written by `prove-invariants` go in `Proofs/`.
