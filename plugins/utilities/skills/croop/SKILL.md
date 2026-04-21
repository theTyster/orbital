---
name: croop
description: >
  Use this skill (or /croop) whenever the user wants a bounded refinement loop with an explicit stop condition — "every N minutes for M hours until Y", "closed loop", "refinement loop until done", or "iterate until score reaches Z". Schedules a prompt on a recurring inner interval bounded by an outer duration that auto-cancels. Requires a measurable stop condition; unlike /loop.
user-invocable: true
allowed-tools: CronCreate, CronList, CronDelete
argument-hint: <outer_duration> [inner_interval] <prompt>
---

# croop — Cron-Closed Loop

Schedule a prompt to run on a recurring inner interval, bounded by an outer duration that clears every cron job in this session when it fires. Think of it as an hourglass around a metronome: the metronome ticks until the sand runs out, then everything stops.

## Arguments

ARGUMENTS contain (in order):

1. **outer_duration** (required) — total wall-clock time the loop should run. Format: `30s`, `5m`, `2h`, `1h30m`, etc.
2. **inner_interval** (optional, default `1m`) — how often to fire the prompt. Same format as outer.
3. **prompt** — the remainder of the arguments is the prompt to run on each tick. Can be a slash command (e.g. `/foo`), a natural-language instruction, or a mix.

### Disambiguation

The first token is always `outer_duration`. The second token is `inner_interval` **only if** it parses as a duration (matches `^\d+[smh]`, optionally chained like `1h30m`). Otherwise it's the start of the prompt and `inner_interval` defaults to `1m`.

Examples:

| Input | outer | inner | prompt |
| --- | --- | --- | --- |
| `30m /babysit-prs` | 30m | 1m | `/babysit-prs` |
| `1h 5m check deploy status` | 1h | 5m | `check deploy status` |
| `2h 10m /run-tests` | 2h | 10m | `/run-tests` |
| `45m summarize PR #123` | 45m | 1m | `summarize PR #123` |

## Invariants

Enforce before scheduling anything. If any fail, explain the problem and stop — do not schedule a partial loop.

1. **Outer must parse** as a positive duration.
2. **Inner must parse** as a positive duration, defaulting to 60 seconds if absent.
3. **Inner < outer.** A loop whose tick exceeds its lifespan would never fire.
4. **Prompt must be non-empty.** Nothing to repeat means nothing to schedule.
5. **The prompt must declare a refinement target and a progress signal.** A closed loop without feedback is just a cron job pointed at a wall. Before scheduling, the prompt must answer two questions explicitly:
   - **What is being refined?** (the artifact, metric, or state under improvement — e.g. "the PR description at #482", "the P99 latency on /checkout", "the draft at notes/intro.md")
   - **How will each tick know it's making progress?** (the measurable signal — e.g. "word count drops", "the failing test named X passes", "grep for TODO returns fewer lines", "the benchmark score printed by `make bench` increases")

   If the user's input omits either, **do not schedule**. Ask for the missing piece in one short question, then schedule once they answer. Do not invent a refinement target on the user's behalf — guessing here means the loop burns compute on the wrong thing.

   When you do schedule, prepend a short preamble to the per-tick prompt so every fire reminds the running agent of both:

   ```
   Refinement target: <what>
   Progress signal: <how to tell it's improving>

   <user's original prompt>
   ```

## Workflow

### 1. Parse and validate

Convert `outer_duration` and `inner_interval` to seconds. Confirm all invariants above, including #5 (refinement target + progress signal). If the target or signal is missing, pause and ask for it before touching the scheduler.

Once everything is in hand, surface the parsed values back to the user in one line so they can catch a misread:

> Refining `<target>` every `<inner>` for the next `<outer>`, tracking `<signal>` — will auto-stop at approximately `<HH:MM local>`.

### 2. Schedule the inner (recurring) job

Pick a cron expression based on `inner_interval`:

- `< 1m`: not supported by 5-field cron — round up to `* * * * *` (every minute) and tell the user.
- `N minutes` where `N` divides 60 cleanly: `*/N * * * *`
- `N minutes` where `N` does not divide 60 (e.g. 7, 13): fall back to the nearest divisor and tell the user which one you picked, OR schedule multiple overlapping crons — prefer the simple fallback.
- `N hours`: `0 */N * * *` (on the hour). If the user asked for something unusual, pick an off-minute like `7 */N * * *` per the CronCreate guidance on avoiding :00.
- Fractional hours (`1h30m`): convert to minutes if divides 60, otherwise use the nearest minute divisor.

Call `CronCreate` with:
- `cron`: the expression above
- `prompt`: the user's prompt, verbatim
- `recurring`: `true`
- `durable`: `false` (session-only — croop loops are ephemeral by design)

Capture the returned job ID.

### 3. Schedule the outer (one-shot) stopper

The outer job is a one-shot timer: compute `now + outer_duration` as a concrete minute/hour/day/month, then schedule a non-recurring cron at that instant whose prompt tells the next Claude turn to tear everything down.

Call `CronCreate` with:
- `cron`: `"<minute> <hour> <dom> <month> *"` pinned to the wall-clock instant of expiry
- `prompt`: a teardown instruction, e.g.
  > "croop outer loop expired — call CronList, then CronDelete every job returned. Report which jobs were cleared. Do not schedule anything new."
- `recurring`: `false`
- `durable`: `false`

The teardown prompt deliberately clears **all** session cron jobs, matching the user's spec ("the outer loop will simply clear all cronjobs for this session"). A user running multiple croops concurrently should know that the first outer expiry wipes the others too — mention this if you schedule a second croop while one is active (check with `CronList` first).

### 4. Confirm

Report both job IDs and the expected stop time. The user should be able to cancel early with `CronDelete` against either ID.

## Duration parsing

Accept `s`, `m`, `h`. Allow chains like `1h30m` or `2h15m30s`. Reject bare numbers — require a unit so `5` is never ambiguous between seconds and minutes.

Reference mapping:
- `30s` → 30
- `5m` → 300
- `1h` → 3600
- `1h30m` → 5400
- `2h15m30s` → 8130

## Rationale

Two crons, one job. The inner cron does the work; the outer cron is a self-destruct fuse. This separation keeps the model out of the critical path — the scheduler handles both ticks and teardown deterministically, so the loop stops even if Claude is mid-thought on an unrelated task when the timer fires.

Keeping durability off is deliberate: these loops are usually "watch this for a bit" tasks, not background daemons. If the session ends, the loop ending with it is the right behavior. If the user explicitly says "keep this going across restarts," escalate — croop's default is wrong for that case and a durable scheduler needs explicit acknowledgement.

## Edge cases

- **Outer < 1 minute**: cron resolution is 1 minute. Refuse and explain.
- **Inner == outer**: violates invariant 3. Refuse.
- **User provides three duration-shaped tokens** (e.g. `30m 5m 1m do X`): treat the first as outer, second as inner, third+ as prompt. If the prompt starts with a duration-looking string the user meant literally, they can quote it.
- **Existing crons already scheduled**: run `CronList` first. If other jobs exist, warn the user that the outer teardown will clear them too, and ask whether to proceed or narrow the teardown to just the croop inner job. Narrowing means the teardown prompt should say "CronDelete <inner_job_id>" instead of "clear every job".
