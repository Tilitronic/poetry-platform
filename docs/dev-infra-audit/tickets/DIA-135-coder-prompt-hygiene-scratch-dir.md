# DIA-135 - Coder prompt hygiene: instance separation, same-session fixes, scratch-dir permissions (DIA-134 follow-up)

---

id: DIA-135
title: "Coder prompt hygiene: instance separation, same-session fixes, scratch-dir permissions (DIA-134 follow-up)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: Developer questions after DIA-134 one-shot run (2026-08-14)
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00003d4d0ffejQ0qOb44ccOKKU"
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_00327cd6effet7lPBAkPxJ0M3U"
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-135-coder-prompt-hygiene-scratch-dir.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

Developer questions surfaced after the DIA-134 one-shot run (2026-08-14)
about how the coder lane is prompted: whether tests and implementation must
run in separate coder instances, whether fix-loop dispatches must resume the
originating session, and why coders repeatedly hit /tmp permission prompts.
Each item below is self-contained: problem / proposed change / verification.

### 1. Instance separation for TESTS vs CODE

**Problem:** unclear whether the coder/orchestrator/reviewer prompt surfaces
(coder.md, coder_append.md, reviewer.md, orchestrator_append.md,
oh-my-opencode-slim.jsonc 3 presets, AGENTS.md sections 2.3 / 2.3.1,
tdd-craftsman SKILL.md) mandate that TESTS (RED) and IMPLEMENTATION (GREEN)
are done by DIFFERENT coder instances. If absent, decide whether to codify.
Note: session reuse across RED -> GREEN is the current practice per the
developer one-shot directive - any codification must reconcile with reuse.

**Proposed change:** add an explicit prompt rule stating the chosen policy,
e.g. "RED test-writing and GREEN implementation MAY run in the same resumed
coder session when context continuity helps; separate instances are NOT
required" - or the opposite if the developer prefers strict separation.

**Verification:** grep the prompt surfaces for the rule after implementation.

### 2. Same-session fixes

**Problem:** unclear whether prompts mandate that fix-loop dispatches REUSE
the same coder session that wrote the code (resume by session_id/task_id).
A fresh instance loses the context of what it wrote; the orchestrator
operating rules already prefer recall/resume via session_id over re-invoking
task() for recall, but the coder prompt side is not explicit.

**Proposed change:** codify: "Fix-loop dispatches MUST resume the coder
session that produced the finding (session reuse for context continuity),
not spawn a fresh instance".

**Verification:** grep for the rule in the prompt surfaces.

### 3. Scratch-dir permissions (the trigger)

**Problem:** during DIA-134, coders repeatedly received permission requests
when creating temp files under /tmp. opencode.jsonc coder permissions re
/tmp are not configured to allow it, so every temp write prompts.

**Proposed change:** implement a fix so coders NEVER need a /tmp permission
prompt, preferring a workspace-internal gitignored scratch dir as primary
(no external-dir permission at all) with /tmp/opencode/\*\* allow as fallback
for genuinely external artifacts:

- (a) add an explicit allow rule for /tmp/opencode/\*\* in the coder
  permission block (bash/edit), and/or
- (b) introduce a workspace-internal gitignored scratch dir (e.g. .scratch/
  or reuse scripts/**tests** for persistent tests) + a prompt instruction
  "create scratch/temp artifacts under <scratch dir>, never under /tmp".

**Verification:** a coder creates a temp file under the scratch dir without
any permission prompt (functional smoke); .gitignore covers it.

## Scope

Three coder-prompt-hygiene items from the DIA-134 retrospective questions
(see Description sections 1-3): instance-separation policy, same-session
fix-loop resume rule, and scratch-dir permissions (/tmp prompt elimination).
Dominant area recorded as opencode-config.

## Verification

Self-check evidence for this ticket's own creation:

- Frontmatter parses: all fields present (id/title/area/severity/status/
  blocked_by/discovered/source/date/created/updated/parent_session_id/
  session_id/lane_id/agent/model/attempts/lease_expires_at/files_touched/
  artifacts/evidence).
- All 5 body sections present: Description / Scope / Verification / Fix /
  Re-verify.
- README index row added after the DIA-134 row.
- README summary counts updated: OPEN 30->31, Medium 44->45; all other
  counts unchanged.

For the 3 scope items: see each item's own verification under Description.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
