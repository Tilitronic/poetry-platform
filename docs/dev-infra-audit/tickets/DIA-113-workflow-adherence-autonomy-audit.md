# DIA-113 — audit workflow-adherence discipline + agentic autonomy configuration

<!-- Filed 2026-08-12 by developer request. Cross-cutting audit: how strictly,
     deterministically, reliably agents (esp. orchestrator) follow the project's
     defined workflows, how the developer is engaged as owner in key decisions,
     how reliable the verification loop is, and how well the agentic loop /
     autonomy is configured — with recommendations grounded in newest best
     practices. Extends DIA-080/086/097/098/099/102/104. -->

---

id: DIA-113
title: "audit workflow-adherence discipline + agentic autonomy configuration vs newest best practices"
area: opencode-config
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-12
source: fix-lane
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-113-workflow-adherence-autonomy-audit.md"]
artifacts: []
evidence: []

---

## Description

Audit how strictly, deterministically, and reliably agents — especially the
orchestrator — follow the project's defined workflows, and how the agentic
loop / autonomy is configured, then recommend concrete adjustments grounded in
newest best practices and approaches.

### Investigation requirements

1. **Workflow-adherence discipline.** Enumerate every defined workflow and its
   enforcement point: feature chain (§2, openspec → coder → reviewer), §2.3.1
   fix → re-review loop (max 2 cycles), §10 AI-devtools modernization gate
   (ai-specialist → user decides → §10 Phase 5 restart-verify), tdd-craftsman,
   persistence loop, research pipeline. Assess from session evidence
   (messages.jsonl / registry.jsonl, ticket ledger, learnings) how
   strictly/deterministically agents follow them vs. improvise.
2. **Developer as owner.** Audit engagement of the developer in key decisions:
   practice-protected zones (openspec authoring, TDD edge-cases, architector
   flags), §4 review-findings disposition, DIA-104 grilling gate (OPEN),
   domain-grilling interviews. How reliably is the developer engaged vs.
   agents self-deciding? Where do agent decisions silently pre-empt the owner?
3. **Verification-loop reliability.** Audit fix → re-verify → re-review
   reliability: verification evidence (exit codes + summary lines), gate
   outputs, DIA-107 re-verify pattern, reviewer verified-closed/still-open
   taxonomy. How often does verification actually prove the fix? Where does
   the loop silently degrade?
4. **Agentic loop / autonomy configuration.** Map current autonomy: permissions
   (task tool, bash delegation pattern, visibleTools), stop behavior
   (DIA-080 CLOSED, DIA-098 OPEN), auto-resume / stall detection, handoff-file
   mechanism (DIA-061 VERIFIED), job board, model tiering (DIA-087/108/111).
   Identify drift vs. intended state.
5. **Best-practice research (web-fresh, dated).** Collect current guidance on
   agentic-loop design, deterministic workflow enforcement, verification /
   checkpoint patterns, and developer-in-the-loop ownership (e.g., Anthropic
   agentic loop guidance, Claude Code hooks, OpenCode docs, OMO patterns).
6. **Deliverables.** Gap matrix + prioritized recommendations ("where and how
   to adjust"), each traced to a specific best-practice source; any proposed
   config change must be routed through §10 (ai-specialist → user decides).
   Findings registered per research-pipeline (conspect → memory shelf).

## Verification

- [ ] Every defined workflow enumerated with its enforcement point (config /
      skill / hook / gate / plugin).
- [ ] Orchestrator adherence assessed from session evidence with concrete
      strict vs. loose examples.
- [ ] Developer-as-owner engagement audited across practice-protected zones +
      findings disposition; gaps identified.
- [ ] Verification-loop reliability quantified from ticket ledger (re-verify
      evidence rate, cycle counts, closed-loop outcomes).
- [ ] Autonomy configuration mapped (permissions / stops / resume / stall /
      handoffs) with drift vs. intended state.
- [ ] Dated, web-verified best-practice sources archived and registered.
- [ ] Gap matrix + prioritized recommendations delivered; config-change
      candidates flagged for §10 routing.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
