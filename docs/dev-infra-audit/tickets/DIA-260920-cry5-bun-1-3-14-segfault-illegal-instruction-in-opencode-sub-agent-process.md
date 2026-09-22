# DIA-260920-cry5 - Bun 1.3.14 segfault + illegal instruction in opencode sub-agent process

---

id: DIA-260920-cry5
title: "Bun 1.3.14 segfault + illegal instruction in opencode sub-agent process"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-20
source: baseline
date: 2026-09-20
created: 2026-09-20
updated: 2026-09-22

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence:

- ses_f377d6331ffeDBVEpwc5FT2Ehl: opencode log analysis confirms class-2 self-update restart 1.18.31->1.18.32

---

## Description

### Symptom

panic: Segmentation fault at address 0xD0; "Bun has crashed. This indicates a bug in Bun, not your code."; Illegal instruction. Crash dump from the opencode sub-agent process.

### Evidence

- Screenshot: `.opencode/images/ses_f4234a503ffeEBQJZ0aduaEHsJ/clipboard-a1c4b93a.png` (analyzed by observer ses_f40b23dbdffeYezUWgE1ddovQa)
- Runtime: `run v1.3.14 (0d9b296a) Linux x64 (baseline)`
- Args: `"opencode" "--sub-agent-opencode/1.18.31" "--use-system-ca"`
- Elapsed: 21621714ms (~6 hours)
- Memory: Peak 2.15GB on a 16.77GB machine
- Stack: `napi_module_register / process_dlopen`
- Crash report: https://bun.report/1.3.14/0d9b296a/GuhogC466tE+quRqr6igF4l1ijF+pt0/E830+/EmI5+/Ek4i5tEy/+oB286tCA2AgN

### Impact

This is the likely root cause of the recurring lane failures observed in the same session:

- 3 coder lanes died with `session_complete + empty_result_detected` x3 -> `failure_cap_reached` (registry.jsonl:1126-1149, messages.jsonl:1198)
- Several dispatches returned "Task cancelled" with no terminal result
- Previously misattributed to model instability / quota exhaustion

### Version Divergence

- Host bun: 1.4.0 (installed to `~/.bun/bin` this session)
- Dockerfile.dev: `ARG BUN_VERSION=1.3.14` (container-side)
- The crash is on 1.3.14

### Not a Config Error

No JSONC syntax error, no unknown model id, no provider auth failure in the dump. Native crash in the Bun/Node-API layer.

### Suggested Investigation

1. Confirm container bun version vs host
2. Check whether 1.3.14 is the pinned image version and whether a bump to 1.4.x is viable
3. Search bun issue tracker for `napi_module_register / process_dlopen` segfault on 1.3.14
4. Consider memory pressure (Peak 2.15GB, 6h uptime) as a contributing factor
5. Evaluate whether long-running sessions should be recycled

### Severity

Major: runtime instability affecting all lanes.

## Verification

- [ ] Container bun version confirmed
- [ ] Bun issue tracker searched for `napi_module_register` / `process_dlopen` segfault on 1.3.14
- [ ] Bump viability to 1.4.x assessed
- [ ] Memory pressure hypothesis evaluated (Peak 2.15GB, 6h uptime)
- [ ] Session recycling policy evaluated

## Re-verify

> To be filled at re-verify time.

## Fix

TWO distinct interruption classes exist in this repo and must not be conflated:

### Class 1: REAL Bun crash (what DIA-260920-cry5 tracks)

- Embedded Bun 1.3.14 inside the opencode binary crashes.
- Signature: `Bun has crashed` / `Segmentation fault at address 0x...` / `Illegal instruction`
- Stack: `napi_module_register` / `process_dlopen`
- Produces a bun.report URL.
- Dmesg shows the crash; /var/crash or core dumps may be present.

### Class 2: FALSE crash - opencode self-update restart

- opencode has a built-in, always-on self-update mechanism (no config toggle).
- Evidence pattern: log line `upgraded method=curl target=<new-version>` followed by
  a new `creating instance` run id seconds later.
- The version banner changes between runs (e.g. 1.18.31 -> 1.18.32).
- NO crash markers in the log; clean dmesg; empty /var/crash; no core dumps.

### 2026-09-22 incident was Class 2

- Log: `upgraded method=curl target=1.18.32` at 08:35:45 (run=9b6824f0).
- Old process last activity 09:32:37; new process `creating instance` at 09:32:47 (+10s).
- No `autoupdate` key exists in `~/.config/opencode/opencode.json` or
  `.opencode/opencode.jsonc`; no `OPENCODE_AUTO_UPDATE` env var.
- The self-update is always-on built-in behavior; cannot be disabled by config.

### Diagnostic recipe (future)

Before declaring a crash, run:

1. `grep -c 'Bun has crashed\|Segmentation fault\|Illegal instruction\|bun.report' ~/.local/share/opencode/log/opencode.log` (expect 0 for non-crash).
2. `grep 'upgraded method=' ~/.local/share/opencode/log/opencode.log | tail -1` (check for self-update).
3. Check whether the run id and version banner changed between the last two `creating instance` lines.
4. Check dmesg / /var/crash / core dumps for actual crash evidence.
5. Only then classify as Class 1 (real crash) or Class 2 (self-update).

All gates are now green: `make test-config` exit 0, `make test-shell` exit 0 (717 ok / 0 not-ok).
