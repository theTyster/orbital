---
name: multi-plan
description: >
  Orchestrate multiple enhancements in parallel, each with a dedicated worktree/branch,
  through a plan → review → human-vetting → implement → commit pipeline.
  Use when: "plan and implement these enhancements", "multi-plan X, Y, Z", "parallel feature development".
user-invocable: true
model: sonnet
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, EnterWorktree, ExitWorktree, TaskCreate, TaskUpdate, TaskList, CronCreate, CronDelete
argument-hint: [list of enhancements to plan and implement]
---

# Multi-Plan Orchestrator

Manage a pipeline of parallel enhancement agents across isolated worktrees.

## Shared Paths

```
PROLOG_RUNTIME=${CLAUDE_SKILL_DIR}/../../../../lib/prolog-runtime
PROLOG_QUERY=${PROLOG_RUNTIME}/scripts/run-query.sh
PROLOG_TEMPLATE=${PROLOG_RUNTIME}/prolog/test_facts.pl
LEAN_PROJECT=${CLAUDE_SKILL_DIR}/../prove-with-lean/lean
LEAN_PROOFS=${LEAN_PROJECT}/ProveWithLean/Proofs
PSEUDOCODE_SKILL=${CLAUDE_SKILL_DIR}/../scaffold-pseudocode
```

Prolog: `${PROLOG_QUERY} <facts_file> <command>` (logs all queries automatically)
Commands: `validate`, `summary`, `describe`, `impact <comp>`, `order`, `scope <c1,c2>`, `coupling`, `crosscut`, `full [<comps>]`
Lean: `cd ${LEAN_PROJECT} && lake build`

---

## Pipeline

```
Step 0: Parse enhancements
Step 1: Plan    (parallel, opus, isolation: worktree)
Step 2: Review  (parallel, opus) — checks artifact↔requirement alignment
  └─ 2b: Iterate plan↔review until aligned (max 3 rounds)
Step 3: HUMAN VETTING — mandatory pause
Step 4: Implement (parallel, sonnet, approved only)
Step 5: Commit    (parallel, haiku)
```

---

## Step 0: Parse Enhancements

Parse arguments as comma- or newline-separated enhancements. If none provided, ask the user.

Classify each as **code** (concrete change, feature, bug fix) or **architecture** (design decision, structural change). Default: code.

Create a task per enhancement to track progress.

---

## Step 1: Plan (parallel, `model: "opus"`, `isolation: "worktree"`)

Branch: `enhancement/<kebab-slug>` derived from enhancement description.

### CODE enhancements produce:

| Artifact | Path | Content |
|----------|------|---------|
| Pseudo-code | `plan/pseudocode.md` | Logical pattern scaffold (see `${PSEUDOCODE_SKILL}/SKILL.md`) |
| Prolog analysis | `plan/reasoning.pl` | C4 facts following orbital flow (3 loops: Find → Define → Condense) |
| Lean4 proofs | `${LEAN_PROOFS}/<Enhancement>.lean` | Invariant theorems + tactic proofs; `sorry` only with justification |
| Proof summary | `plan/proof_summary.md` | Proved vs sorry-stubbed invariants, strategies, file path |

Prolog orbital flow: write C4 facts (`${PROLOG_TEMPLATE}` format) → `validate` until PASS → `summary`/`describe`/`coupling`/`crosscut` → `full <targets>` for CHANGE SCOPE, IMPACT, ORDER.

Lean: `.lean` with `set_option autoImplicit false`, `import Mathlib`, theorems + tactics → `lake build` (self-correct up to 5x, use `exact?`/`apply?`/`simp?`).

### ARCHITECTURE enhancements produce:

| Artifact | Path | Content |
|----------|------|---------|
| Solutions | `plan/solutions.md` | ≥3 candidates with pros/cons/tradeoffs |
| Prolog analysis | `plan/reasoning.pl` | Candidates as facts + ranking rules → `validate` + `summary` |
| Recommendations | `plan/recommendations.md` | Prolog-derived ranking, rationale, risks, open questions |

### Plan agent prompt

```
You are the PLAN agent for: "{ENHANCEMENT}"
Type: {TYPE} | Branch: {BRANCH}

Produce artifacts in `plan/` (Lean proofs go in ${LEAN_PROOFS}).

Pseudocode: Read ${PSEUDOCODE_SKILL}/SKILL.md and follow its process to produce plan/pseudocode.md

Prolog: ${PROLOG_QUERY} <facts_file> <command>
  Template: ${PROLOG_TEMPLATE}
  Orbital flow: write facts → validate → summary/describe/coupling/crosscut → full <targets>

Lean: write to ${LEAN_PROOFS}/<name>.lean → cd ${LEAN_PROJECT} && lake build
  Self-correct up to 5x. Use exact?/apply?/simp? to discover lemmas.

FOR CODE: pseudocode.md (via scaffold-pseudocode) → reasoning.pl (3 loops) → .lean proofs → proof_summary.md
FOR ARCHITECTURE: solutions.md (≥3) → reasoning.pl (validate+summary) → recommendations.md

Do NOT implement code. Do NOT modify files outside plan/ (except Lean proofs).
Output a one-paragraph summary when done.
```

---

## Step 2: Review + Iterate (`model: "opus"`, max 3 rounds)

After all plan agents complete, spawn one review agent per enhancement in the same worktree. This is a **structured alignment check**, not a general code review.

### Review agent prompt

```
You are the REVIEW agent for: "{ENHANCEMENT}"
Worktree: {WORKTREE_PATH}
Original requirement: {ENHANCEMENT_DESCRIPTION}

Check alignment: does each artifact in plan/ faithfully address the requirement?
Are artifacts consistent with each other (pseudocode ↔ prolog ↔ lean/recommendations)?
Are there requirement gaps not covered by any artifact?

Verify: ${PROLOG_QUERY} plan/reasoning.pl validate && cd ${LEAN_PROJECT} && lake build

Write plan/review.md:
- Alignment matrix: | Requirement aspect | artifact coverage | Aligned? |
- Gaps: unaddressed requirements or inter-artifact contradictions
- Risks (ranked) and Open Questions (for human)
- Recommendation: APPROVE | REVISE (list specific artifact changes) | REJECT (why unsalvageable)
```

### Iteration loop

On **REVISE**, spawn a revision agent (same worktree, `model: "opus"`):
```
REVISION agent for: "{ENHANCEMENT}" | Worktree: {WORKTREE_PATH}
Read plan/review.md. Revise ONLY flagged artifacts. Re-run Prolog validate + Lean build.
Output what changed and why.
```
Then re-run the review agent. Repeat until APPROVE/REJECT or 3 rounds. If exhausted, present current state to human with iteration history. Update task status each round.

### Timed iteration

If the user specifies a duration ("iterate for 30m", "refine for 1h"), use CronCreate (`recurring: true`, interval = duration ÷ 6, clamped ≥2m). Each fire runs one revise+review pass per REVISE enhancement. CronDelete when all converge or duration expires → Step 3. Report job ID for early cancellation.

---

## Step 3: Human Vetting (MANDATORY PAUSE)

After all reviews converge, present each enhancement's `plan/review.md` with branch, type, and iteration count. Ask:
> Which enhancements should I implement? ("approve all" / "approve 1, 3" / "reject 2" / add conditions)

**Do not proceed until the user responds.**

---

## Step 4: Implement (parallel, `model: "sonnet"`, approved only)

```
You are the IMPLEMENT agent for: "{ENHANCEMENT}"
Worktree: {WORKTREE_PATH} | Branch: {BRANCH}

Read all plan/ artifacts and plan/review.md.

{If conditions:}
Human conditions: {CONDITIONS}

Implement the enhancement following the plan precisely.
- Minimal code, no speculative abstractions
- Do not modify plan/

Output a summary of changes.
```

---

## Step 5: Commit (parallel, `model: "haiku"`)

```
You are the COMMIT agent for: "{ENHANCEMENT}"
Worktree: {WORKTREE_PATH} | Branch: {BRANCH}

Organize unstaged changes into logical commits.
Commit messages explain *why* not *what*. No Co-Authored-By trailers.
```

---

## Orchestration Rules

1. Spawn all plan agents in parallel (Step 1), then all review agents in parallel (Step 2).
2. **Never skip human vetting** — Step 3 is a hard gate.
3. Steps 4 and 5 run in parallel across approved enhancements.
4. Track each enhancement with TaskCreate/TaskUpdate.
5. Reuse worktree paths from Step 1 across all subsequent steps.
6. Failed agents → mark FAILED, continue others, report at vetting pause.
7. Always pass `model` explicitly on every Agent call.
