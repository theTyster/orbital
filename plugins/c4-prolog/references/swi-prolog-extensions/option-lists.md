# Option Lists

**Problem**: Predicates with many optional parameters become unwieldy with positional arguments.

```prolog
:- use_module(library(option)).

% Define a predicate with options
create_report(Data, Options) :-
    option(format(Format), Options, html),       % default: html
    option(verbose(Verbose), Options, false),     % default: false
    option(output(Output), Options, 'report'),    % default: 'report'
    do_create(Data, Format, Verbose, Output).

% Call with options
?- create_report(my_data, [format(pdf), verbose(true)]).
```

**When to use**: Any predicate with more than 2-3 optional parameters.

---

**See also**: [Dicts](dicts.md) (an alternative for named-field data), [Record](record.md) (for fixed-structure data with defaults).
