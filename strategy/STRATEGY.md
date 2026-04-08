# Merge Strategy: logic-focused-claude + orbital-plugins

Prolog-derived strategy from `merge_facts.pl` + `merge_reasoning.pl`.

## Core Principle

Each skill does one thing well. The new pipeline's single-responsibility decomposition is superior to the existing monolithic skills — but the existing skills have battle-tested infrastructure (Prolog ontology, Lean hooks, worktree orchestration) that must be preserved.

## Final Skill Set (7 skills)

### 1. translate-to-prolog
**Source**: New skill, enhanced with existing infrastructure  
**Replaces**: The fact-extraction phase of `reason-with-prolog`

Take from new: focused single-responsibility extraction  
Take from existing: orbital flow methodology, reusable Prolog infrastructure (`ontology.pl`, `reasoning.pl`, `run.pl`, `scripts/`)

The new skill's focused approach is better, but it currently lacks the proven Prolog modules. Bundle the existing `prolog/` and `scripts/` directories with the new SKILL.md.

### 2. query-hypothesis
**Source**: New skill, absorbs `scaffold-pseudocode`  
**Replaces**: The query/analysis phase of `reason-with-prolog` + all of `scaffold-pseudocode`

Take from new: hypothesis formulation, falsifiable statement generation, formal property identification  
Take from existing scaffold: edge predicate identification, given/when/then logic sketch format

The new skill's hypothesis-driven approach is strictly better for formal reasoning. Incorporate scaffold's edge-case thinking as part of hypothesis formulation — edge predicates become falsifiable conditions.

### 3. formalize-in-lean
**Source**: New skill, enhanced with existing hooks  
**Replaces**: `prove-with-lean`

Take from new: feedback loop to Prolog (loop back to query-hypothesis when unprovable)  
Take from existing: PostToolUse hook validation (`lean-validate.sh`, `.claude/settings.json`), Mathlib integration details, Lean project structure

The new skill is a superset conceptually, but the existing one has working hooks and a built Lean project. Merge the new SKILL.md with the existing `lean/`, `scripts/`, and `.claude/` directories.

### 4. translate-proof-for-llm
**Source**: New skill, keep as-is  
**Status**: Entirely new capability

Converts Lean4 proofs to structured logical descriptions preserving quantifiers and formal structure. This is the critical bridge that makes proofs *usable* by LLMs — the key differentiator of this plugin.

### 5. translate-proof-for-human
**Source**: New skill, keep as-is  
**Status**: Entirely new capability

Converts proofs to jargon-free summaries. Enables non-technical stakeholders to understand what was proven and what it guarantees.

### 6. plan-from-proof
**Source**: New skill, enhanced with multi-plan strengths  
**Replaces**: `multi-plan`

Take from new: proof-grounded planning, invariant guard mapping, risk register  
Take from existing multi-plan: parallel worktree orchestration, human vetting gate, plan-review-iterate cycle

The new skill grounds plans in proven properties — strictly better than planning from pseudocode. But multi-plan's orchestration capabilities (worktrees, review cycles, human gates) are valuable and should be available as an optional mode.

### 7. make-commits
**Source**: Existing skill, keep as-is  
**Status**: No overlap, standalone utility

## Skills Removed

| Skill | Reason | Where it went |
|-------|--------|---------------|
| reason-with-prolog | Monolithic (7 caps, 3 weaknesses) | Split into translate-to-prolog + query-hypothesis |
| prove-with-lean | No feedback loop, no translation | Replaced by formalize-in-lean (superset) |
| scaffold-pseudocode | Outputs not consumed by pipeline | Absorbed into query-hypothesis |
| multi-plan | Too many concerns in one skill | Orchestration moves to plan-from-proof |

## Pipeline Flow

```
translate-to-prolog → query-hypothesis → formalize-in-lean
                                              ↓         ↑ (feedback if unprovable)
                                              ↓         |
                                     translate-proof-for-llm
                                     translate-proof-for-human
                                              ↓
                                     plan-from-proof → make-commits
```

## Implementation Order (Prolog-derived)

1. **translate-to-prolog** — foundation, no dependencies
2. **query-hypothesis** — depends on translate-to-prolog
3. **formalize-in-lean** — depends on query-hypothesis
4. **translate-proof-for-llm** — depends on formalize-in-lean
5. **translate-proof-for-human** — depends on formalize-in-lean (parallel with 4)
6. **plan-from-proof** — depends on translate-proof-for-llm
7. **make-commits** — independent, can be done anytime

## Key Migration Tasks

1. Move `prolog/` and `scripts/` from `reason-with-prolog/` into `translate-to-prolog/`
2. Move `lean/`, `scripts/`, `.claude/` from `prove-with-lean/` into `formalize-in-lean/`
3. Incorporate scaffold-pseudocode's edge predicate and given/when/then patterns into query-hypothesis
4. Add worktree orchestration and human vetting to plan-from-proof as optional mode
5. Update `package.json` and `README.md`
6. Delete old skills directories
7. Remove `new/` directory
