---
name: create-presentation
description: >
  Create an HTML-as-PowerPoint presentation from a topic, document, or handoff.
  Use when: "make a presentation", "create slides", "build a deck about X".
user-invocable: true
agent: general-purpose
model: opus
effort: medium
allowed-tools: Write, Read, Glob, Grep, Agent
argument-hint: [topic, description, or path to source document]
---

# Create Presentation

Generate a self-contained HTML slideshow from source material. The output is a directory containing copies of all mentioned files, and a single `.html` file with embedded CSS and JS — no dependencies, opens in any browser, navigable by keyboard or buttons, with hash-based URLs for deep-linking.

## Project Context

- **Directory**: !`pwd`
- **Git branch**: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo no-git`
- **README preview**: !`head -30 README.md 2>/dev/null || echo no-README`
- **Docs available**: !`find . -maxdepth 3 -name '*.md' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -15 | tr '\n' ','`

## Considerations

Determine what the presentation is about:

- **If a file path is given**: Read it fully. Extract key points, code snippets, diagrams, and structure.
- **If a topic is described**: Use the project context above and Read/Grep/Glob to gather relevant code, docs, or research from the codebase.
- **If a handoff/research doc**: Read the full document, extract findings, learnings, code references, and action items.

Copy these files into the presentation directory.

## Rules

1. **Every slide** gets a unique `id="slide-N"` (sequential, 1-based). This allows view positions to be stored in the URL.
2. **One point per slide** — if a slide has more than 3 code blocks or 5 bullet points, split it
3. **No external dependencies** — everything is embedded in the single HTML file
