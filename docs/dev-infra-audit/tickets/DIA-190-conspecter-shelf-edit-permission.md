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
status: CLOSED
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
updated: 2026-08-16

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

Implemented 2026-08-15 (coder lane; AGENTS.md 2.5 chain: ai-specialist gate
research -> developer-approved Option B -> ai-auditor APPROVE-WITH-NITS,
findings F6/F7 applied). Option B = doc alignment; the config
(.opencode/opencode.jsonc conspecter permission = edit knowledge/\* only) is
CORRECT and UNCHANGED - no permission expansion.

- .opencode/agents/conspecter.md - frontmatter description L2; edit allow-list
  block L17-19 (knowledge/\* only + "Shelf registration is DELEGATED to
  @memory-manager" note); Conspect Synthesis step 4 L44 (report artifact path
  instead of self-registering); output-contract header shelf-registration L59
  ("memory-shelf.yaml (shelf.conspects), delegated to @memory-manager" - keeps
  the M2 validator's required reference tokens); Permissions section L76-80
  (drops the memory-shelf.yaml allow claim).
- .opencode/oh-my-opencode-slim.jsonc L608 - conspecter orchestratorPrompt
  step 4: report the conspect artifact path; @memory-manager registers it in
  memory-shelf.yaml under shelf.conspects.
- .opencode/skills/research-pipeline/SKILL.md L53 + L87 - conspecter reports
  artifact path; @memory-manager registers in memory-shelf.
- .opencode/opencode.jsonc L402-407 (ai-auditor F6) - stale comment aligned to
  the delegation model: conspecter reports the artifact path; @memory-manager
  is the SOLE memory-shelf writer (DIA-143 invariant); comment-only change,
  edit permission stays knowledge/\* only. Rewritten lines are ASCII-only
  (DIA-079).

Validation: make test-config exit 0 (56/56, incl. validate-output-contracts M2
with the delegation-annotated token); make test-shell exit 0 (390); npx
prettier --check exit 0 on the edited non-TS files; typecheck exit 0.

Verification checklist (ticket section above): (a) satisfied via delegation
(Option B) - conspecter reports path, @memory-manager registers; (b) doc-config
drift resolved; (c) make test-config exit 0; (d) sole-writer intent preserved
(config untouched).

## Re-verify

PENDING-restart-verify (after next OpenCode restart; ai-auditor review):

- [ ] (a) dispatch @conspecter on a test conspect (knowledge/res<id>-<topic>/);
      confirm it writes the conspect and REPORTS the artifact path, and does
      NOT attempt a memory-shelf write (no blocked-registration row in
      registry.jsonl; no .opencode/memory-shelf.yaml edit attempt)
- [ ] (b) dispatch @memory-manager to register the reported artifact under
      shelf.conspects; confirm the entry lands (DIA-143 sole-writer flow)
- [ ] (c) confirm the conspecter permission block still reads edit =
      knowledge/\* only (no memory-shelf.yaml allow)

<!-- UPDATE 2026-08-16 (docs lane): RE-OPENED 2026-08-16 (docs lane): fix
     work item - developer chose direction (a) expand conspecter edit allow
     to .opencode/memory-shelf.yaml (contract vs permission drift fix).
     Implementation + ai-auditor + restart-verify pending (Phase 1+ per
     ana023). -->

<!-- UPDATE 2026-08-16 (coder lane, branch omos/dia-190-192-193):
     DIRECTION (a) IMPLEMENTED. The 2026-08-15 Option-B doc alignment
     (delegate shelf registration to @memory-manager) is superseded by the
     developer's re-open decision: restore conspecter self-registration via a
     NARROW permission expansion.

     - .opencode/opencode.jsonc conspecter edit allow-list: added
       ".opencode/memory-shelf.yaml": "allow" (kept "*": "deny" +
       "knowledge/*": "allow"; no broad .opencode write - the shelf YAML
       ONLY). Stale delegation comment rewritten to document direction (a).
     - scripts/__tests__/batch-d-infra.test.mjs S2 drift test updated:
       the conspecter edit-shape assertion now expects
       ["*", ".opencode/memory-shelf.yaml", "knowledge/*"] (the old
       knowledge/*-only pin encoded the Option-B invariant and would have
       failed the config gate after the expansion).

     Verification: make test-config exit 0 (56/56, incl. updated S2
     conspecter assertion + M2 output contract); npx prettier --check clean
     on all edited files; pre-commit hook autofix passed.

     Verification checklist (ticket section above): (a) conspecter can now
     self-register under .opencode/memory-shelf.yaml (shelf.conspects) -
     permission restored, contract + config agree on self-registration;
     (b) opencode.jsonc comment now matches the actual config (no stale
     delegation claim); (c) make test-config exit 0; (d) DIA-143 sole-writer
     intent deliberately revised for conspecter per developer direction (a)
     (2026-08-16 re-open) - memory-manager remains the analyzer-side shelf
     writer; conspecter shelf edits are a narrow self-registration allow.

     Commit: ea86886 config(agents): DIA-190 expand conspecter edit allow to
     memory-shelf.yaml (contract vs permission drift). Status stays OPEN
     (restart-verify + ai-auditor pending per section 2.5 Phase 5). -->

<!-- UPDATE 2026-08-16 (coder lane, branch omos/dia-190-192-193, fix loop
     R5): REVERTED to DIRECTION B per developer disposition 2026-08-16 +
     ai-auditor ai--4 HIGH finding. The direction-(a) expansion (commit
     ea86886, UPDATE block above) CONFLICTS with DIA-143 (VERIFIED), which
     made memory-manager the SOLE memory-shelf writer and explicitly removed
     the memory-shelf.yaml allow from conspecter/analyzer. The direction-(a)
     premise (contract asserts self-registration) was STALE - the 2026-08-14
     contract restoration was the doc-config drift itself (claimed-but-
     unapplied); the delegation model (Option B) is the correct invariant.

     - .opencode/opencode.jsonc conspecter edit block REVERTED to base state:
       "*": "deny" + "knowledge/*": "allow" only (no memory-shelf.yaml
       allow); delegation comment restored verbatim (DIA-143 sole-writer
       wording). Byte-identical to 2c515bd.
     - scripts/__tests__/batch-d-infra.test.mjs S2 drift test REVERTED to
       the knowledge/*-only shape assertion (passes with the reverted
       permission; WHY comment added documenting the DIA-143 invariant).
     - DIA-192/193 changes NOT touched (debug-level downgrades + harness
       assertions stay).

     Verification: make test-config exit 0 (56/56 incl. reverted S2 drift
     test); make test-shell exit 0; node --experimental-strip-types --check
     exit 0; npx prettier --check clean; parallel-handoff harness green.

     STATUS: CLOSED as NO-OP (documented). No permission expansion was ever
     correct - DIA-143 (VERIFIED) keeps memory-manager the sole shelf writer;
     conspecter reports the artifact path and @memory-manager registers it
     (the 2026-08-15 Option-B Fix section above stands as the resolution).

     Commit: (commit A hash - DIA-190 revert) config(agents): DIA-190 revert
     conspecter memory-shelf allow (DIA-143 sole-writer; close as no-op). -->
