---
description: Read-only diagnostic table of all mission-control channels.
argument-hint: "(no arguments)"
allowed-tools: Bash, Read
---

Diagnose every active mission-control channel and print a one-line summary per
channel. Read-only — no state mutations.

## Where to look

This command runs on either side (Mission Control / Astronaut) but inspects
different roots depending on context:

- **Mission Control side (Mission Control):** iterate every subdirectory under
  `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/` that does NOT start with `.`
  (i.e., exclude `.archive/` and any other dot-prefixed entries). Each
  subdirectory's `state.json` is one channel.
- **Astronaut side (project):** check for `./thoughts/.mission-control-state.json`.
  If absent, this project has no active channel. If present, treat it as a
  single channel.

When both roots are present (e.g., a developer running this command from inside
the Mission Control repository while also having an astronaut state file), iterate the
Mission Control side first and include the astronaut file in the same sweep.

If neither root exists (or both exist but are empty / the astronaut file is
absent), print exactly:

```
No active channels.
```

and stop.

## How to read each channel

For each channel's `state.json` path (call it `<state-path>`):

1. **Run diagnose-state:**

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/diagnose-state.sh" "<state-path>"
   ```

   Capture stdout as `diag_json`. The script always exits 0 and emits a JSON
   object; a non-zero exit or malformed output is a per-pair fault (see below).

2. **Extract PID values directly** (diagnose-state.sh reports liveness booleans
   but does NOT include the raw PID numbers):

   ```bash
   our_pid=$(jq -r '.our_pid // "-"' "<state-path>")
   their_pid=$(jq -r '.their_pid // "-"' "<state-path>")
   ```

   If `state.json` is absent or malformed at this point the channel will already
   have triggered the fault-isolation path in step 1.

3. **Extract table fields from `diag_json`:**

   ```bash
   channel=$(echo "$diag_json"  | jq -r '.channel         // "-"')
   diag=$(echo "$diag_json"     | jq -r '.diagnosis        // "-"')
   last_in=$(echo "$diag_json"  | jq -r '.last_seq_in      // "-"')
   last_out=$(echo "$diag_json" | jq -r '.last_seq_out     // "-"')
   action=$(echo "$diag_json"   | jq -r '.suggested_action // "-"')
   ```

## Per-pair fault isolation discipline

If a channel's `diagnose-state.sh` exits non-zero, or its JSON output is
malformed, or reading the channel directory fails for any reason, render that
row as:

```
<channel-name-or-path> | ERROR | - | - | - / - | inspect <state-path>
```

Then **continue iterating** the remaining channels. Do NOT abort the whole
status sweep because one channel is corrupt.

Use `(commands/status.md §iteration)` as the attribution prefix in any
error message printed to stderr for that row.

## Table format

Print a markdown table with this header:

```
| Channel | Diagnosis | Our PID | Peer PID | Last in / out seq | Suggested action |
|---------|-----------|---------|----------|-------------------|------------------|
```

One row per channel. The `Last in / out seq` cell is `<last_in> / <last_out>`.

When `state_exists` is `false` (i.e., `diagnosis` is `not-init`), all numeric
fields render as `-`.

Example rows:

```
| orbital | healthy            | 48291 | 48317 | 7 / 9   | continue             |
| kimmy   | peer-crashed       | 48422 | -     | 12 / 12 | resync               |
| c-f-a   | not-init           | -     | -     | - / -   | initialize           |
```

## Trailing legend

After the table, if any row's `diagnosis` is **not** `healthy` and **not**
`not-init`, print one attribution line per distinct non-healthy/non-init
diagnosis value:

```
<diagnosis> attributed by scripts/diagnose-state.sh
```

Example:

```
peer-crashed attributed by scripts/diagnose-state.sh
uuid-corrupt attributed by scripts/diagnose-state.sh
```

If all diagnoses are `healthy` or `not-init`, omit the legend entirely.

## Mission Control subdirectory exclusion

When iterating `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/*/`:

- Skip any entry whose basename starts with `.` (this covers `.archive` and any
  future dot-prefixed system directories).
- Only descend one level — do not recurse into channel subdirectories.
- Skip entries that are not directories.

## Step-by-step algorithm

1. Collect candidate state paths:
   a. If `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/` exists, for each non-dot
      subdirectory `<dir>` under it, add `<dir>/state.json` to the list.
   b. If `./thoughts/.mission-control-state.json` exists, add it to the list.
2. If the list is empty, print `No active channels.` and stop.
3. For each path in the list, produce a table row string (do NOT print yet):
   - Run `diagnose-state.sh` as above.
   - On fault, produce the ERROR row (and write the stderr attribution to stderr) and continue.
   - On success, extract fields and produce a normal row.
4. Print the table (header + all collected rows).
5. Collect distinct non-healthy / non-not-init diagnoses; print legend if any.
