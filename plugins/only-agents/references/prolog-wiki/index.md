# Prolog Wiki

A general knowledge source for SWI-Prolog: libraries, extensions, idioms, and anything else worth cataloguing. Every entry lives inside a category subdirectory so the index stays navigable as the wiki grows. Today there is one category (`extensions/`); new categories (e.g. `idioms/`, `libraries/`, `patterns/`) can be added alongside it following the same pattern.

## Structure

```
prolog-wiki/
├── index.md          — this file (wiki entry point + quick reference)
├── extensions/       — SWI-Prolog extensions: tabling, CLP, DCG, modules, etc.
├── practices/        — engineering practices: validation, loading discipline, etc.
└── <future-category>/ — additional topic areas as needed
```

Every category directory should contain one markdown file per entry, named after the topic in kebab-case.

## Extensions — Quick Reference

| Extension | Problem It Solves | Enable With | File |
|---|---|---|---|
| Tabling | Infinite loops & redundant recomputation in recursion | `:- table pred/arity.` | [extensions/tabling.md](extensions/tabling.md) |
| CLP(FD) | Constraint satisfaction over integers | `:- use_module(library(clpfd)).` | [extensions/clp.md](extensions/clp.md) |
| CLP(B) | Boolean satisfiability & counting | `:- use_module(library(clpb)).` | [extensions/clp.md](extensions/clp.md) |
| CLP(Q/R) | Constraints over rationals/reals | `:- use_module(library(clpq)).` or `library(clpr)` | [extensions/clp.md](extensions/clp.md) |
| Modules | Namespace collisions in large programs | `:- module(Name, [Exports]).` | [extensions/modules.md](extensions/modules.md) |
| DCG | Verbose parsing/grammar code | `-->` notation (built-in) | [extensions/dcg.md](extensions/dcg.md) |
| Coroutining | Goals evaluated before bindings are ready | `freeze/2`, `when/2`, `dif/2` (built-in) | [extensions/coroutining.md](extensions/coroutining.md) |
| Attributed Variables | Attaching metadata to unbound variables | `put_attr/3`, `get_attr/3` (built-in) | [extensions/attributed-variables.md](extensions/attributed-variables.md) |
| Meta-predicates | Collecting/transforming multiple solutions | `library(apply)`, `library(aggregate)` | [extensions/meta-predicates.md](extensions/meta-predicates.md) |
| Threading | Single-threaded bottlenecks | `library(thread)` | [extensions/threading.md](extensions/threading.md) |
| Dynamic Predicates | Runtime knowledge base modification | Built-in | [extensions/dynamic-predicates.md](extensions/dynamic-predicates.md) |
| Dicts | Key-value data structures | Built-in (SWI 7+) | [extensions/dicts.md](extensions/dicts.md) |
| Persistency | Persisting dynamic predicates to disk | `:- use_module(library(persistency)).` | [extensions/persistency.md](extensions/persistency.md) |
| HTTP/JSON | Web I/O and structured data | `library(http/json)`, `library(http/http_server)` | [extensions/http-json.md](extensions/http-json.md) |
| PCRE | Regular expressions | `:- use_module(library(pcre)).` | [extensions/pcre.md](extensions/pcre.md) |
| Record | Named compound term accessors | `:- use_module(library(record)).` | [extensions/record.md](extensions/record.md) |
| Option Lists | Handling keyword-style options | `:- use_module(library(option)).` | [extensions/option-lists.md](extensions/option-lists.md) |
| Debugging | Debug messages, profiling, clause inspection | `library(debug)` | [extensions/debugging.md](extensions/debugging.md) |
| Pack System | Installing third-party libraries | `pack_install/1` (built-in) | [extensions/pack-system.md](extensions/pack-system.md) |

## Extension Selection Guide

| If you need to... | Use |
|---|---|
| Avoid infinite recursion | [Tabling](extensions/tabling.md) |
| Solve combinatorial integer problems | [CLP(FD)](extensions/clp.md) |
| Check boolean satisfiability | [CLP(B)](extensions/clp.md) |
| Do exact arithmetic with fractions | [CLP(Q)](extensions/clp.md) |
| Parse structured input | [DCG](extensions/dcg.md) |
| Delay evaluation until variables are bound | [Coroutining](extensions/coroutining.md) |
| Ensure two things are never equal | [Coroutining (dif/2)](extensions/coroutining.md) |
| Collect all solutions into a list | [Meta-predicates](extensions/meta-predicates.md) |
| Apply a predicate across a list | [Meta-predicates](extensions/meta-predicates.md) |
| Build a custom constraint solver | [Attributed Variables](extensions/attributed-variables.md) |
| Run tasks in parallel | [Threading](extensions/threading.md) |
| Add or remove facts at runtime | [Dynamic Predicates](extensions/dynamic-predicates.md) |
| Persist facts across sessions | [Persistency](extensions/persistency.md) |
| Handle JSON data | [HTTP/JSON](extensions/http-json.md) |
| Match text patterns | [PCRE](extensions/pcre.md) |
| Manage complex options | [Option Lists](extensions/option-lists.md) |
| Structure data with named fields | [Dicts](extensions/dicts.md) or [Record](extensions/record.md) |
| Organize code into namespaces | [Modules](extensions/modules.md) |
| Trace and profile execution | [Debugging](extensions/debugging.md) |
| Install third-party libraries | [Pack System](extensions/pack-system.md) |

## Practices

| Topic | What it covers | File |
|---|---|---|
| Strict Loading | Treat singleton/discontiguous/undefined-procedure warnings as load failures via `--on-warning=status` | [practices/strict-loading.md](practices/strict-loading.md) |

## Common Import Block

A practical starting point for programs that want broad access to SWI-Prolog's capabilities:

```prolog
:- use_module(library(clpfd)).          % Integer constraints
:- use_module(library(clpb)).           % Boolean constraints
:- use_module(library(lists)).          % List operations
:- use_module(library(apply)).          % maplist, include, foldl
:- use_module(library(aggregate)).      % Aggregation
:- use_module(library(dcg/basics)).     % DCG utilities
:- use_module(library(option)).         % Option lists
:- use_module(library(debug)).          % Debug messages
:- use_module(library(pcre)).           % Regex
:- use_module(library(http/json)).      % JSON
:- use_module(library(persistency)).    % Persistent facts
```

Only import what you actually use. Each import adds to load time and the predicate namespace.
