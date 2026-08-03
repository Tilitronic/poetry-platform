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
    qwen3.7-max 1,000,000; qwen3.7-plus 1,000,000 (per models.dev; verify on next refresh); deepseek-v4-flash 1,000,000;
    big-pickle 200,000 (unverified); others 131,072 unless known. Context windows per models.dev, verified 2026-08-03.
- **CRISIS-DETECTION**: a cycle is in crisis when **ANY** of C1–C5 fires (binary OR — ADR-002,
  `.sdd/dia-redispatch-cycle/architecture.md`; full rule text in
  `openspec/changes/dia-redispatch-cycle/design.md` §1). C1: ≥3 consecutive failures on the
  same task (counter per-task, resets on success, not on cycle change). C2: ≥2 substantive
  design.md re-plans within one cycle. C3: ≥5 tool calls with no observable state change (no
  file written, no test status change, no git diff). C4: hard context overflow/truncation —
  fires; ≥50% context rerun (soft) — flagged only, does NOT fire. C5: a `[BLOCKING]` prognosis
  ticket unresolved for 1 full cycle (fires at the start of cycle N+2). **On crisis:** STOP all
  work, write a crisis HANDOFF.md with all 5 subsections, abbreviated in content (design.md §1 Option A): session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets populated; verification_request/resume_instructions describe crisis-handling only, append a
  final messages.md row, end the turn telling the user a FRESH session must be started — crisis
  takes precedence over SELF-RERUN (no self-rerun from the same context).
- **PROGNOSIS-DISCIPLINE**: every cycle termination (clean / crisis / exhausted / manual-halt)
  MUST produce a HANDOFF.md containing exactly one "Prognosis for next cycle" section with five
  folded subsections (session_summary / fixes_applied / open_tickets / verification_request /
  resume_instructions) — no separate PROGNOSIS.md (ADR-001). The prognosis is the single source
  of truth for the successor session, must be self-contained (successor reconstructs context
  from HANDOFF.md alone), structured, honest (no sandbagging), and actionable. Clean termination
  requires FRESH-session independent verification — **no self-certification**; "I verified"
  markers are UNTRUSTED and block SELF-RERUN (ADR-003). Cycles budget (default max-cycles=3,
  override 2..10 clamped, 1 disallowed, >10 requires split) is recorded in the cycle HANDOFF.md
  (current/max, clean-re-audit, budget-exhausted) + the campaign trigger manifest — NOT in this
  file. Full rule text: design.md §2 / §7 / §9.
- **DELEGATION MAP**: research→@researcher, analysis→@analyzer, inventory→@code-navigator,
  implementation→@coder (after @openspec-plan spec; tdd-craftsman), review→@reviewer,
  architecture→@architector, opencode-config research/review→@ai-specialist,
  knowledge-source curation→@resource-manager, knowledge persist→@memory-manager,
  docs/mechanical→@code-executor, visual→@designer/@observer.
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

| ID      | Summary                                                   | Severity | Disposition                                                                                 |
| ------- | --------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------- |
| DIA-003 | skills-lock pinning (all skills)                          | Minor    | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/) |
| DIA-006 | api-server production Dockerfile                          | Major    | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/) |
| DIA-030 | unverified installs in Dockerfile.dev (volta)             | Medium   | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/) |
| DIA-034 | ecdsa 0.19.2 PYSEC-2026-1325 (transitive via python-jose) | Medium   | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/) |

No open tickets remain from the audit campaign. DIA-003 / DIA-006 / DIA-030 /
DIA-034 were CLOSED and archived 2026-08-03 (owner directive; dispositions in
`tickets/archive/`). DIA-007 was archived in the 2026-08-03 cleanup (git
history). The only active ledger row is DIA-037 (OPEN backlog — make test-skills
gate), tracked in `tickets/README.md`.

## 5. Clean-Cycle Definition

All automated gates pass **and** zero open Blocker/Critical tickets; remaining OPEN
tickets are only DEFERRED / USER-DECISION / MONITOR (non-blocking).

## 6. Session Continuity

`messages.md` is your memory; never lose state — append before ending any session;
handoff protocol at >= 50% context (see rule 2).

## 7. Redispatch Protocol (dia-redispatch-cycle)

The multi-cycle redispatch protocol for long-running features is defined by the
openspec change `openspec/changes/dia-redispatch-cycle/` (proposal / design / tasks)
and its design-authority seed `.sdd/dia-redispatch-cycle/architecture.md` (ADR-001..005).
This section is the orchestrator-operating summary of the protocol.

### 7.1 Cycle identity

- Every redispatch cycle gets a `cycle_id` in the format `c-YYYYMMDD-HHMMss` UTC
  (design.md §6), generated at cycle start and immutable for the cycle duration.
- If two cycles start within the same second, append a sequence suffix:
  `c-20260803-143025-001`.

### 7.2 Outgoing (producer) session — cycle end

At cycle termination (clean / crisis / exhausted / manual-halt), the outgoing session MUST:

1. Write a HANDOFF.md containing the "Prognosis for next cycle" section with the five
   folded subsections (session_summary / fixes_applied / open_tickets /
   verification_request / resume_instructions) per the schema in design.md §3 and the
   template `openspec/templates/HANDOFF.md`.
2. Record the cycle budget in the HANDOFF.md (cycle current/max, clean-re-audit,
   budget-exhausted) + the campaign trigger manifest — NOT in this file (design.md §7).
3. Append a final row to messages.md and end the turn telling the user a fresh session
   should be started (or, on crisis, that a fresh session is REQUIRED — crisis
   precedence over SELF-RERUN, design.md §1).

### 7.3 Incoming (successor) session — boot

The incoming session's FIRST action is to read the predecessor HANDOFF.md and present
the "Prognosis for next cycle" section as a **batch approval** to the developer BEFORE
any delegation or tool use (design.md §8):

1. Read HANDOFF.md and parse the prognosis section.
2. Present each subsection as a batch: session_summary → fixes_applied → open_tickets →
   verification_request → resume_instructions.
3. Developer approves per item (approve / defer / reject).
4. Rejected items become new open_tickets; deferred items carry forward.
5. During open_tickets review, run the **C5 check**: if a `[BLOCKING]` ticket from the
   predecessor was supposed to be resolved but wasn't, C5 fires (design.md §1).
6. Only after ALL items are approved does the session begin work — no work before approval.

### 7.4 Crisis handling

On any C1–C5 trigger (design.md §1): halt the cycle, produce a crisis HANDOFF.md
(all 5 subsections, abbreviated in content — session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets populated; verification_request/resume_instructions describe crisis-handling only), notify the developer with trigger
identity and evidence, and let the developer decide: extend the cycle, start a fresh
cycle (counts against budget), or close the change.

### 7.5 Clean termination

A `clean` exit requires fresh-session independent verification (design.md §9, ADR-003):
the session that produced the work cannot certify its own completion. The fresh session
reads HANDOFF.md, executes each verification_request independently, and confirms or
downgrades exit_state. No self-certification; untrusted markers block SELF-RERUN.

### 7.6 Cycles budget

- Default `max-cycles=3`; override 2..10 (clamped); `max-cycles=1` disallowed; >10
  requires a change split (design.md §7, ADR-004).
- Exit states: `clean` / `crisis` / `exhausted` / `manual-halt`. `exhausted` is a soft
  non-crisis exit with a ≤200-char postmortem and NO C6 trigger (ADR-005).
- Budget increments only on full audit pass (complete HANDOFF.md + successor
  acknowledgment via batch approval); ≥50% context reruns are tracked but do not
  consume budget unless the cycle terminates.

### 7.7 Reference artifacts

- Template: `openspec/templates/HANDOFF.md` (prognosis schema), `openspec/templates/T5-row.md`
  (task row with cycle attribution).
- Fixtures: `openspec/changes/dia-redispatch-cycle/fixtures/` — crisis drills (VP-2),
  budget edge cases (VP-4), batch-approval simulation (VP-3), independence verification
  (VP-5), messages schema fixture (VP-6), integration simulation (VP-7).
