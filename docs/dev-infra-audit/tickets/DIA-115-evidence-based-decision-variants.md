# DIA-115 — mandatory evidence (citations/experiments) for agent decision-variant presentations — cross-agent policy, research-first

<!-- UPDATE 2026-08-13 (IMPLEMENTED + AUDITED + MINORS FIXED - TICKET CLOSED): developer-approved items 1-3 implemented by cod-26 (ses_00312a72dffe5CXTb2M51VZmcg): (1) scripts/validate-decision-variants.sh - mechanical EBDV validator (rules a-g: >=2 variants or fewer-than-2 marker section-scoped, abort/status-quo always, Chosen line, per-variant evidence Tier-1/Tier-2/[INFERENCE], single [INFERENCE]-only rejected, whole-decision needs >=1 Tier-1/Tier-2 hit), opt-in scanning (only tickets with a decision section), exit 0/1/2, TICKETS_DIR override; (2) scripts/__tests__/validate-decision-variants.bats (13 tests after Minor fixes); (3) Makefile test-config wiring (append-only after validate-reviewer-sections.sh); (4) openspec/schemas/spec-driven/templates/proposal.md '## Alternatives considered' EBDV section (schema fork, 4 other files byte-identical to package originals - package at /home/qualt/.volta/tools/image/packages/@fission-ai/openspec/lib/node_modules/@fission-ai/openspec/schemas/spec-driven/); (5) AGENTS.md project section 2.5 + global section 10 EBDV prompt rule. ai-auditor (ai--4) CONFORMANT-WITH-NOTES; developer disposition FIX both Minors (rule g whole-decision evidence + section-scoped fewer-than-2 marker) - applied this lane; Suggestions deferred. Validation: make test-config exit 0 (validator: 88 tickets checked, 88 passed), make test-shell exit 0 (262 + new bats tests), bash -n clean, openspec validate exit 0. Item 4 (practice-protected zone + ai-auditor check) DEFERRED per developer. Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.

     UPDATE 2026-08-13 (RESEARCH + PERSISTENCE COMPLETE - res-3 +
     res022): research lane res-3 (ses_00371d09bffe4xkD90uvOiGwSc)
     delivered the EBDV (evidence-backed decision variants) design:
     triggers (policy-class section-10 changes, AGENTS.md/prompts,
     agent-policy, model/tool selection with >=2 candidates; NOT
     single-obvious-mechanical or fast-path); variant format (title +
     change-description + evidence-sources + pros/cons + effort +
     section-10-flag + Y-statement one-line); evidence tiers T1
     committed/archived-conspec / T2 web-fresh-cited URL+date / T3
     [INFERENCE] labeled, T3-alone rejected; min >=2 real variants +
     recommendation + always-available abort/status-quo; chosen variant
     recorded in ticket UPDATE block + MADR-minimal .sdd ADR for
     architecture-significant + OpenSpec '## Alternatives considered';
     section-10 interaction = layers ON TOP (EBDV adds presentation
     requirement inside section-10 Phase 2 for policy-class, does NOT
     replace the gate). Persisted as conspect res022
     (knowledge/res022-evidence-backed-decision-variants/, 10/10 sources
     archived, 198 lines, shelf.conspects). Developer approved
     2026-08-13: IMPLEMENT items 1-3 (validate-decision-variants.sh
     mechanical validator wired into make test-config; OpenSpec proposal
     template + '## Alternatives considered'; AGENTS.md prompt rule) -
     full section-10 chain. Enforcement item 4 (practice-protected zone
     + ai-auditor) DEFERRED. This ticket stays OPEN pending the
     section-10 implementation.

     Filed 2026-08-12 by developer request. Cross-agent policy: whenever an
agent presents decision variants / propositions to the developer for a choice,
every variant MUST carry evidence (experiment results with logs, OR cited
sources - URLs/papers/benchmarks, dated). No assumption-based options.
RESEARCH FIRST: no implementation before the research phase completes. -->

---

id: DIA-115
title: "mandatory evidence (citations/experiments) for agent decision-variant presentations - cross-agent policy, research-first"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-12
source: owner-reported
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00ad9f335ffejqsIxpQTpOD2a9"
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-115-evidence-based-decision-variants.md"]
artifacts: []
evidence: []

---

## Description

Developer request (verbatim intent): agents' propositions and decisions must be
evidence based - every time an agent asks the developer to pick between decision
variants, it must provide references (experiment results with logs, or cited
sources with links/dates). No own-assumption-based decisions.

Trigger story: DIA-111 line 150 - developer asked "why you chooses KIMI model,
not gpt luna for exmample or qwen pro? I dont see strong arguments." The agent
presented a model-choice variant without cited benchmarks/experiments.

Scope: ALL agents, ALL decision-variant presentations to the developer
(model choices, architecture options, workflow designs, process changes) and
agent propositions. Evidence = experiment results (with reproducible logs) OR
citations (URLs/papers/benchmarks, dated).

Related: DIA-086 (closed, scientific-methodology M1-M5; analyzer evidence-source
contract covers analysis reports only, NOT decision-variant presentations),
DIA-111 (open, model-escalation - narrow trigger scope), DIA-104 (developer
grilling gate - where decisions get presented).

## Verification (research-first gate)

- [ ] RESEARCH PHASE (blocking - no implementation before this completes):
      survey how agentic systems enforce citation-backed decision presentation
      and evidence-graded option sets. REUSE knowledge/res012-scientific-
      methodology/, res013-opencode-model-pricing-audit/,
      res014-model-escalation-routing/, res015-mimo-v25-pro-evaluation/
      conspects (do not duplicate); fresh web sources where needed. Dated and
      sourced; conspect + memory-shelf registration per research-pipeline.
- [ ] Apply DIA-086 SCOPE GUARD: solo-dev system - propose cheap, actually-used
      enforcement; flag any overhead disproportionate to team size.
- [ ] Enforcement mechanism designed AFTER research, with mandatory-vs-optional
      split. Candidate surfaces (decide at research time): AGENTS.md rule,
      practice-protected.md zone, agent prompt contracts in
      oh-my-opencode-slim.jsonc / .opencode/agents/\*.md, mechanical validator
      (extend validate-output-contracts.sh pattern).
- [ ] Acceptance criterion: no decision-variant presentation to the developer
      without evidence (references or experiment results).
- [ ] If config/prompt changes result: route through section-10 chain
      (ai-specialist gate -> owner decision -> design -> coder -> make
      test-config exit 0 -> restart-verify -> ai-auditor -> CHANGELOG).
- [x] Research phase complete (res-3 2026-08-13, EBDV design + evidence tiers + enforcement surface, see top UPDATE)
- [x] Persistence complete (res022 conspect, 10/10 sources, shelf registered)

## Fix

FIX COMPLETE 2026-08-13 (cod-26 + minors lane): items 1-3 implemented (validator rules a-g, template, AGENTS.md); ai-auditor Minors fixed (whole-decision evidence rule g + section-scoped marker). See top UPDATE.

## Re-verify

RE-VERIFY PASS 2026-08-13: make test-config exit 0 (88/88), make test-shell exit 0, bats all green.

---
