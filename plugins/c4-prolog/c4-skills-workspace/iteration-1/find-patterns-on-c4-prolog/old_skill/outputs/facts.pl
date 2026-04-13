/**
 * facts.pl — C4 ontology for plugins/c4-prolog
 *
 * Maps the c4-prolog plugin directory to C4 architectural predicates.
 * Focus: shared Prolog infrastructure and skill definitions.
 */
:- discontiguous context/2, container/3, component/4,
                  file_mapping/3, depends_on/2.

%% ============================================================
%% C1: System Contexts
%% ============================================================

context(c4_prolog, 'C4 architectural modeling and Prolog-based codebase analysis plugin').

%% ============================================================
%% C2: Containers
%% ============================================================

container(c4_prolog, shared_prolog, 'SWI-Prolog').
container(c4_prolog, shared_scripts, 'Bash').
container(c4_prolog, phase_skills, 'Claude Code Skills').
container(c4_prolog, orchestration, 'Claude Code Skills').
container(c4_prolog, evals, 'JSON').

%% ============================================================
%% C3: Components — Shared Prolog Modules
%% ============================================================

component(c4_prolog, shared_prolog, ontology_module, 'C4 schema predicates, validation, and display for context/container/component/file_mapping').
component(c4_prolog, shared_prolog, reasoning_module, 'Analysis procedures: impact, scope, order, coupling, crosscut, full_analysis').
component(c4_prolog, shared_prolog, run_module, 'CLI entry point and command dispatcher for swipl invocations').
component(c4_prolog, shared_prolog, test_facts, 'Example facts file serving as template for generated facts').

%% ============================================================
%% C3: Components — Shared Scripts
%% ============================================================

component(c4_prolog, shared_scripts, run_query_script, 'swipl wrapper with timestamped query logging to markdown').
component(c4_prolog, shared_scripts, validate_facts_script, 'PostToolUse hook that auto-validates .pl facts files after Write/Edit').

%% ============================================================
%% C3: Components — Phase Skills (individual analysis loops)
%% ============================================================

component(c4_prolog, phase_skills, c4_find_patterns_skill, 'Loop 1: Explore codebase, identify C4 levels, write and validate facts.pl').
component(c4_prolog, phase_skills, c4_define_patterns_skill, 'Loop 2: Verify ontology with summary, describe, coupling, crosscut queries').
component(c4_prolog, phase_skills, c4_condense_patterns_skill, 'Loop 3: Map task to components, run targeted analysis, produce implementation plan').

%% ============================================================
%% C3: Components — Orchestration
%% ============================================================

component(c4_prolog, orchestration, c4_analyze_skill, 'Orchestrator that runs find > define > condense in sequence').
component(c4_prolog, orchestration, reason_with_prolog_skill, 'Legacy redirect skill that points users to c4-analyze').

%% ============================================================
%% C3: Components — Evals
%% ============================================================

component(c4_prolog, evals, evals_config, 'Evaluation definitions for testing the atomized skill pipeline').

%% ============================================================
%% Dependencies
%% ============================================================

% run_module loads ontology and reasoning modules
depends_on(run_module, ontology_module).
depends_on(run_module, reasoning_module).

% reasoning_module calls ontology predicates (validate_ontology, describe_all)
depends_on(reasoning_module, ontology_module).

% run_query_script invokes swipl via run_module
depends_on(run_query_script, run_module).

% validate_facts_script also invokes swipl via run_module
depends_on(validate_facts_script, run_module).

% Phase skills depend on the shared scripts (symlinked into each skill)
depends_on(c4_find_patterns_skill, run_query_script).
depends_on(c4_define_patterns_skill, run_query_script).
depends_on(c4_condense_patterns_skill, run_query_script).

% Phase skills depend on the Prolog modules (symlinked into each skill)
depends_on(c4_find_patterns_skill, ontology_module).
depends_on(c4_find_patterns_skill, test_facts).
depends_on(c4_define_patterns_skill, reasoning_module).
depends_on(c4_condense_patterns_skill, reasoning_module).

% Orchestrator depends on the three phase skills
depends_on(c4_analyze_skill, c4_find_patterns_skill).
depends_on(c4_analyze_skill, c4_define_patterns_skill).
depends_on(c4_analyze_skill, c4_condense_patterns_skill).

% Legacy redirect depends on the orchestrator
depends_on(reason_with_prolog_skill, c4_analyze_skill).

% Evals exercise the skills
depends_on(evals_config, c4_find_patterns_skill).
depends_on(evals_config, c4_condense_patterns_skill).

%% ============================================================
%% File Mappings
%% ============================================================

% Context root
file_mapping(context, c4_prolog, 'plugins/c4-prolog').

% Container paths
file_mapping(container, shared_prolog, 'plugins/c4-prolog/shared/prolog').
file_mapping(container, shared_scripts, 'plugins/c4-prolog/shared/scripts').
file_mapping(container, phase_skills, 'plugins/c4-prolog/skills').
file_mapping(container, orchestration, 'plugins/c4-prolog/skills').
file_mapping(container, evals, 'plugins/c4-prolog/evals').

% Shared Prolog module files
file_mapping(component, ontology_module, 'plugins/c4-prolog/shared/prolog/ontology.pl').
file_mapping(component, reasoning_module, 'plugins/c4-prolog/shared/prolog/reasoning.pl').
file_mapping(component, run_module, 'plugins/c4-prolog/shared/prolog/run.pl').
file_mapping(component, test_facts, 'plugins/c4-prolog/shared/prolog/test_facts.pl').

% Shared script files
file_mapping(component, run_query_script, 'plugins/c4-prolog/shared/scripts/run-query.sh').
file_mapping(component, validate_facts_script, 'plugins/c4-prolog/shared/scripts/validate-facts.sh').

% Phase skill definitions
file_mapping(component, c4_find_patterns_skill, 'plugins/c4-prolog/skills/c4-find-patterns/SKILL.md').
file_mapping(component, c4_define_patterns_skill, 'plugins/c4-prolog/skills/c4-define-patterns/SKILL.md').
file_mapping(component, c4_condense_patterns_skill, 'plugins/c4-prolog/skills/c4-condense-patterns/SKILL.md').

% Orchestration skill definitions
file_mapping(component, c4_analyze_skill, 'plugins/c4-prolog/skills/c4-analyze/SKILL.md').
file_mapping(component, reason_with_prolog_skill, 'plugins/c4-prolog/skills/reason-with-prolog/SKILL.md').

% Evals config
file_mapping(component, evals_config, 'plugins/c4-prolog/evals/evals.json').
