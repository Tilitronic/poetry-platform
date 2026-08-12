# DIA-114 - evaluate MiMo-V2.5-Pro agentic coding capability (DIA-087 R5 follow-up)

<!-- Filed 2026-08-12 by docs lane (session 14 autonomous batch). Follow-up
     ticket for the DIA-087 R5 deferred work item: "MiMo evaluation QUEUED
     (deferred)". DIA-087 is CLOSED, so the section-10 ticket gate resolves
     explicit DIA-ids only against OPEN tickets; this OPEN ticket carries the
     deferred research so the gate can correlate the dispatch. -->

---

id: DIA-114
title: "evaluate MiMo-V2.5-Pro agentic coding capability (DIA-087 R5 follow-up)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-12
source: owner-authorized (session 14 autonomous batch)
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-114-mimo-v25-pro-evaluation.md", "knowledge/res015-mimo-v25-pro-evaluation/res015-mimo-v25-pro-evaluation-conspect.md", "knowledge/res015-mimo-v25-pro-evaluation/phase_a_report.txt", "knowledge/ana013-dia097-105-triage/ana013-dia097-105-triage-report.md", ".opencode/memory-shelf.yaml"]
artifacts: ["knowledge/res015-mimo-v25-pro-evaluation/ (conspect + phase_a_report; 32/32 sources archived, sources/ gitignored)", "knowledge/ana013-dia097-105-triage/ (triage report)"]
evidence: ["res015 conspect: knowledge/res015-mimo-v25-pro-evaluation/ (32/32 sources archived; shelf entry .opencode/memory-shelf.yaml lines 71-74)", "researcher lane ses_00b0ca6e2ffeqUeK54NxtnYk9x", "conspecter lane ses_00b0a3522ffeTq1jqbKymg30LN"]

---

## Description

Deferred work item from DIA-087 (CLOSED). DIA-087 R5 recorded: "MiMo
evaluation QUEUED (deferred) - Not enough evidence at audit time". The
Re-verify section of DIA-087 explicitly states "R5 (MiMo) explicitly queued -
not silently dropped", so this research is a required follow-up, now tracked
as its own OPEN ticket.

Background (from res013-opencode-model-pricing-audit, archived 2026-08-12):

- MiMo-V2.5-Pro is confirmed available on Go (opencode-go provider) at
  $0.435/$1M input and $0.87/$1M output with roughly 16,300 req/mo included.
- NO archived SWE-bench or agentic-coding capability score exists for
  MiMo-V2.5-Pro -- this is a benchmark gap. Availability and pricing are
  known; capability is not.
- The coder escalation ladder Rung 3 in res014 / DIA-111 is
  "deepseek-v4-pro OR mimo-v2.5-pro" -- the choice between the two depends
  on this evaluation.

Why it matters: DIA-111 (coder/analyzer escalation routing) names MiMo-V2.5-Pro
as a co-candidate at Rung 3, but there is no evidence today to justify picking
it over deepseek-v4-pro. The escalation design stays provisional until this
benchmark gap is closed. DIA-108 (optimal model assignment audit) also depends
on capability evidence for the models it recommends.

## Verification

Evidence checklist (research lane, source-cited):

- [x] Benchmark evidence from official Xiaomi / HuggingFace / Vals / BenchLM
      sources: SWE-bench (SWE-bench Verified and/or Full), HumanEval /
      LiveCodeBench, and any agentic-coding leaderboards (e.g. Aider
      polyglot, Terminal-Bench, OSWorld) for MiMo-V2.5-Pro. Record raw
      numbers, date, and source URLs.
- [x] Agentic-coding usage evidence: documented tool-calling / agent-loop
      usage of MiMo-V2.5-Pro (function calling, tool use in coding agents,
      long-context behavior). Record source URLs.
- [x] OpenCode / Go community usage evidence: any reports of MiMo-V2.5-Pro
      used through OpenCode or the Go provider (issues, discussions,
      community benchmarks). Record source URLs.
- [x] Comparison vs DeepSeek V4 Pro at identical pricing: both models sit at
      $0.435/$0.87 on Go; compare capability scores side by side to support
      the DIA-111 Rung 3 decision.
- [x] Decision recorded: recommend mimo-v2.5-pro or deepseek-v4-pro for
      Rung 3 of the coder escalation ladder, with the evidence cited.

## Fix

RUNG-3 VERDICT (2026-08-12): recommend **mimo-v2.5-pro** as the default for
coder-ladder Rung 3 (resolves the DIA-111 Rung 3 co-candidate choice).

MiMo-V2.5-Pro edges over deepseek-v4-pro (leaderboard/vendor-reported):

- Terminal-Bench 2.0: 68.4 vs 65.4
- SWE-bench Pro: 57.2 vs 55.4
- GDPVal-AA Elo: 1581 vs ~1554
- ~40-60% fewer tokens per trajectory (cost/efficiency advantage at the
  identical $0.435/$0.87 per-M tokens Go pricing)
- Explicit first-party OpenCode / Go provider support

deepseek-v4-pro retains the reasoning edge:

- GPQA-Diamond: 90.1 vs 86.6
- SWE-bench Verified: 80.6 vs 78.9

CAVEAT: BOTH headline SWE scores are vendor-reported, not independently
reproduced. A live in-repo benchmark is recommended before finalizing
Rung 3, per the DIA-114 verification checklist. See res015 conspect for the
full side-by-side and source URLs.

## Re-verify

RE-VERIFY EVIDENCE (2026-08-12):

- res015 conspect: knowledge/res015-mimo-v25-pro-evaluation/
  (res015-mimo-v25-pro-evaluation-conspect.md + phase_a_report.txt;
  32/32 sources archived; sources/ subdir gitignored per .gitignore:45)
- shelf.conspects entry "MiMo-V2.5-Pro Agentic Coding Evaluation (DIA-114)":
  .opencode/memory-shelf.yaml lines 71-74
- researcher lane: ses_00b0ca6e2ffeqUeK54NxtnYk9x
- conspecter lane: ses_00b0a3522ffeTq1jqbKymg30LN
- Parallel ana013 triage group (same batch): knowledge/ana013-dia097-105-triage/
  (ana013-dia097-105-triage-report.md)

## Rung-3 verdict update (2026-08-12): provisional MiMo pick SUPERSEDED by res017 - independent evidence (NIST CAISI for deepseek-v4-pro 74%; NO independent reproduction for mimo-v2.5-pro) reverses the fallback preference to deepseek-v4-pro > mimo-v2.5-pro. kimi-k3 confirmed default (Vals AI 93.4% independent). See DIA-116 Fix section.

---

## References

- DIA-087 R5 (deferred MiMo evaluation): docs/dev-infra-audit/tickets/DIA-087-agent-model-variant-audit.md
- DIA-111 (coder/analyzer escalation routing, Rung 3 co-candidate):
  docs/dev-infra-audit/tickets/DIA-111-coder-analyzer-model-escalation.md
- DIA-108 (optimal model assignment audit):
  docs/dev-infra-audit/tickets/DIA-108-optimal-model-assignment-audit.md
