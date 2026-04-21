# Attributed Variables

**Problem**: You need to associate arbitrary metadata with an unbound variable and react when it gets unified.

This is the mechanism underlying CLP(FD), CLP(B), and coroutining. You rarely use it directly unless building your own constraint solver.

## Core API

| Predicate | Purpose |
|---|---|
| `put_attr(Var, Module, Value)` | Attach attribute `Value` to `Var` under namespace `Module` |
| `get_attr(Var, Module, Value)` | Retrieve the attribute attached to `Var` under `Module` |
| `del_attr(Var, Module)` | Remove the attribute from `Var` under `Module` |
| `attr_unify_hook(AttrValue, UnifiedValue)` | Callback invoked when an attributed variable is unified |

## Example: Positive Number Constraint

```prolog
:- module(my_constraint, [
    positive/1,
    attr_unify_hook/2
]).

positive(X) :-
    (   var(X)
    ->  put_attr(X, my_constraint, positive)
    ;   X > 0
    ).

attr_unify_hook(positive, Value) :-
    Value > 0.
```

```prolog
?- positive(X), X = 5.   % succeeds
?- positive(X), X = -1.  % fails
```

## Example: Range Constraint with get_attr/3

A more complete example that stores structured metadata and retrieves it:

```prolog
:- module(range_constraint, [
    in_range/3,
    get_range/3,
    attr_unify_hook/2
]).

%% in_range(+Var, +Low, +High)
%  Constrain Var to be between Low and High (inclusive).
in_range(X, Low, High) :-
    (   var(X)
    ->  put_attr(X, range_constraint, range(Low, High))
    ;   X >= Low, X =< High
    ).

%% get_range(+Var, -Low, -High)
%  Retrieve the range constraint on Var, if any.
get_range(X, Low, High) :-
    get_attr(X, range_constraint, range(Low, High)).

attr_unify_hook(range(Low, High), Value) :-
    (   var(Value)
    ->  % Unifying two attributed vars: intersect ranges
        (   get_attr(Value, range_constraint, range(L2, H2))
        ->  NewLow is max(Low, L2),
            NewHigh is min(High, H2),
            NewLow =< NewHigh,
            put_attr(Value, range_constraint, range(NewLow, NewHigh))
        ;   put_attr(Value, range_constraint, range(Low, High))
        )
    ;   % Unifying with a ground value: check range
        Value >= Low, Value =< High
    ).
```

```prolog
?- in_range(X, 1, 10), X = 5.
X = 5.

?- in_range(X, 1, 10), X = 20.
false.

?- in_range(X, 1, 10), get_range(X, Low, High).
Low = 1, High = 10.

?- in_range(X, 1, 10), in_range(X, 5, 15), get_range(X, Low, High).
Low = 5, High = 10.   % intersection of [1,10] and [5,15]
```

**When to use**: Building custom constraint solvers or domain-specific propagators.

---

**See also**: [CLP](clp.md) (CLP(FD), CLP(B), CLP(Q/R) are all built on attributed variables), [Coroutining](coroutining.md) (freeze/2 and dif/2 use attributed variables internally).
