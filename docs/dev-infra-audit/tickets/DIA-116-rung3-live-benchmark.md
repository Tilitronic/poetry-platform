# DIA-116 - live in-repo Rung-3 benchmark: kimi-k3 vs deepseek-v4-pro vs mimo-v2.5-pro (DIA-111/DIA-114 follow-up)

<!-- Filed 2026-08-12 by docs lane (session 15 autonomous batch). Follow-up
     ticket for the DIA-114 (CLOSED) Rung-3 verdict caveat: "BOTH headline SWE
     scores are vendor-reported, not independently reproduced. A live in-repo
     benchmark is recommended before finalizing Rung 3." Also follows the
     DIA-111 (OPEN) assignment of opencode-go/kimi-k3 to the coder-escalated
     agent (490 req/mo cap). Session-15 developer decision (d): 'Benchmark
     first' - open a ticket for a live in-repo benchmark before Rung 3 is
     finalized. -->

---

id: DIA-116
title: "live in-repo Rung-3 benchmark: kimi-k3 vs deepseek-v4-pro vs mimo-v2.5-pro (DIA-111/DIA-114 follow-up)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: owner-authorized (session 15 decision 'benchmark first')
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00ab443d4ffewdS8K6h32j0JgF"
lane_id: "docs"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-116-rung3-live-benchmark.md"]
artifacts: []
evidence: []

---

## Description

- DIA-114 (CLOSED 2026-08-12) recommended mimo-v2.5-pro as the coder-ladder
  Rung-3 default but with an explicit CAVEAT: 'BOTH headline SWE scores are
  vendor-reported, not independently reproduced. A live in-repo benchmark is
  recommended before finalizing Rung 3.' DIA-111 (OPEN) assigned
  opencode-go/kimi-k3 to the new coder-escalated agent (490 req/mo cap) with
  cap-fallback to deepseek-v4-pro / mimo-v2.5-pro.
- Session-15 developer decision (d): 'Benchmark first' - open a ticket for a
  live in-repo benchmark before Rung 3 is finalized.
- Purpose: run a REAL task-based benchmark inside this repo (poetry-platform)
  comparing the three Rung-3/escalation candidates (opencode-go/kimi-k3,
  opencode-go/deepseek-v4-pro, opencode-go/mimo-v2.5-pro) on actual project
  tasks, replacing or corroborating vendor-reported scores with in-repo
  evidence.
- Budget note: kimi-k3 has a 490 req/mo Go cap - the benchmark must use minimal
  request counts per model (design the tasks to fit within the cap; prefer a
  small set of representative tasks over a large sweep).

blocked_by note: DIA-114 is CLOSED (the section-10 ticket gate resolves explicit
DIA-ids only against OPEN tickets), so this follow-up is tracked as its own OPEN
ticket; it follows the DIA-114 CLOSED verdict caveat rather than being gated by
it.

Why it matters: the coder escalation ladder Rung 3 (DIA-111) and the
coder-escalated agent default (DIA-111 / DIA-114) are currently based on
vendor-reported scores only. Until this in-repo benchmark closes the gap, the
escalation design stays provisional. DIA-108 (optimal model assignment audit)
also depends on capability evidence for the models it recommends.

## Verification

- [ ] Benchmark protocol designed and documented in the ticket Fix section:
      task selection (real in-repo tasks representative of the escalation
      trigger - complex/advanced problem-fix), N tasks per model, evaluation
      rubric (pass/fail per task, time, tokens), request-count budget per model
      within caps (kimi-k3 490/mo; deepseek-v4-pro 17,150/mo; mimo-v2.5-pro
      16,300/mo).
- [ ] Benchmark executed via OpenCode task() dispatch of each candidate model
      (per-dispatch override not supported - use agent-definition model swaps
      or dedicated benchmark agent variants; note the DIA-111 probe
      constraint).
- [ ] Results table recorded: per-model pass rate, qualitative notes,
      request/token usage.
- [ ] Verdict recorded: final Rung-3 / escalation default for coder-escalated
      cap-fallback, citing the benchmark evidence.
- [ ] If config change is recommended as a result, route through the
      section-10 chain.
- [ ] DIA-111 and DIA-114 updated with the benchmark verdict cross-reference.

## Fix: Independent benchmark evidence for Rung-3 candidates (DIA-116)

APPROACH CHANGE (developer directive 2026-08-12): the planned live in-repo
benchmark was CANCELLED - self-benchmarking the dispatch models was rejected
in favor of authoritative third-party sources. Evidence gap closed via
knowledge/res017-rung3-benchmark-evidence/ (res017 conspect, 2026-08-12;
21 archived sources, 1 failure: llm-stats.com blocked by anti-bot wall -
impact none, TB 2.1 covered by benchmarklist/AA archives; DIA-072 excluded
claims listed in conspect Section 7). The res016/r015/r014 conspects and
ana014 protocol draft are superseded as the decision basis by res017.

Per-candidate independent evidence:

- kimi-k3 SWE-bench Verified 93.40% - Vals AI mini-swe-agent bash-only
  harness, leaderboard updated 2026-08-08, strongest open-weight model
  (ahead of Opus 4.8 88.60% and Grok 4.5 86.60%). This is the independent
  reproduction DIA-114 flagged as missing; it now exists and is archived.
  AA Intelligence Index 57.11-60 (independent). Terminal-Bench 2.1:
  88.3% vendor (Kimi Code harness, flagged vendor) / 85.0% AA-run
  (Terminus 2, II v4.1.1 component) / 80.9% Vals harness.
- deepseek-v4-pro SWE-bench Verified 74% - NIST CAISI (U.S. government),
  Inspect ReAct, 2026-05-01, IRT Elo 800; vendor 80.6% flagged
  "Unverified" on evals.report. AA Intelligence Index 45 (independent).
- mimo-v2.5-pro NO independent coding-benchmark reproduction exists -
  78.9% headline is vendor-only (Xiaomi model card / mimo.xiaomi.com,
  confirmed by evals.report, llmreference, The Decoder). Only independent
  datum: AA Intelligence Index 43 (composite).

VERDICT (res017):

- KEEP kimi-k3 as coder-escalated default - only candidate with an
  independent reproduction of its headline coding benchmark; leads every
  comparable archived benchmark (SWE-V +19.4 vs CAISI 74, AA II +15/+17,
  Vals TB 2.1 +8.8/+23.6). Binding constraint unchanged: 490 req/mo at
  $3/$15 on Go (sparing escalation tier).
- Rung-3 fallback: PREFER deepseek-v4-pro over mimo-v2.5-pro (REVERSES the
  DIA-114 provisional MiMo pick): deepseek has the CAISI independent
  evaluation; mimo has none; AA II 45 vs 43; Vals TB 2.1 72.1% vs 57.3%;
  cost identical ($0.435/$0.87, ~16-17K req/mo both).
- Cap note: kimi-k3 ~13x pricier per token (~$2.31/M AA blended vs
  $0.18/M co-candidates).
- No config change required: coder-escalated already = kimi-k3 (b0b3c76);
  fallback remains developer-gated per orchestrator rules.

Evidence: knowledge/res017-rung3-benchmark-evidence/
res017-rung3-benchmark-evidence-conspect.md (registered in
.opencode/memory-shelf.yaml lines 79-82).

Cross-references: DIA-111 and DIA-114 updated with this verdict (2026-08-12).

## Re-verify

> To be filled at re-verify time.
