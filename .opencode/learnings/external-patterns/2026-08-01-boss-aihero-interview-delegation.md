# Boss AIHero Interview-Delegation Alignment

- **date**: 2026-08-01
- **source**: @ai-specialist research (user request: restructure boss to strict AIHero-style workflow)
- **finding**: Boss prompt had 3 blockers + 2 majors vs the 5 AIHero-style requirements:
  1. BLOCKER: No mandatory interview gate — workflow starts with "Understand" → "Path Selection" → "Delegation Check", allowing boss to skip interview entirely and go straight to planning/delegation. (boss.ts:168-183)
  2. BLOCKER: Trivial-work escape hatch ("direct execution is allowed when scheduling overhead would clearly dominate") contradicts the "never write code" hard rule. (boss.ts:181)
  3. BLOCKER: HARD RULE in boss_append.md qualified as "dev-infra or config changes" only — not universal. (boss_append.md:29)
  4. MAJOR: @researcher and @analyzer are standalone lanes — boss can dispatch them as independent parallel work streams, not phased into interview/spec. (boss.ts:38-44, oh-my-opencode-slim.jsonc:485)
  5. MAJOR: OpenSpec cascade positioned at step 5 (after Plan & Parallelize at step 4), allowing implementation delegation before specs exist. (boss.ts:188-246)
  - Already aligned: @openspec-plan enforces vertical-slice tasks with blocking edges (prior AIHero pass).
- **applied** (recommended, pending user approval):
  - boss.ts: Remove trivial-work escape hatch, replace with "conversational answers only; any specialist work MUST be delegated"
  - boss.ts: Restructure workflow to AIHero-aligned phases: (1) Interview Gate → (2) Spec Generation → (3) Delegation Check → (4) Plan and Parallelize → (5) Verify
  - boss.ts: Modify @researcher description to mark it as interview/spec-phase tool, not standalone lane
  - boss_append.md: Strengthen HARD RULE to universal "no direct implementation or specialist work"
  - boss_append.md: Add Interview-First Gate section with explicit phasing rules for @researcher/@analyzer
  - oh-my-opencode-slim.jsonc: Update @openspec-plan orchestratorPrompt with research/analysis dispatch guidance (identify need → boss dispatches → feeds results back)
- **user refinement (2026-08-01, approved)**: Research remains a STANDALONE task when the user explicitly requests it (e.g. "research X library"). It is NOT restricted to interview/spec phases only. The rule is: ANY engineering work (features, implementation, bug fixes, refactors, config, dev-infra) the boss is asked for must be processed like any other engineering work — through the Interview Gate → Spec Generation → Delegation chain. Standalone user-requested research/analysis is dispatched directly to the matching specialist (@researcher / @analyzer), never performed by the boss itself.
- **status**: applied (verified 2026-08-01: config validates via validate-opencode-config.sh; boss.ts is pure prompt-string edit with preserved TS logic; bun test/build not runnable on this host — bun only exists in poetry-dev container)
- **schema constraint**: `orchestratorPrompt` is explicitly rejected for boss agent (schema.ts:285-290). Boss prompt customization limited to: boss_append.md (append), boss.md (full replacement), or boss.ts (source edit).
- **existing machinery audit**:
  - feature-interviewer skill: exists in OMO source (263 lines, 4-phase interview), NOT wired in any preset, was consolidated into @openspec-plan in prior AIHero pass. Do NOT re-introduce.
  - grill-with-docs skill: exists in OMO source (88 lines), NOT wired in any preset. Not needed.
  - /interview module: browser-UI interview system (19 files). Separate from agent workflow. Not relevant.
- **status**: proposed (pending user review and approval before implementation)
- **AIHero reference**: mattpocock/skills engineering chain: grill-with-docs → to-spec → to-tickets → implement → code-review. The boss restructuring maps to: interview (grill-with-docs) → spec (to-spec) → vertical tasks (to-tickets) → delegate (implement) → verify (code-review). Source: https://github.com/mattpocock/skills, https://www.aihero.dev/
