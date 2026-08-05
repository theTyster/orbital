# Persistency

**Problem**: Dynamic predicates vanish when the program exits. You want some facts to survive across sessions.

## How It Works

The `:- persistent` directive declares predicates whose facts are automatically journaled to a file. Every `assert_<name>` and `retract_<name>` is appended to the journal. On `db_attach/2`, the journal is replayed to restore state.

## Core API

| Predicate | Purpose |
|---|---|
| `:- persistent spec.` | Declare a persistent predicate with typed fields |
| `db_attach(File, Options)` | Attach (and replay) a journal file |
| `db_detach` | Detach the current database file |
| `db_sync(What)` | Synchronize: `gc` compacts the journal, `reload` re-reads it |
| `assert_<name>(Args...)` | Assert a fact and append to journal |
| `retract_<name>(Args...)` | Retract a fact and append retraction to journal |
| `retractall_<name>(Args...)` | Retract all matching facts |

## Example: Settings Store

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

update_setting(Key, NewValue) :-
    retractall_setting(Key, _),
    assert_setting(Key, NewValue).

remove_setting(Key) :-
    retractall_setting(Key, _).
```

```prolog
?- init_db.
true.

?- save_setting(theme, dark).
true.

?- save_setting(lang, en).
true.

?- load_setting(theme, V).
V = dark.

?- update_setting(theme, light).
true.

?- load_setting(theme, V).
V = light.
```

## Example: Multiple Persistent Predicates

```prolog
:- use_module(library(persistency)).

:- persistent
    user(name: atom, email: atom),
    log_entry(timestamp: float, message: atom).

init :-
    db_attach('app.db', []).

add_user(Name, Email) :-
    assert_user(Name, Email).

log(Msg) :-
    get_time(T),
    assert_log_entry(T, Msg).

%% Compact the journal file (removes retracted facts)
compact_db :-
    db_sync(gc).
```

**When to use**: Small-scale persistence — config, user preferences, cached results. Not a replacement for a real database.

**Pitfall**: The journal file grows with every assert/retract. Call `db_sync(gc)` periodically to compact it.

---

**See also**: [Dynamic Predicates](dynamic-predicates.md) (persistency builds on dynamic predicates), [Record](record.md) (structured data that can be persisted).
