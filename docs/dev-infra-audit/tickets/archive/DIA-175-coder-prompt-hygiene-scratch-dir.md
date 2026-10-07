# DIA-175 - Coder prompt hygiene: instance separation, same-session fixes, scratch-dir permissions (DIA-174 follow-up)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-135 collided with origin/omo-slim-changes ticket DIA-135-research-pipeline-optimization-order-corruption-double-source-fetch-binary-persistence-decision.md (different ticket). Renumbered to DIA-175. -->

---

id: DIA-175
title: "Coder prompt hygiene: instance separation, same-session fixes, scratch-dir permissions (DIA-174 follow-up)"
area: opencode-config
severity: Medium
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: Developer questions after DIA-174 one-shot run (2026-08-14)
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
files_touched: [docs/dev-infra-audit/tickets/DIA-175-coder-prompt-hygiene-scratch-dir.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

Developer questions surfaced after the DIA-174 one-shot run (2026-08-14)
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

**Problem:** during DIA-174, coders repeatedly received permission requests
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

Three coder-prompt-hygiene items from the DIA-174 retrospective questions
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
- README index row added after the DIA-174 row.
- README summary counts updated: OPEN 30->31, Medium 44->45; all other
  counts unchanged.

For the 3 scope items: see each item's own verification under Description.

## Fix

Implemented 2026-08-14 on branch feature/dia135-rules (base c7c8d59, commits
00aae0e + b00101f), squash-merged into omo-slim-changes as 9922f9a
('feat(config): DIA-175 coder prompt hygiene - instance separation,
same-session fixes, scratch dir'). Diff vs base = 5 files, 18 insertions,
3 deletions.

### 1. Instance separation for TESTS vs CODE - DONE

Strict separation policy codified (policy CHANGE: supersedes the DIA-174
same-session GREEN reuse practice):

- AGENTS.md section 2.3 (new bullet): "Instance separation (DIA-175): RED
  test-writing and GREEN implementation for the same slice MUST be dispatched
  to DIFFERENT coder instances; the test-author never implements the slice it
  tested."
- .opencode/oh-my-opencode-slim/coder_append.md (new bullet): role set by the
  orchestrator dispatch payload (test-author or implementer); if you authored
  the tests for a slice, do NOT implement that slice; DIFFERENT coder
  instances.
- .opencode/oh-my-opencode-slim/orchestrator_append.md (new rule R4): RED
  test-writing and GREEN implementation MUST use DIFFERENT coder instances.
- .opencode/oh-my-opencode-slim.jsonc 3 presets (opencode-go / cebula / free)
  INSTANCE-SEPARATION RULE added (byte-identical block, sha256
  9b0b520d3c1e92f207660572b38ed53705a423fc7e48a9de52dddfabc8c26fbc each).

### 2. Same-session fixes - DONE

- AGENTS.md section 2.3.1 (new bullet): "Same-session fixes (DIA-175):
  fix-loop dispatches MUST resume the SAME coder session that wrote the code
  (resume by task_id/session_id per A2), never a fresh instance - fixes need
  the implementer's context."
- orchestrator_append.md new rule R5 (same rule, tied to A2 recall/resume
  mechanics).
- Same block in all 3 presets (byte-identical, see sha256 above).

### 3. Scratch-dir permissions - DONE

- .gitignore: `.scratch/` added (workspace-internal, gitignored).
- coder_append.md new bullet: "Scratch artifacts (DIA-175): create
  scratch/temp artifacts under .scratch/ (gitignored, workspace-internal),
  never under /tmp (external-dir writes prompt for permission)." Chosen fix
  variant (b) - workspace-internal scratch dir as primary; no /tmp/opencode
  allow rule added (variant (a) not needed - coders no longer write /tmp).

### Verification

- Two-axis review closed: 0 Spec, 2 Minor (fixed + re-verified closed).
- ai-auditor independent audit: APPROVE.
- Post-merge verification (commit 9922f9a, all exit 0):
  validate-opencode-config.sh OK; validate-agent-names.sh 24 passed;
  greps green ('DIFFERENT coder instances' x1 AGENTS + x1 orchestrator_append
  - x3 presets; 'SAME coder session' x1 AGENTS 2.3.1 + x1 orchestrator_append
  - x3 presets; '.scratch/' x1 .gitignore + x1 coder_append; 'never under
    /tmp' x1 coder_append); 3 preset rule blocks byte-identical (sha256 x3);
    zero 'two coders' regression; batch D surfaces intact.
- Husky pre-commit hook PASS on the merge commit (DIA-094 docker gate; no
  --no-verify; poetry-dev Up, evidence recorded).
- LOCAL-ONLY: no push, no remote operations (DIA-079 ASCII protocol).

## Re-verify

Re-review loop: 2 Minor findings accepted by developer, fixed on
feature/dia135-rules (b00101f), re-verified closed by reviewer (cycle 1/2);
ai-auditor independent audit APPROVE. No residual findings. Ticket DONE at
merge.
