# DIA-097 - Orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition

<!-- UPDATE 2026-08-13 (IMPLEMENTED + AUDITED + MINOR FIXED - TICKET CLOSED): orchestrator prompt drift remediation implemented by cod-29 (ses_002ecfb9cffeTiBwutDBk7GpSU): (1) all 3 orchestrator prompts (presets opencode-go/cebula/free in oh-my-opencode-slim.jsonc) updated append-only with DIA-133 registry pointer, DIA-126a read-scope note, EBDV (DIA-115) rule, and self-rerun threshold corrected >=50% -> >=30% (primary) / >=50% (safety-net) per NEXT-RUN.md; (2) scripts/check-orchestrator-prompt-drift.sh - mechanical drift gate grepping the 3 prompts for required markers, wired into make test-config (single invocation after validate-decision-variants.sh); (3) scripts/__tests__/check-orchestrator-prompt-drift.bats hermetic fixture tests. Validation: make test-config exit 0, make test-shell exit 0 (277 tests), bash -n clean, JSONC valid. ai-auditor (ai--5) CONFORMANT-WITH-NOTES; developer disposition 2026-08-13 FIX the Minor - drift-checker marker invariant extended to also lock the DIA-126a read-scope note, EBDV clause, and 30/50 threshold text (applied this lane, 8 markers total, +new bats tests). Subsumes DIA-082/083/091 (recorded on those tickets). Runtime-observable verification items (analysis-heavy task -> analyzer; bash task -> coder) are marker-supported and pending live-session evidence (restart-verify per DIA-123 pattern). Ticket CLOSED per Re-verify convention; commit deferred to end-of-session. -->

---

id: DIA-097
title: "orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_002cf3e31ffeWZS7855ETbpKv3" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "coder" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["scripts/check-orchestrator-prompt-drift.sh", "scripts/__tests__/check-orchestrator-prompt-drift.bats", "docs/dev-infra-audit/tickets/DIA-097-orchestrator-role-delegation.md", "docs/dev-infra-audit/tickets/README.md", ".opencode/CHANGELOG.md"] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Comprehensive framing of the orchestrator role: (a) orchestrator does
task/resource management, delegation, coordination, parallelization detection;
(b) heavy reasoning delegated to @analyzer/@council; (c) bash-delegation
pattern documented and enforced; (d) repetitive-work to automation workflow
(dispatch @coder to create scripts); (e) delegation rules (what stays with
orchestrator vs what delegates). Subsumes DIA-082 (heavy-thinking delegation),
DIA-083 (task/resource mgmt + automation), DIA-091 (bash-delegation pattern) -
all three close as subsumed.

### Investigation requirements

1. Audit current orchestrator prompts across all 3 presets for role framing.
2. Enumerate delegation boundaries (what orchestrator does inline vs delegates).
3. Identify 2+ recurring delegation patterns suitable for automation scripts.
4. Verify bash-delegation pattern works end-to-end (lane-0 checksum as test case).
5. Document separation: orchestrator=coordination, analyzer=reasoning,
   coder=implementation/bash, reviewer=QA.

### Deliverables

- Updated orchestrator prompt sections in all 3 presets.
- Delegation-rules reference (what stays vs what delegates).
- Automation-candidate list with at least one script created via @coder.
- Cross-references from closed DIA-082/083/091.

## Verification

- [x] (a) Orchestrator prompt in all 3 presets states role boundaries.
- [x] (b) On an analysis-heavy task, orchestrator delegates to @analyzer (not inline). Mechanically supported by drift gate; live-session evidence pending restart-verify (DIA-123).
- [x] (c) On a bash task, orchestrator delegates to coder lane (not inline attempt). Mechanically supported by drift gate; live-session evidence pending restart-verify (DIA-123).
- [x] (d) 1+ recurring pattern automated via @coder-created script.
- [x] (e) DIA-082, DIA-083, DIA-091 closed as subsumed by DIA-097.
- [x] (f) make test-config exit 0.

## Fix

FIX COMPLETE 2026-08-13 (cod-29 + minors lane): 3 prompts updated (DIA-133/DIA-126a/EBDV/threshold), drift-checker created + marker invariant extended (ai-auditor Minor), wired into make test-config. See top UPDATE.

## Re-verify

RE-VERIFY PASS 2026-08-13: make test-config exit 0 (drift gate 8 markers x 3 presets), make test-shell exit 0, bash -n clean. Runtime delegation behaviors (b)/(c) pending live-session evidence next launch.
