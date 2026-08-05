# Strict Loading — Treat Warnings as Failures

A Prolog KB that loads with warnings is a KB whose downstream queries and proofs cannot be trusted. Singletons hide typos. Discontiguous warnings hide accidental predicate splits. Undefined-procedure warnings hide rules that quietly fail forever. SWI emits all of these as **warnings**, not errors — under a default `swipl -g halt <file>` invocation they print to stderr and the exit code stays 0. Strict loading promotes them to load failures.

## The Contract

A KB file is **valid** only if it loads under:

```bash
swipl --on-warning=status --on-error=status -q \
  -g "[ '<file.pl>' ]" \
  -t halt
```

with exit code 0.

- `--on-warning=status` — every emitted warning bumps the exit code.
- `--on-error=status` — every error does the same (defensive; load errors usually halt anyway).
- `-q` — suppress the welcome banner so stderr stays signal-only.
- `-g "[ '<file>' ]"` — consult the file. Quote the path; brackets are list syntax.
- `-t halt` — top-level goal is `halt`, so the process exits when consult finishes.

If you want the process to stop at the **first** warning (good for tight iteration) instead of accumulating all of them (good for a one-pass clean-up), swap `--on-warning=status` for `--on-warning=halt`.

## What Strict Loading Catches

### Singleton variables

```prolog
% Flagged: Audit appears only once in this clause.
build_dependent_records(Audit, Case, addition, DepRecords) :-
    !,
    current_paid_dependents(Case, Deps),
    maplist(build_dep_record(addition), Deps, DepRecords).
```

Fix: rename to `_Audit` (intentionally unused) or use it. The leading underscore is the explicit "unused on purpose" marker; SWI's singleton check skips names that start with `_`.

This is the most common silent bug in hand-written KBs. A typo like `dpends_on` instead of `depends_on` shows up as a singleton in the surrounding clause — strict mode turns "weird query result" into "load failure" with a line number.

### Discontiguous predicates

```prolog
module(auth).
service(api).
module(crypto).   % Warning: clauses for module/1 are not contiguous.
```

Fix: group all clauses for a predicate together, or add `:- discontiguous module/1.` if the interleaving is intentional. Discontiguous warnings often expose accidental copy-paste duplication where a fact got pasted into the wrong section.

### Undefined procedures

```prolog
:- check_kb_consistency.   % If check_kb_consistency/0 isn't defined, warning.
```

A directive that calls an undefined predicate succeeds-by-failing under default settings. Strict mode makes it a load failure — which is what you want, because a never-run validation rule is worse than no rule at all.

### Unbalanced operators / syntax oddities

Missing periods, mismatched parentheses, and unknown operators all surface here. Strict mode just makes sure you don't ignore them.

## When to Relax

Three legitimate reasons to allow a specific warning:

1. **Intentional unused variable** — prefix with `_` (e.g. `_Audit`). This is not a relaxation, it is the documented escape hatch.
2. **Intentional discontiguity** — declare `:- discontiguous pred/arity.` at the top of the file.
3. **Forward references in a multi-file KB** — declare `:- multifile pred/arity.` and `:- discontiguous pred/arity.` so the loader knows the predicate's clauses span files.

If you find yourself wanting to relax beyond these three, the KB has a real problem — fix the KB, not the validator.

## Who Must Pass This Contract

Every agent in the `orbital-shifting` plugin that **produces** a `.pl` file must gate its output on this contract before declaring success:

- **`agent-of-truth`** — the KB it writes (typically `thoughts/existing-world.pl`) must strict-load. A singleton in a fact-extraction clause means a typo'd predicate name silently dropped facts on the floor; downstream queries will return "no solutions" with no indication why.
- **`prolog-prover`** — the proof file it writes (the one defining `violates_property/1` and the `findall` directive) must strict-load. A singleton in a violation rule means the property is checking the wrong thing — the search will find no counterexamples not because none exist, but because the rule never matches anything. A `[VERIFIED]` line under those conditions is a false positive, and the worst possible failure mode for a proof system.

The pattern is the same in both cases: the agent appends to its file, runs the strict load, and only proceeds when exit is 0. This is what stops silent typos from accumulating across a long file and only surfacing as inscrutable downstream behavior.

## Quick Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `Singleton variables: [X]` | typo or unused arg | rename to `_X` or use `X` |
| `Clauses of P/N are not together` | predicate split across file | regroup, or `:- discontiguous P/N.` |
| `Goal (directive) failed: P` | directive called undefined predicate | define it, or remove the directive |
| `Unknown procedure: P/N` (at runtime) | misspelled call | grep for the misspelling |
| `Operator expected` / `Full stop in atom` | missing `.` or stray punctuation | check end-of-clause periods |
