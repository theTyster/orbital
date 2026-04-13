/**
 * facts.pl — C4 ontology facts for plugins/c4-prolog
 *
 * Maps the c4-prolog plugin directory to C4 model levels:
 *   C1: The plugin as a system context
 *   C2: Shared infrastructure and skills as containers
 *   C3: Individual Prolog modules, scripts, and skill definitions as components
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
container(c4_prolog, skill_find_patterns, 'Claude Code Skill').
container(c4_prolog, skill_define_patterns, 'Claude Code Skill').
container(c4_prolog, skill_condense_patterns, 'Claude Code Skill').
container(c4_prolog, skill_analyze, 'Claude Code Skill').
container(c4_prolog, skill_reason_with_prolog, 'Claude Code Skill').
container(c4_prolog, evals, 'JSON').

%% ============================================================
%% C3: Components
%% ============================================================

%% Shared Prolog modules
component(c4_prolog, shared_prolog, ontology_module, 'C4 schema definition, display predicates, and structural validation').
component(c4_prolog, shared_prolog, reasoning_module, 'Analysis procedures: impact, scope, order, coupling, crosscut').
component(c4_prolog, shared_prolog, run_module, 'CLI entry point and command dispatcher for swipl invocation').
component(c4_prolog, shared_prolog, test_facts, 'Example facts file serving as template and validation fixture').

%% Shared scripts
component(c4_prolog, shared_scripts, run_query_script, 'swipl wrapper with automatic query logging to markdown').
component(c4_prolog, shared_scripts, validate_facts_script, 'PostToolUse hook script for auto-validating facts files after Write/Edit').

%% Skills — find patterns
component(c4_prolog, skill_find_patterns, find_patterns_skill, 'Maps a codebase to C4 ontology facts via explore-identify-write-validate loop').

%% Skills — define patterns
component(c4_prolog, skill_define_patterns, define_patterns_skill, 'Verifies C4 facts with structural queries: summary, describe, coupling, crosscut').

%% Skills — condense patterns
component(c4_prolog, skill_condense_patterns, condense_patterns_skill, 'Transforms Prolog analysis into implementation plans using scope and impact queries').

%% Skills — analyze orchestrator
component(c4_prolog, skill_analyze, analyze_skill, 'Orchestrates full pipeline: find > define > condense in sequence').

%% Skills — legacy redirect
component(c4_prolog, skill_reason_with_prolog, reason_with_prolog_skill, 'Backward-compatible redirect to c4-analyze pipeline').

%% Evals
component(c4_prolog, evals, evals_config, 'Eval definitions for testing c4-prolog skill correctness').

%% ============================================================
%% Dependencies
%% ============================================================

%% Prolog module dependencies
depends_on(run_module, ontology_module).
depends_on(run_module, reasoning_module).
depends_on(reasoning_module, ontology_module).

%% Script dependencies on Prolog
depends_on(run_query_script, run_module).
depends_on(validate_facts_script, run_module).

%% Skill dependencies on shared infrastructure
depends_on(find_patterns_skill, run_query_script).
depends_on(define_patterns_skill, run_query_script).
depends_on(condense_patterns_skill, run_query_script).

%% Skill pipeline dependencies
depends_on(define_patterns_skill, find_patterns_skill).
depends_on(condense_patterns_skill, define_patterns_skill).
depends_on(analyze_skill, find_patterns_skill).
depends_on(analyze_skill, define_patterns_skill).
depends_on(analyze_skill, condense_patterns_skill).
depends_on(reason_with_prolog_skill, analyze_skill).

%% Evals depend on skills they test
depends_on(evals_config, find_patterns_skill).
depends_on(evals_config, condense_patterns_skill).

%% ============================================================
%% File Mappings
%% ============================================================

%% Context root
file_mapping(context, c4_prolog, 'plugins/c4-prolog').

%% Container paths
file_mapping(container, shared_prolog, 'plugins/c4-prolog/shared/prolog').
file_mapping(container, shared_scripts, 'plugins/c4-prolog/shared/scripts').
file_mapping(container, skill_find_patterns, 'plugins/c4-prolog/skills/c4-find-patterns').
file_mapping(container, skill_define_patterns, 'plugins/c4-prolog/skills/c4-define-patterns').
file_mapping(container, skill_condense_patterns, 'plugins/c4-prolog/skills/c4-condense-patterns').
file_mapping(container, skill_analyze, 'plugins/c4-prolog/skills/c4-analyze').
file_mapping(container, skill_reason_with_prolog, 'plugins/c4-prolog/skills/reason-with-prolog').
file_mapping(container, evals, 'plugins/c4-prolog/evals').

%% Component files — shared prolog
file_mapping(component, ontology_module, 'plugins/c4-prolog/shared/prolog/ontology.pl').
file_mapping(component, reasoning_module, 'plugins/c4-prolog/shared/prolog/reasoning.pl').
file_mapping(component, run_module, 'plugins/c4-prolog/shared/prolog/run.pl').
file_mapping(component, test_facts, 'plugins/c4-prolog/shared/prolog/test_facts.pl').

%% Component files — shared scripts
file_mapping(component, run_query_script, 'plugins/c4-prolog/shared/scripts/run-query.sh').
file_mapping(component, validate_facts_script, 'plugins/c4-prolog/shared/scripts/validate-facts.sh').

%% Component files — skills
file_mapping(component, find_patterns_skill, 'plugins/c4-prolog/skills/c4-find-patterns/SKILL.md').
file_mapping(component, define_patterns_skill, 'plugins/c4-prolog/skills/c4-define-patterns/SKILL.md').
file_mapping(component, condense_patterns_skill, 'plugins/c4-prolog/skills/c4-condense-patterns/SKILL.md').
file_mapping(component, analyze_skill, 'plugins/c4-prolog/skills/c4-analyze/SKILL.md').
file_mapping(component, reason_with_prolog_skill, 'plugins/c4-prolog/skills/reason-with-prolog/SKILL.md').

%% Component files — evals
file_mapping(component, evals_config, 'plugins/c4-prolog/evals/evals.json').
