---
name: translate-proof-for-llm
description: >
  Translate a proven Lean4 file into a precise natural language logical description
  formatted for LLM consumption. Preserves formal structure, quantifiers, and
  logical connectives in a machine-parseable format.
  Use when: "translate proof for llm", "create logical description from lean", "export proof as logic".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
argument-hint: "[lean proof file or proof_results.md path]"
---

# Translate Proof for LLM

Read a proven Lean4 file and produce a natural language logical description
that preserves the formal structure in a format optimized for LLM consumption.
The output is a structured document that an LLM can use to reason about the
proven properties without needing Lean4 knowledge.

## Input

Accept one of:
- A `.lean` proof file (single file)
- A `thoughts/proof_results.md` from the formalize-in-lean skill (processes all proven files)

Read the input. For `.lean` files, extract:
- All `theorem` and `lemma` declarations
- All `def` and `structure` definitions
- Import context (what Mathlib modules are used)
- Comments explaining intent

For `proof_results.md`, read each referenced `.lean` file listed under "Proven Properties".

## Process

### 1. Extract Formal Structure

For each theorem/lemma, identify:
- **Quantifiers**: `∀`, `∃` and their bound variables with types
- **Hypotheses**: preconditions (left of `→`)
- **Conclusion**: what is proven (rightmost proposition)
- **Definitions used**: custom types and their constructors
- **Mathlib concepts**: standard mathematical structures referenced

### 2. Translate to Logical Description

Produce a structured logical description for each theorem. Use precise natural
language that preserves the formal meaning.

**Translation rules:**
| Lean construct | Natural language form |
|---------------|----------------------|
| `∀ (x : T)` | "For all x of type T" |
| `∃ (x : T)` | "There exists an x of type T such that" |
| `→` | "implies" or "if ... then ..." |
| `∧` | "and" (both conditions hold simultaneously) |
| `∨` | "or" (at least one condition holds) |
| `¬` | "it is not the case that" |
| `↔` | "if and only if" |
| `=` | "equals" / "is identical to" |
| `≤` / `<` | "is at most" / "is strictly less than" |
| `List.Sorted` | "the list is sorted according to the given ordering" |
| `List.Perm` | "is a permutation of" (same elements, possibly reordered) |

### 3. Write the Output

Write to `thoughts/proof_logic.md` (create `thoughts/` if it doesn't exist):

```markdown
# Logical Description: {source hypothesis or file name}

## Metadata
- Source: {lean file path(s)}
- Proven by: Lean 4 kernel (machine-checked)
- Generated: {date}

## Definitions

### {definition_name}
- **Type**: {what kind of thing it is}
- **Structure**: {fields or constructors}
- **Interpretation**: {what it represents in the domain}

## Proven Properties

### Property: {theorem_name}
- **Formal**: `{lean theorem signature}`
- **Plain logic**:
  > For all {variables with types}, if {hypotheses}, then {conclusion}.
- **Domain interpretation**: {what this means in the original problem domain}
- **Strength**: {how strong this guarantee is — universal, conditional, existential}
- **Dependencies**: {which definitions and other properties this relies on}

### Property: {next_theorem_name}
...

## Logical Chain
{How the properties relate to each other. Which properties build on which.
 Present as a dependency graph in text form:}

1. {base_property} (no dependencies)
2. {derived_property} (depends on: base_property)
3. ...

## Constraints for Downstream Use
- These properties are proven under the assumptions listed in each property.
- Violating a hypothesis invalidates the conclusion.
- The domain interpretation is approximate — the formal statement is authoritative.
```

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

A `thoughts/proof_logic.md` file designed to be consumed by:
- The plan-from-proof skill (to create implementation plans)
- Any LLM session that needs to reason about the proven guarantees
- Automated pipelines that chain formal verification with code generation

Report:
- File path
- Number of definitions translated
- Number of properties translated
- Source Lean file(s)
