# Meta-Predicates

**Problem**: Pure Prolog returns one solution at a time via backtracking. Sometimes you need all solutions collected, or you want to apply a predicate across a list.

## Solution Collection

```prolog
% Collect all solutions
?- findall(X, member(X, [a, b, c]), Xs).
% Xs = [a, b, c].

% Collect with grouping (fails if no solutions)
?- bagof(X, member(X, [a, b, a]), Xs).
% Xs = [a, b, a].

% Collect sorted unique solutions
?- setof(X, member(X, [c, a, b, a]), Xs).
% Xs = [a, b, c].
```

## Higher-Order (library(apply))

```prolog
:- use_module(library(apply)).

?- maplist(succ, [1, 2, 3], Ys).
% Ys = [2, 3, 4].

?- include(>(3), [1, 2, 3, 4, 5], Ys).
% Ys = [1, 2].

?- foldl([X, Acc0, Acc1]>>(Acc1 is Acc0 + X), [1,2,3], 0, Sum).
% Sum = 6.
```

## Aggregation (library(aggregate))

```prolog
:- use_module(library(aggregate)).

age(alice, 30).
age(bob, 25).
age(carol, 35).

?- aggregate_all(max(Age), age(_, Age), Max).
% Max = 35.

?- aggregate_all(count, age(_, _), Count).
% Count = 3.
```

## meta_predicate/1 Declarations

When writing higher-order predicates in modules, declare argument modes so the module system can correctly qualify goals:

```prolog
:- module(my_utils, [map_transform/3]).

:- meta_predicate map_transform(2, +, -).

map_transform(Goal, List, Results) :-
    maplist(Goal, List, Results).
```

The argument specifiers: `0`-`9` = goal with N extra arguments, `+` = input, `-` = output, `?` = any. This ensures that when `map_transform` is called from another module, the goal argument is qualified to the caller's module.

**When to use**: Whenever you need to process multiple solutions — reporting, aggregation, transformation pipelines. Use `meta_predicate/1` declarations whenever you write a module-exported predicate that takes goal arguments.

---

**See also**: [Modules](modules.md) (meta_predicate declarations interact with the module system), [Tabling](tabling.md) (tabled predicates are often used with solution-collection meta-predicates).
