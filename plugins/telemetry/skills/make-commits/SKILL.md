---
name: make-commits
description: Create logical commits of unstaged changes.
user-invocable: true
model: sonnet
effort: medium
allowed-tools: Agent
---

Delegate the commit work to a Sonnet sub-agent. Sonnet is fast and capable for organizing a diff into logical commits, and running in a sub-agent context keeps the parent session's context clean.

## Pass the "why" to the sub-agent

The sub-agent will see the diff itself, but it won't see the conversation that produced it. Good commit messages lean on the *why* — the motivation, the user request, any constraint that shaped the change — and that lives only in your context. Before delegating, draft a short **Session Context** note covering:

- **What the user asked for** — the feature, refactor, fix, or cleanup in one or two sentences.
- **Why it matters** — the motivation behind the change (compliance requirement, past incident, user preference, deprecation, etc.), if you know it. Skip this if the request was purely mechanical.
- **Non-obvious grouping hints** — any changes that look unrelated but belong together (e.g., "the README rewrite and the version bump are the same release"), or changes that look related but shouldn't share a commit.
- **Things to avoid** — e.g., don't commit a stray debug file, don't lump the unrelated lint fix in with the feature work.

Keep it tight — under 200 words. If the session had no meaningful context (trivial change, user just said "commit"), say so explicitly so the sub-agent doesn't invent motivation.

## Delegate

Spawn a general-purpose sub-agent with `model: "sonnet"`. The sub-agent runs `git status` and `git log` itself, so the parent doesn't need to pre-evaluate them. Pass the Session Context inline in the prompt:

```
Agent(
  description: "Organize diff into logical commits",
  subagent_type: "general-purpose",
  model: "sonnet",
  prompt: """
## Session Context
<replace this block with the Session Context note drafted above>

## Your task
Review all unstaged and untracked changes in this git repository and organize them into logical commits.

Start by running `git status` to see what's pending and `git log --oneline -n 10` to learn the recent commit style. Use the Session Context above to inform the *why* in each commit message — don't restate the context, just let it shape your word choice and grouping. Group related changes together. One commit per coherent unit of work. Write concise commit messages focused on *why*, not what. Match the tone and format of the recent commits shown in `git log --oneline -n 10`. Do not include any Co-Authored-By trailer or mention of Claude in the message. Do not push. Do not amend. Create new commits only.
"""
)
```

After the sub-agent finishes, respond with one word: "done". Anything outside that response just adds noise. The user sees the sub-agent's commits via `git log` without you reiterating anything.
