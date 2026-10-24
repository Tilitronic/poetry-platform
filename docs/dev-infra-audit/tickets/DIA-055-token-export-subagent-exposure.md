# DIA-055 — Write-capable token_export exposed to all subagents (permission default-allow model)

<!-- Backlog-only ticket: documents the systemic permission-model exposure found
     during the §10 Phase-5 smoke for @ai-auditor — token_export (global plugin
     opencode-token-monitor@0.5.0) wrote /tmp/opencode/ai-auditor-smoke.txt
     (594B) with no deny. NO code/config change is made by this ticket;
     implementation is out of scope and awaits owner scheduling. Fix touches
     .opencode/ config → routes through §10 (AI Devtools Modernization
     Workflow) when scheduled. -->
<!-- UPDATE 2026-08-07: implemented via §10 cycle (4-delta wildcard-deny
     hardening) — see Fix. Status IMPLEMENTED (pending restart+smoke). -->
<!-- UPDATE 2026-08-08: runtime smoke VERIFIED — 6/6 denied subagents, zero
     writes, orchestrator allow intact. Status VERIFIED (see Re-verify). -->
<!-- CLOSED 2026-08-09: root cause eliminated by the plugin-removal campaign
     (commits 4216406/0af6b6e/58cddc6) — the plugins opencode-telemetry +
     opencode-token-monitor were removed from the configuration per developer
     decision following the usage audit (res006-telemetry-plugin-alternatives).
     The token_export tool no longer exists. Status CLOSED. -->

---

id: DIA-055
title: "Write-capable token_export exposed to all subagents (permission default-allow model)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-06
source: orchestrator-discovered
date: 2026-08-06
created: 2026-08-06
updated: 2026-08-09

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: "ses_029f89402ffe7sago6WvVuIgf4"
lane_id: "cod-1"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: ["messages.md#row-495", "messages.md#row-496", "messages.md#row-497"]

---

## Description

**Summary:** `token_export` (global plugin `opencode-token-monitor@0.5.0`) is a
write-capable tool: it writes an arbitrary `file_path` (`mkdirSync` +
`writeFileSync`, no path allowlist) and auto-writes a CWD
`token-export-<date>.<ext>` file when the export exceeds ~10k chars. It is NOT
denied for any agent → available to all subagents + the orchestrator under
OpenCode's permission default-allow model.

**Reproduction context:** during the §10 Phase-5 smoke for @ai-auditor, a
`token_export` attempt succeeded and wrote `/tmp/opencode/ai-auditor-smoke.txt`
(594B) with NO deny — proving the @ai-auditor permission block
(opencode.jsonc:220-251) lacks `token_export` / `token_history` / `token_stats`
entries. Coder-lane forensics (`ai--3` gate findings) confirmed CONFIG-GAP:
OpenCode permission blocks are per-tool override maps; unlisted tools fall
through to the global permission block → default allow.

**Impact:** any subagent — including the pure-analyst tiers (analyzer /
reviewer / architector) — or the orchestrator can write files at arbitrary
paths (or the CWD) and export token telemetry on demand: a silent write-capable
tool with no path allowlist. Breaches the @ai-auditor read-only intent (see
cross-references).

**Cross-references:** DIA-053 (@ai-auditor 4-source registration — the profile
this gap breached); owner rulings + discovery in session log rows 495/496/497;
ai--3 gate findings registered in
`.opencode/learnings/external-patterns/2026-08-06-ai-auditor-token-export-deny.md`.

## Verification

1. Reproduce the breach: attempt `token_export` as @ai-auditor (or any
   subagent without an explicit deny) → tool succeeds and writes a file (e.g.
   `/tmp/opencode/ai-auditor-smoke.txt`) with NO deny message.
2. Confirm the config gap: @ai-auditor permission block (opencode.jsonc:220-251)
   has no `token_export` / `token_history` / `token_stats` entries; global
   `plugin[]` (opencode.jsonc:136) registers `opencode-token-monitor@0.5.0`;
   global permission block has no token\_\* entries.
3. Post-fix (when scheduled): re-run the §10 Phase-5 style smoke for each
   affected agent — `token_export` attempt must be DENIED (permission denied,
   no file written).

## Fix

**Applied 2026-08-07 (§10 cycle)** — 4-delta config change to
`.opencode/opencode.jsonc`: orchestrator `token_export: allow` (explicit, after
`websearch: allow`); architector/analyzer/reviewer `token_*: deny` (after
`task: deny`); ai-auditor `token_export: deny` → `token_*: deny`;
council/resource-manager/ai-specialist `token_*: deny`. Registration: CHANGELOG
2026-08-07 top entry; learnings `2026-08-07-token-tool-permission-model.md` +
index pointer. Verification: `make test-config` exit 0; ai-auditor
APPROVE-WITH-FINDINGS (F1/F3/F4 fixed, F2 deferred). Owner-directed candidates
(2026-08-06, row 496 session log) retained below as reference.

**Root cause:** OpenCode permission block = per-tool override map; unlisted
tools fall through to the global permission block → default allow (deny-by-
default not implemented upstream).

**Fix candidates (backlog, not now):**

1. **Per-agent `token_export` denies** for the pure-analyst tiers (analyzer /
   reviewer / architector) — add `"token_export": "deny"` after `"task":
"deny"` in each block (mirrors the `ai--3` delta for @ai-auditor).
2. **Evaluate orchestrator need** — the orchestrator has a legitimate token-
   accounting use for `token_export`; likely KEEP for orchestrator, DENY
   subagents.
3. **Project tool-coverage audit script** — enumerate registered tools × each
   agent's permission coverage to surface unlisted default-allow tools (root
   cause, HIGH, architectural — also monitor upstream for deny-by-default).
4. **Upstream issue to opencode-token-monitor** — request a path allowlist /
   opt-in file writes for `token_export`.
5. **Monitor OpenCode for a deny-by-default option** — unlisted-tools-default-
   allow is the architectural root cause.

**Systemic exposure split (S1–S5):**

- **S1** — `token_export` available to ALL subagents; pure-analyst tiers
  (analyzer/reviewer/architector) need audit.
- **S2** — orchestrator also default-allow `token_export`; evaluate per
  candidate 2.
- **S3** — unlisted-tools-default-allow root cause (HIGH, architectural);
  monitor upstream + consider tool-coverage audit script (candidate 3).
- **S4** — `token_export` write behavior: no path allowlist, auto CWD-write on
  output >10k chars; file upstream issue (candidate 4).
- **S5** — `opencode-best-practices.md` + `ai-assist-sources.yaml` MISSING from
  disk though referenced in ai-auditor.md + 2026-08-01 learnings →
  @resource-manager curation. **→ RECLASSIFIED INVALID 2026-08-07:** both files
  DO exist on disk at `.opencode/oh-my-opencode-slim/knowledge/`
  (opencode-best-practices.md 4704B, ai-assist-sources.yaml 10419B) — confirmed
  by ai-specialist ai--1 gate research + direct on-disk check. No
  @resource-manager curation action needed; S5 removed from the exposure set.

**§10 routing note (MANDATORY):** this fix touches `.opencode/` config → when
implemented it MUST route through §10 (AI Devtools Modernization Workflow):
@ai-specialist gate → design → @coder → @ai-specialist independent review →
restart + smoke. Verification gates when implemented: `make test-config` exit
0, JSONC parse, restart-verify per §10 Phase 5.

**Out of scope:** no code/config change in this ticket; backlog item awaiting
owner scheduling.

## Re-verify

**VERIFIED 2026-08-08 (runtime smoke, post-restart):**

- **6/6 denied:** coder, code-navigator, researcher, designer, observer,
  memory-manager all denied `token_*` post-restart — manifested as
  tool-not-available / registry absence (lessons.md:129).
- **Zero writes:** no token telemetry file written by any denied agent.
- **Orchestrator allow intact:** `token_stats` + `token_export` still allowed.

Status: IMPLEMENTED → VERIFIED.

## Closure delta (2026-08-08)

- **R1 — applied:** 6-agent `token_*: deny` added to
  `.opencode/opencode.jsonc` (coder/code-navigator/researcher/designer/
  observer/memory-manager). coder gains its first permission entry with the
  carve-out documented in the preserved "no restrictions" comment (edit/bash/
  task rationale untouched; token telemetry writes serve no implementation
  purpose). Total `"token_*": "deny"` entries in opencode.jsonc: 13 (7 prior +
  6 new). Approved via §10 Phase 2 decision "Proceed R1 + spin DIA-066"
  (gate token present 2026-08-08).
- **R2 — spun off:** tool-coverage audit script → DIA-066 (OPEN, Low).
  Enumeration mechanism (built-in + plugin-registered tools) needs
  investigation — no clean "list all registered tools" API confirmed;
  confidence MEDIUM.
- **R3 — upstream monitoring (recurring):** no permission-model changes in
  OpenCode v1.18.12 → v1.18.15; unlisted-tools-default-allow remains the
  architectural root cause; deny-by-default not available upstream.
- **resource-manager bash-gap — CLOSED (not a real gap):** the R2 audit
  candidate flagged @resource-manager's bash coverage, but inspection of
  opencode.jsonc:195-214 shows bash already restricted to
  curl/wget/trafilatura allow + `*: deny` — no default-allow bash leak.
- **Status decision:** kept IMPLEMENTED. Final VERIFIED status awaits Phase 5
  restart + smoke (next boot) — per §10 Phase 5, config changes take effect on
  next run.
