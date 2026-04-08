/**
 * merge_facts.pl — Plugin decomposition strategy
 *
 * Models skills, their capabilities, and proposed plugin assignments
 * to reason about cohesion, coupling, and decomposition soundness.
 */

:- discontiguous
    plugin/2, skill/2, capability/2, depends_on/2,
    assigned_to/2, concern_domain/2, weakness/2.

%% ============================================================
%% Plugins — each plugin is one coherent capability
%% ============================================================

plugin(logic_focused, 'Formal logic reasoning pipeline — help LLMs think rigorously').
plugin(c4_prolog, 'C4 architectural modeling and Prolog-based codebase analysis').
plugin(multi_plan, 'Parallel worktree orchestration with review cycles').

%% ============================================================
%% Skills — all skills across both existing and new
%% ============================================================

% New pipeline skills
skill(translate_to_prolog, 'Translate domain logic into validated Prolog facts').
skill(query_hypothesis, 'Query Prolog KB to formulate falsifiable hypothesis').
skill(formalize_in_lean, 'Prove hypothesis in Lean4 with feedback loop').
skill(translate_proof_llm, 'Convert Lean4 proofs to structured logic for LLMs').
skill(translate_proof_human, 'Convert Lean4 proofs to plain English').
skill(plan_from_proof, 'Create implementation plan grounded in proven properties').

% Existing skills
skill(reason_with_prolog, 'C4 ontology mapping + orbital flow + Prolog reasoning').
skill(prove_with_lean, 'Lean4 proof orchestration with PostToolUse hooks').
skill(scaffold_pseudocode, 'Logical pattern documents: invariants, types, edge cases').
skill(orchestrate_multi_plan, 'Parallel worktree plan > review > vet > implement > commit').
skill(make_commits, 'Organize unstaged changes into logical commits').

%% ============================================================
%% Capabilities — what each skill provides
%% ============================================================

% translate_to_prolog (currently C4-coupled, needs decoupling)
capability(translate_to_prolog, prolog_fact_generation).
capability(translate_to_prolog, prolog_validation).
capability(translate_to_prolog, c4_ontology_mapping).      % TO REMOVE

% query_hypothesis
capability(query_hypothesis, hypothesis_formulation).
capability(query_hypothesis, prolog_exploration).
capability(query_hypothesis, falsifiable_statement_generation).
capability(query_hypothesis, formal_property_identification).

% formalize_in_lean
capability(formalize_in_lean, lean4_proof).
capability(formalize_in_lean, feedback_loop_to_prolog).
capability(formalize_in_lean, retry_with_budget).
capability(formalize_in_lean, sub_agent_spawning).

% translate_proof_llm
capability(translate_proof_llm, proof_to_structured_logic).
capability(translate_proof_llm, quantifier_preservation).
capability(translate_proof_llm, machine_parseable_output).

% translate_proof_human
capability(translate_proof_human, proof_to_plain_english).
capability(translate_proof_human, limitation_honesty).
capability(translate_proof_human, stakeholder_communication).

% plan_from_proof
capability(plan_from_proof, proof_grounded_planning).
capability(plan_from_proof, invariant_guard_mapping).
capability(plan_from_proof, phase_ordering).
capability(plan_from_proof, risk_register).

% reason_with_prolog (existing)
capability(reason_with_prolog, c4_ontology_mapping).
capability(reason_with_prolog, prolog_validation).
capability(reason_with_prolog, impact_analysis).
capability(reason_with_prolog, implementation_ordering).
capability(reason_with_prolog, dependency_analysis).
capability(reason_with_prolog, orbital_flow).
capability(reason_with_prolog, reusable_prolog_infrastructure).

% prove_with_lean (existing)
capability(prove_with_lean, lean4_proof).
capability(prove_with_lean, posttooluse_hooks).
capability(prove_with_lean, retry_with_budget).
capability(prove_with_lean, sub_agent_spawning).
capability(prove_with_lean, mathlib_integration).

% scaffold_pseudocode (existing)
capability(scaffold_pseudocode, invariant_extraction).
capability(scaffold_pseudocode, type_relation_modeling).
capability(scaffold_pseudocode, edge_predicate_identification).
capability(scaffold_pseudocode, logic_sketch).
capability(scaffold_pseudocode, scope_boundary_definition).

% orchestrate_multi_plan (existing)
capability(orchestrate_multi_plan, parallel_worktree_orchestration).
capability(orchestrate_multi_plan, plan_review_iterate_cycle).
capability(orchestrate_multi_plan, human_vetting_gate).
capability(orchestrate_multi_plan, task_tracking).

% make_commits (existing)
capability(make_commits, logical_commit_organization).

%% ============================================================
%% Concern domains — which domain a capability belongs to
%% ============================================================

concern_domain(prolog_fact_generation, formal_logic).
concern_domain(prolog_validation, formal_logic).
concern_domain(prolog_exploration, formal_logic).
concern_domain(hypothesis_formulation, formal_logic).
concern_domain(falsifiable_statement_generation, formal_logic).
concern_domain(formal_property_identification, formal_logic).
concern_domain(lean4_proof, formal_logic).
concern_domain(feedback_loop_to_prolog, formal_logic).
concern_domain(retry_with_budget, formal_logic).
concern_domain(sub_agent_spawning, formal_logic).
concern_domain(proof_to_structured_logic, formal_logic).
concern_domain(quantifier_preservation, formal_logic).
concern_domain(machine_parseable_output, formal_logic).
concern_domain(proof_to_plain_english, formal_logic).
concern_domain(limitation_honesty, formal_logic).
concern_domain(stakeholder_communication, formal_logic).
concern_domain(proof_grounded_planning, formal_logic).
concern_domain(invariant_guard_mapping, formal_logic).
concern_domain(phase_ordering, formal_logic).
concern_domain(risk_register, formal_logic).
concern_domain(posttooluse_hooks, formal_logic).
concern_domain(mathlib_integration, formal_logic).
concern_domain(invariant_extraction, formal_logic).
concern_domain(edge_predicate_identification, formal_logic).
concern_domain(logic_sketch, formal_logic).
concern_domain(scope_boundary_definition, formal_logic).
concern_domain(type_relation_modeling, formal_logic).
concern_domain(logical_commit_organization, utility).

concern_domain(c4_ontology_mapping, architecture).
concern_domain(impact_analysis, architecture).
concern_domain(implementation_ordering, architecture).
concern_domain(dependency_analysis, architecture).
concern_domain(orbital_flow, architecture).
concern_domain(reusable_prolog_infrastructure, architecture).

concern_domain(parallel_worktree_orchestration, orchestration).
concern_domain(plan_review_iterate_cycle, orchestration).
concern_domain(human_vetting_gate, orchestration).
concern_domain(task_tracking, orchestration).

%% ============================================================
%% Plugin assignments — proposed decomposition
%% ============================================================

% logic_focused gets the new pipeline + make_commits
assigned_to(translate_to_prolog, logic_focused).
assigned_to(query_hypothesis, logic_focused).
assigned_to(formalize_in_lean, logic_focused).
assigned_to(translate_proof_llm, logic_focused).
assigned_to(translate_proof_human, logic_focused).
assigned_to(plan_from_proof, logic_focused).
assigned_to(make_commits, logic_focused).

% c4_prolog gets architecture-specific skills
assigned_to(reason_with_prolog, c4_prolog).
assigned_to(scaffold_pseudocode, c4_prolog).

% multi_plan gets orchestration
assigned_to(orchestrate_multi_plan, multi_plan).

% existing lean/proof skills — infrastructure absorbed into formalize_in_lean
assigned_to(prove_with_lean, logic_focused).  % absorbed, not standalone

%% ============================================================
%% Dependencies — artifact flow between skills
%% ============================================================

% New pipeline
depends_on(query_hypothesis, translate_to_prolog).
depends_on(formalize_in_lean, query_hypothesis).
depends_on(translate_proof_llm, formalize_in_lean).
depends_on(translate_proof_human, formalize_in_lean).
depends_on(plan_from_proof, translate_proof_llm).

% Existing internal deps
depends_on(orchestrate_multi_plan, reason_with_prolog).
depends_on(orchestrate_multi_plan, prove_with_lean).
depends_on(orchestrate_multi_plan, scaffold_pseudocode).
depends_on(orchestrate_multi_plan, make_commits).
depends_on(prove_with_lean, scaffold_pseudocode).

%% ============================================================
%% Weaknesses — known issues to address
%% ============================================================

weakness(translate_to_prolog, coupled_to_c4_ontology).
weakness(reason_with_prolog, monolithic).
weakness(orchestrate_multi_plan, too_many_concerns).
weakness(orchestrate_multi_plan, tightly_coupled_to_old_skills).
weakness(prove_with_lean, no_feedback_loop).
weakness(scaffold_pseudocode, outputs_not_consumed_downstream).
