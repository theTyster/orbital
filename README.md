# logic-focused-claude

Logic-focused skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to implementation planning, plus architectural analysis, parallel orchestration, and logical commit generation.

## Formal Reasoning Pipeline

```
1. translate-to-prolog    — Translate logic into Prolog facts
2. query-hypothesis       — Query Prolog to explore and write a hypothesis
3. formalize-in-lean      — Formalize hypothesis in Lean4 (loops back to 2 if unprovable)
4a. translate-proof-llm   — Translate proven Lean4 into logical description for LLM consumption
4b. translate-proof-human — Translate proven Lean4 into human-readable summary
5. plan-from-proof        — Create implementation plan from the logical description
```

## Skills

### translate-to-prolog

Translate domain logic, requirements, or code behavior into a validated Prolog facts file using C4 ontology predicates.

**Triggers**: "translate this to prolog", "model this logic", "create prolog facts from this code"

### query-hypothesis

Query a Prolog knowledge base to explore relationships, derive hypotheses, and write them to a structured hypothesis file for downstream formalization in Lean4.

**Triggers**: "explore this hypothesis", "query the prolog facts", "what can we derive from this model"

### formalize-in-lean

Formalize a hypothesis as Lean4 theorems with machine-checked proofs. Loops back to query-hypothesis if the hypothesis is unprovable.

**Triggers**: "formalize this hypothesis", "prove this in lean", "verify this formally"

### translate-proof-for-llm

Translate a proven Lean4 file into a precise natural language logical description formatted for LLM consumption. Preserves formal structure, quantifiers, and logical connectives.

**Triggers**: "translate proof for llm", "create logical description from lean", "export proof as logic"

### translate-proof-for-human

Translate a proven Lean4 file into a clear natural language summary for human readers.

**Triggers**: "explain this proof", "summarize the lean proof", "what did we prove"

### plan-from-proof

Create a concrete implementation plan grounded in proven formal properties. Uses formal guarantees to structure phases, invariant guards, and risk registers.

**Triggers**: "create a plan from this proof", "implement based on the proof", "plan from verified logic"

### prove-with-lean

Formally verify code properties using Lean 4 theorem prover. Spawns prover sub-agents with automatic validation via PostToolUse hooks. Use for direct code verification; for hypothesis-driven proofs, use formalize-in-lean instead.

**Triggers**: "prove this correct", "verify this invariant", "prove that this sorts", "check this is safe"

### reason-with-prolog

C4 architectural modeling and Prolog-based codebase analysis. Maps codebases to C4 facts via orbital flow (Find > Define > Condense) and produces implementation plans grounded in formal analysis.

**Triggers**: "analyze this codebase", "plan this change formally", "what's the impact of changing X", "explore relationships"

### scaffold-pseudocode

Produce a logical pattern document (proof-of-concept scaffold) for a code enhancement. Captures invariants, type relations, logic flow, and edge predicates.

**Triggers**: "scaffold this feature", "write pseudocode for X", "logical pattern for this change"

### multi-plan

Orchestrate multiple enhancements in parallel, each with a dedicated worktree/branch, through a plan > review > human-vetting > implement > commit pipeline.

**Triggers**: "plan and implement these enhancements", "multi-plan X, Y, Z", "parallel feature development"

### make-commits

Review all unstaged changes and organize them into logical commits.

**Triggers**: "make commits", "commit these changes logically"

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for formalize-in-lean and prove-with-lean. First build (`lake build` in `skills/prove-with-lean/lean/`) takes 10-20 minutes for Mathlib compilation.
- **SWI-Prolog** (`swipl`): Required for translate-to-prolog, query-hypothesis, reason-with-prolog, and multi-plan.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## License

Apache 2.0
