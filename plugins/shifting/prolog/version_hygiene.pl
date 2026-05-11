:- module(version_hygiene,
          [ check_hygiene/0
          , check_hygiene/2
          , read_pl_terms/2
          ]).

% Hypothesis version hygiene check.
%
% Detects drift between the artifacts of a multi-pass pipeline run. When
% prove-invariants is invoked twice on the same ticket -- for example after
% hypothesis.pl is refined v1 -> v2 -- the artifacts on disk
% (lean_proof_results.pl, target-world.pl, the Lean source files in
% thoughts/lean/Proofs/) must all reference the same generation of fact ids
% and theorem ids. Drift between any two of them signals stale cache.
%
% Three signals are detected (the cheap ones):
%
% 1. theorem_id_drift   -- theorem_verdict/2 in lean_proof_results.pl
%    references a property id absent from the current hypothesis.pl's
%    formal_property/3 set.
% 2. fact_id_drift      -- provenance_annotation/3 in lean_proof_results.pl
%    references a (Fact, Mode) pair absent from the current
%    claim_negation_provenance/3 records in hypothesis.pl.
% 3. timestamp_inversion -- lean_proof_results.pl was generated before
%    hypothesis.pl was last modified.
%
% Two further signals are documented but not implemented in v1 because they
% require parsing Lean source:
%
% 4. lean_source_results_drift  -- theorems declared in
%    thoughts/lean/Proofs/*.lean that have no row in lean_proof_results.pl,
%    or vice versa.
% 5. target_world_transcription_drift -- Lean def blocks transcribed from
%    target-world.pl whose enumerated-fact set disagrees with current
%    target-world content.
%
% Each signal is reported to stderr with prefix [hygiene_warning]. When no
% drift is detected, hygiene_clean. is printed to stdout and the goal
% succeeds. Otherwise the goal fails (so caller scripts that expect -t halt
% semantics exit nonzero).
%
% Usage from prove-invariants or shell:
%
%   swipl -g "use_module('PLUGIN/prolog/version_hygiene'),
%             (check_hygiene -> halt(0) ; halt(1))"
%

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

%! check_hygiene is semidet.
%
%  Default-paths entry point. Uses `thoughts/hypothesis.pl` and
%  `thoughts/lean_proof_results.pl`. Succeeds with `hygiene_clean.` on stdout
%  when no drift is detected; fails (after printing warnings to stderr)
%  otherwise.
check_hygiene :-
    check_hygiene('thoughts/hypothesis.pl',
                  'thoughts/lean_proof_results.pl').

%! check_hygiene(+HypoPath:atom, +ResultsPath:atom) is semidet.
%
%  Runs every implemented drift check. Returns true with `hygiene_clean.`
%  printed to stdout iff every check passes. On failure, warnings are
%  printed to stderr and the predicate fails so `swipl -g goal -t halt`
%  exits with nonzero status.
check_hygiene(HypoPath, ResultsPath) :-
    findall(W, all_warnings(HypoPath, ResultsPath, W), Warnings0),
    list_to_set(Warnings0, Warnings),
    ( Warnings = []
    -> format(user_output, "hygiene_clean.~n", [])
    ; emit_warnings(Warnings),
      fail
    ).

all_warnings(HypoPath, ResultsPath, W) :-
    artifact_warnings(HypoPath, ResultsPath, W).
all_warnings(HypoPath, ResultsPath, W) :-
    timestamp_warnings(HypoPath, ResultsPath, W).
all_warnings(HypoPath, ResultsPath, W) :-
    drift_warnings(HypoPath, ResultsPath, W).

artifact_warnings(HypoPath, _ResultsPath,
        warning(missing_artifact, HypoPath, Msg)) :-
    \+ exists_file(HypoPath),
    format(string(Msg),
           "hypothesis.pl not found — pipeline may not have been run yet",
           []).
artifact_warnings(_HypoPath, ResultsPath,
        warning(missing_artifact, ResultsPath, Msg)) :-
    \+ exists_file(ResultsPath),
    format(string(Msg),
           "lean_proof_results.pl not found — prove-invariants has not produced output yet",
           []).

timestamp_warnings(HypoPath, ResultsPath,
        warning(timestamp_inversion, ResultsPath, Msg)) :-
    exists_file(HypoPath),
    exists_file(ResultsPath),
    time_file(HypoPath, HypoT),
    time_file(ResultsPath, ResT),
    HypoT > ResT,
    format(string(Msg),
           "lean_proof_results.pl is older than hypothesis.pl — re-run prove-invariants",
           []).

drift_warnings(HypoPath, ResultsPath, W) :-
    exists_file(HypoPath),
    exists_file(ResultsPath),
    read_pl_terms(HypoPath, HypoTerms),
    read_pl_terms(ResultsPath, ResultsTerms),
    ( theorem_drift_warning(HypoTerms, ResultsTerms, W)
    ; fact_drift_warning(HypoTerms, ResultsTerms, W)
    ).

theorem_drift_warning(HypoTerms, ResultsTerms,
        warning(theorem_id_drift, T, Msg)) :-
    member(theorem_verdict(T, _), ResultsTerms),
    \+ member(formal_property(T, _, _), HypoTerms),
    format(string(Msg),
           "theorem_verdict(~w, _) in lean_proof_results.pl has no formal_property/3 in hypothesis.pl",
           [T]).

fact_drift_warning(HypoTerms, ResultsTerms,
        warning(fact_id_drift, F-M, Msg)) :-
    member(provenance_annotation(_, F, M), ResultsTerms),
    \+ member(claim_negation_provenance(_, F, M), HypoTerms),
    format(string(Msg),
           "provenance_annotation(_, ~q, ~w) in lean_proof_results.pl has no matching claim_negation_provenance/3 in hypothesis.pl — fact-id or mode disagreement, possible v1/v2 leak",
           [F, M]).

%! read_pl_terms(+Path:atom, -Terms:list) is det.
%
%  Read every clause from a Prolog facts file as a list of terms. Skips
%  module declarations and directives (terms whose principal functor is
%  `:-/1` or `:-/2`). Used by `check_hygiene/2`; exported so callers can
%  add their own checks.
read_pl_terms(Path, Terms) :-
    setup_call_cleanup(
      open(Path, read, Stream),
      read_terms_loop(Stream, Terms),
      close(Stream)
    ).

read_terms_loop(Stream, Terms) :-
    read_term(Stream, T, []),
    ( T == end_of_file
    -> Terms = []
    ; ( T = (:- _) ; T = (:- _, _) )
    -> read_terms_loop(Stream, Terms)
    ; Terms = [T | Rest],
      read_terms_loop(Stream, Rest)
    ).

emit_warnings(Warnings) :-
    forall(member(warning(Code, Subject, Msg), Warnings),
           format(user_error,
                  "[hygiene_warning] ~w on ~q: ~w~n",
                  [Code, Subject, Msg])).
