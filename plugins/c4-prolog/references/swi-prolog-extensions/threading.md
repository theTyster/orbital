# Threading

**Problem**: Prolog is single-threaded by default. CPU-bound tasks can't use multiple cores; I/O-bound tasks block unnecessarily.

```prolog
:- use_module(library(thread)).

% Run two goals concurrently
parallel_example :-
    thread_create(expensive_task(a, ResultA), IdA, []),
    thread_create(expensive_task(b, ResultB), IdB, []),
    thread_join(IdA, exited(ResultA)),
    thread_join(IdB, exited(ResultB)),
    format("Results: ~w, ~w~n", [ResultA, ResultB]).
```

**Message passing**:
```prolog
:- use_module(library(thread)).

worker :-
    thread_get_message(task(X)),
    Result is X * X,
    thread_send_message(main, result(Result)).

run :-
    thread_create(worker, Id, []),
    thread_send_message(Id, task(42)),
    thread_get_message(result(R)),
    format("Result: ~w~n", [R]),
    thread_join(Id, _).
```

**When to use**: Parallel search, web servers, concurrent I/O. Note: SWI-Prolog threads share the same heap, so assert/retract needs care (use `with_mutex/2`).

---

**See also**: [Modules](modules.md) (each thread has its own module import context), [Dynamic Predicates](dynamic-predicates.md) (use with_mutex/2 when asserting/retracting from multiple threads), [HTTP and JSON](http-json.md) (the HTTP server uses threads internally).
