/**
 * adherence.pl — Resource adherence measurement
 *
 * Measures how well resources agree with each other using asserts/2 facts.
 *
 * Expected facts format:
 *   asserts(resource_id, claim_term).
 *
 * Usage:
 *   swipl -g "use_module('adherence'), consult('facts.pl'), adherence_report(prime_id)" -t halt
 */

:- module(adherence, [
    all_resources/1,          % -Resources: list of all resource IDs
    total_claims/2,           % +Resource, -Count
    shared_claims/3,          % +R1, +R2, -Claims
    gap_claims/3,             % +Prime, +Other, -Claims (in Prime, missing from Other)
    extension_claims/3,       % +Prime, +Other, -Claims (in Other, not in Prime)
    find_contradictions/1,    % -Contradictions: list of contradiction terms
    adherence_score/3,        % +Other, +Prime, -Score (0.0-1.0)
    jaccard_score/3,          % +R1, +R2, -Score (0.0-1.0)
    adherence_report/1,       % +Prime: print full prime-relative report
    symmetric_report/0,       % print pairwise symmetric report
    universal_claim/1         % -Claim: claims present in ALL resources
]).

%% ---- Core Predicates ----

%% all_resources(-Resources) is det.
%  List all distinct resource IDs present in asserts/2 facts.
all_resources(Resources) :-
    findall(R, asserts(R, _), Raw),
    sort(Raw, Resources).

%% total_claims(+Resource, -Count) is det.
%  Count total claims for a resource.
total_claims(Resource, Count) :-
    findall(C, asserts(Resource, C), Claims),
    length(Claims, Count).

%% shared_claims(+R1, +R2, -Claims) is det.
%  Claims present in both R1 and R2 (exact term match).
shared_claims(R1, R2, Claims) :-
    findall(C, (asserts(R1, C), asserts(R2, C)), Raw),
    sort(Raw, Claims).

%% gap_claims(+Prime, +Other, -Claims) is det.
%  Claims asserted by Prime that Other does not assert.
gap_claims(Prime, Other, Claims) :-
    findall(C, (asserts(Prime, C), \+ asserts(Other, C)), Raw),
    sort(Raw, Claims).

%% extension_claims(+Prime, +Other, -Claims) is det.
%  Claims asserted by Other that Prime does not assert.
extension_claims(Prime, Other, Claims) :-
    findall(C, (asserts(Other, C), \+ asserts(Prime, C)), Raw),
    sort(Raw, Claims).

%% universal_claim(-Claim) is nondet.
%  True for each claim asserted by every resource.
universal_claim(Claim) :-
    all_resources(Resources),
    Resources = [First|Rest],
    asserts(First, Claim),
    forall(member(R, Rest), asserts(R, Claim)).

%% find_contradictions(-Contradictions) is det.
%  Find claims where two resources assert different values for the same key.
%  Detects contradictions in claims of the form: predicate(Key, Value).
%  A contradiction is when R1 and R2 assert predicate(Key, V1) and
%  predicate(Key, V2) with V1 \= V2 — same predicate and first arg, different second arg.
find_contradictions(Contradictions) :-
    findall(
        contradiction(Pred, Key, R1-V1, R2-V2),
        (
            all_resources(Resources),
            select(R1, Resources, Rest),
            member(R2, Rest),
            R1 @< R2,  % avoid duplicates
            asserts(R1, Claim1),
            Claim1 =.. [Pred, Key, V1],
            asserts(R2, Claim2),
            Claim2 =.. [Pred, Key, V2],
            V1 \= V2
        ),
        Raw
    ),
    sort(Raw, Contradictions).

%% adherence_score(+Other, +Prime, -Score) is det.
%  Prime-relative adherence: shared / total_prime, in range 0.0-1.0.
%  Returns 1.0 if the prime has no claims (vacuously true).
adherence_score(_Other, Prime, 1.0) :-
    total_claims(Prime, 0), !.
adherence_score(Other, Prime, Score) :-
    shared_claims(Prime, Other, Shared),
    length(Shared, SharedN),
    total_claims(Prime, PrimeN),
    Score is SharedN / PrimeN.

%% jaccard_score(+R1, +R2, -Score) is det.
%  Symmetric Jaccard similarity: |intersection| / |union|, range 0.0-1.0.
%  Returns 1.0 if both have no claims.
jaccard_score(R1, R2, 1.0) :-
    total_claims(R1, 0),
    total_claims(R2, 0), !.
jaccard_score(R1, R2, Score) :-
    shared_claims(R1, R2, Shared),
    length(Shared, SharedN),
    findall(C, (asserts(R1, C) ; asserts(R2, C)), UnionRaw),
    sort(UnionRaw, Union),
    length(Union, UnionN),
    (UnionN =:= 0 -> Score = 1.0 ; Score is SharedN / UnionN).

%% ---- Reporting ----

%% adherence_report(+Prime) is det.
%  Print a full prime-relative adherence report to stdout.
adherence_report(Prime) :-
    all_resources(AllResources),
    exclude(==(Prime), AllResources, Others),
    total_claims(Prime, PrimeN),
    format('~n=== Adherence Report (Prime: ~w) ===~n~n', [Prime]),
    format('Prime claims: ~w~n~n', [PrimeN]),
    forall(member(Other, Others), print_resource_section(Prime, Other)),
    format('~n=== Universal Claims ===~n'),
    findall(C, universal_claim(C), Universal),
    length(Universal, UN),
    format('(present in all resources: ~w)~n', [UN]),
    forall(member(C, Universal), format('  ~q~n', [C])),
    format('~n=== Contradictions ===~n'),
    find_contradictions(Contradictions),
    length(Contradictions, CN),
    (CN =:= 0
    ->  format('None found.~n')
    ;   forall(member(Cont, Contradictions), print_contradiction(Cont))
    ).

print_resource_section(Prime, Other) :-
    adherence_score(Other, Prime, RawScore),
    ScorePct is round(RawScore * 1000) / 10.0,
    shared_claims(Prime, Other, Shared),
    length(Shared, SharedN),
    total_claims(Prime, PrimeN),
    gap_claims(Prime, Other, Gaps),
    length(Gaps, GapN),
    extension_claims(Prime, Other, Extensions),
    length(Extensions, ExtN),
    find_contradictions(AllContradictions),
    include(involves(Other), AllContradictions, MyContradictions),
    length(MyContradictions, ContN),
    format('--- ~w ---~n', [Other]),
    format('  Adherence:     ~w% (~w/~w shared)~n', [ScorePct, SharedN, PrimeN]),
    format('  Gaps:          ~w (in prime, missing here)~n', [GapN]),
    format('  Contradictions: ~w~n', [ContN]),
    format('  Extensions:    ~w (here, not in prime)~n~n', [ExtN]),
    (GapN > 0
    ->  format('  Gaps:~n'),
        forall(member(G, Gaps), format('    - ~q~n', [G]))
    ;   true
    ),
    (ExtN > 0
    ->  format('  Extensions:~n'),
        forall(member(E, Extensions), format('    + ~q~n', [E]))
    ;   true
    ),
    nl.

%% involves(+Resource, +Contradiction) is semidet.
%  True if Contradiction involves the given resource.
involves(R, contradiction(_, _, R-_, _)).
involves(R, contradiction(_, _, _-_, R-_)).

print_contradiction(contradiction(Pred, Key, R1-V1, R2-V2)) :-
    format('  CONFLICT ~w(~w, ?): ~w says ~q, ~w says ~q~n',
           [Pred, Key, R1, V1, R2, V2]).

%% symmetric_report is det.
%  Print pairwise Jaccard similarity for all resource pairs.
symmetric_report :-
    all_resources(Resources),
    format('~n=== Symmetric Adherence Report ===~n~n'),
    format('Resources: ~w~n~n', [Resources]),
    forall(
        (member(R1, Resources), member(R2, Resources), R1 @< R2),
        print_pair_section(R1, R2)
    ),
    format('~n=== Universal Claims ===~n'),
    findall(C, universal_claim(C), Universal),
    length(Universal, UN),
    format('(present in all resources: ~w)~n', [UN]),
    forall(member(C, Universal), format('  ~q~n', [C])),
    format('~n=== Contradictions ===~n'),
    find_contradictions(Contradictions),
    length(Contradictions, CN),
    (CN =:= 0
    ->  format('None found.~n')
    ;   forall(member(Cont, Contradictions), print_contradiction(Cont))
    ).

print_pair_section(R1, R2) :-
    jaccard_score(R1, R2, RawScore),
    ScorePct is round(RawScore * 1000) / 10.0,
    shared_claims(R1, R2, Shared),
    length(Shared, SharedN),
    total_claims(R1, N1),
    total_claims(R2, N2),
    gap_claims(R1, R2, GapsFromR1),
    length(GapsFromR1, G1N),
    gap_claims(R2, R1, GapsFromR2),
    length(GapsFromR2, G2N),
    format('--- ~w vs ~w ---~n', [R1, R2]),
    format('  Jaccard similarity: ~w%~n', [ScorePct]),
    format('  Shared claims:      ~w~n', [SharedN]),
    format('  ~w total, ~w total~n', [N1, N2]),
    format('  In ~w not ~w: ~w~n', [R1, R2, G1N]),
    format('  In ~w not ~w: ~w~n~n', [R2, R1, G2N]),
    (SharedN > 0
    ->  format('  Shared:~n'),
        forall(member(C, Shared), format('    = ~q~n', [C]))
    ;   true
    ),
    nl.
