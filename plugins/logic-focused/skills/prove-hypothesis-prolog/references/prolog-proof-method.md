---
name: prolog-proof-method
description: Prolog proof patterns, encoding strategies, and anti-patterns for prove-hypothesis-prolog.
---

# Prolog Proof Methodology

Full reference for encoding formal properties as Prolog rules and running verified queries.

## Core Principle: Falsification Over Confirmation

A Prolog "proof" of a property is not just finding one case where it holds — it's
demonstrating that no counterexample exists. Always structure verification as:

1. Define what a violation looks like
2. Search exhaustively for violations
3. Verify the result is empty

```prolog
% Pattern: prove by exhaustive violation search
:- findall(X, violates_property(X), Violations),
   (Violations == []
    -> format("[VERIFIED] property_name~n")
    ;  format("[FALSIFIED] counterexamples: ~w~n", [Violations])).
```

This is stronger than showing positive examples.

## Universal Property Patterns

### "All X must satisfy P"

```prolog
% Explicit findall of violations (recommended — gives counterexamples)
all_satisfy_p :-
    findall(X, (domain_entity(X), \+ p(X)), Violations),
    Violations == [].

% forall/2 (cleaner but no evidence on failure)
all_satisfy_p :-
    forall(domain_entity(X), p(X)).
```

Prefer the `findall` pattern when you need to report counterexamples on failure.

### "No X satisfies P"

```prolog
% Negation-as-failure (compact)
none_satisfy_p :- \+ p(_).

% findall variant (gives evidence)
none_satisfy_p :-
    findall(X, p(X), Found),
    Found == [].
```

### "All X in A also appear in B"

```prolog
a_subset_of_b :-
    findall(X, (member_of_a(X), \+ member_of_b(X)), Missing),
    Missing == [].
```

### "Exactly N instances"

```prolog
exactly_n(Predicate, N) :-
    Goal =.. [Predicate, _],
    findall(_, Goal, Bag),
    length(Bag, N).
```

## Graph / Relational Property Patterns

### Transitive closure

```prolog
% Define once per property to avoid name collisions
prop_reaches(A, B) :- edge(A, B).
prop_reaches(A, B) :- edge(A, Mid), prop_reaches(Mid, B).
```

Use a unique prefix (`prop_` or the property name) to avoid conflicts if multiple
properties define their own transitive closure.

### Reachability

```prolog
% "A can reach B"
:- (prop_reaches(a, b)
    -> format("[VERIFIED] a reaches b~n")
    ;  format("[FALSIFIED] a cannot reach b~n")).

% "A cannot reach B"
:- (\+ prop_reaches(a, b)
    -> format("[VERIFIED] a cannot reach b~n")
    ;  findall(Path, prop_path(a, b, Path), Paths),
       format("[FALSIFIED] a reaches b via ~w~n", [Paths])).
```

### Acyclicity

```prolog
acyclic_graph :-
    \+ prop_reaches(X, X).

% With evidence on failure
acyclic_or_report :-
    findall(X, prop_reaches(X, X), Cycles),
    (Cycles == []
     -> format("[VERIFIED] graph is acyclic~n")
     ;  format("[FALSIFIED] cycles at nodes: ~w~n", [Cycles])).
```

### Connectivity (every node reaches a sink)

```prolog
all_reach_sink :-
    findall(X, (node(X), \+ is_sink(X), \+ prop_reaches(X, Sink), is_sink(Sink)), Disconnected),
    (Disconnected == []
     -> format("[VERIFIED] all nodes reach a sink~n")
     ;  format("[FALSIFIED] disconnected: ~w~n", [Disconnected])).
```

## Counting and Cardinality Patterns

```prolog
% At least N
at_least(Goal, N) :-
    findall(_, Goal, Bag),
    length(Bag, L),
    L >= N.

% At most N
at_most(Goal, N) :-
    findall(_, Goal, Bag),
    length(Bag, L),
    L =< N.

% Unique values (no duplicates)
all_unique(Goal, Key) :-
    findall(K, (call(Goal, K)), Keys),
    sort(Keys, Sorted),
    length(Keys, L), length(Sorted, L).
```

## Negative Properties (Things That Must NOT Exist)

```prolog
% Pattern: mutual exclusion
mutually_exclusive(A, B) :-
    \+ (member_of(X, A), member_of(X, B)).

% Pattern: no orphans (every X has a parent)
no_orphans :-
    findall(X, (entity(X), \+ parent(_, X)), Orphans),
    Orphans == [].

% Pattern: no cycles in imports
no_import_cycles :-
    findall(M, (imports(M, _), import_reaches(M, M)), Cycles),
    Cycles == [].
```

## Structured Evidence Output

When FALSIFIED, produce structured evidence rather than just printing the first failure:

```prolog
% Good — full evidence
:- findall(X-Y, violating_pair(X, Y), Pairs),
   (Pairs == []
    -> format("[VERIFIED] property_name~n")
    ;  forall(member(X-Y, Pairs),
              format("  COUNTEREXAMPLE: ~w → ~w~n", [X, Y])),
       format("[FALSIFIED] ~w violations found~n", [Pairs])).

% Avoid — stops at first failure, no evidence
:- (\+ violating_pair(_, _) -> format("VERIFIED~n") ; format("FALSIFIED~n")).
```

## Helper Rule Organization

Structure `thoughts/prolog_proofs.pl` in sections:

```prolog
% ============================================================
% PREAMBLE — load the facts file
% ============================================================
:- [path/to/facts].

% ============================================================
% SHARED HELPERS — predicates used by multiple properties
% ============================================================
% (define transitive closures, common groupings, etc.)

% ============================================================
% Property: property_one_name
% Description: ...
% ============================================================
% (helpers scoped to this property)
% (property encoding)
% (verification directive)

% ============================================================
% Property: property_two_name
% ...
```

Always list properties in the order they appear in `thoughts/hypothesis.md`.

## Debugging Encodings

When a query returns unexpected results, debug incrementally:

```bash
# Step 1: Does the base predicate return what you expect?
swipl -g "depends_on(X, Y), format('~w->~w~n',[X,Y]), fail ; true" -t halt facts.pl

# Step 2: Does the helper rule work?
swipl -g "reaches(auth_lib, X), format('~w~n',[X]), fail ; true" \
  -t halt -l facts.pl thoughts/prolog_proofs.pl

# Step 3: Is the violation predicate matching what you intend?
swipl -g "findall(X, violates_prop(X), Vs), format('violations: ~w~n',[Vs])" \
  -t halt -l facts.pl thoughts/prolog_proofs.pl
```

## Common Encoding Mistakes

**Mistake: Using `assert` to define helper rules inside a directive**
```prolog
% Wrong — asserted rules go to a different context
:- assert((reaches(A,B) :- edge(A,B))).

% Right — define as top-level clauses
reaches(A, B) :- edge(A, B).
```

**Mistake: Forgetting namespace isolation**
```prolog
% Wrong — generic name clobbers another property's helper
path(A, B) :- depends_on(A, B).      % property 1
path(A, B) :- calls(A, B).           % property 2 — overwrites!

% Right — prefix by property
dep_path(A, B) :- depends_on(A, B).
call_path(A, B) :- calls(A, B).
```

**Mistake: `\+` with unbound variables**
```prolog
% Wrong — \+(member(X, [])) will fail because X is unbound
:- \+ (entity(X), \+ has_owner(X)).

% Right — collect first, then check emptiness
:- findall(X, (entity(X), \+ has_owner(X)), Xs), Xs == [].
```

**Mistake: Confirming positive case only**
```prolog
% Weak — this just shows the property is *possible*, not universal
:- has_property(some_entity), format("VERIFIED~n").

% Strong — prove NO counterexample exists
:- findall(X, (entity(X), \+ has_property(X)), Missing),
   (Missing == [] -> format("VERIFIED~n") ; format("FALSIFIED: ~w~n", [Missing])).
```

## Running the Proofs File

The proofs file is designed to be self-contained and re-runnable:

```bash
# Run all verifications
swipl -g halt -l <facts_file> thoughts/prolog_proofs.pl

# Run just one property (load file, then query interactively)
swipl -l <facts_file> thoughts/prolog_proofs.pl

# Re-run after KB update to check regressions
swipl -g halt -l updated_facts.pl thoughts/prolog_proofs.pl
```

If the facts file path is hardcoded in the preamble `:- [path]`, remove it and always
pass it on the command line — this keeps the proofs file portable.
