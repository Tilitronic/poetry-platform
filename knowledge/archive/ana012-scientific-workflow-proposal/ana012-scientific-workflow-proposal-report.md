# Ana012: Scientific-Workflow Proposal for Poetry-Platform

**Ticket:** DIA-086 (items 3-4: internal mapping pass, mandatory-vs-optional split)
**Author:** @analyzer (ana-3 lane)
**Date:** 2026-08-11
**Evidence base:** knowledge/res012-scientific-methodology/ (50 archived sources, MLA-cited conspect)

---

## 1. Gap Analysis: Survey Practices vs. Existing Mechanisms

### 1.1 Survey Practice Categories (from res012 conspect sections 1-10)

| # | Survey Practice | Existing Mechanism | Coverage | Gap Type |
|---|----------------|--------------------|----------|----------|
| 1 | Structured hypothesis/claim objects | domain-grilling (Phase 1 Socratic interview), openspec-plan (interview transcript), researcher High/Medium/Low confidence | PARTIAL -- hypotheses emerge from interviews but are not captured as structured objects with id/claim/variables/metrics/falsifiers | **Structural gap**: no schema for claim objects in lane reports |
| 2 | Novelty checks (literature pre-experiment) | research-pipeline (Phase 1 dispatches @researcher; conspecter archives sources); DIA-072 Archive-Before-Claim | STRONG -- literature review is mandatory before persistence; conspect requires 3+ sources | No gap for project-scoped research. Cross-project novelty (is this idea new in the wild) is out of scope per SCOPE GUARD. |
| 3 | Experiment journals/logs (tamper-evident traces) | delegation-observer plugin (registry.jsonl + messages.jsonl); session log (messages.md/jsonl); HANDOFF.md verification evidence; coder fix-summaries with exit codes | STRONG -- traces exist as evidence, not self-report (evaluator reads raw logs, per conspect section 9 failure modes) | **Minor gap**: analysis/lane reports lack a formal experiment-log header (timestamp, env, commit, seed) |
| 4 | Falsification (explicit falsifiers, adversarial checks) | review-re-verify skill (re-review cycle N/2 with verification evidence); @reviewer two-axis (independent from coder); AGENTS.md section 2.3.1 re-review loop | PARTIAL -- re-review verifies prior findings resolved, which approximates "attempt to break the claim," but there is no explicit step where the reviewer GENERATES counter-claims or adversarial tests | **Structural gap**: no falsification step as distinct from verification |
| 5 | Independent reviewer critique | @reviewer two-axis (Standards + Spec fidelity); review-re-verify; Fowler smell baseline (code-review-fowler skill) | STRONG -- reviewer is independent from coder; two axes are explicit; findings-resolution table is the critique artifact | No gap |
| 6 | Provenance / constrained citations | DIA-072 Archive-Before-Claim (research-pipeline skill section "Archive-Before-Claim Policy"); source-urls.txt; archived .md/.pdf in sources/; conspect exclusions flagged | STRONG -- claims without archived sources are excluded; conspect cites MLA-style | No gap (DIA-072 is the direct mapping) |
| 7 | Test-driven SWE agents | tdd-craftsman skill (RED-GREEN-REVIEW cycle, tracer bullets at pre-agreed seams, vertical slices); SWE-bench-style fail-to-pass as reproduction contract | STRONG -- test-first is load-bearing; separation of test-author (tdd-craftsman / @coder in RED phase) from implementer (@coder in GREEN phase) from verifier (@reviewer) | **Nuance gap** (not a project gap): conspect section 10 warns enforced TDD slows exploratory code -- project already handles this via domain-grilling (design phase before TDD) |
| 8 | Eval-driven development (define evals early) | Existing test suites (test-shell, test-infra, test-config, test-python); Makefile gates; pre-commit hook (DIA-094); verify-pre-commit.sh | PARTIAL -- test suites exist and gate merges, but there is no dedicated FROZEN LITE EVAL SET for agent capability benchmarking (per conspect section 8: Anthropic recommends 20-50 tasks from real past failures, LangChain lite benchmark) | **Structural gap**: no frozen eval set for agent workflows |
| 9 | Failure modes (hallucination, reward hacking, shortcut learning) | Conspect res012 section 9 catalogs these; project has DIA-078 loop hardening, DIA-094 docker gate, DIA-072 archive-before-claim as partial mitigations | PARTIAL -- failure modes are documented in conspect; mitigations exist ad hoc; no FAILURE-MODE LEDGER in the project | **Minor gap**: no explicit failure-mode classification in analysis reports |
| 10 | Overhead/cost (SCOPE GUARD for solo dev) | DIA-086 ticket SCOPE GUARD; project is solo-developer | ALIGNED -- this report is the SCOPE GUARD application | No gap |

### 1.2 Structural Gaps (Confirmed)

The researcher's brief identified two practices as NOT structurally present. Verification:

**Gap A: Falsification / "Break Your Own Claim"**
- **Status:** CONFIRMED as structural gap.
- **Evidence:** review-re-verify skill (knowledge/.opencode/skills/review-re-verify/SKILL.md) verifies PRIOR findings resolved -- it does not generate new counter-claims. @reviewer two-axis (oh-my-opencode-slim/reviewer.md) evaluates Standards + Spec fidelity, not adversarial stress tests of the claim itself. The re-review loop (AGENTS.md section 2.3.1) caps at 2 cycles and focuses on fix verification, not claim falsification.
- **Conspect trace:** res012 section 4 (falsification) cites POPPER (sources/018, 016) and DASES Abyss Falsifier as frameworks for automated falsification; section 10 notes full adversarial co-evolution is disproportionate for solo dev.
- **Verdict:** lightweight falsification (explicit "attempt to break" step) is cheap and addable; full POPPER/DASES machinery is disproportionate.

**Gap B: Competing-Hypothesis Comparison**
- **Status:** CONFIRMED as structural gap.
- **Evidence:** domain-grilling skill (Phase 3 ADR Capture) explores alternatives for architectural decisions (Alternatives Considered), but analysis reports (ana*) do not have a structured section comparing competing hypotheses for the analysis claim itself. The research-pipeline produces a single conspect with confidence levels, not a hypothesis-comparison matrix.
- **Conspect trace:** res012 section 1 (structured hypothesis/claim objects) notes best practice includes "prior-evidence links, proposed experiment(s), expected falsifiers" -- no existing mechanism enforces this for analysis claims.
- **Verdict:** lightweight competing-hypothesis section is addable to analysis reports; full systematic comparison (AutoSci-style) is disproportionate.

### 1.3 Already-Implemented Inventory (Additive to DIA-086 item 1)

The ticket's item 1 already recorded the research-pipeline, knowledge/, tdd-craftsman mapping. This analysis confirms:

- **research-pipeline skill** (`.opencode/skills/research-pipeline/SKILL.md`): 4-phase pipeline (research -> persistence decision -> conspecter -> memory shelf); DIA-072 Archive-Before-Claim (section "Archive-Before-Claim Policy"); 3-tier fallback chain for source archival. Maps to: constrained citations, provenance, experiment logs (via conspect + memory shelf).
- **tdd-craftsman skill** (`.opencode/oh-my-opencode-slim/src/skills/tdd-craftsman/SKILL.md`): RED-GREEN-REVIEW cycle; tracer bullets at pre-agreed seams; vertical slices; separation of test-author from implementer. Maps to: test-driven verification, reproduction contracts.
- **@reviewer + review-re-verify skill** (`.opencode/oh-my-opencode-slim/reviewer.md` + `.opencode/skills/review-re-verify/SKILL.md`): two-axis review (Standards + Spec); findings-resolution table; re-review cycle N/2 with verification evidence; clean-termination independent verification mode. Maps to: independent reviewer critique, falsification-as-re-review (partial).
- **delegation-observer plugin** (registry.jsonl + messages.jsonl): tamper-evident traces of delegations, decisions, handoffs, crises; session log (messages.md/jsonl) as the orchestrator-level event log. Maps to: experiment logs as evidence (not self-report).
- **domain-grilling skill** (`.opencode/skills/domain-grilling/SKILL.md`): 3-phase Socratic interview (Grilling -> Domain Modeling -> ADR Capture); practice-protected (developer writes substance); ADR format includes Alternatives Considered. Maps to: hypothesis formation (via interview), uncertainty exploration.
- **openspec-plan / openspec-propose skills** (`.opencode/skills/openspec-propose/SKILL.md`): interview-first spec authoring; Socratic interview precedes ALL artifact synthesis; numerical-invariants battery for scientific computation; practice-protected. Maps to: explicit assumptions, hypothesis formation.
- **researcher lane High/Medium/Low confidence** (research-pipeline skill Phase 1 output contract): structured summary with confidence assessment. Maps to: uncertainty scoring.
- **AGENTS.md section 2.3.1 re-review loop**: max 2 fix->re-review cycles; coder must provide verification evidence (exit codes + summary lines); reviewer verifies each prior finding; cycle cap prevents infinite loops. Maps to: falsification-as-re-review (partial), independent verification.
- **Practice-protected zones** (`.opencode/practice-protected.md`): OpenSpec proposal.md / design.md authoring; TDD edge-case identification; architectural decisions. Maps to: separation of test-author from implementer (tdd-craftsman writes tests, @coder implements, @reviewer verifies).

---

## 2. Mandatory-vs-Optional Split (Ticket Item 4)

### 2.1 MANDATORY Set (Cheap, Existing-Mechanism-Aligned, Enforceable via Current Gates)

These additions are low-overhead, plug into existing gates (config validation, ticket gate, review gate, handoff gate), and are enforceable without new infrastructure:

| # | Addition | What It Is | Why (Survey Finding) | Where It Plugs In | Effort | Conspect Trace |
|---|----------|-----------|----------------------|-------------------|--------|----------------|
| M1 | Claim/Evidence/Confidence Template for Lane Reports | Structured header in analysis/research reports: claim_id, claim_statement, evidence_summary (bullet list of archived sources), confidence (High/Medium/Low), falsifiers_attempted (bullet list of what was tried to break the claim), competing_hypotheses (bullet list of alternatives considered and why rejected). | res012 section 1 (structured hypothesis/claim objects); section 4 (falsification); section 5 (independent verification); section 9 (failure modes). | ana* reports, res* conspects. Enforceable via @analyzer/@conspecter output contracts. | 2h (template + skill update) | sources/001, 004, 008, 009, 016, 018 |
| M2 | Experiment-Log Header Convention in Reports | Formal header in lane reports: timestamp (ISO 8601), environment (container image hash or commit), seed (if applicable), raw_outputs (link to registry.jsonl session_id or messages.jsonl range). | res012 section 3 (experiment journals/logs -- tamper-evident traces); section 6 (provenance). | ana* reports, res* conspects. Enforceable via @analyzer/@conspecter output contracts. | 1h (convention doc + template) | sources/001, 051 |
| M3 | "Break Your Claim" Step in Review Loop | Add a third section to @reviewer two-axis review: "Falsification" -- reviewer explicitly attempts to generate counter-claims or adversarial tests for the coder's implementation. Not a full POPPER machinery, just a structured prompt: "List 3 ways this implementation could be wrong despite passing tests." | res012 section 4 (falsification); section 5 (independent verification); conspect section 9 (failure modes -- hallucination, shortcut learning). | @reviewer two-axis review (oh-my-opencode-slim/reviewer.md); review-re-verify skill. Add "Falsification" axis or section. | 3h (reviewer prompt update + skill update) | sources/016, 018, 065 |
| M4 | Explicit Hypothesis Line in openspec-plan Interviews | Add a mandatory question to the Socratic interview protocol: "State your hypothesis as a single sentence: 'I believe [change] will [outcome] because [rationale]. Falsified if [observable condition].'" Capture in interview transcript and fold into proposal.md. | res012 section 1 (structured hypothesis/claim objects); section 4 (falsification -- explicit falsifiers). | openspec-propose skill (Socratic interview protocol); domain-grilling skill (Phase 1 Grilling). | 2h (interview protocol update) | sources/001, 004, 009 |
| M5 | Frozen Lite Eval Set Proposal for Test Suites | Create a small (20-50 task) frozen eval set from real past failures (per Anthropic guidance). Not a new test suite -- a curated subset of existing tests (test-shell, test-infra, test-config, test-python) that represents the project's core capabilities. Run as a daily smoke test (per JetBrains guidance). | res012 section 8 (eval-driven development); conspect cites Anthropic (20-50 tasks from real past failures), LangChain (lite benchmark), JetBrains (10-task daily smoke). | Makefile (new target: `make eval-lite`); existing test suites (curate subset). | 4h (curation + Makefile target) | sources/039, 040, 041 |

**Enforceability:** M1-M4 are output-contract enforceable (lane skills can require the template/header/step). M5 is a Makefile target, enforceable via CI (not yet wired, but addable). All are cheap (<12h total).

### 2.2 OPTIONAL Set (Disproportionate for Solo Dev per SCOPE GUARD)

These are flagged by the researcher as high-overhead or research-lab-scale, not appropriate for a solo-developer system:

| # | Practice | Why Optional / Rejected | Conspect Trace |
|---|----------|------------------------|----------------|
| O1 | Full autonomous research pipelines (AI Scientist-style, AutoSci, DASES adversarial co-evolution) | Multi-hour to multi-day runs; cluster resources; reviewer networks; compute-intensive. DIA-086 SCOPE GUARD: "solo-developer system, not a research lab." | res012 section 10 (overhead/cost); sources/001, 004, 013, 016. |
| O2 | POPPER statistical machinery (e-values, power analysis, pre-registration) | Statistical framework for falsification; requires cluster compute and large-scale experiments. Lightweight "attempt to break" step (M3) is sufficient. | res012 section 4 (falsification); sources/016, 018. |
| O3 | Dogmatic enforced TDD on exploratory/research code | Conspect section 10 warns: "tests-first is NOT always right (AgentPatterns: exploratory/research code, fuzzy requirements, non-deterministic output -- enforced TDD slows loop and encodes premature interfaces)." Project already handles this via domain-grilling (design phase before TDD). | res012 section 7 (test-driven SWE agents); section 10 (overhead); source/043 (AgentPatterns). |
| O4 | Full novelty checks against literature (retrieval-based similarity, citation graph overlap) | Cross-project novelty (is this idea new in the wild) is out of scope. Project-scoped literature review (research-pipeline) is sufficient. | res012 section 2 (novelty checks); sources/034, 035, 037. |
| O5 | Failure-mode ledger with instrumentation | Conspect section 9 catalogs failure classes; project has ad hoc mitigations (DIA-078, DIA-094, DIA-072). A formal ledger is useful but not mandatory -- M1 (claim/evidence/confidence template) captures failure modes implicitly via falsifiers_attempted. | res012 section 9 (failure modes); sources/044, 045, 046. |
| O6 | Competing-hypothesis comparison matrix (AutoSci-style systematic comparison) | Lightweight competing-hypothesis section (M1 template) is sufficient. Full systematic comparison is research-lab-scale. | res012 section 1 (structured hypothesis/claim objects); sources/004, 013. |

**Verdict:** M1-M5 are the mandatory set (cheap, enforceable, existing-mechanism-aligned). O1-O6 are optional/rejected per SCOPE GUARD.

---

## 3. Concrete Workflow-Proposal: 5 Lightweight Additions

### 3.1 M1: Claim/Evidence/Confidence Template for Lane Reports

**What:** Structured header in ana* and res* reports:
```
## Claim Object
- **claim_id:** ana012-001
- **claim_statement:** [single-sentence claim]
- **evidence_summary:**
  - [archived source 1, MLA-ish citation]
  - [archived source 2, MLA-ish citation]
- **confidence:** High | Medium | Low
- **falsifiers_attempted:**
  - [what was tried to break the claim, result]
- **competing_hypotheses:**
  - [alternative 1, why rejected]
  - [alternative 2, why rejected]
```

**Why:** res012 section 1 (structured hypothesis/claim objects -- best practice for machine-readable artifacts); section 4 (falsification -- explicit falsifiers); section 5 (independent verification -- critique artifacts); section 9 (failure modes -- hallucination, shortcut learning).

**Where:** @analyzer skill output contract; @conspecter skill output contract. Enforceable via skill templates.

**Effort:** 2h (template + skill update).

**Conspect trace:** sources/001 (AI Scientist v1 -- idea->implementation artifactization), 004 (AI Scientist v2), 008 (Agent Laboratory -- experiment manifests), 009 (AgentLaboratory code templates), 016 (DASES -- falsification), 018 (POPPER -- falsification framework).

### 3.2 M2: Experiment-Log Header Convention in Reports

**What:** Formal header in lane reports:
```
## Experiment Log
- **timestamp:** 2026-08-11T14:30:00Z
- **environment:** poetry-dev container @ commit abc1234
- **seed:** session_id ses_0133de7fdffeKc3ClhE6fqFy0X
- **raw_outputs:** registry.jsonl range seq 700-720; messages.jsonl range m0580-m0600
```

**Why:** res012 section 3 (experiment journals/logs -- tamper-evident traces: timestamped logs, committed code+seed, environment capture, input data snapshot, metrics with raw outputs); section 6 (provenance -- resolvable pointers to archived artifacts).

**Where:** @analyzer skill output contract; @conspecter skill output contract. Enforceable via skill templates.

**Effort:** 1h (convention doc + template).

**Conspect trace:** sources/001 (AI Scientist v1 -- experiment traceability), 051 (Self-RAG -- provenance pointers).

### 3.3 M3: "Break Your Claim" Step in Review Loop

**What:** Add a third section to @reviewer two-axis review:
```
## Falsification
Attempt to generate counter-claims or adversarial tests for the implementation.
- **counter_claim_1:** [way the implementation could be wrong despite passing tests]
- **counter_claim_2:** [way the implementation could be wrong despite passing tests]
- **counter_claim_3:** [way the implementation could be wrong despite passing tests]
- **adversarial_tests:** [if applicable, tests that stress the implementation]
```

Not a full POPPER machinery -- just a structured prompt forcing the reviewer to think adversarially.

**Why:** res012 section 4 (falsification -- explicit falsifiers, negative-control experiments, automated detection of overfitting/shortcut solutions); section 5 (independent verification -- human-in-the-loop peer review with structured review forms); section 9 (failure modes -- hallucination, shortcut learning, brittle tool use).

**Where:** @reviewer prompt (oh-my-opencode-slim/reviewer.md); review-re-verify skill. Add "Falsification" section after Standards + Spec axes.

**Effort:** 3h (reviewer prompt update + skill update).

**Conspect trace:** sources/016 (DASES -- falsification framework), 018 (POPPER -- falsification toolkit), 065 (failure-mode survey).

### 3.4 M4: Explicit Hypothesis Line in openspec-plan Interviews

**What:** Add a mandatory question to the Socratic interview protocol:
```
Q: State your hypothesis as a single sentence.
Format: "I believe [change] will [outcome] because [rationale]. Falsified if [observable condition]."
Example: "I believe adding a frozen lite eval set will catch agent capability regressions because it represents real past failures. Falsified if the eval set does not catch regressions that manual testing would have caught."
```

Capture in interview transcript and fold into proposal.md under a "## Hypothesis" section.

**Why:** res012 section 1 (structured hypothesis/claim objects -- hypothesis statements coupled with required data, code, metrics, acceptance criteria); section 4 (falsification -- explicit falsifiers attached to hypotheses).

**Where:** openspec-propose skill (Socratic interview protocol, step 1); domain-grilling skill (Phase 1 Grilling). Add to interview protocol.

**Effort:** 2h (interview protocol update).

**Conspect trace:** sources/001 (AI Scientist v1 -- hypothesis objects), 004 (AI Scientist v2), 009 (AgentLaboratory -- structured experiment manifests).

### 3.5 M5: Frozen Lite Eval Set Proposal for Test Suites

**What:** Create a Makefile target `make eval-lite` that runs a curated subset (20-50 tasks) of existing test suites (test-shell, test-infra, test-config, test-python). Curate from real past failures (DIA tickets, review findings, regression bugs). Run as a daily smoke test.

Not a new test suite -- a curated subset representing the project's core capabilities.

**Why:** res012 section 8 (eval-driven development -- define evaluation harnesses early, instrument experiments, use continuous evaluation to guide iteration; Anthropic: build evals defining planned capabilities, 20-50 tasks from real past failures; LangChain lite benchmark ~8x faster 6x cheaper; JetBrains 10-task daily smoke).

**Where:** Makefile (new target); existing test suites (curate subset). Enforceable via CI (not yet wired, but addable).

**Effort:** 4h (curation + Makefile target).

**Conspect trace:** sources/039 (Anthropic -- eval pipelines), 040 (LangChain -- lite benchmark), 041 (JetBrains -- daily smoke test).

---

## 4. Before/After Comparison Table

| Stage | Current Workflow | Proposed Workflow (with M1-M5) |
|-------|------------------|--------------------------------|
| **Interview** (domain-grilling / openspec-plan) | Socratic interview explores assumptions, edge cases, alternatives; ADR capture with Alternatives Considered. | **ADD M4:** explicit hypothesis line in interview protocol. Interview produces a structured hypothesis statement with falsification condition. Folded into proposal.md. |
| **Spec** (openspec-plan artifacts) | proposal.md, design.md, tasks.md synthesized from interview transcript. Testing Decisions section in tasks.md. | **NO CHANGE** -- spec artifacts remain as-is. Hypothesis from interview is captured in proposal.md (M4). |
| **Implement** (tdd-craftsman / @coder) | RED-GREEN-REVIEW cycle; tracer bullets at pre-agreed seams; vertical slices; separation of test-author from implementer. | **NO CHANGE** -- implementation workflow remains as-is. |
| **Review** (@reviewer two-axis) | Two axes: Standards (Fowler baseline) + Spec fidelity. Findings-resolution table. Re-review cycle N/2. | **ADD M3:** third section "Falsification" -- reviewer attempts to generate counter-claims or adversarial tests. Not a full POPPER machinery, just structured adversarial thinking. |
| **Persist** (@analyzer / @conspecter / memory-manager) | Lane reports (ana*, res*) with findings, recommendations, citations. Memory shelf registration. | **ADD M1 + M2:** structured claim/evidence/confidence header (M1) + experiment-log header (M2) in all lane reports. Enforceable via skill output contracts. |
| **Eval** (test suites / Makefile gates) | test-shell, test-infra, test-config, test-python; pre-commit hook (DIA-094); verify-pre-commit.sh. | **ADD M5:** `make eval-lite` target -- curated subset (20-50 tasks) from real past failures. Daily smoke test. |

**Summary:** 5 lightweight additions (M1-M5), <12h total effort, plug into existing gates, no new infrastructure. Mandatory set is cheap and enforceable. Optional set (O1-O6) rejected per SCOPE GUARD.

---

## 5. Explicit Traceability to Archived Sources

Every proposal cites the archived source in knowledge/res012-scientific-methodology/sources/ that supports it (MLA-ish reference):

| Proposal | Archived Sources (MLA-ish) |
|----------|---------------------------|
| M1 (Claim/Evidence/Confidence Template) | Lu, Christopher. "The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery." arXiv, 2024. knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md. <br> "AI Scientist v2." arXiv, 2025. knowledge/res012-scientific-methodology/sources/004-arxiv-org-abs-2504-08066.md. <br> "Agent Laboratory." arXiv, 2025. knowledge/res012-scientific-methodology/sources/008-arxiv-org-abs-2501-04227.md. <br> Schmidgall, Samuel. "Agent Laboratory." GitHub, 2025. knowledge/res012-scientific-methodology/sources/009-github-com-samuelschmidgall-agentlaboratory.md. <br> "DASES: Darwin-Award-Winning AI via Self-Evolving Adversarial Co-Optimization." arXiv, 2025. knowledge/res012-scientific-methodology/sources/016-arxiv-org-abs-2502-09858.md. <br> "POPPER: Automated Falsification Framework." GitHub, 2025. knowledge/res012-scientific-methodology/sources/018-github-com-snap-stanford-popper.md. |
| M2 (Experiment-Log Header) | Lu, Christopher. "The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery." arXiv, 2024. knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md. <br> "Self-RAG: Learning to Retrieve, Generate, and Critique through Self-Reflection." GitHub, 2024. knowledge/res012-scientific-methodology/sources/034-selfrag-github-io.md. |
| M3 ("Break Your Claim" Step) | "DASES: Darwin-Award-Winning AI via Self-Evolving Adversarial Co-Optimization." arXiv, 2025. knowledge/res012-scientific-methodology/sources/016-arxiv-org-abs-2502-09858.md. <br> "POPPER: Automated Falsification Framework." GitHub, 2025. knowledge/res012-scientific-methodology/sources/018-github-com-snap-stanford-popper.md. <br> "A Survey on Failure Modes in AI Systems." arXiv, 2026. knowledge/res012-scientific-methodology/sources/065-arxiv-org-abs-2601-03315v1.md. |
| M4 (Explicit Hypothesis Line) | Lu, Christopher. "The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery." arXiv, 2024. knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md. <br> "AI Scientist v2." arXiv, 2025. knowledge/res012-scientific-methodology/sources/004-arxiv-org-abs-2504-08066.md. <br> Schmidgall, Samuel. "Agent Laboratory." GitHub, 2025. knowledge/res012-scientific-methodology/sources/009-github-com-samuelschmidgall-agentlaboratory.md. |
| M5 (Frozen Lite Eval Set) | "Demystifying Evals for AI Agents." Anthropic Engineering, 2025. knowledge/res012-scientific-methodology/sources/039-www-anthropic-com-engineering-demystifying-evals-for-ai-agents.md. <br> "How We Benchmark Deep Agents." LangChain Blog, 2025. knowledge/res012-scientific-methodology/sources/040-www-langchain-com-blog-how-we-benchmark-deep-agents.md. <br> "Testing AI Coding Agents with TeamCity and SWE-Bench." JetBrains Blog, 2025. knowledge/res012-scientific-methodology/sources/041-blog-jetbrains-com-teamcity-2025-09-testing-ai-coding-agents-with-teamcity-and-swe-bench.md. |

**DIA-072 trace:** M1 (evidence_summary), M2 (experiment-log header), and the existing research-pipeline skill all map directly to DIA-072 Archive-Before-Claim policy. DIA-072 is the project's existing provenance mechanism; M1-M2 extend it with structured headers.

---

## 6. SCOPE GUARD Confirmation: What Was REJECTED and Why

**REJECTED per SCOPE GUARD (solo-developer system, not a research lab):**

| # | Rejected Practice | Why Rejected |
|---|-------------------|--------------|
| O1 | Full autonomous research pipelines (AI Scientist-style, AutoSci, DASES adversarial co-evolution) | Multi-hour to multi-day runs; cluster resources; reviewer networks; compute-intensive. Disproportionate for solo dev. |
| O2 | POPPER statistical machinery (e-values, power analysis, pre-registration) | Statistical framework for falsification; requires cluster compute and large-scale experiments. Lightweight "attempt to break" step (M3) is sufficient. |
| O3 | Dogmatic enforced TDD on exploratory/research code | Conspect section 10 warns enforced TDD slows exploratory code and encodes premature interfaces. Project already handles this via domain-grilling (design phase before TDD). |
| O4 | Full novelty checks against literature (retrieval-based similarity, citation graph overlap) | Cross-project novelty is out of scope. Project-scoped literature review (research-pipeline) is sufficient. |
| O5 | Failure-mode ledger with instrumentation | Conspect section 9 catalogs failure classes; project has ad hoc mitigations. M1 (claim/evidence/confidence template) captures failure modes implicitly via falsifiers_attempted. |
| O6 | Competing-hypothesis comparison matrix (AutoSci-style systematic comparison) | Lightweight competing-hypothesis section (M1 template) is sufficient. Full systematic comparison is research-lab-scale. |

**RATIONALE:** DIA-086 SCOPE GUARD: "this is a solo-developer system, not a research lab. Weight the output toward 'what's cheap and actually gets used' over building a full methodology framework." The mandatory set (M1-M5) is <12h total effort, plugs into existing gates, and is enforceable without new infrastructure. The optional set (O1-O6) is research-lab-scale and disproportionate.

---

## 7. Summary

**Report path:** knowledge/ana012-scientific-workflow-proposal/ana012-scientific-workflow-proposal-report.md
**Word count:** ~3,500 words
**Gap-analysis verdict:**
- **Mapped (existing mechanisms):** novelty checks (research-pipeline + DIA-072), experiment logs (delegation-observer + session log), independent reviewer critique (@reviewer two-axis), provenance/constrained citations (DIA-072 Archive-Before-Claim), test-driven SWE agents (tdd-craftsman), uncertainty scoring (researcher High/Medium/Low).
- **Structural gaps (confirmed):** falsification/"break your own claim" (not structurally present as distinct step), competing-hypothesis comparison (not structurally present in analysis reports), frozen lite eval set (not structurally present for agent capabilities).

**Mandatory-vs-optional headline split:**
- **MANDATORY (M1-M5):** Claim/evidence/confidence template (M1), experiment-log header (M2), "break your claim" step in review (M3), explicit hypothesis line in interviews (M4), frozen lite eval set (M5). Total effort <12h.
- **OPTIONAL/REJECTED (O1-O6):** Full autonomous research pipelines, POPPER statistical machinery, dogmatic enforced TDD on exploratory code, full novelty checks against literature, failure-mode ledger, competing-hypothesis comparison matrix. All rejected per SCOPE GUARD.

**Memory-shelf registration:** Pending (will be appended after report is written).

**DIA-072 trace:** All proposals trace to DIA-072 Archive-Before-Claim as the existing provenance mechanism. M1-M2 extend it with structured headers.

---

## 8. Implementation Status (2026-08-11)

**Status:** PROPOSAL -> IMPLEMENTED. All five mandatory additions (M1-M5) were
delivered and archived on 2026-08-11 as the change
`dia-086-m1-m5-agent-contracts-eval-lite`
(`openspec/changes/archive/2026-08-11-dia-086-m1-m5-agent-contracts-eval-lite/`).

| Mandate | Delivered Artifact | Gate |
|---------|--------------------|------|
| M1 analyzer output contract | `ANALYZER-OUTPUT-CONTRACT` header block in `.opencode/agents/analyzer.md` (schema-version, agent, claim-type, evidence-source, confidence, shelf-registration) + `scripts/validate-output-contracts.sh` | make test-config |
| M2 conspecter output contract | `CONSPECTER-OUTPUT-CONTRACT` header block in `.opencode/agents/conspecter.md` (schema-version, agent, phase-a-source-count, phase-a-failures, shelf-registration) + same validator | make test-config |
| M3 reviewer Falsification axis | `## Falsification` section in `.opencode/oh-my-opencode-slim/reviewer.md` between `## Spec` and `## Summary`, exactly 3 severity-labelled `[FALSIFICATION-N]` claims + `scripts/validate-reviewer-sections.sh` | make test-config |
| M4 hypothesis question | Identical question in `.opencode/skills/openspec-propose/SKILL.md` + `.opencode/skills/domain-grilling/SKILL.md` after `<!-- FIRST-QUESTION -->` anchor + `validate-skills.sh` extension | make test-skills |
| M5 eval-lite harness | `scripts/eval-lite.sh`, `docs/dev-infra/eval-lite-tasks.md` (20-task manifest), `scripts/__tests__/eval-lite.bats`, Makefile `eval-lite` target + test-config wiring | make eval-lite |

**Review chains:** Slice A (M1-M4, config-tooling per AGENTS.md 2.5) @coder + @ai-auditor
APPROVE; Slice B (M5, dev-infra per AGENTS.md 2.4) @coder + @reviewer APPROVE on both axes.

**Gate evidence (2026-08-11):** `make eval-lite` 20/20 (~22s); `make test-shell` 193/0;
`make test-config` exit 0 (224 pre-existing WARNs); `openspec validate` 15/15 post-archive.

**Memory-shelf registration:** COMPLETE (2026-08-11) - `shelf.specs` entry added for the
archived change; the "Pending" note in section 7 is superseded.

---

**END OF REPORT**
