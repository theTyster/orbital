/**
 * run.pl — Entry point for skill invocation
 *
 * Usage:
 *   swipl -g "consult('run.pl')" -- <facts_file> [command] [args...]
 *
 * Commands:
 *   validate              — check ontology integrity
 *   summary               — system metrics
 *   describe              — full C4 tree
 *   describe <system>     — single system tree
 *   impact <component>    — impact analysis
 *   order                 — implementation order
 *   scope <comp1,comp2>   — change scope analysis
 *   chain <component>     — dependency chain from a component
 *   coupling              — container coupling
 *   crosscut              — cross-cutting concerns
 *   full                  — all analyses (no targets)
 *   full <comp1,comp2>    — all analyses with targets
 *
 * If no command is given, runs 'full'.
 */

%% Resolve module paths relative to this file, not CWD
:- prolog_load_context(directory, Dir),
   atomic_list_concat([Dir, '/ontology.pl'], OntPath),
   atomic_list_concat([Dir, '/reasoning.pl'], ResPath),
   use_module(OntPath),
   use_module(ResPath).

:- initialization(main, main).

%% Ensure depends_on/2 exists in user module even if facts file omits it
ensure_depends_on :-
    ( predicate_property(user:depends_on(_, _), defined)
    -> true
    ;  assert(user:(depends_on('$$dummy$$', '$$dummy$$'))),
       retract(user:(depends_on('$$dummy$$', '$$dummy$$')))
    ).

main :-
    current_prolog_flag(argv, Args),
    ( Args = [FactsFile|Rest]
    -> load_facts(FactsFile),
       ensure_depends_on,
       run_command(Rest)
    ;  format("ERROR: usage: swipl -g \"consult('run.pl')\" -- <facts.pl> [command] [args]~n"),
       halt(1)
    ).

load_facts(File) :-
    ( exists_file(File)
    -> consult(File)
    ;  format("ERROR: facts file '~w' not found~n", [File]),
       halt(1)
    ).

run_command([]) :- full_analysis, halt.
run_command(['validate']) :- validate_ontology, halt.
run_command(['summary']) :- system_summary, halt.
run_command(['describe']) :- describe_all, halt.
run_command(['describe', System]) :- atom_string(Sys, System), describe_system(Sys), halt.
run_command(['impact', Component]) :- atom_string(C, Component), impact_analysis(C), halt.
run_command(['order']) :- implementation_order, halt.
run_command(['scope'|CompArgs]) :- parse_comp_list(CompArgs, Comps), change_scope(Comps), halt.
run_command(['chain', Comp]) :- atom_string(C, Comp), dependency_chain(C, Chain), format("~w~n", [Chain]), halt.
run_command(['coupling']) :- container_coupling, halt.
run_command(['crosscut']) :- cross_cutting_concerns, halt.
run_command(['full']) :- full_analysis, halt.
run_command(['full'|CompArgs]) :- parse_comp_list(CompArgs, Comps), full_analysis(Comps), halt.
run_command(Unknown) :-
    format("ERROR: unknown command ~w~n", [Unknown]),
    format("Commands: validate summary describe impact order scope chain coupling crosscut full~n"),
    halt(1).

%% Parse "comp1,comp2,comp3" or "comp1 comp2 comp3" into atom list
parse_comp_list(Args, Comps) :-
    atomic_list_concat(Args, ' ', Joined),
    atomic_list_concat(Parts, ',', Joined),
    maplist(normalize_comp, Parts, Comps).

normalize_comp(Raw, Atom) :-
    atom_string(Raw, Str),
    split_string(Str, " ", " ", Parts),
    exclude(=(""), Parts, Clean),
    atomic_list_concat(Clean, '_', Atom).
