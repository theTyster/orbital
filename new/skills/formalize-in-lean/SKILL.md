---
name: formalize-in-lean
description: >
  Formalize a hypothesis as Lean4 theorems with machine-checked proofs.
  Reads a hypothesis file, translates properties into Lean4, and attempts
  to prove them. Loops back to query-hypothesis if unprovable.
  Use when: "formalize this hypothesis", "prove this in lean", "verify this formally".
user-invocable: true
model: opus
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[hypothesis file path] [optional: prolog facts file for fallback]"
---

# Formalize in Lean4

Read a structured hypothesis file and translate each formal property into a
Lean4 theorem with a machine-checked proof. If a property is unprovable,
loop back to query-hypothesis to refine.

## Prerequisites

1. **Lean installed**: `lean --version` must succeed.
2. **Lean project built**: A Lean project with Mathlib must be available.

```
LEAN_SKILL=${CLAUDE_SKILL_DIR}/../../plugins/marketplaces/logic-focused-plugins/skills/prove-with-lean
LEAN_PROJECT=${LEAN_SKILL}/lean
LEAN_PROOFS=${LEAN_PROJECT}/ProveWithLean/Proofs
```

If these paths don't exist, search for `ProveWithLean` with Glob and adjust.
If `${LEAN_PROJECT}/.lake/build/` doesn't exist, run `cd ${LEAN_PROJECT} && lake build`.

3. **Hypothesis file**: A `thoughts/hypothesis.md` from the query-hypothesis skill.

## Process

### 1. Read the Hypothesis

Read the hypothesis file. Extract:
- The formal properties listed under "Formal Properties"
- Their natural language descriptions
- Any Lean sketch provided
- Assumptions and scope

### 2. Translate to Lean4

For each formal property, create a `.lean` file in `${LEAN_PROOFS}/`:

```lean
import Mathlib

set_option autoImplicit false

-- Property: {natural language description}
-- From hypothesis: {hypothesis title}

{Lean definitions modeling the domain}

theorem {property_name} : {formal statement} := by
  {tactic proof}
```

**Translation guidelines:**
- Map domain types to Lean types (use Mathlib where possible)
- Express relationships as propositions
- Graph properties → use Mathlib's `SimpleGraph` or model with `Finset`
- Set properties → use `Finset` or `Set`
- Ordering properties → use `PartialOrder`, `LinearOrder`
- Numeric properties → try `omega` first

### 3. Verify Each Property

After writing each `.lean` file:
```bash
cd ${LEAN_PROJECT} && lake build
```

**On success**: The property is machine-checked. Record it as proven.

**On failure**: Self-correct up to 5 attempts per property:
- Syntax/tactic errors → fix based on error message
- Type mismatches → reconsider the Lean modeling
- Timeout → simplify the proof strategy
- Use `exact?`, `apply?`, `simp?` to discover applicable lemmas

### 4. Handle Unprovable Properties

If a property exhausts correction attempts (5 inner × 3 outer = 15 total):

**Diagnose the failure mode:**

| Failure type | Meaning | Action |
|-------------|---------|--------|
| Tactic failure | Proof strategy wrong, property may still hold | Try fundamentally different approach |
| Type mismatch | Lean model doesn't match domain | Revise definitions |
| Logical contradiction | Property may be false | **Loop back** |
| Timeout | Property too complex for automation | Decompose into sub-properties |

**Loop back to query-hypothesis:**

When a property appears genuinely unprovable (logical contradiction or persistent
type mismatches after modeling revisions), invoke the query-hypothesis skill:

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

### 5. Produce Results

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
- **Action taken**: {looped back to query-hypothesis / decomposed / weakened}

## Lean Files
{list of all .lean files written}
```

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

- One or more `.lean` files in `${LEAN_PROOFS}/`
- A `thoughts/proof_results.md`
- If any properties looped back: a request to re-run query-hypothesis

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
- **Prover model**: opus (for sub-agents)
