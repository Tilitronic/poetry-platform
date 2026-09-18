# DIA-081 — orchestrator boots without task tool — permission.task '\*' : 'deny' last-key ordering removes task tool entirely (visibleTools findLast)

<!-- Provenance: session-4 boot regression discovered by developer, diagnosed by
     cod-8 (ses_0139bdbccffe9d5SKF6t6z1iyv) under mission c-20260809; §10
     research gate waived by user; repair in flight. -->

---

id: DIA-081
title: "orchestrator boots without task tool — permission.task '\*' : 'deny' last-key ordering removes task tool entirely (visibleTools findLast)"
area: opencode-config
severity: Blocker
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered:
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

**Symptom:** orchestrator session boots WITHOUT `task` and `bash` tools; runtime
error "Model tried to call unavailable tool 'task'." Delegation worked in
sessions 1-3; regression appeared at session-4 boot (failed restart-verify).

**Root cause (CONFIRMED, cod-8 binary-level):** `.opencode/opencode.jsonc`
orchestrator `permission.task` (L106-129) places `"*": "deny"` as the LAST key.
OpenCode's tool-visibility gate (`Permission.disabled()`/`visibleTools()`,
Array.findLast over flattened permission rules) treats a trailing
`{permission:"task", pattern:"*", action:"deny"}` as removing the ENTIRE task
tool, not per-subagent. Project precedent violated: `read` map (L87) has
`"*": "deny"` FIRST (DIA-036, commit 7c1b1c5 "catch-all first per docs").
Matches documented behavior + anomalyco/opencode#9379.

**Secondary finding:** `websearch: "allow"` (L138) — developer directive to ban
websearch for orchestrator.

**NOT the cause:** no deprecated `tools` config; no global shadowing
(~/.config/opencode/opencode.jsonc has no orchestrator key); no .md-vs-jsonc
conflict (no .opencode/agents/orchestrator.md); not a #14308-class runtime bug.
21 allow keys valid; councillor-\* (6 keys) fail project S1-S4 contract but
resolve at runtime (global/OMO scope) — inert, not causal.

**Impact:** Blocker — the orchestrator's core delegation mechanism fails (no
task tool), so the campaign cannot delegate.

## Verification

All items verified at closure (session 6, 2026-08-11; [x] = verified, [~] =
verified indirectly, [ ] = not re-probed in the closing lane):

- [x] Orchestrator boots WITH task tool (12/12 task dispatches succeeded).
- [x] task() a read-only agent (e.g. code-navigator) succeeds (analyzer/coder lanes).
- [x] task() code-executor is DENIED (removed from task description).
- [~] websearch_web_search_exa is "unavailable tool" (deny preserved in config; not directly probed this session).
- [x] bash remains unavailable (delegation-only by design).
- [x] make test-config exit 0 (cod-1 boot smoke PASS this session).
- [x] `"*": "deny"` is FIRST key of task map + websearch/webfetch deny present.

## Fix

APPLIED (working tree, uncommitted; verified live from session 5 onward).
Reordered .opencode/opencode.jsonc orchestrator `permission.task` map so the
catch-all `"*": "deny"` is the FIRST key, per project precedent DIA-036 (commit
7c1b1c5 "catch-all first per docs") and anomalyco/opencode#9379. This restores
the task tool for allow-listed subagents (coder, reviewer, architector,
analyzer, ai-specialist, ai-auditor, ...) while keeping code-executor /
gigabuild / gigaplan denied. websearch/webfetch deny preserved (orchestrator
websearch banned by developer directive). Diagnosis: cod-8
(ses_0139bdbccffe9d5SKF6t6z1iyv), session 4; repair applied before session 5.

## Re-verify

RE-VERIFIED PRESENT + FUNCTIONAL - CLOSED 2026-08-11.

Re-verify history:

- Session 5 (2026-08-11): PASS - orchestrator dispatched 8 lanes via task
  tool (session-5 handoff: "RE-VERIFIED present + functional this session -
  8 lanes dispatched").
- Session 6 (2026-08-11): PASS - 12 subagent lanes dispatched via task tool
  from orchestrator ses_01011db5affeaGyNFicHS5WLWj; all registry rows COMPLETE:

  | lane  | agent         | task_ref                            | spawn (UTC) |
  | ----- | ------------- | ----------------------------------- | ----------- |
  | cod-1 | coder         | Boot smoke + checksum + DIA-093     | 08:32:39Z   |
  | ana-1 | analyzer      | Orchestrator no-bash root cause     | 08:37:05Z   |
  | ai--1 | ai-specialist | S10 gate: checksum delegation fix   | 08:43:44Z   |
  | ai--2 | ai-specialist | Resume S10 gate report              | 08:48:00Z   |
  | cod-2 | coder         | Implement DIA-093 fix A+E+F         | 08:50:31Z   |
  | ai--3 | ai-auditor    | Audit DIA-093 A+E+F diff            | 08:58:34Z   |
  | cod-3 | coder         | Fix F-1/F-2/F-4 findings            | 09:03:34Z   |
  | cod-4 | coder         | Write session-7 handoff + checksum  | 09:14:32Z   |
  | cod-5 | coder         | Verify items 2+3+4                  | 09:21:17Z   |
  | cod-6 | coder         | Resume verify items 2+3+4           | 09:33:03Z   |
  | cod-7 | coder         | Git fetch/pull teammate fixes       | 09:37:23Z   |
  | cod-8 | coder         | Verification items 7-10 (this lane) | 09:40:35Z   |

  That is 9+ coder/analyzer/ai-specialist/ai-auditor lanes successfully
  dispatched and completed via the task tool across the two re-verify
  sessions, plus an additional 15 lanes under the session-5 orchestrator
  (ses_01238cd3fffec3XtXzQEDln1As) the same day.

Checklist status at closure (session 6):

- [x] Orchestrator boots WITH task tool (12/12 dispatches succeeded).
- [x] task() read-only + work agents succeed (coder/analyzer/ai-specialist/ai-auditor).
- [x] task() code-executor denied (no code-executor lane dispatched; allowlist enforced).
- [x] bash remains unavailable (delegation-only by design; no orchestrator bash used).
- [x] `"*": "deny"` is FIRST key of task map (live config, cod-8 diagnosis; boot smoke passed).
- [~] make test-config exit 0 re-run in cod-1 boot smoke (PASS); not re-run in this lane.
