# Coroutining

**Problem**: A goal may be called before its arguments are sufficiently bound, causing unwanted nondeterminism or errors.

## freeze/2

Delays a goal until a variable is bound:
```prolog
?- freeze(X, format("X is ~w~n", [X])), X = hello.
% Output: X is hello
```

## when/2

Delays until an arbitrary condition holds:
```prolog
?- when((nonvar(X), nonvar(Y)), Z is X + Y), X = 3, Y = 4.
% Z = 7.
```

## dif/2

Constrains two terms to be different (sound negation):
```prolog
?- dif(X, Y), X = a, Y = a.
% false.

?- dif(X, Y), X = a, Y = b.
% true.
```

**When to use**: When you want to set up constraints before values are known — e.g., building constraint networks, or ensuring soundness in negation scenarios.

---

**See also**: [Attributed Variables](attributed-variables.md) (freeze/2 and dif/2 are implemented using attributed variables), [CLP](clp.md) (constraint solvers build on the same delayed-goal infrastructure).
