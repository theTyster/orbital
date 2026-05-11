# `thoughts/hypothesis.pl` — schema

Emitted by `decompose-proposition`. Consumed by `model-obligations` (and indirectly, via `target-world.pl`, by `prove-invariants`).

## Header

```prolog
:- discontiguous claim/2, claim_label/2, claim_status/2,
                 claim_premise/2, claim_negation_provenance/3,
                 evidence/3, formal_property/3,
                 sub_hypothesis/2, coverage/2, assumption/2.

proposition("{one-sentence natural-language proposition}").
existing_world_file('thoughts/existing-world.pl').
counterfactual_question("{the guiding question}").
```

## Claims and their tags

```prolog
% claim(ClaimId, "natural-language statement").
% claim_label(ClaimId, descriptive | counterfactual | prescriptive).
% claim_status(ClaimId, clear | conditional | open).
claim(c_001, "cli_tool must not transitively depend on logging").
claim_label(c_001, counterfactual).
claim_status(c_001, conditional).
```

`claim_label/2` is the *ontology label* dimension — exactly one of `descriptive`, `counterfactual`, `prescriptive`. Every claim must have one. See `../ontology.md` for semantics.

## Negated premises — 3-argument form

```prolog
% claim_premise(ClaimId, Fact) — the specific ground fact the claim negates
%                                or asserts. Required for every counterfactual
%                                claim and for every prescriptive claim that
%                                asserts a new fact.
% claim_negation_provenance(ClaimId, Fact, absent | contradicts)
%   — required for every negated premise (every counterfactual claim, plus any
%     prescriptive claim whose body contains ¬…). Domain is exactly two values.
claim_premise(c_001, depends_on(cli_tool, logging)).
claim_negation_provenance(c_001, depends_on(cli_tool, logging), absent).
```

**The 3-argument form is mandatory.** A 2-argument `negation_provenance/2` does not carry the fact and cannot be consumed by `model-obligations`. The fact is required because target-world construction needs to know *which fact* to remove or contradict, not just *which claim* carries a negation.

`target-world.pl` uses the distinct predicate `negation_provenance/2` for the per-fact form — see `target-world.md`. `model-obligations` performs the 3-arg → 2-arg translation at the boundary.

## Formal properties

```prolog
% formal_property(PropertyId, "natural-language description", "lean-sketch").
formal_property(p_001,
    "cli_tool has no transitive path to logging in the target relation",
    "theorem cli_tool_not_reaches_logging : ¬ Reach depends_on_target Module.cli_tool Module.logging := by sorry").
```

The predicate is `formal_property/3` — **not** `property/2`. The three arguments are always `(Id, NLDescription, LeanSketch)` in that order. Downstream skills match on the arity. `model-obligations` propagates each `formal_property/3` fact verbatim into `target-world.pl`.

## Evidence, sub-hypotheses, assumptions, coverage

```prolog
% evidence(ClaimId, QueryText, ResultSummary).
evidence(c_001,
    "findall(P, depends_on_trans(cli_tool, logging, P), Ps)",
    "found paths: [[cli_tool,formatter,logging], [cli_tool,logging]]").

% sub_hypothesis(Id, "natural-language statement").
sub_hypothesis(sh_001, "no transitive dependency from cli_tool to logging").

% assumption(Id, "what would resolve this").
assumption(a_001, "need structural facts about public-interface definitions").

% coverage(Key, Value).
coverage(total_clauses, 412).
coverage(clauses_exercised, 287).
coverage(percentage, 69).
coverage(assessment, medium).
coverage(unexercised_predicates, [role/2, owner/1]).
```

## Validation

```bash
swipl -g halt thoughts/hypothesis.pl
```

Every `claim/2` must have a matching `claim_label/2` and `claim_status/2`. Every counterfactual claim must have at least one `claim_premise/2` and exactly one `claim_negation_provenance/3` per premise.

## Required shape for pure-invariant mode

If the hypothesis has no counterfactual or prescriptive claims (pure invariant mode), emit `claim_label(_, descriptive)` for every claim and omit both `claim_premise/2` and `claim_negation_provenance/3`.
