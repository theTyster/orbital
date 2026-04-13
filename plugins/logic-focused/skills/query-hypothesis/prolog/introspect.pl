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

%% user_predicates(-Preds:list) is det.
%  Sorted list of Name/Arity for every predicate with clauses in the user module.
%  Excludes imported predicates, system internals ($-prefixed), and multifile
%  predicates (which filters SWI-Prolog's file_search_path/2 etc.).
user_predicates(Preds) :-
    findall(Name/Arity,
        (   current_predicate(user:Name/Arity),
            functor(Head, Name, Arity),
            predicate_property(user:Head, number_of_clauses(N)), N > 0,
            \+ predicate_property(user:Head, imported_from(_)),
            \+ predicate_property(user:Head, multifile),
            \+ sub_atom(Name, 0, _, _, '$')
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

print_pred_count(Name/Arity, Acc, Acc1) :-
    functor(Head, Name, Arity),
    predicate_property(user:Head, number_of_clauses(Count)),
    format('  ~w/~w  ~w clauses~n', [Name, Arity, Count]),
    Acc1 is Acc + Count.

%% kb_describe is det.
%  Print all user facts, grouped by predicate.
kb_describe :-
    user_predicates(Preds),
    forall(member(P, Preds), kb_describe(P)).

%% kb_describe(+Spec) is det.
%  Print facts for a single predicate.
%  Spec is Name/Arity (e.g., depends_on/2) or just Name (prints all arities).
kb_describe(Name/Arity) :-
    !,
    functor(Head, Name, Arity),
    format('~n--- ~w/~w ---~n', [Name, Arity]),
    forall(user:Head, format('  ~q.~n', [Head])).
kb_describe(Name) :-
    atom(Name),
    forall(
        current_predicate(user:Name/Arity),
        kb_describe(Name/Arity)
    ).

%% kb_find(+Atom) is det.
%  Print every fact that mentions Atom in any argument position.
kb_find(Atom) :-
    format('=== Facts mentioning ~w ===~n~n', [Atom]),
    user_predicates(Preds),
    forall(
        (   member(Name/Arity, Preds),
            functor(Head, Name, Arity),
            user:Head,
            term_mentions(Head, Atom)
        ),
        format('  ~q.~n', [Head])
    ).

%% kb_related(+Atom) is det.
%  Print atoms that co-occur with Atom in the same fact.
kb_related(Atom) :-
    format('=== Atoms related to ~w ===~n~n', [Atom]),
    user_predicates(Preds),
    findall(Co,
        (   member(Name/Arity, Preds),
            functor(Head, Name, Arity),
            user:Head,
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
        (   member(Name/2, Preds),
            functor(Head, Name, 2),
            user:Head,
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

pred_stats(Name/Arity) :-
    functor(Head, Name, Arity),
    predicate_property(user:Head, number_of_clauses(Count)),
    format('~w/~w  (~w clauses)~n', [Name, Arity, Count]),
    forall(between(1, Arity, Pos), arg_stats(Name, Arity, Pos)),
    nl.

arg_stats(Name, Arity, Pos) :-
    functor(Head, Name, Arity),
    findall(V, (user:Head, arg(Pos, Head, V)), Vals),
    sort(Vals, Uniq),
    length(Uniq, NU),
    (   NU =< 8
    ->  format('  arg ~w: ~w unique — ~w~n', [Pos, NU, Uniq])
    ;   length(Sample, 5),
        append(Sample, _, Uniq),
        format('  arg ~w: ~w unique — ~w ...~n', [Pos, NU, Sample])
    ).
