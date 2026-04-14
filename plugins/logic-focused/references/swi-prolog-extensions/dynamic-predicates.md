# Dynamic Predicates

**Problem**: The knowledge base is static by default. Sometimes you need to add or remove facts at runtime.

```prolog
:- dynamic known/2.

learn(Key, Value) :-
    assertz(known(Key, Value)).

forget(Key) :-
    retractall(known(Key, _)).

update(Key, NewValue) :-
    forget(Key),
    learn(Key, NewValue).
```

**When to use**: Caching, stateful computation, learning systems, configuration.

**Pitfall**: Overuse of assert/retract makes programs hard to reason about. Prefer passing state as arguments when possible.

---

**See also**: [Persistency](persistency.md) (persist dynamic facts across sessions), [Tabling](tabling.md) (monotonic tabling reacts to asserted facts), [Threading](threading.md) (use with_mutex/2 for concurrent assert/retract).
