# Design: parallel-handoff-slots

> **Proposal:** `openspec/changes/parallel-handoff-slots/proposal.md`
> **Interview:** `openspec/changes/parallel-handoff-slots/interview.md`
> **Ticket:** DIA-085
> **Scope:** dev-infra — delegation-observer plugin writer + boot-gate protocol. No
> application code, no system architecture escalation.

## Context

### Relationship to the ana011 protocol (interview Q1 decision)

ana011 (`knowledge/ana011-parallel-sessions-coordination/`) defines the full
claim+heartbeat coordination model for parallel orchestrator sessions: task
ownership, heartbeat intervals, stale-claim detection, reclaim procedure,
resume-after-stop. This change implements ONE specific conflict from ana011's
conflict table ("Handoff clobber = HARD") and EXPLICITLY DEFERS the rest of
ana011 to a follow-up change.

The separation is intentional:

- This change = make handoff writes safe for parallel sessions (slotting).
- Follow-up change = coordinate task ownership across parallel sessions (claims).

The slotting in this change is a NECESSARY PREREQUISITE for ana011 to work
correctly (ana011's "in-worktree work" handoff semantics in §4 assume each
session has its own handoff slot).

### Design authority (.sdd/) reference

- `.sdd/dev-infra/architecture.md` — worktrees-only parallel model. This
  change operates within those boundaries (no new module boundary).
- `.sdd/dia-redispatch-cycle/architecture.md` — ADR-001 (prognosis in
  HANDOFF only) and the cycle termination protocol. This change extends
  with multi-session safety; does not contradict ADR-001.
- DIA-120 (CLOSED, commit e15a876) — terminal-status filter. This change
  preserves that filter; does not re-open the in-flight/non-terminal
  question.

No `.sdd/` module doc exists specifically for delegation-observer.ts. The
plugin is governed by NEXT-RUN.md §7 + AGENTS.md §6 operating rules.

---

## §1 — File layout

### New directory structure

```
.opencode/session/
  current-handoff.json               # LEGACY, read-only fallback (untouched by new writer)
  handoffs/
    active.json                      # POINTER: optimization, points to most recent slot
    .reconciled                      # RECONCILIATION: session_ids already batch-approved
    <session-id>.json                # SLOT: per-session handoff, one per terminal write
    <session-id>.json                # (multiple, one per parallel session)
    archive/
      <session-id>.<iso-ts>.json     # ARCHIVE: prior slot content on same-session rewrite
```

All under `.opencode/session/`, so `.gitignore:82` covers everything.

### Slot file format

Identical JSON schema to current `current-handoff.json`:

```json
{
  "status": "done" | "failed" | "manual-halt",
  "session_id": "ses_...",
  "cycle_id": "c-..." | null,
  "timestamp": "2026-08-15T09:04:54.000Z",
  "checksum": "<64-hex-SHA256-over-canonical-prognosis>",
  "prognosis": {
    "session_summary": { ... },
    "fixes_applied": [ ... ],
    "open_tickets": [ ... ],
    "verification_request": [ ... ],
    "resume_instructions": "..."
  }
}
```

**No schema change from the single-slot file.** The checksum still covers
the canonical serialization of the `prognosis` object (DIA-061).

### Pointer file format

```json
{
  "active_session_id": "ses_...",
  "timestamp": "2026-08-15T09:04:54.000Z",
  "pointer_version": 1
}
```

`pointer_version: 1` allows future schema evolution. Pointer is written
AFTER slot (order matters — see §3 error states).

### Reconciled sidecar format

```json
{
  "reconciled_sessions": ["ses_...", "ses_..."],
  "last_updated": "2026-08-15T09:10:00.000Z"
}
```

After batch approval of a slot, its session_id is appended here. Boot gate
filters out reconciled slots when scanning for unreconciled ones.

### Archive filename convention

`<session-id>.<iso-timestamp-with-hyphens>.json`

Example: `ses_ffd538953ffeHi5JxeN4RF1aAp.2026-08-15T09-04-54.json`

Colons in the ISO timestamp are replaced with hyphens for filesystem safety
(portable across POSIX, Windows, Docker volumes).

---

## §2 — Writer flow

### atomicWriteHandoff (new flow)

```
Input: content (Record<string, unknown>), sessionId (string)
Step 1: archive_prior(sessionId)
   if handoffs/<sessionId>.json exists:
      ts = now().toISOString() with colons -> hyphens
      renameSync(handoffs/<sessionId>.json,
                 handoffs/archive/<sessionId>.<ts>.json)
      on error: console.warn + continue (best-effort archive)
Step 2: write_slot(content, sessionId)
   tmpPath = handoffs/.<sessionId>.json.tmp
   writeFileSync(tmpPath, JSON.stringify(content))
   fsync(tmpPath)
   renameSync(tmpPath, handoffs/<sessionId>.json)  // atomic by POSIX
   fsyncDir(handoffs/)
Step 3: write_pointer(sessionId)
   pointerContent = { active_session_id: sessionId, timestamp: now(),
                      pointer_version: 1 }
   tmpPath = handoffs/.active.json.tmp
   writeFileSync(tmpPath, JSON.stringify(pointerContent))
   fsync(tmpPath)
   renameSync(tmpPath, handoffs/active.json)  // atomic by POSIX
   fsyncDir(handoffs/)
Step 4: registry row enrichment
   if archive happened in step 1: add archived_prior field to the
   terminal handoff registry row
```

### log_decision handler changes

At line 2448 (`atomicWriteHandoff({...})`), pass session_id explicitly:

```typescript
atomicWriteHandoff({
  status,
  session_id: parentSessionId ?? args.lane_id ?? "unknown",
  ...
}, sessionId)  // NEW parameter
```

The existing `parentSessionId ?? args.lane_id ?? "unknown"` logic becomes
the source of truth for which slot to write. No schema change to the
written JSON.

### Terminal-status filter preserved

The existing `TERMINAL_HANDOFF_STATUSES` check (DIA-120, line 2419) is
unchanged. Non-terminal events still skip the writer.

---

## §3 — Boot-gate selection chain (reader flow)

### Resolution chain

```
Step 1: try pointer
   if handoffs/active.json exists and parses:
      read active_session_id
      if handoffs/<active_session_id>.json exists:
         use it
      else:
         fall through to Step 2
   else:
      fall through to Step 2

Step 2: mtime scan
   list handoffs/*.json (exclude active.json, .reconciled, archive/*)
   filter out reconciled sessions (from .reconciled sidecar)
   if list is empty:
      fall through to Step 3
   else:
      sort by mtime descending
      if exactly 1: use it
      if > 1: present ALL as "pending reconciliations" for developer
              disposition

Step 3: legacy fallback
   if .opencode/session/current-handoff.json exists:
      use it (legacy path; mark as "legacy fallback" in presentation)
   else:
      no handoff; normal boot

Step 4: present
   present resolved slot(s) per NEXT-RUN.md §7.3 batch-approval protocol
```

### Reconciliation after batch approval

After developer approves all items in batch:

```
Step R1: read .reconciled sidecar (or initialize empty)
Step R2: append approved slot's session_id to reconciled_sessions
Step R3: atomic write of updated .reconciled (same temp+rename pattern)
```

This prevents the boot gate from re-presenting the same prognosis on
subsequent boots.

---

## §4 — Error handling table

| Failure mode                               | Behavior                                                                                                             | Rationale                                                              |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Slot rename fails (disk full / permission) | console.warn + registry error row; prior slot intact (tmp unlinked); log_decision still logs message row             | Handoff loss recoverable via §7.8; log row is more important than file |
| Pointer write fails                        | Slot still valid; pointer stale; boot falls back to mtime scan                                                       | Pointer is optimization                                                |
| Archive rename fails                       | Log warn; proceed with slot write (prior slot content lost but new one lands)                                        | Best-effort archive; not a blocker                                     |
| Two writers race, SAME session             | Last atomic rename wins; archive preserved prior slot; both prognoses survive                                        | Archive-on-overwrite is the safety net                                 |
| Two writers race, DIFFERENT sessions       | Both slots exist (different filenames, no collision); pointer points to last writer; boot presents both unreconciled | No data loss; developer disposes                                       |
| Pointer file missing                       | Boot falls back to mtime scan over `handoffs/`                                                                       | Pointer is optimization                                                |
| Pointer points to nonexistent slot         | Boot falls back to mtime scan                                                                                        | Stale pointer recovery                                                 |
| Slot JSON unreadable (corrupt)             | Log error; present raw content to boot gate for developer inspection; do NOT auto-delete                             | §7.8 still has the data; human disposes                                |
| Legacy `current-handoff.json` read fails   | Slots are authoritative; legacy is just a fallback                                                                   | Non-fatal                                                              |
| `.reconciled` file missing/corrupt         | Treat as empty reconciled set (all slots are unreconciled)                                                           | Safe default - may re-present, but no data loss                        |
| `handoffs/` directory missing              | Boot falls back to legacy; new writer creates `handoffs/` on first write                                             | Backward compat                                                        |

### Policy principle

Every failure degrades gracefully:

- POINTER is the dispensable optimization
- SLOTS are the source of truth
- ARCHIVE is the forensic safety net
- LOG ROW is the non-negotiable audit trail

---

## §5 — Observability

- **Archive event:** `console.warn "[delegation-observer] handoff archived:
<session-id> prior slot -> archive/<session-id>.<ts>.json"` before slot
  write.
- **Registry row enrichment:** existing terminal handoff registry row gains
  optional field `archived_prior: "archive/<session-id>.<ts>.json"` when an
  archive happened; omitted when no prior slot existed. Backward-compatible
  (optional field).
- **messages.jsonl log_decision row:** unchanged schema. The prognosis
  carries session's own state; `session_id` field in the written JSON
  identifies the writer.
- **Boot gate report:** when presenting batch approval, include "slot
  <session-id> (written <timestamp>); active pointer = <session-id>;
  reconciled = {true/false}" + if multiple unreconciled slots: "N
  unreconciled slots found; presenting all for disposition."
- **session-log render output:** unchanged event types; additional
  `archived_prior` field in rendered rows when present.

---

## §6 — Seams (test seams)

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-
> agreed public boundaries where tests will live."

### S1 — Plugin writer seam (unit test)

**Public boundary:** `atomicWriteHandoff(content, sessionId)` function.

**Test location:** `.opencode/plugins/__tests__/parallel-handoff.test.mjs`
(extending the DIA-189 bun harness).

**Test scenarios:**

- slot write creates `<session-id>.json` with correct schema
- pointer write creates `active.json` with correct session_id
- archive-on-overwrite creates archive/<session-id>.<ts>.json
- archive skipped when no prior slot exists
- checksum in slot matches canonical serialization of prognosis
- terminal-status filter still works (in-flight events skip writer)

### S2 — Boot-gate resolution seam (bats test)

**Public boundary:** the resolution chain logic (pointer -> mtime -> legacy).

**Test location:** `scripts/__tests__/parallel-handoff.bats` or
`scripts/test-parallel-handoff.sh` with bats-compatible assertions.

**Test scenarios (the six from proposal.md):**

- two-session smoke
- forced race
- same-session rewrite (archive)
- legacy fallback
- pointer stale recovery
- pointer mismatch recovery

### S3 — validate-handoff.sh slot-aware seam (bats test)

**Public boundary:** `validate-handoff.sh [-s <session-id>]` command.

**Test location:** extend existing `scripts/__tests__/validate-handoff.bats`
(if present) or new file.

**Test scenarios:**

- default mode reads pointer, validates pointed slot
- `-s <session-id>` validates specific slot
- missing pointer -> mtime fallback validation
- legacy fallback validation
- checksum verification on each mode

---

## §7 — Risks / Trade-offs

### Pointer atomicity vs slot atomicity

The writer does TWO atomic renames (slot, then pointer). A crash between
them leaves slot new but pointer old. **Mitigation:** pointer is an
optimization; boot gate has mtime fallback. This mirrors the §7.8 design
principle "handoff file is an optimization, not the source of truth."

### Archive growth

`handoffs/archive/` grows with every same-session rewrite. **Mitigation:**
deferred self-clean (ana011 §SCOPE-GUARD item 3 pattern: `find -mtime +30
-delete` in follow-up). Acceptable because same-session rewrites are rare
(only HANDOFF-REFRESH G2 at campaign milestones).

### Reconciled-set growth

`.reconciled` array grows indefinitely. **Mitigation:** deferred pruning
(follow-up ticket or ana011 follow-up). Acceptable at expected scale (<20
sessions per campaign).

### pointer_version insurance

Field is present for future schema evolution but no v2 is planned. Cost: 1
JSON field. Benefit: forward-compat.

### POSIX atomic rename assumption

`rename(2)` is atomic on POSIX filesystems including the Docker volume. On
Windows (not a deployment target) or network filesystems (not used), this
assumption does not hold. Documented in test headers.

---

## §8 — Open Questions (deferred)

1. **Archive retention policy.** Deferred to ana011 follow-up. When `find
-mtime +30 -delete` should run, how to wire it (cron, plugin, manual).
2. **`.reconciled` pruning.** Same question as archive. Defer.
3. **Pointer schema v2.** None planned. `pointer_version: 1` is insurance.
4. **Plugin TS unit test strategy.** The DIA-189 bun harness is the
   established pattern. Extend it; no new harness needed.

---

## §9 — Integration points

- **DIA-061 checksum verification:** unchanged semantics. Each slot has its
  own checksum; LANE-0 computes canonical checksum of the pointed slot.
- **DIA-124 session-end handoff rule:** unchanged semantics. The plugin
  writes the handoff BEFORE the final summary; now it writes to a per-
  session slot instead of the shared file.
- **DIA-120 terminal-status filter:** preserved. The fix commit e15a876 is
  not re-opened by this change.
- **NEXT-RUN.md §7.8 loss recovery:** still authoritative, but archive-on-
  overwrite reduces the frequency of §7.8 invocation.

---

<!--
ownership:
  substance: developer (via interview decisions; captured in interview.md)
  structure: AI (@openspec-plan)
  interview_depth: full
-->
