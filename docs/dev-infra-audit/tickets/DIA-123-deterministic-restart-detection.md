# DIA-123 - deterministic opencode restart detection for the orchestrator

<!-- UPDATE 2026-08-13 (IMPLEMENTED - VERIFIED, CLOSURE PENDING NEXT SESSION): implemented by cod-35 (ses_0010adea2ffe6G1Zq92g0jYAIq): (1) `session_boot` registry.jsonl event emitted at plugin body top-level (process load, before any session activity) via appendRow (seq + timestamp + writer conventions preserved) with boot_id (randomUUID), process_started_at (captured BEFORE file I/O), config_load_signal (opencode.jsonc + oh-my-opencode-slim.jsonc mtimes at load), optional opencode_version (env best-effort); (2) dedicated boot marker .opencode/session/boot.json (atomic write tmp->fsync->rename->dir fsync, fail-soft) with version/event/boot_id/seq/process_started_at/timestamp/config_load_signal/writer - NOT a ticker.json field (ticker.json owned by needs-input-observer.ts, out of scope; documented deviation); (3) seq seed changed from lines.filter(Boolean).length to Math.max(maxSeq, lineCount) - strictly monotonic after external row removal (45 out-of-order transitions confirmed in live registry, new seed 3447); (4) determinism: process_started_at is authoritative boot time, verifier compares >= recorded config mtime. Validation: npx tsc exit 0, make test-config exit 0, make test-shell exit 0 (280), prettier --check clean, seq dry-run monotonic. LIVE RESTART-VERIFY PENDING next opencode launch (DIA-123 pattern): launch opencode, grep '"event":"session_boot"' registry.jsonl + cat boot.json, touch config + restart -> new boot row shows newer mtime. Closure (ai-auditor review + ticket status) pending next session per developer instruction (session ended after this ticket's implementation).

     Planning ticket filed 2026-08-13 from the DIA-122 restart-verify evidence
     lane (2026-08-13). During the DIA-122 restart-verify, the evidence lane
     detected the opencode restart only through the needs-input-observer ticker
     boot re-seed (ticker.json created at 2026-08-12T22:41:40Z with empty
     waiting/errors lists = fresh boot state). This detection was FRAGILE - it
     worked only because of directory-mtime proof of file creation. The
     developer requested a ticket for a deterministic restart-detection tool so
     the orchestrator can reliably detect opencode restarts in the future.
     This is an opencode-config feature request. Planning ticket - no
     implementation performed yet. -->

---

id: DIA-123
title: "deterministic opencode restart detection for the orchestrator"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-13
source: evidence-lane (DIA-122 restart-verify)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

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

**Background (2026-08-13 DIA-122 restart-verify evidence lane):** the only
artifact that proved the opencode tool load after the DIA-122 restart was the
needs-input-observer ticker boot re-seed. Today's detection was FRAGILE and
non-deterministic - the orchestrator needs a deterministic restart-detection
mechanism for future restarts.

**(a) The observed detection:** ticker.json created 2026-08-12T22:41:40.490Z,
`updated_at` 22:41:40.492Z matching the file mtime, `version` 1, empty
`waiting` and `errors` lists, parent dir mtime 22:41:40.494Z proving file
CREATION at that instant - the only artifact proving the tool loaded after
restart.

**(b) The five weaknesses that make this non-deterministic:**

1. No `session.created` / boot / tool-load events exist in registry.jsonl
   (0 of 2934 rows) or messages.jsonl (0 rows) - ticker.json existence is the
   ONLY artifact proving tool load.
2. ticker.json `updated_at` is indistinguishable from a periodic rewrite
   without a dedicated boot marker (a `boot_id` / `process_started_at` field
   separate from `updated_at`); only the dir-mtime proof of file creation made
   today's detection a boot re-seed - a future rewrite would lose that
   evidence.
3. registry.jsonl sequence numbers are non-monotonic (35 out-of-order
   transitions observed, last 2898 -> 2866), indicating external
   rewriting/reordering that makes seq-based reasoning unreliable.
4. messages.jsonl writer is stale vs registry.jsonl writer (22:40:21Z vs
   22:42:42Z at detection time) - two divergent freshness domains.
5. current-handoff.json still references the PRIOR session
   (ses_0088b118...), so the handoff timestamp cannot serve as current-session
   restart evidence.

**(c) Proposed deterministic mechanism (to be designed at fix time, NOT
implemented now):**

- Emit an explicit boot/init event (`session.created` for the orchestrator
  session, or `tool.load` with process start time, opencode version, and
  registered tool list) written atomically to registry.jsonl.
- Add a `boot_id` / `process_started_at` field to ticker.json separate from
  `updated_at`.
- Enforce monotonic sequence numbers.
- Unify the event writer so boot evidence lands in the same stream as activity
  evidence.

**Workflow requirements:** if the fix touches `.opencode/` tooling it must
route through the AI Devtools Modernization Workflow (gate research ->
developer review -> design -> implement -> validate -> independent review ->
register). DIA-063 section-10 ticket gate satisfied by this ticket.

## Verification

> To be filled at fix time.

## Fix

**Implemented 2026-08-14 by the DIA-123 section-10 Phase-4 lane (file:
`.opencode/plugins/delegation-observer.ts`, the ONLY implementation file
touched besides this ticket). No commit made - commit deferred to end of
session.**

### What was implemented (ticket (c) mechanism, scoped to the lane)

1. **Boot event row in registry.jsonl** - `event: "session_boot"` written via
   the existing `appendRow` (same stream as activity evidence - satisfies the
   unify-event-writer concern). Fields: `seq` (auto), `timestamp` (auto -
   row-WRITE time), `event: "session_boot"`, `boot_id` (randomUUID), `process_started_at`
   (plugin-load time captured before ANY file I/O - the deterministic T1),
   `config_load_signal` (opencode.jsonc + oh-my-opencode-slim.jsonc mtimes AT
   LOAD - the config state the process actually saw), optional `opencode_version`
   (env `OPENCODE_VERSION`, best-effort - the @opencode-ai/plugin input exposes
   no version getter), `writer: "plugin"`. Emitted in the plugin body top-level
   at load, before any session activity, before `return hooks`.

2. **Dedicated boot marker file `.opencode/session/boot.json`** - NOT a field in
   ticker.json (that file is owned by needs-input-observer.ts, outside this
   lane's scope; its `updated_at` is indistinguishable from a periodic rewrite -
   DIA-123 finding b2). The dedicated marker carries `boot_id` + `seq` +
   `process_started_at` + `timestamp` + `config_load_signal` + optional
   `opencode_version`, written atomically (tmp -> fsync -> rename -> dir fsync,
   same pattern as `atomicWriteHandoff`). Fail-soft: a lost marker never crashes
   the plugin; the registry row remains canonical.

3. **Monotonic seq discipline** - the seq seed was `lines.filter(Boolean).length`
   (line count), which regresses when rows are removed/reordered externally
   (observed 2898 -> 2866). Now seeded from `Math.max(maxSeq, lineCount)` - the
   next row is strictly greater than every existing row even after removal;
   legacy rows WITHOUT a seq field still advance past the line count as before.

4. **Determinism proof** (for the closure lane): a verifier reads boot.json /
   the latest `session_boot` row and compares `process_started_at` (T1) against
   the recorded `config_load_signal` mtimes (T0) AND against the CURRENT config
   file mtimes. If current config mtime > recorded mtime -> config written AFTER
   boot -> restart required. If process_started_at >= recorded mtime -> the
   process booted after that config write -> the config IS loaded. The marker
   does NOT rely on seq alone (known non-monotonic) - `boot_id` +
   `process_started_at` are the authoritative identity.

### What could NOT be tested live (lane cannot trigger a plugin load)

- The live restart-verify (launch opencode, observe the `session_boot` row +
  boot.json appear) is the closure lane's job per the DIA-123 pattern.

### Validation evidence (lane)

- `npx tsc --noEmit --strict --skipLibCheck --target ESNext --module preserve
--moduleResolution bundler .opencode/plugins/delegation-observer.ts` -> exit 0
- `make test-config` -> exit 0 (drift gate 8 markers x 3 presets unaffected;
  test-ticket-gate.sh regression patterns still present)
- `make test-shell` -> exit 0 (280 bats tests pass)
- prettier `--check` on the plugin -> clean
- Static functional verification: (a) emit call site is in the plugin body
  top-level (line ~517), which runs at plugin load before hooks return;
  (b) `session_boot` present (5 refs); (c) no plugin unit-test harness exists
  (only the static test-ticket-gate.sh probe, which passed). Seq dry-run against
  the real registry: 3446 rows, maxSeq 3446, 45 out-of-order transitions found
  in the file (confirms the DIA-123 finding), new seed = 3446 -> next row 3447,
  strictly monotonic.

### Closure-lane restart-verify procedure (record in Fix/Re-verify)

1. Launch an opencode process in this repo (e.g. `make opencode` or the TUI).
2. `grep '"event":"session_boot"' .opencode/session/registry.jsonl` - expect a
   row with `boot_id`, `process_started_at` close to launch time, and
   `config_load_signal` mtimes.
3. `cat .opencode/session/boot.json` - expect `boot_id` matching the registry
   row, `process_started_at`, `seq`, `config_load_signal`.
4. Touch a config file (e.g. `.opencode/opencode.jsonc`), restart opencode,
   repeat steps 2-3: the new boot row/marker must show the NEWER config mtime,
   proving the second boot happened AFTER the write.
5. Cross-check determinism: `process_started_at` of the latest boot >= its
   recorded config mtime.

## Re-verify

> To be filled at re-verify time.
