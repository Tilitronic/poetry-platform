# Dev-Infra Audit — Next-Run Instruction (Orchestrator Operating Manual)

This is the operating manual for the **next orchestrator instance** that resumes or
reruns the dev-infra audit campaign. You (the orchestrator) are read-restricted and
delegation-only — read this file plus the session log, then run the campaign
through delegated lanes.

---

## 1. Boot Sequence

Read these files **in this order** when a session starts:

1. `.opencode/session/HANDOFF.md` — if it exists, read it **FIRST**. It is the resume
   point from a previous instance (previous session id, last message #, reason,
   campaign state, resume instructions).
2. `.opencode/session/messages.md` — the session history record. Read the **last ~20
   entries** to reconstruct what happened and what the next action is.
3. **This file** (`docs/dev-infra-audit/NEXT-RUN.md`) — the operating manual.
4. `.opencode/practice-protected.md` — the practice-protected zones (do not silently
   implement anything inside them).

Then check the ledger state via a **delegated read lane** (per rule 2 you may not read
repo files yourself): dispatch a read-only lane (e.g. `@code-navigator` or `@coder`
with a read-only task) to report the current contents of:

- `docs/dev-infra-audit/README.md` (campaign overview + Current State)
- `docs/dev-infra-audit/tickets/README.md` (ledger index + rollup counts)

## 2. Orchestrator Operating Rules

- **READ RESTRICTION**: you are FORBIDDEN from reading repo files. You know NOTHING
  about the codebase except what arrives in delegation results and the files above.
  All codebase knowledge comes from delegated agents — they report paths/evidence in
  their final messages. The path-scoped permission block enforces this
  (`read` allows only `.opencode/session/*`, `docs/dev-infra-audit/NEXT-RUN.md`,
  `AGENTS.md`, `.opencode/practice-protected.md`).
- **WRITE RESTRICTION**: you write ONLY to `.opencode/session/*` (messages.md append
  - HANDOFF.md). Never edit code, config, or docs directly.
- **MESSAGES-LOG DISCIPLINE**: after EVERY delegation result and every user decision,
  append one row to `.opencode/session/messages.md` (table: `# | timestamp | from |
to | lane/ticket | result | next-action`). Also append campaign-state snapshots
  before any session end.
- **SELF-RERUN**: when context usage >= 50%, write `.opencode/session/HANDOFF.md`
  (previous session id, last message #, reason, campaign state incl. active tickets
  - next lane + gates passed, resume instructions), append a final log row, then end
    your turn telling the user a fresh session should be started — the next instance
    reads HANDOFF.md + messages.md and resumes. Detection: call `token_stats`; compute
    (input+output)/model_context_window using this lookup (estimates):
    qwen3.7-max 1,000,000; qwen3.7-plus 131,072; deepseek-v4-flash 64,000;
    big-pickle 200,000; others 131,072 unless known.
- **DELEGATION MAP**: research→@researcher, analysis→@analyzer, inventory→@code-navigator,
  implementation→@coder (after @openspec-plan spec; tdd-craftsman), review→@reviewer,
  architecture→@architector, opencode-config research/review→@ai-specialist,
  knowledge persist→@memory-manager, docs/mechanical→@code-executor, visual→@designer/@observer.
- **STRICT WORKFLOW**: engineering work goes through the interview-first gate
  (openspec-plan) unless fast-path approved by the user; OpenCode-config changes
  route through §10 (ai-specialist gate → user decision → implement → validate →
  independent review → CHANGELOG); never auto-apply reviewer recommendations (the
  user disposes).

## 3. Audit Rerun Flow

Run gates **in order** by DELEGATING verification-only lanes to @coder/@code-executor
(record each result in messages.md):

1. `make test-config`
2. `make test-shell` (54 bats)
3. `pnpm verify:format` / `verify:lint` / `verify:typecheck` / `verify:test` + `pnpm audit`
4. `bash scripts/verify-python.sh`
5. `make audit-python`
6. `make test-infra` (needs Docker; ends with stack down)
7. container pytest (`.opencode/scripts`)

Any failure → create/update ticket in `docs/dev-infra-audit/tickets/` (via @coder
docs lane) → fix via delegation → re-verify. Repeat until the full cycle is CLEAN.

## 4. Open Tickets to Close

| ID      | Summary                                                   | Severity | Disposition                                                                           |
| ------- | --------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------- |
| DIA-003 | skills-lock pinning (all skills)                          | Minor    | DEFERRED — keep with note (format limitation)                                         |
| DIA-006 | api-server production Dockerfile                          | Major    | **USER DECISION** — present options + trade-offs to the owner; never auto-decide      |
| DIA-007 | split ai-specialist into resource-manager + specialist    | Major    | **USER DECISION** — present options + trade-offs to the owner; never auto-decide      |
| DIA-030 | unverified installs in Dockerfile.dev (volta)             | Medium   | MONITOR — re-check upstream for official digests; close only when verifiably resolved |
| DIA-034 | ecdsa 0.19.2 PYSEC-2026-1325 (transitive via python-jose) | Medium   | MONITOR — re-check upstream for published fix; close only when resolved               |

For the MONITOR tickets: delegate a read/research lane to check upstream, record the
result in messages.md, then transition the ticket (OPEN → VERIFIED/CLOSED only when
verifiably resolved, or update the note if still unresolved).

## 5. Clean-Cycle Definition

All automated gates pass **and** zero open Blocker/Critical tickets; remaining OPEN
tickets are only DEFERRED / USER-DECISION / MONITOR (non-blocking).

## 6. Session Continuity

`messages.md` is your memory; never lose state — append before ending any session;
handoff protocol at >= 50% context (see rule 2).
