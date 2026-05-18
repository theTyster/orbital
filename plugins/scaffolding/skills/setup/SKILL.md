---
name: setup
description: >
  First-time bootstrap for an adopter who just installed the orbital marketplace
  and needs to provision the silent prerequisites every pipeline skill assumes.
  Interviews the user, then idempotently creates `thoughts/`, appends `.gitignore`
  entries, optionally adds a Claude Code hook, and delegates to the Lean setup
  skills if the proof backend is wanted. Use whenever the user says: "set up
  orbital", "first-time setup", "install orbital dependencies", "bootstrap
  orbital", "configure orbital for this project", "what do I need to install",
  "doctor / health check the install", or has clearly just run
  `/install-plugin` and is trying to figure out what comes next. Also trigger
  proactively when a pipeline skill (close-world, decompose-proposition,
  prove-invariants, etc.) fails on a missing prerequisite like an absent
  `thoughts/` directory, missing `swipl`, or no Mathlib clone.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Skill, AskUserQuestion
argument-hint: "[--check]"
model: sonnet
effort: medium
---

# setup

Bootstrap an adopter project so the orbital plugins work out of the box. The
orbital marketplace has several **quiet dependencies** — a `thoughts/` artifact
directory, `.gitignore` entries, external binaries, a shared Mathlib clone —
that every pipeline skill silently assumes. This skill discovers what is
missing, interviews the adopter about what they actually plan to use, and
either provisions the missing pieces or prints the exact commands the user
needs to run.

The skill is **idempotent**: re-running it on a configured project just prints
"OK" for every check. It is also **non-destructive**: anything that mutates the
adopter's repo or shell environment goes through a confirmation step that
shows a diff first.

## Modes

Two invocation modes:

- **`setup`** — interactive provisioning. Asks the user what they want, then
  acts.
- **`setup --check`** — read-only audit. Prints a punch list of what is
  missing and stops. No mutations. Useful as a "doctor" / "health check".

If `--check` was passed (visible in the argument hint context), skip every
mutation in the steps below and emit only the readiness report at the end.

## Step 1: Detect the host platform

```bash
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin)  PKG_HINT="brew install" ;;
  Linux)   PKG_HINT="apt install   # or dnf install, pacman -S, etc." ;;
  MINGW*|MSYS*|CYGWIN*) PKG_HINT="see vendor docs — Windows install varies" ;;
  *)       PKG_HINT="see vendor docs for $PLATFORM" ;;
esac
echo "Platform: $PLATFORM  |  install hint: $PKG_HINT"
```

The hint is informational — never run package-manager commands without
explicit user consent in Step 5.

## Step 2: Interview — which plugins is the adopter using?

Use `AskUserQuestion` with one multi-select question:

> Which orbital plugins do you plan to use in this project?
> - shifting (formal logic pipeline)
> - scaffolding (C4 architectural analysis)
> - trajectory (single-ticket pipeline orchestration)
> - telemetry (commits, presentations, loops)

The answer narrows which checks matter:

| Plugin selected | Prerequisites that become relevant |
| --- | --- |
| any | `thoughts/` directory, `.gitignore` entries |
| shifting, scaffolding, trajectory | `swipl` |
| shifting (Lean path), trajectory | `elan`, `lean`, `python3`, shared Mathlib clone, `thoughts/lean/` project |
| shifting | `jq` (for the artifact-staleness gatekeeper hook — fail-open if absent) |
| any (user preference) | `toon` if the user's global CLAUDE.md mentions it |

If the user picks shifting, ask a follow-up:

> Which shifting proof backend will you use?
> - Lean 4 (mathematical / abstract proofs)
> - Prolog only (relational / structural verification)
> - Both

Skip the Lean toolchain checks entirely for "Prolog only".

## Step 3: Run detection probes

Run only the probes that the interview marked relevant. Each probe is a single
`command -v` or `test` call so the audit is fast and side-effect-free.

**Idempotency fast path:** before probing, consult the existing marker. If
`.claude/orbital-setup.json` already records a prereq as `"ok"`, skip the
probe and trust the marker. The user can force a re-probe by deleting the
marker file. The helper at `${CLAUDE_SKILL_DIR}/scripts/check-setup.sh
<prereq>` returns 0 when the marker reports the prereq is provisioned.

```bash
have() { command -v "$1" >/dev/null 2>&1 && echo OK || echo MISSING; }

echo "swipl:    $(have swipl)"      # shifting, scaffolding
echo "elan:     $(have elan)"       # shifting Lean path
echo "lean:     $(have lean)"       # shifting Lean path
echo "python3:  $(have python3)"    # shifting Lean path
echo "jq:       $(have jq)"         # shifting gatekeeper hook
echo "toon:     $(have toon)"       # user's global preference
echo "git:      $(have git)"        # universal
echo "curl:     $(have curl)"       # universal

test -d "$HOME/.lean/mathlib4"            && echo "mathlib clone: OK"          || echo "mathlib clone: MISSING"
test -d thoughts                           && echo "thoughts/:      OK"          || echo "thoughts/:      MISSING"
test -d thoughts/lean                      && echo "thoughts/lean/: OK"          || echo "thoughts/lean/: MISSING"
[ -f .gitignore ] && grep -qE '^thoughts/?$' .gitignore \
                                           && echo "gitignore:     OK"          || echo "gitignore:     MISSING"
```

Record each result in a small table — it is reused in the final readiness
report in Step 7.

## Step 4: Create `thoughts/` (with `.gitkeep`)

The `thoughts/` directory is where every pipeline skill writes its artifacts
(`existing-world.pl`, `hypothesis.pl`, `target-world.pl`, `lean/`,
`adherence_report.md`, …). If it does not exist, pipeline skills crash on
first write.

If missing, create it:

```bash
mkdir -p thoughts
touch thoughts/.gitkeep
```

This step does not need confirmation — it is a no-op on existing setups and
the only mutation is creating a single empty directory the plugins were going
to create anyway.

## Step 5: Append `.gitignore` entries (with confirmation)

The adopter almost always wants pipeline artifacts and build output excluded
from git. The canonical patterns are:

```
thoughts/
*.local.*
.lake/
lake-packages/
```

Process:

1. Read the adopter's `.gitignore` (create if missing).
2. Compute which of the four patterns are not already present (treat
   `thoughts` and `thoughts/` as equivalent).
3. If any are missing, show the user the **exact diff** that will be appended
   and use `AskUserQuestion` to confirm:

   > Append these lines to `.gitignore`?
   > - Yes, append
   > - Skip — I'll edit `.gitignore` myself

4. On confirmation, append the missing lines under a header comment:

   ```
   # orbital — pipeline artifacts and build output
   thoughts/
   *.local.*
   .lake/
   lake-packages/
   ```

If all four are already present, log "OK" and skip the prompt entirely.

## Step 6: Print install commands for missing binaries

**Do not run installer commands automatically.** Print a copy-pasteable block
of OS-appropriate commands for every binary that came back `MISSING` in
Step 3, then ask the user to run them out of band.

Example for darwin with `swipl` and `jq` missing and the Lean path selected:

```
The following binaries are missing. Run these commands yourself (orbital will
not run package-manager commands for you):

  brew install swi-prolog jq
  curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
```

Why this is a print-and-confirm rather than an auto-run:

- Package managers vary across platforms (`brew`, `apt`, `dnf`, `pacman`,
  `winget`, `scoop`) and across hosts within the same platform (homebrew vs
  MacPorts). Picking the wrong one causes more harm than asking the user.
- `elan` writes to `$HOME` and modifies shell rc files — that warrants
  explicit user action.
- `toon` is the user's global preference but not an orbital dependency; just
  mention it as recommended.

After printing the block, use `AskUserQuestion`:

> Have you installed the missing binaries?
> - Yes, continue
> - Skip for now — I'll install later

If skipped, the readiness report at the end will mark those prereqs as
`user-action-needed`.

## Step 7: Lean path — delegate to existing skills

If the adopter chose the Lean proof backend in Step 2, the heavy lifting is
already encoded in two existing skills. **Do not duplicate their logic.**
Both now live in the scaffolding plugin alongside this one. Invoke them via
the `Skill` tool in order:

1. `scaffolding:setup-lean-mathlib` — provisions `~/.lean/mathlib4` if absent.
   This is the multi-hour step (pre-built oleans are downloaded, not
   compiled). Skip if the clone already exists.
2. `scaffolding:setup-lean-project` — provisions `thoughts/lean/` referencing
   the shared clone. Cheap. Skip if `thoughts/lean/.lake/build/` already
   exists.

If the adopter wants the optional `lake update` blocker hook (described in
`setup-lean-mathlib`), use `AskUserQuestion`:

> Add the `lake update` blocker hook to `.claude/settings.json`? It prevents
> accidental re-download of all Mathlib dependencies.
> - Yes, add it
> - Skip — I don't want to touch `.claude/settings.json`

If yes, show the diff first (read existing `settings.json`, compute the
merged `hooks.PreToolUse` array, present the JSON delta), confirm again,
then write. The exact hook body is in
`plugins/scaffolding/skills/setup-lean-mathlib/SKILL.md` — copy it verbatim.

The shifting plugin's **artifact-staleness gatekeeper hook** does **not**
need adopter action: it is bundled in the plugin and auto-loads via
`plugins/shifting/hooks/hooks.json`. This is a separate concern from the
setup-completion marker introduced below — it polices artifact *freshness*
across pipeline runs, not whether setup itself is done. Mention it so the
adopter knows the hook is there and how to opt out:

```
The shifting plugin installs a PreToolUse hook that blocks reads of stale
pipeline artifacts (e.g., reading hypothesis.pl when existing-world.pl is
newer). It is fail-open if jq is missing. Opt out per session with:

  export SHIFTING_GATEKEEPER=off
```

## Step 8: Write the setup-completion marker

Once every relevant prerequisite is either **OK** or **installed-this-run**,
write `.claude/orbital-setup.json` so downstream skills can verify "setup is
done" with a single cheap check instead of re-probing every binary.

Schema (extend cautiously — bump the top-level `version` if you add fields):

```json
{
  "version": 1,
  "completed_at": "2026-05-18T13:42:00Z",
  "plugins_selected": ["shifting", "scaffolding"],
  "lean_backend": true,
  "prereqs": {
    "thoughts_dir": "ok",
    "gitignore": "ok",
    "swipl": "ok",
    "elan": "ok",
    "lean": "ok",
    "python3": "ok",
    "jq": "ok",
    "toon": "ok",
    "mathlib_clone": "/Users/ty/.lean/mathlib4",
    "lean_project": "thoughts/lean",
    "shifting_gatekeeper_hook": "bundled",
    "lake_update_blocker_hook": "user-declined"
  }
}
```

Values:

- `"ok"` — provisioned and verified
- a path string — same as "ok" but records the resolved location (useful for
  `mathlib_clone` and `lean_project`)
- `"user-action-needed"` — the user must install or configure this
- `"skipped"` — not relevant to the selected plugins
- `"user-declined"` — the user was asked and said no

Only write the marker if at least one prereq is `"ok"`. If every relevant
prereq is `user-action-needed`, do not write the marker; the readiness report
already names what's blocking and a future re-run can finalize.

If `.claude/` does not exist, create it. Do not write `.claude/settings.json`
or any other Claude Code config from scratch in this step — only the marker.

## Step 9: Readiness report

Emit a single concise table summarizing every prerequisite that was relevant
to this adopter's plugin selection. One row per prereq, one of four statuses:

- **OK** — was already in place
- **installed-this-run** — orbital created it during this session (e.g.,
  `thoughts/`, `.gitignore` entries, Lean project)
- **user-action-needed** — printed install command, awaiting the user
- **skipped** — not relevant to the selected plugins

Example:

```
orbital — readiness report

  thoughts/                            OK
  .gitignore entries                   installed-this-run
  swipl                                OK
  elan + lean                          user-action-needed
  python3                              OK
  jq                                   user-action-needed
  toon (optional)                      user-action-needed
  ~/.lean/mathlib4 (Mathlib clone)     skipped — install elan first
  thoughts/lean (Lean project)         skipped — depends on Mathlib clone
  shifting gatekeeper hook             OK (bundled with plugin)
  lake update blocker hook (optional)  skipped

Next steps:
  1. brew install jq
  2. curl -sSf https://…/elan-init.sh | sh
  3. Re-run /setup to finish the Lean side
```

End there. Do not auto-loop back into the skill.

## Idempotency contract

A second invocation of `setup` on a clean adopter project should produce a
report where every row is **OK** and ask zero confirmation questions. If a
later run prompts for something it already configured, that is a bug — the
detection probe in Step 3 needs to be tightened.

The two non-obvious idempotency rules:

- `.gitignore` matching is line-anchored and treats `thoughts` and
  `thoughts/` as equivalent. Don't accidentally append duplicates because of
  trailing-slash differences.
- The `lake update` blocker hook is detected by the exact `command` string,
  not by the matcher pattern — multiple hooks can share a matcher, and the
  adopter may already have other hooks under `PreToolUse > Bash`.

## The marker is the single source of truth

After Step 8 writes `.claude/orbital-setup.json`, every other orbital skill
should consult it via `scaffolding/skills/setup/scripts/check-setup.sh`
instead of running its own detection probes. This is what makes the "one
setup, no constant rechecking" promise hold across the marketplace:

- `prove-invariants` checks `mathlib_clone` and `lean_project`
- `close-world`, `decompose-proposition`, `instantiate-properties`,
  `measure-entailment` check `swipl`
- Agents that shell out (`prolog-prover`, `lean-expert`, `agent-of-truth`,
  …) check the relevant binary

If a skill is asked to run and the marker says its prereq is **not** `ok`,
the skill should print a single line — "Run `/setup` first" — and stop,
rather than emit a wall of detection output. This keeps the failure mode
sharp and the recovery action obvious.

The marker is **not** the artifact-staleness gatekeeper (`SHIFTING_GATEKEEPER`,
`plugins/shifting/hooks/scripts/check-chain.sh`). Those are two independent
mechanisms with different scopes:

| Mechanism | Scope | When it fires |
| --- | --- | --- |
| `.claude/orbital-setup.json` (this skill) | "Is the environment provisioned?" | Once, at session start (via the scaffolding SessionStart hook) and on demand by skills |
| `SHIFTING_GATEKEEPER` PreToolUse hook | "Are pipeline artifacts mutually consistent?" | Before every `Read`/`Bash` during pipeline execution |

A common confusion: `SHIFTING_GATEKEEPER` does not record whether setup is
done — it gates *data freshness*. The marker file introduced here is the
right place to record setup completeness.

## What this skill deliberately does not do

- It does not run `brew install`, `apt install`, `curl | sh`, or any other
  package-manager command. The user runs those themselves after seeing the
  printed block.
- It does not create `.claude/settings.json` from scratch — only merges into
  an existing one. If the adopter has never configured Claude Code, that
  file does not exist and the hook step is skipped with a note.
- It does not edit any source code in the adopter's project.
- It does not install or update any orbital plugin — that is the plugin
  manager's job (`/install-plugin`, `/plugin update`).
- It does not perform the `setup-lean-mathlib` or `setup-lean-project` work
  inline. Those are delegated via the `Skill` tool so their logic stays
  authoritative in one place.
