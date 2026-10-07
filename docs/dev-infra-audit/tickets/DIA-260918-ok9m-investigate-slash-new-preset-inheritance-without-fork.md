# DIA-260918-ok9m - Investigate slash-new preset inheritance without fork

---

id: DIA-260918-ok9m
title: "Investigate slash-new preset inheritance without fork"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: [new-module, cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-18
source: inventory
date: 2026-09-18
created: 2026-09-18
updated: 2026-09-18

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

S1 spike: /new newborn sessions land on stale model while footer shows preset
intent. Investigate preset inheritance without forking OMO. S1 implements a
session.created guard that calls switchModel exactly once for divergent
newborns. Key files: .opencode/plugins/preset-model-guard.ts,
openspec/changes/dia-260918-ok9m-s1-switchmodel-guard/specs/session-created-model-guard/spec.md,
openspec/changes/dia-260918-ok9m-s1-switchmodel-guard/design.md. Scope limit
(rev-1 Critical): synthetic override marker is best-effort ONLY; a real
--model flag carries NO marker on session.created payloads in OMO 2.2.19
(zero info.override hits in vendored dist), so real --model newborns ARE
switched when divergent.

## Verification

- [x] Focused tests T1/T3/T5: 11 pass 0 fail 32 expects exit 0
- [x] make test-config exit 0 (78 PASS, decision-variants 359/359)
- [x] rev-1 4/4 closed (cycle2 commit 7b19111)
- [x] rev-2 4/4 closed + 3 doc obs fixed (commit 28bc2a9)
- [ ] Full suite: fails triaged pre-existing, not caused by S1
- [ ] Wiring registration proof deferred (plugin event-seam attach not shown live)
- [ ] S1 spike still open (no DONE close)

## Fix

- 9fc299d GREEN-B: session-created switchModel guard plus T5 green (11/11 pass).
- 7b19111 cycle2 rev-1 fixes: synthetic override scope, stripJsonc
  single-owner, D3 preset-NAME amendment, uncapped fire-once.
- 28bc2a9 tiny docs: real --model typo in guard.ts:19, synthetic scope in
  design, synthetic scenario retitle in spec.
- This closeout: spec.md:21 real---model to real --model (same class as
  guard.ts:19 fix in 28bc2a9, flagged by coder) plus CHANGELOG entry.

## Re-verify

- rev-1 verdict: 4/4 closed per cycle2 review.
- rev-2 verdict: 4/4 closed + 3 doc obs fixed in 28bc2a9.
- Focused T1/T3/T5 11/11 pass exit 0; test-config PASS (78 PASS, 359/359).
- Residual: full-suite fails pre-existing; wiring registration proof
  deferred; S1 spike still open.
