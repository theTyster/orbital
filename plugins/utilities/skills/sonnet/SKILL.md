---
name: sonnet
description: Run a prompt with Sonnet in a new session
user-invocable: true
allowed-tools: Bash
---

Spawn a new Claude Sonnet session with the user's prompt, enriched with current project context.

## Project Context

- **Directory**: !`pwd`
- **Git branch**: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)"`
- **Modified files**: !`git diff --name-only 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/, $//' || echo "(none)"`
- **Project type**: !`ls package.json Cargo.toml pyproject.toml go.mod 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || echo "(unknown)"`

## Instructions

Run the user's ARGUMENTS as a prompt in a new Claude Sonnet session. Prepend the project context above to the prompt so the new session has immediate environmental awareness.

```bash
claude -p "Project context:
- Dir: $(pwd)
- Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a git repo')
- Modified: $(git diff --name-only 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/, $//')

ARGUMENTS" --model "claude-sonnet-4-6" --allowedTools "Read"
```

## Rules

- No need to present the output to the user unless explicitly requested.
- Default permissions are Read only. Edit and Bash must be explicitly passed via `--allowedTools`
- Return results as-is without summarizing or modifying them
