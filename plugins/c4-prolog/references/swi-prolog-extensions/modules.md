# Module System

**Problem**: In large programs, predicate names collide. Modules provide namespaces.

```prolog
% file: utils.pl
:- module(utils, [
    mean/2,
    median/2
]).

mean(List, Mean) :-
    sum_list(List, Sum),
    length(List, N),
    Mean is Sum / N.

median(List, Median) :-
    msort(List, Sorted),
    length(Sorted, N),
    Mid is N // 2,
    nth0(Mid, Sorted, Median).
```

```prolog
% file: main.pl
:- use_module(utils).

run :-
    mean([1,2,3,4,5], M),
    format("Mean: ~w~n", [M]).
```

**Selective import**: `:- use_module(utils, [mean/2]).` imports only `mean/2`.

**Reexport**: A module can re-export predicates from other modules, creating facade modules:

```prolog
:- module(all_utils, []).
:- reexport(utils).
:- reexport(string_utils, [trim/2]).
```

**Library paths**: Use `library(Name)` for installed libraries vs. file paths for local modules:

```prolog
:- use_module(library(lists)).       % system library
:- use_module(library(apply)).       % system library
:- use_module('./helpers/parser').    % local file
```

**When to use**: Any project with more than one file. Always use modules for reusable libraries.

---

**See also**: [Meta-Predicates](meta-predicates.md) (meta_predicate/1 declarations ensure correct goal qualification across modules), [DCG](dcg.md) (DCG rules can be modularized and imported), [Pack System](pack-system.md) (third-party packs are loaded as modules via use_module/1).
