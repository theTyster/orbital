# Record (Named Compound Terms)

**Problem**: Accessing fields in compound terms by position (arg/3) is fragile and unreadable.

## Generated Predicates

For a declaration `:- record point(x: float = 0.0, y: float = 0.0)`, the library generates:

| Generated Predicate | Purpose |
|---|---|
| `default_point(-Record)` | Create a record with all defaults |
| `make_point(+Fields, -Record)` | Create from a list of `field(value)` pairs |
| `point_x(+Record, -Value)` | Get the `x` field |
| `point_y(+Record, -Value)` | Get the `y` field |
| `set_x_of_point(+Value, +RecordIn, -RecordOut)` | Set the `x` field (functional update) |
| `set_y_of_point(+Value, +RecordIn, -RecordOut)` | Set the `y` field (functional update) |
| `point_data(?Name, ?Value, +Record)` | Access any field by name at runtime |

## Example: Geometry

```prolog
:- use_module(library(record)).

:- record point(x: float = 0.0, y: float = 0.0, z: float = 0.0).

example :-
    default_point(P0),
    set_x_of_point(3.0, P0, P1),
    set_y_of_point(4.0, P1, P2),
    point_x(P2, X),
    point_y(P2, Y),
    Dist is sqrt(X*X + Y*Y),
    format("Distance from origin: ~f~n", [Dist]).
```

## Example: make_<name>/2 for Construction

```prolog
:- use_module(library(record)).

:- record config(
    host: atom = localhost,
    port: integer = 8080,
    debug: boolean = false
).

start_server :-
    make_config([host(example.com), debug(true)], Cfg),
    % port defaults to 8080
    config_host(Cfg, Host),
    config_port(Cfg, Port),
    config_debug(Cfg, Debug),
    format("Starting ~w:~w (debug=~w)~n", [Host, Port, Debug]).
```

```prolog
?- start_server.
% Starting example.com:8080 (debug=true)
```

## Example: Runtime Field Access with <name>_data/3

```prolog
:- use_module(library(record)).

:- record person(name: atom, age: integer = 0).

show_all_fields(Person) :-
    forall(
        person_data(FieldName, Value, Person),
        format("  ~w: ~w~n", [FieldName, Value])
    ).
```

```prolog
?- make_person([name(alice), age(30)], P), show_all_fields(P).
%   name: alice
%   age: 30
```

**When to use**: When you have structured data but dicts feel too heavy, or you want compile-time field name checking.

---

**See also**: [Dicts](dicts.md) (heavier-weight alternative with runtime field access), [Option Lists](option-lists.md) (for optional parameters rather than structured data).
