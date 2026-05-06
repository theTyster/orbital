---
name: opus
description: Run a prompt with Opus in a new session
user-invocable: true
allowed-tools: Bash
---

Spawn a new Claude Opus session with the user's prompt, enriched with current project context.

## Instructions

Before running the sub-session, gather the following context using your own tools:
- Current working directory (use `pwd`)
- Current git branch (use `git rev-parse --abbrev-ref HEAD`)
- Modified files (use `git diff --name-only | head -10`)

Then run the user's ARGUMENTS as a prompt in a new Claude Opus session, prepending the gathered context so the new session has immediate environmental awareness:

```bash
claude -p "Project context:
- Dir: <dir>
- Branch: <branch>
- Modified: <modified-files>

<ARGUMENTS>" --model "opus" --effort "medium" --allowedTools "Read"
```

## Rules

- No need to present the output to the user unless explicitly requested.
- Default permissions are Read only. Edit and Bash must be explicitly passed via `--allowedTools`
- Return results as-is without summarizing or modifying them
