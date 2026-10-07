# Pattern: 2026-08-03 — Anthropic verification loop → reviewing stage (gate findings)

> §10 config-change workflow record (global AGENTS.md §10 Phase 1 — orchestrator-registered GATE pre-change research; read-only; §10 Phase 2 owner decision pending).

## Source

- **Claude Code Best Practices** (https://code.claude.com/docs/en/best-practices):
  - "Give Claude a way to verify its work" — evidence-over-assertion; verification subagent gets fresh context ("the agent doing the work isn't the one grading it").
  - 4 gating strategies: in-prompt evaluation / `/goal` evaluator / Stop-hook deterministic gate (8-block override) / verification subagent.
  - Adversarial fresh-context diff review; trust-then-verify gap.
- **Building Effective Agents** (https://www.anthropic.com/engineering/building-effective-agents): evaluator-optimizer workflow; ground truth comes from the environment; stopping conditions / max iterations bound the loop.
- **Boris Cherny "Loop Engineering"** (2026-06): "self-evaluation is a trap"; worker ≠ judge; generator-evaluator contract negotiation; canonical definition of the verification loop.
- **Multi-Agent Research System** (https://www.anthropic.com/engineering/multi-agent-research-system): LLM-as-judge with rubric; deterministic retry + checkpoints.

## Canonical loop (synthesized)

- **plan → implement → verify → fix → re-verify**; independent verifier with its own fresh context.
- Deterministic ground truth (tests / lint / build exit code) is the final arbiter; evidence over assertion.
- Bounded iteration cap; state persistence across cycles; human disposition points; generator-evaluator contract negotiation.

## Gap analysis (vs. our reviewing stage)

- **Reviewer is read-only pure analyst (bash:deny)** — CANNOT run tests; relies on coder self-report; no deterministic ground truth.
- **NO fix → re-verify → re-review loop** — verified across 4 campaigns (dia-redispatch-cycle, mattpocock skills, T1+T3, test-skills-gate): fixes applied, then straight to memory-manager/commit.
- **No evidence requirement on coder handoff**; only 3-failures escalation inside the coder lane, no inter-lane fix-review cap.

## Recommended package

- **Phase 1 (LOW risk — prompt/workflow only)**:
  - O1: fix→re-verify→re-review loop with cap 2 + findings-resolution table (verified-closed | still-open | partial).
  - O2: verification-evidence requirement in coder handoff.
  - O5: coder self-verification checklist.
  - O6: reviewer verified-closed evidence format.
- **Phase 2 (MODERATE)**: O3 reviewer bash allowlist for test/lint/typecheck (practice-protected reclassification).
- **Phase 3 (MODERATE)**: O4 Stop-hook test gate.
- **Phase 1 files**: AGENTS.md §2.3.x + oh-my-opencode-slim.jsonc reviewer+coder orchestratorPrompt (~600ch delta); no permission changes; git-revertible rollback.

## Outcome

- **ADOPTED** 2026-08-03 — §10 Phase 1–6 complete. Phase 1 (O1/O2/O5/O6) implemented per architector design: fix→re-verify→re-review loop (cap 2 cycles) in AGENTS.md §2.3.1; targeted re-review protocol in NEW skill .opencode/skills/review-re-verify/SKILL.md; coder pre-handoff verification checklist + evidence requirement (coder prompt ×3 presets); reviewer VERIFICATION EVIDENCE + RE-REVIEW MODE sections (orchestratorPrompt); orchestrator_append review-gate cross-ref. ai-specialist independent review APPROVE-WITH-CHANGES (1 Minor tool-limitation, 1 Suggestion). Reviewer stays read-only (bash:deny) — verification loop automates re-verification, practice-protected §4 disposition authority preserved. Phase 2 (O3 reviewer bash allowlist) + Phase 3 (O4 Stop hook) deferred to separate §10 campaigns.

- **Known prompt-budget note** (ai--2 Suggestion): coder prompt actual length = 1068 decoded chars (spec estimated ≤1000); reviewer orchestratorPrompt = 3658ch (pre-existing overrun ~3323 accepted). Compress prompts before Phase 2/3 additions.

## Addendum 2026-08-03 — Context-fork research + review-loop audit

**Terminology correction:** "context fork" (community shorthand) ≠ Claude Code "fork". A Claude Code fork (/subtask, Agent fork type) INHERITS the parent's full conversation — the OPPOSITE of what verification needs. Anthropic's recommended pattern is the named subagent with FRESH, ISOLATED context window (code.claude.com/docs/en/sub-agents: "Each subagent starts with a fresh, isolated context window... The exception is a fork, which inherits the parent conversation").

**Why Anthropic recommends fresh-context verification:** "the agent doing the work isn't the one grading it"; "sees only the diff and the criteria you give it, not the reasoning that produced the change" (Claude Code Best Practices); "self-evaluation is a trap... use a separate adversarial evaluator with its own context window" (Boris Cherny, Loop Engineering). Pass to verifier: diff, criteria/rubric, fixed point, spec, prior findings (re-review), coder's evidence (exit codes), cycle counter. EXCLUDE: builder's chain-of-thought, failed attempts, self-justifications, parent conversation. Each re-review = FRESH invocation, never resume (resume accumulates narrative → contaminates independence).

**Audit of our loop:** ALIGNED — each @reviewer dispatch is a fresh subagent instance (task(), not resume); re-review re-dispatches fresh (AGENTS.md §2.3.1); orchestrator forwards evidence+summary, not coder's reasoning. 11/11 alignment (partial only on deterministic ground truth = Phase 2 O3 deferred).

**Gaps identified:** G1 teaching skill in reviewer (mentoring posture anchors evaluation); G2 reflect skill (self-referential anchoring); G3 playwright-browser (irrelevant bloat); G4 coder fixes-applied summary is narrative not structured diff-like; G5 reviewer bash:deny (deferred O3); G7 book-rag (optional). Options: A (remove teaching/reflect/playwright-browser from reviewer skills ×3 presets) + C (explicit fresh-context instruction in reviewer prompt) = immediate before-commit; B (structured fixes-applied summary) = follow-up campaign. Status: APPLIED 2026-08-03 — owner approved Option A+C (reviewer skills cleanup + FRESH-CONTEXT EVALUATION prompt section); ai-specialist APPROVE; Option B deferred; O3/O4 remain deferred.
