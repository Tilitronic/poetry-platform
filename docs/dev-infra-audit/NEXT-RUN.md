# Dev-Infra Audit — Next-Run Instruction (Orchestrator Operating Manual)

This is the operating manual for the **next orchestrator instance** that resumes or
reruns the dev-infra audit campaign. You (the orchestrator) are read-restricted and
delegation-only — read this file plus the session log, then run the campaign
through delegated lanes.

---

## 1. Boot Sequence

Read these files **in this order** when a session starts:

1. **HANDOFF RESOLUTION CHAIN (DIA-085 parallel-handoff-slots)** - resolve the
   resume-point handoff in this order:
   (a) `.opencode/session/handoffs/active.json` - read the pointer via direct
   `read()` (deterministic path); if it exists and parses, resolve
   `active_session_id` to the slot `.opencode/session/handoffs/<session-id>.json`.
   (b) If the pointer is missing/stale/mismatched (its slot file is absent), mtime
   scan `.opencode/session/handoffs/*.json` (exclude `active.json`, `.reconciled`,
   `archive/`); if exactly 1 slot, use it; if > 1, present ALL as pending
   reconciliations (section 7.3 batch approval).
   (c) If `handoffs/` is empty, fall back to the legacy
   `.opencode/session/current-handoff.json` (READ-ONLY fallback; the new writer
   never touches it).
   The slot is the resume point from a previous instance (previous session id,
   last message #, reason, campaign state, resume instructions). During detection,
   NOTE the stored `checksum` field state (present 64-hex / null / missing); do NOT
   compute or compare SHA256 here - the orchestrator has no bash tool by design
   (DIA-093). Present the checksum state in the prognosis presentation; actual
   computation and verification is delegated to the lane-0 coder step AFTER batch
   approval (section 7.3 step 7).
   1.5. **BATCH-APPROVAL GATE (G1)** - if the handoff file exists and contains a
   "Prognosis for next cycle" section (inside the `prognosis` field), present the
   full prognosis (including the noted checksum state) to the developer as a
   **batch approval** BEFORE reading messages.md or delegating any work. Checksum
   computation and integrity comparison happen in the lane-0 coder step after
   approval, not at presentation. See section 7.3 for protocol.
   1.6. **DIA-124 NOTE** - the handoff file exists at boot (in the normal flow)
   because the prior session honored the DIA-124 hard rule (7.2): it wrote the
   handoff BEFORE presenting its final summary. A missing file means the prior
   session failed the rule - record it as a finding; the batch-approval /
   normal-boot flow is unaffected (7.3).
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
- **WRITE RESTRICTION**: you write NO files directly - the per-session handoff slot
  (`.opencode/session/handoffs/<session-id>.json`) is written SOLELY by the
  delegation-observer plugin via `log_decision` (event_type: 'handoff', terminal
  resolution_status, prognosis: JSON.stringify(prognosisObject)); the plugin writes
  the per-session slot atomically + updates the pointer
  (`.opencode/session/handoffs/active.json`); manual write/edit of the handoff file
  is forbidden (DIA-120). Never edit code, config, or docs directly. messages.md /
  messages.jsonl are plugin-managed - never append to them (see SESSION LOGGING below).
- **SESSION LOGGING**: automatic via delegation-observer plugin; use `log_decision` tool for semantic events; do NOT manually edit messages.md or messages.jsonl
- **SELF-RERUN**: OpenCode native compaction (`compaction.auto: true`, opencode.jsonc)
  handles RAW context pressure within a session — no human action needed for compaction
  events. SELF-RERUN is triggered by: (a) **CAMPAIGN MILESTONE** — a major phase
  completes (implementation done, review disposition finalized, campaign complete) and
  the next phase benefits from a fresh session; (b) **CONTEXT DEGRADATION** — compaction
  has compacted campaign-critical context (the handoff file, prognosis, cycle state) so the
  orchestrator cannot reliably continue; (c) **PRIMARY THRESHOLD** — context usage
  > = 15% of the model context window (150K tokens for 1M-window models); (d) **HARD
  > SAFETY-NET** — context usage >= 25% (unconditional force). On ANY trigger: build the
  > handoff prognosis and log it via `log_decision` (event_type: 'handoff',
  > resolution_status: 'done', prognosis: JSON.stringify(prognosisObject)) — the plugin
  > writes the per-session slot atomically + updates the pointer; the prognosis
  > carries previous session id, last message #, reason, campaign
  > state incl. active tickets + next lane + gates passed, resume instructions. Then
  > end your turn telling the user a fresh session should be started —
  > the next instance reads the handoff file + messages.md and resumes. Detection: call
  > `context_usage` (delegation-observer plugin tool); it returns estimated usage as a
  > fraction of the model context window using registry.jsonl activity signals and
  > session metadata. The tool handles model context-window lookup internally (1M
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
  work, produce the crisis handoff by logging it via `log_decision` (event_type: 'handoff',
  resolution_status: 'escalated', prognosis: JSON.stringify(crisisPrognosis)) — the plugin
  writes the per-session slot atomically + updates the pointer (all 5 subsections,
  abbreviated in content per design.md §1 Option A: session_summary includes crisis_triggers;
  fixes_applied may be empty; open_tickets populated; verification_request/resume_instructions
  describe crisis-handling only) and computes/stores the checksum. Separately log the
  semantic crisis event via `log_decision` (event_type: 'crisis', resolution_status:
  'escalated') — a log row only, it does NOT write the handoff file (DIA-120). Then end the
  turn telling the user a FRESH session must be started — crisis
  takes precedence over SELF-RERUN (no self-rerun from the same context).
- **COUNCIL-BUDGET-GUARD**: the orchestrator MUST monitor cumulative council-dispatch credit
  spend against a 1500-credit session budget. **Warn** at 75% (1125 credits): emit a visible
  notice to the developer with the current spend + remaining budget; continue dispatching.
  **Hard-stop** at 90% (1350 credits): cease all council dispatches for the remainder of the
  session; notify the developer; hand off remaining council-needs to the next session via the
  handoff file's prognosis. Detection: `context_usage` (delegation-observer plugin tool)
  with `scope: council` to get the council-dispatch subset; credit cost per councillor
  dispatch is model-dependent (use the `estimated_credits` field from `context_usage`,
  not a static lookup). If the plugin is not loaded, fall back to counting council
  dispatches from registry.jsonl rows where agent='council' or agent='councillor'
  (visible via read() of registry.jsonl) × model cost estimate.
- **PROGNOSIS-DISCIPLINE**: every cycle termination (clean / crisis / exhausted / manual-halt)
  MUST produce a handoff slot (.opencode/session/handoffs/<session-id>.json) containing exactly one "Prognosis
  for next cycle" section with five folded subsections (session_summary / fixes_applied /
  open_tickets / verification_request / resume_instructions) — no separate PROGNOSIS.md
  (ADR-001). The prognosis is the single source of truth for the successor session, must be
  self-contained (successor reconstructs context from the handoff file alone), structured, honest
  (no sandbagging), and actionable. Includes a SHA256 `checksum` field over the prognosis for
  integrity verification. Clean termination requires FRESH-session independent verification —
  **no self-certification**; "I verified" markers are UNTRUSTED and block SELF-RERUN (ADR-003).
  Cycles budget (default max-cycles=3, override 2..10 clamped, 1 disallowed, >10 requires
  split) is recorded in the cycle handoff file (current/max, clean-re-audit, budget-exhausted) +
  the campaign trigger manifest — NOT in this file. Full rule text: design.md §2 / §7 / §9.
- **HANDOFF-REFRESH (G2)**: the handoff slot must be **REWRITTEN** (not appended) at each
  campaign milestone: (a) after any implementation lane completes; (b) after any review
  disposition is finalized; (c) after any commit lane lands; (d) at campaign completion.
  A rewrite = logging a FRESH terminal handoff via `log_decision` (event_type: 'handoff',
  terminal resolution_status, prognosis: JSON.stringify(prognosisObject)) - the plugin
  atomically replaces the per-session slot + updates the pointer; never edit the file in
  place (DIA-120). Each rewrite
  captures the current state snapshot — supersede, do not accumulate stale sections.
  Detection: after a plugin-logged delegation row whose result contains
  DONE/COMPLETE/PASS for an implementation/review/commit lane, log the fresh handoff within
  the same delegation cycle.
- **DELEGATION MAP**: research→@researcher, analysis→@analyzer, inventory→@code-navigator,
  implementation→@coder (after @openspec-plan spec; tdd-craftsman), review→@reviewer,
  architecture→@architector, opencode-config research/review→@ai-specialist,
  knowledge-source curation→@resource-manager, knowledge persist→@memory-manager,
  docs/mechanical→@coder, visual→@designer/@observer.
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

Before ANY escalated dispatch to a quota-metered lane, the orchestrator MUST:

1. Consult `knowledge/model-registry.yaml` to identify the model's `req_per_month` cap. If null (Copilot-credit lanes), SKIP the guard.
2. Count the lane's consumption in `registry.jsonl` matching `event: 'session_spawn'` for that model within the current YYYY-MM window.
3. Thresholds:
   - If count >= 80% of cap: WARN (state the remaining headroom in the dispatch justification).
   - If count+1 > cap: HARD-STOP. Do NOT dispatch. Use the defined `fallback[]` from the registry or `wait_for_user`.
4. SILENT_FAILURE Check: Before re-dispatching a previously-failed lane, check `registry.jsonl` for a `dispatch_state` of SILENT_FAILURE. If present, treat exactly like a quota-stop (fallback or wait_for_user); do not blindly retry.

## 3. Audit Rerun Flow

Run gates **in order** by DELEGATING verification-only lanes to @coder
(delegations are plugin-logged automatically; gate outcomes go through `log_decision`):

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
   exit-gate evidence is in hand — verification results from @coder/@reviewer (relevant
   `make test-*` suite exit 0, lint clean, typecheck clean, `openspec validate` if
   applicable), review disposition complete (all findings accepted/rejected by developer),
   `git status` shows no unrelated changes. Gate failure ⇒ exit_state "manual-halt" (never
   "clean") with the unconfirmed gates listed as open_tickets. Lane-0 checksum verification
   (if a coder lane is dispatched) is POST-HOC VERIFICATION ONLY — it computes and compares,
   it never writes the handoff file.
1. **Log the terminal handoff via `log_decision`** (event_type: 'handoff',
   resolution_status: 'done' | 'escalated' | 'pending-owner', prognosis:
   JSON.stringify(prognosisObject)). The prognosis object MUST contain the "Prognosis
   for next cycle" section with the five folded subsections (session_summary /
   fixes_applied / open_tickets / verification_request / resume_instructions) per the
   schema in design.md §3 and the template `openspec/templates/HANDOFF.md`. The
   delegation-observer plugin writes the per-session slot
   (`.opencode/session/handoffs/<session-id>.json`) atomically + updates the pointer
   and computes/stores the SHA256 `checksum` field itself - NO manual file write, NO
   pre-write checksum computation, NO post-write checksum-field edits (DIA-120, DIA-093).
2. Record the cycle budget INSIDE the prognosis object (cycle current/max, clean-re-audit,
   budget-exhausted) + the campaign trigger manifest — NOT in this file (design.md §7).
   The plugin persists it with the handoff write.
3. End the turn telling the user a fresh session should be started (or, on crisis,
   that a fresh session is REQUIRED — crisis precedence over SELF-RERUN,
   design.md §1). **CRITICAL**: the `prognosis` parameter MUST be
   `JSON.stringify()`'d — the plugin parses it via `JSON.parse()` to write the
   handoff file. Plain text/objects will cause a silent parse failure and the
   handoff file will not be written. If the exit is a crisis/crash where
   `log_decision` cannot run, `resume_instructions` MUST explicitly flag
   `lane-0 checksum delegation required` (no handoff file is produced; lane-0
   at next boot recomputes and reports).

**HARD RULE (DIA-124) - handoff BEFORE final presentation.** BEFORE presenting the
session's final summary to the developer (the message that ends a delegation cycle -
cycle termination, SELF-RERUN, crisis, or campaign completion), the orchestrator MUST
have written the handoff via `log_decision` (event_type: 'handoff', terminal
resolution_status, prognosis: JSON.stringify(prognosis)) - the plugin writes the
per-session slot (`.opencode/session/handoffs/<session-id>.json`) atomically +
updates the pointer, with the DIA-061 checksum (DIA-120). Sequence: (1) write the
handoff; (2) confirm the resolved slot exists AND its `session_id` equals the
current orchestrator session AND its `checksum` field
is populated (64-hex) - via a delegated read of the file (do NOT treat the
log_decision return text as write confirmation: atomic-write failures are
caught-and-warned but the tool still returns success, DIA-124 ai-auditor finding 2);
(3) only then present the final summary, referencing the handoff. If the handoff write
fails (plugin unavailable/crash), present the summary WITH an explicit flag that the
handoff is missing, and `resume_instructions` MUST include 'lane-0 checksum delegation
required' (DIA-093 crisis path). Rationale: the developer's last interaction must
never be the only record of session state.

### 7.3 Incoming (successor) session — boot

The incoming session's FIRST action is to read the predecessor handoff file and present
the "Prognosis for next cycle" section as a **batch approval** to the developer BEFORE
any delegation or tool use (design.md §8):

0.5. PARALLELISM-CONSTRAINT — For true parallel sessions (multiple sessions
working simultaneously), use worktrees (separate checkouts → separate
.opencode/session/ dirs → no coordination). Within a single working
directory, multiple parallel sessions may each write their OWN per-session
slot (.opencode/session/handoffs/<session-id>.json) - slot filenames are
session-unique, so parallel writes never clobber each other. The pointer
(.opencode/session/handoffs/active.json) is last-writer-wins by design and is
NOT a data-loss vector: slots are the source of truth, the pointer is an
optimization. Unreconciled slots are presented for batch approval (step 0);
the .reconciled sidecar prevents re-presentation of already-approved slots. 0. **DETECTION** — at session start, resolve the handoff via the section 1
resolution chain: read `.opencode/session/handoffs/active.json`, resolve
`active_session_id` to `.opencode/session/handoffs/<session-id>.json`; if the
pointer is missing/stale/mismatched, mtime scan `handoffs/*.json`; if
`handoffs/` is empty, fall back to the legacy
`.opencode/session/current-handoff.json`. If the resolved slot/file exists AND
contains a `prognosis` field with populated subsections, the batch-approval
protocol is MANDATORY: log a detection observation via `log_decision`
(event_type: 'decision', resolution_status: 'acknowledged',
content_ref: 'handoff-detected', task_ref: 'batch-approval-gate') noting the
resolved slot's `session_id` before proceeding. If no handoff file exists or it
has no prognosis section, skip to normal boot (§1).
DIA-124 SELF-CHECK: this gate also implicitly verifies the prior session honored
DIA-124 - a missing handoff at boot means the prior session failed the rule
(presented its final summary without writing the handoff). Treat that as a finding
to record, NOT a blocker; the gate proceeds per the normal flow.

1. **VERIFY INTEGRITY (delegated, DIA-093)** - the DIA-061 SHA256 of the `prognosis`
   object of the RESOLVED SLOT (from the step-0 chain; the legacy file only when the
   chain fell back to it) is computed by a coder lane as lane-0 immediately after batch
   approval (step 7), not by the orchestrator (no bash tool by design). At this step only
   NOTE the stored
   `checksum` field state (present 64-hex / null / missing). A missing or invalid checksum
   does NOT block presentation - it is flagged in the prognosis presentation and resolved
   by the lane-0 delegation (step 7). At COMPARISON TIME (after lane-0 returns the computed
   value) RE-READ the handoff file's `checksum` field fresh - do NOT compare against the
   value memorized from the boot read (DIA-120 secondary finding 1: the file may have been
   rewritten in between, turning a clobber into a false mismatch). A MISMATCH after lane-0
   computation is treated as tampered/corrupted: escalate to developer immediately,
   reporting BOTH `stored=` (the re-read value) and `computed=` (the lane-0 value) in the
   escalation.
2. Read the handoff file and parse the `prognosis` section.
3. Present each subsection as a batch: session_summary → fixes_applied → open_tickets →
   verification_request → resume_instructions.
   3a. TICKET-REFERENCE FORMAT: when presenting open_tickets or any subsection that
   references DIA tickets, ALWAYS quote the ticket ID + human-readable slug from
   the filename (e.g., "DIA-100 'git worktrees for parallel dev sessions'", not
   "DIA-100" alone). The slug is derivable from the ticket filename
   (DIA-NNN-<descriptor>.md) or the README index. This applies to all
   user-facing references: batch approvals, handoff prognoses, session summaries,
   and log_decision content_ref fields.
4. Developer approves per item (approve / defer / reject).
5. Rejected items become new open_tickets; deferred items carry forward.
6. During open_tickets review, run the **C5 check**: if a `[BLOCKING]` ticket from the
   predecessor was supposed to be resolved but wasn't, C5 fires (design.md §1).
7. **LANE-0 CHECKSUM DELEGATION (automatic; no waiver menu; VERIFICATION ONLY — DIA-093,
   DIA-120).** Immediately after batch approval and BEFORE any verification_request item,
   dispatch @coder on a single-task brief to compute the DIA-061 canonical checksum of the
   RESOLVED SLOT (path from the step-0 chain - the slot
   `.opencode/session/handoffs/<session-id>.json`, NOT the legacy file unless the chain
   fell back to it):
   `jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' .opencode/session/handoffs/<session-id>.json | tr -d '\n' | sha256sum`
   The lane computes the canonical value for VERIFICATION ONLY — it MUST NOT write or edit
   the handoff file (the file is written SOLELY by the delegation-observer plugin via
   `log_decision(handoff, ..., JSON.stringify(prognosis))`; the plugin computes and stores
   the `checksum` field atomically, DIA-120). At comparison time RE-READ the handoff file's
   `checksum` field fresh — never compare against a value memorized from the boot read
   (DIA-120 secondary finding 1). Compare `stored=` (re-read) vs `computed=`:
   (a) mismatch means tampered handoff: refuse further work, escalate to developer
   immediately; (b) if checksum was null/missing, the computed value verifies the prognosis
   as-is — the file is NOT edited; the next terminal `log_decision(handoff)` populates the
   `checksum` field automatically — proceed; (c) match: proceed. Developer waiver exists
   ONLY for crash exits where coder dispatch itself fails.
8. **VERIFICATION** — after the developer approves ALL items, log a decision event via
   `log_decision` (event_type: 'decision', resolution_status: 'acknowledged',
   content_ref: 'batch-approval-complete'); ONLY THEN begin work. Rejected items become
   new open_tickets and await instruction — they are not silently carried forward.
9. **MARK RECONCILED (DIA-085 parallel-handoff-slots)** - after batch approval, append
   the resolved slot's `session_id` to `.opencode/session/handoffs/.reconciled` (atomic
   temp+rename write, same pattern as the slot/pointer writes; `.reconciled` is a
   sidecar, not the handoff file, so direct writing is permitted). This prevents the
   boot gate from re-presenting the same prognosis on subsequent boots (the section 1
   resolution chain filters reconciled slots from the mtime scan).

### 7.4 Crisis handling

On any C1–C5 trigger (design.md §1): halt the cycle, produce the crisis handoff by logging
it via `log_decision` (event_type: 'handoff', resolution_status: 'escalated', prognosis:
JSON.stringify(crisisPrognosis)) — the plugin writes the per-session slot atomically +
updates the pointer (`.opencode/session/handoffs/<session-id>.json`, all 5 subsections,
abbreviated in content —
session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets
populated; verification_request/resume_instructions describe crisis-handling only) — then
notify the developer with trigger identity and evidence, and let the developer decide:
extend the cycle, start a fresh cycle (counts against budget), or close the change.

### 7.5 Clean termination

A `clean` exit requires fresh-session independent verification (design.md §9, ADR-003):
the session that produced the work cannot certify its own completion. The fresh session
reads the handoff (the resolved slot per section 1, e.g.
`.opencode/session/handoffs/<session-id>.json`), executes each
verification_request independently, and confirms or downgrades exit_state. Procedure:
the verifier records its outcome by logging a FRESH terminal handoff via `log_decision`
(event_type: 'handoff', prognosis: JSON.stringify(prognosisObject)) — the plugin writes
the per-session slot atomically + updates the pointer (no manual append/edit of the
handoff file, DIA-120). The
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
  acknowledgment via batch approval); ≥25% context reruns are tracked but do not
  consume budget unless the cycle terminates.

### 7.7 Reference artifacts

- Template: `openspec/templates/HANDOFF.md` (prognosis schema), `openspec/templates/T5-row.md`
  (task row with cycle attribution).
- Fixtures: `openspec/changes/dia-redispatch-cycle/fixtures/` — crisis drills (VP-2),
  budget edge cases (VP-4), batch-approval simulation (VP-3), independence verification
  (VP-5), messages schema fixture (VP-6), integration simulation (VP-7).

### 7.8 Handoff-file loss recovery

NOTE (DIA-085 parallel-handoff-slots): archive-on-overwrite preserves prior
same-session slot content under
`.opencode/session/handoffs/archive/<session-id>.<ts>.json` before a rewrite, so a
clobbered current slot is recoverable from its own archive entry - reducing the
frequency of section 7.8 invocation. Section 7.8 remains the lossless fallback for
catastrophic cases
(whole-`handoffs/` loss, filesystem corruption).

If current-handoff.json is clobbered or missing, the prognosis can be
reconstructed from:
(a) messages.jsonl (full message log, plugin-managed)
(b) registry.jsonl (ticket↔lane↔session_id cross-refs, A2)
(c) Native session recall (session.prompt({path:{id}}))
(d) log_decision events (semantic events: handoffs, crises, decisions)

This is slower than the convenience file but lossless. The handoff file is
an optimization, not the source of truth.
