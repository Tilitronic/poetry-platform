# DIA-135 coder prompt hygiene - instance separation, same-session fixes, scratch dir (2026-08-14)

- **Date:** 2026-08-14
- **Source:** DIA-135 ticket (Medium, opencode-config, DIA-134 follow-up); developer questions after the DIA-134 one-shot batch D run: whether tests/code need separate coder instances, whether fix loops must resume the originating session, and why coders kept hitting /tmp permission prompts.
- **Status:** IMPLEMENTED + REVIEWED + AUDIT-APPROVED + MERGED (squash-merge 9922f9a on omo-slim-changes, 2026-08-14); ticket DIA-135 DONE.
- **Outcome:** all 3 items closed. (1) Strict instance separation codified: AGENTS.md 2.3 bullet + coder_append.md bullet + orchestrator_append.md R4 + INSTANCE-SEPARATION RULE in all 3 presets (byte-identical) - RED test-writing and GREEN implementation MUST use DIFFERENT coder instances; the test-author never implements the slice it tested. (2) Same-session fixes codified: AGENTS.md 2.3.1 bullet + orchestrator_append.md R5 + SAME-SESSION FIXES rule in all 3 presets - fix-loop dispatches MUST resume the SAME coder session that wrote the code (resume by task_id/session_id per A2), never a fresh instance. (3) Scratch-dir permission pattern: .gitignore gains `.scratch/` + coder_append.md bullet "create scratch/temp artifacts under .scratch/, never under /tmp" - coders never need a /tmp external-dir permission prompt.

## Ticket

- **DIA-135** (Medium, opencode-config, DONE) - "Coder prompt hygiene: instance separation, same-session fixes, scratch-dir permissions (DIA-134 follow-up)".
- **Related:** DIA-134 (parent), DIA-063 (ticket-ID gate), DIA-128 (prompt precedence - file wins in project runtime).

## Lessons

- **Strict instance separation is now the policy (POLICY CHANGE):** the DIA-134 one-shot practice of reusing the same coder session across RED/GREEN is SUPERSEDED. AGENTS.md 2.3 (DIA-135 bullet) now mandates DIFFERENT coder instances for test-writing and implementation; the orchestrator dispatch payload names the coder's role (test-author or implementer) per dispatch. Any future batch that reuses sessions across RED/GREEN contradicts the prompt surface and fails the DIA-063-adjacent prompt lockstep.
- **Same-session fixes rule (R5):** fix-loop dispatches resume the SAME coder session that wrote the code (resume by task_id/session_id per A2) - fixes need the implementer's context; a fresh instance loses what it wrote. This is separate from (and compatible with) instance separation: separation applies RED vs GREEN authorship; R5 applies the fix loop after GREEN.
- **Scratch-dir pattern (.scratch/):** workspace-internal gitignored scratch dir as the primary temp-artifact location means coders NEVER trigger the external-dir (/tmp) permission prompt - a zero-config, zero-permission-change fix. Prefer this pattern over adding /tmp allow rules (the ticket's variant (a), /tmp/opencode/** allow, was NOT needed - variant (b) alone eliminated the prompts).
- **Worktree husky-shim live proof:** the DIA-134 S1 worktree husky-shim (scripts/worktrees.sh materializes .husky/_ in new worktrees) worked in production - both feature/dia135-rules commits (00aae0e, b00101f) ran the fresh worktree's pre-commit hook; the main-tree hook PASSED on the squash-merge commit. The shim is not just bats-tested, it now has two real worktree commit runs behind it.

## Validation

- Post-merge full verification (commit 9922f9a, 2026-08-14, all exit 0): bash .opencode/scripts/validate-opencode-config.sh exit 0; bash scripts/validate-agent-names.sh 24 passed / 0 failed; lockstep greps green ('DIFFERENT coder instances' in AGENTS.md + orchestrator_append.md + all 3 presets; 'SAME coder session' in AGENTS.md 2.3.1 + orchestrator_append.md + all 3 presets; '.scratch/' in .gitignore + coder_append.md; 'never under /tmp' in coder_append.md); 3 preset rule blocks byte-identical (sha256 9b0b520d... x3); zero 'two coders' regression; batch D surfaces intact; git show --stat HEAD = exactly 5 files.
- Husky pre-commit hook PASSED on the squash-merge commit (DIA-094 docker gate respected; poetry-dev Up, docker compose ps evidence recorded before merge).
- Two-axis review: 0 Spec, 2 Minor (fixed + re-verified closed, cycle 1/2); ai-auditor independent audit APPROVE.
- ASCII-only (DIA-079); LOCAL-ONLY (no push, no remote ops).
