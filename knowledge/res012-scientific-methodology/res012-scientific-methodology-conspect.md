Res012: Scientific Methodology for AI-driven Research Agents

Scope: synthesis of archived sources in knowledge/res012-scientific-methodology/sources/. Ten topical sections follow: (1) structured hypothesis/claim objects, (2) novelty checks, (3) experiment journals/logs, (4) falsification, (5) independent verification/reviewer critique, (6) provenance/constrained citations, (7) test-driven SWE agents, (8) eval-driven development, (9) documented failure modes, (10) overhead/cost with SCOPE GUARD lens (solo developer). Each section includes a confidence assessment and MLA-cited sources (archived local files).

1. Structured hypothesis / claim objects

Summary: Several projects (AI Scientist v1/v2; AutoSci; AgentLaboratory) treat research outputs as discrete, machine-readable artifacts: hypothesis statements coupled with required data, code, metrics, and acceptance criteria. Best practice is an explicit schema for a hypothesis object containing: id, short claim, rationale, prior-evidence links, proposed experiment(s), success criteria, expected falsifiers, and provenance pointers (code+dataset+seed). This enables automated tracking, regression, and meta-analysis.

Confidence: High. Grounding: AI Scientist v1/v2 (Lu) demonstrates explicit idea->implementation artifactization; AutoSci and AgentLaboratory provide practical templates and code for structured experiment manifests (knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md; 004-arxiv-org-abs-2504-08066.md; 009-github-com-samuelschmidgall-agentlaboratory.md).

Select citations (MLA):
- Lu, Christopher. "The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery." arXiv, 2024. knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md.
- "Agent Laboratory." arXiv, 2025. knowledge/res012-scientific-methodology/sources/008-arxiv-org-abs-2501-04227.md; knowledge/res012-scientific-methodology/sources/009-github-com-samuelschmidgall-agentlaboratory.md.

2. Novelty checks

Summary: Automated novelty assessment mixes retrieval-based similarity checks (Self-RAG, MIRAGE), citation graph overlap, and lightweight reproducibility probes. The approach is two-tier: (A) offline literature similarity to detect close prior art; (B) fast sanity experiments to test whether the claimed phenomenon is non-trivial. Systems combine dense retrieval with deterministic plagiarism/overlap heuristics to avoid overclaiming.

Confidence: Medium-High. Grounding: Self-RAG and provenance work (Self-RAG; MIRAGE; RECLAIM) and ScienceAgentBench describe retrieval+eval pipelines used for novelty and reproducibility screening (sources: 051-selfrag..., 054-arxiv-org-html-2409-11242v4.md, 023-osu-nlp-group-scienceagentbench.md).

3. Experiment journals / logs

Summary: Machine-executed experiments must produce tamper-evident experiment journals: timestamped logs, committed code+seed, environment capture (container image or hashed package list), input data snapshot, and metrics with raw outputs. Journals serve as both reproducibility artifacts and as the primary input to automated reviewers. Formats range from structured JSON manifests to human-readable experiment notebooks with a formal header schema.

Confidence: High. Grounding: AI Scientist papers and AutoSci/AgentLaboratory implementations emphasize experiment traceability; provenance papers and Self-RAG recommend environment capture and retrieval-friendly artifacts (sources: 001, 004, 051).

4. Falsification

Summary: Operationalizing Popperian falsification in agent workflows requires (1) explicit falsifiers attached to hypotheses, (2) negative-control experiments, and (3) automated detection of overfitting/shortcut solutions via stress tests. POPPER, DASES, and HEP literature provide frameworks for automated falsification and adversarial checks integrated into the experiment harness.

Confidence: Medium. Grounding: POPPER and related falsification toolkits (sources: 023-github-com-snap-stanford-popper.md; 016-arxiv-org-abs-2502-09858.md) outline algorithmic falsification; practical adoption is nascent but feasible.

5. Independent verification / reviewer critique

Summary: Two complementary mechanisms: (A) automated reviewers trained or rule-based (AI Scientist automated reviewer); (B) human-in-the-loop peer review with structured review forms linking to experiment journals and novelty checks. Automated reviewers can triage or score papers but must be calibrated against human reviewers to avoid acceptance of shallow artifacts.

Confidence: Medium. Grounding: AI Scientist presents an automated reviewer with validated near-human performance on conference-style judgments; ScienceAgentBench and community eval guidance (Anthropic, LangChain) show how to benchmark reviewers and agent outputs (sources: 001, 033-ScienceAgentBench, 039-anthropic-demystifying-evals-for-ai-agents.md).

6. Provenance / constrained citations

Summary: Provenance is mandatory for credible claims. Constrained citation practices combine Self-RAG retrieval provenance, in-line provenance pointers in generated text, and selective quoting of primary sources. Systems must embed resolvable pointers to archived artifacts (dataset versions, code repo commits, PDF snapshots). For automated conspects, storing the archived markdown/pdf alongside the conspect is required.

Confidence: High. Grounding: Self-RAG, MIRAGE, RECLAIM, and IBM Self-RAG implementations emphasize provenance as core to traceability (sources: 051, 052, 054).

7. Test-driven SWE agents

Summary: Treat agent behaviors as software units: write unit/integration-style tests for prompt flows, tool usage, sandboxed execution, and failure modes. Projects such as SWE-Agent, TDFlow, and Otter propose harnesses and CI integration (SWE Bench, TeamCity blog) for continuous evaluation. Test-first development reduces brittle emergent behavior in engineering agents.

Confidence: High. Grounding: SWE-agent repositories and TDFlow/EACL paper examples (sources: 028-github-com-swe-agent-swe-agent.md; 036-aclanthology-org-2026-eacl-long-70-pdf.pdf; 041-blog-jetbrains-teamcity-2025-09-testing-ai-coding-agents-with-teamcity-and-swe-bench.md).

8. Eval-driven development

Summary: Develop by metrics: define evaluation harnesses early, instrument experiments, and use continuous evaluation to guide iteration. Anthropic and LangChain engineering posts describe practical eval pipelines and metrics-as-contracts for agent development. Beware of narrow metric gaming; include multiple complementary evaluations including robustness and failure-case coverage.

Confidence: High. Grounding: Anthropic, LangChain, JetBrains and practitioner posts detail concrete pipelines and pitfalls (sources: 039, 040, 041, 042-rahulkashyap.md).

9. Documented failure modes

Summary: Surveys and recent analyses catalog failure classes: hallucination, reward hacking, shortcut learning, brittle tool use, data provenance breaks, and untraceable stochastic nondeterminism. Instrumentation should capture these classes and signal remediation strategies with priority labels.

Confidence: High. Grounding: Failure-mode literature and surveys in the archive list multiple taxonomies and incident reports (sources: 065-arxiv-org-abs-2601.03315v1.md; 066-arxiv-org-html-2509-08713.md; 067-arxiv-org-html-2608-05179.md).

10. Overhead / cost with SCOPE GUARD lens (solo developer)

Summary: Several systems present high compute, storage, and human-supervision costs. For a solo developer, adopt a SCOPE GUARD: prioritize light-weight provenance (archived MD + small artifact bundle), bounded evals (small seed experiments, synthetic controls), and selective automation (automate scaffolding, not full end-to-end). Avoid heavy-model retraining and large-scale compute unless team/resources scale. Many published systems assume cluster resources and reviewer networks; these are disproportionate to solo workflows.

Confidence: High. Grounding: AI Scientist cost claims (low $/paper at scale) depend on cloud credits and batching; ScienceAgentBench and Aviary note compute and dataset scale. Practitioner posts (JetBrains, LangChain) give pragmatic CI/bench guidance for constrained resources (sources: 001, 033, 047-arxiv-org-abs-2412-21154.md; 041, 040).

Excluded claims per DIA-072: No claims in this conspect rely on sources outside the archived set. Any assertion not traceable to archived artifacts was excluded.

Concluding recommendations (practical checklist for a solo developer):
- Adopt a minimal hypothesis schema and capture every experiment as a journal entry (ID, code commit, env hash, seed, raw outputs).
- Integrate lightweight novelty checks via local RAG against archived corpus and a small external index (mirror of primary papers).
- Implement unit-like tests for prompt/tool flows and run them in CI (SWE-bench style) before large experiments.
- Use provenance-first generation: every claim sentence references a resolvable pointer to archived sources.
- Maintain a failure-mode ledger and instrument experiments to surface known classes.

Local sources (archived files used):
- knowledge/res012-scientific-methodology/sources/001-arxiv-org-abs-2408-06292.md (AI Scientist v1)
- knowledge/res012-scientific-methodology/sources/006-pub-sakana-ai-ai-scientist-v2-paper-paper-pdf.pdf (AI Scientist v2)
- knowledge/res012-scientific-methodology/sources/004-arxiv-org-abs-2504-08066.md (AI Scientist v2 arXiv)
- knowledge/res012-scientific-methodology/sources/008-arxiv-org-abs-2501-04227.md (Agent Laboratory)
- knowledge/res012-scientific-methodology/sources/023-osu-nlp-group-github-io-scienceagentbench.md (ScienceAgentBench)
- knowledge/res012-scientific-methodology/sources/051-selfrag-github-io.md (Self-RAG provenance)
- knowledge/res012-scientific-methodology/sources/028-github-com-swe-agent-swe-agent.md (SWE-agent)
- knowledge/res012-scientific-methodology/sources/036-aclanthology-org-2026-eacl-long-70-pdf.pdf (TDFlow / EACL)
- knowledge/res012-scientific-methodology/sources/039-www-anthropic-com-engineering-demystifying-evals-for-ai-agents.md (Anthropic evals)
- knowledge/res012-scientific-methodology/sources/041-blog-jetbrains-com-teamcity-2025-09-testing-ai-coding-agents-with-teamcity-and-swe-bench.md (SWE bench CI)
- knowledge/res012-scientific-methodology/sources/065-arxiv-org-abs-2601.03315v1.md (Failure-mode survey)

---
Document prepared by conspecter lane on 2026-08-11. All citations point to locally archived artifacts under knowledge/res012-scientific-methodology/sources/.

(End of conspect)
