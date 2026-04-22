---
name: opus
description: Run a prompt with Opus in a new session
user-invocable: true
allowed-tools: Bash
---

Spawn a new Claude Opus session with the user's prompt, enriched with current project context.

## Instructions

Run the user's ARGUMENTS as a prompt in a new Claude Opus session. Prepend the project context above to the prompt so the new session has immediate environmental awareness.

```bash
claude -p "Project context:
- Dir: $(pwd)
- Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a git repo')
- Modified: $(git diff --name-only 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/, $//')

ARGUMENTS" --model "opus" --allowedTools "Read"
```

## Rules

- No need to present the output to the user unless explicitly requested.
- Default permissions are Read only. Edit and Bash must be explicitly passed via `--allowedTools`
- Return results as-is without summarizing or modifying them
