# Adversary Contract

Shared contract for the two refutation specialists in this plugin: `prolog-adversary` and `lean-adversary`. Both agents are invoked exclusively by the `disprove-proposition` skill. They share the input/output/discipline shape documented here; they differ only in the formalism (Prolog CLP search vs Lean witness construction). Each agent file references this document rather than restating its content.

## Inputs

Every adversary invocation supplies the following fields. The caller (`disprove-proposition`) is responsible for pinning these values; the agent does not infer them.

| Field | Type | Meaning |
|---|---|---|
| `target_id` | atom / string | Identifier the verdict is recorded against: a Prolog `claim_id` (`c_007`), a Lean theorem name (`theorem_sorted_output`), or a test name. |
| `target_text` | string | The pinned proposition in its strongest defendable form. Set by the orchestrator before delegation — see `disprove-proposition` Process step 1. |
| `provenance` | path | Absolute path to the file where the claim lives (`thoughts/hypothesis.pl`, `thoughts/lean_proof_results.pl`, a test file). The agent reads provenance for context but never modifies it. |
| `refutation_shape` | string | The shape of a successful witness: e.g. *"a single x with ¬P(x)"*, *"an input/state where the antecedent holds but the consequent fails"*. Named before search begins. |
| `budget` | string | Token / wall-clock / attempt cap. Forms the same `disprove_budget/2` entry the skill emits. Exhausting the budget without a witness is `abstained`, not `inconclusive`. |
| `output_dir` | path | Defaults to `thoughts/refutations/`. The directory where the agent writes its refutation artifact on `refuted`. |

## Outputs

The agent returns a structured digest to the caller and, on `refuted`, writes a refutation artifact file. The digest fields are stable across both adversaries:

```
verdict          ∈ {refuted, inconclusive, abstained}
artifact_path    path under output_dir on refuted; otherwise the atom no_artifact
witness_summary  one-sentence description of the witness or partial evidence
budget_spent     what the search actually consumed (techniques tried, depth, time)
obstruction      for abstained: the named obstacle preventing progress (e.g.
                 "claim is open-domain — exhaustive search infeasible within budget")
defenses_applied list of bias-isolation defenses the caller declared
                 (role_brief, minimum_context, ...) — copied verbatim from the
                 briefing so disprove-proposition can record them in
                 disprove_budget/2.
```

The agent never prints raw stdout to the caller. The digest is the entire return surface; the artifact file is the entire side-effect surface.

### Refutation artifact files

The artifact file shape is formalism-specific (see each agent body), but the naming and placement convention is shared:

- Prolog refutations: `${output_dir}/${target_id}.pl`
- Lean refutations: `${output_dir}/${target_id}.lean`
- Cross-formalism: when the same `target_id` is refuted in both Prolog and Lean (rare — same English proposition disproved twice through two formalisms), discriminate by suffix: `${target_id}__prolog.pl` and `${target_id}__lean.lean`.

Refutation files are deposited under `thoughts/refutations/` by default. The `disprove-proposition` skill then records the artifact path in `thoughts/disproof_results.pl` via `disprove_attempt/3`. The skill — not the agent — is responsible for updating `counterexamples.pl`.

## Discipline (non-negotiable)

These three rules mirror `disprove-proposition/SKILL.md` §"The frame" lines 22–27 and apply identically to both adversaries.

1. **Abstention is first-class.** *"I could not refute this within budget"* is a valid, useful outcome. Fabricating a witness to satisfy the call is a debate foul, symmetric to fabricating a proof.
2. **Witnesses must be concrete.** A `refuted` verdict requires a specific value, configuration, or trace that demonstrates the claim's failure. A sketch, a near-miss, or a "this probably refutes it" hand-wave is `inconclusive`, not `refuted`.
3. **Solutions stay open-ended.** Declaring a claim *"unrefutable"* is forbidden. The agent's reach is bounded by its budget and its formalism; it does not opine on the claim's truth in the abstract.

Two further rules are specific to the adversary role:

4. **Do not weaken the claim before refuting it.** A refutation of a strawman is not a refutation. If the pinned `target_text` reads as the strongest defendable form, attack it directly. If the agent finds the pinned form actually trivially refutable (e.g. an obvious vacuous case), it returns `refuted` with the witness *and* annotates the digest as `witness_summary: "trivial refutation — pinning likely too weak; recommend orchestrator re-pin"`.
5. **The pinned form is the contract.** The agent does not negotiate the claim with the caller mid-search; it does not request the claim be reformulated. If the pinned form is genuinely incoherent (e.g. an undefined predicate), the agent returns `abstained` with `obstruction: "claim references undefined symbol X — orchestrator must re-pin"`.

## Calibrated Abstention

If a search exhausts its correction budget without producing a witness:

- **Say so.** Report what approaches were tried, what the final search state is, and whether the claim appears genuinely true or merely hard within the budget given.
- **Don't guess.** A wrong claim of refutation is worse than honest abstention.
- **Preserve partial results.** Partial evidence (a near-miss, a fragile region, a related-but-not-pinned refutation) is `inconclusive`, not `abstained`. Reserve `abstained` for *"the search produced no information about this claim"* — typically because the formalism cannot express the claim shape, the search space is unboundedly large, or the relevant data is absent from the KB / Lean project.

The orchestrator validates witnesses against the pinned form before recording `refuted` in `disproof_results.pl`. The agent's self-reported verdict is candidate evidence, not output.

## What this contract is NOT

- Not a pipeline contract. Both adversaries sit under `disprove-proposition`, which is `unstaged_skill/1` per the orchestration substrate. The pipeline does not invoke either adversary directly.
- Not an exhaustive-search guarantee. A `abstained` verdict means the agent's budget was insufficient or the formalism was inapplicable, not that the claim is true.
- Not a delegation hub. Neither adversary spawns further sub-agents (no `Agent` tool in either agent's allow-list). Composition happens upstream at the `disprove-proposition` skill level.
