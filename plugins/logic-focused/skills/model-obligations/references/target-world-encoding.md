# Constructing target-world — counterfactual + prescriptive encoding

The mechanics from the old conditional-mode encoding remain, but reframed as "how target-world is built" rather than "two proof modes." Counterfactuals are applied via a target-relation filter; prescriptive obligations are asserted directly; per-property verdicts are derived by querying the target relation.

```prolog
% From hypothesis.pl — counterfactual claims:
%   :- claim_label(h_07, counterfactual).
%   :- claim_premise(h_07, depends_on(cli_tool, logging)).
%   :- claim_negation_provenance(h_07, depends_on(cli_tool, logging), absent).
cf_fact(cli_tool, logging).
cf_fact(cli_tool, formatter).
cf_fact(formatter, logging).

% Target relation: existing-world's depends_on minus counterfactuals.
depends_on_target(X, Y) :-
    depends_on(X, Y),
    \+ cf_fact(X, Y).

% Prescriptive obligations from hypothesis.pl (claim_label/2 = prescriptive)
% are asserted directly into target-world as new depends_on/2 facts with
% provenance(_, prescriptive) tags — they extend the target relation.

% Property verdict: does the property hold in the target relation?
dep_t_reaches(A, B) :- depends_on_target(A, B).
dep_t_reaches(A, B) :- depends_on_target(A, Mid), dep_t_reaches(Mid, B).

:- (\+ dep_t_reaches(cli_tool, logging)
    -> assertz(verdict(p_no_cli_to_logging, consistent))
    ;  findall(P, dep_t_reaches(cli_tool, logging), Ps),
       assertz(verdict(p_no_cli_to_logging, inconsistent)),
       assertz(counterexample(p_no_cli_to_logging, Ps))).

% Counterfactual minimality check — for each cf_fact F, re-introducing F to
% the target relation must re-violate at least one property. If not, F is
% extraneous and the hypothesis's counterfactual list is over-specified.
depends_on_target_plus_cli_logging(X, Y) :- depends_on_target(X, Y).
depends_on_target_plus_cli_logging(cli_tool, logging).
dep_tpl_reaches(A, B) :- depends_on_target_plus_cli_logging(A, B).
dep_tpl_reaches(A, B) :- depends_on_target_plus_cli_logging(A, Mid),
                         dep_tpl_reaches(Mid, B).

:- (dep_tpl_reaches(cli_tool, logging)
    -> assertz(cf_status(depends_on(cli_tool, logging), load_bearing))
    ;  assertz(cf_status(depends_on(cli_tool, logging), extraneous))).
```

A property verdict is `consistent` only when (a) the target-relation check succeeds and (b) every counterfactual feeding into that property is `load_bearing`. Any `extraneous` counterfactual gets recorded for a loop back to `decompose-proposition` to prune the claim list.
