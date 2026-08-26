# cebula-openai-hy3 variant-priority tuning gate findings (DIA-260826-spu5, ai-specialist section-2.5 gate)

Source: ai-specialist gate review ses_fc16ca273ffe3Qj67HX19uIwcM, 2026-08-26.

1. F1: OMO "variant" = reasoning effort (low/medium/high), NOT the thinking toggle (res021 correction). Effort table: low = execution coding, medium = agentic coding / research / delegation (default), high = hard reasoning / complex debugging / security, xhigh = security + code review. res021: medium beats high on code by 3-5pp (over-thinking regression).
2. F2: opencode-go/hy3 on Go: $0.14 / $0.58 per 1M tokens, $60 bucket, 4,300 req / 5h, 21,500 req / mo, 256K ctx (res030). Quota parity with qwen3.7-plus (21,600 req / mo).
3. F3: review-diversity collision: coder primary hy3 vs reviewer primary hy3 = same model ID, violates ai-assist-sources.yaml:245 ("reviewer must be different model family than coder"). Developer consciously overrode: same model + HIGHER reasoning effort (reviewer variant high vs coder medium) accepted as sufficient; big-pickle fallback retained for episodic family diversity (res029: fallbacks activate on error signals only). Documented override recorded in ticket DIA-260826-spu5.
4. F4: model-registry Rung4 routes reviewer -> gpt-5.3-codex (Copilot credits) as guidance, not a hard preset constraint.
5. F5: analyzer-escalated stays variant high (developer decision; lowering would contradict its hard-reasoning escalation purpose).
6. Gate verdict: APPROVE-WITH-CAVEATS; caveats resolved by developer decisions above.

Outcome: APPLIED 2026-08-26, ticket DIA-260826-spu5, committed, CHANGELOG entry added.

CAVEATS (recorded 2026-08-26, review rev-1): (F1) big-pickle fallback provides family diversity ONLY on error signals (res029), so in steady state reviewer and coder share the hy3 model family - the review-diversity rule (ai-assist-sources.yaml:245) is consciously overridden in steady state, not just on fallback. (F2) The variant-lowering evidence (res021: medium beats high on code by 3-5pp) is coding-task evidence applied to non-coding agents (orchestrator, openspec-plan, conspecter, analyzer, ai-specialist, researcher); applicability to non-coding reasoning tasks is unverified and accepted as a conscious decision. Revisit if non-coding lanes show quality regression.
