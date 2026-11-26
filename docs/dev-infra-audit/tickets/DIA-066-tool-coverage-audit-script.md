# DIA-066 — Tool-coverage audit script — surface unlisted default-allow tools

<!-- Spin-off from DIA-055 (R2 of the §10-approved closure, 2026-08-08).
     UPDATE 2026-08-08: IMPLEMENTED + two-axis review closed (see Fix).
     Fix touches scripts/ + Makefile (test-config wiring). -->

---

id: DIA-066
title: "Tool-coverage audit script — surface unlisted default-allow tools"
area: scripts
severity: Low
status: VERIFIED
blocked_by: []
discovered: 2026-08-08
source: fix-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-08

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: "ses_0213b7008ffeB0wYC5RIhgFN1u"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Write `scripts/audit-agent-tool-coverage.sh` that enumerates all registered
tools (built-in + plugin-registered, incl. opencode-token-monitor's
`token_export` / `token_stats` / `token_history`, `envsitter_*`,
`console-ninja_*`, `dcp_*`) × each agent's permission coverage in
`.opencode/opencode.jsonc` and reports any unlisted = default-allow gaps.

**NOTE from gate (2026-08-08):** tool enumeration mechanism needs investigation —
OpenCode may not expose a clean "list all registered tools" API; investigate
`opencode debug config` or a plugin-registered-tools dump as source of truth
before committing to the approach. Confidence MEDIUM.

**Why it matters:** OpenCode permission blocks are per-tool override maps —
unlisted tools fall through to the global permission block → default allow
(DIA-055 root cause). This script converts that systemic exposure into a
repeatable gate that surfaces newly registered tools (plugin upgrades, new
plugins, new built-ins) before they silently become write-capable for every
agent.

**References:** DIA-055 (source ticket) ·
`.opencode/learnings/external-patterns/2026-08-08-dia055-token-permission-closure.md`
(R2 section).

## Verification

1. Script exits 0 with zero gaps reported after DIA-055 R1 lands.
2. Script reports each gap as `file:line` of the offending agent block.
3. Negative test: temporarily removing a `"token_*": "deny"` from one agent
   block makes the script exit non-zero and report that agent's block.

## Fix

**Implemented 2026-08-08 (coder lane, reviewed):**

- `scripts/audit-agent-tool-coverage.sh` — enumerates registered tools
  (built-in + plugin-registered) × each agent's permission coverage in
  `.opencode/opencode.jsonc` and reports unlisted = default-allow gaps as
  `file:line` of the offending agent block.
- `scripts/__tests__/audit-agent-tool-coverage.bats` — 17 tests.
- Makefile `test-config` wiring.

**Review trail (two-axis, rev-1 → rev-2):**

- rev-1 findings: 1 Critical (P1 exit-code collapse) + 3 Minor standards +
  3 Minor spec. Developer disposition: accept all; fix P1 + S1 + S3.
- rev-2 (cycle 1/2): ALL findings verified-closed, no new observations.

**Verification evidence (exit codes):**

- `bats scripts/__tests__/audit-agent-tool-coverage.bats` — 17/17 pass (exit 0).
- `make test-config` — exit 0.
- `bash -n scripts/audit-agent-tool-coverage.sh` — clean.
- `openspec validate dia-066-tool-coverage-audit` — exit 0.

Status: OPEN → IMPLEMENTED → VERIFIED (runtime re-verify 2026-08-08, see
Re-verify).

## Re-verify

**VERIFIED 2026-08-08 (runtime re-verify, independent lane).**
Status IMPLEMENTED → VERIFIED.

- `make test-config` — exit 0, 7/7 groups pass.
- Audit group output verbatim: "16 agents audited, 0 gaps, 181 warnings"
  against `.opencode/opencode.jsonc`.
- docker-profile invocation — ran cleanly.
- Verifier lane: ses_0201a1d57ffeOQwCxi5nL4y4x2.

## Review residuals (accepted 2026-08-08, closure commit ec961ef)

Two-axis review fbf4a5e...ec961ef: 0 Blocker / 0 Critical / 0 Major. Developer
disposition: accept + ticketize + close (no re-review cycle).

- S1 [Minor] audit-agent-tool-coverage.sh:80-87 — parse.py exit-code-3 documented but never emitted (dead contract)
- S2 [Minor] audit-agent-tool-coverage.sh:283-296 — json.load(open(...)) without context managers; double-open on error path
- S3 [Minor] audit-agent-tool-coverage.sh:204-206 — find_line naive substring search for agent keys (fragile for drift gate)
- S4 [Suggestion] audit-agent-tool-coverage.sh:297-303 — write-capable override not enumerated at invocation site
- S5 [Suggestion] bats test 12 name ambiguous vs test 6 (blanket-form)
- T1 [Minor] summary 'gaps' vs tasks.md 'hard gaps' — RESOLVED by amending tasks.md T4 AC to 'gaps' (proposal.md authority)
