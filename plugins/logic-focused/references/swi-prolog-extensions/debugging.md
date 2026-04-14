# Debugging Extensions

## Debug Messages

```prolog
:- use_module(library(debug)).

:- debug(my_app).  % Enable debug topic

my_predicate(X) :-
    debug(my_app, "Processing: ~w", [X]),
    process(X).
```

Enable/disable at runtime: `?- debug(my_app).` / `?- nodebug(my_app).`

## Execution Profiling

```prolog
?- profile(my_goal).
% Shows time spent per predicate

?- time(expensive_computation(Result)).
% Shows wall time, inferences, CPU
```

## Clause Inspection

```prolog
?- listing(my_predicate/2).
% Prints the current definition, including asserted clauses
```

---

**See also**: [Modules](modules.md) (debug topics can be scoped per module), [Meta-Predicates](meta-predicates.md) (profile/1 and time/1 are meta-predicates that take a goal argument).
