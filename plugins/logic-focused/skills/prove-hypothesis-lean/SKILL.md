---
name: prove-hypothesis-lean
description: >
  Use this skill whenever the user wants to prove a hypothesis in Lean4 — "formalize this", "prove this in lean", "verify formally", "machine-check these properties". Reads hypothesis.md, translates each property to a Lean4 theorem, and proves it; loops back to hypothesize if unprovable.
user-invocable: true
model: opus
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[hypothesis file path] [optional: prolog facts file for fallback]"
---

# Formalize in Lean4

Read a structured hypothesis file and translate each formal property into a Lean4 theorem with a machine-checked proof. If a property is unprovable, loop back to hypothesize to refine.

## Prerequisites

1. **Lean installed**: `lean --version` must succeed.
2. **Shared Mathlib clone exists**: Check for `~/.lean/mathlib4`:
   ```bash
   MATHLIB_ROOT="$(cd ~/.lean/mathlib4 2>/dev/null && pwd)" || echo "NOT FOUND"
   ```
   If not found, tell the user to run the `setup-lean-mathlib` skill first and stop.
3. **Lean project exists in working directory**: Check for `thoughts/lean/.lake/build/`:
   ```bash
   LEAN_PROJECT="thoughts/lean"
   LEAN_PROOFS="${LEAN_PROJECT}/Proofs"
   ```
   If `${LEAN_PROJECT}/.lake/build/` does not exist, invoke the `setup-lean-project` skill
   to create and build it before continuing.

3. **Hypothesis file**: A `thoughts/hypothesis.md` from the hypothesize skill.

## Delegate to `lean-expert`

The primary way to execute this skill is to spawn the `logic-focused:lean-expert` sub-agent with the `Agent` tool. That agent is the Lean 4 proof engineer: it treats `lake build` as its reasoning tool rather than chain-of-thought, and applies adversarial verification patterns (interpretation checking, extracted-lemma counterexample search, calibrated abstention). Running Lean proofs through a sub-agent also isolates the noisy compiler output from your main context.

Brief the sub-agent with:
- The hypothesis file path
- The Lean project root (`thoughts/lean`) and proofs directory (`thoughts/lean/Proofs`)
- The shared Mathlib location (`~/.lean/mathlib4`)
- The per-property correction budget (5 inner / 3 outer, see §4)
- An instruction to produce `thoughts/proof_results.md` in the format in §7
- An instruction that on genuine unprovability it must stop and report the failure mode rather than rewrite the property to make it go through
- The absolute path to the plugin's Mathlib wiki: `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/` — lean-expert reads this directly for lemma/theorem lookups
- A pointer to the skill-local `${CLAUDE_SKILL_DIR}/references/lean-proof-method.md` methodology doc

Do the work inline only when the user has explicitly asked you to prove it yourself in this turn. Proof size is not a reason — even a one-liner benefits from the specialist's `lake build` discipline and Mathlib familiarity, and inline execution floods the main context with compiler output. When in doubt, delegate. The rest of this file is both your guide for the inline case and the briefing material for the sub-agent.

## Proof Methodology

Read `references/lean-proof-method.md` before writing any proofs. The key principles are summarized here but the reference has full detail with examples.

### One Step at a Time

Write one tactic, check diagnostics (use `done` to see unsolved goals), repeat. Never write multiple tactics before checking. This is the single most important discipline — multi-tactic writes cause cascading errors that waste correction attempts.

- `by sorry` is acceptable for placeholders you're not actively working on.
- `done` is required when you expect there to be next steps in an active proof.

### Error Priority

Fix errors in this exact order — higher-priority errors make lower-priority ones unreliable:

1. **Syntax errors** → 2. **Type errors** → 3. **Unsolved goals / tactic failures** → 4. **Linter warnings**

"Unsolved goals" errors appear on `by` or `=>` lines, NOT where you add tactics. If there's an "unsolved goals" on line 59 but a tactic error on line 65 — fix line 65 FIRST.

Stop writing tactics after any error.

### Work on the Hardest Case First

**Across theorems**: Go directly to the target theorem. Don't fill in `sorry`s in helper lemmas first — Lean treats `sorry` as an axiom, so dependent theorems still work. Move sorries earlier in the file by factoring into lemmas:

```lean
-- Before:
theorem main_theorem : A = C := by sorry

-- After:
theorem lemma1 : A = B := by sorry
theorem lemma2 : B = C := by sorry
theorem main_theorem : A = C := by
  rw [lemma1, lemma2]
```

**Within a proof**: When a proof has multiple cases, `sorry` the easy cases and work on the hardest one first. If the hard case fails, effort on easy cases is wasted.

### Dependent Type Rewriting

When you encounter "motive is not type correct" or similar errors during rewriting, the cause is usually rewriting a term that appears in dependent types. The fix is to generalize first, instantiate last:

```lean
suffices ∀ s, statement_about s by
  have h_specific := the_equality_you_have
  convert this ?_ <;> exact h_specific
intro s
-- Now prove the general statement for arbitrary s
```

## Mathlib Reference

A curated Mathlib wiki ships with this plugin at `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/`. **Don't read it yourself** — wiki content flows through `lean-expert`, which has direct access and returns task-shaped lemma recommendations. Include the absolute wiki path in the briefing when delegating (see above); for inline proofs, spawn `lean-expert` anyway rather than opening the wiki from this context.

This keeps heavy lemma content out of the main context window and preserves the separation between skill orchestration (what this file is) and Mathlib expertise (what the agent provides).

## Process

### 1. Read the Hypothesis

Read the hypothesis file. Extract:
- The formal properties listed under "Formal Properties"
- Their natural language descriptions
- Any Lean sketch provided
- Assumptions and scope

### 2. Translate to Lean4

For each formal property, create a `.lean` file in `${LEAN_PROOFS}/` (i.e. `thoughts/lean/Proofs/`):

```lean
import Mathlib

set_option autoImplicit false

-- Property: {natural language description}
-- From hypothesis: {hypothesis title}

{Lean definitions modeling the domain}

theorem {property_name} : {formal statement} := by
  sorry -- start with sorry, then prove one tactic at a time
```

**Translation guidelines:**
- Map domain types to Lean types (use Mathlib where feasible)
- Express relationships as propositions
- Graph properties → use Mathlib's `SimpleGraph` or model with `Finset`
- Set properties → use `Finset` or `Set`
- Ordering properties → use `PartialOrder`, `LinearOrder`
- Numeric properties → try `omega` first
- Consult the wiki for appropriate lemmas before inventing custom definitions

### 3. Verify Each Property

Write one tactic at a time, building the proof incrementally:

```bash
cd thoughts/lean && lake build
```

After each build:
- If it succeeds with no errors, add the next tactic
- If it fails, stop and fix the error before writing any more tactics
- Use `done` to check what goals remain

**On success** (no `sorry` remaining): The property is machine-checked. Record it as proven.

**On failure**: Self-correct following error priority order:
1. Fix syntax errors first
2. Fix type errors second
3. Fix tactic failures / unsolved goals last
4. Linter warnings are lowest priority

**Tactic discovery** (in order of preference):
1. Consult the bundled Mathlib wiki (`references/lean4-wiki/`) for a lemma matching your goal shape
2. Use `exact?` to find an exact lemma match
3. Use `apply?` to find applicable lemmas
4. Use `simp?` to discover simplification lemmas
5. Try `omega` for arithmetic goals, `decide` for decidable goals, `norm_num` for numeric goals

### 4. Correction Budget

Each property gets a correction budget to prevent infinite loops:

- **Inner corrections** (fix-and-retry on the same approach): 5 attempts
- **Outer iterations** (fundamentally different approach): 3 attempts
- **Total**: 5 inner × 3 outer = 15 attempts max per property

After exhausting inner corrections, step back and try a fundamentally different proof strategy — different tactic, different lemma, different decomposition.

### 5. Proof Cleanup

After getting a proof to work, clean it up immediately:
- Combine redundant steps (`rw [a]; rw [b]` → `rw [a, b]`)
- Test if `simp` can handle more (remove earlier steps one by one)
- Find the truly minimal proof

### 6. Handle Unprovable Properties

If a property exhausts its correction budget:

**Diagnose the failure mode:**

| Failure type | Meaning | Action |
|-------------|---------|--------|
| Tactic failure | Proof strategy wrong, property may still hold | Try fundamentally different approach |
| Type mismatch | Lean model doesn't match domain | Revise definitions |
| Logical contradiction | Property may be false | **Loop back** |
| Timeout | Property too complex for automation | Decompose into sub-properties |

**Loop back to hypothesize:**

When a property appears genuinely unprovable (logical contradiction or persistent type mismatches after modeling revisions), stop and tell the user to re-run hypothesize, providing this context:

```
The following property from hypothesis "{title}" could not be proven:

Property: {name}
Statement: {formal statement}
Failure: {diagnostics summary}

Possible causes:
- The hypothesis may be too strong
- The property may need additional assumptions
- The Prolog model may be missing relevant facts

Please re-query the Prolog facts file at {facts_file_path} to:
1. Check if the property has counterexamples
2. Identify missing relationships that would make it provable
3. Formulate a revised, weaker hypothesis if needed
```

### 7. Produce Results

Write results to `thoughts/proof_results.md` (create `thoughts/` if it doesn't exist):

```markdown
# Proof Results: {hypothesis title}

## Summary
- Properties attempted: N
- Proven: M
- Unprovable (looped back): K
- Status: {complete | partial | failed}

## Proven Properties

### {property_name}
- **Statement**: {Lean theorem statement}
- **File**: {path to .lean file}
- **Strategy**: {brief description of proof approach}

## Unprovable Properties

### {property_name}
- **Statement**: {attempted Lean theorem}
- **Failure mode**: {tactic | type mismatch | contradiction | timeout}
- **Diagnostics**: {final error}
- **Action taken**: {looped back to hypothesize / decomposed / weakened}

## Lean Files
{list of all .lean files written}
```

## Verification

Never declare a proof complete while `sorry` placeholders or error diagnostics remain.

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

- One or more `.lean` files in `${LEAN_PROOFS}/`
- A `thoughts/proof_results.md`
- If any properties looped back: a request to re-run hypothesize

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
- **Prover model**: opus (for sub-agents)
