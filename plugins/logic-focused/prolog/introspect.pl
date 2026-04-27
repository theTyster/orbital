/**
 * introspect.pl — Generic knowledge base introspection
 *
 * Explore any Prolog facts file loaded into the user module.
 * Not tied to any ontology — works with arbitrary predicates.
 *
 * Usage:
 *   swipl -g "use_module('introspect'), consult('facts.pl'), kb_summary" -t halt
 */

:- module(introspect, [
    kb_summary/0,        % Print predicate names, arities, clause counts
    kb_describe/0,       % Print all facts grouped by predicate
    kb_describe/1,       % Print facts for a specific predicate (Name/Arity or Name)
    kb_find/1,           % Find facts containing a given atom
    kb_related/1,        % Find atoms that co-occur with a given atom
    kb_graph/0,          % Print binary predicates as directed edges
    kb_stats/0           % Per-predicate statistics (counts, unique values)
]).

%% ---- Helpers ----

%% kb_module(-Module) is nondet.
%  Modules that may hold user-authored facts. Includes `user` (the default for
%  unqualified consult) plus any module loaded from a file outside SWI's
%  installation tree. This admits facts files that begin with `:- module(...)`,
%  which previous versions silently ignored. The introspect module itself is
%  excluded so kb_describe doesn't recurse into its own predicates.
kb_module(user).
kb_module(M) :-
    current_module(M),
    M \== user,
    M \== introspect,
    module_property(M, file(F)),
    \+ system_file(F).

%% system_file(+File) is semidet.
%  True if File is under SWI's installation tree.
system_file(F) :-
    current_prolog_flag(home, Home),
    sub_atom(F, 0, _, _, Home).

%% user_predicate(+Module, +Head) is semidet.
%  True if Head names a user-authored predicate in Module: it has clauses, was
%  not imported, is not a built-in, is not a $-prefixed internal, and (if a
%  defining file is known) that file lies outside SWI's installation tree.
%  This last check filters multifile bookkeeping like file_search_path/2 that
%  SWI ships into the user module, while still keeping user-authored multifile
%  predicates declared in a project's own facts file.
user_predicate(M, Head) :-
    predicate_property(M:Head, number_of_clauses(N)), N > 0,
    \+ predicate_property(M:Head, imported_from(_)),
    \+ predicate_property(M:Head, built_in),
    functor(Head, Name, _),
    \+ sub_atom(Name, 0, _, _, '$'),
    (   predicate_property(M:Head, file(F))
    ->  \+ system_file(F)
    ;   true
    ).

%% user_predicates(-Preds:list) is det.
%  Sorted list of Module:Name/Arity for every user-authored predicate.
user_predicates(Preds) :-
    findall(M:Name/Arity,
        (   kb_module(M),
            current_predicate(M:Name/Arity),
            functor(Head, Name, Arity),
            user_predicate(M, Head)
        ),
        Raw),
    sort(Raw, Preds).

%% term_mentions(+Term, +Atom) is semidet.
%  True if Atom appears anywhere in Term (head functor or arguments).
term_mentions(Term, Atom) :- Term == Atom, !.
term_mentions(Term, Atom) :-
    compound(Term),
    Term =.. [_|Args],
    member(Arg, Args),
    term_mentions(Arg, Atom), !.

%% ---- Public predicates ----

%% kb_summary is det.
%  Print each user predicate with its arity and clause count.
kb_summary :-
    user_predicates(Preds),
    format('=== Knowledge Base Summary ===~n~n'),
    foldl(print_pred_count, Preds, 0, Total),
    length(Preds, NP),
    format('~n~w predicates, ~w total clauses~n', [NP, Total]).

print_pred_count(M:Name/Arity, Acc, Acc1) :-
    functor(Head, Name, Arity),
    predicate_property(M:Head, number_of_clauses(Count)),
    (   M == user
    ->  format('  ~w/~w  ~w clauses~n', [Name, Arity, Count])
    ;   format('  ~w:~w/~w  ~w clauses~n', [M, Name, Arity, Count])
    ),
    Acc1 is Acc + Count.

%% kb_describe is det.
%  Print all user facts, grouped by predicate.
kb_describe :-
    user_predicates(Preds),
    forall(member(P, Preds), kb_describe(P)).

%% kb_describe(+Spec) is det.
%  Print facts for a single predicate.
%  Spec is Module:Name/Arity, Name/Arity, or just Name.
kb_describe(M:Name/Arity) :-
    !,
    functor(Head, Name, Arity),
    format('~n--- ~w:~w/~w ---~n', [M, Name, Arity]),
    forall(M:Head, format('  ~q.~n', [Head])).
kb_describe(Name/Arity) :-
    !,
    forall(
        (   kb_module(M),
            current_predicate(M:Name/Arity),
            functor(Head, Name, Arity),
            user_predicate(M, Head)
        ),
        kb_describe(M:Name/Arity)
    ).
kb_describe(Name) :-
    atom(Name),
    forall(
        (   kb_module(M),
            current_predicate(M:Name/Arity),
            functor(Head, Name, Arity),
            user_predicate(M, Head)
        ),
        kb_describe(M:Name/Arity)
    ).

%% kb_find(+Atom) is det.
%  Print every fact that mentions Atom in any argument position.
kb_find(Atom) :-
    format('=== Facts mentioning ~w ===~n~n', [Atom]),
    user_predicates(Preds),
    forall(
        (   member(M:Name/Arity, Preds),
            functor(Head, Name, Arity),
            M:Head,
            term_mentions(Head, Atom)
        ),
        (   M == user
        ->  format('  ~q.~n', [Head])
        ;   format('  ~w: ~q.~n', [M, Head])
        )
    ).

%% kb_related(+Atom) is det.
%  Print atoms that co-occur with Atom in the same fact.
kb_related(Atom) :-
    format('=== Atoms related to ~w ===~n~n', [Atom]),
    user_predicates(Preds),
    findall(Co,
        (   member(M:Name/Arity, Preds),
            functor(Head, Name, Arity),
            M:Head,
            term_mentions(Head, Atom),
            Head =.. [_|Args],
            member(Arg, Args),
            atomic(Arg),
            Arg \== Atom,
            Co = Arg
        ),
        Raw),
    sort(Raw, Cos),
    forall(member(C, Cos), format('  ~w~n', [C])).

%% kb_graph is det.
%  Print all binary predicates as directed edges: A -[pred]-> B.
%  Useful for dependency-like visualization of any binary relation.
kb_graph :-
    format('=== Graph (binary predicates) ===~n~n'),
    user_predicates(Preds),
    forall(
        (   member(M:Name/2, Preds),
            functor(Head, Name, 2),
            M:Head,
            arg(1, Head, A),
            arg(2, Head, B)
        ),
        format('  ~w -[~w]-> ~w~n', [A, Name, B])
    ).

%% kb_stats is det.
%  Per-predicate statistics: clause count and unique values per argument position.
kb_stats :-
    format('=== Knowledge Base Statistics ===~n~n'),
    user_predicates(Preds),
    forall(member(P, Preds), pred_stats(P)).

pred_stats(M:Name/Arity) :-
    functor(Head, Name, Arity),
    predicate_property(M:Head, number_of_clauses(Count)),
    (   M == user
    ->  format('~w/~w  (~w clauses)~n', [Name, Arity, Count])
    ;   format('~w:~w/~w  (~w clauses)~n', [M, Name, Arity, Count])
    ),
    forall(between(1, Arity, Pos), arg_stats(M, Name, Arity, Pos)),
    nl.

arg_stats(M, Name, Arity, Pos) :-
    functor(Head, Name, Arity),
    findall(V, (M:Head, arg(Pos, Head, V)), Vals),
    sort(Vals, Uniq),
    length(Uniq, NU),
    (   NU =< 8
    ->  format('  arg ~w: ~w unique — ~w~n', [Pos, NU, Uniq])
    ;   length(Sample, 5),
        append(Sample, _, Uniq),
        format('  arg ~w: ~w unique — ~w ...~n', [Pos, NU, Sample])
    ).
