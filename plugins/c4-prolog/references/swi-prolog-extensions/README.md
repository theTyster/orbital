# SWI-Prolog Extensions Reference

A supplementary reference for skills that generate, analyze, or reason about SWI-Prolog code. Each extension has its own file. Use the quick reference table to find what you need, then read the relevant file.

## Quick Reference

| Extension | Problem It Solves | Enable With | File |
|---|---|---|---|
| Tabling | Infinite loops & redundant recomputation in recursion | `:- table pred/arity.` | [tabling.md](tabling.md) |
| CLP(FD) | Constraint satisfaction over integers | `:- use_module(library(clpfd)).` | [clp.md](clp.md) |
| CLP(B) | Boolean satisfiability & counting | `:- use_module(library(clpb)).` | [clp.md](clp.md) |
| CLP(Q/R) | Constraints over rationals/reals | `:- use_module(library(clpq)).` or `library(clpr)` | [clp.md](clp.md) |
| Modules | Namespace collisions in large programs | `:- module(Name, [Exports]).` | [modules.md](modules.md) |
| DCG | Verbose parsing/grammar code | `-->` notation (built-in) | [dcg.md](dcg.md) |
| Coroutining | Goals evaluated before bindings are ready | `freeze/2`, `when/2`, `dif/2` (built-in) | [coroutining.md](coroutining.md) |
| Attributed Variables | Attaching metadata to unbound variables | `put_attr/3`, `get_attr/3` (built-in) | [attributed-variables.md](attributed-variables.md) |
| Meta-predicates | Collecting/transforming multiple solutions | `library(apply)`, `library(aggregate)` | [meta-predicates.md](meta-predicates.md) |
| Threading | Single-threaded bottlenecks | `library(thread)` | [threading.md](threading.md) |
| Dynamic Predicates | Runtime knowledge base modification | Built-in | [dynamic-predicates.md](dynamic-predicates.md) |
| Dicts | Key-value data structures | Built-in (SWI 7+) | [dicts.md](dicts.md) |
| Persistency | Persisting dynamic predicates to disk | `:- use_module(library(persistency)).` | [persistency.md](persistency.md) |
| HTTP/JSON | Web I/O and structured data | `library(http/json)`, `library(http/http_server)` | [http-json.md](http-json.md) |
| PCRE | Regular expressions | `:- use_module(library(pcre)).` | [pcre.md](pcre.md) |
| Record | Named compound term accessors | `:- use_module(library(record)).` | [record.md](record.md) |
| Option Lists | Handling keyword-style options | `:- use_module(library(option)).` | [option-lists.md](option-lists.md) |
| Debugging | Debug messages, profiling, clause inspection | `library(debug)` | [debugging.md](debugging.md) |
| Pack System | Installing third-party libraries | `pack_install/1` (built-in) | [pack-system.md](pack-system.md) |

## Extension Selection Guide

| If you need to... | Use |
|---|---|
| Avoid infinite recursion | [Tabling](tabling.md) |
| Solve combinatorial integer problems | [CLP(FD)](clp.md) |
| Check boolean satisfiability | [CLP(B)](clp.md) |
| Do exact arithmetic with fractions | [CLP(Q)](clp.md) |
| Parse structured input | [DCG](dcg.md) |
| Delay evaluation until variables are bound | [Coroutining](coroutining.md) |
| Ensure two things are never equal | [Coroutining (dif/2)](coroutining.md) |
| Collect all solutions into a list | [Meta-predicates](meta-predicates.md) |
| Apply a predicate across a list | [Meta-predicates](meta-predicates.md) |
| Build a custom constraint solver | [Attributed Variables](attributed-variables.md) |
| Run tasks in parallel | [Threading](threading.md) |
| Add or remove facts at runtime | [Dynamic Predicates](dynamic-predicates.md) |
| Persist facts across sessions | [Persistency](persistency.md) |
| Handle JSON data | [HTTP/JSON](http-json.md) |
| Match text patterns | [PCRE](pcre.md) |
| Manage complex options | [Option Lists](option-lists.md) |
| Structure data with named fields | [Dicts](dicts.md) or [Record](record.md) |
| Organize code into namespaces | [Modules](modules.md) |
| Trace and profile execution | [Debugging](debugging.md) |
| Install third-party libraries | [Pack System](pack-system.md) |

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
