# DIA-079 — delegation-observer handoff atomic write fails — JSON Parse error: Unexpected identifier "computed"

<!-- Observed in orchestrator session (screenshot 2026-08-10, obs-1 analysis).
     Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-079
title: "delegation-observer handoff atomic write fails — JSON Parse error: Unexpected identifier \"computed\""
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty (cross-ref DIA-061 in Description)
discovered: 2026-08-10
source: test-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

The delegation-observer plugin's handoff atomic write fails with
`[delegation-observer] handoff atomic write failed: JSON Parse error: Unexpected
identifier "computed"` (observed in orchestrator session, screenshot 2026-08-10,
obs-1 analysis). The payload written by the plugin during a handoff is not valid
JSON — a bare identifier `computed` appears where JSON requires a quoted key or
string value.

Likely causes: a JS-style object key serialized without quotes (e.g.
`{computed: ...}`), or a raw string interpolated into the JSON payload (e.g. a
prognosis/log_decision field containing the word "computed", such as the boot-gate
checksum prognosis text `computed == stored == ...`).

Impact: handoff atomic writes can fail, leaving current-handoff.json
missing/corrupt — this breaks the DIA-061 boot gate (REFUSE TO RESUME on
unverifiable checksum) and campaign resume continuity. Cross-ref: DIA-061 (boot
gate depends on valid handoff file).

## Session-6 investigation findings (2026-08-11, campaign c-20260809-residual-closure)

New evidence from registry (.opencode/session/registry.jsonl) + messages log
(.opencode/session/messages.jsonl):

- ai--1 (ai-specialist, ses_010020e27ffevmWNY2tqcgbxxc, task_ref "S10 gate:
  checksum delegation fix"): returned TRUNCATED (one intro sentence, no
  findings) on an ASCII-ONLY payload. Registry: spawn 08:43:44Z -> complete
  08:47:23Z (3m38s), status COMPLETE, no failed/error row.
  Resume ai--2 (ses_00ffe26a0ffeiDyc9YCKVy8w8E, task_ref "Resume S10 gate
  report"): returned FULL but OFF-TARGET (misread A+E+F fix items as
  code-quality checksums), 53s, status COMPLETE.
- cod-5 (coder, ses_00fdfaeabffeqwXb5eg93IiQrB, task_ref "Verify items 2+3+4"):
  returned EMPTY on an ASCII-ONLY payload. Registry: spawn 09:21:17Z ->
  complete 09:32:27Z (11m09s, the LONGEST lane of the session), status
  COMPLETE, no failed/error row.
  Resume cod-6 (ses_00fd4e8a6ffe6Qe3Xqi7ky1mDX, task_ref "Resume verify items
  2+3+4"): returned the full report, 4m05s, status COMPLETE.
- Registry completeness: neither truncated lane carries a failure marker; the
  session_spawn / session_complete / task_success rows record NO message-count
  or token signals, so completion quality is NOT observable from the registry
  alone. Duration does not separate them either (truncated lanes 3m38s and
  11m09s; healthy lanes 53s to 9m28s).
- Em-dash hypothesis WEAKENED: session-5 empties (cod-4/cod-5) occurred on
  em-dash-containing payloads, but this session's truncation/empty occurred on
  ASCII-only payloads (ai--1, cod-5). Em-dash serialization is therefore NOT
  the common cause of truncated/empty returns.
- Suspected causes (in order of evidence): (1) step-budget / max-steps
  truncation (cf. L20260810-003; cod-5's 11m09s duration is consistent with
  spending the budget then emitting an empty/partial final message);
  (2) model-behavior variance - empty-first-response pattern (cf.
  L20260810-001); (3) resume-path first-response quirks (ai--2 off-target,
  cod-6 correct after a fresh prompt).
- ASCII-only protocol REMAINS standing practice as defense-in-depth: it is
  cheap, and it removes one variable even though it is not the root cause.
- No handoff-write JSON parse error observed this session: current-handoff.json
  parsed cleanly (valid JSON), so the original "computed" identifier failure
  was not reproduced in the ASCII-only regime.

Action: keep ASCII-only protocol for all lane dispatch payloads + reports;
escalate empty/truncated returns immediately (never 3rd in-lane retry,
L20260810-001); front-load full remaining-state into resume prompts
(L20260810-003).

## Recurrence + confirmed root cause (2026-08-11, session-8 -> session-9 boundary)

Second observed occurrence, identical failure class (screenshot 2026-08-11, obs-1 analysis of clipboard-550894fb.png):

    [delegation-observer] handoff atomic write failed: JSON Parse error: Unexpected identifier "Session"

CONFIRMED ROOT CAUSE (cod-7 recon, 2026-08-11):

- Choke point: .opencode/plugins/delegation-observer.ts:1463 - `const prognosis = JSON.parse(args.prognosis)` is the ONLY JSON.parse inside the log_decision handoff branch try block (1457-1486).
- The orchestrator LLM hand-assembles the `prognosis` argument string (no JSON.stringify; written by hand per the HANDOFF.md template). LLM-authored "JSON" routinely contains JSON5/JS-object-literal artifacts: unquoted keys, single quotes, and string values written as bare identifiers with no quotes.
- Session-metadata prose contains a capitalized word "Session" (e.g. "Session 9 of N" or the literal "Session halted at context threshold..." recorded in DIA-080). When interpolated without double quotes, strict JSON.parse throws SyntaxError: Unexpected identifier "Session".
- The catch at 1483-1486 logs the misleading message; atomicWriteHandoff() (634-654, JSON.stringify at 635 - always emits valid JSON) NEVER executes. Net effect: current-handoff.json silently not written -> breaks the DIA-061 boot gate and campaign resume continuity.
- Same class as the original "computed" failure: caller-supplied prognosis string is JSON5-ish, not strict JSON.

FIX SURFACE (queued for the next session, S10-routed - plugin + config change):

- Primary (hardening) delegation-observer.ts:1462-1491: on strict JSON.parse failure, do NOT abandon the write - construct a minimal valid prognosis object carrying the raw text (e.g. { parse_error: "strict JSON parse failed", raw: <string> }) so atomicWriteHandoff ALWAYS writes valid JSON; the successor boot gate (DIA-061) still sees a file (checksum mismatch escalates to the developer instead of silent loss). Improve the catch (1483-1486) to include a truncated, ASCII-sanitized view of the offending string.
- Secondary (prevention, S10-routed prompt/config): state explicitly in the orchestrator prompt (.opencode/oh-my-opencode-slim.jsonc:26/204/393), orchestrator_append.md:105-119, NEXT-RUN.md section 7.2 (217-227), and the log_decision tool description (delegation-observer.ts:1426-1427) that `prognosis` MUST be strict JSON - all keys and string values double-quoted, e.g. "session": "Session 9 of N".

## Verification

- [ ] Trigger a handoff write while a log_decision/registry prognosis contains the word "computed"; observe whether the atomic write fails with the JSON Parse error.
- [ ] Inspect the delegation-observer handoff-write serialization path for unquoted-key/string interpolation.
- [ ] Fix so handoff payload is always valid JSON (proper quoting/escaping).
- [ ] Confirm: handoff writes succeed and `jq`-parses cleanly; DIA-061 checksum verification passes.

## Fix

§10-routed (plugin change — delegation-observer, .opencode/ plugin).

Fix surface confirmed by cod-7 recon 2026-08-11 - see "Recurrence + confirmed root cause" section above.

## Re-verify

> To be filled at re-verify time.
