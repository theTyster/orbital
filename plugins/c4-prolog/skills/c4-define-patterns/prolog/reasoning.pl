/**
 * reasoning.pl — Stored Procedures for Ontology Analysis
 *
 * Queries that transform C4 ontology facts into structured
 * analysis output. These are the "reasoning steps" that force
 * formalization before planning.
 *
 * Each procedure prints structured output that an AI agent
 * can parse to inform implementation decisions.
 */
:- module(reasoning, [
    full_analysis/0,
    full_analysis/1,
    system_summary/0,
    impact_analysis/1,
    implementation_order/0,
    dependency_chain/2,
    change_scope/1,
    cross_cutting_concerns/0,
    container_coupling/0
]).

%% ============================================================
%% depends_on/2 — Declared in user module by facts files
%% depends_on(Dependent, Dependency)
%%   "Dependent depends on Dependency"
%% ============================================================

%% ============================================================
%% Full Analysis — convenience entry points
%% ============================================================

%% full_analysis/0 — run all analyses (no target components)
full_analysis :-
    ontology:validate_ontology,
    system_summary,
    implementation_order,
    cross_cutting_concerns,
    container_coupling.

%% full_analysis/1 — run all analyses including change scope
full_analysis(TargetComponents) :-
    ontology:validate_ontology,
    system_summary,
    change_scope(TargetComponents),
    forall(
        member(C, TargetComponents),
        impact_analysis(C)
    ),
    implementation_order,
    cross_cutting_concerns,
    container_coupling.

%% ============================================================
%% System Summary
%% High-level metrics for the entire ontology
%% ============================================================

system_summary :-
    format("~n--- SYSTEM SUMMARY ---~n"),
    aggregate_all(count, user:context(_, _), NC),
    aggregate_all(count, user:container(_, _, _), NCo),
    aggregate_all(count, user:component(_, _, _, _), NCp),
    aggregate_all(count, user:file_mapping(_, _, _), NF),
    ( predicate_property(user:depends_on(_, _), defined)
    -> aggregate_all(count, user:depends_on(_, _), ND)
    ;  ND = 0
    ),
    format("  contexts:     ~w~n", [NC]),
    format("  containers:   ~w~n", [NCo]),
    format("  components:   ~w~n", [NCp]),
    format("  file_maps:    ~w~n", [NF]),
    format("  dependencies: ~w~n", [ND]),
    % Flag potential issues
    ( NC =:= 0 -> format("  !! No contexts defined~n") ; true ),
    ( NCo =:= 0 -> format("  !! No containers defined~n") ; true ),
    ( NCp =:= 0 -> format("  !! No components defined~n") ; true ).

%% ============================================================
%% Impact Analysis
%% Given a component, show what it affects and what affects it
%% ============================================================

impact_analysis(Component) :-
    format("~n--- IMPACT: ~w ---~n", [Component]),
    % Lineage
    ( user:component(Sys, Container, Component, Resp)
    -> format("  system:    ~w~n  container: ~w~n  role:      ~w~n",
              [Sys, Container, Resp])
    ;  format("  !! Component '~w' not found in ontology~n", [Component]),
       fail
    ),
    % Files
    findall(P, user:file_mapping(component, Component, P), Paths),
    ( Paths \= []
    -> format("  files:~n"),
       forall(member(F, Paths), format("    ~w~n", [F]))
    ;  format("  files: (none mapped)~n")
    ),
    % Upstream: what this component depends on
    findall(Up, user:depends_on(Component, Up), Upstreams),
    ( Upstreams \= []
    -> format("  depends_on: ~w~n", [Upstreams])
    ;  format("  depends_on: (nothing)~n")
    ),
    % Downstream: what depends on this component
    findall(Down, user:depends_on(Down, Component), Downstreams),
    ( Downstreams \= []
    -> format("  depended_on_by: ~w~n", [Downstreams])
    ;  format("  depended_on_by: (nothing — leaf node)~n")
    ),
    % Transitive downstream
    transitive_dependents(Component, TransDeps),
    ( TransDeps \= []
    -> format("  transitive_impact: ~w~n", [TransDeps])
    ;  true
    ).

transitive_dependents(Root, AllDeps) :-
    transitive_dependents_([Root], [], AllDeps).

transitive_dependents_([], Acc, Deps) :-
    sort(Acc, Deps).
transitive_dependents_([H|T], Acc, Deps) :-
    findall(D, (user:depends_on(D, H), \+ member(D, Acc), D \= H), NewDeps),
    append(NewDeps, T, Queue),
    append(NewDeps, Acc, NewAcc),
    transitive_dependents_(Queue, NewAcc, Deps).

%% ============================================================
%% Dependency Chain
%% Trace the full dependency path from a component
%% ============================================================

dependency_chain(Start, Chain) :-
    dependency_chain_(Start, [Start], RevChain),
    reverse(RevChain, Chain).

dependency_chain_(Current, Visited, Chain) :-
    ( user:depends_on(Current, Next),
      \+ member(Next, Visited)
    -> dependency_chain_(Next, [Next|Visited], Chain)
    ;  Chain = Visited
    ).

%% ============================================================
%% Implementation Order
%% Topological sort: implement dependencies before dependents
%% ============================================================

implementation_order :-
    format("~n--- IMPLEMENTATION ORDER ---~n"),
    findall(Comp, user:component(_, _, Comp, _), AllComps),
    sort(AllComps, Unique),
    topo_sort(Unique, [], Ordered),
    print_order(Ordered, 1).

topo_sort([], Acc, Result) :- reverse(Acc, Result).
topo_sort(Remaining, Done, Result) :-
    Remaining \= [],
    include(all_deps_done(Done), Remaining, Ready),
    ( Ready = []
    -> % Cycle detected or no deps — take first remaining
       Remaining = [H|T],
       format("  !! cycle or missing dep near '~w'~n", [H]),
       topo_sort(T, [H|Done], Result)
    ;  append(Ready, Done, NewDone),
       subtract(Remaining, Ready, NewRemaining),
       topo_sort(NewRemaining, NewDone, Result)
    ).

all_deps_done(Done, Comp) :-
    findall(Dep, user:depends_on(Comp, Dep), Deps),
    subset(Deps, Done).

print_order([], _).
print_order([H|T], N) :-
    ( user:component(_, Container, H, Resp)
    -> format("  ~w. ~w  (~w — ~w)~n", [N, H, Container, Resp])
    ;  format("  ~w. ~w~n", [N, H])
    ),
    N1 is N + 1,
    print_order(T, N1).

%% ============================================================
%% Change Scope
%% Given a task description (as component list), show the
%% minimal set of files and components that need attention
%% ============================================================

change_scope(Components) :-
    format("~n--- CHANGE SCOPE ---~n"),
    format("  targets: ~w~n", [Components]),
    % Downstream: what breaks if we change these
    foldl(collect_downstream, Components, [], DownAll),
    sort(DownAll, Downstream),
    % Upstream: what these depend on (must understand before changing)
    foldl(collect_upstream, Components, [], UpAll),
    sort(UpAll, Upstream),
    % Combined unique set
    append([Components, Downstream, Upstream], Combined),
    sort(Combined, AllAffected),
    format("  upstream (must understand): ~w~n", [Upstream]),
    format("  downstream (may break):     ~w~n", [Downstream]),
    format("  total scope: ~w~n", [AllAffected]),
    % Collect all files
    foldl(collect_files, AllAffected, [], AllFiles),
    sort(AllFiles, UniqueFiles),
    format("  files_to_review:~n"),
    forall(member(F, UniqueFiles), format("    ~w~n", [F])).

collect_downstream(Comp, Acc, Result) :-
    transitive_dependents(Comp, Deps),
    append(Deps, Acc, Result).

collect_upstream(Comp, Acc, Result) :-
    transitive_dependencies(Comp, Deps),
    append(Deps, Acc, Result).

collect_files(Comp, Acc, Result) :-
    findall(F, user:file_mapping(component, Comp, F), Files),
    append(Files, Acc, Result).

%% transitive_dependencies — follow depends_on upward
transitive_dependencies(Root, AllDeps) :-
    transitive_dependencies_([Root], [], AllDeps).

transitive_dependencies_([], Acc, Deps) :- sort(Acc, Deps).
transitive_dependencies_([H|T], Acc, Deps) :-
    findall(D, (user:depends_on(H, D), \+ member(D, Acc), D \= H), NewDeps),
    append(NewDeps, T, Queue),
    append(NewDeps, Acc, NewAcc),
    transitive_dependencies_(Queue, NewAcc, Deps).

%% ============================================================
%% Cross-Cutting Concerns
%% Find components that appear as dependencies across
%% multiple containers (shared infrastructure)
%% ============================================================

cross_cutting_concerns :-
    format("~n--- CROSS-CUTTING CONCERNS ---~n"),
    findall(
        Dep-ExtContainers,
        (
            user:component(_, DepContainer, Dep, _),
            findall(
                Container,
                (
                    user:depends_on(Other, Dep),
                    user:component(_, Container, Other, _),
                    Container \= DepContainer
                ),
                Containers
            ),
            sort(Containers, ExtContainers),
            ExtContainers \= []
        ),
        Pairs
    ),
    sort(Pairs, UniquePairs),
    ( UniquePairs = []
    -> format("  (none found)~n")
    ;  forall(
           member(Dep-Containers, UniquePairs),
           (
               user:component(_, Home, Dep, _),
               length(Containers, Count),
               format("  ~w (home: ~w) used by ~w external container(s): ~w~n",
                      [Dep, Home, Count, Containers])
           )
       )
    ).

%% ============================================================
%% Container Coupling
%% Measure how tightly coupled containers are via dependencies
%% ============================================================

container_coupling :-
    format("~n--- CONTAINER COUPLING ---~n"),
    findall(
        C1-C2,
        (
            user:depends_on(Comp1, Comp2),
            user:component(_, C1, Comp1, _),
            user:component(_, C2, Comp2, _),
            C1 \= C2
        ),
        AllEdges
    ),
    sort(AllEdges, UniqueEdges),
    ( UniqueEdges = []
    -> format("  (no cross-container dependencies)~n")
    ;  forall(
           member(C1-C2, UniqueEdges),
           (
               aggregate_all(count,
                   (member(C1-C2, AllEdges)),
                   Weight),
               format("  ~w -> ~w  (~w component edge(s))~n", [C1, C2, Weight])
           )
       )
    ).
