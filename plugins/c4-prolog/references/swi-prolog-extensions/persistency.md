# Persistency

**Problem**: Dynamic predicates vanish when the program exits. You want some facts to survive across sessions.

```prolog
:- use_module(library(persistency)).

:- persistent
    setting(key: atom, value: term).

init_db :-
    db_attach('settings.db', []).

save_setting(Key, Value) :-
    assert_setting(Key, Value).

load_setting(Key, Value) :-
    setting(Key, Value).
```

**When to use**: Small-scale persistence — config, user preferences, cached results. Not a replacement for a real database.

---

**See also**: [Dynamic Predicates](dynamic-predicates.md) (persistency builds on dynamic predicates), [Record](record.md) (structured data that can be persisted).
