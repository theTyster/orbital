---
name: c4-orchestrate
description: >
  Orchestrate the full C4 analysis pipeline.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: [target directory] [task description]
---

# C4 Analyze — Orchestrated Pipeline

Run the full C4 analysis pipeline by invoking each phase skill in sequence.

## Process

### Phase 1: Find Patterns

Invoke `/c4-find-patterns <target_directory>`

Wait for output: validated `facts.pl` path.
If validation fails after reasonable iteration, stop and report.

### Phase 2: Define Patterns

Invoke `/c4-define-patterns <facts_file>`

Wait for output: verification confirmation.
If alignment issues found, return to Phase 1 to update facts.

### Phase 3: Create Plan

Invoke `/c4-pattern-to-plan <facts_file> <task_description>`

Wait for output: implementation plan.

## Shortcuts

- If a `facts.pl` already exists from a prior run, skip Phase 1.
- If the user only wants structural analysis (no plan), stop after Phase 2.
