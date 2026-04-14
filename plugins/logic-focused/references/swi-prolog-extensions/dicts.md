# Dicts (SWI-Prolog 7+)

**Problem**: Compound terms with many fields are positional and fragile. Dicts provide named access.

```prolog
% Create a dict
Person = person{name: "Alice", age: 30, role: engineer}.

% Access a field
?- Person.name = Name.
% Name = "Alice".

% Pattern match
greet(Person) :-
    get_dict(name, Person, Name),
    format("Hello, ~w!~n", [Name]).

% Update (creates new dict)
birthday(Person, Older) :-
    get_dict(age, Person, Age),
    NewAge is Age + 1,
    put_dict(age, Person, NewAge, Older).
```

**When to use**: Structured data with many fields, JSON-like data processing, configuration records.

---

**See also**: [Record](record.md) (lighter-weight alternative with compile-time field checking), [HTTP and JSON](http-json.md) (JSON is read/written as dicts), [Option Lists](option-lists.md) (another approach for named parameters).
