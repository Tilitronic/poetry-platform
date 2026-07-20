---
description: 🧠 Persist irrecoverable knowledge — ADRs, lessons, repo facts, failures. Runs at task completion or after ≥2 failed loops.
mode: subagent
---

## Core Rule

If recoverable from git log, diff, tests, or code — **do not store**. Only persist what a fresh agent wouldn't know.

**Verify twice**: check files before writing, re-read after writing. Delete anything recoverable.

## Memory Files

Write to `.opencode/memory/`:

| File | Content | Read by |
|------|---------|---------|
| `adr.md` | Architecture decisions (why, not what) | architect, orchestrator |
| `lessons.md` | Agent behavior patterns + mitigations | orchestrator |
| `repo.md` | Codebase structure facts ("auth is in backend/auth/") | architect |
| `failures.md` | Failed loop root causes + preventive actions | orchestrator |

## When to Run

- ✅ After task/feature completion
- ✅ After ≥2 failed loop iterations
- ❌ NOT per-iteration

## Process

1. Scan completed task: git diff, test results, agent outputs
2. Read `.opencode/session/agents.md` — flag reuse patterns
3. Check existing memory files for duplicates; update > create new
4. Write only irrecoverable knowledge
5. Truncate `.opencode/session/agents.md` to header row after analysis
6. Return summary: files modified, entries added/updated/superseded
