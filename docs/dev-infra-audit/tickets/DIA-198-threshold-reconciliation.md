# DIA-198 - reconcile self-rerun thresholds 15/25 across OMO inline prompts + drift-checker marker (DIA-191 F4/F5 follow-up)

<!-- FILED 2026-08-16 (merge lane cod-13). Follow-up from ai-auditor review of
     the DIA-191 threshold retune (F4/F5 nits, developer-accepted 2026-08-16).
     Small config reconciliation - no behavior change beyond aligning the
     threshold text in the OMO inline prompts + drift-checker contract with
     the already-merged NEXT-RUN.md / context_usage tool retune (15/25). -->

---

id: DIA-198
title: "reconcile self-rerun thresholds 15/25 across OMO inline prompts + drift-checker marker (DIA-191 F4/F5 follow-up)"
area: opencode-config
severity: Low
status: OPEN
blocked_by: [] # no blockers
parent_epic: "DIA-191" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "waived" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [spike-poc] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-16
source: ai-auditor-review
date: 2026-08-16
created: 2026-08-16
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional ---)

session_id: "" # filed by merge lane cod-13 (session attribution optional per GRANDFATHERED note)
lane_id: "cod-13"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "" # orchestrator session (merge dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

The DIA-191 threshold retune (ana025 V1, commit f18281f, merged 47064d0)
changed the self-rerun authority from 30%/50% to **15%/25%** in
`docs/dev-infra-audit/NEXT-RUN.md` and retuned the `context_usage` tool
output fields (`threshold_15pct`/`threshold_25pct`, delegation-observer.ts
~2845). Three surfaces still carry the OLD 30/50 text and now drift from the
merged authority:

1. **OMO inline orchestrator prompt summaries** -
   `.opencode/oh-my-opencode-slim.jsonc` lines 26 / 209 / 433 still say
   `>=30% (primary) / >=50% (safety-net)` in the "Orchestrator Operating
   Rules" prompt (all three presets).
2. **Drift-checker marker contract** -
   `scripts/check-orchestrator-prompt-drift.sh` line ~35-36 (comment) and
   line 67 (`THRESHOLD_MARKER="30% (primary)"`) still assert the 30% text,
   so the drift gate would FAIL once the inline prompts are retuned to 15% —
   the marker and the prompts must change together. Companion fixture
   needles in `scripts/__tests__/check-orchestrator-prompt-drift.bats`
   (lines ~151-159, `30% (primary)`) must be updated to match.
3. **context_usage tool description** - `delegation-observer.ts` (~line 2693) tool description still describes the old threshold semantics
   (single 30/50 framing); should document the dual 15/25 fields.

Impact: inline orchestrator guidance contradicts the merged NEXT-RUN.md
authority, and the drift-checker would hard-fail (or force a --no-verify
bypass) on the next prompt retune. Low severity: text-alignment only, no
runtime behavior change.

## Verification

- `make test-config` exit 0 (the drift checker test is wired into the config
  suite; it must go GREEN with the retuned markers).
- `grep -n "30%\|50%" .opencode/oh-my-opencode-slim.jsonc` returns NOTHING in
  the inline prompt sections (no 30/50 summary text remains).
- `scripts/check-orchestrator-prompt-drift.sh` exit 0 against the current
  tree (marker 15% (primary) matches the inline prompts).

## Fix

To be filled at fix time.

> To be filled at fix time.

## Re-verify

To be filled at re-verify time.

> To be filled at re-verify time.
