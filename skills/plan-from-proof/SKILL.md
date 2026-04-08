---
name: plan-from-proof
description: >
  Create a concrete implementation plan grounded in a proven logical description.
  Uses the formal guarantees from proof_logic.md to structure the plan, ensuring
  implementation respects proven invariants and dependency ordering.
  Use when: "create a plan from this proof", "implement based on the proof", "plan from verified logic".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent
argument-hint: "[proof_logic.md path] [optional: target codebase directory]"
---

# Plan from Proof

Create an implementation plan that is structurally grounded in proven formal
properties. The plan respects proven invariants, follows the dependency ordering
established by the proofs, and flags any implementation decisions that could
violate the formal guarantees.

## Input

- **Required**: A `thoughts/proof_logic.md` from the translate-proof-for-llm skill
- **Optional**: A target codebase directory to ground the plan in existing code

Read `thoughts/proof_logic.md` thoroughly. Extract:
- All proven properties and their domain interpretations
- The logical chain (dependency ordering between properties)
- Definitions and their domain interpretations
- Constraints for downstream use

If a target codebase is provided, explore it with `Glob`, `Grep`, `Read`,
and `Agent(Explore)` to understand the current state.

## Process

### 1. Map Properties to Implementation Requirements

For each proven property, derive concrete implementation requirements:

| Proven property | Implementation requirement |
|----------------|---------------------------|
| "For all inputs X, output is sorted" | Sort function must handle all input types |
| "If A then B" | When condition A is detected, ensure B is produced |
| "A and B are equivalent" | Can implement via either path; must maintain equivalence |
| "No state S where invariant is violated" | Guard against state S in all code paths |

### 2. Determine Implementation Order

Use the logical chain from `proof_logic.md`:
- Properties with no dependencies → implement first (foundational types, base cases)
- Properties that depend on others → implement after their dependencies
- Properties that are interdependent → implement together as a unit

Cross-reference with codebase dependency analysis if a target codebase is provided.

### 3. Identify Invariant Guards

For each proven property, identify where the implementation must actively
maintain the invariant:

- **Construction sites**: Where the data structure is created — must satisfy invariant from birth
- **Mutation sites**: Where the data structure is modified — must preserve invariant
- **Boundary sites**: Where data enters or leaves the system — must validate invariant

### 4. Write the Plan

Write to `thoughts/implementation_plan.md` (create `thoughts/` if it doesn't exist):

```markdown
# Implementation Plan: {title from proof_logic.md}

## Grounding
This plan is derived from machine-checked proofs. The following properties
are formally guaranteed and must be preserved by the implementation:

{List each proven property with its domain interpretation}

## Implementation Order

### Phase 1: {foundation}
**Implements**: {which proven properties}
**Why first**: {no dependencies / required by later phases}

#### Tasks
1. {specific task}
   - **Files**: {files to create or modify}
   - **Invariant**: {which proven property this task must respect}
   - **Test**: {how to verify this task preserves the invariant}

2. ...

### Phase 2: {next layer}
**Implements**: {which proven properties}
**Depends on**: Phase 1 ({specific properties})

#### Tasks
...

### Phase N: {final integration}
...

## Invariant Guard Map

| Invariant | Guard location | Guard type | Implementation note |
|-----------|---------------|------------|-------------------|
| {property} | {file:function} | construction | must hold at creation |
| {property} | {file:function} | mutation | must be preserved |
| {property} | {file:function} | boundary | must be validated |

## Risk Register

| Risk | Proven property at risk | Mitigation |
|------|------------------------|------------|
| {what could go wrong} | {which property} | {how to prevent} |

## Verification Checklist
For each phase, before proceeding to the next:
- [ ] All tasks complete
- [ ] Invariants verified by tests
- [ ] No proven property violated by new code

## Assumptions
{Assumptions from the proof that the implementation relies on.
 If any assumption is violated in practice, the guarantees don't hold.}
```

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

A `thoughts/implementation_plan.md` file.

Report:
- File path
- Number of phases
- Number of proven properties the plan covers
- Any properties that couldn't be mapped to implementation tasks (gaps)

## Guidance

- **Proofs are constraints, not blueprints**: The proof tells you what must be true, not how to code it. The plan bridges that gap.
- **Flag gaps**: If a proven property can't be cleanly mapped to an implementation task, flag it explicitly. Don't silently drop formal guarantees.
- **Test strategy follows proof structure**: Each proven property should map to at least one test. The proof tells you the property; the test verifies the implementation achieves it.
- **Don't over-constrain**: The proof establishes minimum requirements. The plan should leave room for implementation decisions that don't affect the proven properties.
