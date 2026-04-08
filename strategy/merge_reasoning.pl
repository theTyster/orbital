/**
 * merge_reasoning.pl — Plugin decomposition analysis
 *
 * Queries:
 *   1. Plugin cohesion — do all skills in a plugin share its concern?
 *   2. Cross-plugin coupling — which skills depend across plugin boundaries?
 *   3. Straddle detection — does any skill have capabilities in multiple domains?
 *   4. Orphan detection — any skills not assigned to a plugin?
 *   5. Decomposition summary — final verdict
 */

%% ============================================================
%% 1. Plugin Cohesion
%%    For each plugin, what concern domains do its skills touch?
%%    A cohesive plugin has skills in one (or few) domains.
%% ============================================================

plugin_cohesion :-
    format("~n=== PLUGIN COHESION ===~n"),
    forall(
        user:plugin(Plugin, Desc),
        (
            format("~n  ~w: ~w~n", [Plugin, Desc]),
            findall(Domain,
                (user:assigned_to(Skill, Plugin),
                 user:capability(Skill, Cap),
                 user:concern_domain(Cap, Domain)),
                AllDomains),
            sort(AllDomains, Domains),
            length(Domains, DC),
            format("    concern domains: ~w~n", [Domains]),
            ( DC =:= 1
            -> format("    COHESIVE — single domain~n")
            ; DC =:= 2
            -> format("    MOSTLY COHESIVE — two domains, check if secondary is minor~n")
            ; format("    WARNING: ~w domains — consider splitting~n", [DC])
            ),
            % List skills and their domains
            forall(
                user:assigned_to(Skill, Plugin),
                (
                    findall(D,
                        (user:capability(Skill, C),
                         user:concern_domain(C, D)),
                        SkillDomains),
                    sort(SkillDomains, SD),
                    format("      ~w -> ~w~n", [Skill, SD])
                )
            )
        )
    ).

%% ============================================================
%% 2. Cross-Plugin Coupling
%%    Which skills depend on skills in a different plugin?
%% ============================================================

cross_plugin_coupling :-
    format("~n=== CROSS-PLUGIN COUPLING ===~n"),
    findall(
        From-FromPlugin-To-ToPlugin,
        (user:depends_on(From, To),
         user:assigned_to(From, FromPlugin),
         user:assigned_to(To, ToPlugin),
         FromPlugin \= ToPlugin),
        Crossings),
    sort(Crossings, Unique),
    ( Unique = []
    -> format("  No cross-plugin dependencies — clean separation.~n")
    ; forall(
          member(From-FP-To-TP, Unique),
          format("  ~w (~w) -> ~w (~w)~n", [From, FP, To, TP])
      )
    ).

%% ============================================================
%% 3. Straddle Detection
%%    Skills with capabilities in multiple concern domains
%% ============================================================

straddle_detection :-
    format("~n=== STRADDLE DETECTION ===~n"),
    findall(
        Skill-Domains,
        (user:skill(Skill, _),
         findall(D,
             (user:capability(Skill, C), user:concern_domain(C, D)),
             AllD),
         sort(AllD, Domains),
         length(Domains, N),
         N > 1),
        Straddlers),
    ( Straddlers = []
    -> format("  No skills straddle multiple domains.~n")
    ; forall(
          member(Skill-Domains, Straddlers),
          (format("  ~w straddles: ~w~n", [Skill, Domains]),
           % Show which caps are in which domain
           forall(
               member(D, Domains),
               (findall(C,
                   (user:capability(Skill, C), user:concern_domain(C, D)),
                   Caps),
                format("    ~w: ~w~n", [D, Caps]))
           ))
      )
    ).

%% ============================================================
%% 4. Orphan Detection
%%    Skills not assigned to any plugin
%% ============================================================

orphan_detection :-
    format("~n=== ORPHAN DETECTION ===~n"),
    findall(Skill,
        (user:skill(Skill, _),
         \+ user:assigned_to(Skill, _)),
        Orphans),
    ( Orphans = []
    -> format("  All skills assigned.~n")
    ; format("  UNASSIGNED: ~w~n", [Orphans])
    ).

%% ============================================================
%% 5. Decomposition Summary
%% ============================================================

decomposition_summary :-
    format("~n=== DECOMPOSITION SUMMARY ===~n"),
    forall(
        user:plugin(Plugin, _),
        (
            findall(S, user:assigned_to(S, Plugin), Skills),
            length(Skills, SC),
            findall(D,
                (member(Sk, Skills),
                 user:capability(Sk, C),
                 user:concern_domain(C, D)),
                AllD),
            sort(AllD, Domains),
            format("~n  ~w (~w skills, domains: ~w)~n", [Plugin, SC, Domains]),
            forall(member(S, Skills), format("    - ~w~n", [S]))
        )
    ),
    % Cross-plugin dep count
    findall(_,
        (user:depends_on(F, T),
         user:assigned_to(F, FP),
         user:assigned_to(T, TP),
         FP \= TP),
        XDeps),
    length(XDeps, XC),
    format("~n  Cross-plugin dependencies: ~w~n", [XC]),
    ( XC =:= 0
    -> format("  VERDICT: Clean decomposition.~n")
    ; XC =< 2
    -> format("  VERDICT: Acceptable coupling — document the interfaces.~n")
    ; format("  VERDICT: High coupling — reconsider assignments.~n")
    ).

%% ============================================================
%% Entry point
%% ============================================================

run :-
    plugin_cohesion,
    cross_plugin_coupling,
    straddle_detection,
    orphan_detection,
    decomposition_summary.
