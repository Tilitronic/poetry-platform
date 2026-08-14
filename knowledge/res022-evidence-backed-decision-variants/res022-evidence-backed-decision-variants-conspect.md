# Evidence-Backed Decision Variants (EBDV) - Conspect (res022)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 10
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-115 (OPEN research ticket, research-first): "mandatory evidence (citations/experiments) for agent decision-variant presentations - cross-agent policy". This is the persistence of the DIA-115 res-1 researcher findings: an evidence-backed decision-variant (EBDV) presentation format for policy-class decisions, synthesized from the ADR/MADR/Y-statement tradition and Claude Code / community (Prisma, Meshtastic, ruvnet agentic-flow) decision-documentation practices. Ten external URLs were archived locally in `sources/` (2026-08-13); every claim below is grounded either in an archived source file or in a project-internal document (DIA-115/DIA-086 tickets, res012-015 conspects, ana015/ana004 analyses). Researcher-supplied precedents that could NOT be confirmed in the archive (Swift Evolution, Carbon) are flagged per DIA-072 and listed in section 7, not asserted as claims.

## 1. Decision context (DIA-115)

DIA-115 (filed 2026-08-12, status OPEN, severity Medium, area opencode-config) mandates: whenever an agent presents decision variants / propositions to the developer for a choice, every variant MUST carry evidence - experiment results with logs, OR cited sources (URLs/papers/benchmarks, dated). No assumption-based options. The ticket is research-first: no implementation before the research phase completes, and this conspect closes that research phase.

**Trigger story (DIA-115, line 45-47):** DIA-111 line 150 - the developer asked "why you chooses KIMI model, not gpt luna for example or qwen pro? I dont see strong arguments." The agent had presented a model-choice variant without cited benchmarks or experiments. This is the model-choice trigger class: an agent proposes a model or tool selection with two or more candidates and no evidence backing the recommendation.

**Scope per ticket:** ALL agents, ALL decision-variant presentations to the developer (model choices, architecture options, workflow designs, process changes). Evidence = experiment results (with reproducible logs) OR citations (URLs/papers/benchmarks, dated).

**DIA-086 SCOPE GUARD (binding):** this is a solo-developer system, not a research lab (DIA-086 ticket line 74). Enforcement must be cheap and actually used; the design must split mandatory-vs-optional items and flag any overhead disproportionate to team size. The DIA-115 ticket repeats this: "Apply DIA-086 SCOPE GUARD: solo-dev system - propose cheap, actually-used enforcement" (line 68) and requires a mandatory-vs-optional split in the enforcement mechanism (line 70).

**Related tickets:** DIA-111 (model escalation - narrow trigger scope), DIA-104 (developer grilling gate - where decisions get presented), DIA-086 (scientific methodology M1-M5; analyzer evidence-source contract covers analysis reports only, NOT decision-variant presentations).

## 2. Evidence-backed decision-variant format (the EBDV design)

The EBDV design answers DIA-115 by defining: (a) when the format applies (triggers), (b) the per-variant field set, (c) a graded evidence model (T1/T2/T3), (d) a minimum-variant rule, and (e) documentation of the chosen variant. It is a presentation requirement, not a new decision workflow: the underlying decision flow (spec-interview -> proposal -> implement -> review) is unchanged.

### 2.1 Triggers (when EBDV applies - policy-class decisions)

EBDV applies when an agent presents decision variants to the developer for a choice in the following policy-class categories:

- **Section-10 policy changes**: any change to AI tooling (agents, skills, rules, config, plugins, MCPs, permissions) per global AGENTS.md section 10.
- **AGENTS.md / prompt changes**: rules and instruction-file edits (the CLAUDE.md/AGENTS.md class - Claude Code best practices treats the instruction file as load-bearing configuration: "CLAUDE.md is a special file that Claude reads at the start of every conversation. Include Bash commands, code style, and workflow rules").
- **Agent-policy changes**: lane prompts, agent definitions, permission models.
- **Model/tool-selection with >=2 candidates**: the DIA-111 trigger class (model-choice variants presented without cited benchmarks). This is exactly the DIA-115 trigger story.

The mandatory-vs-optional split (DIA-086): the four triggers above are MANDATORY (policy-class). Routine implementation choices inside an already-specced task are optional and remain normal coder discretion - EBDV is not a general decision bureaucracy.

### 2.2 Variant format (per-variant fields)

Each decision variant presented to the developer carries these fields:

| Field | Content | Grounding |
|---|---|---|
| title | Short name of the variant (concrete, not abstract) | MADR option titles; Prisma "concrete deliverable" title rule |
| change-description | What the change is, in plain user-observable language | Prisma "decision-led, narrative" structure; MADR Decision Outcome |
| evidence-sources | Tiered evidence list (T1/T2/T3, see 2.3) | DIA-115 evidence definition; Zimmermann "refer to actual requirements and empirical evidence"; ruvnet benchmark numbers |
| pros/cons | Good because / Bad because arguments, one per line | MADR Pros and Cons of the Options; ruvnet per-alternative Pros/Cons |
| effort | Estimated effort/cost of the variant (solo-dev relevant) | DIA-086 scope guard; InfoQ "cost efficiency of required changes"; Y-statement "accepting that: drawbacks... and effort/cost" |
| section-10-flag | Yes/No: does this variant route through the AI-devtools modernization chain (global AGENTS.md section 10)? | DIA-115: "If config/prompt changes result: route through section-10 chain" |
| Y-statement summary | One-sentence (WH)Y summary: in the context of X, facing Y, we decided for Z, and neglected W, to achieve Q, accepting D | Zimmermann Y-statement six elements (section 3.2) |

### 2.3 Evidence tiers T1/T2/T3 (with the T3-alone-insufficient rule)

Evidence is graded into three tiers so the developer can judge strength at a glance:

- **T1 - committed/archived-conspec**: evidence already persisted in the knowledge base (a conspect in `knowledge/` with locally archived sources, or a committed experiment log with reproducible commands). Strongest tier: it is verifiable locally and stable over time. Grounded in the provenance-first practice of res012 (section 6: provenance is mandatory for credible claims; "storing the archived markdown/pdf alongside the conspect is required") and the project's Archive-Before-Claim rule (DIA-072).
- **T2 - web-fresh-cited (URL + date)**: a fresh web source cited with its URL and access date (and, where relevant, publication date). Verifiable online at time of reading; weaker than T1 because the page can move. Grounded in DIA-115's own evidence definition ("cited sources - URLs/papers/benchmarks, dated") and the dated-citation practice in the MLA-cited conspects.
- **T3 - [INFERENCE] labeled**: reasoning labeled explicitly as inference, e.g. "[INFERENCE] derived from res014 ladder structure". Weakest tier.
- **T3-alone-insufficient rule**: a variant whose evidence list contains only T3 items is not admissible as a presented variant under DIA-115. Every variant must carry at least one T1 or T2 item. This is the operationalization of DIA-115's "No assumption-based options" and Zimmermann's warning against pseudo-rationale ("Avoid pseudo rationale and killer phrases; refer to actual requirements and empirical evidence on your decision records. Do compare alternatives!" - y-statement.md line 115) and of the InfoQ bad-rationale example: "End users want it, but no evidence exists of a pressing business need" (infoq-sustainable-decisions.md line 37) - a justification with no evidence is treated as unsustainable.

### 2.4 Minimum-variant rule

A decision-variant presentation must contain:

1. **>=2 real variants** (genuinely distinct options, each with the full field set of 2.2).
2. **A recommendation** (the agent states which variant it recommends and why - the MADR "Chosen option: X, because Y" pattern; ruvnet marks the chosen alternative with a checkmark).
3. **An always-available abort/status-quo variant** (the option to not change anything, or to stop the change). This keeps "do nothing" a first-class choice rather than an implicit default, and matches the ADR status vocabulary (proposed | rejected | accepted | deprecated, madr-adr-template.md line 1) where rejecting all options is a valid outcome.

The >=2 + recommendation + abort/status-quo floor guarantees the developer is never presented with a single forced option and always has an evidence-free exit - both requirements implicit in DIA-115's "no assumption-based options" and in the Y-statement's "and neglected: alternatives not chosen (not to be forgotten!)" (y-statement.md line 79).

### 2.5 Chosen-variant documentation (ticket UPDATE block)

After the developer chooses, the chosen variant (with its evidence) is recorded in the DIA ticket's UPDATE block (the `## Fix` / re-verify sections per the ticket schema). Rationale: the DIA-115 acceptance criterion is "no decision-variant presentation to the developer without evidence"; recording the chosen variant in the ticket makes the evidence durable at the point of decision and satisfies the res012 provenance principle (resolvable pointers to archived artifacts). This also closes the ana015 G2 gap class (re-verify evidence rate 51% on CLOSED tickets, 22% with empty placeholder - section 6): the ticket carries the evidence trail, not just a decision line.

## 3. Provenance of the pattern

The EBDV design is a synthesis of established decision-documentation practice. Each element traces to an archived source:

### 3.1 ADR / MADR (decision-record tradition)

- adr.github.io defines the vocabulary: "An Architectural Decision (AD) is a justified design choice that addresses a functional or non-functional requirement that is architecturally significant... An Architectural Decision Record (ADR) captures a single AD and its rationale... along with its trade-offs and consequences" (adr-org.md line 3). The site explicitly grounds its work in Sustainable Architectural Decisions by Zdun et al., "for instance the Y-statement format suggested in that article" (adr-org.md line 22).
- MADR (Markdown Architectural Decision Records) is the lean template: the full template contains Context and Problem Statement, Decision Drivers, Considered Options, Decision Outcome ("Chosen option: X, because..."), Consequences (Good/Bad), Confirmation (how compliance is verified), Pros and Cons of the Options (per-option Good/Neutral/Bad lines), and More Information ("provide additional evidence/confidence for the decision outcome here" - madr-template.md line 186). MADR 3.0.0 merged Positive/Negative Consequences into Consequences "to enable similar grammar as in Pros and Cons of the Options" (madr-template.md line 30) - the pros/cons vocabulary is the shared spine of the format.
- The MADR template source (madr-adr-template.md) additionally shows the RACI-style metadata (decision-makers / consulted / informed) and the status vocabulary, and ends with the evidence/confidence field (line 47).

### 3.2 Y-statement (Zimmermann)

The Y-statement (WH)Y format, defined in Olaf Zimmermann's "Architectural Decisions - The Making Of" (the ozimmer.ch page resolves to this article), is a six-element single sentence: context / facing / we decided for / and neglected / to achieve / accepting that (y-statement.md lines 74-81). Three direct contributions to EBDV:

1. **Neglected alternatives are mandatory**: "and neglected: alternatives not chosen (not to be forgotten!)" (line 79) - the provenance of the >=2-variants rule.
2. **Evidence over assertion**: "Avoid pseudo rationale and killer phrases; refer to actual requirements and empirical evidence on your decision records. Do compare alternatives!" (line 115) - the provenance of the T1/T2/T3 evidence requirement.
3. **Effort/cost is part of the decision**: the "accepting that" element covers "drawbacks, impact on other properties/context and effort/cost" (line 81) - the provenance of the effort field.

Zimmermann also gives the good-justification exemplars ("We have applied this design several times on successful projects...", "We performed a Proof-of-Concept and the results were convincing") vs the killer phrases ("Everybody does it. I was told that this is a good choice.", "We have always done it like that. I do not know any alternative, and I do not have time to look for one." - lines 96-104). "I do not know any alternative" is precisely the anti-pattern DIA-115 forbids.

### 3.3 Sustainable design decisions (Zdun, Capilla, Tran, Zimmermann - IEEE Software via InfoQ)

The InfoQ article supplies the sustainability criteria and the lean-documentation lesson: decision sustainability = the time period the decision stays right + the cost efficiency of changing it (infoq-sustainable-decisions.md lines 4-8). Relevant rules: (a) start lean and minimalistic - the (WH)Y approach reduces documentation to one sentence, and "architects prefer using lean documentation rather than elaborate, large decision templates" (lines 75-85) - a direct DIA-086 scope-guard alignment: EBDV must stay lean; (b) rationale guidelines: be precise, highlight decision drivers, "refer to actual project requirements, not just generic background information from the literature" (lines 123-133); (c) bad rationales are unsustainable: the "no evidence exists of a pressing business need" example (line 37). These ground the variant-format's insistence on evidence-sources and the T3-alone-insufficient rule.

### 3.4 Claude Code best practices: show evidence, not assertion

Claude Code's best-practices page provides the agent-specific rationale: "Have Claude show evidence rather than asserting success: the test output, the command it ran and what it returned, or a screenshot of the result. Reviewing evidence is faster than re-running the verification yourself, and it works for sessions you weren't watching" (claude-code-best-practices.md line 14). Two adjacent rules reinforce the design: "Give Claude a way to verify its work" (line 5 - the verification loop) and the "trust-then-verify gap" failure pattern: "Always provide verification (tests, scripts, screenshots). If you can't verify it, don't ship it" (line 213). The DIA-115 acceptance criterion ("no decision-variant presentation without evidence") is the decision-presentation analogue of "if you can't verify it, don't ship it."

Anthropic's "Building Effective Agents" adds the simplicity guard that justifies the scope-guard split: "you should consider adding complexity only when it demonstrably improves outcomes" and "Start with simple prompts, optimize them with comprehensive evaluation, and add multi-step agentic systems only when simpler solutions fall short" (anthropic-effective-agents.md lines 75-77). EBDV is a presentation-layer addition, deliberately not a new decision framework.

### 3.5 Prisma create-pr: alternatives at the end, as decisions

Prisma's create-pr SKILL.md shows the community pattern for alternatives in decision presentation: the PR body follows a "decision-led, narrative" structure with a `## Alternatives considered` section at the END (prisma-create-pr-skill.md lines 58, 95, 121, 147). Three transferable rules: (a) alternatives are framed as decisions, not non-goals - "Don't conflate 'non-goals' with 'alternatives considered'. Non-goals are scope statements ('we didn't ship X'); alternatives are decisions ('we considered X and chose Y because Z')" (line 103); (b) evidence anchors are bounded - "Cites 1-2 evidence files (tests / fixtures / e2e)" (line 77) and the behavior-change section is `## Behavior changes & evidence` (line 75); (c) rationale must follow the deliverable, not precede it (line 121) - cognitive-load argument for placing alternatives after the decision. For EBDV this means: the variant list is presented as weighed decisions with evidence, not as a menu of non-goals; and the recommendation should come with the concrete deliverable first.

### 3.6 ruvnet agentic-flow: the decision log with per-alternative evidence

ruvnet's CRISPR-Cas13 ARCHITECTURAL_DECISIONS.md is a full worked example of the variant format in practice: each ADR has Status/Date/Decision Makers, Context, Decision, Alternatives with per-alternative Pros/Cons (the chosen one marked with a checkmark), reasons with concrete measured evidence ("Benchmarks show 5-10ms median latency vs. 50ms for Node.js", "10x throughput improvement via horizontal scaling", "3x faster genomic annotation queries"), positive/negative consequences, and a closing ADR summary table with an Impact column (ADR-001..010, ruvnet-agentic-flow-decisions.md lines 274-285). The header states the format: "Each decision includes context, alternatives considered, and the rationale for the chosen solution" (line 1). This is the closest existing template to the EBDV variant format - measured evidence inside each alternative's pros/cons is exactly the T1/T2 evidence placement EBDV requires.

### 3.7 Meshtastic: rejected-alternative markers in research docs

Meshtastic's node-list-layout research.md shows rejected-alternative documentation in a spec: each decision block states the decision, the rationale (including evidence like "The codebase already uses DataStore for similar UI preferences (BLE scan prefs, node filter options, sort order)"), then alternatives each marked "Rejected - [reason]" ("Room table for layout preferences: Rejected - too heavy for 10 boolean keys. Room is appropriate for entity data, not UI presentation state", meshtastic-node-list-research.md line 7), plus requirements traceability (FR-002, FR-004, NFR-003, FR-010). The "Rejected - because" marker is the community precedent for making non-chosen variants visible and reasoned - the negation of "alternatives not chosen (not to be forgotten!)".

### 3.8 Swift Evolution and Carbon (researcher-supplied, NOT archived)

The researcher findings cite gh_grep community patterns from Swift Evolution and the Carbon language (decision proposals with considered-alternatives sections) as additional precedent. These two URLs were NOT in the Phase A archive list; per DIA-072 they are excluded from the claim body and recorded here for traceability only. The archived Prisma/Meshtastic/ruvnet sources independently establish the community pattern; Swift/Carbon add breadth but are not required for the design.

## 4. Section-10 interaction (layers on top; section 10 stays the routing gate)

EBDV is layered ON TOP of the AI-Devtools Modernization Workflow (global AGENTS.md section 10) - it does not replace or weaken it:

- **Section 10 remains the routing gate**: section 10 decides WHICH changes must go through the ai-specialist gate -> owner decision -> design -> coder -> validate -> ai-auditor -> register chain (Phase 1 GATE through Phase 6 REGISTER). EBDV changes nothing about routing.
- **EBDV is a presentation requirement inside Phase 2 (Review & Decide) for policy-class changes only**: when the specialist (or any agent) presents decision variants to the developer for a choice - the Phase 2 step - each variant must carry the EBDV field set (title, change-description, evidence-sources, pros/cons, effort, section-10-flag, Y-statement summary) with the T1/T2/T3 evidence rule and the >=2 + recommendation + abort/status-quo floor. This is precisely the DIA-115 scope ("If config/prompt changes result: route through section-10 chain", DIA-115 line 77) and the trigger story (a model-choice presentation happened without evidence, inside what is now recognized as a policy-class presentation).
- **The section-10-flag field is additive metadata**: each variant states whether it routes through section 10 (Yes for agent/skill/rule/config/plugin/MCP/permission changes; No for pure dev-infra like scripts/ or Makefile, which per the existing workflow do not route through section 10). The flag makes the routing decision visible per-variant instead of implicit.
- **Deferred items stay deferred**: the practice-protected-zone + ai-auditor enforcement item (section 5, item 4) remains deferred per the DIA-115 research-first gate - the conspect completes research; enforcement implementation and any config/prompt changes will route through the section-10 chain.

## 5. Enforcement surface (ranked cheap -> heavy per DIA-086)

The enforcement mechanism is designed AFTER research (DIA-115 line 70) with a mandatory-vs-optional split and a cheap-first ranking (DIA-086 scope guard). Four candidate surfaces, ranked by cost:

| # | Surface | Cost | Mandatory/Optional | Notes |
|---|---|---|---|---|
| 1 | `validate-decision-variants.sh` mechanical validator wired into `make test-config` | S (cheapest) | MANDATORY (tier 1) | Extends the validate-output-contracts.sh pattern (DIA-115 line 73 explicitly names this). A script that mechanically checks decision-variant blocks for: >=2 variants, abort/status-quo presence, per-variant evidence-sources field non-empty with >=1 T1/T2 item, no T3-only variant, section-10-flag present. Mechanical beats prompt: ana004 shows the philosophy scores 52/100 "embedded as intent, not enforcement" with 4 hard bypass paths outranking soft layers, and ana015 recommends "a mechanical check" for the reviewer-disposition gap. |
| 2 | OpenSpec proposal template + `## Alternatives considered` section | M | MANDATORY (tier 2) | Codify the EBDV variant format into the OpenSpec proposal template so policy-class proposals structurally contain an alternatives section (Prisma's `## Alternatives considered` pattern, meshtastic rejected-markers). Template-level enforcement is cheaper than runtime validation and matches the existing openspec-plan workflow. |
| 3 | AGENTS.md prompt rule | S (write) but WEAK alone | OPTIONAL (soft layer) | A prompt rule stating the EBDV format. Cheap to write, but ana004 demonstrates prompt-only enforcement is the weakest layer (4 hard paths bypass it); it works only as a reminder layer on top of items 1-2, never as the sole enforcement. |
| 4 | Practice-protected zone + ai-auditor review | Heavy (process) | DEFERRED | Making EBDV a practice-protected zone (agents ask guiding questions and wait) and adding an ai-auditor check for evidence compliance. Heaviest option, disproportionate for a solo-dev system today (DIA-086); deferred until items 1-3 prove insufficient. |

Rationale for the ordering: item 1 is the DIA-115 ticket's own candidate ("mechanical validator (extend validate-output-contracts.sh pattern)", line 73), is cheap to build as a bats-tested script wired into the existing test-config gate, and follows the ana015/ana004 finding that mechanical checks beat prompt rules. Items 2-3 are structural/soft complements. Item 4 is the classic heavy hammer, deferred per scope guard.

## 6. Cross-references (evidence vocabulary + adherence findings)

**Evidence vocabulary (res012-015):**

- **res012 (scientific methodology)**: supplies the evidence vocabulary EBDV operates with - structured claim objects with "prior-evidence links" and "provenance pointers (code+dataset+seed)" (res012 section 1); provenance-first generation ("every claim sentence references a resolvable pointer to archived sources", section 8); and the SCOPE GUARD lens: "prioritize light-weight provenance (archived MD + small artifact bundle), bounded evals, and selective automation" (res012 section 10). T1 = res012's archived-provenance tier; the DIA-086 scope guard is inherited verbatim into EBDV's mandatory-vs-optional split.
- **res013 (model pricing audit)**: demonstrates T2 evidence in practice - every pricing/benchmark claim carries its source (Go pricing pages, vendor pages) with per-claim attribution; the DIA-108 disposition record (a recommendation rejected because the model was not in the actual subscription list) is a worked example of evidence-carrying variant presentation and its review.
- **res014 (escalation routing)**: the "Escalate on evidence, not habit" principle (AgentPatterns codified effort+escalation policy in the instruction file; SWE-Router conditioning on observed failure) is the model-choice side of EBDV: model/tool-selection variants with >=2 candidates must carry evidence - exactly the DIA-115 trigger class. The Rung0-4 ladder itself is a T1-style committed artifact EBDV variants can cite.
- **res015 (MiMo evaluation)**: contributes the vendor-reported vs independent flagging discipline - every headline score tagged [vendor-reported]/[independent], and "no OSWorld score is asserted (none found in the archive)" as an absence-of-evidence claim per DIA-072. EBDV's T3 [INFERENCE] label is the same labeling discipline applied to reasoning rather than to scores.

**Adherence findings (ana015, ana004):**

- **ana015 G1/G2/G3**: G1 reviewer-disposition silent bypass ~81%; G2 re-verify evidence rate 51% on CLOSED tickets (22% empty placeholder); G3 interview-first gate bypass ~30% on implementation tickets. The G2 finding is the strongest argument for the chosen-variant-in-ticket-UPDATE rule (section 2.5): evidence recorded in the ticket at decision time survives to re-verify time, attacking the 22%-empty-placeholder class. ana015's recommendation to add "a mechanical check" for the reviewer-disposition gap is the same enforcement philosophy as EBDV item 1.
- **ana004 (spec-authoring philosophy)**: verdict 52/100 - "embedded as intent, not as enforcement"; 4 hard bypass paths outrank 4 soft aligned layers; "the project currently relies on the weakest possible enforcement (prompt append + convention)". This is the direct empirical justification for ranking the mechanical validator (item 1) above the AGENTS.md prompt rule (item 3) in section 5: prompt-only enforcement is the ana004-proven weak layer, and the validator is the ana004-proven remediation direction ("hard paths" as enforcement, not intent).

## 7. Source URLs and MLA citations (all archived locally in sources/)

All 10 source URLs were archived in Phase A (10/10, 0 failures). Method: trafilatura markdown extraction for all 10; no curl/crawl4ai fallback was needed. The GitHub blob URLs (3, 8, 9, 10) returned rendered Markdown content directly via trafilatura.

1. adr. "Architecture Decision Records." GitHub, 2026, adr.github.io/. Accessed 13 Aug. 2026. [archived: sources/adr-org.md]
2. Kopp, Oliver, et al. "Markdown Architectural Decision Records (MADR)." adr.github.io, 2026, adr.github.io/madr/. Accessed 13 Aug. 2026. [archived: sources/madr-template.md]
3. adr. "adr-template.md (MADR template source)." GitHub, 2026, github.com/adr/madr/blob/develop/template/adr-template.md. Accessed 13 Aug. 2026. [archived: sources/madr-adr-template.md]
4. Zimmermann, Olaf. "Architectural Decisions - The Making Of." ozimmer.ch, 2020, ozimmer.ch/practices/2020/04/27/ArchitectureDecisionMaking.html. Accessed 13 Aug. 2026. [archived: sources/y-statement.md]
5. Zdun, Uwe, Rafael Capilla, Huy Tran, and Olaf Zimmermann. "Sustainable Architectural Design Decisions." IEEE Software, via InfoQ, infoq.com/articles/sustainable-architectural-design-decisions/. Accessed 13 Aug. 2026. [archived: sources/infoq-sustainable-decisions.md]
6. Anthropic. "Building Effective Agents." Anthropic Engineering, 2024, anthropic.com/engineering/building-effective-agents. Accessed 13 Aug. 2026. [archived: sources/anthropic-effective-agents.md]
7. Anthropic. "Claude Code Best Practices." code.claude.com, 2026, code.claude.com/docs/en/best-practices. Accessed 13 Aug. 2026. [archived: sources/claude-code-best-practices.md]
8. Prisma. "create-pr SKILL.md." GitHub, 2026, github.com/prisma/prisma/blob/main/skills-contrib/create-pr/SKILL.md. Accessed 13 Aug. 2026. [archived: sources/prisma-create-pr-skill.md]
9. ruvnet. "ARCHITECTURAL_DECISIONS.md (CRISPR-Cas13 pipeline)." GitHub, 2025, github.com/ruvnet/agentic-flow/blob/main/agentic-flow/examples/crispr-cas13-pipeline/docs/ARCHITECTURAL_DECISIONS.md. Accessed 13 Aug. 2026. [archived: sources/ruvnet-agentic-flow-decisions.md]
10. Meshtastic. "research.md (node-list-layout spec, 20260507-161758)." GitHub, 2026, github.com/meshtastic/Meshtastic-Android/blob/main/specs/20260507-161758-node-list-layout/research.md. Accessed 13 Aug. 2026. [archived: sources/meshtastic-node-list-research.md]

**Not archived / researcher-supplied (DIA-072 policy):** Swift Evolution and Carbon decision-proposal patterns were identified by the researcher (gh_grep community search) but were NOT in the Phase A URL list, so they are not archived here and no claim is asserted from them; they are recorded in section 3.8 for traceability only. No URL failed archival (0 failures).

Project-internal references (not external sources): docs/dev-infra-audit/tickets/DIA-115-evidence-based-decision-variants.md (ticket, trigger story, verification gate), docs/dev-infra-audit/tickets/DIA-086-scientific-methodology-workflow.md (SCOPE GUARD), knowledge/res012-scientific-methodology/ (evidence/provenance vocabulary, SCOPE GUARD), knowledge/res013-opencode-model-pricing-audit/ (T2 evidence practice, DIA-108 disposition), knowledge/res014-model-escalation-routing/ (escalate-on-evidence, Rung0-4 ladder), knowledge/res015-mimo-v25-pro-evaluation/ (vendor-reported/independent labeling), knowledge/ana015-workflow-adherence-audit/ (G1/G2/G3, mechanical-check recommendation), knowledge/ana004-spec-authoring-philosophy/ (52/100 intent-not-enforcement), global AGENTS.md section 10 (AI-Devtools Modernization Workflow).

## 8. Claim-to-source mapping (key claims)

| Claim | Source |
|---|---|
| ADR captures a single AD and its rationale, trade-offs and consequences; ADR org work based on Sustainable Architectural Decisions incl. Y-statement | sources/adr-org.md (lines 3, 22) |
| MADR full template: Considered Options, Decision Outcome, Consequences, Confirmation, Pros and Cons of the Options, More Information (evidence/confidence) | sources/madr-template.md (lines 124-187); sources/madr-adr-template.md (lines 1-47) |
| Y-statement six elements (context/facing/decided for/neglected/to achieve/accepting); neglected alternatives "not to be forgotten"; avoid pseudo rationale, refer to empirical evidence, do compare alternatives; good vs killer justifications | sources/y-statement.md (lines 66-83, 92-104, 114-115) |
| Decision sustainability = duration right + cost efficiency of change; lean (WH)Y documentation preferred; rationale guidelines (precise, decision drivers, actual requirements); no-evidence rationale is unsustainable | sources/infoq-sustainable-decisions.md (lines 4-8, 75-85, 123-133, 37) |
| Show evidence rather than asserting success; give Claude a way to verify its work; trust-then-verify gap - "If you can't verify it, don't ship it" | sources/claude-code-best-practices.md (lines 5, 14, 213) |
| Add complexity only when it demonstrably improves outcomes; simplest solution first | sources/anthropic-effective-agents.md (lines 13, 75-77) |
| PR body: decision-led narrative, ## Behavior changes & evidence (1-2 evidence files), ## Alternatives considered at END, alternatives = decisions not non-goals, concrete titles | sources/prisma-create-pr-skill.md (lines 45-46, 58, 75-77, 95, 103, 121, 142, 147) |
| Decision log format: Status/Date/Decision Makers, Context, Decision, per-alternative Pros/Cons with measured evidence, chosen marked, positive/negative consequences, ADR summary table with Impact | sources/ruvnet-agentic-flow-decisions.md (lines 1-2, 12-29, 47-56, 274-285) |
| Alternatives marked "Rejected - because" with rationale and requirements traceability (FR/NFR refs) | sources/meshtastic-node-list-research.md (lines 3-9, 14-21, 33-35, 45-47) |
| DIA-115: mandatory evidence for decision-variant presentations, no assumption-based options, trigger story (DIA-111 line 150), scope all agents, research-first, candidate enforcement surfaces incl. mechanical validator (validate-output-contracts.sh pattern), section-10 routing | docs/dev-infra-audit/tickets/DIA-115-evidence-based-decision-variants.md (lines 3-7, 40-79) |
| DIA-086 SCOPE GUARD: solo-dev, cheap and actually-used, weight overhead | docs/dev-infra-audit/tickets/DIA-086-scientific-methodology-workflow.md (line 74) |
| Evidence vocabulary: structured claim objects with prior-evidence links and provenance pointers; provenance mandatory; SCOPE GUARD lens | knowledge/res012-scientific-methodology-conspect.md (sections 1, 6, 10) |
| Escalate on evidence, not habit; codified escalation policy; model choice conditioned on evidence | knowledge/res014-model-escalation-routing-conspect.md (section 2, 4) |
| Vendor-reported vs independent labeling; absence-of-evidence claims per DIA-072 | knowledge/res015-mimo-v25-pro-evaluation-conspect.md (section 3, 7) |
| ana015: G1 81% silent bypass, G2 51% evidence rate / 22% empty placeholder, G3 ~30% bypass; mechanical check recommendation | knowledge/ana015-workflow-adherence-audit-report.md (lines 14, 247-256, 272-273) |
| ana004: 52/100 embedded as intent not enforcement; 4 hard bypass paths; weakest enforcement = prompt append + convention | knowledge/ana004-spec-authoring-philosophy-report.md (lines 7, 39, 92, 251) |
| Section 10: AI-devtools changes route through specialist gate -> owner decision -> design -> coder -> validate -> ai-auditor -> register | global AGENTS.md section 10 (AI Devtools Modernization Workflow) |
