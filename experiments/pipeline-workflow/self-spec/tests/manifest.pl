% thoughts/tests/manifest.pl
% Emitted by instantiate-properties at the close of stage 5.
% Schema: plugins/shifting/references/pipeline-schema/manifest.md
%
% Carrier (sole predecessor input): thoughts/lean_proof_results.pl + the
% thoughts/lean/Proofs/*.lean directory it cross-references. Upstream
% hypothesis.pl / target-world.pl were consulted ONLY through the carrier's
% transitive citation chains (theorem_source/2, provenance_annotation/3).

% --- Citation records: one descends_from/2 per .pl artifact consulted in Step 1.
descends_from('orbital_pipeline.proof_properties.test.js', 'thoughts/lean_proof_results.pl').
descends_from('orbital_pipeline.proof_properties.test.js', 'thoughts/hypothesis.pl').
descends_from('orbital_pipeline.proof_properties.test.js', 'thoughts/target-world.pl').

% --- Gap records: upstream_gap/3 facts appended after the citation block.
% No upstream gaps this run. All 7 invariants (I-1..I-7) are `proven` and
% axiom-free; every property projected onto a concrete fixture in the target
% Workflow (no unfixturable_property). All necessity lemmas are `proven`
% (no extraneous-counterfactual), and no INSUFFICIENT conditional proof.
