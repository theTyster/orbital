# Attributed Variables

**Problem**: You need to associate arbitrary metadata with an unbound variable and react when it gets unified.

This is the mechanism underlying CLP(FD), CLP(B), and coroutining. You rarely use it directly unless building your own constraint solver.

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

**When to use**: Building custom constraint solvers or domain-specific propagators.

---

**See also**: [CLP](clp.md) (CLP(FD), CLP(B), CLP(Q/R) are all built on attributed variables), [Coroutining](coroutining.md) (freeze/2 and dif/2 use attributed variables internally).
