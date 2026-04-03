# logic-focused-claude

Logic-focused skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): formal verification with Lean 4, formal reasoning with SWI-Prolog, logical pseudocode scaffolding, parallel multi-plan orchestration, and logical commit generation.

## Skills

### prove-with-lean

Formally verify code properties using Lean 4 theorem prover. Translates code into Lean 4 specifications and constructs machine-checked proofs. Spawns prover sub-agents with automatic validation via PostToolUse hooks.

**Triggers**: "prove this correct", "verify this invariant", "formally verify", "prove that this sorts", "check this is safe"

### reason-with-prolog

Formal reasoning using SWI-Prolog and C4 model ontologies to analyze codebases before planning implementation. Maps codebases to C4 architectural facts, validates with Prolog, and produces implementation plans grounded in formal analysis.

**Triggers**: "analyze this codebase", "plan this change formally", "what's the impact of changing X", "explore relationships"

### scaffold-pseudocode

Produce a logical pattern document (proof-of-concept scaffold) for a code enhancement. Captures invariants, type relations, logic flow, and edge predicates in a form that feeds directly into Prolog reasoning and Lean verification. Used standalone or as the first step in the multi-plan pipeline.

**Triggers**: "scaffold this feature", "write pseudocode for X", "logical pattern for this change"

### multi-plan

Orchestrate multiple enhancements in parallel, each with a dedicated worktree/branch, through a plan > review > human-vetting > implement > commit pipeline. Integrates with scaffold-pseudocode, prove-with-lean, and reason-with-prolog for plan validation.

**Triggers**: "plan and implement these enhancements", "multi-plan X, Y, Z", "parallel feature development"

### make-commits

Review all unstaged changes and organize them into logical commits.

**Triggers**: "make commits", "commit these changes logically"

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for prove-with-lean. First build (`lake build` in `skills/prove-with-lean/lean/`) takes 10-20 minutes for Mathlib compilation.
- **SWI-Prolog** (`swipl`): Required for reason-with-prolog and multi-plan's Prolog analysis.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## License

Apache 2.0
