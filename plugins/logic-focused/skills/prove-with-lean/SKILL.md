---
name: prove-with-lean
description: >
  Formally verify code properties using Lean 4 theorem prover. Translates code
  into Lean 4 specifications and constructs machine-checked proofs. Spawns prover
  sub-agents with automatic validation via PostToolUse hooks.
  Use when: "prove this correct", "verify this invariant", "formally verify",
  "prove that this sorts", "check this is safe".
user-invocable: true
model: opus
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[code to verify and property to prove]"
---

# Prove with Lean 4

You are an orchestrator (P) for formal code verification using Lean 4.

## Prerequisites

Before anything else, verify all four:

1. **Lean installed**: `lean --version` must succeed
2. **Shared Mathlib clone exists**: Check for `~/.lean/mathlib4`:
   ```bash
   MATHLIB_ROOT="$(cd ~/.lean/mathlib4 2>/dev/null && pwd)" || echo "NOT FOUND"
   ```
   If not found, tell the user to run the `setup-lean-mathlib` skill first and stop.
3. **Project configured and built**:
   a. Check if `${CLAUDE_SKILL_DIR}/lean/lakefile.lean` contains a `require mathlib from` line.
      If not, append one using the absolute path:
      ```bash
      MATHLIB_ROOT="$(cd ~/.lean/mathlib4 && pwd)"
      echo "" >> ${CLAUDE_SKILL_DIR}/lean/lakefile.lean
      echo "require mathlib from \"$MATHLIB_ROOT\"" >> ${CLAUDE_SKILL_DIR}/lean/lakefile.lean
      ```
   b. Copy the toolchain from the shared clone:
      ```bash
      cp "$MATHLIB_ROOT/lean-toolchain" ${CLAUDE_SKILL_DIR}/lean/lean-toolchain
      ```
   c. Generate the manifest (no network access needed):
      ```bash
      cd ${CLAUDE_SKILL_DIR}/lean
      python3 ${CLAUDE_SKILL_DIR}/../setup-lean-mathlib/scripts/generate_manifest.py proveWithLean
      ```
   d. If `${CLAUDE_SKILL_DIR}/lean/.lake/build/` does not exist, build:
      ```bash
      cd ${CLAUDE_SKILL_DIR}/lean && LAKE_ARTIFACT_CACHE=true lake build
      ```
4. **Hook active**: `${CLAUDE_SKILL_DIR}/.claude/settings.json` must contain a PostToolUse hook for Edit|Write. If missing, the prover will get no feedback — a silent failure mode.

If any prerequisite fails, report the issue and stop.

## Step 1: Read and Analyze Target Code

Read the code the user wants verified. Determine:
- **Function/module**: What specific code to verify
- **Property**: What to prove (from user description, or infer: correctness, safety, invariant)
- **Domain**: What Lean/Mathlib concepts apply (lists, arithmetic, data structures, etc.)

## Step 2: Spawn Prover Sub-Agent

Use the Agent tool to spawn a fresh prover (L). Pass this prompt, filling in the template variables:

---

**Agent parameters:**
- `model`: opus
- `description`: "Prove {property} for {function_name}"
- `prompt`: (see template below)

**Prover (L) Prompt Template:**

> You are a Lean 4 prover agent. Write a formal proof that is checked by Lean's kernel.
>
> ## Target Code
> ```{language}
> {target_code}
> ```
>
> ## Property to Prove
> {property_description}
>
> ## Lean Project
> - Working directory: `${CLAUDE_SKILL_DIR}/lean`
> - Write proofs to: `${CLAUDE_SKILL_DIR}/lean/ProveWithLean/Proofs/`
> - Specs available at: `${CLAUDE_SKILL_DIR}/lean/ProveWithLean/Specs/`
>
> ## Instructions
> 1. Create a `.lean` file in `ProveWithLean/Proofs/` containing:
>    - `import Mathlib` and any needed Mathlib submodules
>    - Lean 4 definitions modeling the target code's types and logic
>    - A `theorem` statement expressing the property
>    - A tactic proof (use `by` blocks with simp, omega, aesop, decide, induction, cases, etc.)
> 2. After you write the file, a validation hook runs `lake build` automatically.
>    - If you see error diagnostics, read them carefully and fix the proof.
>    - If you see no error output, the file compiled — the proof is valid.
> 3. You have up to 5 self-correction attempts. Use them wisely:
>    - Syntax/tactic errors: fix directly based on the error message
>    - Type mismatches: reconsider your Lean modeling of the target code
>    - Timeout/deterministic timeout: simplify the proof strategy
> 4. When done (success or budget exhausted), report:
>    - **Status**: success or failure
>    - **Files written**: list of .lean file paths
>    - **Diagnostics**: final error messages (if failure)
>    - **Approach**: brief description of proof strategy used
>
> ## Lean 4 Conventions
> - Always set `set_option autoImplicit false` at file top
> - Prefer Mathlib definitions over custom ones (e.g., `List.Sorted`, `List.Perm`)
> - Use `#check` and `#print` to explore available lemmas
> - Try `exact?`, `apply?`, `simp?` when stuck — they suggest applicable lemmas
> - For numeric properties, try `omega` first
>
> {retry_context}

**Retry context** (only on iterations 2+):
> ## Prior Attempts
> This is attempt {iteration_number} of 3. Previous attempts failed.
>
> **Previous approach**: {prior_approach}
>
> **Previous diagnostics**:
> ```
> {prior_diagnostics}
> ```
>
> **Previous files** (read these to understand what was tried):
> {prior_file_paths}
>
> Do NOT repeat the same approach. Try a fundamentally different proof strategy.
> If prior attempts had type mismatches in the specification itself (not just the proof),
> reconsider whether the Lean definitions correctly model the target code.

---

## Step 3: Evaluate Result

Read L's response and decide:

### Success
Report to the user:
- The theorem statement (what was proved)
- That it was machine-checked by Lean's kernel
- The file path for reference

### Failure — Budget Remaining (< 3 outer iterations)
Analyze L's diagnostics:
- **Different errors each time**: Good — approaches are varying. Spawn L' with retry context.
- **Same type mismatch 2+ times**: The specification may be wrong. Before spawning L', reconsider whether the Lean definitions correctly model the target code's semantics. Adjust the property description or modeling approach in the retry prompt.
- **Timeout/resource errors**: Simplify the verification target. Consider proving a weaker property.

Spawn a new L' with full retry context (prior diagnostics, prior files, prior approach, incremented iteration number).

### Failure — Budget Exhausted
Report to the user:
- What was attempted across all iterations
- The final diagnostics
- Whether the issue appears to be the proof (tactics), the specification (modeling), or the property (may not be provable with current tooling)
- Suggestions for manual next steps

## Configuration
- **Outer iterations** (P spawns fresh L): 3
- **Inner corrections** (L self-fixes per spawn): 5
- **Hook timeout**: 120 seconds
- **Proof directory**: `${CLAUDE_SKILL_DIR}/lean/ProveWithLean/Proofs/`
