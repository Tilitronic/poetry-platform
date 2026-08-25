---
# Coder bash allow-list vs 300s permission watchdog (external pattern registration)

- Date: 2026-08-25
- Ticket: see new permission ticket created this change (cross-ref DIA-260825-e9ou)
- Source: ai-specialist gate ses_fc6f516efffeO0DdLJ4kEH4r2J + code-navigator diagnosis ses_fc67272a4ffenGwNAgE19b7ZZA

## Finding

Coder agent bash permission is an allow-list MAP (deny-by-default) at
opencode.jsonc:312-324; it does NOT inherit the global "*": "allow" baseline.
Commands outside the list default to "ask", and the needs-input-observer plugin
(hardcoded 300s watchdog, env PERMISSION_STALL_TIMEOUT_MINUTES) auto-rejects
unanswered prompts ("no_human_response_within_threshold"). Three fix-lane
sessions died this way before any work started. coder-escalated had the same
gap (allow-list with zero allows). designer/memory-manager inherit the global
baseline - no gap.

Fix: explicit safe-command allows for coder + coder-escalated: 12 git read/safe
commands (log/status/diff/add/commit/show/branch/checkout/merge/rebase/fetch/
pull), make/pnpm/npm/node/bun, jq/sha256sum/python3, scripts/*. Deliberately
EXCLUDED: "git *" and "git push *" - an agent-level allow-list overrides global
destructive denies, so broad git patterns would bypass DIA-096 force-push/main-
push protections. Coder does not push per workflow.

Watchdog timeout deferred: not the root cause.

## Outcome

Applied under the new permission ticket; test-config green; restart required for live effect.
---
