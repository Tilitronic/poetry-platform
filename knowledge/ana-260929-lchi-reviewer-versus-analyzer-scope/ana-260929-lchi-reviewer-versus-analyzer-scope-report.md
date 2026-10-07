# Reviewer vs Analyzer: Do We Need Both Lanes?

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/session/messages.jsonl
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket: DIA-260929-nc6w (agent-role consolidation study, lane: reviewer+analyzer).
Question: do we need both lanes, or keep the reviewer only (the developer's current lean)?
Verdict up front: **keep both. The merge recommendation is declined with evidence.**

## 1. Method

MECE split of the two lane contracts (purpose, permissions, artifacts, triggers, models),
inversion test ("what concrete capability loses its home if one lane dies"), and
frequency evidence from session logs. Raw logs reduced in-worker per the data-reducer
threshold rule (messages.jsonl = 52.8 MB / 130,148 lines; registry.jsonl = 728 KB /
2,790 lines; both over ~100 KB, so only aggregates entered context - never the blobs).

## 2. Contracts side by side (Sub-question 1)

| Dimension          | reviewer                                              | analyzer                                                  |
|--------------------|-------------------------------------------------------|-----------------------------------------------------------|
| Definition files   | orchestratorPrompt (4025 chars) in .opencode/oh-my-opencode-slim.jsonc + agent block in opencode.jsonc. NO .opencode/agents/reviewer.md file exists (0 matches in agents/). | .opencode/agents/analyzer.md (71 lines) + orchestratorPrompt (1919 chars) + opencode.jsonc block. |
| Purpose            | Two-axis review (Standards + Spec fidelity) of a diff since a FIXED git point; axes reported separately, never merged. | Multi-method analysis (5-Whys, inversion, MECE, OODA) + terminal/Mermaid visualization + persistent report artifacts. |
| Permissions        | `edit: deny, bash: deny, task: deny` (opencode.jsonc L306-313). Cannot even run `git diff` itself - the plugin injects a pinned envelope. | `edit: knowledge/* only, bash: allow, task: deny` (L267-278, artifact-producer tier per DIA-057/F3). |
| Produced artifact  | Transient findings in-session ([SEVERITY] file:line format). .opencode/session/review-packet/ holds working material; memory-shelf.yaml has NO `reviews` key - reviews are gates, not knowledge. | `knowledge/ana-<id>-<topic>/...-report.md` with parseable ANALYZER-OUTPUT-CONTRACT header; 16 ana-* dirs on disk, 59 entries under shelf.analyses. |
| Invocation trigger | Mandatory chain step: AGENTS.md 2.3 step 4, 2.3.1 re-review loop, 2.4 step 4 (dev-infra), review matrix L111. Every completed feature passes it. | Demand-driven, NOT routed by AGENTS.md sections 2.2-2.5 at all (only the section-9 naming table). Routed from: orchestrator OMO rules (ID ALLOCATION ana-type, ANALYSIS GATE), NEXT-RUN.md delegation map L154 ("analysis->@analyzer"), architector step 4 (tradeoffs), openspec-plan interview ("dispatch @analyzer for trade-off analysis"). |
| Model (mimo-balanced, active preset) | opencode-go/deepseek-v4.1-flash variant high, temp 0.1; fallback qwen3.8-flash. Prompt mandates: "intentionally different model family than coder". Coder = mimo-v2.6-flash, so family split holds. | opencode-go/qwen3.8-flash variant high; fallback deepseek-v4-flash. analyzer-escalated = deepseek-v4.1-flash variant max. Evidence: oh-my-opencode-slim.jsonc L339-370, L490-506; knowledge/model-registry.yaml L11-25. |
| Skills wired       | code-review-fowler, review-re-verify, book-rag. | teaching, mermaid-diagramming, console-charting, data-reducer, openspec-explore, debugging-workflow + websearch MCP. |
| Escalation lane    | None (coder-escalated is implementation, not review). | analyzer-escalated: hidden, orchestrator-only, one-shot, for "cannot comprehend domain" / abort-on-complexity (opencode.jsonc L289-305). |

## 3. What each uniquely provides (Sub-question 2)

Reviewer-unique: two-axis split against a fixed point; Fowler 12-smell baseline as
labelled heuristics; re-review cycle (findings-resolution table, max 2 cycles,
verified-closed/still-open/partial); severity ladder; fresh-context evaluation rule
(no coder chain-of-thought); verification-evidence enforcement on coder handoffs;
mechanical git-envelope injection by delegation-observer.ts (DIA-260827-4q3h:
`reviewer_envelope_attached` 22x, `reviewer_envelope_blocked` 12x in the
post-2026-09-16 registry window).

Analyzer-unique: analytical method battery; terminal + Mermaid visualization toolchain;
persistent knowledge artifacts with output-contract header validated by
scripts/validate-output-contracts.sh; EBDV variant tables (DIA-115 output shape for
policy-class decisions); analyzer-escalated escape hatch; data-reducer threshold rule
("Currently wired: analyzer / analyzer-escalated only", data-reducer SKILL.md, per
DIA-260826-6mhy); analysis-pending gate (live mechanism - .opencode/session/
analysis-pending.json last armed 2026-09-25 for a conspecter artifact, status
"verified").

## 4. Structural difference test (Sub-question 3)

Does the fixed-point precondition alone force two lanes? No - it is one of three
independent axes; any one of the three alone defeats a merge:

1. Permission asymmetry (decisive). Reviewer is bash:deny/edit:deny - four-eyes
   independence expressed as inability to mutate or self-serve evidence; its git
   envelope arrives pre-pinned from outside. Analyzer is bash:allow/edit:knowledge/*.
   A merged lane must take the UNION of permissions, which destroys the reviewer's
   read-only invariant (a reviewing lane that can run arbitrary bash and write files
   is no longer the independent pair of eyes the ai--1/failures.md incident history
   built it to be), or the INTERSECTION, which leaves the analyzer unable to write
   reports or render diagrams. Neither intersection nor union satisfies both jobs.
2. Serialization invariants differ. OMO batch rule: "NEVER batch: two analyzers,
   coder+reviewer (reviewer needs fixed point)". Reviewer is serial-after-coder;
   analyzer is parallel-fan-out-capable across single-writer knowledge dirs. One lane
   cannot hold both scheduling signatures without the orchestrator keeping two
   personas anyway.
3. Persistence planes differ. Reviewer findings are consumed and disposed by the
   developer inside the feature cycle (transient gate; zero shelf presence).
   Analyzer reports are long-lived knowledge (59 shelf.analyses entries). Merging
   conflates a quality gate with a knowledge producer.

So: the fixed point forces the coder->reviewer serialization, but the merge blocker is
the permission asymmetry plus model-family diversity (reviewer must stay a different
family from coder; analyzer runs a third family; a merged lane collapses to two
families and violates the diversity rule or the analysis routing).

## 5. Overlap analysis (Sub-question 4)

Genuine collisions (thin):
- Both emit written findings with severity/confidence language.
- Both read architecture.md / AGENTS.md / .sdd/ (duplicated design-authority knowledge).
- Both can opine on design quality (reviewer: code-vs-design; analyzer: option-vs-option).

Apparent-only overlaps that do NOT collide:
- "Verification" vs "analysis": reviewer is diff-bound - it cannot answer any question
  not expressible as "does this committed delta match the spec". The current dispatch
  (this study) is the proof: it is a 4-lane analysis with no fixed point and no diff;
  a reviewer has no contract under which to accept it.
- Findings format similarity is cosmetic; reviewer findings drive a fix loop with
  developer disposition; analyzer findings drive decisions with evidence tiers.
- No mechanical routing confusion observed: 0 analyzer-attributed ROUTING_VIOLATION
  rows (registry: 14 ROUTING_VIOLATION, all coder-attributed).

## 6. Invocation frequency (Sub-question 5)

Source: delegation events in .opencode/session/messages.jsonl, window
2026-08-07T00:58Z..2026-09-29 (130,148 lines; reduced in python3 worker:
input 52.8 MB -> result ~0.5 KB). registry.jsonl (post-rotation, covers
2026-09-16 onward, 2,790 rows) does not carry per-agent dispatch names except via
envelope/gate events; messages.jsonl is the attribution source of record.

```
dispatch counts (delegation events, ~7.7 weeks)
coder               | 1266  ########################################
openspec-plan       |  393  ############
ai-specialist       |  146  ####
reviewer            |  131  ####
memory-manager      |  120  ###
ai-auditor          |  113  ###
code-navigator      |  112  ###
analyzer            |   49  #
researcher          |   37  #
conspecter          |   23
architector         |   20
analyzer-escalated  |    6
coder-escalated     |    1
```

Monthly split: reviewer 70 (Aug) / 61 (Sep, partial to the 29th) - steady.
analyzer 18 (Aug) / 31 (Sep) - RISING, +72% while reviewer is flat. Reviewer:coder
ratio ~1:10 matches the pipeline (one review per completed slice).
AGENTS.md routing: 6 functional reviewer mentions in 2.3/2.3.1/2.4 + review matrix;
0 functional analyzer routing in 2.2-2.5 (by design - the analyzer serves the
orchestrator/architect/openspec-plan demand plane, not the implementation chain).
Neither number is near zero; neither lane is vestigial.

## 7. Keep-one-lane variants (Sub-question 6)

Keep reviewer only (the developer's lean). Concrete orphans:
- No writer for knowledge/ana-* reports (reviewer edit:deny cannot write anywhere).
- EBDV (DIA-115) variant tables for policy decisions lose their producer lane; the
  orchestrator's own prompt bans it from doing analysis ("no research, no analysis",
  delegation-only constraint) - the variants would have to be produced by... nobody.
- analyzer-escalated escape hatch loses its base lane (escalated config, hidden flag,
  steps:50, budgeted one-shot rule all keyed to "base analyzer reports cannot
  comprehend domain").
- analysis-pending gate loses its consumer (gate exists to block dispatching @analyzer).
- data-reducer wiring (only analyzer/analyzer-escalated) becomes dead config.
- Mermaid/console/teaching skills lose their only agent holder.
Rules needing REWRITE (not deletion): NEXT-RUN.md delegation map L154; OMO ID ALLOCATION
rule (ana type); OMO ANALYSIS GATE rule; architect prompt steps 4-5; openspec-plan
interview rule; AGENTS.md section 9 rows; scripts/allocate-id ana type;
validate-output-contracts.sh analyzer schema; memory-manager "documented impact"
trigger loses one of its two producers.
This is ~12 rewrite sites for one lane's 49 dispatches - and those 49 were NOT
idle: they include the analysis plane that feeds architect trade-offs and spec
interviews.

Keep analyzer only. Concrete orphans: four-eyes diff review against a pinned fixed
point; the whole re-review cycle (2.3.1: verified-closed/still-open/partial, max 2
cycles, cycle-cap trigger for coder-escalated); Fowler baseline; reviewer_envelope
plugin mechanism (22 attaches/12 blocks in 2 weeks); severity-ladder findings driving
developer disposition; review matrix row for dev-infra (2.4). The analyzer's
bash:allow/edit:knowledge-* permissions are exactly the wrong shape for an
independent gate. Rules needing rewrite: AGENTS.md 2.3 step 4, 2.3.1 (entire
sub-section), 2.4 step 4, 2.5 review matrix, DIA-175 same-session/cycle-cap
references, delegation-observer envelope code. Heavier than the reviewer-only list,
and it removes the mandated quality gate for EVERY feature - unacceptable.

## 8. Cost of keeping both (Sub-question 7)

- Prompt surface: reviewer 4025 chars (config-only), analyzer 1919 + 3056 chars
  (config + agents file). Two surfaces, both documented.
- Maintenance churn (git -S over oh-my-opencode-slim.jsonc): reviewer 18 commits,
  analyzer 19 commits - comparable, steady, no runaway duplication (the churn is
  lane-SPECIFIC edits like envelope work or data-reducer wiring, not the same edit
  applied twice).
- Model budget: both opencode-go, different families by design (deepseek-v4.1 vs
  qwen3.8); no savings from merging because the merge would collapse the diversity
  rule anyway. Total analyzer+reviewer dispatch volume 180 of 4516 (~4%).
- Duplicated design-authority knowledge: both READ architecture.md/AGENTS.md/.sdd/.
  Read-only duplication of stable files costs nothing to maintain - it is context,
  not config.

## 9. EBDV decision variants (DIA-115 required shape)

Option A - STATUS QUO: keep both lanes (abort variant).
  Evidence: sections 4-8 above (Tier-1: messages.jsonl counts; opencode.jsonc
  L267-313; oh-my-opencode-slim.jsonc L339-370; delegation-observer.ts
  L1883-1998; data-reducer SKILL.md "wired: analyzer only").
  Pros: all invariants intact (read-only reviewer, family diversity, serialization,
  analysis gate); zero rewrite; analyzer demand is rising (+72% MoM).
  Cons: two prompts to maintain; ~4% dispatch volume split across them.
  Effort: 0. Section-10 routing flag: none needed (no change).

Option B - KEEP REVIEWER ONLY (developer lean).
  Evidence: section 7 orphan list (Tier-1: EBDV rule text in OMO orchestrator prompt;
  NEXT-RUN.md L154; DIA-260826-6mhy changelog row "wire data-reducer ... analyzer";
  59 shelf.analyses entries with no other producer). Analyzer-escalated prompt:
  oh-my-opencode-slim.jsonc L810-811.
  Pros: deletes analyzer surface; simpler delegation directory.
  Cons: kills the entire knowledge-analysis plane; ~12 rewrite sites; EBDV,
  trade-off analysis feeding architecture/spec flows, and the analysis-pending gate
  have no home; contradicts rising analyzer demand.
  Effort: M (~2-4h config + doc rewrites + validator/schema edits, then re-validation
  and restart smoke). Section-10 routing flag: YES - agent-policy/config change;
  needs @ai-specialist gate, @ai-auditor review, CHANGELOG entry.

Option C - MERGE INTO ONE DUAL-MODE LANE.
  Evidence: permission-union/intersection argument, section 4 (Tier-1:
  opencode.jsonc blocks; OMO batch rule "coder+reviewer (reviewer needs fixed
  point)"; [INFERENCE] support: the union-permission independence risk is inferred
  from the prompt-stated design intent, never sole basis).
  Pros: one surface.
  Cons: breaks reviewer read-only invariant or analyzer output capability (both
  fatal); single prompt roughly doubles; scheduling personas split anyway; worst of
  all options.
  Effort: L (new contract, gate redesign, envelope plugin rewrite). Section-10
  routing flag: YES.

## 10. Recommendation

Keep both (Option A). BECAUSE the lanes are not duplicates but opposites on the axis
that matters for independence: the reviewer is a deliberately powerless gate (no bash,
no edit, externally pinned evidence, different model family from the coder) that
serializes after every implementation, while the analyzer is an empowered
artifact-producer (bash, knowledge writes, escalating model ladder) that serves the
demand plane of architecture and spec work. Frequency data shows both live (131 vs 49
delegations in 7.7 weeks, reviewer steady / analyzer rising), and every merge variant
either destroys a stated invariant or orphans 12+ config sites that reference
analyzer-specific machinery (EBDV, analysis-pending gate, data-reducer wiring,
analyzer-escalated).

Position on the developer's lean: **disagree.** The lean ("keep the reviewer") reads
the two lanes as overlapping because both "write findings". The evidence says
otherwise: review findings are transient gates with zero shelf presence; analysis
findings are the 59-entry knowledge shelf. Cutting the analyzer would not shed
redundant weight - it would amputate the project's only persistent-analysis organ to
save one 1,919-char prompt. If prompt count is the real cost driving the lean, the
lazy fix is A (zero deletion), not B.

OPEN_QUESTIONS
- Is there any completed study ticket where a reviewer-run analysis was actually
  substituted for an analyzer dispatch? None found in this window (would be a
  ROUTING_VIOLATION or envelope event; zero observed). If the developer knows of
  such cases, that would be the strongest B evidence - worth asking.
- analyzer-escalated (6 dispatches) could itself be questioned as a third lane; it
  was out of scope here but rides on analyzer's contracts, so A is its precondition.
- The dispatch-name gap in registry.jsonl (agents only in envelope/gate events) makes
  registry-based frequency analysis secondary; noted so future studies use
  messages.jsonl delegations.
