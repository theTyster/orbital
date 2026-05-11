# Lean 4 Tooling Glossary

| Term | What it is |
|---|---|
| **elan** | Lean version manager (like rustup for Rust). Installs toolchains to `~/.elan/toolchains/`. Selects which `lean`/`lake` binary to use based on `lean-toolchain` file. |
| **lake** | Build system and package manager for Lean 4. Bundled with each Lean toolchain — no separate install needed. |
| **mathlib4** | The community mathematics library for Lean 4. ~700k+ lines. Hours to compile from source; always use pre-built oleans. |
| **`.olean`** | Compiled Lean module (Lean's equivalent of `.o` or `.pyc`). Produced by `lake build` or downloaded via `lake exe cache get`. |
| **`.ltar`** | Compressed archive of `.olean` files. Downloaded from Mathlib CI into `~/.cache/mathlib/`, then extracted into `.lake/build/`. |
| **`.olean.hash`** | 16-byte content hash file sitting beside each `.olean`. Lake uses these for incremental rebuild decisions. Idempotent — safe to regenerate. |
| **`lean-toolchain`** | File in the project root specifying which Lean version to use (e.g., `leanprover/lean4:v4.29.0`). elan reads this to select the toolchain. |
| **`lakefile.toml` / `lakefile.lean`** | Project configuration. Declares dependencies, build targets, library/executable names. The `.toml` format is newer and preferred for simple projects. |
| **`lake-manifest.json`** | Dependency lockfile. Each entry is either `"type": "git"` (cloned from a URL) or `"type": "path"` (local directory). The shared-clone workflow converts all entries to path type. |
| **`LAKE_ARTIFACT_CACHE`** | Environment variable (`true`/`false`). When enabled, Lake maintains a content-addressed cache of build artifacts shared across all projects. Lean 4.22+. Caches `.olean` files only, not source repositories. |
| **`lake exe cache get`** | Downloads pre-built `.olean` archives from Mathlib's CI. The `.ltar` files land in `~/.cache/mathlib/` (reusable across versions) and are extracted into the project's `.lake/build/`. |
