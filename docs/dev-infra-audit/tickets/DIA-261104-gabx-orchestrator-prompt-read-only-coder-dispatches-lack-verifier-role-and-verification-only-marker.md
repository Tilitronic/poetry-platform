# DIA-261104-gabx - orchestrator prompt: read-only coder dispatches lack verifier role and verification-only marker

---

id: DIA-261104-gabx
title: "orchestrator prompt: read-only coder dispatches lack verifier role and verification-only marker"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-04
source: inventory
date: 2026-11-04
created: 2026-11-04
updated: 2026-11-04

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

- commit:b454ff76fc3187ad167445873cc8d5395a617961
- commit:7c29205ac36f1169caeca08d7ebda81ad93583e7

---

## Description

Problem: several orchestrator prompt passages dispatch the coder lane on
read-only work but carry neither the hyphenated marker (verification-only /
read-only verification / verify-only) that the delegation-observer plugin keys
its empty-result exemption on, nor the ROLE: verifier field of the new coder
contract. Consequence: a valid empty verification result is flagged as
empty_result_detected, or the coder runs the full Pre-Handoff checklist after
a pure read.

Confirmed spots:

1. .opencode/oh-my-opencode-slim/orchestrator_append.md lane-0 checksum delegation: text says
   "VERIFICATION ONLY" spelled with a space and no ROLE line. Add the
   hyphenated marker plus ROLE: verifier.
2. .opencode/oh-my-opencode-slim/orchestrator_append.md Templates section, block
   "# verification / run-gates (no edits)": the template already carries the
   hyphenated marker but lacks ROLE: verifier and the standard
   REPORT: RESULT, ROLE, FILES_TOUCHED, VERIFICATION_EVIDENCE, COMMANDS_RUN,
   BLOCKERS line. Bring it in line with the "# coder implementation" template.
3. .opencode/oh-my-opencode-slim/orchestrator_append.md "Exit checksum delegation (DIA-093, FIX E)":
   heading and body use "verification only" / "for VERIFICATION ONLY" with a
   space. Add the hyphenated marker and ROLE: verifier, WITHOUT weakening the
   existing hard rule that the lane must never write or edit the handoff file.
4. .opencode/oh-my-opencode-slim/orchestrator_append.md "Changelog Read Protocol (DIA-194)": the delegated
   partial-read lookup must carry the hyphenated marker and ROLE: verifier so
   the lane skips the Pre-Handoff checklist. Note the lane choice there is
   permission-driven (only coder / coder-escalated hold a python3 bash entry)
   - do not re-describe it as role-driven.
5. .opencode/oh-my-opencode-slim/orchestrator_append.md Truncated/Empty Subagent Result Protocol, step
   "3. RESUME" (scripts/lane-resume via coder dispatch): read-only call, add
   the hyphenated marker and ROLE: verifier.
6. .opencode/oh-my-opencode-slim/orchestrator_append.md same protocol, step "4. VALIDATE": two fixes -
   (a) replace "escalate per the 3-failures rule" with "escalate after 3
   consecutive empty results - do NOT loop" (the 3-failures rule is three
   failures of the same test, not three empty results); (b) widen the field
   list from (RESULT / FILES_TOUCHED / VERIFICATION_EVIDENCE) to
   (RESULT / ROLE / FILES_TOUCHED / VERIFICATION_EVIDENCE / COMMANDS_RUN /
   BLOCKERS).
7. .opencode/agents/coder-escalated.md (pre-handoff checklist lines): the
   instruction to run dev build, lint and tests is unconditional and now
   contradicts the role-dependent coder contract. Make it role-dependent and
   reference RESULT: BLOCKED.

UNCONFIRMED, verify before editing: a report claims the headings
"1. DETECT", "2. PRESERVE", "3. RESUME", "4. VALIDATE" in the same protocol
are glued to their following word with no separator (for example
**DETECT**after). One copy of the text shows them correctly separated
("1. **DETECT** - after"). Do NOT "fix" them if they are already correct -
record the actual state at HEAD in your report.

Out of scope, do not touch: VERIFICATION_ONLY_PATTERN and the empty-result
detector (they must keep keying on the hyphenated literal only, never on
ROLE), tdd-craftsman, check-orchestrator-prompt-drift.sh,
batch-d-infra.test.mjs, validate-output-contracts.sh, AGENTS.md section 9
agent-name lockstep, and all of ai-specialist / ai-auditor / analyzer /
analyzer-escalated prompt bodies.

## Verification

- make test-config exit 0 after each commit (b454ff76 and 7c29205a).
- scripts/check-orchestrator-prompt-drift.sh: 0 gaps; both jsonc preset
  prompts updated byte-identically (same string in both preset blocks).
- batch-d-infra suite: 64 pass / 0 fail.
- ai-auditor verdict PASS-WITH-FINDINGS, then targeted re-review PASS:
  the single Minor finding verified-closed, zero re-review observations.
- Commits: b454ff76fc3187ad167445873cc8d5395a617961 (verifier role +
  verification-only markers across orchestrator_append.md,
  coder-escalated.md, oh-my-opencode-slim.jsonc) and
  7c29205ac36f1169caeca08d7ebda81ad93583e7 (resume-truncated-lane skill
  alignment).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Owner disposition

- D1 accepted (new escalate wording)
- D2 accepted (both jsonc presets included)
- D3 rejected (generic prose untouched)
