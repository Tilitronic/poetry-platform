# DIA-260926-5vin - permission asks in unattended lanes: convert unnecessary ask to deny, narrow external_directory, add catch-all defaults

---

id: DIA-260926-5vin
title: "permission asks in unattended lanes: convert unnecessary ask to deny, narrow external_directory, add catch-all defaults"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: inventory
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-26

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
evidence: []

---

## Description

### Problem

- In unattended/parallel runs a permission configured `ask` is not a question - it is a deterministic 5-minute stall followed by death. `deny` fails instantly; `ask` is the only fatal action.
- EVIDENCE: 15 records `permission_auto_rejected` in .opencode/session/registry.jsonl, each with `reason: "no_human_response_within_threshold"` and `timeout_seconds: 300`. They correlate exactly with the failed lanes of 2026-09-26 (cod-2, cod-3, cod-4, cod-12, cod-14, cod-17, ai--4, ai--5, cod-21). Control lanes have ZERO such records. In 6 of the 9 the work HAD been done and survived on disk - only the report was lost.
- The asks originate in OpenCode CORE, not in a plugin. .opencode/plugins/needs-input-observer.ts is only the watchdog that force-rejects at the timeout (autoRejectPermission ~:411-479, SDK call ~:436) and writes the registry event.
- THE TIMEOUT IS CONFIGURABLE, not a constant: PERMISSION_STALL_TIMEOUT_MINUTES (needs-input-observer.ts ~:316-323, default 300s).
- TWO ROOT SOURCES of the deaths:
  1. `external_directory` defaults to `ask` and is a SEPARATE key NOT covered by the read/bash catch-alls. Any path outside /workspace therefore blocks - e.g. ~/.local/share/opencode, ~/.config/opencode, ~/.cache/opencode, /tmp.
  2. bash `rm`, `rm -rf`, `rmdir`, `chmod`, `chown` are global `ask` (.opencode/opencode.jsonc ~:112-116).
- The observed rejected calls were bash (7), read (7), grep (1) - matching exactly those two sources.
- ADDITIONAL MISLEADING SIGNAL: .opencode/plugins/lib/stall-sweep.ts is unaware of waiting lanes, so a lane blocked on a human is stamped `escalation: "dead"` at ~60 minutes - a false death.

### Fix

1. Run unattended/agent sessions with `opencode --auto` AND convert the five destructive `ask` rules (`rm`, `rm -rf`, `rmdir`, `chmod`, `chown`) to `deny`. This is the proven pattern in .opencode/opencode-overnight.jsonc: deny stays enforced under --auto, so nothing destructive is silently granted. Highest-effect single change.
2. Add narrowly-scoped `external_directory` allows for the specific roots lanes genuinely need - read-only where possible. Do NOT blanket-allow.
3. Add an explicit `"*"` catch-all to every permission object that lacks one, so an unlisted path/tool never falls through to the default `ask`.
4. RESOLVE AN AMBIGUITY FIRST: a comment at .opencode/opencode.jsonc ~:374-376 asserts the coder bash map does NOT inherit global denies, while the OpenCode docs say agent permissions merge with global and take precedence. Settle it per agent with `opencode debug agent <name>` BEFORE flipping anything.
5. Raising PERMISSION_STALL_TIMEOUT_MINUTES is a stopgap only - it buys time, it does not remove the death.
6. Make stall-sweep aware of waiting lanes so a blocked lane is not reported as dead.

### Acceptance criteria

- [ ] A lane performing a legitimate in-scope operation never blocks on an `ask` in an unattended run.
- [ ] The five destructive bash rules are `deny`, not `ask`, verified under `--auto`.
- [ ] `external_directory` is explicitly configured for the roots lanes need, read-only where possible.
- [ ] No permission object relies on an implicit default for unlisted inputs.
- [ ] The agent-vs-global inheritance question is settled with `opencode debug agent <name>` evidence and recorded.
- [ ] A blocked lane is no longer reported as dead by the stall sweep.

### Relations

- Root-caused on 2026-09-26 by two read-only lanes (ai-specialist plus a registry micro-probe) during the DIA-260922-cp0m campaign. The surfacing half is a companion ticket. Related: DIA-260903-oj59 (thresholds) and DIA-260926-k8ej (tickets CLI).

## Verification

## Fix

> To be completed when the fix is implemented.
