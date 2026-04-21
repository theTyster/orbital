---
name: make-commits
description: Use when the user wants to create logical commits of unstaged changes.
user-invocable: true
allowed-tools: Bash
---

Current Git Status: !`git status`

Delegate the commit work to a new Claude Haiku session. Haiku is fast and capable enough for organizing a diff into logical commits, and running in a fresh session keeps the parent session's context clean.

```bash
claude -p "Working directory: $(pwd)

Review all unstaged and untracked changes in this git repository and organize them into logical commits. Group related changes together. One commit per coherent unit of work. Write concise commit messages focused on *why*, not what. Do not include any Co-Authored-By trailer or mention of Claude in the message. Do not push. Do not amend. Create new commits only." \
  --model "claude-haiku-4-5-20251001" \
  --allowedTools "Bash Read Grep Glob"
```

Return Haiku's output as-is — do not re-summarize the commit list.
