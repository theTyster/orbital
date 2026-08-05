# Tabling (Memoization)

**Problem**: Recursive predicates can loop infinitely or recompute the same subgoals exponentially many times. Classic example: naive Fibonacci.

**How to enable**: Add a `:- table` directive for the predicate. The `table/1` directive accepts a predicate indicator or a list of them.

```prolog
:- table fib/2.

fib(0, 0).
fib(1, 1).
fib(N, F) :-
    N > 1,
    N1 is N - 1,
    N2 is N - 2,
    fib(N1, F1),
    fib(N2, F2),
    F is F1 + F2.
```

Without tabling, `fib(50, F)` does not terminate in reasonable time. With tabling, it returns instantly.

**When to use**: Any recursive predicate that revisits the same arguments — graph reachability, transitive closure, dynamic programming.

**Pitfall**: Tabled predicates cannot use side effects (I/O, assert) reliably because the memo table may skip re-execution.

**Lattice answer subsumption**: Use `:- table p(_, lattice(merge/3)).` to keep only the "best" answer per call pattern, where `merge/3` combines competing answers. Useful for shortest-path and optimization problems.

```prolog
:- table shortest_path(+, +, -, lattice(shortest/3)).

shortest(P1, P2, P1) :- length(P1, L1), length(P2, L2), L1 =< L2.
shortest(_, P2, P2).
```

**Monotonic tabling**: `:- table p/2 as monotonic.` supports incremental updates when underlying facts change via `assert`. The table is updated incrementally rather than invalidated. Useful for reactive/event-driven programs.

---

**See also**: [Meta-Predicates](meta-predicates.md) (tabled predicates often collect results via findall/bagof), [Dynamic Predicates](dynamic-predicates.md) (monotonic tabling reacts to asserted facts).
