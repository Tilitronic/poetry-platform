# DIA-051 — Raw JSONL telemetry leak into human chat UI (messages.jsonl sidecar)

<!-- Owner-reported system bug (UA context). Backlog-only ticket: documents the
     defect + owner-directed fix direction. NO code/config change is made by
     this ticket; implementation is out of scope and awaits owner scheduling.
     Fix touches .opencode/ config + plugin → routes through §10 (AI Devtools
     Modernization Workflow) when scheduled. -->

---

id: DIA-051
title: "Raw JSONL telemetry leak into human chat UI (messages.jsonl sidecar)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-06
source: owner-reported
date: 2026-08-06
created: 2026-08-06
updated: 2026-08-06

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Summary:** raw JSONL telemetry payload (the machine-readable sidecar rows
destined for `.opencode/session/messages.jsonl`) leaks into the human chat UI.
During orchestrator decision logging, the owner sees raw telemetry JSON rendered
in the conversation instead of a clean human summary — the human channel is
polluted with machine-only data.

**Reproduction context:** the orchestrator logs decisions under the
`.opencode/session/README.md` append discipline — `messages.md` is the
human-readable export and `messages.jsonl` is the machine-readable sidecar
(one JSON object per event, semconv v1.42.0; dual-write mandated by the
orchestrator prompt additions in `oh-my-opencode-slim.jsonc` + the JSONL
sidecar section of `orchestrator_append.md`, per the 2026-08-03 T1
implementation). During orchestrator decision logging the raw JSONL row
intended for the sidecar is emitted into the chat channel instead of staying
file-only.

**Impact:** the human channel is polluted with machine-only telemetry; breaks
the human-readable UI contract; adds confusion/noise to every delegation cycle.
Owner-visible every time the orchestrator logs a decision.

## Verification

1. Observe an orchestrator decision-logging cycle; confirm raw JSONL (a
   `messages.jsonl`-shaped row, e.g. `gen_ai.operation.name` /
   `event_type` fields per `.opencode/session/README.md` schema) appears in the
   human chat UI instead of a clean summary.
2. Correlate the leaked row against `.opencode/session/messages.jsonl` —
   expect the exact same payload (dual-write leak, not a summary).
3. Post-fix (when scheduled): `make test-config` exit 0, restart OpenCode, then
   smoke one delegation cycle — JSONL payload must appear ONLY in
   `messages.jsonl` / `messages.md`, never in chat (per §10 Phase 5).

## Fix

> To be filled at fix time. Owner-directed direction (2026-08-06) captured
> below — backlog item awaiting owner scheduling; NOT implemented by this
> ticket.

**Fix approach (owner-directed) — "silent logging":** the messages.jsonl
payload must be written ONLY to the sidecar file (and messages.md), never
surfaced in the human chat UI. Two candidate implementation sites
(owner-specified, both must be listed):

1. **Candidate A — Config level:** `.opencode/oh-my-opencode-slim.jsonc` —
   suppress / log-silently the orchestrator's JSONL emission (the prompt
   strings that mandate `messages.md + messages.jsonl` dual-write), so the
   JSONL row is written to the file only, never rendered in chat.
2. **Candidate B — Plugin level:** `delegation-observer.ts` at
   `.opencode/plugins/delegation-observer.ts` — route JSONL to file/stderr
   only, never chat (plugin-level routing guard on the sidecar write).

**§10 routing note (MANDATORY):** this fix touches `.opencode/` config + a
plugin → when implemented it MUST route through §10 (AI Devtools Modernization
Workflow): @ai-specialist gate → design → @coder → @ai-specialist independent
review → restart + smoke. Verification gates when implemented: `make
test-config` exit 0, JSONC parse, restart-verify per §10 Phase 5.

**Out of scope:** no code/config change in this ticket; backlog item awaiting
owner scheduling.

**Resolved-by-implementation (2026-08-06):** the silent-session-logging campaign
(Option E) implemented the fix — the delegation-observer plugin writes JSONL to
file only (never the human chat UI), `messages.md` is a derived view, and the
`log_decision` tool is restricted to orchestrator ("allow"). See CHANGELOG
2026-08-06 + learnings/external-patterns/2026-08-06-silent-session-logging.md.

## Re-verify

**Close (2026-08-06, resolved-by-implementation):** P5 smoke PASS 100%
(in-universe 8/8) — JSONL rows written silently by the delegation-observer
plugin (writer:"plugin", row_id, event_uuid), no raw telemetry rendered in the
human chat UI; `make jsonl-cross-check` exit 0 (registry 213 task_success = 205
legacy + 8 in-universe; ≥99% completeness, ±5s tolerance). Status flipped
OPEN → CLOSED 2026-08-06 per §10 Phase 6 registration.
