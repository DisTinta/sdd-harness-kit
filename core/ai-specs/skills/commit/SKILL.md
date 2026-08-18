---
name: commit
description: Use when the user says "commit", "create a commit" or similar. Stages and commits the current changes as atomic conventional commits, after checking the documentation gate.
author: sdd-harness-kit
version: 1.0.0
argument-hint: [optional scope or paths to limit the commit]
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Read Grep Glob
---

## Current state
- Status: !`git status --short`
- Diff: !`git diff HEAD`
- Branch: !`git branch --show-current`

## Instructions

### Step 1 — Scope

If `$ARGUMENTS` names a scope or paths, limit the commit to changes matching it. If nothing clearly
matches, **report it and do not commit**.

### Step 2 — Documentation gate

Before committing, check whether this change invalidated any documentation
(`docs/documentation-standards.md` requires this). If it did, say so and offer to run `update-docs`
first. Do not commit a change that leaves the documentation describing a system that no longer exists.

### Step 3 — Atomicity

Inspect the changes. If the diff mixes unrelated areas, **propose separate atomic commits** with
selective staging and ask for confirmation before executing anything. A single large commit makes review
impossible, and review is the point.

### Step 4 — Message

Conventional commits: `type(scope): description`.

- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Scope: the capability or the layer
- First line: 72 characters maximum, imperative present tense (`add`, not `added`)
- **In English**, per `docs/base-standards.md` §2
- If the change needs explaining, add a body after a blank line that explains the *why*, not the what
- Include the ticket id if the branch or context has one

### Step 5 — Execute and confirm

`git add <paths> && git commit -m "<message>"`, then confirm the commit was created.

## Prohibitions

- **Never `git push`.** The push is the human's decision.
- Never `git push --force`, under any circumstances, even if asked in passing.
- Never `git commit --amend` on a commit that is already pushed.
- Never stage `.env` or any file matching a secret pattern, even if the user asks.
