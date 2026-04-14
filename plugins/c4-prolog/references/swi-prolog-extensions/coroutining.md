# Coroutining

**Problem**: A goal may be called before its arguments are sufficiently bound, causing unwanted nondeterminism or errors. Coroutining lets you delay goals until the information they need is available.

## Core API

| Predicate | Purpose |
|---|---|
| `freeze(Var, Goal)` | Delay `Goal` until `Var` is bound |
| `when(Condition, Goal)` | Delay `Goal` until `Condition` holds |
| `dif(X, Y)` | Constrain `X` and `Y` to be different (sound negation) |
| `frozen(Var, Goal)` | Retrieve the goal frozen on `Var` |

Conditions for `when/2` are built from: `nonvar(X)`, `ground(X)`, `?=(X, Y)`, and combinations with `,` (and) and `;` (or).

## freeze/2

Delays a goal until a variable is bound:
```prolog
?- freeze(X, format("X is ~w~n", [X])), X = hello.
% Output: X is hello

%% Multiple freezes on the same variable queue up
?- freeze(X, write(first)), freeze(X, write(second)), X = go.
% Output: firstsecond

%% Inspect what is frozen on a variable
?- freeze(X, write(hello)), frozen(X, Goal).
% Goal = write(hello).
```

## when/2

Delays until an arbitrary condition holds:
```prolog
?- when((nonvar(X), nonvar(Y)), Z is X + Y), X = 3, Y = 4.
% Z = 7.

%% Wait for either variable to become ground
?- when((ground(X) ; ground(Y)), format("Ready: ~w ~w~n", [X, Y])),
   X = done.
% Output: Ready: done _G123

%% Wait until two variables are known to be equal or different
?- when(?=(X, Y), format("Decided: ~w ~w~n", [X, Y])),
   X = a, Y = a.
% Output: Decided: a a
```

## dif/2

Constrains two terms to be different (sound negation):
```prolog
?- dif(X, Y), X = a, Y = a.
% false.

?- dif(X, Y), X = a, Y = b.
% true.

%% dif/2 survives partial binding — it waits until it can decide
?- dif(f(X, Y), f(a, b)), X = a.
% Succeeds — still possible for Y \= b
% Y is constrained: dif(Y, b)

?- dif(f(X, Y), f(a, b)), X = a, Y = b.
% false.
```

## Practical Example: Demand-Driven Computation (Lazy Lists)

Coroutining enables lazy evaluation by freezing computations until values are actually requested:

```prolog
%% Generate an infinite stream of integers on demand.
%% The tail is only computed when accessed.
lazy_ints(N, [N|Tail]) :-
    freeze(Tail, (N1 is N + 1, lazy_ints(N1, Tail))).

%% Take the first K elements from a lazy list.
take(0, _, []) :- !.
take(K, [H|T], [H|Rest]) :-
    K > 0,
    K1 is K - 1,
    take(K1, T, Rest).

%% Usage:
%% ?- lazy_ints(1, S), take(5, S, First5).
%% First5 = [1, 2, 3, 4, 5].
%% S = [1, 2, 3, 4, 5 | _Frozen].   % rest is still frozen
```

## Practical Example: Constraint Propagation with dif/2

Use `dif/2` for safe inequality constraints in search problems:

```prolog
%% Assign colors to graph nodes so no adjacent nodes share a color.
color_map(Colors) :-
    Colors = [WA, NT, SA, Q, NSW, V, T],
    Palette = [red, green, blue],
    maplist(domain(Palette), Colors),
    %% Adjacent regions must differ
    dif(WA, NT), dif(WA, SA),
    dif(NT, SA), dif(NT, Q),
    dif(SA, Q),  dif(SA, NSW), dif(SA, V),
    dif(Q, NSW),
    dif(NSW, V).

domain(Palette, X) :- member(X, Palette).

%% ?- color_map([WA, NT, SA, Q, NSW, V, T]).
%% WA = red, NT = green, SA = blue, Q = red, NSW = red, V = green, T = red ;
%% ...
```

**When to use**: When you want to set up constraints before values are known — lazy evaluation, demand-driven data structures, constraint networks, or ensuring soundness in negation scenarios.

**Pitfall**: Deeply nested frozen goals can be hard to debug. Use `frozen/2` to inspect what is waiting on a variable.

---

**See also**: [Attributed Variables](attributed-variables.md) (freeze/2 and dif/2 are implemented using attributed variables), [CLP](clp.md) (constraint solvers build on the same delayed-goal infrastructure), [Tabling](tabling.md) (another approach to avoiding redundant computation).
