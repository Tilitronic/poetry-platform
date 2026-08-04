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
   1.5. **BATCH-APPROVAL GATE (G1)** — if HANDOFF.md exists and contains a "Prognosis for
   next cycle" section, present the full prognosis to the developer as a **batch
   approval** BEFORE reading messages.md or delegating any work. See §7.3 for protocol.
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
  append BOTH (a) one row to `.opencode/session/messages.md` (table: `# | timestamp |
from | to | lane/ticket | result | next-action`) AND (b) one JSON line to
  `.opencode/session/messages.jsonl` (semconv v1.42.0 — same event, one JSON object).
  Row numbering MUST be strictly monotonic — continue from the last row # across
  sessions, never restart on a fresh session; an empty file starts at 1. Also append
  campaign-state snapshots before any session end.
- **SELF-RERUN**: OpenCode native compaction (`compaction.auto: true`, opencode.jsonc)
  handles RAW context pressure within a session — no human action needed for compaction
  events. SELF-RERUN is triggered by: (a) **CAMPAIGN MILESTONE** — a major phase
  completes (implementation done, review disposition finalized, campaign complete) and
  the next phase benefits from a fresh session; (b) **CONTEXT DEGRADATION** — compaction
  has compacted campaign-critical context (HANDOFF.md, prognosis, cycle state) so the
  orchestrator cannot reliably continue; (c) **PRIMARY THRESHOLD** — context usage
  > = 30% of the model context window (300K tokens for 1M-window models); (d) **HARD
  > SAFETY-NET** — context usage >= 50% (unconditional force). On ANY trigger: write
  > `.opencode/session/HANDOFF.md` (previous session id, last message #, reason, campaign
  > state incl. active tickets + next lane + gates passed, resume instructions), append a
  > final log row, then end your turn telling the user a fresh session should be started —
  > the next instance reads HANDOFF.md + messages.md and resumes. Detection: call
  > `token_stats`; compute (input+output)/model_context_window using this lookup
  > (estimates): qwen3.7-max 1,000,000; qwen3.7-plus 1,000,000 (per models.dev; verify on
  > next refresh); deepseek-v4-flash 1,000,000;
  > big-pickle 200,000 (unverified); others 131,072 unless known. Context windows per
  > models.dev, verified 2026-08-03. NOTE: compaction is size-triggered, not
  > relevance-triggered, and loses campaign-critical detail — hence the 30% primary
  > threshold (research-refined division of labor).
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
- **HANDOFF-REFRESH (G2)**: HANDOFF.md must be **REWRITTEN** (not appended) at each
  campaign milestone: (a) after any implementation lane completes; (b) after any review
  disposition is finalized; (c) after any commit lane lands; (d) at campaign completion.
  Each rewrite captures the current state snapshot — supersede, do not accumulate stale
  sections. Detection: after logging a messages.md row whose result contains
  DONE/COMPLETE/PASS for an implementation/review/commit lane, rewrite HANDOFF.md within
  the same delegation cycle.
- **DELEGATION MAP**: research→@researcher, analysis→@analyzer, inventory→@code-navigator,
  implementation→@coder (after @openspec-plan spec; tdd-craftsman), review→@reviewer,
  architecture→@architector, opencode-config research/review→@ai-specialist,
  knowledge-source curation→@resource-manager, knowledge persist→@memory-manager,
  docs/mechanical→@coder, visual→@designer/@observer.
- **STRICT WORKFLOW**: engineering work goes through the interview-first gate
  (openspec-plan) unless fast-path approved by the user; OpenCode-config changes
  route through §10 (ai-specialist gate → user decision → implement → validate →
  independent review → CHANGELOG); never auto-apply reviewer recommendations (the
  user disposes).

## 3. Audit Rerun Flow

Run gates **in order** by DELEGATING verification-only lanes to @coder
(record each result in messages.md):

1. `make test-config`
2. `make test-shell` (54 bats)
3. `pnpm verify:format` / `verify:js` / `verify:js-tests` + `pnpm audit`
4. `bash scripts/verify-python.sh`
5. `make audit-python`
6. `make test-infra` (needs Docker; ends with stack down)
7. container pytest (`.opencode/scripts`)

Any failure → create/update ticket in `docs/dev-infra-audit/tickets/` (via @coder
docs lane) → fix via delegation → re-verify. Repeat until the full cycle is CLEAN.

## 4. Open Tickets to Close

| ID      | Summary                                                   | Severity | Disposition                                                                                                                                                                                          |
| ------- | --------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DIA-003 | skills-lock pinning (all skills)                          | Minor    | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/)                                                                                                          |
| DIA-006 | api-server production Dockerfile                          | Major    | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/)                                                                                                          |
| DIA-030 | unverified installs in Dockerfile.dev (volta)             | Medium   | **CLOSED** — 2026-08-03 owner directive; migration executed via `openspec/changes/volta-to-mise` (Volta v2.0.2 → SHA256-verified mise v2026.8.0); archived per archive policy (see tickets/archive/) |
| DIA-034 | ecdsa 0.19.2 PYSEC-2026-1325 (transitive via python-jose) | Medium   | **CLOSED** — 2026-08-03 owner directive; archived per archive policy (see tickets/archive/)                                                                                                          |

The table above is the **archived** history — DIA-003 / DIA-006 / DIA-030 /
DIA-034 were CLOSED and archived 2026-08-03 (owner directive; dispositions in
`tickets/archive/`). DIA-030's migration directive was executed 2026-08-03 via
`openspec/changes/volta-to-mise` (Volta v2.0.2 → SHA256-verified mise v2026.8.0
in `Dockerfile.dev` + `tools/opencode-docker/Dockerfile`; `.mise.toml` is the new
single source of node/pnpm pins). DIA-007 was archived in the 2026-08-03 cleanup (git
history).

**Current ledger (as of the 2026-08-04 dev-environment audit):** the ledger holds
**13 active rows** — 5 OPEN (DIA-043 / DIA-044 / DIA-045 / DIA-048 / DIA-049),
6 VERIFIED (DIA-038 / DIA-039 / DIA-040 / DIA-041 / DIA-046 / DIA-047),
1 E2E (DIA-042), 1 IMPLEMENTED (DIA-037). `tickets/README.md` is the authoritative
ledger index — it supersedes this snapshot; consult it for rollup counts, statuses,
and per-ticket detail.

## 5. Clean-Cycle Definition

All automated gates pass **and** zero open Blocker/Critical tickets; remaining OPEN
tickets are only DEFERRED / USER-DECISION / MONITOR (non-blocking).

## 6. Session Continuity

`messages.md` is your memory; never lose state — append before ending any session;
handoff protocol per rule 2 (30% primary threshold / 50% safety-net; campaign milestones).

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

0. **DETECTION** — at session start, check for `.opencode/session/HANDOFF.md`. If it
   exists AND contains a `## Prognosis for next cycle` heading, the batch-approval
   protocol is MANDATORY: log a messages.md row (channel: 'handoff',
   event_type: 'batch-approval-gate') before proceeding. If no HANDOFF.md exists or it
   has no Prognosis section, skip to normal boot (§1).
1. Read HANDOFF.md and parse the prognosis section.
2. Present each subsection as a batch: session_summary → fixes_applied → open_tickets →
   verification_request → resume_instructions.
3. Developer approves per item (approve / defer / reject).
4. Rejected items become new open_tickets; deferred items carry forward.
5. During open_tickets review, run the **C5 check**: if a `[BLOCKING]` ticket from the
   predecessor was supposed to be resolved but wasn't, C5 fires (design.md §1).
6. **VERIFICATION** — after the developer approves ALL items, log a messages.md row
   (channel: 'delegation', resolution_status: 'acknowledged',
   content_ref: 'batch-approval-complete'); ONLY THEN begin work. Rejected items become
   new open_tickets and await instruction — they are not silently carried forward.

### 7.4 Crisis handling

On any C1–C5 trigger (design.md §1): halt the cycle, produce a crisis HANDOFF.md
(all 5 subsections, abbreviated in content — session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets populated; verification_request/resume_instructions describe crisis-handling only), notify the developer with trigger
identity and evidence, and let the developer decide: extend the cycle, start a fresh
cycle (counts against budget), or close the change.

### 7.5 Clean termination

A `clean` exit requires fresh-session independent verification (design.md §9, ADR-003):
the session that produced the work cannot certify its own completion. The fresh session
reads HANDOFF.md, executes each verification_request independently, and confirms or
downgrades exit_state. Procedure: the fresh session APPENDS a `## Verification Result`
section to HANDOFF.md with, per verification_id, a status (verified-pass |
verified-fail | verified-partial), evidence, the verifier session ID, and a timestamp.
All verified-pass → confirm 'clean'; any verified-fail → downgrade exit_state to
'crisis' (and append failure details); mixed pass+partial → 'manual-halt'. The producer
session NEVER writes the Verification Result — it is the verifier's contract only; no
self-certification; untrusted markers block SELF-RERUN.

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
