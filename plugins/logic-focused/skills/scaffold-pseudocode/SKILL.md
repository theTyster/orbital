---
name: scaffold-pseudocode
description: >
  Produce a logical pattern document (proof-of-concept scaffold) for a code
  enhancement. Captures invariants, type relations, logic flow, and edge
  predicates in a form that feeds directly into Prolog reasoning and Lean
  verification. Use when: "scaffold this feature", "write pseudocode for X",
  "logical pattern for this change".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent
argument-hint: [enhancement description and optional target directory]
---

# Scaffold Pseudocode

Produce a logical pattern document — a proof-of-concept scaffold that captures
an enhancement's core logic in a form amenable to formal reasoning. This is not
an implementation plan. It captures *just enough* logical structure to validate
the approach.

## When used from multi-plan

When invoked as part of the multi-plan pipeline, write output to `plan/pseudocode.md`
in the current worktree. The scaffold feeds downstream artifacts:
`pseudocode.md → reasoning.pl → .lean proofs → proof_summary.md`

---

## Process

### 1. Ground in the codebase

Explore the relevant codebase area to understand what exists:

- `Glob` for file structure around the target area
- `Grep` for types, interfaces, and entry points the enhancement touches
- `Read` key files to understand current behavior
- `Agent(Explore)` for broader context when scope is unclear

The scaffold must reflect reality — don't invent components that don't exist
or ignore constraints the codebase imposes.

### 2. Identify the core logical pattern

Ask: what is the **single logical pattern** this enhancement introduces or
modifies? Examples:
- A new validation rule (predicate over input)
- A data transformation (map from type A to type B)
- A state transition (from state S₁ to S₂ under condition C)
- An ordering constraint (X must happen before Y)
- An access control rule (actor A can perform action P on resource R)

If the enhancement involves multiple patterns, pick the dominant one and note
the others in the scope boundary.

### 3. Write the scaffold

Produce a `pseudocode.md` with the following sections:

---

## Output Format

```markdown
# Scaffold: {enhancement name}

## Intent
One-line description of what the enhancement achieves.

## Invariants
Properties that must hold. Express as logical propositions.
These feed directly into Lean theorem statements.

- **Pre**: conditions that must be true before the operation
- **Post**: conditions that must be true after the operation
- **Maintained**: properties preserved throughout (loop invariants, structural invariants)

Example:
- Pre: `input.length > 0`
- Post: `output is sorted ∧ output is permutation of input`
- Maintained: `∀ i < cursor: result[i] ≤ result[i+1]`

## Types & Relations
Types involved and their relationships. Express as entities and relations.
These feed directly into Prolog `component/4` and `depends_on/2` facts.

| Entity | Kind | Responsibility |
|--------|------|---------------|
| ... | type / module / service | what it does |

| Relation | From | To | Nature |
|----------|------|----|--------|
| depends_on | A | B | A calls/imports/uses B |
| contains | A | B | A structurally contains B |
| produces | A | B | A creates instances of B |

## Logic Sketch
Step-by-step algorithm as logical steps. Not implementation code —
logical flow that can be verified.

Use given/when/then form:
1. **Given** {precondition}, **when** {action}, **then** {postcondition}
2. ...

Or sequential logical steps:
1. Assert {condition}
2. Derive {conclusion} from {premises}
3. Transform {input} to {output} by {rule}

## Edge Predicates
Edge cases as conditions with expected behavior.
Each is a testable predicate.

| Predicate | Expected behavior |
|-----------|------------------|
| `input = ∅` | return empty / error / default |
| `key ∈ map` | update existing / reject duplicate |
| ... | ... |

## Scope Boundary
What this scaffold covers and what it explicitly does not.

**In scope**: ...
**Out of scope**: ...
**Adjacent patterns noted but deferred**: ...
```

---

## Guidance

- **Proof-of-concept, not specification**: Include just enough to validate the
  logical approach. Omit implementation details like error messages, logging,
  configuration, UI.
- **Formal-reasoning-ready**: Every invariant should be expressible as a Lean
  theorem. Every relation should map to a Prolog fact. If you can't express it
  formally, it's too vague — sharpen it.
- **Grounded**: Reference actual files, types, and functions from the codebase.
  Don't invent abstractions that don't exist yet.
- **Focused**: One dominant logical pattern per scaffold. If the enhancement is
  large, produce one scaffold for the core pattern and note deferred patterns
  in the scope boundary.
