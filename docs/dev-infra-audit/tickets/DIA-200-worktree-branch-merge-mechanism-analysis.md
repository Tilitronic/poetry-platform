# DIA-200 - Analyze worktree/branch/merge mechanism + verify Codex/ClaudeCode follow the same conventions

---

id: DIA-200
title: "Analyze worktree/branch/merge mechanism + verify Codex/ClaudeCode follow the same conventions"
area: dev-infra
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: developer-directive
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffdda6438ffemwyKfkQzMuU6qx" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "coder" # agent name (coder, reviewer, etc.)
model: "opencode-go/deepseek-v4-flash" # model ID used
parent_session_id: "" # orchestrator's session ID
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [docs/dev-infra-audit/tickets/DIA-200-worktree-branch-merge-mechanism-analysis.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

Developer directive (2026-08-14, verbatim transliterated): "chy varto
shchos vypratyty u mekhanizmakh stvorennia/merdzhu hilok chy worktree, i chy
Codex i ClaudeCode robliat v toi samyi sposib" ("is it worth fixing anything
in the branch/worktree creation/merge mechanisms, and do Codex and ClaudeCode
do it the same way"). Full analysis of the parallel-worktree mechanism AND a
check of whether Codex/ClaudeCode follow the same conventions via their
.codex/ .claude/ configs.

Context: this session (DIA-139 + DIA-153) exercised the batch-D parallel-
worktree mechanism end-to-end and surfaced five known frictions:

1. **Squash-merged branches refuse `git branch -d`** - after a squash-merge
   the feature branch is not a proper descendant, so `git branch -d` refuses
   and `-D` is required, which is agent-denied by DIA-096. Leaves branches
   stranded.
2. **Worktrees accumulate with no automatic teardown** - 13 stale worktrees
   from DIA-132-135 still present as of 2026-08-14 (see DIA-177, which
   documents the same accumulation for feature branches and 13 worktrees).
3. **Nested worktree requires innermost-first removal** - a nested worktree
   (feature-dia134-shim-selfcheck inside feature-dia134-shim) must be removed
   innermost-first; the current tooling does not model or document this
   ordering.
4. **Shared test seam not declared in slice-ownership** - the shared test
   file batch-d-infra.test.mjs was not declared in slice-ownership, producing
   a predictable merge conflict during batch-D merges (resolved manually in
   DIA-179 merge phase, slice C).
5. **Push mechanism now smooth** - after SSH/known_hosts/IdentityAgent fixes
   (DIA-153, DIA-173) push works; this part is resolved, not a friction.

Related tickets: DIA-100 (git worktrees for parallel dev sessions, FIXED),
DIA-132 (coder-escalated silent failure), DIA-137 (orchestrator routine work
systems), DIA-153 (push lineage reconciliation), plus DIA-172/174 (batch-D
expansion and hardening).

## Scope

1. **Mechanism review** - review worktree-conventions.md, scripts/worktrees.sh,
   and the DIA-100/132/137 lifecycle for optimization opportunities:
   - auto-teardown after merge (extend the DIA-177 cleanup direction)
   - nested-worktree prohibition or safe ordering
   - squash-merge vs regular-merge implications for branch cleanup
   - shared test-seam declaration in slice-ownership (batch-d-infra.test.mjs
     style conflicts)
2. **Code client parity inventory** - inventory .codex/ .claude/ configs (and
   any other AI-tool configs, e.g. .cursorrules): do they reference
   worktree-conventions.md or worktrees.sh, do they follow batch-D, or do
   they define divergent workflows?
3. **Recommendations** - categorized findings with rationale, concrete
   recommendation, and effort estimate each. Optionally a knowledge report
   (analyzer lane may preallocate an ana-ID if it produces a report).

## Verification

An analysis report exists with categorized findings. Required categories:
MECHANISM / CODE-CLIENT-PARITY / FIX / DRY. Each finding carries rationale +
concrete recommendation + effort estimate. The Codex/ClaudeCode parity section
is evidence-based: it reads the actual .codex/ .claude/ (etc.) configs, not
speculation.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE (2026-08-16) - CLOSE: ana022 mechanism deliverable, follow-ups filed, CODE-CLIENT-PARITY verified

Closeout lane (AFK campaign 2026-08-16, developer-authorized autonomous
closeout):

- Mechanism deliverable: knowledge/ana022-worktree-mechanism-analysis/
  ana022-worktree-mechanism-analysis-report.md (418 lines, committed 8f227f2,
  shelf-registered .opencode/memory-shelf.yaml:554). Categorized findings
  MECHANISM (M-1..M-5) / DRY (D-1..D-3) / OBSERVATIONS (O-1..O-7), each with
  rationale + recommendation + effort; prioritized summary R-1..R-6 in
  section 7. Verification checklist satisfied: analysis report exists with
  all required categories and evidence-based recommendations.
- CODE-CLIENT-PARITY scope item: CLOSED with evidence - no `.codex/`, no
  `.claude/`, no `.cursorrules`, no `.cursor/`, no
  `.github/copilot-instructions.md` exist anywhere in the repo (checked
  2026-08-16 at closeout); no AI-client configs reference
  worktree-conventions.md / worktrees.sh / batch-D, and none define divergent
  workflows. The parity question resolves to "no clients configured, no
  conventions to diverge".
- Follow-up tickets filed for the highest-value fixes (this ticket does NOT
  close the tooling gaps - it delivers the analysis that drives them):
  - DIA-201 worktree cleanup: orphaned-dir sweep for .worktrees/ (ana022 R-1,
    section 2 + M-2) - highest-value fix, effort M.
  - DIA-202 worktrees.sh: nested-worktree creation guard (ana022 R-2, M-3) -
    effort S-M.
  - DIA-203 make worktree-gc target + dry-run post-push warning (ana022 R-4,
    section 7 + M-1) - effort M, explicitly NOT cron/auto-scheduled.
    (R-3 spec-template seam rule, R-5 worktree_pairs() DRY, R-6 policy-prose
    trim were judged lower-value and left to normal maintenance.)
- Status: OPEN -> CLOSED (2026-08-16).
