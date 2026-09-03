# DIA-113 — audit workflow-adherence discipline + agentic autonomy configuration

<!-- UPDATE 2026-08-13 (AUDIT COMPLETE + TICKET CLOSED): all 6 investigation requirements satisfied. #4/#5 done by ai-specialist (ai--1: C7 project config aligned with best practices - no drift; C8 --auto canonical overnight escape hatch). #1/#2/#3/#6 done by analyzer lane ana-2 (ses_0038a1611ffeMFnlv6Fh8f3Zaj), report: knowledge/ana015-workflow-adherence-audit/ana015-workflow-adherence-audit-report.md (registered memory-shelf analyses[15]). KEY FINDINGS: two-tier adherence - structural/plugin-enforced workflows STRONG, practice-protected/prompt-enforced WEAK-to-MODERATE. GAPS: G1 HIGH reviewer-disposition silent bypass (81% reviewer dispatches skip pending-owner); G2 HIGH re-verify evidence rate 51% (23/45 CLOSED concrete, 12 weak, 10 empty); G3 MEDIUM interview-first gate bypass ~30%; G4 MEDIUM TDD edge-case prioritization not visible; G5 MEDIUM @architector flags not enforced (0 dispatches); G6 LOW developer attestation UPDATE blocks 7%; G7 LOW re-review cycle counter visibility; G8 HIGH feature-chain bypass on implementation (526 coder dispatches). RECOMMENDATIONS: R1 HIGH reviewer-disposition pending-owner gate (S10 flag YES); R2 HIGH re-verify evidence checklist + scripts/validate-reverify.sh (S10 flag NO); R3 MEDIUM skip-spec flag on coder dispatches (S10 flag PARTIAL); R4 MEDIUM @architector activation pathway (S10 flag YES); R5 MEDIUM TDD edge-case surfacing M6 (S10 flag PARTIAL). VERIFICATION-LOOP: CLOSED 45, re-verify evidence 51%, cycle 1 ~80% / cycle 2 ~15% / >2 = 0 (cap respected), closed-after-re-review 93%. R1/R4/R5 are §10 config-change candidates - to be routed through the section-10 chain as follow-up tickets (NOT implemented here). Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.

     UPDATE 2026-08-13 (PARTIAL PROGRESS - AUTONOMY-CONFIG SLICE DONE, FULL AUDIT REMAINS): the combined DIA-126a+113 ai-specialist gate-research lane (ai--1, ses_004127c39ffeMbdgQtiWpE5qB3, web-fresh OpenCode docs) covered requirements #4 (autonomy configuration mapping) and #5 (best-practice research). Findings: (C7) project config is ALIGNED with current best practices - no drift detected: steps:50 on escalated lanes matches the documented Max-steps pattern, hidden lanes use hidden:true per docs, background subagents (OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS) correctly NOT used (native feature is experimental; project uses delegation-observer + task() tool), compaction auto/prune configured per standard anti-overflow practice. (C8) No dedicated autonomous-profile concept in OpenCode; --auto is the canonical unattended escape hatch (auto-approves ask-level, deny stays enforced). NOT covered by this slice: requirements #1 (enumerate every defined workflow + enforcement point), #2 (developer-as-owner engagement audit across practice-protected zones), #3 (verification-loop reliability quantification from ticket ledger: re-verify evidence rate, cycle counts), #6 (full gap matrix + prioritized recommendations + conspect registration). Status stays OPEN; completion requires a dedicated @analyzer audit lane (session-evidence analysis of messages.jsonl/registry.jsonl/ticket ledger + workflow enumeration + gap matrix), which the orchestrator has queued after the DIA-125 Ideas A/B research (per developer ordering 2026-08-13).

     Filed 2026-08-12 by developer request. Cross-cutting audit: how strictly,
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
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-13

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

- [x] Every defined workflow enumerated with its enforcement point (config /
      skill / hook / gate / plugin). (completed via ana-2 2026-08-13, see top UPDATE)
- [x] Orchestrator adherence assessed from session evidence with concrete
      strict vs. loose examples. (completed via ana-2 2026-08-13, see top UPDATE)
- [x] Developer-as-owner engagement audited across practice-protected zones +
      findings disposition; gaps identified. (completed via ana-2 2026-08-13, see top UPDATE)
- [x] Verification-loop reliability quantified from ticket ledger (re-verify
      evidence rate, cycle counts, closed-loop outcomes). (completed via ana-2 2026-08-13, see top UPDATE)
- [x] Autonomy configuration mapped (permissions / stops / resume / stall /
      handoffs) with drift vs. intended state. (completed via ai--1 2026-08-13, see top UPDATE)
- [x] Dated, web-verified best-practice sources archived and registered. (completed via ai--1 2026-08-13, see top UPDATE)
- [x] Gap matrix + prioritized recommendations delivered; config-change
      candidates flagged for §10 routing. (completed via ana-2 2026-08-13, see top UPDATE)
- [ ] (partial) Autonomy-config mapping (#4) + best-practice research (#5) DONE via ai--1 2026-08-13 (C7 no-drift, C8 --auto). Remaining: #1 workflow enumeration, #2 developer-ownership audit, #3 verification-loop quantification, #6 gap matrix + registration - queued as dedicated @analyzer lane.

## Fix

> FIX COMPLETE 2026-08-13 - audit executed across two lanes (see top UPDATE).
>
> OUTCOME: two-tier adherence pattern confirmed - structural/plugin-enforced
> workflows (ticket gate, plugin gates, make test gates) are STRONG;
> practice-protected/prompt-enforced workflows (reviewer disposition,
> re-verify evidence, interview-first, TDD edge-cases, architector flags)
> are WEAK-to-MODERATE. Eight gaps (G1-G8) with five prioritized
> recommendations (R1-R5), each traced to a best-practice source in the
> ana015 report (knowledge/ana015-workflow-adherence-audit/).
>
> RECOMMENDATIONS + section-10 routing flags:
> R1 HIGH reviewer-disposition pending-owner gate (S10 flag YES -
> plugin/delegation-observer change)
> R2 HIGH re-verify evidence checklist + scripts/validate-reverify.sh
> (S10 flag NO - dev-infra script)
> R3 MEDIUM skip-spec flag enforcement on coder dispatches (S10 flag PARTIAL)
> R4 MEDIUM @architector activation pathway (S10 flag YES)
> R5 MEDIUM TDD edge-case surfacing convention M6 (S10 flag PARTIAL)
>
> R1/R4/R5 are section-10 config-change candidates - to be routed through
> the section-10 chain (ai-specialist -> user decides -> design -> coder ->
> ai-auditor -> validate -> register) as follow-up tickets, NOT implemented
> in this ticket. R2 (validate-reverify.sh) is a dev-infra script candidate
> for the standard dev-infra workflow. Findings registered per
> research-pipeline: ana015 conspect registered in memory-shelf analyses[15].
> Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.

## Re-verify

> RE-VERIFY PASS 2026-08-13 - all 6 investigation requirements met: #1
> workflow enumeration + adherence assessment (ana-2), #2 developer-ownership
> audit (ana-2), #3 verification-loop quantification (ana-2: CLOSED 45,
> re-verify evidence 51%, cycle 1 ~80% / cycle 2 ~15% / >2 = 0, cap
> respected, closed-after-re-review 93%), #4 autonomy-config mapping (ai--1,
> C7 no-drift), #5 best-practice research (ai--1, C8 --auto), #6 gap matrix
>
> - prioritized recommendations + registration (ana-2, ana015 registered
>   memory-shelf analyses[15]). Evidence: ana015 report +
>   knowledge/ana015-workflow-adherence-audit/ + ai--1 C7/C8 findings in this
>   ticket. Gap matrix + R1-R5 recommendations delivered; config-change
>   candidates (R1/R4/R5) flagged for section-10 routing as follow-up tickets.
>   Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.
