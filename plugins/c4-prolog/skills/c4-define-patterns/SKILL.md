---
name: c4-define-patterns
description: >
  Verify a C4 ontology facts file by running structural queries and confirming
  alignment with codebase understanding. Identifies coupling and cross-cutting concerns.
  Use when: "verify the facts file", "check the ontology", "analyze coupling",
  "run structural analysis", or after c4-find-patterns to confirm correctness.
user-invocable: true
allowed-tools: Bash, Read, Write
argument-hint: [facts file path]
---

# C4 Define Patterns

Verify a C4 ontology facts file by running structural queries against it. The goal
is to confirm that the formal model matches your understanding of the codebase,
identify coupling boundaries, and surface cross-cutting concerns.

Input: A validated `facts.pl` (output from `/c4-find-patterns` or manual creation).

## Key Paths

- **Query runner**: `${CLAUDE_SKILL_DIR}/scripts/run-query.sh`
- **Query log**: Written automatically next to facts file as `<name>_queries.md`

### Reasoning procedures

```!
cat ${CLAUDE_SKILL_DIR}/prolog/reasoning.pl
```

## References

SWI-Prolog extension documentation is at `${CLAUDE_SKILL_DIR}/../../references/swi-prolog-extensions/`. Consult it when you need advanced Prolog features (tabling, DCGs, constraint logic programming, modules, etc.).

## How to invoke queries

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> <command> [args]
```

---

## Process

### 1. Run system summary

Confirm the ontology matches your understanding of the codebase:

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> summary
```

Check: Do the context/container/component counts match what you explored?
If not, the facts file needs revision — go back to `/c4-find-patterns`.

### 2. Run describe

See the full C4 tree and verify the hierarchy:

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> describe
```

Check: Are components in the right containers? Are containers in the right contexts?

### 3. Run coupling and crosscut

Understand system boundaries and shared infrastructure:

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> coupling
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> crosscut
```

Coupling reveals which containers depend on each other. Crosscut identifies
components that are depended on across multiple container boundaries — these
are your shared infrastructure hotspots.

---

## Output

Verified ontology: the same `facts.pl`, confirmed correct. The query log at
`<facts_basename>_queries.md` captures all verification results for transparency.

If alignment issues are found, report them with specifics so the facts can be
corrected (either manually or by re-running `/c4-find-patterns`).
