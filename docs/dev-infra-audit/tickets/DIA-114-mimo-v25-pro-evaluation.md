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
status: OPEN
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-114-mimo-v25-pro-evaluation.md"]
artifacts: []
evidence: []

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

- [ ] Benchmark evidence from official Xiaomi / HuggingFace / Vals / BenchLM
      sources: SWE-bench (SWE-bench Verified and/or Full), HumanEval /
      LiveCodeBench, and any agentic-coding leaderboards (e.g. Aider
      polyglot, Terminal-Bench, OSWorld) for MiMo-V2.5-Pro. Record raw
      numbers, date, and source URLs.
- [ ] Agentic-coding usage evidence: documented tool-calling / agent-loop
      usage of MiMo-V2.5-Pro (function calling, tool use in coding agents,
      long-context behavior). Record source URLs.
- [ ] OpenCode / Go community usage evidence: any reports of MiMo-V2.5-Pro
      used through OpenCode or the Go provider (issues, discussions,
      community benchmarks). Record source URLs.
- [ ] Comparison vs DeepSeek V4 Pro at identical pricing: both models sit at
      $0.435/$0.87 on Go; compare capability scores side by side to support
      the DIA-111 Rung 3 decision.
- [ ] Decision recorded: recommend mimo-v2.5-pro or deepseek-v4-pro for
      Rung 3 of the coder escalation ladder, with the evidence cited.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

---

## References

- DIA-087 R5 (deferred MiMo evaluation): docs/dev-infra-audit/tickets/DIA-087-agent-model-variant-audit.md
- DIA-111 (coder/analyzer escalation routing, Rung 3 co-candidate):
  docs/dev-infra-audit/tickets/DIA-111-coder-analyzer-model-escalation.md
- DIA-108 (optimal model assignment audit):
  docs/dev-infra-audit/tickets/DIA-108-optimal-model-assignment-audit.md
