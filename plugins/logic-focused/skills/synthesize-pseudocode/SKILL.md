---
name: synthesize-pseudocode
description: >
  Synthesize pseudocode from any combination of sources: requirements, existing code, Lean proofs, Prolog KB, hypotheses. Works as a planner (requirements + code → new implementation), a converger (multiple formal artifacts → unified logic), or a condenser (large artifacts → compact reference). The synthesized pseudocode is the deliverable — downstream skills consume it instead of re-reading originals. Use when: "synthesize pseudocode", "plan this from requirements", "combine logic sources", "condense for implementation", "converge code and proofs", "synthesize from lean and prolog", "write pseudocode for this feature", "what should this implementation look like".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent
argument-hint: "[requirements, source files, or target directory]"
---

# Synthesize Pseudocode

Produce a unified pseudocode artifact from whatever sources are available. This skill is a **planner masked as a translator** — the output is not just a summary of what exists, but a logically coherent target that an implementor can execute against.

It operates in three modes, which can overlap:

1. **Planning**: Given requirements (specs, tickets, markdown docs) and optionally existing code, synthesize pseudocode for a new or modified implementation. The output represents a *target state* — what should be true after the implementation. Gaps between current behavior and requirements become explicit delta items.

2. **Convergence**: When logic is spread across formal artifacts (Lean proofs, Prolog KB, hypotheses, code), synthesize them into a single document that captures the combined logical picture. Contradictions and partial overlaps are first-class outputs.

3. **Condensation**: When the original artifacts are too large to fit in a downstream context window, the synthesized pseudocode replaces them. Downstream skills (translate-to-tests, prove-hypothesis-lean, formalize-in-lean) consume `pseudocode.md` directly. File paths to originals are preserved as provenance references but re-reading them is discouraged.

Use whichever modes are relevant. Most real invocations involve at least two.

## When used from multi-plan

When invoked as part of the multi-plan pipeline, write output to `plan/pseudocode.md` in the current worktree. The synthesized file feeds downstream skills:
`pseudocode.md → translate-to-tests | prove-hypothesis-lean | formalize-in-lean`

---

## Input

Accept any combination of the following source types. No single source is required — synthesize from whatever is available. Requirements alone are sufficient to produce a planning pseudocode; formal artifacts alone are sufficient to produce a convergence pseudocode.

| Source type | Typical path | What it contributes |
|-------------|-------------|---------------------|
| Requirements | spec docs, tickets, markdown, inline description | Target behavior: what the implementation must do |
| Lean proof file | `thoughts/lean/*.lean` | Formally verified invariants, type signatures, theorem statements |
| Proof results doc | `thoughts/proof_results.md` | Human-readable translation of proven properties and their domain meaning |
| Prolog KB | `thoughts/reasoning.pl`, `*.pl` | Structural facts, dependency graph, predicate relationships |
| Hypothesis doc | `thoughts/hypothesis.md` | Propositions, decomposed sub-claims, confirmed/refuted evidence |
| Source code files | any `.ts`, `.py`, `.go`, etc. | Ground-truth current behavior: types, control flow, edge handling |
| Target directory | any directory path | Explore to discover relevant code when no explicit files are named |

If the user provides a directory rather than specific files, use `Glob`, `Grep`, and `Agent(Explore)` to discover the relevant artifacts before synthesizing.

---

## Process

### 1. Inventory available sources

Before reading anything, enumerate what exists:

- Check `thoughts/` for `hypothesis.md`, `proof_results.md`, `lean/`, and any `.pl` files
- `Glob` for `.lean` files in scope
- If a target directory is provided, `Glob` its structure to find relevant code files
- List every source found — this becomes the "Sources Consulted" section

Do not skip this step. A complete inventory prevents accidental omissions that would silently drop logic from the synthesis.

### 2. Read each source with a provenance label

Read every identified source. As you read, tag each logical claim with its origin:

- `[from: thoughts/proof_results.md]`
- `[from: thoughts/reasoning.pl]`
- `[from: thoughts/lean/proof.lean]`
- `[from: thoughts/hypothesis.md]`
- `[from: src/core/auth.ts]`

Keep the provenance labels precise: use the actual file path, not a generic category. Two sources may contribute overlapping claims — record both and note the overlap.

### 3. Extract logical content by type

For each source, extract the relevant logical content:

**From requirements**: the behaviors the system must exhibit, constraints it must satisfy, and outcomes it must produce. Express as propositions: "given X, the system must Y". Identify explicit constraints (must, must not, shall) separately from implied behavior. These become the target state for planning mode.

**From Lean files**: theorem statements, type definitions, `have` lemmas, `suffices` claims. Extract the logical proposition each theorem encodes — not the tactic proof.

**From proof_results.md**: proven properties and their natural-language domain interpretations. The property name and its meaning.

**From Prolog KB**: the predicate schema (what predicates exist and their arities), ground facts of significance, and any rules (`:- ` clauses). Note structural relationships that appear as binary predicates.

**From hypothesis.md**: the proposition, surviving sub-hypotheses (confirmed), refuted sub-hypotheses, and open assumptions. Confirmed sub-hypotheses become invariants; refuted ones become constraints or edge predicates.

**From source code**: actual types, function signatures, control flow patterns, boundary conditions. Grep for interface definitions, type declarations, and return types on entry points. In planning mode, this is the *current* state that the implementation must move away from.

### 4. Detect contradictions and gaps

Compare logical content across sources:

- **Contradiction**: Source A asserts `P`, source B asserts `¬P`. Flag explicitly with both source paths.
- **Partial overlap**: Source A says X must hold for inputs of type T; source code shows type T is also used in contexts source A ignores. Note the gap.
- **Assumption mismatch**: A hypothesis assumes X; the Prolog KB shows X is not universally true. Flag as a weakened invariant.
- **Missing coverage**: A source covers module M thoroughly but another module N is relevant and uncovered. Note as a synthesis gap.

Do not silently resolve contradictions by picking one source. Flag them all — the downstream consumer decides.

### 5. Unify into pseudocode sections

Produce the unified `pseudocode.md` using the output format below. Write from the synthesis, not by copying source text. The pseudocode should be readable without consulting any original source.

Every claim in the output must carry a provenance marker. Every section that has no provenance is a synthesis inference — mark it `[synthesized]`.

### 6. Write the output file

Write to `thoughts/pseudocode.md` (or `plan/pseudocode.md` in multi-plan context). Create the `thoughts/` directory if it does not exist.

---

## Output Format

```markdown
# Pseudocode: {subject}

## Sources Consulted

| Source | Type | Path |
|--------|------|------|
| Lean proof | formal proof | thoughts/lean/proof.lean |
| Proof results | human summary | thoughts/proof_results.md |
| Prolog KB | structural facts | thoughts/reasoning.pl |
| Hypothesis | evidence doc | thoughts/hypothesis.md |
| Auth module | source code | src/core/auth.ts |

*Downstream skills should treat this document as the authoritative logic
reference and avoid re-reading the original sources unless resolving a
flagged contradiction.*

---

## Invariants
Properties that must hold. Each marked with its source.

- **Pre**: conditions that must be true before the operation
  - `{condition}` [from: thoughts/proof_results.md]
  - `{condition}` [from: thoughts/hypothesis.md — confirmed sub-hypothesis]

- **Post**: conditions that must be true after the operation
  - `{condition}` [from: thoughts/lean/proof.lean — theorem {name}]

- **Maintained**: properties preserved throughout (loop invariants, structural invariants)
  - `{condition}` [from: src/core/auth.ts — inferred from type constraints] [synthesized]

## Types & Relations
Types and structural relationships from all sources combined.

| Entity | Kind | Responsibility | Source |
|--------|------|---------------|--------|
| {name} | type / module / service | what it does | thoughts/reasoning.pl |

| Relation | From | To | Nature | Source |
|----------|------|----|--------|--------|
| depends_on | A | B | A calls/imports/uses B | thoughts/reasoning.pl |
| contains | A | B | A structurally contains B | src/core/auth.ts |
| proves | theorem_X | property_Y | formal guarantee | thoughts/lean/proof.lean |

## Logic Sketch
Step-by-step logical flow converged from all sources. Not implementation
code — logical steps that can be verified.

1. **Given** {precondition} [from: thoughts/hypothesis.md], **when** {action}, **then** {postcondition} [from: thoughts/proof_results.md]
2. **Assert** {condition} [from: thoughts/reasoning.pl — predicate {name}]
3. **Derive** {conclusion} from {premises} [synthesized from proof_results.md + hypothesis.md]
4. **Transform** {input} to {output} by {rule} [from: src/module.ts — function {name}]

## Edge Predicates
Edge cases from all sources, with expected behavior and provenance.

| Predicate | Expected behavior | Source |
|-----------|-----------------|--------|
| `input = ∅` | return empty / error / default | thoughts/hypothesis.md — refuted sub-hypothesis H2 |
| `key ∈ map` | update existing / reject duplicate | src/core/cache.ts |
| `{condition}` | {behavior} | [synthesized] |

## Implementation Delta
*(Planning mode only — omit if no requirements source was used.)*

What must change relative to the current implementation to satisfy the requirements:

| Requirement | Current behavior | Target behavior | Notes |
|-------------|-----------------|-----------------|-------|
| {requirement from spec} | {what code does now} | {what it must do} | {gap or conflict} |

*(If no existing code was provided: "No current implementation to diff against — delta is the full pseudocode above.")*

## Contradictions
Conflicts detected between sources. Must be resolved before implementation.

| Claim | Source A | Source B | Notes |
|-------|----------|----------|-------|
| {proposition P} | asserts P [thoughts/proof_results.md] | asserts ¬P [src/module.ts] | Proof was derived under assumption X which code does not enforce |

*(If no contradictions: "No contradictions detected across sources.")*

## Synthesis Gaps
Areas where source coverage is incomplete.

- **{area}**: Covered by {source A} but not verified in {source B}. Assumption: {what we're taking on faith}.
- **{area}**: No source covers this case. Implementation must decide.

*(If no gaps: "No synthesis gaps detected.")*

## Scope Boundary
What this pseudocode covers and what it explicitly does not.

**In scope**: ...
**Out of scope**: ...
**Deferred**: patterns present in sources but not synthesized here, with reason
```

---

## Output

Write `thoughts/pseudocode.md` (or `plan/pseudocode.md` in multi-plan context).

Report to the user:
- List of sources consulted (one line each with type and path)
- Number of invariants synthesized
- Number of contradictions found
- Number of synthesis gaps flagged
- File path written

Then state which downstream skill is the natural next step based on what was synthesized:
- If formal properties are present → **"This pseudocode is ready for `formalize-in-lean` or `prove-hypothesis-lean`."**
- If structural relations dominate → **"This pseudocode is ready for `translate-to-prolog`."**
- If the logic is implementation-complete → **"This pseudocode is ready for `translate-to-tests` or direct implementation."**

Do not automatically invoke the downstream skill. The user should review the contradictions and gaps first.

---

## Guidance

- **This is a planning skill**: The pseudocode is not just a summary of inputs — it is a target. When requirements are present, the pseudocode describes what *should* be true after implementation. When only formal artifacts are present, it describes what *is* true according to those artifacts. Either way, an implementor should be able to read `pseudocode.md` and know exactly what to build.

- **Condenser discipline**: The synthesized output must be self-contained enough that a downstream skill does not need to open any original source to understand the logic. If a concept from an original source cannot be captured without the original file, the synthesis is incomplete — go back and capture it.

- **Provenance is non-optional**: Every logical claim must carry a source marker. Claims without provenance cannot be verified or trusted when contradictions arise. Mark genuine inferences as `[synthesized]` rather than leaving them unmarked.

- **Contradictions are outputs, not failures**: A contradiction between a Lean proof and source code is valuable information — it usually means the proof was proven under assumptions the code doesn't enforce, or the code has drifted. Flagging it is more useful than silently picking a winner.

- **Synthetic fidelity over completeness**: When sources are large, prioritize capturing the core logical structure over exhaustively enumerating every fact. The goal is a document that preserves logical meaning, not a verbatim copy. Omit implementation details (logging, config, UI) unless they encode logical constraints.

- **Same structural skeleton, richer content**: The Invariants / Types & Relations / Logic Sketch / Edge Predicates sections provide the same organizing structure as before. The difference is that every entry now carries a source marker, and Contradictions and Synthesis Gaps are first-class sections rather than edge cases.

- **No single dominant source**: Resist the temptation to treat one source as canonical and use the others for confirmation. Each source captures a different projection of the truth — a Lean proof captures what is formally guaranteed, Prolog facts capture structural relationships, and source code captures what is actually running. All three projections matter.
