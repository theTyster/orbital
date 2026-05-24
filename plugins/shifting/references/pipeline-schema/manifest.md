# `thoughts/tests/manifest.pl` schema

Carrier-widened sidecar for the `thoughts/tests/` directory. Emitted by
`instantiate-properties` (stage 5), consumed by `realize-specification`
(stage 6) and the `realize-test-briefer` sub-agent. **Always present
after a stage-5 run, even on the happy path** — the file is the
load-bearing carrier signal that stage 5 completed.

## Two record families

### 1. `descends_from(TestFileBasename, ArtifactPath)` — required

Named `descends_from/2` rather than `artifact_provenance/2` because the
second argument is a source path (unbounded) rather than an epistemic
kind (small enumeration). The `_provenance` family is reserved for
entity → kind tagging (`negation_provenance(_, absent | contradicts)`);
file-lineage relations are a different shape. The cwa-owa essay's
existing English already uses "descend" — the predicate matches the
prose.

One row per upstream `.pl` artifact the test file transitively depends
on. At minimum the file MUST carry one `descends_from/2` row naming
`lean_proof_results.pl` (the stage-5 mandatory input). Additional rows
for `hypothesis.pl`, `model_results.pl`, and `target-world.pl` MUST be
emitted when `instantiate-properties` consulted those artifacts during
Step 1 of its run.

```prolog
descends_from('test_admin_surface.py', 'thoughts/lean_proof_results.pl').
descends_from('test_admin_surface.py', 'thoughts/hypothesis.pl').
descends_from('test_admin_surface.py', 'thoughts/target-world.pl').
```

`TestFileBasename` is the leaf filename without directory components.
`ArtifactPath` is the project-relative path the producer actually read.

### 2. `upstream_gap(EmittingStage, GapDescriptor, RecoveryHint)` — optional

Gap-emission sidecar — unchanged from the existing
`instantiate-properties` contract. Empty when the producer run
is clean. See `../../skills/instantiate-properties/SKILL.md` §
"Orchestrator contract → Upstream gap emissions" for the full
catalogue.

## Emission rules

- Citation records (`descends_from/2`) come FIRST in the file; gap
  records (`upstream_gap/3`) come LAST.
- File MUST be valid Prolog (loads cleanly under
  `swipl --on-warning=status --on-error=status -g "consult(...), halt"`).
- File MUST exist after every `instantiate-properties` run that
  emitted at least one test file. A missing manifest is a halt-loud
  signal for `realize-specification` (see "Consumer contract" below).

## Consumer contract

`realize-specification`'s Stage-0 pre-flight checks
`thoughts/tests/manifest.pl` exists and contains at least one
`descends_from/2` row. Missing or empty file → halt with attribution
to `instantiate-properties` Step "Emit the manifest".

`realize-test-briefer` follows `descends_from/2` rows when assembling
per-test briefings. It never re-derives citation paths from
test-comment tags; tags name the *claims* / *theorems* / *fixtures*
the test descends from, while the manifest names the *files* those
references resolve into.

## Validator enforcement

`kb-validator` Tier-4 rules (to be added in a follow-up ticket post
Wave 1):

1. **Empty-manifest detection.** Manifest exists but carries zero
   `descends_from/2` rows. Warn (not reject — the missing-file case
   is already covered by stage-6 pre-flight).
2. **Dangling-citation detection.** A `descends_from/2` row names a
   file path that does not exist on disk. Warn.

Both rules join the same Tier-4 family as the C7
`endpoint_requires_permission/2` arity check and the C6.5 binding-style
mismatch check.
