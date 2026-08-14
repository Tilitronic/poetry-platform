# DIA-117 - Fix agent-instruction audit findings: HANDOFF.md refs, missing AGENTS.md section 10, boss_append.md duplicate

<!-- Fix ticket (fix-lane): implements developer-approved findings from
     ana016-agent-instruction-audit (DIA-114). Filed 2026-08-12, cod-lane. -->

---

id: DIA-117
title: "Fix agent-instruction audit findings: HANDOFF.md refs, missing AGENTS.md section 10, boss_append.md duplicate"
area: opencode-config
severity: Major
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

References ana016-agent-instruction-audit (knowledge/ana016-agent-instruction-audit/). Three developer-approved fixes:

1. oh-my-opencode-slim.jsonc lines 26, 210, 401 preset prompts reference "HANDOFF.md" but the runtime file is .opencode/session/current-handoff.json (HANDOFF.md is only a template) - replace the filename in all 3 preset prompt fields.
2. orchestrator_append.md, NEXT-RUN.md, and all 3 preset prompts reference "AGENTS.md section 10" which does not exist in AGENTS.md - restore the section or repoint the references (must not break the AI Devtools Modernization Workflow references).
3. .opencode/oh-my-opencode-slim/boss_append.md (100 lines, ~80% byte-identical to orchestrator_append.md, previously flagged dead) - delete it after confirming no preset references it.

## Verification

- make test-config passes.
- grep confirms no "HANDOFF.md" reference remains in jsonc preset prompts.
- grep confirms no "section 10" / "section 10" dangling reference.
- boss_append.md gone and no jsonc preset references it.

## Fix

Implemented 2026-08-12 (coder lane, working tree uncommitted). All three
developer-approved fixes applied, in fix-scope files only:

- **FIX 1 - HANDOFF.md -> .opencode/session/current-handoff.json (3 preset prompts).**
  oh-my-opencode-slim.jsonc lines 26/210/401: the preset prompts referenced
  "HANDOFF.md" but the runtime handoff file is .opencode/session/current-handoff.json
  (HANDOFF.md is only a template). Filename replaced in all 3 preset prompt fields.
- **FIX 2 - "AGENTS.md section 10"/"section 10" repointed to "AGENTS.md section 2.5".**
  oh-my-opencode-slim.jsonc lines 26/210/401/581/582/585 + docs/dev-infra-audit/NEXT-RUN.md
  line 124: AGENTS.md has no section 10 (the AI Devtools Modernization Workflow is
  section 2.5). References repointed without breaking the workflow references.
- **FIX 3 - boss_append.md deleted (dead duplicate).**
  .opencode/oh-my-opencode-slim/boss_append.md (100 lines, ~80% byte-identical to
  orchestrator_append.md) removed via git rm; scripts/test-interview-enforcement.sh
  Check 5 repointed to orchestrator_append.md. Single-sourced into
  orchestrator_append.md.

### Verification evidence (all gates exit 0)

- `rg "HANDOFF\.md"` over oh-my-opencode-slim.jsonc + opencode.jsonc -> 0 matches (FIX 1).
- `rg "section 10|S10"` over fix-scope files (oh-my-opencode-slim.jsonc, NEXT-RUN.md) -> 0 matches (FIX 2).
- `rg "boss_append"` over both jsonc configs -> 0 matches; boss_append.md absent from .opencode/oh-my-opencode-slim/ (FIX 3).
- make test-config sub-commands all exit 0 (make not installed on host, sub-commands run directly):
  - test-interview-enforcement 5/5 PASS
  - validate-opencode-config ok (x4 checks)
  - validate-agent-names 22 passed
  - validate-output-contracts 2 passed
  - validate-reviewer-sections 1 passed
  - validate-handoff 5 passed
  - test-ticket-gate ok
  - audit-agent-tool-coverage x2: 18 agents, 0 gaps
  - validate-skills 24 passed

## Re-verify

Independent review (ai-auditor, 2026-08-12): verdict APPROVE-WITH-NOTES -
implementation PASS; only process evidence (restart-smoke + registration) was
pending at review time. This close-out lane closes that gap.

Registered per AGENTS.md section 2.5 workflow step 7 (Register) + step 5 (Validate) evidence:

- **Restart smoke (step 5):** the fixed config was LIVE throughout the
  implementation session - this session's dispatches (incl. the ai-auditor
  independent review) ran under the new config with no HANDOFF.md / section 10 / boss_append
  regressions. A full daemon restart is NOT yet performed; the fix-verified config
  is staged in the working tree and will load on the next natural OpenCode restart.
  Restart-smoke is therefore satisfied-in-part: config-live evidence recorded,
  full-daemon-restart evidence pending next natural restart. Not fabricating a restart.
- **Registration (step 7):** CHANGELOG entry added (2026-08-12, DIA-117);
  learnings entry .opencode/learnings/external-patterns/2026-08-12-dia117-agent-instruction-fixes.md
  created with outcome field; ticket status OPEN -> VERIFIED (README index + counts updated).
- **Status: VERIFIED.**
