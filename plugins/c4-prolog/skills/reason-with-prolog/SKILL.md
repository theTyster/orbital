---
name: reason-with-prolog
description: >
  Formal reasoning skill using SWI-Prolog and C4 model ontologies to analyze
  codebases before planning implementation. Use when a task requires understanding
  system structure, dependency impact, or implementation ordering across a codebase.
  Triggers: "analyze this codebase", "plan this change formally", "what's the impact of changing X", "explore relationships".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: [target directory or description of change]
---

# Formal Reasoning with Prolog

This skill has been decomposed into three focused phase skills and an orchestrator.
Invoke `/c4-analyze` to run the full pipeline, or use individual phases:

- `/c4-find-patterns <directory>` — Map a codebase to C4 ontology facts (Loop 1: Find)
- `/c4-define-patterns <facts_file>` — Verify the ontology with structural queries (Loop 2: Define)
- `/c4-condense-patterns <facts_file> <task>` — Transform analysis into implementation plan (Loop 3: Condense)

## Quick Reference

Use `/c4-analyze <directory> <task>` for the full pipeline (recommended).
Use individual phase skills when you only need one step — e.g., skip to
`/c4-condense-patterns` if you already have a validated facts file.

Invoke `/c4-analyze` now to proceed.
