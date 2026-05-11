# Option Lists

**Problem**: Predicates with many optional parameters become unwieldy with positional arguments.

## Core API

| Predicate | Purpose |
|---|---|
| `option(Opt, Options)` | Extract option value; **fails** if not present |
| `option(Opt, Options, Default)` | Extract option value with a default if absent |
| `merge_options(New, Old, Merged)` | Merge two option lists; `New` overrides `Old` |
| `select_option(Opt, Options, Rest)` | Extract option and return remaining list |
| `meta_options(IsMeta, Options0, Options)` | Expand module-qualified options |

## Example: option/2 vs option/3

```prolog
:- use_module(library(option)).

%% option/3 — with default (never fails due to missing option)
create_report(Data, Options) :-
    option(format(Format), Options, html),       % default: html
    option(verbose(Verbose), Options, false),     % default: false
    option(output(Output), Options, 'report'),    % default: 'report'
    do_create(Data, Format, Verbose, Output).

%% option/2 — required option (fails if missing)
connect(Options) :-
    option(host(Host), Options),                  % required — no default
    option(port(Port), Options, 443),             % optional — defaults to 443
    open_connection(Host, Port).
```

```prolog
?- create_report(my_data, [format(pdf), verbose(true)]).
% Output defaults to 'report'

?- connect([host(example.com)]).
% Port defaults to 443

?- connect([port(8080)]).
% Fails — host is required
```

## Example: merge_options/3

Layering user options over defaults:

```prolog
:- use_module(library(option)).

default_config([
    timeout(30),
    retries(3),
    verbose(false),
    format(json)
]).

run_request(UserOptions) :-
    default_config(Defaults),
    merge_options(UserOptions, Defaults, Options),
    % UserOptions win on conflict; Defaults fill gaps
    option(timeout(T), Options),
    option(retries(R), Options),
    option(verbose(V), Options),
    option(format(F), Options),
    format("timeout=~w retries=~w verbose=~w format=~w~n",
           [T, R, V, F]).
```

```prolog
?- run_request([timeout(5), verbose(true)]).
% timeout=5 retries=3 verbose=true format=json
%   timeout and verbose overridden; retries and format from defaults
```

## Example: select_option/3

Consuming options one at a time, passing the rest through:

```prolog
process_and_forward(Options) :-
    select_option(debug(true), Options, Rest),
    !,
    format("Debug mode on~n"),
    forward(Rest).      % remaining options without debug(true)
process_and_forward(Options) :-
    forward(Options).   % debug not present — forward all
```

**When to use**: Any predicate with more than 2-3 optional parameters. Use `merge_options/3` when layering user-supplied options over defaults.

---

**See also**: [Dicts](dicts.md) (an alternative for named-field data), [Record](record.md) (for fixed-structure data with defaults).
