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
    subsumed_shared_claims/3, % +Prime, +Other, -Claims (fuzzy via subsumes_term/2)
    gap_claims/3,             % +Prime, +Other, -Claims (in Prime, missing from Other)
    gaps_by_category/3,       % +Prime, +Other, -CategoryGaps (Cat-Gaps pairs)
    silent_gaps/3,            % +Prime, +Other, -Claims (gap with no matching key in Other)
    conflicting_gaps/3,       % +Prime, +Other, -Claims (gap whose key has conflicting value in Other)
    extension_claims/3,       % +Prime, +Other, -Claims (in Other, not in Prime)
    canonicalize_claim/2,     % +Raw, -Canonical (strings -> atoms, fail if non-ground)
    find_contradictions/1,    % -Contradictions: list of contradiction terms
    adherence_score/3,        % +Other, +Prime, -Score (0.0-1.0); fails if Prime empty
    weighted_adherence_score/3, % +Other, +Prime, -Score (weighted by claim_weight/2)
    jaccard_score/3,          % +R1, +R2, -Score (0.0-1.0); fails if both empty
    adherence_report/1,       % +Prime: print full prime-relative report
    symmetric_report/0,       % print pairwise symmetric report
    universal_claim/1,        % -Claim: claims present in ALL resources
    adherence_facts_out/2,    % +Prime, +Stream: emit machine-readable result/N facts
    adherence_or_fail/2,      % +Prime, +Threshold: halt(1) if any score < Threshold
    main/0,                   % CLI entry point: --threshold N [--threshold-for R=N]* facts.pl prime
    claim/2,                  % ?Resource, ?Claim
    claim/3,                  % ?Resource, ?Category, ?Claim
    hypothesis_loaded/0,        % semidet: succeeds when hypothesis.pl predicates are visible
    counterfactual_violations/2, % +ImplResource, -Violations (Pattern 3: forbidden fact still present)
    counterfactual_honored/2,    % +ImplResource, -Honored (forbidden fact correctly absent)
    prescriptive_unfulfilled/2,  % +ImplResource, -Unfulfilled (required fact missing)
    prescriptive_fulfilled/2,    % +ImplResource, -Fulfilled (required fact present)
    prescriptive_negation_violations/2, % +ImplResource, -Violations (¬premise of prescriptive still present)
    descriptive_drift/3,         % +ImplResource, +ExistingResource, -Lost (descriptive facts no longer present)
    label_aware_report/1,        % +ImplResource: print per-epistemic-label section
    label_aware_facts_out/2      % +ImplResource, +Stream: emit machine-readable result/N facts
]).

:- use_module(library(ordsets)).
:- use_module(library(pairs)).
:- use_module(library(assoc)).

%% ---- Display configuration ----

%% max_items_per_section(-N) is det.
%  Cap on how many gap or extension claims a reporter prints per section.
%  When the underlying list is longer, the reporter emits the first N items
%  followed by a '… and K more' tail. Override by reconsulting with a
%  different clause; default is 50.
:- multifile max_items_per_section/1.
max_items_per_section(50).

%% print_capped(+Items, +Prefix) is det.
%  Print up to max_items_per_section/1 items with the given prefix string,
%  appending a '… and N more' tail when truncated.
print_capped(Items, Prefix) :-
    once(max_items_per_section(Cap)),
    length(Items, Total),
    (   Total =< Cap
    ->  forall(member(X, Items), format('    ~w ~q~n', [Prefix, X]))
    ;   length(Head, Cap),
        append(Head, Tail, Items),
        length(Tail, More),
        forall(member(X, Head), format('    ~w ~q~n', [Prefix, X])),
        format('    ... and ~w more~n', [More])
    ).

%% ---- Module-aware claim lookup ----

%% claims_module(-M) is nondet.
%  Modules that may hold asserts/2 or asserts/3 clauses. Includes `user`
%  plus any module loaded from a file outside SWI's installation tree that
%  has clauses for asserts/2 or asserts/3. Mirrors introspect.pl's
%  kb_module/1 pattern.
claims_module(user).
claims_module(M) :-
    current_module(M),
    M \== user,
    M \== adherence,
    module_property(M, file(F)),
    \+ system_file(F),
    once(( module_has_asserts(M, 2) ; module_has_asserts(M, 3) )).

module_has_asserts(M, Arity) :-
    current_predicate(M:asserts/Arity),
    functor(Head, asserts, Arity),
    \+ predicate_property(M:Head, imported_from(_)),
    predicate_property(M:Head, number_of_clauses(N)), N > 0.

%% system_file(+File) is semidet.
system_file(F) :-
    current_prolog_flag(home, Home),
    sub_atom(F, 0, _, _, Home).

%% claim(?R, ?C) is nondet.
%  Resolve asserts/2 and asserts/3 across every claims_module/1,
%  canonicalizing each claim on read. Non-ground claims emit a warning
%  and are skipped. The 2-arg form is treated as category `general`.
claim(R, C) :-
    claim(R, _Category, C).

%% claim(?R, ?Category, ?C) is nondet.
%  Categorized variant. asserts/2 facts produce category `general`;
%  asserts/3 facts carry their declared category.
claim(R, Category, C) :-
    claims_module(M),
    raw_assert(M, R, Category, Raw),
    (   canonicalize_claim(Raw, C)
    ->  true
    ;   print_message(warning,
                      format('adherence: skipping non-ground claim from ~w: ~q',
                             [R, Raw])),
        fail
    ).

%% raw_assert(+M, -R, -Category, -Raw) is nondet.
%  Pull a raw claim from either asserts/2 (category=general) or asserts/3
%  in module M. Guards each call with current_predicate/1 so modules that
%  define only one arity don't trip an existence error.
raw_assert(M, R, general, Raw) :-
    current_predicate(M:asserts/2),
    M:asserts(R, Raw).
raw_assert(M, R, Category, Raw) :-
    current_predicate(M:asserts/3),
    M:asserts(R, Category, Raw).

%% canonicalize_claim(+Raw, -Canonical) is semidet.
%  Normalize a claim term: convert any string arguments to atoms (recursively
%  through compound args). Fails if the claim is not ground (a non-ground
%  claim could unify with anything during set ops, which is unsafe).
canonicalize_claim(Raw, Canonical) :-
    ground(Raw),
    canon_term(Raw, Canonical).

canon_term(T, A) :-
    string(T), !,
    atom_string(A, T).
canon_term(T, T) :-
    ( atom(T) ; number(T) ), !.
canon_term(T, C) :-
    compound(T), !,
    T =.. [F|Args],
    maplist(canon_term, Args, CanonArgs),
    C =.. [F|CanonArgs].
canon_term(T, T).

%% ---- Core Predicates ----

%% all_resources(-Resources) is det.
all_resources(Resources) :-
    findall(R, claim(R, _), Raw),
    sort(Raw, Resources).

%% total_claims(+Resource, -Count) is det.
total_claims(Resource, Count) :-
    findall(C, claim(Resource, C), Claims),
    sort(Claims, Uniq),
    length(Uniq, Count).

%% claims_set(+Resource, -SortedClaims) is det.
%  Sorted (ordset) list of all claims for Resource.
claims_set(Resource, Sorted) :-
    findall(C, claim(Resource, C), Raw),
    sort(Raw, Sorted).

%% shared_claims(+R1, +R2, -Claims) is det.
shared_claims(R1, R2, Claims) :-
    claims_set(R1, S1),
    claims_set(R2, S2),
    ord_intersection(S1, S2, Claims).

%% subsumed_shared_claims(+Prime, +Other, -Claims) is det.
%  Fuzzy shared-claims: a Prime claim P counts as covered when Other has
%  some claim O with subsumes_term(P, O) — i.e. P is more general (has
%  variables) and O is an instance. Asymmetric on purpose: the prime side
%  is read raw (variables permitted) while Other goes through canonicalized
%  claim/2.
subsumed_shared_claims(Prime, Other, Claims) :-
    findall(P, raw_prime_claim(Prime, P), PrimeRaw),
    sort(PrimeRaw, PrimeClaims),
    claims_set(Other, OtherClaims),
    include(subsumed_in(OtherClaims), PrimeClaims, Claims).

subsumed_in(Set, P) :-
    member(O, Set),
    \+ \+ subsumes_term(P, O),
    !.

%% raw_prime_claim(+Prime, -Claim) is nondet.
%  Like claim/2 but without canonicalization or ground-check, so wildcards
%  in the prime survive. Strings are still folded to atoms recursively to
%  keep matching consistent with the canonical Other side.
raw_prime_claim(Prime, Claim) :-
    claims_module(M),
    raw_assert(M, Prime, _Cat, Raw),
    canon_term(Raw, Claim).

%% gap_claims(+Prime, +Other, -Claims) is det.
%  Union of silent and conflicting gaps. Kept for backward compatibility.
gap_claims(Prime, Other, Claims) :-
    silent_gaps(Prime, Other, Silent),
    conflicting_gaps(Prime, Other, Conflicting),
    ord_union(Silent, Conflicting, Claims).

%% gaps_by_category(+Prime, +Other, -CategoryGaps) is det.
%  Group gap_claims/3 output by the Prime-side category of each claim.
%  Result is a sorted list of `Category-GapList` pairs. A claim that
%  appears under multiple categories on the Prime side is reported under
%  each. Resources whose claims are all 2-arg `asserts/2` will produce a
%  single `general-Gaps` pair.
gaps_by_category(Prime, Other, CategoryGaps) :-
    gap_claims(Prime, Other, Gaps),
    findall(Cat-C,
            ( member(C, Gaps),
              once(claim(Prime, Cat, C))
            ),
            Pairs),
    keysort(Pairs, Sorted),
    group_pairs_by_key(Sorted, CategoryGaps).

%% silent_gaps(+Prime, +Other, -Claims) is det.
%  Claims in Prime that have NO matching key in Other (Other says nothing
%  about that functor/arg-pattern). A "key" matches when functor and arity
%  agree and the two claims differ in at most one argument position.
silent_gaps(Prime, Other, Claims) :-
    claims_set(Prime, SP),
    claims_set(Other, SO),
    ord_subtract(SP, SO, Missing),
    include(no_key_match_in(SO), Missing, Claims).

no_key_match_in(Set, Claim) :- \+ has_key_match(Claim, Set).

%% conflicting_gaps(+Prime, +Other, -Claims) is det.
%  Claims in Prime whose key IS present in Other but with a differing value
%  (i.e., Other has a claim same-functor/arity differing in exactly one arg).
conflicting_gaps(Prime, Other, Claims) :-
    claims_set(Prime, SP),
    claims_set(Other, SO),
    ord_subtract(SP, SO, Missing),
    include(key_match_in(SO), Missing, Claims).

key_match_in(Set, Claim) :- has_key_match(Claim, Set).

%% has_key_match(+Claim, +ClaimSet) is semidet.
%  True when ClaimSet contains a claim sharing functor/arity with Claim that
%  differs in exactly one argument position (matching the contradiction
%  definition). Arity-0 claims have no possible key match.
has_key_match(Claim, Set) :-
    functor(Claim, F, A),
    A > 0,
    member(Other, Set),
    functor(Other, F, A),
    Claim \== Other,
    findall(P,
        (between(1, A, P), arg(P, Claim, V1), arg(P, Other, V2), V1 \== V2),
        [_]),
    !.

%% extension_claims(+Prime, +Other, -Claims) is det.
extension_claims(Prime, Other, Claims) :-
    claims_set(Prime, SP),
    claims_set(Other, SO),
    ord_subtract(SO, SP, Claims).

%% universal_claim(-Claim) is nondet.
universal_claim(Claim) :-
    all_resources(Resources),
    Resources = [First|Rest],
    claim(First, Claim),
    forall(member(R, Rest), claim(R, Claim)).

%% find_contradictions(-Contradictions) is det.
%  Two claims contradict when their functor/arity match and they agree on
%  all arguments except exactly one position. Yields:
%    contradiction(Pred/Arity, DiffPos, R1-Claim1, R2-Claim2)
find_contradictions(Contradictions) :-
    findall(
        contradiction(F/A, DiffPos, R1-Claim1, R2-Claim2),
        contradicting_pair(R1, Claim1, R2, Claim2, F, A, DiffPos),
        Raw
    ),
    sort(Raw, Contradictions).

contradicting_pair(R1, Claim1, R2, Claim2, F, A, DiffPos) :-
    claim(R1, Claim1),
    claim(R2, Claim2),
    R1 @< R2,
    functor(Claim1, F, A),
    functor(Claim2, F, A),
    A > 0,
    Claim1 \== Claim2,
    findall(P,
        (between(1, A, P), arg(P, Claim1, V1), arg(P, Claim2, V2), V1 \== V2),
        [DiffPos]).

%% adherence_score(+Other, +Prime, -Score) is semidet.
%  Prime-relative adherence: shared / total_prime, in range 0.0-1.0.
%  Fails when prime has zero claims (caller must handle).
adherence_score(Other, Prime, Score) :-
    total_claims(Prime, PrimeN),
    PrimeN > 0,
    shared_claims(Prime, Other, Shared),
    length(Shared, SharedN),
    Score is SharedN / PrimeN.

%% claim_weight(?Claim, ?Weight) is nondet.
%  Optional per-claim weight, supplied by the user via multifile clauses
%  declared in `user` or any module loaded outside SWI's installation tree.
%  Defaults to 1.0 when no clause matches a given claim.
:- multifile user:claim_weight/2.

%% claim_weight_for(+Claim, -Weight) is det.
%  Lookup with default 1.0 when no claim_weight/2 clause matches in any
%  visible module.
claim_weight_for(Claim, Weight) :-
    (   weight_lookup(Claim, W)
    ->  Weight = W
    ;   Weight = 1.0
    ).

weight_lookup(Claim, W) :-
    user:claim_weight(Claim, W), !.
weight_lookup(Claim, W) :-
    claims_module(M),
    M \== user,
    current_predicate(M:claim_weight/2),
    M:claim_weight(Claim, W), !.

%% weighted_adherence_score(+Other, +Prime, -Score) is semidet.
%  Weighted prime-relative adherence. For each shared claim, sum
%  claim_weight/2 (default 1.0); divide by the total weight of all
%  Prime claims. Fails when prime has zero claims or zero total weight.
weighted_adherence_score(Other, Prime, Score) :-
    claims_set(Prime, PrimeClaims),
    PrimeClaims \== [],
    sum_weights(PrimeClaims, PrimeW),
    PrimeW > 0,
    shared_claims(Prime, Other, Shared),
    sum_weights(Shared, SharedW),
    Score is SharedW / PrimeW.

sum_weights(Claims, Total) :-
    foldl(add_weight, Claims, 0, Total).

add_weight(Claim, Acc, New) :-
    claim_weight_for(Claim, W),
    New is Acc + W.

%% jaccard_score(+R1, +R2, -Score) is semidet.
%  Symmetric Jaccard. Fails when both R1 and R2 have zero claims.
jaccard_score(R1, R2, Score) :-
    claims_set(R1, S1),
    claims_set(R2, S2),
    ord_union(S1, S2, Union),
    length(Union, UnionN),
    UnionN > 0,
    ord_intersection(S1, S2, Inter),
    length(Inter, InterN),
    Score is InterN / UnionN.

%% ---- Reporting ----

%% adherence_report(+Prime) is det.
adherence_report(Prime) :-
    all_resources(AllResources),
    exclude(==(Prime), AllResources, Others),
    total_claims(Prime, PrimeN),
    find_contradictions(AllContradictions),
    format('~n=== Adherence Report (Prime: ~w) ===~n~n', [Prime]),
    format('Prime claims: ~w~n~n', [PrimeN]),
    forall(member(Other, Others),
           print_resource_section(Prime, Other, AllContradictions)),
    format('~n=== Universal Claims ===~n'),
    print_universals(AllResources),
    format('~n=== Contradictions ===~n'),
    length(AllContradictions, CN),
    (CN =:= 0
    ->  format('None found.~n')
    ;   forall(member(Cont, AllContradictions), print_contradiction(Cont))
    ).

print_resource_section(Prime, Other, AllContradictions) :-
    shared_claims(Prime, Other, Shared),
    length(Shared, SharedN),
    total_claims(Prime, PrimeN),
    silent_gaps(Prime, Other, Silent),
    length(Silent, SilentN),
    conflicting_gaps(Prime, Other, Conflicting),
    length(Conflicting, ConflictN),
    extension_claims(Prime, Other, Extensions),
    length(Extensions, ExtN),
    include(involves(Other), AllContradictions, MyContradictions),
    length(MyContradictions, ContN),
    format('--- ~w ---~n', [Other]),
    (   adherence_score(Other, Prime, RawScore)
    ->  ScorePct is round(RawScore * 1000) / 10.0,
        format('  Adherence:     ~w% (~w/~w shared)~n', [ScorePct, SharedN, PrimeN])
    ;   format('  Adherence:     n/a (prime has no claims)~n')
    ),
    format('  Silent gaps:     ~w (no matching key in ~w)~n', [SilentN, Other]),
    format('  Conflicting gaps: ~w (key present in ~w, value differs)~n', [ConflictN, Other]),
    format('  Contradictions:  ~w~n', [ContN]),
    format('  Extensions:      ~w (here, not in prime)~n~n', [ExtN]),
    gaps_by_category(Prime, Other, CatGaps),
    (   has_nongeneral_category(CatGaps)
    ->  print_categorized_gaps(CatGaps, Silent, Conflicting)
    ;   (SilentN > 0
        ->  format('  Silent gaps:~n'),
            print_capped(Silent, '-')
        ;   true
        ),
        (ConflictN > 0
        ->  format('  Conflicting gaps:~n'),
            print_capped(Conflicting, '~')
        ;   true
        )
    ),
    (ExtN > 0
    ->  format('  Extensions:~n'),
        print_capped(Extensions, '+')
    ;   true
    ),
    nl.

%% has_nongeneral_category(+CatGaps) is semidet.
has_nongeneral_category(CatGaps) :-
    member(Cat-_, CatGaps),
    Cat \== general,
    !.

%% print_categorized_gaps(+CatGaps, +Silent, +Conflicting) is det.
%  Emit one block per category, splitting each into silent vs conflicting.
print_categorized_gaps(CatGaps, Silent, Conflicting) :-
    list_to_ord_set(Silent, SilentSet),
    list_to_ord_set(Conflicting, ConflictSet),
    forall(member(Cat-Gaps, CatGaps),
           print_category_block(Cat, Gaps, SilentSet, ConflictSet)).

print_category_block(Cat, Gaps, SilentSet, ConflictSet) :-
    list_to_ord_set(Gaps, GapSet),
    ord_intersection(GapSet, SilentSet, CatSilent),
    ord_intersection(GapSet, ConflictSet, CatConflict),
    length(CatSilent, SN),
    length(CatConflict, CN),
    format('  [~w] silent: ~w, conflicting: ~w~n', [Cat, SN, CN]),
    (   SN > 0
    ->  format('    Silent gaps:~n'),
        print_capped(CatSilent, '-')
    ;   true
    ),
    (   CN > 0
    ->  format('    Conflicting gaps:~n'),
        print_capped(CatConflict, '~')
    ;   true
    ).

%% involves(+Resource, +Contradiction) is semidet.
involves(R, contradiction(_, _, R-_, _)).
involves(R, contradiction(_, _, _, R-_)).

%% involves_pair(+R1, +R2, +Contradiction) is semidet.
%  Contradictions are emitted with @< ordering on resources, so the pair
%  appears in (R1, R2) order whenever R1 @< R2.
involves_pair(R1, R2, contradiction(_, _, R1-_, R2-_)).

print_contradiction(contradiction(_F/2, 2, R1-Claim1, R2-Claim2)) :-
    !,
    Claim1 =.. [Pred, Key, V1],
    Claim2 =.. [Pred, _, V2],
    format('  CONFLICT ~w(~w, ?): ~w says ~q, ~w says ~q~n',
           [Pred, Key, R1, V1, R2, V2]).
print_contradiction(contradiction(F/A, DiffPos, R1-Claim1, R2-Claim2)) :-
    format('  CONFLICT ~w/~w (arg ~w differs): ~w asserts ~q; ~w asserts ~q~n',
           [F, A, DiffPos, R1, Claim1, R2, Claim2]).

%% symmetric_report is det.
symmetric_report :-
    all_resources(Resources),
    find_contradictions(AllContradictions),
    empty_assoc(EmptyCache),
    setup_call_cleanup(
        nb_setval(adherence_pair_cache, EmptyCache),
        ( format('~n=== Symmetric Adherence Report ===~n~n'),
          format('Resources: ~w~n~n', [Resources]),
          forall(
              (member(R1, Resources), member(R2, Resources), R1 @< R2),
              print_pair_section(R1, R2, AllContradictions)
          ),
          format('~n=== Universal Claims ===~n'),
          print_universals(Resources),
          format('~n=== Contradictions ===~n'),
          length(AllContradictions, CN),
          (CN =:= 0
          ->  format('None found.~n')
          ;   forall(member(Cont, AllContradictions), print_contradiction(Cont))
          )
        ),
        nb_delete(adherence_pair_cache)
    ).

%% pair_cache_get(+R1, +R2, -Entry) is det.
%  Memoize per-pair stats for the duration of one symmetric_report/0 call.
%  Entry is a dict with keys: shared, silent12, conflict12, silent21,
%  conflict21, n1, n2. Pairs are keyed by sorted resource names so the
%  cache is order-insensitive.
pair_cache_get(R1, R2, Entry) :-
    sort([R1, R2], [A, B]),
    Key = A-B,
    (   nb_current(adherence_pair_cache, Cache),
        get_assoc(Key, Cache, Hit)
    ->  Entry = Hit
    ;   shared_claims(A, B, Shared),
        silent_gaps(A, B, Silent12),
        conflicting_gaps(A, B, Conflict12),
        silent_gaps(B, A, Silent21),
        conflicting_gaps(B, A, Conflict21),
        total_claims(A, NA),
        total_claims(B, NB),
        Built = entry(A, B, Shared, Silent12, Conflict12, Silent21, Conflict21, NA, NB),
        (   nb_current(adherence_pair_cache, C0)
        ->  put_assoc(Key, C0, Built, C1),
            nb_setval(adherence_pair_cache, C1)
        ;   true
        ),
        Entry = Built
    ).

%% print_universals(+Resources) is det.
%  Print the Universal Claims section, distinguishing the no-resources case
%  from the resources-disagree case.
print_universals([]) :-
    !,
    format('(no resources loaded)~n').
print_universals(_) :-
    findall(C, universal_claim(C), UniversalRaw),
    sort(UniversalRaw, Universal),
    length(Universal, UN),
    (   UN =:= 0
    ->  format('(none: resources loaded but no claim is shared by all)~n')
    ;   format('(present in all resources: ~w)~n', [UN]),
        forall(member(C, Universal), format('  ~q~n', [C]))
    ).

print_pair_section(R1, R2, AllContradictions) :-
    pair_cache_get(R1, R2, E),
    E = entry(A, _B, Shared, Silent12, Conflict12, Silent21, Conflict21, NA, NB),
    length(Shared, SharedN),
    %  Cache stores gaps from A->B where [A,B] = sort([R1,R2]). Map back.
    (   R1 == A
    ->  SilentR1 = Silent12, ConflictR1 = Conflict12,
        SilentR2 = Silent21, ConflictR2 = Conflict21,
        N1 = NA, N2 = NB
    ;   SilentR1 = Silent21, ConflictR1 = Conflict21,
        SilentR2 = Silent12, ConflictR2 = Conflict12,
        N1 = NB, N2 = NA
    ),
    length(SilentR1, S1N),
    length(ConflictR1, C1N),
    length(SilentR2, S2N),
    length(ConflictR2, C2N),
    include(involves_pair(R1, R2), AllContradictions, PairContradictions),
    length(PairContradictions, ContN),
    format('--- ~w vs ~w ---~n', [R1, R2]),
    (   jaccard_score(R1, R2, RawScore)
    ->  ScorePct is round(RawScore * 1000) / 10.0,
        format('  Jaccard similarity: ~w%~n', [ScorePct])
    ;   format('  Jaccard similarity: n/a (both empty)~n')
    ),
    format('  Shared claims:      ~w~n', [SharedN]),
    format('  Contradictions:     ~w~n', [ContN]),
    format('  ~w: ~w claims; ~w: ~w claims~n', [R1, N1, R2, N2]),
    format('  In ~w not ~w: ~w silent, ~w conflicting~n', [R1, R2, S1N, C1N]),
    format('  In ~w not ~w: ~w silent, ~w conflicting~n~n', [R2, R1, S2N, C2N]),
    (SharedN > 0
    ->  format('  Shared:~n'),
        print_capped(Shared, '=')
    ;   true
    ),
    nl.

%% ---- Machine-readable output ----

%% adherence_facts_out(+Prime, +Stream) is det.
%  Emit result/N facts to Stream covering scores, shared/gap/extension,
%  contradictions, universal claims, and totals.
adherence_facts_out(Prime, Stream) :-
    all_resources(AllResources),
    exclude(==(Prime), AllResources, Others),
    forall(member(Other, Others),
           emit_adherence(Stream, Prime, Other)),
    forall(
        (member(R1, AllResources), member(R2, AllResources), R1 @< R2),
        emit_pair(Stream, R1, R2)
    ),
    forall(member(Other, Others),
           emit_gaps_extensions(Stream, Prime, Other)),
    once(find_contradictions(Contradictions)),
    forall(member(C, Contradictions), emit_contradiction(Stream, C)),
    findall(U, universal_claim(U), UniRaw),
    sort(UniRaw, Universal),
    forall(member(U, Universal), emit_term(Stream, result(universal, U))),
    forall(member(R, AllResources), emit_total(Stream, R)).

emit_adherence(Stream, Prime, Other) :-
    (   adherence_score(Other, Prime, Score)
    ->  emit_term(Stream, result(adherence, Other, Prime, Score))
    ;   true
    ).

emit_pair(Stream, R1, R2) :-
    (   jaccard_score(R1, R2, JScore)
    ->  emit_term(Stream, result(jaccard, R1, R2, JScore))
    ;   true
    ),
    shared_claims(R1, R2, Shared),
    length(Shared, SharedN),
    emit_term(Stream, result(shared, R1, R2, SharedN)).

emit_gaps_extensions(Stream, Prime, Other) :-
    gap_claims(Prime, Other, Gaps),
    forall(member(G, Gaps), emit_term(Stream, result(gap, Prime, Other, G))),
    extension_claims(Prime, Other, Extensions),
    forall(member(E, Extensions),
           emit_term(Stream, result(extension, Prime, Other, E))).

emit_contradiction(Stream, contradiction(F/A, DiffPos, R1-C1, R2-C2)) :-
    emit_term(Stream, result(contradiction, F/A, DiffPos, R1-C1, R2-C2)).

emit_total(Stream, Resource) :-
    total_claims(Resource, N),
    emit_term(Stream, result(total, Resource, N)).

emit_term(Stream, Term) :-
    writeq(Stream, Term),
    write(Stream, '.'),
    nl(Stream).

%% adherence_or_fail(+Prime, +Threshold) is det.
%  halt(1) if any non-prime resource has adherence below its threshold.
%  Threshold may be:
%    - a number: applied uniformly to every non-prime resource
%    - a list of `Resource-Threshold` pairs: per-resource thresholds; any
%      resource missing from the list uses the value bound to the atom
%      `default` (defaults to 0.0 if no `default-N` entry is present).
adherence_or_fail(Prime, Threshold) :-
    all_resources(AllResources),
    exclude(==(Prime), AllResources, Others),
    threshold_for(Threshold, default, DefaultT),
    findall(Other-Score-T,
        (member(Other, Others),
         threshold_for(Threshold, Other, T0),
         (T0 == none -> T = DefaultT ; T = T0),
         adherence_score(Other, Prime, Score),
         Score < T),
        Failures),
    (   Failures == []
    ->  describe_threshold(Threshold, Desc),
        format('OK: all resources meet ~w adherence to ~w~n', [Desc, Prime])
    ;   describe_threshold(Threshold, Desc),
        format('FAIL: resources below ~w adherence to ~w:~n', [Desc, Prime]),
        forall(member(R-S-T, Failures),
               format('  ~w: ~w (threshold ~w)~n', [R, S, T])),
        halt(1)
    ).

%% threshold_for(+Threshold, +Resource, -T) is det.
%  When Threshold is numeric, every resource resolves to it. When Threshold
%  is a list of Resource-Value pairs, look up the resource (or `default`)
%  and return `none` for misses so the caller can apply a fallback.
threshold_for(N, _, N) :- number(N), !.
threshold_for(List, R, T) :-
    is_list(List), !,
    (   memberchk(R-T0, List)
    ->  T = T0
    ;   T = none
    ).

describe_threshold(N, Atom) :-
    number(N), !,
    format(atom(Atom), '>= ~w', [N]).
describe_threshold(List, 'per-resource thresholds') :-
    is_list(List), !.
describe_threshold(_, 'unknown threshold').

%% ---- CLI entry point ----

%% main is det.
%  Shell-callable entry:
%    swipl -q -g main -t halt adherence.pl -- \
%        --threshold 0.8 [--threshold-for R=0.95]* facts.pl prime
%  Exits 0 when all resources meet their thresholds, 1 otherwise.
main :-
    current_prolog_flag(argv, Argv),
    parse_cli_args(Argv, Opts, Positional),
    (   Positional = [FactsFile, PrimeArg]
    ->  atom_string(Prime, PrimeArg),
        user:consult(FactsFile),
        build_threshold(Opts, Threshold),
        adherence_or_fail(Prime, Threshold)
    ;   format(user_error,
               'usage: --threshold N [--threshold-for R=N]* FACTS.pl PRIME~n', []),
        halt(2)
    ).

parse_cli_args([], opts(none, []), []).
parse_cli_args(['--threshold', N | Rest], opts(NumT, PerR), Pos) :-
    !,
    atom_number(N, NumT),
    parse_cli_args(Rest, opts(_, PerR), Pos).
parse_cli_args(['--threshold-for', Spec | Rest], opts(NumT, [R-V | PerR]), Pos) :-
    !,
    split_string(Spec, "=", "", [RS, VS]),
    atom_string(R, RS),
    number_string(V, VS),
    parse_cli_args(Rest, opts(NumT, PerR), Pos).
parse_cli_args([Arg | Rest], Opts, [Arg | Pos]) :-
    parse_cli_args(Rest, Opts, Pos).

build_threshold(opts(NumT, []), NumT) :-
    number(NumT), !.
build_threshold(opts(NumT, PerR), List) :-
    PerR \== [], !,
    (   number(NumT)
    ->  List = [default-NumT | PerR]
    ;   List = PerR
    ).
build_threshold(opts(none, []), 0.0).

%% ---- Label-aware verdicts (consume hypothesis.pl) ----
%
% These predicates close the Pattern 3 gap from
% philosophy/cwa-owa-tension.md. The standard adherence machinery scores
% facts as "shared / gap / contradiction / extension" without knowing which
% facts the upstream hypothesis declared had to FLIP. Pattern 3 is the case
% where a counterfactual obligation went unhonored: the implementation still
% asserts a fact the hypothesis said had to become false. Without label
% awareness, that fact appears as a benign "extension" of impl over the
% prime — which it is not.
%
% The predicates below read hypothesis.pl directly, alongside
% adherence_facts.pl. The hypothesis predicates (claim_label/2,
% claim_premise/2, claim_negation_provenance/3) come from the user module
% when hypothesis.pl is consulted via `swipl -g "..." thoughts/hypothesis.pl`
% or an explicit consult/1 call from the runner.
%
% Domain conventions, per references/pipeline-schema/hypothesis.md:
%   - claim_label(C, counterfactual) + claim_premise(C, F) +
%     claim_negation_provenance(C, F, _) → F must be ABSENT in impl.
%   - claim_label(C, prescriptive) + claim_premise(C, F)
%     (no claim_negation_provenance) → F must be PRESENT in impl.
%   - claim_label(C, prescriptive) + claim_premise(C, F) +
%     claim_negation_provenance(C, F, _) → F must be ABSENT in impl
%     (a prescriptive claim with a negated premise).
%   - claim_label(C, descriptive) → no fact-level encoding in hypothesis;
%     drift is detected only when existing-world.pl is supplied as a
%     separate resource.

%% hypothesis_loaded is semidet.
%  Succeed when the hypothesis facts are visible — i.e., hypothesis.pl
%  was consulted into a module reachable from `user`. Used as a guard so
%  stand-alone runs (no hypothesis.pl) skip the label-aware section
%  silently rather than erroring.
hypothesis_loaded :-
    current_predicate(user:claim_label/2),
    once(user:claim_label(_, _)).

%% canonical_premise(+ClaimId, -CanonFact, -RawFact) is nondet.
%  Yield each ground claim_premise/2 fact with both its raw and canonical
%  forms. Canonicalisation matches what `claim/2` does on the asserts/2
%  side, so a hypothesis premise written with strings still matches an
%  impl fact written with atoms.
canonical_premise(ClaimId, CanonFact, RawFact) :-
    user:claim_premise(ClaimId, RawFact),
    canonicalize_claim(RawFact, CanonFact).

%% impl_claim_set(+ImplResource, -Set) is det.
%  Compute the impl resource's canonical claim set once. Used by the
%  label-aware predicates so each hypothesis-claim membership check is a
%  cheap memberchk on a sorted list rather than a backtracking call to
%  claim/2 (which warns spuriously when the second argument is bound to a
%  fact that doesn't match the next raw_assert/4 row — the warning would
%  mislead a reader, and the cost of a cleaner membership check is
%  negligible).
impl_claim_set(ImplResource, Set) :-
    claims_set(ImplResource, Set).

%% counterfactual_violations(+ImplResource, -Violations) is det.
%  Pattern 3 detector. A violation is a counterfactual claim whose
%  forbidden premise still appears in ImplResource. Emits
%  violation(ClaimId, Fact, Provenance) terms; sorted, deduplicated.
%  Returns [] when hypothesis.pl is not loaded.
counterfactual_violations(ImplResource, Violations) :-
    (   hypothesis_loaded
    ->  impl_claim_set(ImplResource, ImplSet),
        findall(violation(ClaimId, CanonFact, Provenance),
            ( user:claim_label(ClaimId, counterfactual),
              canonical_premise(ClaimId, CanonFact, RawFact),
              user:claim_negation_provenance(ClaimId, RawFact, Provenance),
              memberchk(CanonFact, ImplSet)
            ),
            Raw),
        sort(Raw, Violations)
    ;   Violations = []
    ).

%% counterfactual_honored(+ImplResource, -Honored) is det.
%  The complementary check: counterfactual claims whose forbidden premise
%  is correctly absent from ImplResource. Emits honored/3 terms.
counterfactual_honored(ImplResource, Honored) :-
    (   hypothesis_loaded
    ->  impl_claim_set(ImplResource, ImplSet),
        findall(honored(ClaimId, CanonFact, Provenance),
            ( user:claim_label(ClaimId, counterfactual),
              canonical_premise(ClaimId, CanonFact, RawFact),
              user:claim_negation_provenance(ClaimId, RawFact, Provenance),
              \+ memberchk(CanonFact, ImplSet)
            ),
            Raw),
        sort(Raw, Honored)
    ;   Honored = []
    ).

%% prescriptive_unfulfilled(+ImplResource, -Unfulfilled) is det.
%  Prescriptive claims whose required (positive) premise is missing from
%  ImplResource. A premise counts as positive when it has no
%  claim_negation_provenance/3 entry. Emits unfulfilled/2 terms.
prescriptive_unfulfilled(ImplResource, Unfulfilled) :-
    (   hypothesis_loaded
    ->  impl_claim_set(ImplResource, ImplSet),
        findall(unfulfilled(ClaimId, CanonFact),
            ( user:claim_label(ClaimId, prescriptive),
              canonical_premise(ClaimId, CanonFact, RawFact),
              \+ user:claim_negation_provenance(ClaimId, RawFact, _),
              \+ memberchk(CanonFact, ImplSet)
            ),
            Raw),
        sort(Raw, Unfulfilled)
    ;   Unfulfilled = []
    ).

%% prescriptive_fulfilled(+ImplResource, -Fulfilled) is det.
prescriptive_fulfilled(ImplResource, Fulfilled) :-
    (   hypothesis_loaded
    ->  impl_claim_set(ImplResource, ImplSet),
        findall(fulfilled(ClaimId, CanonFact),
            ( user:claim_label(ClaimId, prescriptive),
              canonical_premise(ClaimId, CanonFact, RawFact),
              \+ user:claim_negation_provenance(ClaimId, RawFact, _),
              memberchk(CanonFact, ImplSet)
            ),
            Raw),
        sort(Raw, Fulfilled)
    ;   Fulfilled = []
    ).

%% prescriptive_negation_violations(+ImplResource, -Violations) is det.
%  Prescriptive claims whose negated premise still appears in
%  ImplResource. Same Pattern-3 shape as counterfactuals, on the
%  prescriptive side.
prescriptive_negation_violations(ImplResource, Violations) :-
    (   hypothesis_loaded
    ->  impl_claim_set(ImplResource, ImplSet),
        findall(violation(ClaimId, CanonFact, Provenance),
            ( user:claim_label(ClaimId, prescriptive),
              canonical_premise(ClaimId, CanonFact, RawFact),
              user:claim_negation_provenance(ClaimId, RawFact, Provenance),
              memberchk(CanonFact, ImplSet)
            ),
            Raw),
        sort(Raw, Violations)
    ;   Violations = []
    ).

%% descriptive_drift(+ImplResource, +ExistingResource, -Lost) is det.
%  Descriptive claims have no fact-level encoding in hypothesis.pl, but
%  semantically they should be entailed by both existing-world and the
%  implementation. When the caller provides existing-world.pl as a
%  resource, we surface facts present in ExistingResource that are
%  missing from ImplResource — possible descriptive drift the reviewer
%  should inspect. Returns [] when the existing resource is unknown.
descriptive_drift(ImplResource, ExistingResource, Lost) :-
    all_resources(All),
    (   memberchk(ExistingResource, All)
    ->  gap_claims(ExistingResource, ImplResource, Lost)
    ;   Lost = []
    ).

%% label_aware_report(+ImplResource) is det.
%  Print the per-epistemic-label verdict block. Skip with a single
%  diagnostic line when hypothesis.pl is not loaded — stand-alone
%  measure-entailment runs have nothing to verdict against.
label_aware_report(ImplResource) :-
    format('~n=== Epistemic Label Verdicts ===~n', []),
    (   hypothesis_loaded
    ->  emit_counterfactual_section(ImplResource),
        emit_prescriptive_section(ImplResource),
        emit_descriptive_section(ImplResource)
    ;   format('  hypothesis.pl not loaded — per-label verdicts skipped.~n', []),
        format('  Load hypothesis.pl alongside the facts file to enable~n', []),
        format('  Pattern 3 (counterfactual still present) detection.~n', [])
    ).

emit_counterfactual_section(ImplResource) :-
    counterfactual_violations(ImplResource, Violations),
    counterfactual_honored(ImplResource, Honored),
    length(Violations, VN),
    length(Honored, HN),
    Total is VN + HN,
    format('~n--- Counterfactual claims (~w total) ---~n', [Total]),
    format('  Honored:    ~w (forbidden fact correctly absent in ~w)~n',
           [HN, ImplResource]),
    format('  Violations: ~w (Pattern 3: forbidden fact still present)~n',
           [VN]),
    (   VN > 0
    ->  format('  Pattern 3 details:~n'),
        forall(member(violation(C, F, P), Violations),
               format('    [~w / provenance=~w] ~q still asserted in ~w~n',
                      [C, P, F, ImplResource]))
    ;   true
    ).

emit_prescriptive_section(ImplResource) :-
    prescriptive_unfulfilled(ImplResource, Unfulfilled),
    prescriptive_fulfilled(ImplResource, Fulfilled),
    prescriptive_negation_violations(ImplResource, NegViolations),
    length(Unfulfilled, UN),
    length(Fulfilled, FN),
    length(NegViolations, NVN),
    Positive is UN + FN,
    format('~n--- Prescriptive claims (~w positive premise(s), ~w negated) ---~n',
           [Positive, NVN]),
    format('  Fulfilled:    ~w (required fact present in ~w)~n',
           [FN, ImplResource]),
    format('  Unfulfilled:  ~w (required fact missing)~n', [UN]),
    (   UN > 0
    ->  format('  Unfulfilled details:~n'),
        forall(member(unfulfilled(C, F), Unfulfilled),
               format('    [~w] ~q missing from ~w~n', [C, F, ImplResource]))
    ;   true
    ),
    (   NVN > 0
    ->  format('  Negated-premise violations (same shape as Pattern 3):~n'),
        forall(member(violation(C, F, P), NegViolations),
               format('    [~w / provenance=~w] ~q still asserted in ~w~n',
                      [C, P, F, ImplResource]))
    ;   true
    ).

emit_descriptive_section(ImplResource) :-
    findall(C, user:claim_label(C, descriptive), DescClaims),
    length(DescClaims, DN),
    format('~n--- Descriptive claims (~w total) ---~n', [DN]),
    (   DN =:= 0
    ->  format('  (no descriptive claims in hypothesis.pl)~n')
    ;   format('  Descriptive claims describe the existing world.~n'),
        format('  To check drift, supply existing-world.pl as a resource and call~n'),
        format('  descriptive_drift(~w, existing, Lost).~n', [ImplResource])
    ).

%% label_aware_facts_out(+ImplResource, +Stream) is det.
%  Emit machine-readable result/N facts mirroring label_aware_report/1.
%  Used by adherence_facts_out/2 callers and by tests that check the
%  shape without parsing report text.
label_aware_facts_out(ImplResource, Stream) :-
    (   hypothesis_loaded
    ->  counterfactual_violations(ImplResource, CV),
        forall(member(violation(C, F, P), CV),
               emit_term(Stream,
                   result(counterfactual_violation, ImplResource, C, F, P))),
        counterfactual_honored(ImplResource, CH),
        forall(member(honored(C, F, P), CH),
               emit_term(Stream,
                   result(counterfactual_honored, ImplResource, C, F, P))),
        prescriptive_unfulfilled(ImplResource, PU),
        forall(member(unfulfilled(C, F), PU),
               emit_term(Stream,
                   result(prescriptive_unfulfilled, ImplResource, C, F))),
        prescriptive_fulfilled(ImplResource, PF),
        forall(member(fulfilled(C, F), PF),
               emit_term(Stream,
                   result(prescriptive_fulfilled, ImplResource, C, F))),
        prescriptive_negation_violations(ImplResource, PNV),
        forall(member(violation(C, F, P), PNV),
               emit_term(Stream,
                   result(prescriptive_negation_violation, ImplResource, C, F, P)))
    ;   emit_term(Stream, result(label_aware, skipped, hypothesis_not_loaded))
    ).

%% ---- Tests ----

:- begin_tests(adherence).

:- multifile user:asserts/2.
:- dynamic user:asserts/2.

setup_fixture :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(r1, color(sky, blue))),
    assertz(user:asserts(r1, color(grass, green))),
    assertz(user:asserts(r1, deprecated(foo))),
    assertz(user:asserts(r1, triple(a, b, c))),
    assertz(user:asserts(r1, foo(a, b))),
    assertz(user:asserts(r2, color(sky, blue))),
    assertz(user:asserts(r2, color(grass, yellow))),
    assertz(user:asserts(r2, deprecated(bar))),
    assertz(user:asserts(r2, triple(a, b, d))),
    assertz(user:asserts(r2, foo(c, d))),
    assertz(user:asserts(r3, color(sky, blue))).

teardown_fixture :-
    retractall(user:asserts(_, _)).

test(shared, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    shared_claims(r1, r2, Shared),
    memberchk(color(sky, blue), Shared),
    \+ memberchk(color(grass, green), Shared).

test(gap, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    gap_claims(r1, r2, Gaps),
    memberchk(color(grass, green), Gaps),
    \+ memberchk(color(sky, blue), Gaps).

test(extension, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    extension_claims(r1, r2, Ext),
    memberchk(color(grass, yellow), Ext),
    \+ memberchk(color(sky, blue), Ext).

test(adherence_ratio, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    adherence_score(r3, r1, Score),
    total_claims(r1, N),
    Expected is 1 / N,
    abs(Score - Expected) < 0.0001.

test(adherence_empty_fails, [setup(retractall(user:asserts(_,_))), cleanup(teardown_fixture)]) :-
    assertz(user:asserts(empty_prime_other, foo(x))),
    \+ adherence_score(empty_prime_other, no_such_prime, _).

test(jaccard_both_empty_fails, [setup(retractall(user:asserts(_,_))), cleanup(teardown_fixture)]) :-
    \+ jaccard_score(none_a, none_b, _).

test(contradiction_arity2, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    find_contradictions(Cs),
    memberchk(contradiction(color/2, 2, r1-color(grass,green), r2-color(grass,yellow)), Cs).

test(contradiction_unary, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    find_contradictions(Cs),
    memberchk(contradiction(deprecated/1, 1, r1-deprecated(foo), r2-deprecated(bar)), Cs).

test(contradiction_arity3, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    find_contradictions(Cs),
    memberchk(contradiction(triple/3, 3, r1-triple(a,b,c), r2-triple(a,b,d)), Cs).

test(no_contradiction_when_two_args_differ,
     [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    find_contradictions(Cs),
    \+ memberchk(contradiction(foo/2, _, r1-foo(a,b), r2-foo(c,d)), Cs).

test(multi_module_claims_visible,
     [setup(retractall(user:asserts(_,_))),
      cleanup((teardown_fixture,
               catch(abolish(adherence_test_kb:asserts/2), _, true),
               catch(delete_file(TmpFile), _, true)))]) :-
    % Create a temp file declaring its own module with asserts/2 facts and
    % verify claim/2 (via claims_module/1) finds them without help from `user`.
    tmp_file_stream(text, TmpFile, S),
    write(S, ':- module(adherence_test_kb, [asserts/2]).\n'),
    write(S, ':- discontiguous(asserts/2).\n'),
    write(S, 'asserts(mod_r1, color(sky, blue)).\n'),
    write(S, 'asserts(mod_r1, shape(ball, round)).\n'),
    write(S, 'asserts(mod_r2, color(sky, blue)).\n'),
    close(S),
    use_module(TmpFile),
    findall(R-C, claim(R, C), Pairs),
    memberchk(mod_r1-color(sky, blue), Pairs),
    memberchk(mod_r1-shape(ball, round), Pairs),
    memberchk(mod_r2-color(sky, blue), Pairs),
    all_resources(Resources),
    memberchk(mod_r1, Resources),
    memberchk(mod_r2, Resources),
    shared_claims(mod_r1, mod_r2, Shared),
    memberchk(color(sky, blue), Shared).

test(facts_out_emits_results, [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    new_memory_file(MF),
    open_memory_file(MF, write, Out),
    adherence_facts_out(r1, Out),
    close(Out),
    open_memory_file(MF, read, In),
    read_string(In, _, S),
    close(In),
    free_memory_file(MF),
    once(sub_string(S, _, _, _, "result(adherence,r2,r1,")),
    once(sub_string(S, _, _, _, "result(jaccard,")),
    once(sub_string(S, _, _, _, "result(shared,")),
    once(sub_string(S, _, _, _, "result(gap,r1,r2,")),
    once(sub_string(S, _, _, _, "result(extension,r1,r2,")),
    once(sub_string(S, _, _, _, "result(contradiction,")),
    once(sub_string(S, _, _, _, "result(universal,")),
    once(sub_string(S, _, _, _, "result(total,r1,")).

%% --- #14: bounded gap/extension dumps ---

setup_many_gaps :-
    retractall(user:asserts(_, _)),
    forall(between(1, 75, I),
           assertz(user:asserts(big_prime, item(I)))),
    assertz(user:asserts(big_other, sentinel)).

test(print_capped_truncates_with_tail,
     [setup(setup_many_gaps), cleanup(teardown_fixture)]) :-
    gap_claims(big_prime, big_other, Gaps),
    length(Gaps, 75),
    with_output_to(string(Out), print_capped(Gaps, '-')),
    once(sub_string(Out, _, _, _, "and 25 more")),
    % First item printed, last item NOT printed (truncated past cap=50).
    once(sub_string(Out, _, _, _, "item(1)")),
    \+ sub_string(Out, _, _, _, "item(75)").

test(print_capped_no_tail_when_under_cap,
     [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    gap_claims(r1, r2, Gaps),
    with_output_to(string(Out), print_capped(Gaps, '-')),
    \+ sub_string(Out, _, _, _, "more").

%% --- #15: labeled totals in symmetric_report ---

test(symmetric_report_labels_totals,
     [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    with_output_to(string(Out), symmetric_report),
    once(sub_string(Out, _, _, _, "r1: 5 claims; r2: 5 claims")),
    \+ sub_string(Out, _, _, _, "5 total, 5 total").

%% --- #16: distinguish no-resources from no-universals ---

test(report_handles_no_resources_loaded,
     [setup(retractall(user:asserts(_,_))), cleanup(teardown_fixture)]) :-
    with_output_to(string(Out), symmetric_report),
    once(sub_string(Out, _, _, _, "no resources loaded")).

setup_disagreeing :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(da, only_a)),
    assertz(user:asserts(db, only_b)).

test(report_handles_no_universals_when_resources_disagree,
     [setup(setup_disagreeing), cleanup(teardown_fixture)]) :-
    with_output_to(string(Out), symmetric_report),
    once(sub_string(Out, _, _, _, "no claim is shared by all")),
    \+ sub_string(Out, _, _, _, "no resources loaded").

%% --- #4: claim canonicalization ---

setup_string_atom :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(ra, requires(auth, oauth2))),
    assertz(user:asserts(rb, requires(auth, "oauth2"))).

test(canonicalize_string_to_atom_shared,
     [setup(setup_string_atom), cleanup(teardown_fixture)]) :-
    shared_claims(ra, rb, Shared),
    memberchk(requires(auth, oauth2), Shared).

test(canonicalize_claim_rejects_nonground) :-
    \+ canonicalize_claim(requires(auth, _Var), _).

test(canonicalize_claim_normalizes_strings) :-
    canonicalize_claim(requires(auth, "oauth2"), C),
    C == requires(auth, oauth2).

setup_nonground :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(ng, color(sky, blue))),
    assertz(user:asserts(ng, requires(auth, _Anything))).

test(nonground_claim_warns_and_skips,
     [setup(setup_nonground), cleanup(teardown_fixture)]) :-
    findall(C, claim(ng, C), Cs),
    memberchk(color(sky, blue), Cs),
    \+ ( member(X, Cs), X = requires(auth, _) ).

%% --- #8: silent vs conflicting gaps ---

setup_silent_vs_conflicting :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(s1, requires(auth, oauth2))),
    assertz(user:asserts(s1, provides(metrics))),
    assertz(user:asserts(s2, requires(auth, saml))).

test(conflicting_gap_detected,
     [setup(setup_silent_vs_conflicting), cleanup(teardown_fixture)]) :-
    conflicting_gaps(s1, s2, Conflicting),
    memberchk(requires(auth, oauth2), Conflicting),
    \+ memberchk(provides(metrics), Conflicting).

test(silent_gap_detected,
     [setup(setup_silent_vs_conflicting), cleanup(teardown_fixture)]) :-
    silent_gaps(s1, s2, Silent),
    memberchk(provides(metrics), Silent),
    \+ memberchk(requires(auth, oauth2), Silent).

test(gap_claims_unions_silent_and_conflicting,
     [setup(setup_silent_vs_conflicting), cleanup(teardown_fixture)]) :-
    gap_claims(s1, s2, Gaps),
    memberchk(provides(metrics), Gaps),
    memberchk(requires(auth, oauth2), Gaps).

test(adherence_report_prints_silent_and_conflicting_sections,
     [setup(setup_silent_vs_conflicting), cleanup(teardown_fixture)]) :-
    with_output_to(string(Out), adherence_report(s1)),
    once(sub_string(Out, _, _, _, "Silent gaps:")),
    once(sub_string(Out, _, _, _, "Conflicting gaps:")).

test(symmetric_report_splits_silent_and_conflicting,
     [setup(setup_silent_vs_conflicting), cleanup(teardown_fixture)]) :-
    with_output_to(string(Out), symmetric_report),
    once(sub_string(Out, _, _, _, "silent")),
    once(sub_string(Out, _, _, _, "conflicting")).

%% --- #5: claim weighting ---

:- multifile user:claim_weight/2.
:- dynamic user:claim_weight/2.

setup_weighted :-
    retractall(user:asserts(_, _)),
    retractall(user:claim_weight(_, _)),
    assertz(user:asserts(wp, must(auth))),
    assertz(user:asserts(wp, must(tls))),
    assertz(user:asserts(wp, nice(logging))),
    assertz(user:asserts(wo, must(auth))),
    assertz(user:asserts(wo, nice(logging))).

teardown_weighted :-
    retractall(user:asserts(_, _)),
    retractall(user:claim_weight(_, _)).

test(weighted_score_default_matches_unweighted,
     [setup(setup_weighted), cleanup(teardown_weighted)]) :-
    adherence_score(wo, wp, Plain),
    weighted_adherence_score(wo, wp, Weighted),
    abs(Plain - Weighted) < 1.0e-9.

test(weighted_score_diverges_with_nonuniform_weights,
     [setup(setup_weighted), cleanup(teardown_weighted)]) :-
    assertz(user:claim_weight(must(auth), 5.0)),
    assertz(user:claim_weight(must(tls), 5.0)),
    assertz(user:claim_weight(nice(logging), 1.0)),
    adherence_score(wo, wp, Plain),
    weighted_adherence_score(wo, wp, Weighted),
    % Plain = 2/3 ≈ 0.667; Weighted = (5+1)/(5+5+1) = 6/11 ≈ 0.545
    abs(Plain - 0.6667) < 0.01,
    abs(Weighted - 0.5454) < 0.01,
    Weighted < Plain.

%% --- #6: claim categorization ---

:- multifile user:asserts/3.
:- dynamic user:asserts/3.

setup_categorized :-
    retractall(user:asserts(_, _)),
    retractall(user:asserts(_, _, _)),
    assertz(user:asserts(cp, structural, requires(auth, oauth2))),
    assertz(user:asserts(cp, structural, requires(tls, v13))),
    assertz(user:asserts(cp, behavioral, retries(3))),
    assertz(user:asserts(co, structural, requires(auth, oauth2))).

teardown_categorized :-
    retractall(user:asserts(_, _)),
    retractall(user:asserts(_, _, _)).

test(categorized_gaps_grouped_by_category,
     [setup(setup_categorized), cleanup(teardown_categorized)]) :-
    gaps_by_category(cp, co, CatGaps),
    memberchk(structural-Structural, CatGaps),
    memberchk(requires(tls, v13), Structural),
    memberchk(behavioral-Behavioral, CatGaps),
    memberchk(retries(3), Behavioral).

test(claim3_exposes_categories,
     [setup(setup_categorized), cleanup(teardown_categorized)]) :-
    findall(Cat-C, claim(cp, Cat, C), Triples),
    memberchk(structural-requires(auth, oauth2), Triples),
    memberchk(behavioral-retries(3), Triples).

setup_mixed_arity :-
    retractall(user:asserts(_, _)),
    retractall(user:asserts(_, _, _)),
    assertz(user:asserts(mp, plain_claim)),
    assertz(user:asserts(mp, structural, tagged_claim)),
    assertz(user:asserts(mo, sentinel)).

test(mixed_arity_2arg_becomes_general,
     [setup(setup_mixed_arity), cleanup(teardown_categorized)]) :-
    findall(Cat-C, claim(mp, Cat, C), Triples),
    memberchk(general-plain_claim, Triples),
    memberchk(structural-tagged_claim, Triples).

test(adherence_report_categorized_block,
     [setup(setup_categorized), cleanup(teardown_categorized)]) :-
    with_output_to(string(Out), adherence_report(cp)),
    once(sub_string(Out, _, _, _, "[structural]")),
    once(sub_string(Out, _, _, _, "[behavioral]")).

%% --- #7: fuzzy / structural matching ---

setup_fuzzy :-
    retractall(user:asserts(_, _)),
    retractall(user:asserts(_, _, _)),
    % Prime contains a wildcard; canonicalize_claim/2 would reject it,
    % so this asserts/2 fact only flows through subsumed_shared_claims/3.
    assertz(user:asserts(fp, requires(auth, _))),
    assertz(user:asserts(fp, missing(thing))),
    assertz(user:asserts(fo, requires(auth, oauth2))),
    assertz(user:asserts(fo, unrelated(stuff))).

test(subsumed_claim_covers_wildcard,
     [setup(setup_fuzzy), cleanup(teardown_categorized)]) :-
    subsumed_shared_claims(fp, fo, Shared),
    once(( member(P, Shared), P =@= requires(auth, _) )).

test(subsumed_non_matching_excluded,
     [setup(setup_fuzzy), cleanup(teardown_categorized)]) :-
    subsumed_shared_claims(fp, fo, Shared),
    \+ ( member(P, Shared), P =@= missing(thing) ).

%% --- #11: pair cache invariants ---

test(symmetric_report_with_cache_matches_uncached_counts,
     [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    %  Cache must produce the same per-pair numbers as direct calls.
    with_output_to(string(Out), symmetric_report),
    shared_claims(r1, r2, S),
    length(S, SN),
    format(string(Needle), 'Shared claims:      ~w', [SN]),
    once(sub_string(Out, _, _, _, Needle)).

test(pair_cache_unset_after_symmetric_report,
     [setup(setup_fixture), cleanup(teardown_fixture)]) :-
    with_output_to(string(_), symmetric_report),
    \+ nb_current(adherence_pair_cache, _).

%% --- #13: threshold maps and CLI shape ---

setup_thresholds :-
    retractall(user:asserts(_, _)),
    assertz(user:asserts(tp, foo(1))),
    assertz(user:asserts(tp, foo(2))),
    assertz(user:asserts(tp, foo(3))),
    assertz(user:asserts(tp, foo(4))),
    %  ta shares 4/4 with tp -> 1.0
    assertz(user:asserts(ta, foo(1))),
    assertz(user:asserts(ta, foo(2))),
    assertz(user:asserts(ta, foo(3))),
    assertz(user:asserts(ta, foo(4))),
    %  tb shares 2/4 with tp -> 0.5
    assertz(user:asserts(tb, foo(1))),
    assertz(user:asserts(tb, foo(2))),
    assertz(user:asserts(tb, bar(99))),
    assertz(user:asserts(tb, bar(100))).

test(per_resource_threshold_passes_when_all_meet,
     [setup(setup_thresholds), cleanup(teardown_fixture)]) :-
    %  ta needs >=1.0 (has 1.0), tb needs >=0.4 (has 0.5). Both pass.
    catch(adherence_or_fail(tp, [ta-1.0, tb-0.4, default-0.0]), _, fail).

test(per_resource_threshold_fails_when_any_below,
     [setup(setup_thresholds), cleanup(teardown_fixture)]) :-
    %  Cannot easily test halt(1); instead, confirm Failures non-empty by
    %  intercepting before halt via a wrapper that catches halt as exception.
    %  Strategy: use a tiny helper that re-implements failure detection.
    Threshold = [ta-1.0, tb-0.9, default-0.0],
    all_resources(AllRes),
    exclude(==(tp), AllRes, Others),
    threshold_for(Threshold, default, DefT),
    findall(R-S-T,
        (member(R, Others),
         threshold_for(Threshold, R, T0),
         (T0 == none -> T = DefT ; T = T0),
         adherence_score(R, tp, S),
         S < T),
        Failures),
    Failures \== [],
    memberchk(tb-_-0.9, Failures).

test(threshold_for_numeric_uniform) :-
    threshold_for(0.7, anything, 0.7).

test(threshold_for_list_default_falls_through) :-
    threshold_for([x-0.9, default-0.5], y, none).

%% --- #17: property-style tests over generated fixtures ---

%  Fixture: build a small KB programmatically.
build_property_kb(NPerResource, Resources) :-
    retractall(user:asserts(_, _)),
    Resources = [pa, pb, pc],
    forall(
        (member(R, Resources), between(1, NPerResource, I)),
        assertz(user:asserts(R, kv(I, R)))
    ),
    %  Add some shared claims so intersections aren't empty.
    forall(member(R, Resources),
           ( assertz(user:asserts(R, common(alpha))),
             assertz(user:asserts(R, common(beta))) )).

teardown_property_kb :-
    retractall(user:asserts(_, _)).

test(property_shared_claims_symmetric,
     [setup(build_property_kb(5, _Rs)), cleanup(teardown_property_kb)]) :-
    forall(
        (member(R1, [pa, pb, pc]), member(R2, [pa, pb, pc]), R1 @< R2),
        ( shared_claims(R1, R2, S12),
          shared_claims(R2, R1, S21),
          msort(S12, M12), msort(S21, M21),
          M12 == M21
        )
    ).

test(property_gap_is_disjoint_union_of_silent_and_conflicting,
     [setup(build_property_kb(4, _)), cleanup(teardown_property_kb)]) :-
    forall(
        (member(R1, [pa, pb, pc]), member(R2, [pa, pb, pc]), R1 \== R2),
        ( silent_gaps(R1, R2, Silent),
          conflicting_gaps(R1, R2, Conflict),
          gap_claims(R1, R2, Gaps),
          ord_union(Silent, Conflict, Union),
          Union == Gaps,
          ord_intersection(Silent, Conflict, Inter),
          Inter == []
        )
    ).

test(property_self_adherence_is_one,
     [setup(build_property_kb(3, _)), cleanup(teardown_property_kb)]) :-
    forall(member(R, [pa, pb, pc]),
        ( adherence_score(R, R, S),
          abs(S - 1.0) < 1.0e-9
        )).

test(property_weighted_with_unit_weights_equals_unweighted,
     [setup(( build_property_kb(4, _),
              retractall(user:claim_weight(_, _)) )),
      cleanup(( teardown_property_kb,
                retractall(user:claim_weight(_, _)) ))]) :-
    %  No claim_weight/2 clauses defined -> default 1.0 for everything.
    forall(
        (member(R1, [pa, pb, pc]), member(R2, [pa, pb, pc]), R1 \== R2),
        ( adherence_score(R1, R2, Plain),
          weighted_adherence_score(R1, R2, Weighted),
          abs(Plain - Weighted) < 1.0e-9
        )
    ).

test(property_jaccard_symmetric,
     [setup(build_property_kb(3, _)), cleanup(teardown_property_kb)]) :-
    forall(
        (member(R1, [pa, pb, pc]), member(R2, [pa, pb, pc]), R1 @< R2),
        ( jaccard_score(R1, R2, J12),
          jaccard_score(R2, R1, J21),
          abs(J12 - J21) < 1.0e-9
        )
    ).

%% --- Label-aware verdicts (Pattern 3 detection) ---

:- multifile user:claim_label/2, user:claim_premise/2,
             user:claim_negation_provenance/3.
:- dynamic user:claim_label/2, user:claim_premise/2,
           user:claim_negation_provenance/3.

teardown_label_aware :-
    retractall(user:asserts(_, _)),
    retractall(user:asserts(_, _, _)),
    retractall(user:claim_label(_, _)),
    retractall(user:claim_premise(_, _)),
    retractall(user:claim_negation_provenance(_, _, _)).

%  Counterfactual fixture: c_001 says depends_on(cli_tool, logging) must
%  become false; impl still asserts it (Pattern 3). c_002 says
%  template_engine(physical_mail, lob) must become false; impl removed it
%  (honored).
setup_counterfactual_kb :-
    teardown_label_aware,
    assertz(user:claim_label(c_001, counterfactual)),
    assertz(user:claim_premise(c_001, depends_on(cli_tool, logging))),
    assertz(user:claim_negation_provenance(c_001, depends_on(cli_tool, logging), absent)),
    assertz(user:claim_label(c_002, counterfactual)),
    assertz(user:claim_premise(c_002, template_engine(physical_mail, lob))),
    assertz(user:claim_negation_provenance(c_002, template_engine(physical_mail, lob), contradicts)),
    %  impl: still has c_001's forbidden fact (Pattern 3 violation),
    %  cleanly omits c_002's (honored).
    assertz(user:asserts(impl, depends_on(cli_tool, logging))),
    assertz(user:asserts(impl, depends_on(cli_tool, parser))).

test(pattern_3_detected,
     [setup(setup_counterfactual_kb), cleanup(teardown_label_aware)]) :-
    counterfactual_violations(impl, Violations),
    memberchk(violation(c_001, depends_on(cli_tool, logging), absent), Violations),
    \+ memberchk(violation(c_002, _, _), Violations).

test(counterfactual_honored_when_fact_removed,
     [setup(setup_counterfactual_kb), cleanup(teardown_label_aware)]) :-
    counterfactual_honored(impl, Honored),
    memberchk(honored(c_002, template_engine(physical_mail, lob), contradicts), Honored),
    \+ memberchk(honored(c_001, _, _), Honored).

test(pattern_3_clean_after_removal,
     [setup(( setup_counterfactual_kb,
              retract(user:asserts(impl, depends_on(cli_tool, logging))) )),
      cleanup(teardown_label_aware)]) :-
    counterfactual_violations(impl, []),
    counterfactual_honored(impl, Honored),
    memberchk(honored(c_001, depends_on(cli_tool, logging), absent), Honored).

%  String→atom canonicalisation: hypothesis premise written with strings
%  matches an impl fact written with atoms.
test(pattern_3_canonicalises_strings,
     [setup(( teardown_label_aware,
              assertz(user:claim_label(c_str, counterfactual)),
              assertz(user:claim_premise(c_str, requires(auth, "oauth2"))),
              assertz(user:claim_negation_provenance(c_str, requires(auth, "oauth2"), absent)),
              assertz(user:asserts(impl, requires(auth, oauth2))) )),
      cleanup(teardown_label_aware)]) :-
    counterfactual_violations(impl, Violations),
    memberchk(violation(c_str, requires(auth, oauth2), absent), Violations).

%  Prescriptive: positive premise (no negation_provenance) must appear in impl.
setup_prescriptive_kb :-
    teardown_label_aware,
    %  c_p1: required positive fact, present in impl → fulfilled
    assertz(user:claim_label(c_p1, prescriptive)),
    assertz(user:claim_premise(c_p1, exports(auth_module, login))),
    %  c_p2: required positive fact, missing from impl → unfulfilled
    assertz(user:claim_label(c_p2, prescriptive)),
    assertz(user:claim_premise(c_p2, exports(auth_module, logout))),
    %  c_p3: prescriptive with negated premise still present → negation violation
    assertz(user:claim_label(c_p3, prescriptive)),
    assertz(user:claim_premise(c_p3, depends_on(auth_module, legacy_lib))),
    assertz(user:claim_negation_provenance(c_p3, depends_on(auth_module, legacy_lib), absent)),
    assertz(user:asserts(impl, exports(auth_module, login))),
    assertz(user:asserts(impl, depends_on(auth_module, legacy_lib))).

test(prescriptive_fulfilled_detected,
     [setup(setup_prescriptive_kb), cleanup(teardown_label_aware)]) :-
    prescriptive_fulfilled(impl, Fulfilled),
    memberchk(fulfilled(c_p1, exports(auth_module, login)), Fulfilled),
    \+ memberchk(fulfilled(c_p2, _), Fulfilled).

test(prescriptive_unfulfilled_detected,
     [setup(setup_prescriptive_kb), cleanup(teardown_label_aware)]) :-
    prescriptive_unfulfilled(impl, Unfulfilled),
    memberchk(unfulfilled(c_p2, exports(auth_module, logout)), Unfulfilled),
    \+ memberchk(unfulfilled(c_p1, _), Unfulfilled).

test(prescriptive_negation_violation_detected,
     [setup(setup_prescriptive_kb), cleanup(teardown_label_aware)]) :-
    prescriptive_negation_violations(impl, NegViolations),
    memberchk(violation(c_p3, depends_on(auth_module, legacy_lib), absent),
              NegViolations),
    %  Positive prescriptive claims must not appear in negation violations
    \+ memberchk(violation(c_p1, _, _), NegViolations),
    \+ memberchk(violation(c_p2, _, _), NegViolations).

test(prescriptive_unfulfilled_excludes_negated_premises,
     [setup(setup_prescriptive_kb), cleanup(teardown_label_aware)]) :-
    %  c_p3's premise carries a negation_provenance, so it must NOT show up
    %  as "unfulfilled" — it's a different obligation shape.
    prescriptive_unfulfilled(impl, Unfulfilled),
    \+ memberchk(unfulfilled(c_p3, _), Unfulfilled).

%  hypothesis-not-loaded guard: stand-alone runs return [] silently.
test(label_aware_silent_without_hypothesis,
     [setup(retractall(user:asserts(_, _))), cleanup(teardown_label_aware)]) :-
    retractall(user:claim_label(_, _)),
    \+ hypothesis_loaded,
    counterfactual_violations(any, []),
    counterfactual_honored(any, []),
    prescriptive_unfulfilled(any, []),
    prescriptive_fulfilled(any, []),
    prescriptive_negation_violations(any, []).

test(label_aware_report_skips_message_without_hypothesis,
     [setup(retractall(user:asserts(_, _))), cleanup(teardown_label_aware)]) :-
    retractall(user:claim_label(_, _)),
    with_output_to(string(Out), label_aware_report(any)),
    once(sub_string(Out, _, _, _, "hypothesis.pl not loaded")).

test(label_aware_report_calls_out_pattern_3,
     [setup(setup_counterfactual_kb), cleanup(teardown_label_aware)]) :-
    with_output_to(string(Out), label_aware_report(impl)),
    once(sub_string(Out, _, _, _, "Counterfactual claims")),
    once(sub_string(Out, _, _, _, "Pattern 3")),
    once(sub_string(Out, _, _, _, "depends_on(cli_tool,logging)")).

%  Descriptive drift: facts present in existing-world but absent from impl.
test(descriptive_drift_against_existing_world,
     [setup(( teardown_label_aware,
              assertz(user:claim_label(c_d1, descriptive)),
              assertz(user:asserts(existing, has_endpoint(login))),
              assertz(user:asserts(existing, has_endpoint(logout))),
              assertz(user:asserts(impl, has_endpoint(login))) )),
      cleanup(teardown_label_aware)]) :-
    descriptive_drift(impl, existing, Lost),
    memberchk(has_endpoint(logout), Lost),
    \+ memberchk(has_endpoint(login), Lost).

test(descriptive_drift_empty_when_existing_unknown,
     [setup(( teardown_label_aware,
              assertz(user:asserts(impl, has_endpoint(login))) )),
      cleanup(teardown_label_aware)]) :-
    descriptive_drift(impl, existing_not_loaded, []).

test(label_aware_facts_out_emits_pattern_3,
     [setup(setup_counterfactual_kb), cleanup(teardown_label_aware)]) :-
    new_memory_file(MF),
    open_memory_file(MF, write, Out),
    label_aware_facts_out(impl, Out),
    close(Out),
    open_memory_file(MF, read, In),
    read_string(In, _, S),
    close(In),
    free_memory_file(MF),
    once(sub_string(S, _, _, _, "result(counterfactual_violation,impl,c_001,")),
    once(sub_string(S, _, _, _, "result(counterfactual_honored,impl,c_002,")).

:- end_tests(adherence).
