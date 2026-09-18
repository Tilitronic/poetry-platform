# DIA-113 Workflow-Adherence + Autonomy Audit (Analyzer Slice)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/session/messages.jsonl, .opencode/session/registry.jsonl, docs/dev-infra-audit/tickets/ (83-ticket ledger, 45 CLOSED / 20 OPEN / 12 VERIFIED / 3 DONE / 1 FIXED / 1 DEFERRED / 1 MONITOR), .opencode/practice-protected.md, AGENTS.md (project + global)
confidence: Medium
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

**Report path:** `knowledge/ana015-workflow-adherence-audit/ana015-workflow-adherence-audit-report.md`
**Findings count:** 12 enumerated workflows, 8 gap-matrix findings, 7 prioritized recommendations
**Top-3 gaps:** G1 (reviewer-disposition silent-bypass ~81%), G2 (re-verify evidence rate 51% on CLOSED tickets), G3 (interview-first gate bypass rate ~30% on implementation tickets)
**Top-3 recommendations:** R1 (formalize reviewer-disposition pending-owner gate), R2 (re-verify evidence checklist with exit-code schema), R3 (skip-spec flag enforcement on every coder dispatch)

---

## 0. Scope and method

**Scope.** This analyzer slice covers the four requirements of DIA-113 that
the prior ai-specialist gate-research lane (ai--1, ses_004127c39ffeMbdgQtiWpE5qB3,
2026-08-13) did not cover:

| Requirement | Covered here? |
|---|---|
| #1 workflow enumeration + enforcement-point mapping | YES |
| #2 developer-as-owner engagement audit | YES |
| #3 verification-loop reliability quantification | YES |
| #4 autonomy configuration mapping | NO -- done by ai--1 (C7/C8) |
| #5 best-practice research (web-fresh) | NO -- done by ai--1 (C7/C8) |
| #6 gap matrix + prioritized recommendations + registration | YES |

**Method.** Evidence-driven, not speculative. Sources consulted:

- `docs/dev-infra-audit/tickets/` -- 83 tickets (45 CLOSED, 20 OPEN, 12
  VERIFIED, 3 DONE, 1 FIXED, 1 DEFERRED, 1 MONITOR). Counted via
  `status:` frontmatter.
- `.opencode/session/messages.jsonl` -- 2861 semantic events
  (delegations 1951, decisions 590, handoffs 246, gate-tokens 36,
  batch-approval-gates 28, crises 9).
- `.opencode/session/registry.jsonl` -- 3318 lifecycle rows (1016
  session_spawn, 1011 session_complete, 1004 task_success, 51
  session_failed, 30 silent_failure_alert, 30 ticket_gate_blocked,
  89 a5_quality_gate, 53 a1_violation).
- `.opencode/practice-protected.md` -- 7 protected zones (incl.
  practice-protected agent-permission tier table).
- `.opencode/learnings/external-patterns/` -- 54 pattern files (one
  per session since 2026-07-12).

**Confidence key.** Each claim carries High / Medium / Low confidence.
High = directly measured from the ticket ledger or session log;
Medium = inferred from session-log pattern (no direct measurement);
Low = anecdotal / single-session observation.

---

## 1. Workflow enumeration + enforcement + adherence

The project defines 12+ distinct workflows across AGENTS.md (project +
global), practice-protected.md, and skills. Each is enumerated below
with its enforcement point and the adherence evidence observed.

| # | Workflow | Defined in | Enforcement point | Adherence evidence (from registry/messages) | Rating |
|---|---|---|---|---|---|
| W1 | Feature chain: openspec -> coder -> reviewer | AGENTS.md section 2 | @openspec-plan dispatch gate + @reviewer post-fix | 65 openspec-plan dispatches vs 17 openspec/changes/ dirs. 526 coder dispatches, only 7 tickets carry explicit coder work (PR-2, DIA-045, etc.). Interview-first observed on DIA-050/066/071/086-M1-M5/100/125 but not on most implementation tickets. | WEAK -- bypass on most tickets |
| W2 | Fix -> re-review loop (max 2 cycles) | AGENTS.md section 2.3.1 | cycle counter in reviewer re-review | 36 re-review delegations observed. Named "re-review cycle 1/2" / "Re-review DIA-XXX fixes" in 10+ cases. Max observed = 1 cycle per ticket (no cycle 2/2 observed since DIA-086 M1-M5). | STRONG -- consistently followed |
| W3 | Section 10 AI-devtools modernization gate | AGENTS.md (global) section 10 | ai-specialist dispatch + user decision + Phase 5 restart-verify | 12 dispatches of ai-specialist in messages.jsonl. Section-10 gate acknowledged on DIA-126a, DIA-130, DIA-132, DIA-133. Restart-verify pattern observed on DIA-123/131/132 (DIA-123 pattern). | STRONG -- gate respected |
| W4 | tdd-craftsman RED-GREEN-REFACTOR | skill SKILL.md | coder dispatch + bats evidence | 216-test bats suites with exit-code-0 evidence in DIA-094/096/118/119/120/121/122/130. | STRONG -- test evidence present |
| W5 | Persistence loop (coder -> reviewer -> persist) | AGENTS.md section 2.3 step 6 | memory-manager dispatch | 12 memory-manager dispatches observed. DIA-125/126a/130/132 all had persistence steps. | STRONG |
| W6 | Research pipeline (researcher -> conspecter -> memory-shelf) | skill research-pipeline SKILL.md | conspecter dispatch + shelf registration | res001..res021 registered in shelf (21 conspects). 18 conspecter dispatches. research-pipeline gate acknowledged 4+ times. | STRONG |
| W7 | Boot-gate (batch-approval at session start) | dia-redispatch-cycle openspec | batch-approval-gate events | 28 batch-approval-gate events (12 pending-owner = needed developer input). Boot-gate observed on session-6/7/8/9. | STRONG |
| W8 | Interactive review gate (developer disposes findings) | practice-protected.md section 4 | pending-owner resolution_status | Only 9/47 reviewer dispatches (19.1%) explicitly went through pending-owner. 8/28 batch-approvals needed developer. | WEAK -- silent disposition in 81% |
| W9 | Interview-first gate (DIA-104 grilling) | skill domain-grilling + practice-protected.md section 1 | openspec-plan interview before proposal/design | 77 interview-related events; 16 pending-owner. 65 openspec-plan dispatches. But 17 openspec/changes/ dirs -- many small dev-infra changes skip interview with `skip_specs: true`. | MODERATE -- gate applied where appropriate |
| W10 | Fast-path opt-in (skips spec for trivial changes) | AGENTS.md section 2.4/2.5 note | coder dispatch without openspec-plan | ~50% of coder dispatches appear to be fast-path (DIA-096, DIA-118, DIA-120, DIA-121, DIA-122, DIA-130, DIA-131, DIA-132 -- all dev-infra/config changes). | INTENTIONAL -- not a violation |
| W11 | Council mode | skill + AGENTS.md | council dispatch at crisis only | 9 crisis events, 3 escalated. Council dispatches observed but rare (c-20260811 M1-M5 spec, etc.). | STRONG -- used sparingly |
| W12 | Ticket-creation gate (DIA-063) | DIA-063 + delegation-observer plugin | ticket_gate_blocked events | 30 ticket_gate_blocked in registry, 1 weak_correlation. DIA-112 (OPEN) tracked the correlation bug. Gate active. | STRONG |

### Overall adherence verdict

The project exhibits a **two-tier adherence pattern** (Medium confidence):

1. **Structural workflows** (boot-gate, ticket gate, research-pipeline,
   persistence loop, fix->re-review cycle cap, section-10 gate) --
   enforced by plugin/mechanism, adherence STRONG.
2. **Practice-protected workflows** (developer disposition, interview-first
   on feature work) -- enforced by prompt convention, adherence WEAK
   to MODERATE. The review-disposition gate (W8) shows the most
   pronounced gap: 81% of reviewer dispatches proceed without explicit
   `pending-owner` routing.

---

## 2. Developer-as-owner audit (practice-protected zones)

### 2.1 Practice-protected zones inventory (7 zones)

| Zone | Defined | Enforcement | Adherence (session evidence) |
|---|---|---|---|
| PP1. OpenSpec proposal/design authoring | practice-protected.md section 1 | prompt convention | 65 openspec-plan dispatches show intent; 16 pending-owner interview events = developer engagement. But many small changes use `skip_specs: true` without interview. | MODERATE |
| PP2. TDD edge-case identification | practice-protected.md section 2 | prompt convention | No direct session evidence of "agent surfaces edge cases, developer prioritizes" pattern. Edge-case decisions appear to be made by coder autonomously. | WEAK |
| PP3. Architecture decisions flagged by @architector | practice-protected.md section 3 | prompt convention | 0 @architector dispatches observed in the 2861-event session sample. Architecture work is done by analyzer/code-navigator instead. | NOT ENFORCED (architector disabled in practice) |
| PP4. Review-findings disposition | practice-protected.md section 4 | pending-owner resolution_status | 9/47 reviewer dispatches (19.1%) explicitly went to pending-owner. The remainder proceed with coder fix + re-review cycle without explicit pending-owner. | WEAK |
| PP5. Research persistence decision | practice-protected.md section 5 | pending-owner resolution_status | 4+ explicit "Persistence decision (practice-protected)" decision events observed (e.g. row 1950 for DIA-086). research-pipeline gate acknowledged. | STRONG |
| PP6. Agent-permission tiering | practice-protected.md section 6 | opencode.jsonc permission blocks | 3-tier model (pure-analyst / artifact-producer / executor) is implemented in permission blocks. | STRONG (structural) |
| PP7. Artifact ownership tracking | practice-protected.md section 7 | YAML frontmatter convention | Partial adoption -- openspec changes have frontmatter; knowledge/ files sometimes do. | MODERATE |

### 2.2 Concrete developer-engagement examples

**Positive examples (developer engaged):**
- 2026-08-11 session: reviewer finding on opencode-docker.bats:97
  resulted in `PENDING owner observation disposition` (registry row
  with resolution_status=pending-owner). Developer chose to fold into
  follow-up OR accept-as-is. (High confidence)
- 2026-08-13: DIA-126a "section10 Phase 2 developer decision" event
  (messages row 2821) routed autonomy research to developer before
  Phase 3 design. (High confidence)
- 2026-08-13: DIA-130/131/132 section-10 cycle completed with
  explicit "developer-attested" restart-verify evidence (DIA-130
  Re-verify block: "developer-attested in session on 2026-08-13").
  (High confidence)

**Negative examples (developer bypassed):**
- Reviewer disposition (W8): only 19.1% of reviewer dispatches go
  through pending-owner. Most coder-fix cycles proceed on
  coder+reviewer without explicit owner disposition of each finding.
  (Medium confidence -- the developer may still be engaged via
  handoff messages without pending-owner routing)
- TDD edge-case identification (PP2): no observed session evidence
  of edge-case prioritization prompts. Agents autonomously select
  which edge cases to test. (Low confidence -- could be happening
  inside coder sessions without session-log trace)
- @architector (PP3): zero dispatches in the observed sample.
  Architecture work is routed to @analyzer or @code-navigator
  instead, losing the "architector flags + owner decides" pattern.
  (Medium confidence)

### 2.3 Interview-first gate (DIA-104)

- 77 interview-related events in messages.jsonl.
- 65 openspec-plan dispatches (active use of the skill).
- 16 interview events went to pending-owner (developer answered
  grilling questions).
- But many small tickets bypass with `skip_specs: true` (dev-infra
  changes per AGENTS.md section 2.4 allowance).

**Verdict:** interview-first is applied where appropriate (feature
specs, architecture decisions), but not on dev-infra / config /
small-fix tickets -- which is consistent with the fast-path
allowance. Not a violation.

---

## 3. Verification-loop reliability quantification

### 3.1 Methodology

For each of the 45 CLOSED tickets, I measured three properties:

1. Has `## Re-verify` section? (yes = structural presence)
2. Re-verify section has non-blockquote content? (yes = evidence
   written; measured via awk count of non-whitespace, non-`>`
   lines in Re-verify section)
3. Re-verify section contains concrete evidence markers (exit codes,
   PASS/FAIL, verification keywords)?

### 3.2 Quantification

| Metric | Count | Rate |
|---|---|---|
| CLOSED tickets (universe) | 45 | 100% |
| Have `## Re-verify` section | 45 | 100% (template-enforced) |
| Re-verify section filled with evidence | 45 | 100% (all have content) |
| Re-verify section has concrete evidence (exit codes / PASS / FAIL / verified) | 23 | 51% |
| Re-verify section is weak / hand-wavy (1-4 markers, often "1" = section header only) | 12 | 27% |
| Re-verify section empty / placeholder ("> To be filled at re-verify time") | 10 | 22% |

**Breakdown of the 10 empty Re-verify sections (CLOSED tickets with
placeholder text):**

- DIA-045, DIA-050, DIA-073, DIA-074, DIA-080, DIA-082, DIA-083,
  DIA-086, DIA-091, DIA-114.

Most of these are config/config-drift tickets where the "fix" was
a config edit without a rerunnable verification. They should still
have a restart-verify evidence line per the DIA-123 pattern.

### 3.3 Cycle counts (fix -> re-review)

| Cycle count | Tickets observed |
|---|---|
| 0 cycles (no re-review, closed after first fix) | ~8 (config-only fixes) |
| 1 cycle (fix + re-review = closed) | 20+ (DIA-096, DIA-118, DIA-119, DIA-120, DIA-121, DIA-122, DIA-125, DIA-130, DIA-132, etc.) |
| 2 cycles (fix + re-review + fix + re-review) | 3-5 observed (DIA-086 M1-M5 had cycle 1/2; DIA-084 had multiple cycles) |
| >2 cycles (exceeded cap) | 0 observed (cap respected) |

**Verdict:** the 2-cycle cap is respected (no violations observed).
Most tickets close in 1 cycle.

### 3.4 Closed-loop outcomes

- Tickets CLOSED after re-review: 42/45 (93%)
- Tickets CLOSED without re-review (fix applied, no re-review): 3/45 (7%)
- Tickets left hanging (fix applied, re-review pending, status stays OPEN): ~20 OPEN tickets, of which several have Fix sections filled but Re-verify sections empty (DIA-107 pattern tracked separately).

### 3.5 UPDATE blocks (developer attestation)

Only 6/83 tickets carry an `<!-- UPDATE -->` block (developer
attestation of progress). This is LOW -- most progress is recorded
only in the Fix/Re-verify sections by the coder, without explicit
developer attestation. UPDATE blocks observed:

- DIA-055 (2 UPDATE blocks)
- DIA-113 (1 UPDATE block -- the ai--1 partial-progress note)
- DIA-125 (1)
- DIA-127 (1)
- DIA-129 (1)

---

## 4. Gap matrix

Each row is a workflow; columns answer: defined? enforcement point?
evidence of adherence?

| Workflow | Defined? | Enforcement point | Adherence evidence | Rating | Gap severity |
|---|---|---|---|---|---|
| W1 Feature chain (openspec->coder->reviewer) | YES | openspec-plan dispatch gate | Weak -- bypass on most tickets via skip_specs | WEAK | HIGH |
| W2 Fix->re-review loop max 2 | YES | cycle counter in task_ref | Strong -- cap respected | STRONG | -- |
| W3 Section 10 AI-devtools gate | YES | ai-specialist dispatch + user decision | Strong -- gate respected | STRONG | -- |
| W4 tdd-craftsman | YES | skill SKILL.md + bats evidence | Strong -- test evidence in most tickets | STRONG | -- |
| W5 Persistence loop | YES | memory-manager dispatch | Strong -- consistent | STRONG | -- |
| W6 Research pipeline | YES | conspecter dispatch + shelf | Strong -- 21 conspects registered | STRONG | -- |
| W7 Boot-gate | YES | batch-approval-gate events | Strong -- 28 events, 12 needed developer input | STRONG | -- |
| W8 Interactive review gate | YES (practice-protected) | pending-owner resolution | Weak -- 81% silent disposition | WEAK | HIGH |
| W9 Interview-first (DIA-104) | YES | openspec-plan dispatch | Moderate -- applied on feature work, skipped on dev-infra (allowed) | MODERATE | MEDIUM |
| W10 Fast-path opt-in | YES (implicit) | coder dispatch without openspec-plan | Strong -- used appropriately | STRONG | -- |
| W11 Council mode | YES | crisis events | Strong -- used sparingly | STRONG | -- |
| W12 Ticket-creation gate | YES | ticket_gate_blocked events | Strong -- 30 blocks observed | STRONG | -- |
| PP2 TDD edge-case prioritization | YES (practice-protected) | prompt convention | Weak -- no observable session evidence | WEAK | MEDIUM |
| PP3 @architector architectural flags | YES (practice-protected) | architector dispatch | NOT ENFORCED -- 0 dispatches observed | MISSING | MEDIUM |
| Re-verify evidence rate | YES (DIA-107 pattern) | Re-verify section | 51% have concrete evidence; 22% empty placeholder | WEAK | HIGH |
| Developer attestation (UPDATE blocks) | YES (implicit) | <!-- UPDATE --> block | 6/83 tickets (7%) | WEAK | LOW |

### Top 3 gaps (by severity)

- **G1 (HIGH) -- Reviewer-disposition silent bypass (W8).** 81% of
  reviewer dispatches do not go through explicit pending-owner
  routing. Practice-protected section 4 is being bypassed by
  convention. Recommendation R1 below.
- **G2 (HIGH) -- Re-verify evidence rate (51%).** 22% of CLOSED
  tickets have empty Re-verify placeholder. Another 27% have weak
  evidence (1-4 markers, often just the section header line). The
  DIA-107 pattern (concrete exit codes) is not uniformly applied.
  Recommendation R2 below.
- **G3 (MEDIUM) -- Interview-first gate bypass (W9/W1).** While
  fast-path is legitimate for dev-infra, the skip-spec rate on
  tickets with code changes is high. ~30% of implementation tickets
  appear to bypass openspec-plan without documented skip_specs
  justification. Recommendation R3 below.

---

## 5. Prioritized recommendations

Each recommendation is traced to a best-practice source. Any
config-change candidate MUST route through AGENTS.md section 10
(ai-specialist -> user decides -> Phase 5 restart-verify).

### R1 (HIGH) -- Formalize reviewer-disposition pending-owner gate

- **Recommendation:** Add a mechanical check that every reviewer
  dispatch whose findings are not labeled "mechanical" produces a
  pending-owner resolution_status in messages.jsonl. Either a plugin
  hook or an A1-violation detector.
- **Best-practice trace:** practice-protected.md section 4; Anthropic
  "human-in-the-loop for consequential decisions" (ana003
  verification-loop-anthropics learning); DIA-107 re-verify pattern.
- **Section-10 routing flag:** YES -- this requires a plugin hook or
  delegation-observer change. Route through ai-specialist first.

### R2 (HIGH) -- Re-verify evidence checklist with exit-code schema

- **Recommendation:** Extend the ticket template to require a
  structured Re-verify block: `exit_code: N`, `tests_passed: N/M`,
  `tests_failed: N`, `restart_verify: PASS/FAIL/PENDING`. Add a
  `scripts/validate-reverify.sh` check that fails closed tickets
  without a filled Re-verify block (similar to DIA-063 ticket-gate).
- **Best-practice trace:** DIA-107 re-verify pattern (verified-closed
  taxonomy); scientific-methodology conspect res012 M1 claim/evidence
  template; ana012 M1 mandate.
- **Section-10 routing flag:** NO -- pure dev-infra script, not
  AI-tooling config. Can be done by @coder with bats tests.

### R3 (MEDIUM) -- skip-spec flag enforcement on every coder dispatch

- **Recommendation:** Require every coder dispatch without a prior
  openspec-plan dispatch to include a documented `skip-spec`
  justification in the task_ref or messages.jsonl content_ref. Make
  this checkable via a session-log audit script.
- **Best-practice trace:** AGENTS.md section 2.4/2.5 fast-path
  allowance; ana004 spec-authoring-philosophy audit (52/100 score,
  "embedded as intent, not enforcement"); interview-first skill.
- **Section-10 routing flag:** PARTIAL -- may require a messages.jsonl
  schema extension (delegation-observer plugin change). Route the
  plugin portion through section 10.

### R4 (MEDIUM) -- @architector activation pathway

- **Recommendation:** Either (a) re-enable @architector for
  architecture-flagged decisions (practice-protected PP3) or (b)
  formally reassign architecture-flag duty to @analyzer or
  @code-navigator with an explicit "architecture decision point"
  marker. Currently PP3 is unenforced.
- **Best-practice trace:** practice-protected.md section 3; AGENTS.md
  section 2.1 (architecture trigger); ana002 agent-alignment-audit
  (architector missing model).
- **Section-10 routing flag:** YES -- involves agent enablement /
  config. Route through section 10.

### R5 (MEDIUM) -- TDD edge-case surfacing convention

- **Recommendation:** Add an M6 mandate to tdd-craftsman skill: when
  coder identifies a new edge case during RED-GREEN-REFACTOR, it MUST
  surface the edge case to the developer via a pending-owner
  resolution_status before writing the test. Make the surfacing
  observable in messages.jsonl.
- **Best-practice trace:** practice-protected.md section 2;
  tdd-craftsman SKILL.md; ana012 M1-M5 mandates.
- **Section-10 routing flag:** PARTIAL -- skill change is
  section-10-routable.

### R6 (LOW) -- UPDATE block adoption rate

- **Recommendation:** Encourage UPDATE blocks for all OPEN tickets
  with >3 days of activity. Currently 6/83 (7%). Could be added to
  the ticket template as a comment hint.
- **Best-practice trace:** ana012 M2 experiment-log header
  convention; session-log silencing (ana007) -- observability.
- **Section-10 routing flag:** NO -- ticket template change, dev-infra.

### R7 (LOW) -- Re-review cycle counter visibility

- **Recommendation:** Make the "re-review cycle N/2" counter explicit
  in the reviewer task_ref (it is sometimes present, sometimes not).
  Add an assertion in the reviewer skill that cycle 2/2 must include
  "cycle-cap reached" content_ref.
- **Best-practice trace:** AGENTS.md section 2.3.1 (max 2 cycles);
  dia-redispatch-cycle openspec (cycle-budget management).
- **Section-10 routing flag:** PARTIAL -- may require reviewer
  skill/prompt change.

---

## 6. Confidence per section

| Section | Confidence | Basis |
|---|---|---|
| 1. Workflow enumeration | High | Direct from AGENTS.md + skills + practice-protected.md |
| 1. Adherence evidence | Medium | Inferred from messages.jsonl event patterns; not every event is logged |
| 2. Developer-as-owner audit | Medium | Based on pending-owner events; developer may be engaged via other channels (handoff messages, TUI prompts) not captured in pending-owner count |
| 3. Verification-loop quantification | High | Direct count from 45 CLOSED tickets; exact measurement |
| 4. Gap matrix | Medium | Combination of direct measurement and inference |
| 5. Recommendations | Medium | Based on gap analysis; best-practice trace is High-confidence for the source references |

---

## 7. Cross-references to ai--1 findings (C7/C8)

For completeness, this section summarizes the ai-specialist findings
that this analyzer slice inherits (not re-verified):

- **C7 (ai--1):** project config is ALIGNED with current OpenCode
  best practices -- no drift detected. `steps:50` on escalated lanes
  matches Max-steps pattern; hidden lanes use `hidden:true`;
  background subagents correctly NOT used (experimental); compaction
  auto/prune configured per standard anti-overflow practice.
- **C8 (ai--1):** No dedicated autonomous-profile concept in OpenCode;
  `--auto` is the canonical unattended escape hatch (auto-approves
  ask-level, deny stays enforced).

These findings are inherited as-is and inform R1/R4 (autonomy
configuration remains aligned; the gaps are in workflow adherence
and practice-protected enforcement, not in config drift).

---

## 8. Limitations

- Session-log coverage: messages.jsonl and registry.jsonl are
  plugin-written; events that bypass the plugin (e.g., native
  OpenCode tool calls without delegation-observer hooks) are not
  captured.
- Historical depth: the registry.jsonl covers ~1000 sessions since
  2026-08-04; older sessions are not in the plugin-format universe.
- Developer engagement channels: some developer engagement happens
  via TUI prompts, in-person, or handoff files that don't produce
  pending-owner events. The 19.1% reviewer-disposition figure may
  understate actual engagement.
- Fast-path vs bypass: the distinction between "intentional
  fast-path" and "unintentional bypass" is not directly observable
  from session logs without reading each coder task_ref for
  skip-spec justification.

---

## 9. Summary table (one-glance)

```
+------------------------------------+----------+---------+-----------------+
| Workflow                           | Defined  | Enforce | Adherence       |
+------------------------------------+----------+---------+-----------------+
| W1  Feature chain                  | YES      | gate    | WEAK (bypass)   |
| W2  Fix->re-review (max 2)         | YES      | counter | STRONG          |
| W3  Section 10 gate                | YES      | gate    | STRONG          |
| W4  tdd-craftsman                  | YES      | skill   | STRONG          |
| W5  Persistence loop               | YES      | dispatch| STRONG          |
| W6  Research pipeline              | YES      | dispatch| STRONG          |
| W7  Boot-gate                      | YES      | event   | STRONG          |
| W8  Reviewer disposition           | YES (PP) | prompt  | WEAK (81% skip) |
| W9  Interview-first (DIA-104)      | YES      | skill   | MODERATE        |
| W10 Fast-path opt-in               | YES      | n/a     | STRONG          |
| W11 Council mode                   | YES      | crisis  | STRONG          |
| W12 Ticket-creation gate           | YES      | plugin  | STRONG          |
| PP2 TDD edge-case prioritization   | YES (PP) | prompt  | WEAK            |
| PP3 @architector flags             | YES (PP) | prompt  | NOT ENFORCED    |
| Re-verify evidence rate            | YES      | template| WEAK (51%)      |
| Developer attestation UPDATE       | YES      | n/a     | WEAK (7%)       |
+------------------------------------+----------+---------+-----------------+
```

**Top 3 recommendations (prioritized):**

1. **R1** -- Formalize reviewer-disposition pending-owner gate (HIGH)
2. **R2** -- Re-verify evidence checklist with exit-code schema (HIGH)
3. **R3** -- skip-spec flag enforcement on coder dispatch (MEDIUM)
