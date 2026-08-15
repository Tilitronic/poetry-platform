# DIA-190 - Conspecter memory-shelf edit-permission defect: contract asserts shelf registration, permission denies it (doc drift)

<!-- FILED 2026-08-15 (docs lane, memory-manager agent). Tracking ticket - no
     config or code change performed yet. NUMBER DEVIATION: the task payload
     requested the id one less than this (which a concurrent, unrelated OPEN
     ticket - terminal session identity - had already taken, Major/OPEN,
     filed 2026-08-15). This ticket was created as DIA-190 (next free,
     verified unused) with corrected ledger counts (OPEN 17 -> 18, Major
     45 -> 46). Forensic evidence verified 2026-08-15: opencode.jsonc L408-420
     (conspecter edit = deny * + allow knowledge/* only) vs the conspecter
     contract (oh-my-opencode-slim.jsonc orchestratorPrompt step 4 +
     research-pipeline SKILL.md L53/L87 + conspecter.md L17-19/L76-80) which
     asserts shelf self-registration under .opencode/memory-shelf.yaml. -->

---

id: DIA-190
title: "Conspecter memory-shelf edit-permission defect - contract asserts shelf registration, permission denies it (doc drift)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# grilling-gate markers (ai--7 validated design): fill at creation time with

# the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer report 2026-08-15 during the omo-slim project self-sufficiency persistence pipeline; forensics by code-navigator lane
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffb566c7affeGbzYgUWyI5enEi" # filing lane (docs)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "" # orchestrator session (filing dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-190-conspecter-shelf-edit-permission.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

@conspecter's lane contract says it registers conspects in
.opencode/memory-shelf.yaml under shelf.conspects:

- oh-my-opencode-slim.jsonc conspecter orchestratorPrompt step 4 (line ~608):
  "Register the conspect in .opencode/memory-shelf.yaml under
  shelf.conspects."
- research-pipeline SKILL.md L53 ("synthesizes the MLA-cited conspect, and
  registers it in memory-shelf") and L87 ("writes conspect; registers
  memory-shelf").
- .opencode/agents/conspecter.md L17-19 + L76-80: edit allow-list =
  knowledge/\* (writing the conspect) + .opencode/memory-shelf.yaml
  (registering the conspect under shelf.conspects).

But its edit permission in .opencode/opencode.jsonc L408-420 is
{ "_": "deny", "knowledge/_": "allow" } - .opencode/memory-shelf.yaml is NOT
under knowledge/, so the permission blocks the lane's own declared duty.

Manifested 2026-08-15 during the res028 persistence pipeline: conspecter
wrote the conspect (knowledge/res028-opencode-version-pin/
res028-opencode-version-pin-conspect.md, 96 lines) but the shelf edit was
DENIED (crisis row 2026-08-15 08:36:45Z: "res028-opencode-version-pin
conspect registration blocked", escalated, lane conspecter); registration was
completed by the @memory-manager lane instead (mem-2, messages.jsonl rows
27593-27594 "Register res028 in shelf" / "res028-registered-memory-shelf").
Prior incident of the same class: res019 (2026-08-13) shelf registration was
actually performed by a coder/commit lane, not conspecter (registry.jsonl
shows no edit events for the conspecter session
ses_004c114f9ffew0vS5KFLWBopUZ on 2026-08-13; the coder lane "Commit res019
artifacts + cleanup" at messages.jsonl row 2706 did it).

### VERDICT (forensics, 2026-08-15)

PRE-EXISTING CONFIG GAP + DOC DRIFT, NOT a fresh regression. Timeline:

(a) before 2026-08-12 .opencode/memory-shelf.yaml WAS in conspecter's edit
scope;
(b) 2026-08-12 memory-shelf centralization (commit 0697a08) deliberately
removed the memory-shelf.yaml allow from conspecter + analyzer, making
memory-manager the sole shelf writer (opencode.jsonc L395-399:
memory-manager edit = { "_": "deny", ".opencode/memory/_": "allow",
".opencode/memory-shelf.yaml": "allow" });
(c) 2026-08-14 the research-pipeline optimization change (of 2026-08-14)
CLAIMED restoration ("edit map gains .opencode/memory-shelf.yaml allow
for self-registration" in CHANGELOG L79 + conspecter.md L17-19/L76-80)
but the actual .opencode/opencode.jsonc NEVER received it - doc-config
drift. The drift misled the res028 flow (orchestrator trusted the
contract, permission blocked).

### Scope / Fix options (to be decided in interview)

(A) expand conspecter edit to include .opencode/memory-shelf.yaml: allow
(restores self-registration per the 2026-08-14 research-pipeline
optimization intent);
(B) change the conspecter contract + research-pipeline skill to delegate
shelf registration to @memory-manager (aligns with the memory-shelf
centralization design of 2026-08-12: memory-manager as sole shelf
writer);
(C) keep as-is with documented workaround (memory-manager/coder registers
shelf entries).

Note the delegation-observer plugin WRITER_LANES = {analyzer, conspecter,
memory-manager} (delegation-observer.ts L481) for batch-conflict purposes -
analyzer/conspecter are treated as shelf writers for batching even though
only memory-manager has the edit permission.

### Evidence

- current config opencode.jsonc L408-420 (conspecter), L395-399
  (memory-manager), L256-259 (analyzer), L280-283 (analyzer-escalated);
- the memory-shelf centralization change of 2026-08-12 (ticket + CHANGELOG
  entry, commit 0697a08);
- the research-pipeline optimization change of 2026-08-14 (ticket) +
  CHANGELOG L79 (claimed-but-unapplied restoration: "edit map gains
  .opencode/memory-shelf.yaml allow for self-registration");
- registry.jsonl rows (res019 conspecter dispatch
  ses_004c114f9ffew0vS5KFLWBopUZ + coder commit lane; res028 crisis row
  2026-08-15 08:36:45Z "registration blocked" + mem-2 registration rows);
- memory-shelf.yaml res019 L126 + res028 L283 entries.

### Route

Section 2.5 chain: ai-specialist gate (if scope expansion chosen) or
openspec-plan interview (if contract/skill change) -> coder implement ->
make test-config exit 0 -> ai-auditor independent review -> restart-verify
-> register. EBDV decision variants required (policy-class: agent permission
change).

## Verification

Checklist:

- [ ] (a) conspecter can self-register a conspect in memory-shelf (or the
      contract explicitly delegates shelf registration to @memory-manager)
- [ ] (b) doc-config drift resolved (CHANGELOG/conspecter.md match the
      actual config)
- [ ] (c) make test-config exit 0
- [ ] (d) no regression to the memory-shelf centralization intent
      (sole-writer design of 2026-08-12)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
