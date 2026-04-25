# `thoughts/lean_proof_results.pl` — schema

Emitted by `prove-invariants`. Consumed by `instantiate-properties`, `realize-specification`, and the `explain` reference as a structured KB — not as prose.

## Per-theorem verdicts

```prolog
% theorem_verdict(TheoremId, proven | unprovable).
theorem_verdict(t_acyclic_deps, proven).
theorem_verdict(t_no_cli_to_logging, proven).
theorem_verdict(t_role_minimality, unprovable).
```

Verdict semantics:

| Verdict | Meaning | Next step |
|---|---|---|
| `proven` | Lean discharged the theorem with no `sorry`. | `instantiate-properties` emits the matching test as **live**. |
| `unprovable` | Lean could not close the proof within the correction budget. | Loop back to `decompose-proposition` with the `failure_mode`. |

## Proof strategy and failure mode

```prolog
% proof_strategy(TheoremId, StrategyString) — one per proven theorem.
proof_strategy(t_acyclic_deps,
               "induction on list, simp with List.append_nil").

% failure_mode(TheoremId, Mode) — one per unprovable theorem.
% Mode ∈ { tactic | type_mismatch | contradiction | timeout
%        | insufficient_negations | extraneous_negation }.
failure_mode(t_role_minimality, tactic).
```

## Provenance annotations (mandatory)

```prolog
% provenance_annotation(TheoremId, FactId, absent | contradicts).
% MANDATORY — one fact per theorem, and one per negated premise on
% counterfactual theorems. Domain is exactly [absent, contradicts];
% value must agree with the negation_provenance/2 tag of the corresponding
% fact in target-world.pl.
provenance_annotation(t_no_cli_to_logging, f_cli_logging, absent).
provenance_annotation(t_no_legacy_deploy, f_deploy_legacy, contradicts).
```

`provenance_annotation/3` is the structured echo of the `provenance(absent | contradicts)` docstring above each theorem in `thoughts/lean/Proofs/*.lean`. Domain is exactly `[absent, contradicts]`. If a theorem has a negated premise but no `provenance_annotation/3` fact, the run is malformed — `cwa_negation_neq_lean_proof` (see `../epistemic-types.md`) makes this distinction load-bearing, and dropping it silently upgrades CWA-absence into logical falsity.

## Source locations

```prolog
% theorem_source(TheoremId, LeanPath).
theorem_source(t_acyclic_deps, "thoughts/lean/Proofs/AcyclicDeps.lean").
```

## Counterfactual necessity lemmas

```prolog
% necessity_lemma_status(TheoremId, FactId, proven | extraneous | unprovable).
% For counterfactual claims, one fact per negated-premise (fact) the theorem cites.
% - proven       → re-introducing the fact falsifies the property (load-bearing).
% - extraneous   → re-introducing reduces to False (the fact is not load-bearing;
%                  loop back to decompose-proposition to prune the claim).
% - unprovable   → the necessity strategy failed; distinct from extraneous.
necessity_lemma_status(t_no_cli_to_logging, f_cli_logging, proven).
necessity_lemma_status(t_no_cli_to_logging, f_cli_formatter, extraneous).
```

## Aggregate summary

```prolog
run_summary(properties_attempted, 4).
run_summary(proven, 2).
run_summary(unprovable, 1).
```

## Consumer usage

`instantiate-properties` reads `theorem_verdict/2`:
- `proven` → emit a live test asserting the property.
- `unprovable` → emit a skipped pre-failing test with `failure_mode/2` as the skip message.

Any `necessity_lemma_status(_, _, extraneous)` fact triggers a loopback to `decompose-proposition` to prune the over-specified counterfactual.
