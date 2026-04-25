# `thoughts/target-world.pl` — schema

Emitted by `model-obligations`. Consumed by `prove-invariants`.

`target-world.pl` is `existing-world.pl` with counterfactual facts removed and prescriptive obligations asserted. **In addition**, it propagates `formal_property/3` facts from `hypothesis.pl` so `prove-invariants` has schema-level access to the property list without reaching back to `hypothesis.pl`.

## Ground facts with per-fact provenance

```prolog
% provenance(Fact, descriptive | prescriptive).
depends_on(auth_lib, db).
provenance(depends_on(auth_lib, db), descriptive).

depends_on(auth_lib, audit_log).
provenance(depends_on(auth_lib, audit_log), prescriptive).
```

Every carried-over or newly asserted fact is tagged with a per-fact `provenance/2` fact so the diff between existing-world and target-world is auditable from the file alone.

## Per-fact negation provenance — 2-argument form

```prolog
% negation_provenance(Fact, absent | contradicts).
% — per-fact, 2-argument form. Distinct from hypothesis.pl's
%   claim_negation_provenance/3 which is per-claim and 3-argument.
negation_provenance(depends_on(cli_tool, logging), absent).
negation_provenance(legacy(deploy), contradicts).
```

**Arity differs by artifact.** In `hypothesis.pl` the per-claim record is `claim_negation_provenance/3`; in `target-world.pl` the per-fact record is `negation_provenance/2`. `model-obligations` performs the translation: for each `claim_negation_provenance(ClaimId, Fact, Mode)` in hypothesis, emit `negation_provenance(Fact, Mode)` in target-world.

The counterfactually-removed fact itself is *omitted* from target-world (CWA-absent); only the `negation_provenance/2` marker survives. `prove-invariants` reads the marker to decide how to lift the negation into Lean — see `../epistemic-types.md` for why `absent` and `contradicts` carry different logical strength.

## Counterfactual scaffolding

```prolog
% cf_fact/N — counterfactual-removed facts, keyed on the original relation
%             and arity. Used by target-relation filter helpers below.
cf_fact(cli_tool, logging).

% Target-relation helpers scoped to each base relation.
depends_on_target(X, Y) :-
    depends_on(X, Y),
    \+ cf_fact(X, Y).
```

## Formal properties (propagated from hypothesis.pl)

```prolog
% formal_property/3 — propagated verbatim from hypothesis.pl.
% This is prove-invariants's schema-level access to the property list.
formal_property(p_001,
    "cli_tool has no transitive path to logging in the target relation",
    "theorem cli_tool_not_reaches_logging : ¬ Reach depends_on_target Module.cli_tool Module.logging := by sorry").
```

`model-obligations` MUST copy every `formal_property/3` from `hypothesis.pl` into `target-world.pl` verbatim. Without this propagation, `prove-invariants` has no schema-level handle on the property list and is forced to parse prose or reach back through the pipeline — both are contract violations. Do **not** rename to `property/2`; do **not** strip the Lean sketch.

## Verdict directives (emitted inline at load time)

```prolog
% verdict(PropertyId, consistent | inconsistent | gap).
% counterexample(PropertyId, Witness) — present iff verdict is inconsistent.
% gap_reason(PropertyId, ReasonString) — present iff verdict is gap.
% cf_status(Fact, load_bearing | extraneous) — counterfactual minimality.
```

These are asserted dynamically by `:- ...` directives that run at load time. They are then dumped into `model_results.pl` for downstream consumption — see `model-results.md`.
