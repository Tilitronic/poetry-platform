# Orchestration Rules

> System architecture reference: `architecture.md` — read on-demand when architectural context is needed.

## Context Budgets

Give each agent only what it needs — not the full conversation history.
Boss holds the full picture; subagents get only their slice.

| Agent | Give | Do NOT give |
|-------|------|-------------|
| architector | user request + file paths | Full diffs, entire files |
| reviewer | branch names, diff summary, file paths | Raw data, entire files |
| coder | exact plan, target code, line numbers | 200 lines of context, unrelated functions |
| memory-manager | review findings + task summary | Full history, raw agent output |
| code-navigator | search query, file patterns | — (stateless) |
| designer | UI specs, component references | Backend logic, unrelated code |
| web_scout | specific question, library version | General programming questions |

Anti-pattern: copy-pasting the entire conversation into every subagent prompt.

## Escalation Rules

| Rule | Description |
|------|-------------|
| **3 failures → escalate** | If coder fails the same test 3 times, escalate to boss with hypothesis analysis. Do not loop. |
| **Re-plan limit** | Max 2 returns to architector per task. After 2, present to user: switch mode, narrow scope, or abort. **Never loop silently.** |
| **Refactor plan → user approval** | If reviewer produces a refactor plan, present to user and wait for explicit approval. Do not apply automatically. |
| **User rejects refactor** | Offer: (1) proceed as-is, (2) re-invoke reviewer, (3) abort. |
| **Subagent questions** | Answer from existing context if possible. Otherwise present to user. **Never guess.** |
