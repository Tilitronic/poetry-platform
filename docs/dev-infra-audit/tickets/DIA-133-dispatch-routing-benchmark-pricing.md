# DIA-133 - data-driven dispatch routing: orchestrator selects lane by model benchmarks + pricing + quota

<!-- UPDATE 2026-08-13 (IMPLEMENTED + AUDITED + CLOSED): ADR-DIA-133 implemented per developer-approved design (2026-08-13). Deliverables: (1) knowledge/model-registry.yaml - 7 models (deepseek-v4-flash coder-default 0.14/0.28/158150/73.7 res013; qwen3.7-plus arch/analyzer 0.40/1.60/21600/77.7 res016; kimi-k3 coder-escalated 3.00/15.00/490/93.40 res016 fallback[deepseek-v4-pro,mimo-v2.5-pro] binding cap 490; gpt-5.6-luna analyzer-escalated 0.20/1.20/10250/swe_bench_verified:null subagent-weak; deepseek-v4-pro fallback 0.435/0.87/17150/74.0 CAISI res017; mimo-v2.5-pro fallback-2 0.435/0.87/16300/null benchmark-gap-OPEN; gpt-5.3-codex reviewer 1.75/14.00/req_per_month:null Copilot-skip) + routing_table 10 entries (Rung0-4 + Rung3-fallback/-2 + Analyzer/Analyzer-escalated/Analyzer-route-back; quota_guarded on Rung3/Rung3-fallback/-2/Analyzer-escalated) - every score carries source_ref (res013/016/017), NO self-benchmark figures (ana014), nulls per developer decision; (2) NEXT-RUN.md section 2 appended '### Dispatch Routing & Quota Guard' (warn 80%, hard-stop count+1>cap -> fallback[]/wait_for_user, SILENT_FAILURE check before re-dispatch, skip Copilot-credit lanes); (3) oh-my-opencode-slim.jsonc append-only pointer in both escalated-lane prompts (coder-escalated L593, analyzer-escalated L596), NO trigger text removed. Validation: python3+PyYAML YAML OK (7x11 fields + 10 rows verbatim vs design); make test-config exit 0. ai-auditor (ai--3) CONFORMANT-WITH-NOTES; developer disposition ACCEPT. Registry owner: ai-specialist research -> coder edit (developer decision). RESTART-VERIFY PENDING next opencode launch (DIA-123 pattern): confirm prompts load the pointer and orchestrator consults the registry on escalated dispatch. Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.

     COUNTING CONVENTION (2026-08-13): registry.jsonl session_spawn rows lack a model_id field. The quota-guard counts by lane/model via task/agent correlation (the dispatch's subagent_type + session model attribution) OR the orchestrator records the model in the dispatch justification when the row lacks it. If model attribution is unavailable in a row, treat the lane's count as approximate and prefer the fallback[] chain on close-to-cap conditions. A future plugin enhancement (DIA-098 G2 / DIA-135 pipeline) may add model_id to session_spawn rows.

     Filed 2026-08-13 by developer request ("improve the workflow so the
     orchestrator, based on model benchmarks and prices, can choose whom to
     dispatch"). Builds on the DIA-111/DIA-108 escalation work (res013/res014/
     res016/res017/ana014). Current state: escalation lanes exist (coder-escalated
     kimi-k3, analyzer-escalated gpt-5.6-luna) but their dispatch triggers are
     HARDCODED in the orchestratorPrompt (2 failed re-review loops / Critical
     severity / cannot-comprehend-domain). Goal: make dispatch selection
     data-driven via a machine-readable model registry (benchmarks + prices +
     monthly quotas) plus a codified signal-to-lane policy, with a mechanical
     quota guard before expensive escalated dispatches.

     RESEARCH WORKFLOW REQUIREMENT (MANDATORY): this topic REQUIRES a
     research-first workflow. The routing policy and registry must be grounded
     in archived benchmark/pricing evidence, not invented numbers. Evidence
     already archived: res013 (pricing/limits), res014 (Rung0-4 ladder + 6
     routing patterns), res016 (kimi-k3 93.4% SWE-V, 490 req/mo cap),
     res017 (independent Rung-3 reproductions), ana014 (live benchmark
     CANCELLED by developer directive 2026-08-12 - no self-benchmarking).
     Developer decisions (2026-08-13): (1) mechanism = registry + codified
     policy in prompt (no plugin/tool); (2) signals = workflow signals + quota
     only (orchestrator cannot read repo files); (3) quota-guard = yes, consult
     registry.jsonl before escalated dispatch; (4) process = DIA ticket +
     section-10 chain. Constraints verified: dynamic model routing does not
     exist in OpenCode (#18644 closed-not-planned; #14961 auto-closed);
     orchestrator has no bash and reads only .opencode/session/*, tickets/*,
     NEXT-RUN.md, AGENTS.md, practice-protected.md; no native per-agent
     timeout / empty-result handling (res020/DIA-132). -->

---

id: DIA-133
title: "data-driven dispatch routing: orchestrator selects lane by model benchmarks + pricing + quota"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # no blocking dependency; follows DIA-111 (CLOSED) research
discovered: 2026-08-13
source: owner-reported
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_004588397ffeAJPNbTPqHxprJU"
lane_id: "build"
agent: "build"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-133-dispatch-routing-benchmark-pricing.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: []

---

## Description

The orchestrator currently dispatches escalation lanes via HARDCODED trigger
conditions embedded in the orchestratorPrompt (oh-my-opencode-slim.jsonc lines
593, 596): coder-escalated fires on "2 consecutive failed re-review loops" or
"Critical severity findings"; analyzer-escalated fires on "cannot comprehend
domain" or abort-on-complexity. The model choice per rung is fixed and the
quota facts (kimi-k3 490 req/mo, gpt-5.6-luna 10,250 req/mo) live only in
prose, not in a machine-readable form the orchestrator can consult.

Goal: turn dispatch selection into a data-driven decision. The orchestrator
should be able to justify "dispatch lane X with model Y" from a single
authoritative registry of model capabilities (benchmarks), prices, and monthly
quotas, and to mechanically refuse an escalated dispatch when the monthly
quota is exhausted (fallback or wait_for_user instead).

Why it matters:

1. **Cost/quality control:** without a registry, a future model swap or price
   change requires editing prose prompts in 3 presets; the registry makes the
   model facts a single source of truth with evidence citations.
2. **Quota protection:** kimi-k3 (490 req/mo) has already been consumed by
   ONE-SHOT dispatches; a mechanical quota guard prevents blind re-dispatch
   when the cap is near (DIA-132 silent-failure context).
3. **Auditability:** every escalated dispatch becomes explainable (benchmark
   score + price + quota check), consistent with the evidence-based workflow
   mandated by DIA-086/ana012.

### Research-first workflow (REQUIRED by this topic)

This ticket MUST follow the research workflow before any config change:

1. **Evidence grounding:** every benchmark score and price in the registry MUST
   carry a `source` reference (res013 / res016 / res017). No invented figures.
   Per ana014 developer directive (2026-08-12): NO self-benchmarking; only
   authoritative external evidence.
2. **Section-10 gate:** this is an opencode-config change (AGENTS.md section
   2.5 + section 10). Phase 1 gate = @ai-specialist research (read-only) on
   whether the registry + policy + quota-guard design conforms to
   opencode-best-practices; findings registered in
   .opencode/learnings/external-patterns/ before implementation.
3. **Design phase:** non-trivial change (3+ files) - @architector or
   @openspec-plan produces the detailed design (registry schema, policy table,
   quota threshold semantics, read-scope glob semantics).
4. **Independent review:** Phase 6 = @ai-auditor (read-only) per the
   config-review matrix; then CHANGELOG + learnings registration.

### Verified constraints

- Dynamic model routing does NOT exist in OpenCode: issue #18644
  (chat.model hook / active-model state) closed as not-planned; PR #14961
  (model param on Task tool) auto-closed 2026-04-26. Mechanism stays:
  static lanes with pinned models + orchestrator picks the lane by policy.
- Orchestrator has no bash (by design) and its read scope is limited to
  .opencode/session/_, docs/dev-infra-audit/NEXT-RUN.md,
  docs/dev-infra-audit/tickets/_ (+archive), AGENTS.md,
  .opencode/practice-protected.md (3 preset prompts + opencode.jsonc).
  The registry file must be added to this readable set (read-scope change).
- No native per-agent wall-clock timeout / empty-result handling
  (res020, DIA-132 Tier 1 only implemented: "steps": 50). The quota guard
  is orchestrator-side, not plugin-side.

### Planned artifacts (design sketch, detailed in the design phase)

- **A1** `.opencode/model-registry.yaml` - per-model: role, price_in/out
  ($/1M Go), req_per_month cap, swe_bench_verified + tb21 (+ source refs),
  lane, fallback[], notes. Evidence from res013/016/017; missing independent
  reproduction flagged as vendor-only/null (e.g. mimo-v2.5-pro).
- **A2** `orchestrator_append.md` "Dispatch Routing" section - Rung0-4
  signal-to-lane table (res014 section 4, updated by res016/017):
  Rung0 coder/deepseek-v4-flash (start, routine) / Rung1 coder retry
  (verify-fail #1, Minor finding) / Rung2 coder+qwen3.7-plus (verify-fail #2)
  / Rung3 coder-escalated/kimi-k3 (2x failed re-review OR Critical, quota-
  guarded) / Rung4 reviewer re-review (gpt-5.3-codex). Analyzer:
  qwen3.7-plus -> gpt-5.6-luna on cannot-comprehend -> route-back.
  Plus DIA-132 lesson: check registry.jsonl for SILENT_FAILURE of the lane
  before re-dispatching it.
- **A3** Quota-guard procedure (text in policy): count lane dispatches in
  messages.jsonl for the current calendar month before escalated dispatch;
  if count+1 > cap -> fallback per fallback[] or wait_for_user; warn at 80%.
- **A4** Read-scope change in .opencode/opencode.jsonc to make the registry
  readable by the orchestrator (glob semantics verified at implementation).

## Verification

1. `make test-config` exit 0 (validate-agent-names + config validation).
2. Registry is valid YAML; every benchmark score has a `source` field;
   no self-benchmarking figures (ana014 directive).
3. Restart-verify (DIA-123 pattern): after restart, orchestrator can read
   the registry and demonstrates a dispatch justification (lane + benchmark +
   price + quota check) in its summary when dispatching an escalated lane.
4. Quota-guard: with a simulated exhausted cap, the orchestrator does NOT
   dispatch the escalated lane and instead uses fallback[] or wait_for_user.
5. ASCII-only ticket/report text (DIA-079).

Implementation + audit closure checklist:

- [x] Research + design complete (res-4 + res023 conspect + arc-1 ADR-DIA-133, EBDV per DIA-115)
- [x] Registry implemented (7 models, routing_table, source_ref on every score, no self-benchmark, nulls per developer approval)
- [x] Quota-guard policy text in NEXT-RUN.md section 2 (warn 80% / hard-stop / SILENT_FAILURE check / Copilot-skip)
- [x] Orchestrator prompt pointer appended (append-only, no trigger text removed)
- [x] make test-config exit 0; registry YAML valid
- [x] ai-auditor CONFORMANT-WITH-NOTES; developer disposition ACCEPT
- [ ] restart-verify pending next launch (DIA-123)

## Fix

FIX COMPLETE 2026-08-13: ADR-DIA-133 implemented (registry + routing table + procedural quota-guard + prompt pointer). Registry owner: ai-specialist -> coder.

## Re-verify

RE-VERIFY PASS 2026-08-13 (implementation + config validation + independent audit). RESTART-VERIFY PENDING next opencode launch per DIA-123 pattern (prompt/config load + orchestrator registry consult on escalated dispatch).

### Open question (next actions, tracked by this ticket)

- Registry schema details and exact model set (deepseek-v4-flash,
  deepseek-v4-pro, qwen3.7-plus, kimi-k3, gpt-5.6-luna, mimo-v2.5-pro,
  gpt-5.3-codex) - resolved in the design phase from res013/016/017.
- Read-scope glob semantics for the registry path - verified at
  implementation + restart-verify (DIA-096 merge-semantics pattern).
- Quota counting source: messages.jsonl (has lane_id) vs registry.jsonl
  (has dispatch_state) - decided in design phase.
