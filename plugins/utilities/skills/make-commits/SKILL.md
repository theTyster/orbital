---
name: make-commits
description: Create logical commits of unstaged changes.
user-invocable: true
allowed-tools: Bash
---

Delegate the commit work to a new Claude Haiku session. Haiku is fast and capable enough for organizing a diff into logical commits, and running in a fresh session keeps the parent session's context clean.

## Pass the "why" to Haiku

Haiku will see the diff, but it won't see the conversation that produced it. Good commit messages lean on the *why* — the motivation, the user request, any constraint that shaped the change — and that lives only in your context. Before spawning Haiku, draft a short **Session Context** note covering:

- **What the user asked for** — the feature, refactor, fix, or cleanup in one or two sentences.
- **Why it matters** — the motivation behind the change (compliance requirement, past incident, user preference, deprecation, etc.), if you know it. Skip this if the request was purely mechanical.
- **Non-obvious grouping hints** — any changes that look unrelated but belong together (e.g., "the README rewrite and the version bump are the same release"), or changes that look related but shouldn't share a commit.
- **Things to avoid** — e.g., don't commit a stray debug file, don't lump the unrelated lint fix in with the feature work.

Keep it tight — under 200 words. If the session had no meaningful context (trivial change, user just said "commit"), say so explicitly so Haiku doesn't invent motivation.

## Spawn Haiku

Pass the context inline in the prompt:

```bash
claude -p "Working directory: $(pwd)

## Session Context
Current Git Status: 
$(git status)

Recent commit style:
$(git log --oneline -n 10)

<Additional context from your session with the user goes here — replace this block>

## Your task
Review all unstaged and untracked changes in this git repository and organize them into logical commits. Use the Session Context above to inform the *why* in each commit message — don't restate the context, just let it shape your word choice and grouping. Group related changes together. One commit per coherent unit of work. Write concise commit messages focused on *why*, not what. Match the tone and format of the recent commits shown in \`git log --oneline -n 10\`. Do not include any Co-Authored-By trailer or mention of Claude in the message. Do not push. Do not amend. Create new commits only." \
  --model "haiku" \
  --allowedTools "Bash Read Grep Glob"
```

After Haiku has finished you need only respond with one word "done". Anything outside of this response just adds noise and repetition. The user can see Haiku's output without you reiterating anything about it.
