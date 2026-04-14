# Dynamic Predicates

**Problem**: The knowledge base is static by default. Sometimes you need to add or remove facts at runtime.

## Core API

| Predicate | Purpose |
|---|---|
| `:- dynamic pred/arity.` | Declare a predicate as modifiable at runtime |
| `asserta(Clause)` | Add a clause at the **beginning** of the predicate |
| `assertz(Clause)` | Add a clause at the **end** of the predicate |
| `retract(Clause)` | Remove the **first** matching clause (fails if none) |
| `retractall(Head)` | Remove **all** clauses whose head matches (always succeeds) |
| `abolish(Pred/Arity)` | Remove the predicate entirely (including its dynamic declaration) |

## Example: asserta/1 vs assertz/1

The difference is clause ordering, which affects which clause matches first on backtracking:

```prolog
:- dynamic greeting/1.

?- assertz(greeting(hello)).
?- assertz(greeting(hi)).
?- asserta(greeting(hey)).

?- greeting(X).
X = hey ;    % asserta put this first
X = hello ;  % assertz preserved insertion order
X = hi.      % assertz preserved insertion order
```

## Example: retract/1 vs retractall/1

```prolog
:- dynamic task/2.

?- assertz(task(1, pending)).
?- assertz(task(2, pending)).
?- assertz(task(3, done)).
?- assertz(task(4, pending)).

%% retract/1 — removes FIRST match, can backtrack for more
?- retract(task(_, pending)).
% Removes task(1, pending). On backtracking, removes task(2, pending), etc.

%% retractall/1 — removes ALL matches at once, always succeeds
?- retractall(task(_, pending)).
% Removes task(2, pending) and task(4, pending) in one call
% Succeeds even if no clauses match
```

## Example: Knowledge Base CRUD

```prolog
:- dynamic known/2.

%% Create
learn(Key, Value) :-
    assertz(known(Key, Value)).

%% Read
lookup(Key, Value) :-
    known(Key, Value).

%% Update (replace all values for a key)
update(Key, NewValue) :-
    retractall(known(Key, _)),
    assertz(known(Key, NewValue)).

%% Delete
forget(Key) :-
    retractall(known(Key, _)).

%% Conditional insert (only if not already known)
learn_once(Key, Value) :-
    (   known(Key, Value)
    ->  true
    ;   assertz(known(Key, Value))
    ).
```

## Example: Dynamic Rules (Not Just Facts)

You can assert full rules, not just ground facts:

```prolog
:- dynamic can_access/2.

%% Assert a rule with a body
?- assertz((can_access(User, Resource) :-
                member(User, [admin, root]))).

%% Assert a ground fact
?- assertz(can_access(alice, reports)).

?- can_access(admin, anything).
true.

?- can_access(alice, reports).
true.
```

**When to use**: Caching, stateful computation, learning systems, configuration.

**Pitfall**: Overuse of assert/retract makes programs hard to reason about. Prefer passing state as arguments when possible.

---

**See also**: [Persistency](persistency.md) (persist dynamic facts across sessions), [Tabling](tabling.md) (monotonic tabling reacts to asserted facts), [Threading](threading.md) (use with_mutex/2 for concurrent assert/retract).
