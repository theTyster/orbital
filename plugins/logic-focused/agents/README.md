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

**Used by**: prove-hypothesis-lean

### agent-of-truth

Prolog KB construction specialist. Identifies facts, relationships, and constraints in any domain. Expert in domain-fitting predicate design, graph/ontology modeling, DCGs for structured parsing, and constraint validation rules.

**Used by**: translate-to-prolog, hypothesize

### agent-of-questions

Prolog query specialist. Discovers KB structure through `swipl` introspection alone — never reads `.pl` files directly. Uses the introspect module to understand any KB, then writes precise queries.

**Used by**: hypothesize, prove-hypothesis-prolog, measure-adherance

### bookworm

Librarian for the plugin's central reference material. Owns exclusive access to `references/prolog-wiki/` and `references/lean4-wiki/`, augments them with web research, and maintains project-specific wiki extensions under `thoughts/prolog-wiki/` and `thoughts/lean4-wiki/` in the caller's working directory. Both wikis follow the same shape: a root `index.md` plus one subdirectory per category (e.g. `extensions/`, `lemmas/`, `theorems/`), one markdown file per entry. Returns task-shaped briefings (recommended library/lemma, minimal snippet, gotchas) rather than raw reference dumps. The only skill-local reference it does *not* own is `skills/prove-hypothesis-lean/references/lean-proof-method.md`, which stays with the lean proving skill.

**Used by**: translate-to-prolog, hypothesize, prove-hypothesis-lean, measure-adherance, lean-expert, prolog-prover, agent-of-truth

### prolog-prover

Prolog formal proof specialist. Combines KB construction (agent-of-truth), query expertise (agent-of-questions), and CLP libraries to write exhaustive verification proofs. Every proof is a counterexample search.

**Used by**: prove-hypothesis-prolog
