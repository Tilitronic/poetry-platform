# DIA-260921-6o4i - Console free-tier gate rejects -free models

---

id: DIA-260921-6o4i
title: "Console free-tier gate rejects -free models"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-21
source: inventory
date: 2026-09-21
created: 2026-09-21
updated: 2026-09-21

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

Console free-tier gate rejects `-free` models. Any `-free` model ID routed via
`providerID=opencode` (legacy Zen/console path) is refused at request time with
`OpenCode's free tier can only be used from within OpenCode`, even via
`make opencode PRESET=free` and after fresh auth reconnect. Same-session
`providerID=opencode-go` models stream fine. Root cause is provider-side
(entitlement/context enforcement on the console path, onset ~2026-09-18), not
client-side. Full analysis:
`knowledge/ana-260921-0f9i-free-tier-gate/ana-260921-0f9i-free-tier-gate-report.md`.

## Verification

- [x] Error evidence logged: `opencode.log` shows `providerID=opencode` +
      `modelID=muse-spark-1.3-contributor-free` refused inside provider error
      payload (`AI_APICallError`); error string has zero hits in repo (server-originated).
- [x] Runtime probe: binary opencode 1.18.18 = `Dockerfile.dev` pin, OMO 2.2.19
      consistent; `auth list` shows Go + OpenAI, no Zen line.
- [x] Reconnect test: fresh container reconnect did NOT fix (falsifies stale-auth cause).
- [x] Split-path probe: `opencode-go/*` streams fine in same session/container/network.
- [ ] V1 Go-equivalent routing applied (pending developer approval).
- [ ] Re-verify: `-free` outage documented; Go fallback confirmed by operator.

## Fix

Provider-side Console gate, onset ~09-18 per ana-260921-0f9i report. No
client-side fix applies (correct launch, fresh reconnect, OMO reinstall all
falsified or excluded). Recommended: V1 Go-equivalent routing - point
free-intent lanes at `opencode-go/*` equivalents per model-registry.yaml
(already blessed fallbacks, zero client change). V1 pending developer
approval; ticket stays OPEN until approval + routing applied.

## Re-verify

- [x] Researcher res-1 external corroboration: anomalyco/opencode issue 42029
      (UA gate corroboration), issues 45744/44847 (same-account 500-vs-200 split),
      issue 33318 (intentional-gate comment). Verbatim error string not found
      publicly (no public report quotes it word-for-word); corroboration is
      behavioral, not textual.
- [ ] Post-V1: confirm free-intent launches resolve to Go equivalents and stream.
