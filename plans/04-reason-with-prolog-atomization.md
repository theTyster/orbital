# Plan: Atomize reason-with-prolog into Isolated Skills

## Goal

The reason-with-prolog skill in c4-prolog has 3 inner loops (Find Patterns, Define Patterns, Condense Patterns). Each should become its own isolated skill. A new orchestration skill automates moving through all three.

## Current State

### Skill definition
- `plugins/c4-prolog/skills/reason-with-prolog/SKILL.md` (184 lines)
- Single monolithic skill with 3 sequential loops
- Each loop has distinct goals, inputs, outputs, and checkpoint criteria
- The skill is C4-specific (this plan does NOT change that — c4-prolog stays C4-focused)

### The 3 loops

**Loop 1: Find Patterns**
- Input: target codebase (directory path)
- Process: explore with Glob/Grep/Read/Agent(Explore), identify C4 levels, write facts.pl, validate
- Output: validated `facts.pl`
- Checkpoint: `validate` passes

**Loop 2: Define Patterns**
- Input: validated `facts.pl`
- Process: run summary, describe, coupling, crosscut to verify alignment
- Output: verified ontology (same facts.pl, confirmed correct)
- Checkpoint: hierarchy matches understanding, counts align

**Loop 3: Condense Patterns**
- Input: verified `facts.pl` + user's task description
- Process: map task to components, run `full <comps>`, interpret output, write plan
- Output: implementation plan + query log
- Checkpoint: plan grounded in Prolog output

### Prolog infrastructure
- `prolog/ontology.pl` — C4 schema + validation
- `prolog/reasoning.pl` — C4 queries (system_summary, impact_analysis, etc.)
- `prolog/run.pl` — command dispatcher
- `scripts/run-query.sh` — bash wrapper

## Changes

### 1. Create 3 new skills from the loops

#### Skill: `c4-find-patterns`

```yaml
name: c4-find-patterns
description: >
  Map a codebase to C4 ontology facts. Explore the codebase, identify system
  boundaries, containers, and components, then write and validate a Prolog facts file.
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[target directory to analyze]"
```

SKILL.md content: Extract Loop 1 from the current reason-with-prolog SKILL.md. Keep it self-contained with its own prerequisites, process, and output sections.

Output contract: `thoughts/facts.pl` (validated)

#### Skill: `c4-define-patterns`

```yaml
name: c4-define-patterns
description: >
  Verify a C4 ontology facts file by running structural queries and confirming
  alignment with codebase understanding. Identifies coupling and cross-cutting concerns.
allowed-tools: Bash, Read, Write
argument-hint: "[facts file path]"
```

SKILL.md content: Extract Loop 2. Input is a validated facts.pl. Process is the summary/describe/coupling/crosscut verification sequence.

Output contract: Verified `facts.pl` (unchanged file, but confirmed correct) + verification notes in query log.

Note: `Read` is allowed here because the agent may need to re-read the facts file or source code to verify alignment. But the primary action is running Prolog queries.

#### Skill: `c4-condense-patterns`

```yaml
name: c4-condense-patterns
description: >
  Transform Prolog analysis into an implementation plan. Maps user task to C4
  components, runs targeted analysis, and produces a plan grounded in formal output.
allowed-tools: Bash, Read, Write
argument-hint: "[facts file path] [task description or component list]"
```

SKILL.md content: Extract Loop 3. Input is verified facts.pl + task description. Process is component mapping, `full <comps>`, interpretation, plan writing.

Output contract: `thoughts/implementation_plan.md` + query log

### 2. Create orchestration skill: `c4-analyze`

```yaml
name: c4-analyze
description: >
  Orchestrate the full C4 analysis pipeline: find patterns in a codebase, verify
  the ontology, and condense into an implementation plan. Runs c4-find-patterns,
  c4-define-patterns, and c4-condense-patterns in sequence.
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[target directory] [task description]"
```

SKILL.md content:

```markdown
# C4 Analyze — Orchestrated Pipeline

Run the full C4 analysis pipeline by invoking each phase in sequence.

## Process

### Phase 1: Find Patterns
Invoke `/c4-find-patterns <target_directory>`

Wait for output: validated facts.pl path.
If validation fails after reasonable iteration, stop and report.

### Phase 2: Define Patterns
Invoke `/c4-define-patterns <facts_file>`

Wait for output: verification confirmation.
If alignment issues found, return to Phase 1 to update facts.

### Phase 3: Condense Patterns
Invoke `/c4-condense-patterns <facts_file> <task_description>`

Wait for output: implementation plan.

## Shortcuts

- If a facts.pl already exists from a prior run, skip Phase 1.
- If the user only wants structural analysis (no plan), stop after Phase 2.
```

### 3. Update the existing reason-with-prolog

Two options:

**Option A (recommended)**: Convert reason-with-prolog into an alias/redirect that tells the user to use the new skills. Keep it for backward compatibility but have it invoke the orchestration skill.

**Option B**: Delete reason-with-prolog entirely. This is cleaner but breaks existing users.

Recommendation: Option A. The SKILL.md becomes a thin wrapper that says "this skill now orchestrates the three phase skills" and invokes `/c4-analyze`.

### 4. Shared Prolog infrastructure

The 3 new skills all need access to the same `ontology.pl`, `reasoning.pl`, `run.pl`, and `run-query.sh`. Options:

**Option A**: Duplicate into each skill's directory (current pattern across plugins). Simple but maintenance burden.

**Option B (recommended)**: Move shared Prolog modules to `plugins/c4-prolog/shared/prolog/` and have each skill's `run-query.sh` reference the shared location via `${CLAUDE_PLUGIN_DIR}` or a relative path.

This requires checking whether `CLAUDE_SKILL_DIR` or `CLAUDE_PLUGIN_DIR` is available in the hook/script environment.

## Files to Create

- `plugins/c4-prolog/skills/c4-find-patterns/SKILL.md`
- `plugins/c4-prolog/skills/c4-find-patterns/scripts/run-query.sh` (symlink or copy)
- `plugins/c4-prolog/skills/c4-find-patterns/scripts/validate-facts.sh`
- `plugins/c4-prolog/skills/c4-define-patterns/SKILL.md`
- `plugins/c4-prolog/skills/c4-define-patterns/scripts/run-query.sh`
- `plugins/c4-prolog/skills/c4-condense-patterns/SKILL.md`
- `plugins/c4-prolog/skills/c4-condense-patterns/scripts/run-query.sh`
- `plugins/c4-prolog/skills/c4-analyze/SKILL.md` (orchestrator)
- Possibly: `plugins/c4-prolog/shared/prolog/` (shared modules)

## Files to Modify

- `plugins/c4-prolog/skills/reason-with-prolog/SKILL.md` — convert to wrapper/redirect
- `.claude-plugin/marketplace.json` — update c4-prolog description, version bump

## Files to Leave Alone

- `plugins/c4-prolog/skills/reason-with-prolog/prolog/*` — these become the shared modules or stay as-is if we duplicate
- `plugins/logic-focused/*` — separate plugin, separate concern

## Downstream Impact

- **multi-plan** imports reason-with-prolog in its pipeline. It would need to reference the orchestrator or the individual phase skills instead.
- **Marketplace users** who invoke `/reason-with-prolog` need the wrapper to still work.

## Risk

- Skill invocation overhead: 3 skill invocations vs. 1 monolithic skill. Each skill load has context cost. Mitigated by the orchestrator skill which batches them.
- Shared module path resolution: `CLAUDE_SKILL_DIR` is per-skill. If we centralize modules, we need `CLAUDE_PLUGIN_DIR` or a relative path convention. Need to verify this works.
- The orchestrator invoking sub-skills: Can a skill invoke another skill via `/skill-name`? Need to verify this is supported in the Claude Code skill system. If not, the orchestrator would need to inline the logic or use Agent tool.

## Open Questions

- Does Claude Code support a skill invoking another skill? If not, the orchestrator must be structured differently (perhaps as agent spawning or inline instructions).
- Should the validate-facts.sh PostToolUse hook be shared or duplicated per skill?
- Should the Prolog modules be symlinked or copied? Symlinks are cleaner but may not work in all installation scenarios.

## Order of Operations

1. Decide on shared module strategy (symlink vs. copy vs. shared dir)
2. Create c4-find-patterns (extract Loop 1)
3. Create c4-define-patterns (extract Loop 2)
4. Create c4-condense-patterns (extract Loop 3)
5. Create c4-analyze orchestrator
6. Convert reason-with-prolog to wrapper
7. Update multi-plan references if needed
8. Test: run the full pipeline via orchestrator and verify same output as monolithic skill
