# `thoughts/model_results.pl` — schema

Emitted by `model-obligations`. Consumed by `instantiate-properties`.

Per-property verdicts from target-world model construction, plus counterfactual minimality status and aggregate summary counts. Downstream skills query this file with `swipl` rather than parsing prose.

## Verdicts

```prolog
% verdict(PropertyId, consistent | inconsistent | gap).
verdict(p_acyclic_deps, consistent).
verdict(p_no_cli_to_logging, consistent).
verdict(p_unique_owner, inconsistent).
verdict(p_role_minimality, gap).
```

Verdict semantics:

| Verdict | Meaning | Next step |
|---|---|---|
| `consistent` | Property holds in target-world. Structural consistency only — not a universal proof. | Hand off to `prove-invariants`. |
| `inconsistent` | Target-world contains a counterexample. | Loop back to `decompose-proposition` with the counterexample. |
| `gap` | Target-world lacks facts to decide the property. | Loop back to `decompose-proposition` to add a prescriptive obligation or enrich existing-world. |

A `consistent` verdict is structural consistency in target-world only; it is *not* a universal proof (`lean_universal_neq_test_verified`). CWA-absent counterfactuals do not constitute a Lean disproof (`cwa_negation_neq_lean_proof`). See `../epistemic-types.md`.

## Evidence for inconsistent and gap verdicts

```prolog
% counterexample(PropertyId, Witness) — present iff verdict is inconsistent.
counterexample(p_unique_owner, [user_42, user_99]).

% gap_reason(PropertyId, ReasonString) — present iff verdict is gap.
gap_reason(p_role_minimality,
           "no role/2 facts in target-world; prescriptive obligation missing").
```

## Counterfactual minimality

```prolog
% cf_status(Fact, load_bearing | extraneous).
% Any extraneous counterfactual flags the hypothesis's claim list as
% over-specified and triggers a loop back to decompose-proposition.
cf_status(depends_on(cli_tool, logging), load_bearing).
cf_status(depends_on(formatter, logging), extraneous).
```

## Summary counts

```prolog
summary(verdicts_total, 4).
summary(consistent, 2).
summary(inconsistent, 1).
summary(gap, 1).
summary(extraneous_counterfactuals, 1).
```

## Consumer usage

`instantiate-properties` reads `verdict/2` to decide which properties become live tests and which become skipped pre-failing tests pending a successful Lean proof in `lean_proof_results.pl`.
