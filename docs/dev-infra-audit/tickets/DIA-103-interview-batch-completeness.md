# DIA-103 - interview completeness vs depth mode plan enforcement: pre-synthesis completion self-check gate

<!-- UPDATE 2026-08-14 (CLOSED - closure lane, ai-auditor Phase 6 review +
     developer disposition + CHANGELOG; LIVE RESTART-VERIFY DEFERRED - see
     Re-verify section for the follow-up placeholder):
     ai-auditor Phase 6 review (ai--4, ses_fffbf5668ffedWrkyeItmfnyEq) verdict
     CONFORMANT-WITH-NOTES. Findings 1-4 PASS: (1) Variant 1 soft prompt gate
     present in the shared agents section orchestratorPrompt, (2) single edit
     covers all 3 presets opencode-go/cebula/free via OMO deepMerge
     root-override, (3) ticket reframe + severity downgrade Medium -> Low
     accurate, (4) validation evidence make test-config exit 0
     (interview-enforcement 5/5, validate-agent-names 24 passed,
     validate-decision-variants 105/105, drift 3x8 0 gaps). Finding 5 Minor:
     README.md:56 still shows the stale title + severity + status OPEN - the
     README is a protected concurrent-session file (DIA-153 lease); the
     DIA-103 index row update is DEFERRED to the DIA-153 lease commit (rollup
     counts unaffected - frontmatter is the source of truth). Finding 6:
     residual fabricatability (LLM can skip the self-check) accepted by design
     - mechanical Variants 2/3 judged diminishing returns (EBDV DIA-115).
     Finding 7 Medium process: RESTART-VERIFY PENDING was closure-blocking,
     now DEFERRED per developer decision (DIA-123 second-boot pattern, same
     as DIA-078). DEVELOPER DISPOSITION (binding): "Close w/ deferred verify"
     - all 7 notes accepted, status OPEN -> CLOSED, closed 2026-08-14. -->

<!-- UPDATE 2026-08-14 (IMPLEMENTED - Variant 1 soft prompt gate, Phase 4
     section-10 lane; restart-verify PENDING - config change takes effect on
     next OpenCode restart; status stays OPEN - closure is a separate lane:
     ai-auditor Phase 6 review + developer disposition + CHANGELOG):
     REFRAME per ai-specialist Phase 1 gate findings (registered in
     .opencode/learnings/external-patterns/2026-08-14-interview-completeness-
     vs-batch-drop.md). CRITICAL FINDING: the one-at-a-time delivery rule
     (oh-my-opencode-slim.jsonc openspec-plan Phase 2) ALREADY prevents batch
     question-drops - N simultaneous questions is itself a protocol violation.
     The REAL risk is PREMATURE TERMINATION: the agent skips remaining
     questions and moves to artifact synthesis. Ticket reframed from
     "interview batch completeness enforcement" to "interview completeness vs
     depth mode plan enforcement"; severity downgraded Medium -> Low
     (developer-approved per ai-specialist recommendation 5).
     EBDV VARIANTS CONSIDERED (DIA-115): Variant 1 (Status Quo + Soft Prompt
     Gate) ADOPTED - pre-synthesis "Completion Self-Check" phase added to the
     openspec-plan INTERVIEW PROTOCOL (shared agents section, applies to all
     3 presets opencode-go/cebula/free via deepMerge root-override): state
     depth mode used + confirm all applicable questions asked/answered, state
     why if any were skipped, do not proceed until transcript complete.
     Variants 2 (transcript artifact + validator script) and 3 (plugin hook on
     synthesis transition) considered but NOT implemented - mechanical but
     diminishing returns (LLM-generated transcript fabricatable, user-turn
     count a poor proxy, zero incidents in session history). Variant 4 (ABORT
     / status quo) considered and rejected - the soft gate closes the real
     premature-termination gap at minimal cost. No new scripts, no plugin
     changes - prompt-level gate ONLY. -->

<!-- Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
     Parallel dev infra batch ticket. opencode-config: enforces that the
     openspec-plan interview is complete (per depth mode plan) before artifact
     synthesis proceeds - a pre-synthesis completion self-check gate.
     Original scope ("capture answers to ALL questions of a returned batch")
     was REFRAMED 2026-08-14: one-at-a-time delivery already prevents batch
     drops; the gate now targets premature termination. Targets openspec-plan
     interview flow. -->

---

id: DIA-103
title: "interview completeness vs depth mode plan enforcement: pre-synthesis completion self-check gate"
area: opencode-config
severity: Low
status: CLOSED
blocked_by: []
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-14
closed: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

REFRAMED 2026-08-14 (ai-specialist Phase 1 gate, DIA-115 EBDV):
the original "batch completeness" framing assumed an interview agent can
return a batch of N questions that must all be captured. Investigation showed
the openspec-plan INTERVIEW PROTOCOL (MANDATORY) in oh-my-opencode-slim.jsonc
delivers questions ONE AT A TIME (Phase 2), so N simultaneous questions is
itself a protocol violation - batch drops are already prevented. The REAL
enforcement gap is PREMATURE TERMINATION: the agent may skip remaining
questions from the depth-mode battery (Full 11+ / Compressed <=5 / Skip) and
move to artifact synthesis before the interview transcript is complete. No
pre-synthesis completeness gate existed - only `openspec validate` AFTER
synthesis. Enforcement mechanism (Variant 1, adopted): a soft prompt gate -
"Completion Self-Check" phase in the openspec-plan INTERVIEW PROTOCOL that
requires the agent to state the depth mode used and confirm all applicable
questions were asked and answered (stating why if any were skipped) before
proceeding to artifact synthesis. Prompt-level ONLY (no scripts, no plugins);
still fabricatable by design - mechanical enforcement (Variants 2/3) judged
diminishing returns.

### Investigation requirements (historical - completed 2026-08-14)

1. Read openspec-plan interview protocol (oh-my-opencode-slim.jsonc,
   orchestratorPrompt/openspec-plan sections). DONE - Phase 0 depth modes +
   Phases 1-3 + new Phase 4 Completion Self-Check.
2. Read domain-grilling skill (.opencode/skills/domain-grilling/SKILL.md).
   DONE - one-at-a-time at line 24; unstructured battery; lower risk.
3. Identify enforcement gap: is there a mechanical check that all questions
   are answered? DONE - none exists; one-at-a-time prevents batch drops;
   gap is premature termination.
4. Propose enforcement mechanism. DONE - Variant 1 soft prompt gate adopted
   (EBDV, see learnings file).
5. Define test: N questions returned -> N answers required before synthesis.
   DONE - test case documented in Fix/Re-verify; negative test = self-check
   after Q3 of 11 reads "3/11, Q4-Q11 skipped because [reason]".

### Deliverables (all completed 2026-08-14)

- Enforcement gap analysis (current state) - learnings file section (a).
- Enforcement mechanism proposal - Variant 1 adopted (learnings file (b)).
- Test case (N questions -> N answers) - learnings file (c) + this ticket.

## Verification

- [x] (a) Gap analysis documents current enforcement (or lack thereof).
- [x] (b) Mechanism proposal tested with 3+ question batch.
- [x] (c) All N answers captured before synthesis proceeds (soft gate).
- [x] (d) Cross-linked with openspec-plan interview protocol.

## Fix

> Filled 2026-08-14 (Phase 4 section-10 lane, Variant 1 - soft prompt gate).

Variant 1 (Status Quo + Soft Prompt Gate) implemented in
.opencode/oh-my-opencode-slim.jsonc, agents.openspec-plan.orchestratorPrompt
(shared agents section - applies to ALL 3 presets opencode-go/cebula/free via
the OMO deepMerge root-override; a single copy, no per-preset duplication for
openspec-plan). Added "### Phase 4: Completion Self-Check" between Phase 3
(Interview Summary) and "## ARTIFACT SYNTHESIS" - a pre-synthesis
precondition in the natural location (the ticket's "Phase 5" label was based
on the assumption that Phases 1-4 existed; the actual protocol has Phase 0 +
Phases 1-3, so the new phase is numbered 4 to keep the sequence gap-free).
Exact text added:

"Before proceeding to artifact synthesis, state which depth mode was used
(Full/Compressed/Skip) and confirm all applicable questions from that mode's
battery have been asked and answered. If any were skipped, state why. Do not
proceed to synthesis until the interview transcript is complete."

No new scripts, no plugin changes, no Variants 2/3. ASCII-only (DIA-079).
Validation: make test-config exit 0 (agent-name lockstep, drift gates,
banned-phrase check 2 unaffected - it greps the skill + /opsx commands, not
the jsonc), JSONC parse confirmed. Do NOT commit - Phase 6 ai-auditor review
then orchestrator closure.

## Re-verify

> Filled 2026-08-14 (Phase 4 section-10 lane, Variant 1).

Positive test: dispatch @openspec-plan on a Full-mode feature. Expected:
agent declares depth mode "Full", asks Q1 -> developer responds, continues
one-at-a-time through all applicable questions, then BEFORE synthesis states
"Completion self-check: depth mode Full, questions asked Q1-Q11 (11/11), all
answered." Only then proceeds to artifact synthesis.

Negative test: after only Q3 answered, agent must NOT proceed to synthesis;
self-check reads "Q1-Q3 (3/11), Q4-Q11 skipped because [reason]" - developer
decides to continue the interview or accept the partial (practice-protected).

Mechanical check (no new script): grep the config for "Completion Self-Check"
and the full gate sentence (must be present in the shared agents section);
make test-config exit 0.

DEFERRED live restart-verify (DIA-103 follow-up): in a POST-change OpenCode
session, dispatch @openspec-plan on a Full-mode feature and confirm the Phase 4
Completion Self-Check fires before artifact synthesis (11/11 self-check in
positive case; 3/11 + stated reason in negative case). The change is
prompt-level and takes effect on next OpenCode restart (config hook resolves
orchestratorPrompts at init). Deferred per the DIA-123 second-boot pattern
(same as DIA-078): this placeholder is the follow-up plan, NOT evidence of a
live run - the closure session ran the PRE-change config.
