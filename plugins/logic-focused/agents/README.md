# Agents

Domain expert agent definitions for the logic-focused plugin. Skills spawn these as sub-agents by reading the agent file and using its contents as the agent prompt.

## Usage from Skills

```bash
# Path from any skill's SKILL.md
AGENTS="${CLAUDE_SKILL_DIR}/../../agents"
```

Skills reference an agent by reading its `.md` file and incorporating the instructions into an `Agent()` call. The agent file contains the full briefing — the spawned sub-agent gets the domain expertise without the skill needing to inline it.

## Agents

### lean-expert

Lean 4 formal proof specialist. Uses `lake build` as deductive reasoning steps rather than chain-of-thought. Incorporates adversarial verification patterns: interpretation checking, extracted-lemma counterexample search, and calibrated abstention.

**Used by**: prove-invariants

### agent-of-truth

Prolog KB construction specialist. Identifies facts, relationships, and constraints in any domain. Expert in domain-fitting predicate design, graph/ontology modeling, DCGs for structured parsing, and constraint validation rules. Reads `references/prolog-wiki/` directly when an extension recipe is needed.

**Used by**: close-world, decompose-proposition, measure-entailment

### agent-of-questions

Prolog query specialist. Discovers KB structure through `swipl` introspection alone — never reads `.pl` files directly. Uses the introspect module to understand any KB, then writes precise queries. Reads `references/prolog-wiki/` directly when a query needs an advanced extension.

**Used by**: decompose-proposition, model-obligations, measure-entailment

### prolog-prover

Prolog formal proof specialist. Combines KB construction (agent-of-truth), query expertise (agent-of-questions), and CLP libraries to write exhaustive verification proofs. Every proof is a counterexample search. Reads `references/prolog-wiki/` directly for CLP and tabling recipes.

**Used by**: model-obligations

## Plugin References

The two wikis under `plugins/logic-focused/references/` (`prolog-wiki/` and `lean4-wiki/`) are accessed **only by the agents above** — skills brief the agent with the absolute wiki path but never read the wiki content themselves. This keeps heavy reference material inside sub-agent contexts. When a wiki is thin on a topic, the domain agents fall back to `WebSearch` / `WebFetch` against the official Mathlib 4 or SWI-Prolog docs.
