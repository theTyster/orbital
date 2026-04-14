# Constraint Logic Programming

## CLP(FD) — Finite Domains (Integers)

**Problem**: Generate-and-test over integers is exponentially slow. CLP(FD) lets you state constraints declaratively and the solver prunes the search space.

```prolog
:- use_module(library(clpfd)).

% Solve: X + Y #= 10, X in 1..9, Y in 1..9
puzzle(X, Y) :-
    X in 1..9,
    Y in 1..9,
    X + Y #= 10,
    X #< Y,
    label([X, Y]).
```

**Key operators**: `#=`, `#\=`, `#<`, `#>`, `#=<`, `#>=`, `in`, `ins`, `label/1`, `labeling/2`, `all_distinct/1`.

**When to use**: Scheduling, puzzles (Sudoku, N-Queens), resource allocation, any combinatorial problem over integers.

**Example — N-Queens**:
```prolog
:- use_module(library(clpfd)).

n_queens(N, Qs) :-
    length(Qs, N),
    Qs ins 1..N,
    safe_queens(Qs),
    label(Qs).

safe_queens([]).
safe_queens([Q|Qs]) :-
    safe_from(Q, Qs, 1),
    safe_queens(Qs).

safe_from(_, [], _).
safe_from(Q0, [Q|Qs], D) :-
    Q0 #\= Q,
    abs(Q0 - Q) #\= D,
    D1 is D + 1,
    safe_from(Q0, Qs, D1).
```

## CLP(B) — Booleans

**Problem**: Boolean satisfiability, counting solutions, and probabilistic reasoning over boolean formulas.

```prolog
:- use_module(library(clpb)).

% Are there assignments where (A or B) and (not A or C) is true?
example(A, B, C) :-
    sat(A + B),          % A OR B
    sat(~A + C),         % NOT A OR C
    labeling([A, B, C]).

% Count the number of satisfying assignments
count_example(Count) :-
    sat_count(A * B + ~A * C, Count).
```

**When to use**: Circuit verification, configuration validity, combinatorial counting.

## CLP(Q) and CLP(R) — Rationals and Reals

**Problem**: Floating-point arithmetic is imprecise. CLP(Q) gives exact rational arithmetic; CLP(R) gives approximate but constraint-aware real arithmetic.

```prolog
:- use_module(library(clpq)).

% Solve: X + Y = 1, X - Y = 1/3
solve(X, Y) :-
    { X + Y = 1, X - Y = 1/3 }.
```

**When to use**: Financial calculations (CLP(Q) for exactness), linear programming, geometric reasoning.

---

**See also**: [Attributed Variables](attributed-variables.md) (the underlying mechanism that all CLP libraries are built on), [Coroutining](coroutining.md) (delayed goals and constraint propagation share the same foundations).
