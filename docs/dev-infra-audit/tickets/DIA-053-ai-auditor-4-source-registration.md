# DIA-053 — @ai-auditor 4-source registration + @ai-specialist docs-only narrowing

<!-- Task T2 of openspec/changes/ai-self-improvement-auditor-and-cleanup (validated,
     openspec validate exit 0, 2026-08-06). §10-ROUTED TICKET (AI-tooling config):
     Phase-1 ai-specialist gate already DONE (findings ai--1); implementation via
     @coder; §10 Phase-5 restart+smoke (owner-side); §10 Phase-6 independent
     review by @ai-specialist (review matrix: opencode config → @ai-specialist,
     per AGENTS.md §2.5). THIS TICKET DOES NOT IMPLEMENT. -->

---

id: DIA-053
title: "@ai-auditor 4-source registration + @ai-specialist docs-only narrowing"
area: opencode-config
severity: Medium
status: DONE
blocked_by: [DIA-052]
discovered: 2026-08-06
source: inventory
date: 2026-08-06
created: 2026-08-06
updated: 2026-08-06

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Summary:** register a new read-only `@ai-auditor` subagent across all 4
agent-name sources (S1–S4) and narrow the `@ai-specialist` description to a
documentation-only mandate. The 4-source containment contract
(`scripts/validate-agent-names.sh` extracts S1..S4) is the mechanical gate:
post-change it must report `22 passed` (was 21).

**Blocking edge (per tasks.md dependency graph):** blocked by DIA-052 (T1) only
in the verification-matrix sense — the post-T1 `make test-skills` clean baseline
is a precondition for the final combined gate run. T2 does NOT functionally
depend on T1's output and CAN be implemented in parallel with T1; the two touch
disjoint files.

**S1 — `AGENTS.md` §9 row (add one):** display `@ai-auditor`, internal
`ai-auditor`, lane `AI-tooling audit (read-only)`; placement alphabetical by
internal name (between `ai-specialist` and `analyzer`).

**S2 — `.opencode/opencode.jsonc` (two changes):**

- Add `ai-auditor` agent block (`mode: subagent`). Permission contract per the
  owner-approved orchestrator brief — this REFINES design.md §2's snippet
  (brief supersedes: bash is fully denied here, no `curl`/`wget` — the auditor
  has no network need):
  - deny: `edit`, `bash`, `apply_patch`, `ast_grep_replace`,
    `envsitter_*`, `webfetch`, `task`
  - allow `read` scoped to: `.opencode/session/*`, `NEXT-RUN.md`, `AGENTS.md`,
    `practice-protected.md`
  - allow tools: `read`, `glob`, `grep`, `list`, `skill`, `question`,
    `wait_for_user`, `get-my-session-id`
  - `mode: subagent` alone does not prevent writes — the permission block is the
    behavioural enforcement.
- Narrow `ai-specialist` `description` field ONLY (no change to `prompt`,
  `orchestratorPrompt`, model, temperature, color, or permissions — already
  `edit: deny`). Exact new wording per design.md §3:
  "Read-only researcher of agent/skill/config best practices for OpenCode
  itself. Findings routed through orchestrator for persistence. Scope:
  documentation + config review only; no runtime dispatch authority; no
  implementation."

**S3 — `.opencode/oh-my-opencode-slim.jsonc` (three changes):**

- Add `ai-auditor` to the top-level `agents` block (model/variant/skills/mcps
  shape mirroring the existing `ai-specialist` entry).
- Add `ai-auditor` to each of the 3 preset slots that carry `ai-specialist`
  (`opencode-go`, `cebula`, `deepthink`), mirroring those preset shapes. Model
  slots per the orchestrator brief (coder discretion per design.md §2 para 3):
  primary `github-copilot/gpt-5.3-codex`, fallback
  `github-copilot/gemini-3.1-pro-preview`.
- Orchestrator prompt: add the council rule to `orchestratorPrompt` (exact text
  at coder discretion per the brief) + narrow `ai-specialist.prompt` wording
  (documentation-only scope clause; permissions stay read-only).

**S4 — `.opencode/agents/ai-auditor.md` (new file):** frontmatter carries
`description` + `mode: subagent` ONLY (mirroring `memory-manager.md` — the
permissions live in `opencode.jsonc`, keeping a single source of truth); body:
short read-only mandate. Note `.opencode/agents/*.md` auto-loads at next
OpenCode startup, so the agent is dispatchable immediately after restart.

**§10 ROUTING NOTE (MANDATORY):** this ticket changes `.opencode/` config +
agent files → routes through AGENTS.md §10 (AI Devtools Modernization
Workflow). Phase-1 @ai-specialist gate is ALREADY DONE (findings `ai--1`,
registered in `.opencode/learnings/external-patterns/2026-08-06-ai-self-improvement-gate.md`).
Implement via @coder; §10 Phase-5 restart+smoke is OWNER-SIDE (restart OpenCode

- smoke dispatch); §10 Phase-6 independent review by @ai-specialist per the
  review matrix (opencode config → @ai-specialist). Verification gates:
  `make test-config` exit 0, JSONC parse, restart-verify per §10 Phase 5.

## Verification

1. `bash scripts/validate-agent-names.sh` — exit 0,
   `22 passed, 0 failed, 0 warnings` (delta 21 → 22).
2. `make test-config` — exit 0 (all config validators green).
3. `ls .opencode/agents/` — shows both `memory-manager.md` and `ai-auditor.md`.
4. `grep -c '"ai-auditor"' .opencode/opencode.jsonc` — ≥ 1.
5. `grep -c '"ai-auditor"' .opencode/oh-my-opencode-slim.jsonc` — ≥ 4 (1 in
   `agents` block + 3 preset slots).
6. `grep -c '^|.*ai-auditor.*|' AGENTS.md` — 1 (the new §9 row).
7. §10 Phase-5 restart+smoke (owner-side): restart OpenCode; dispatch
   `@ai-auditor` on a minimal task (e.g. "list the agents registered in
   AGENTS.md §9") — dispatch must succeed; an edit attempt must fail at the
   permission layer; out-of-allowlist bash must fail at the permission layer.
   Document the result in the coder handoff.

## Fix

**Fix (2026-08-06, campaign T2 — ledger row 483):** cod-7 implemented the 4-source
registration: S1 — AGENTS.md §9 row (`@ai-auditor | ai-auditor`); S2 —
`.opencode/opencode.jsonc` ai-auditor block (permission contract per the orchestrator
brief: deny `edit`/`bash`/`apply_patch`/`ast_grep_replace`/`webfetch`/`task` + 15
`envsitter_*` tools; allow `read`/`glob`/`grep`/`list`) + ai-specialist description
narrowing; S3 — `.opencode/oh-my-opencode-slim.jsonc` agents entry + 3 preset slots
(opencode-go/cebula/free; deepthink corrected to the real `free` preset) +
orchestratorPrompt AI-AUDITOR rule + ai-specialist.prompt doc-only scope; S4 —
`.opencode/agents/ai-auditor.md` (new, frontmatter description+mode only, mirrors
memory-manager.md). Verification: validate-agent-names.sh **`22 passed, 0 failed,
0 warnings`** (delta 21→22), make test-config exit 0, openspec validate exit 0.

## Re-verify

**Re-verify (2026-08-06 — ledger rows 484/486):** §10 Phase-6 independent review by
@ai-specialist (ai--2, row 484) — **APPROVE-WITH-CONDITIONS** (S1–S4 per-delta VERIFIED;
1 Minor finding F4 = ai-specialist orchestratorPrompt overlap at
`.opencode/oh-my-opencode-slim.jsonc:565`). F4 fix applied by cod-8 (row 486): 1-line
docs-only edit deferring §10 Phase 6 to @ai-auditor; re-verified agent-names **22/0/0** +
test-config exit 0 + openspec validate exit 0. **In-scope follow-up (this cycle, row 499):**
`"token_export": "deny"` added at `.opencode/opencode.jsonc:231` (ai-auditor permission
block; §10 chain rows 496-500) — same ticket scope area (ai-auditor read-only profile
hardening); §10 Phase-5 re-smoke certified SMOKE-PASS (row 507). Ticket flipped
**OPEN → DONE** (2026-08-06) per owner authorization (G1 gate row 503 + certification
path row 509).
