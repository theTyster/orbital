# Debugging Extensions

## Debug Messages (library(debug))

The `debug/3` message system is the primary way to add structured, toggleable trace output to Prolog programs.

```prolog
:- use_module(library(debug)).

:- debug(my_app).  % Enable debug topic

my_predicate(X) :-
    debug(my_app, "Processing: ~w", [X]),
    process(X).
```

Enable/disable at runtime: `?- debug(my_app).` / `?- nodebug(my_app).`

### Hierarchical Topics

```prolog
:- debug(my_app/parser).    % Enable only parser messages
:- debug(my_app/db).        % Enable only database messages

parse(Input) :-
    debug(my_app/parser, "Parsing: ~w", [Input]),
    do_parse(Input).

query_db(Q) :-
    debug(my_app/db, "Query: ~w", [Q]),
    run_query(Q).
```

```prolog
?- debug(my_app/_).        % Enable ALL sub-topics of my_app
?- nodebug(my_app/parser). % Disable just the parser topic
```

### Conditional Debug Messages

```prolog
check_threshold(Value, Limit) :-
    (   Value > Limit
    ->  debug(my_app, "WARNING: ~w exceeds limit ~w", [Value, Limit])
    ;   debug(my_app, "OK: ~w within limit ~w", [Value, Limit])
    ).
```

## Interactive Tracer (spy/1, trace/0)

The built-in tracer lets you step through execution interactively.

```prolog
% Trace everything (verbose — use sparingly)
?- trace.
?- my_goal(X).
%  Call: my_goal(X)
%  ...type 'h' for help at any port

% Stop tracing
?- notrace.

% Spy on specific predicates (much more practical)
?- spy(my_predicate/2).
?- my_goal(X).
% Breaks into tracer only when my_predicate/2 is called

% Remove spy point
?- nospy(my_predicate/2).

% Remove all spy points
?- nospyall.
```

### Tracer Ports

At each tracer prompt, you see one of four ports:

| Port | Meaning |
|---|---|
| **Call** | Entering a goal |
| **Exit** | Goal succeeded |
| **Redo** | Backtracking into a goal |
| **Fail** | Goal failed |

Common tracer commands: `c` (creep/step), `s` (skip), `l` (leap to next spy point), `a` (abort), `n` (nodebug/continue).

## Execution Profiling

```prolog
?- profile(my_goal).
% Shows time spent per predicate — statistical sampling

?- time(expensive_computation(Result)).
% Shows wall time, inferences, CPU — lightweight measurement
```

### Counting Inferences

```prolog
?- statistics(inferences, Before),
   my_goal,
   statistics(inferences, After),
   Count is After - Before,
   format("Inferences: ~w~n", [Count]).
```

## Clause Inspection

```prolog
?- listing(my_predicate/2).
% Prints the current definition, including asserted clauses

?- predicate_property(my_predicate/2, Prop).
% Query properties: defined_in, number_of_clauses, etc.
```

---

**See also**: [Modules](modules.md) (debug topics can be scoped per module), [Meta-Predicates](meta-predicates.md) (profile/1 and time/1 are meta-predicates that take a goal argument).
