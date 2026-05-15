# Agents

Domain expert agent definitions for the orbital-shifting plugin. Skills spawn these as sub-agents by reading the agent file and using its contents as the agent prompt.

## Usage from Skills

```bash
# Path from any skill's SKILL.md
AGENTS="${CLAUDE_SKILL_DIR}/../../agents"
```

Skills reference an agent by reading its `.md` file and incorporating the instructions into an `Agent()` call. The agent file contains the full briefing — the spawned sub-agent gets the domain expertise without the skill needing to inline it.

## Agents

> Every `.md` file in this directory (besides this README) must have a corresponding entry below, including the `**Used by**` mapping. New agents added without a README entry are considered undocumented and should be flagged in review.

### lean-expert

Lean 4 formal proof specialist. Uses `lake build` as deductive reasoning steps rather than chain-of-thought. Incorporates adversarial verification patterns: interpretation checking, extracted-lemma counterexample search, and calibrated abstention.

**Used by**: prove-invariants

### agent-of-truth

Prolog KB construction specialist. Identifies facts, relationships, and constraints in any domain. Expert in domain-fitting predicate design, graph/ontology modeling, DCGs for structured parsing, and constraint validation rules. Reads `references/prolog-wiki/` directly when an extension recipe is needed.

**Used by**: close-world, decompose-proposition, measure-entailment

### agent-of-questions

Prolog query specialist. Discovers KB structure through `swipl` introspection alone — never reads `.pl` files directly. Uses the introspect module to understand any KB, then writes precise queries. Reads `references/prolog-wiki/` directly when a query needs an advanced extension.

**Used by**: decompose-proposition, model-obligations, measure-entailment

### kb-validator

Validation cascade specialist. Given a `.pl` path and a digest output path, runs the five-tier cascade — strict load → referential integrity → constraint firing → spot-check sample → uncovered-predicate report — with halt-on-tier-fail discipline, then writes a JSON digest to the caller's chosen path. Reports tier failures with enough specificity for the caller to fix the file, but never edits the `.pl` artifact and never opines on coverage thresholds. No `Agent` tool (leaf, not delegator). Haiku/low-effort budget.

**Used by**: close-world, agent-of-truth

### pl-fact-extractor

Read-only Prolog projection specialist. Given a list of `.pl` paths and a list of `{predicate, arity}` entries, runs one focused `swipl` projection per entry and returns a JSON digest of fact tuples and counts. No discovery, no synthesis, no validation — projection only. Missing predicates are reported with `missing: true` rather than inferred. No `Write` tool (digest returned, not stored), no `Agent` tool (leaf, not delegator). Haiku/low-effort budget.

**Used by**: instantiate-properties, prove-invariants, model-obligations, measure-entailment

### prolog-prover

Prolog formal proof specialist. Combines KB construction (agent-of-truth), query expertise (agent-of-questions), and CLP libraries to write exhaustive verification proofs. Every proof is a counterexample search. Reads `references/prolog-wiki/` directly for CLP and tabling recipes.

**Used by**: model-obligations

### prolog-adversary

Prolog refutation specialist — the adversarial mirror of `prolog-prover`. Encodes the negation of a pinned claim as a CLP-driven counterexample search and writes a refutation file at `thoughts/refutations/<target_id>.pl` on `refuted`, otherwise reports `inconclusive` or `abstained` with the obstruction named. Shares input/output/discipline contract with `lean-adversary` at `references/adversary-contract.md`. Reads `references/prolog-wiki/` directly for CLP extensions. No `Agent` tool — adversaries are leaves, not delegators.

**Used by**: disprove-proposition

### proposition-sharpener

Falsifiability discipline specialist. Given a raw user proposition and an `existing-world.pl` path, introspects the KB's predicate vocabulary via `swipl` and returns one of two shapes: a one-sentence falsifiable, scoped, contestable restatement (with the KB predicates it references), or `{outcome: "abstained", reason, what_user_should_clarify}`. Halt-on-ambiguity discipline: never invents predicates the KB does not enumerate, never emits multi-clause sharpenings, never hedges past one declarative sentence to disguise uncertainty. No `Write` tool (result returned, not stored), no `Agent` tool (leaf, not delegator). Sonnet/medium-effort budget.

**Used by**: decompose-proposition, disprove-proposition

### lean-adversary

Lean refutation specialist — the adversarial mirror of `lean-expert`. Constructs a Lean term inhabiting the negation of a pinned theorem and writes a refutation file at `thoughts/refutations/<target_id>.lean` on `refuted`, otherwise reports `inconclusive` or `abstained`. Inadmissible for purely behavioral/runtime targets. Shares input/output/discipline contract with `prolog-adversary` at `references/adversary-contract.md`. Reads `references/lean4-wiki/` directly for negation-lemma pages and `references/lean-tactics.md` for forbidden-tactics carve-outs. No `Agent` tool.

**Used by**: disprove-proposition

### realize-counterfactual-scanner

Counterfactual locator and re-introduction watchdog. Queries `hypothesis.pl` for every claim with `claim_label(_, counterfactual)` and locates the file:line sources in the target codebase where each forbidden fact currently materialises (an import, a call site, a config entry). Two-mode operation: `initial` (Stage 0, builds the locator table the orchestrator hands to removal briefings) and `recheck` (Stage 3d, re-greps after a refactor to detect silently re-introduced counterfactuals under new names). Read-only against source; writes only into the realize-specification scratch directory.

**Used by**: realize-specification

### realize-suite-runner

Test-suite runner. Runs the project's full test command, compares the result to a persisted baseline, and returns a small structured digest — `targeted: pass|fail`, regression list, new-pass list, a short failure excerpt — instead of the verbatim multi-megabyte test log. Two-mode operation: `baseline` (Stage 1, records the green/red sets before any unskip) and `verify` (Stages 2c, 2e, 3c, 3d — runs after a change and reports the delta). Verbatim logs are written to scratch for forensic reads, but only the digest is returned.

**Used by**: realize-specification

### realize-test-briefer

Per-test briefing builder. Reads one skipped test plus the Prolog artifacts it cites (`lean_proof_results.pl`, `hypothesis.pl`, optionally `model_results.pl`, `existing-world.pl`, `target-world.pl`) and emits a self-contained briefing file ready for an implementation sub-agent. Routes the briefing to one of three shapes — addition, removal, behavioral — based on `test_category` and the cited claim's `claim_label`. Read-only against the codebase; writes only into the realize-specification scratch directory.

**Used by**: realize-specification

### verdict-extractor

Fixed-query verdict-row extractor. Given `adherence_facts.pl` (plus optionally `hypothesis.pl` and `existing-world.pl`) and an `impl_resource_id`, loads the adherence module with `use_module(..., except([claim/2, claim/3]))`, runs the five FIXED label-aware queries (counterfactual violations, counterfactual honored, prescriptive unfulfilled, prescriptive negation violations, descriptive drift), and returns a JSON digest with every row present — `count: 0, entries: []` when empty, `skipped: true, reason: ...` when an optional input was missing. No category invention (a new verdict is a `measure-entailment` ticket, not a runtime concern), no interpretation, no writes to the source KBs. No `Agent` tool (leaf, not delegator). Haiku/low-effort budget.

**Used by**: measure-entailment

## Plugin References

The two wikis under `plugins/shifting/references/` (`prolog-wiki/` and `lean4-wiki/`) are accessed **only by the agents above** — skills brief the agent with the absolute wiki path but never read the wiki content themselves. This keeps heavy reference material inside sub-agent contexts. When a wiki is thin on a topic, the domain agents fall back to `WebSearch` / `WebFetch` against the official Mathlib 4 or SWI-Prolog docs.
