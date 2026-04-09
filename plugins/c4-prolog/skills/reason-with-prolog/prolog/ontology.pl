/**
 * ontology.pl — C4 Model Ontology Schema (Levels 1-3)
 *
 * Defines the structural predicates for mapping a codebase
 * to the C4 architectural model. Facts are asserted in the
 * `user` module by generated facts files.
 *
 * C1 Context:   System boundaries and external actors
 * C2 Container: Deployable/runnable units within a system
 * C3 Component: Logical groupings within a container
 */
:- module(ontology, [
    % Display
    describe_system/1,
    describe_all/0,
    list_contexts/0,
    list_containers/1,
    list_components/2,

    % Queries
    components_in/2,
    files_at_level/2,
    files_for/2,
    system_for_file/2,
    container_for_file/2,
    component_for_file/2,

    % Validation
    validate_ontology/0,
    validate_ontology/1
]).

%% ============================================================
%% C1: System Context
%% context(SystemName, Description)
%%   - SystemName: atom identifying the system
%%   - Description: atom/string describing purpose
%% ============================================================

%% ============================================================
%% C2: Container
%% container(SystemName, ContainerName, Technology)
%%   - SystemName: parent context
%%   - ContainerName: atom identifying the container
%%   - Technology: atom describing the tech stack
%% ============================================================

%% ============================================================
%% C3: Component
%% component(SystemName, ContainerName, ComponentName, Responsibility)
%%   - SystemName: grandparent context
%%   - ContainerName: parent container
%%   - ComponentName: atom identifying the component
%%   - Responsibility: atom describing what it does
%% ============================================================

%% ============================================================
%% File Mapping
%% file_mapping(Level, OntologyName, FilePath)
%%   - Level: context | container | component
%%   - OntologyName: the entity this file belongs to
%%   - FilePath: absolute or project-relative path
%% ============================================================

%% ============================================================
%% Display Predicates
%% ============================================================

describe_all :-
    forall(user:context(Sys, _), describe_system(Sys)).

describe_system(System) :-
    ( user:context(System, Desc)
    -> true
    ;  format("ERROR: Unknown system '~w'~n", [System]), fail
    ),
    format("~n=== ~w ===~n", [System]),
    format("  ~w~n", [Desc]),
    ( user:file_mapping(context, System, SysPath)
    -> format("  root: ~w~n", [SysPath])
    ;  true
    ),
    forall(
        user:container(System, Container, Tech),
        describe_container(System, Container, Tech)
    ).

describe_container(System, Container, Tech) :-
    format("~n  [~w] ~w~n", [Tech, Container]),
    ( user:file_mapping(container, Container, CPath)
    -> format("    path: ~w~n", [CPath])
    ;  true
    ),
    forall(
        user:component(System, Container, Comp, Resp),
        describe_component(Comp, Resp)
    ).

describe_component(Comp, Resp) :-
    format("    - ~w: ~w~n", [Comp, Resp]),
    forall(
        user:file_mapping(component, Comp, FPath),
        format("      @ ~w~n", [FPath])
    ).

list_contexts :-
    format("~nContexts:~n"),
    forall(
        user:context(Sys, Desc),
        format("  ~w — ~w~n", [Sys, Desc])
    ).

list_containers(System) :-
    format("~nContainers in ~w:~n", [System]),
    forall(
        user:container(System, C, T),
        format("  ~w (~w)~n", [C, T])
    ).

list_components(System, Container) :-
    format("~nComponents in ~w/~w:~n", [System, Container]),
    forall(
        user:component(System, Container, Comp, Resp),
        format("  ~w — ~w~n", [Comp, Resp])
    ).

%% ============================================================
%% Query Predicates
%% ============================================================

components_in(Container, Components) :-
    findall(Comp, user:component(_, Container, Comp, _), Components).

files_at_level(Level, Files) :-
    findall(Path, user:file_mapping(Level, _, Path), Files).

files_for(EntityName, Files) :-
    findall(Path, user:file_mapping(_, EntityName, Path), Files).

system_for_file(FilePath, System) :-
    user:file_mapping(_, Entity, FilePath),
    entity_system(Entity, System),
    !.

entity_system(Entity, Entity) :- user:context(Entity, _), !.
entity_system(Entity, System) :- user:container(System, Entity, _), !.
entity_system(Entity, System) :- user:component(System, _, Entity, _).

container_for_file(FilePath, Container) :-
    user:file_mapping(component, CompName, FilePath),
    user:component(_, Container, CompName, _).

component_for_file(FilePath, Component) :-
    user:file_mapping(component, Component, FilePath).

%% ============================================================
%% Validation
%% Checks structural integrity of the ontology.
%% Every container must belong to a context.
%% Every component must belong to a container.
%% Every file_mapping must reference an existing entity.
%% ============================================================

validate_ontology :-
    validate_ontology(Warnings),
    format("~n--- Validating Ontology ---~n"),
    ( Warnings = []
    -> format("  PASS: no issues found~n")
    ;  length(Warnings, WC),
       forall(member(W, Warnings), format("  WARN: ~w~n", [W])),
       format("  ~w warning(s)~n", [WC])
    ),
    format("--- Validation Complete ---~n").

%% validate_ontology(-Warnings) — collect warnings as a list
validate_ontology(Warnings) :-
    findall(W, validation_warning(W), Warnings).

%% validation_warning(-Warning) — generates warnings on backtracking
validation_warning(orphan_container(Container, Sys)) :-
    user:container(Sys, Container, _),
    \+ user:context(Sys, _).

validation_warning(invalid_lineage(Comp, Sys, Container)) :-
    user:component(Sys, Container, Comp, _),
    ( \+ user:context(Sys, _) ; \+ user:container(Sys, Container, _) ).

validation_warning(dangling_file_mapping(Level, Name)) :-
    user:file_mapping(Level, Name, _),
    \+ mapping_target_exists(Level, Name).

validation_warning(unmapped_component(Comp)) :-
    user:component(_, _, Comp, _),
    \+ user:file_mapping(component, Comp, _).

validation_warning(phantom_dependency(Comp, Target)) :-
    user:depends_on(Comp, Target),
    \+ user:component(_, _, Target, _).

validation_warning(phantom_dependent(Comp, Source)) :-
    user:depends_on(Source, _),
    Source = Comp,
    \+ user:component(_, _, Comp, _).

validation_warning(circular_dependency(Normalized)) :-
    user:depends_on(A, B),
    path_to(B, A, [B], Cycle),
    normalize_cycle(Cycle, Normalized),
    %% Only emit from the canonical starting node to avoid duplicates
    Normalized = [A|_].

%% path_to(+From, +To, +Visited, -Path) — find path via depends_on
path_to(From, To, Visited, Path) :-
    user:depends_on(From, To),
    reverse([To|Visited], Path).
path_to(From, To, Visited, Path) :-
    user:depends_on(From, Mid),
    Mid \= To,
    \+ member(Mid, Visited),
    path_to(Mid, To, [Mid|Visited], Path).

%% Rotate cycle so lexically smallest atom is first
normalize_cycle(Cycle, Normalized) :-
    min_list_atom(Cycle, Min),
    rotate_to(Min, Cycle, Normalized).

min_list_atom([H], H).
min_list_atom([H|T], Min) :-
    min_list_atom(T, TMin),
    ( H @< TMin -> Min = H ; Min = TMin ).

rotate_to(Elem, List, Rotated) :-
    append(Before, [Elem|After], List),
    append([Elem|After], Before, Rotated),
    !.

mapping_target_exists(context, Name) :- user:context(Name, _).
mapping_target_exists(container, Name) :- user:container(_, Name, _).
mapping_target_exists(component, Name) :- user:component(_, _, Name, _).
