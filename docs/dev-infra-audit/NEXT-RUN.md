# Dev-Infra Audit — Next-Run Instruction (Orchestrator Operating Manual)

This is the operating manual for the **next orchestrator instance** that resumes or
reruns the dev-infra audit campaign. You (the orchestrator) are read-restricted and
delegation-only — read this file plus the session log, then run the campaign
through delegated lanes.

---

## 1. Boot Sequence

Read these files **in this order** when a session starts:

1. **HANDOFFS (MANUAL)** - handoffs are written and read only by two slash
   commands: `/make-handoff` writes
   `.opencode/session/handoffs/HANDOFF-<date>-<branch>.md` and `/read-handoff`
   reads the newest matching file back on developer request. The directory is
   gitignored. There is no plugin enforcement, no checksum and no lane-0
   verification: nothing about a handoff is verified automatically, the plugin
   writes no per-session slot, and the orchestrator does not auto-present a
   prognosis at session start. Boot neither resolves nor gates a handoff.
2. `.opencode/session/messages.md` — the session history record. Read the **last ~20
   entries** to reconstruct what happened and what the next action is.
3. **This file** (`docs/dev-infra-audit/NEXT-RUN.md`) — the operating manual.
4. `.opencode/practice-protected.md` — the practice-protected zones (do not silently
   implement anything inside them).

Then check the ledger state via a **delegated read lane** (per rule 2 you may not read
repo files yourself): dispatch a read-only lane (e.g. `code-navigator` or `coder`
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
- **WRITE RESTRICTION**: you write NO files directly. Handoff files are written only
  by the `/make-handoff` slash command at developer request (section 1); the plugin no
  longer writes per-session handoff slots, pointers or checksums. Never edit code,
  config, or docs directly. messages.md / messages.jsonl are plugin-managed - never
  append to them (see SESSION LOGGING below).
- **SESSION LOGGING**: automatic via delegation-observer plugin; use `log_decision` tool for semantic events; do NOT manually edit messages.md or messages.jsonl
- **SELF-RERUN**: OpenCode native compaction (`compaction.auto: true`, opencode.jsonc)
  handles RAW context pressure within a session — no human action needed for compaction
  events. SELF-RERUN is triggered by: (a) **CAMPAIGN MILESTONE** — a major phase
  completes (implementation done, review disposition finalized, campaign complete) and
  the next phase benefits from a fresh session; (b) **CONTEXT DEGRADATION** — compaction
  has compacted campaign-critical context (the handoff file, prognosis, cycle state) so the
  orchestrator cannot reliably continue; (c) **PRIMARY THRESHOLD** — context usage
  > = 15% of the model context window (150K tokens for 1M-window models); (d) **HARD
  > SAFETY-NET** — context usage >= 25% (unconditional force). On ANY trigger: log the
  > semantic event via `log_decision` (event_type: 'handoff',
  > resolution_status: 'done', prognosis: JSON.stringify(prognosisObject)) - a log row
  > only, it writes no handoff file; the file itself is written by `/make-handoff` at
  > developer request (section 1). The prognosis
  > carries previous session id, last message #, reason, campaign
  > state incl. active tickets + next lane + gates passed, resume instructions. Then
  > end your turn telling the user a fresh session should be started —
  > the next instance resumes from messages.md (plus the handoff file, when one was
  > written). Detection: call
  > `context_usage` (delegation-observer plugin tool); it returns usage as a
  > fraction of the model context window via a direct live read of the last
  > completed assistant message's tokens (TUI-equivalent computation), with a
  > registry.jsonl activity-signal proxy fallback for fresh sessions (no
  > completed assistant message yet) or client-call failure. The tool handles
  > model context-window lookup internally (1M
  > default). If the plugin is not loaded (tool unavailable), fall back to manual
  > estimation: count delegations dispatched × ~2000 tokens average per delegation,
  > add to visible conversation length heuristic, and apply the 15%/25% thresholds
  > conservatively (trigger earlier when uncertain). NOTE: compaction is size-triggered, not
  > relevance-triggered, and loses campaign-critical detail — hence the 15% primary
  > threshold (research-refined division of labor).
- **CRISIS-DETECTION**: a cycle is in crisis when **ANY** of C1–C5 fires (binary OR — ADR-002,
  `.sdd/dia-redispatch-cycle/architecture.md`; full rule text in
  `openspec/changes/dia-redispatch-cycle/design.md` §1). C1: ≥3 consecutive failures on the
  same task (counter per-task, resets on success, not on cycle change). C2: ≥2 substantive
  design.md re-plans within one cycle. C3: ≥5 tool calls with no observable state change (no
  file written, no test status change, no git diff). C4: hard context overflow/truncation —
  fires; ≥25% context rerun (soft) — flagged only, does NOT fire. C5: a `[BLOCKING]` prognosis
  ticket unresolved for 1 full cycle (fires at the start of cycle N+2). **On crisis:** STOP all
  work and log the crisis semantically via `log_decision` (event_type: 'crisis',
  resolution_status: 'escalated') - a log row only, it writes no handoff file. The crisis
  prognosis (all 5 subsections, abbreviated in content per design.md §1 Option A:
  session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets
  populated; verification_request/resume_instructions describe crisis-handling only) is
  presented to the developer, who persists it with `/make-handoff` if wanted. Then end the
  turn telling the user a FRESH session must be started — crisis
  takes precedence over SELF-RERUN (no self-rerun from the same context).
- **PROGNOSIS-DISCIPLINE**: every cycle termination (clean / crisis / exhausted / manual-halt)
  MUST present exactly one "Prognosis
  for next cycle" section with five folded subsections (session_summary / fixes_applied /
  open_tickets / verification_request / resume_instructions) — no separate PROGNOSIS.md
  (ADR-001); the developer persists it with `/make-handoff`. The prognosis is the
  single source of truth for the successor session, must be
  self-contained (successor reconstructs context from the handoff file alone), structured, honest
  (no sandbagging), and actionable. There is no checksum field and no integrity
  verification. Clean termination requires FRESH-session independent verification —
  **no self-certification**; "I verified" markers are UNTRUSTED and block SELF-RERUN (ADR-003).
  Cycles budget (default max-cycles=3, override 2..10 clamped, 1 disallowed, >10 requires
  split) is recorded in the cycle handoff file (current/max, clean-re-audit, budget-exhausted) +
  the campaign trigger manifest — NOT in this file. Full rule text: design.md §2 / §7 / §9.
- **HANDOFF-REFRESH (G2)**: the handoff file must be **REWRITTEN** (not appended) at each
  campaign milestone: (a) after any implementation lane completes; (b) after any review
  disposition is finalized; (c) after any commit lane lands; (d) at campaign completion.
  A rewrite = the developer re-runs `/make-handoff` for the current branch; the file is
  replaced wholesale, never edited in place. Each rewrite
  captures the current state snapshot — supersede, do not accumulate stale sections.
  Detection: after a plugin-logged delegation row whose result contains
  DONE/COMPLETE/PASS for an implementation/review/commit lane, ask for the fresh handoff
  within the same delegation cycle.
- **DELEGATION MAP**: research→researcher, analysis→analyzer, inventory→code-navigator,
  implementation→coder (after openspec-plan spec; tdd-craftsman), review→reviewer,
  architecture→architector, opencode-config research/review→ai-specialist,
  knowledge-source curation→researcher, knowledge persist→memory-manager,
  docs/mechanical→coder, visual→designer/observer.
- **STRICT WORKFLOW**: engineering work goes through the interview-first gate
  (openspec-plan) unless fast-path approved by the user; OpenCode-config changes
  route through AGENTS.md section 2.5 (ai-specialist gate → user decision →
  implement → validate → independent review → CHANGELOG); never auto-apply
  reviewer recommendations (the user disposes).
- **BATCH-DISPATCH RULE (A1, plugin-advised)**: task() calls MAY share a message
  only when all dispatched lanes form an approved conflict-free batch (read-only
  fan-out; single-writer + readers; post-fix reviewer + ai-auditor). NEVER batch
  two coders, two analyzers, coder+reviewer, or two memory-shelf.yaml writers.
  The delegation-observer plugin warns on unsafe parallel task() batches -
  advisory, not blocking.
- **RETROACTIVE CONSISTENCY CHECK (A3, plugin-enforced)**: the plugin compares
  in-flight registry rows against actual session outcomes on every `session.idle` /
  `session.error`. Dangling DISPATCHED/RUNNING rows without completion = silent
  failure alert. On boot, scan registry.jsonl for rows stuck in non-terminal
  `dispatch_state` and reconcile before delegating new work.
- **STATUS-TRANSITION GUARD (C3)**: registry.jsonl status transitions are strictly
  PENDING→INVOKED→RUNNING→COMPLETED/FAILED. The plugin enforces forward-only
  transitions; backwards transitions (COMPLETE→RUNNING) are logged as anomalies.
  Background-subagent mode (`OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS`) may
  alter blocking behavior — test both modes before relying on timing assumptions.

### Dispatch Routing & Quota Guard

Before ANY quota-metered dispatch, the orchestrator MUST:

1. Consult `knowledge/model-registry.yaml` to identify the model's `req_per_month` cap. If null (Copilot-credit lanes), SKIP the guard.
2. Count the lane's consumption in `registry.jsonl` matching `event: 'session_spawn'` for that model within the current YYYY-MM window.
3. Thresholds:
   - If count >= 80% of cap: WARN (state the remaining headroom in the dispatch justification).
   - If count+1 > cap: HARD-STOP. Do NOT dispatch. Use the defined `fallback[]` from the registry or `wait_for_user`.
4. SILENT_FAILURE Check: Before re-dispatching a previously-failed lane, check `registry.jsonl` for a `dispatch_state` of SILENT_FAILURE. If present, treat exactly like a quota-stop (fallback or wait_for_user); do not blindly retry.

## 3. Audit Rerun Flow

Run gates **in order** by DELEGATING verification-only lanes to coder
(delegations are plugin-logged automatically; gate outcomes go through `log_decision`):

1. `make test-config`
2. `make test-shell` (54 bats)
3. `pnpm verify:format` / `verify:js` / `verify:js-tests` + `pnpm audit`
4. `bash scripts/verify-python.sh`
5. `make audit-python`
6. `make test-infra` (needs Docker; ends with stack down)

Any failure → create/update ticket in `docs/dev-infra-audit/tickets/` (via coder
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
in `Dockerfile.dev`; `.mise.toml` is the new
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

`messages.jsonl` is your memory (plugin-logged); never lose state — the
delegation-observer plugin logs delegations automatically; log semantic events via
`log_decision` before ending any session; handoff protocol per rule 2 (15% primary
threshold / 25% safety-net; campaign milestones).

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

0. **PRE-HANDOFF VERIFICATION GATE (exit semantics):** before terminating, confirm the
   exit-gate evidence is in hand — verification results from coder/reviewer (relevant
   `make test-*` suite exit 0, lint clean, typecheck clean, `openspec validate` if
   applicable), review disposition complete (all findings accepted/rejected by developer),
   `git status` shows no unrelated changes. Gate failure ⇒ exit_state "manual-halt" (never
   "clean") with the unconfirmed gates listed as open_tickets.
1. **Present the terminal prognosis for manual persistence.** The prognosis MUST contain
   the "Prognosis for next cycle" section with the five folded subsections (session_summary
   / fixes_applied / open_tickets / verification_request / resume_instructions) per the
   schema in design.md section 3 and the template `openspec/templates/HANDOFF.md`.
   Persisting it is the developer's action: `/make-handoff` writes
   `.opencode/session/handoffs/HANDOFF-<date>-<branch>.md`. There is no plugin write, no
   per-session slot, and no checksum.
2. Log the semantic handoff event via `log_decision` (event_type: 'handoff', terminal
   resolution_status: 'done' | 'escalated' | 'pending-owner', prognosis:
   JSON.stringify(prognosisObject)) - a messages row only; it writes no file.
3. Record the cycle budget INSIDE the prognosis object (cycle current/max, clean-re-audit,
   budget-exhausted) + the campaign trigger manifest - NOT in this file (design.md
   section 7).
4. End the turn telling the user a fresh session should be started (or, on crisis,
   that a fresh session is REQUIRED - crisis precedence over SELF-RERUN, design.md
   section 1).

**HANDOFF TIMING.** Nothing verifies a handoff: there is no checksum, no lane-0 dispatch
and no boot gate. Present the prognosis together with the session's final summary and let
the developer decide when to run `/make-handoff`.

### 7.3 Incoming (successor) session — boot

There is no batch-approval boot gate and no automatic prognosis presentation. The plugin
does not resolve a handoff slot at session start and nothing about a handoff is verified.
If the developer wants the previous cycle's context they run `/read-handoff`, which
reports the newest `.opencode/session/handoffs/HANDOFF-<date>-<branch>.md`; otherwise boot
proceeds straight to section 1. For true parallel sessions use worktrees (separate
checkouts, separate `.opencode/session/` dirs).

When a resume point IS acknowledged, log it via `log_decision` (event_type: 'decision',
resolution_status: 'acknowledged') and review the predecessor's open_tickets before
delegating:

- TICKET-REFERENCE FORMAT: when presenting open_tickets or any other subsection that
  references DIA tickets, ALWAYS quote the ticket ID + human-readable slug from
  the filename (e.g., "DIA-100 'git worktrees for parallel dev sessions'", not
  "DIA-100" alone). The slug is derivable from the ticket filename
  (DIA-NNN-<descriptor>.md) or the README index. This applies to all
  user-facing references: prognoses, session summaries,
  and log_decision content_ref fields.
- C5 CHECK: if a `[BLOCKING]` ticket from the predecessor was supposed to be resolved but
  wasn't, C5 fires (design.md section 1). Rejected items become new open_tickets; deferred
  items carry forward.

### 7.4 Crisis handling

On any C1–C5 trigger (design.md §1): halt the cycle and log the crisis semantically via
`log_decision` (event_type: 'crisis', resolution_status: 'escalated') - a messages row
only; the plugin writes no handoff file. Present the crisis prognosis (all 5 subsections,
abbreviated in content -
session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets
populated; verification_request/resume_instructions describe crisis-handling only), then
notify the developer with trigger identity and evidence, and let the developer decide:
extend the cycle, start a fresh cycle (counts against budget), or close the change. The
developer persists the prognosis with `/make-handoff` if wanted.

### 7.5 Clean termination

A `clean` exit requires fresh-session independent verification (design.md §9, ADR-003):
the session that produced the work cannot certify its own completion. The fresh session
reads the handoff if one was written (`.opencode/session/handoffs/HANDOFF-<date>-<branch>.md`,
via `/read-handoff`), executes each
verification_request independently, and confirms or downgrades exit_state. Procedure:
the verifier records its outcome by logging a FRESH terminal handoff event via
`log_decision` (event_type: 'handoff', prognosis: JSON.stringify(prognosisObject)) - a
messages row only; nothing is written to disk by the plugin. The
verifier's prognosis carries the verification results per verification_id (status
verified-pass | verified-fail | verified-partial, evidence, the verifier session ID, and
a timestamp) plus the confirmed exit_state.
All verified-pass → confirm 'clean' (resolution_status 'done'); any verified-fail →
downgrade exit_state to 'crisis' (resolution_status 'escalated', failure details in the
prognosis); mixed pass+partial → 'manual-halt' (resolution_status 'pending-owner'). The
producer session NEVER writes the Verification Result — it is the verifier's contract
only; no self-certification; untrusted markers block SELF-RERUN.

### 7.6 Cycles budget

- Default `max-cycles=3`; override 2..10 (clamped); `max-cycles=1` disallowed; >10
  requires a change split (design.md §7, ADR-004).
- Exit states: `clean` / `crisis` / `exhausted` / `manual-halt`. `exhausted` is a soft
  non-crisis exit with a ≤200-char postmortem and NO C6 trigger (ADR-005).
- Budget increments only on full audit pass (complete handoff file + successor
  acknowledgment); ≥25% context reruns are tracked but do not
  consume budget unless the cycle terminates.

### 7.7 Reference artifacts

- Template: `openspec/templates/HANDOFF.md` (prognosis schema), `openspec/templates/T5-row.md`
  (task row with cycle attribution).
- Fixtures: `openspec/changes/dia-redispatch-cycle/fixtures/` — crisis drills (VP-2),
  budget edge cases (VP-4), batch-approval simulation (VP-3, historical: the boot gate is
  removed), independence verification
  (VP-5), messages schema fixture (VP-6), integration simulation (VP-7).

### 7.8 Handoff-file loss recovery

Handoff files are per-branch markdown snapshots written by `/make-handoff`. If one is
missing, clobbered, or was never written, the history can be
reconstructed from:
(a) messages.jsonl (full message log, plugin-managed)
(b) registry.jsonl (ticket↔lane↔session_id cross-refs, A2)
(c) Native session recall (session.prompt({path:{id}}))
(d) log_decision events (semantic events: handoffs, crises, decisions)

This is slower than the convenience file but lossless. The handoff file is
an optimization, not the source of truth.
