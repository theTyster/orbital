# Dicts (SWI-Prolog 7+)

**Problem**: Compound terms with many fields are positional and fragile. Dicts provide named access with a concise syntax.

## Core API

| Predicate / Syntax | Purpose |
|---|---|
| `Tag{key: value, ...}` | Dict literal syntax (Tag can be a variable) |
| `Dict.Key` | Dot accessor — get a field value (syntactic sugar) |
| `get_dict(Key, Dict, Value)` | Get a field value; **fails** if key absent |
| `get_dict(Key, Dict, Value, NewDict, NewValue)` | Get and functionally update in one step |
| `put_dict(Key, Dict, Value, NewDict)` | Set a single field, producing a new dict |
| `put_dict(Data, Dict, NewDict)` | Merge `Data` (dict or list) into `Dict` |
| `dict_pairs(Dict, Tag, Pairs)` | Convert between dict and `Key-Value` pair list |
| `dict_keys(Dict, Keys)` | Get all keys as a sorted list |
| `dict_create(Dict, Tag, Data)` | Create a dict from a tag and key-value data |
| `is_dict(Term)` | Test whether `Term` is a dict |
| `is_dict(Term, Tag)` | Test whether `Term` is a dict with the given `Tag` |

## Creating and Accessing Dicts

```prolog
%% Literal syntax with a tag
Person = person{name: "Alice", age: 30, role: engineer}.

%% Anonymous dict (unbound tag)
Config = _{host: localhost, port: 8080}.

%% Dot accessor syntax — syntactic sugar for get_dict
?- Person = person{name: "Alice", age: 30}, Name = Person.name.
% Name = "Alice".

%% get_dict/3 — explicit field access
?- get_dict(age, person{name: "Alice", age: 30}, Age).
% Age = 30.

%% get_dict/3 fails on missing keys (no error)
?- get_dict(email, person{name: "Alice"}, _).
% false.
```

## Pattern Matching

Dicts unify structurally — you can pattern match in clause heads:

```prolog
%% Match any dict with at least a name key
greet(Person) :-
    _{name: Name} :< Person,
    format("Hello, ~w!~n", [Name]).

%% Or use get_dict for the same effect
greet2(Person) :-
    get_dict(name, Person, Name),
    format("Hello, ~w!~n", [Name]).

%% :<  is "dict select" — left side keys must be subset of right
?- _{a: X} :< _{a: 1, b: 2, c: 3}.
% X = 1.
```

## Updating Dicts

Dicts are immutable — updates produce new dicts:

```prolog
%% put_dict/4 — set a single field
?- put_dict(age, person{name: "Alice", age: 30}, 31, Updated).
% Updated = person{age:31, name:"Alice"}.

%% put_dict/3 — merge multiple fields from another dict
?- put_dict(_{age: 31, role: admin}, person{name: "Alice", age: 30}, Updated).
% Updated = person{age:31, name:"Alice", role:admin}.

%% get_dict/5 — get old value and update in one step
?- get_dict(age, person{name: "Alice", age: 30}, OldAge, Updated, 31).
% OldAge = 30, Updated = person{age:31, name:"Alice"}.
```

## dict_pairs/3 — Convert Between Dicts and Pair Lists

This is the workhorse for programmatic dict construction and introspection:

```prolog
%% Dict to pairs
?- dict_pairs(point{x: 1, y: 2, z: 3}, Tag, Pairs).
% Tag = point, Pairs = [x-1, y-2, z-3].

%% Pairs to dict
?- dict_pairs(D, config, [host-localhost, port-8080, debug-true]).
% D = config{debug:true, host:localhost, port:8080}.

%% Build a dict dynamically from a list of keys and values
build_dict(Tag, Keys, Values, Dict) :-
    pairs_keys_values(Pairs, Keys, Values),
    dict_pairs(Dict, Tag, Pairs).

?- build_dict(row, [name, score, rank], ["Alice", 95, 1], D).
% D = row{name:"Alice", rank:1, score:95}.
```

## Practical Example: Data Transformation Pipeline

```prolog
:- use_module(library(apply)).

%% Normalize a list of user dicts: lowercase names, enforce defaults
normalize_users(RawUsers, Normalized) :-
    maplist(normalize_user, RawUsers, Normalized).

normalize_user(Raw, Norm) :-
    get_dict(name, Raw, Name),
    downcase_atom(Name, LowerName),
    (   get_dict(role, Raw, Role)
    ->  true
    ;   Role = viewer
    ),
    (   get_dict(active, Raw, Active)
    ->  true
    ;   Active = true
    ),
    dict_pairs(Norm, user, [name-LowerName, role-Role, active-Active]).

%% Filter to active admins
active_admins(Users, Admins) :-
    include(is_active_admin, Users, Admins).

is_active_admin(User) :-
    get_dict(role, User, admin),
    get_dict(active, User, true).

%% ?- normalize_users([_{name:'ALICE', role: admin},
%%                      _{name:'BOB'},
%%                      _{name:'CAROL', role: admin, active: false}],
%%                     Users),
%%    active_admins(Users, Admins).
%% Admins = [user{active:true, name:alice, role:admin}].
```

**When to use**: Structured data with many fields, JSON-like data processing, configuration records, or any case where positional compound terms would be fragile.

**Pitfall**: Dot accessor syntax (`Dict.Key`) only works when the compiler can resolve it — in some contexts (e.g., meta-calls), use `get_dict/3` explicitly.

---

**See also**: [Record](record.md) (lighter-weight alternative with compile-time field checking), [HTTP and JSON](http-json.md) (JSON is read/written as dicts), [Option Lists](option-lists.md) (another approach for named parameters).
