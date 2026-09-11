# Builtin Containment (Revised) - 2026-09-10 - DIA-260831-h3i4

Ticket: DIA-260831-h3i4 (section-2.5 step 1 learnings registration).
Source: ai-specialist session ses_f745f5b3affeY8Qudq1VQEBkZO + orchestrator interview Q1-Q4 + developer revision.
Scope: READ-ONLY synthesis. No config edits. Single-file write only.

## 1. Problem

Native OpenCode agents (build / plan / scout) and direct coder bindings
(tdd-cycle, test-package, frontier.md, rag.md) can bypass project lanes
(coder, reviewer, architector, ai-specialist) and the DIA-217 ticket gate.
Bypass = engineering work with no governing OPEN DIA ticket and no lane
attribution, which breaks auditability and the two-axis review chain.

## 2. Interview synthesis (Q1-Q4)

Q1 - Which native agents are actually used?
  Finding: no legitimate workflow depends on build / plan / scout directly.
  All implementation flows through @coder; planning through @openspec-plan;
  recon through @code-navigator. Native agents are redundant surface.

Q2 - Which direct coder bindings are load-bearing?
  Finding: the 4 flagged bindings (tdd-cycle, test-package, frontier.md,
  rag.md) are convenience shortcuts, not load-bearing. Their functions are
  covered by lane dispatches and skills (tdd-craftsman, to-tickets,
  research-pipeline). Removal cost is low.

Q3 - What breaks if we disable?
  Finding: nothing in the spec -> implement -> review chain breaks.
  Only ad-hoc direct invocations stop, which is the intent. Fallback is
  explicit lane dispatch with a ticket ID.

Q4 - How do we verify without breaking sessions?
  Finding: gate on `make test-config` (agent-name lockstep, schema validity)
  plus a restart probe (OpenCode restart + smoke dispatch). No container
  dependency. Rollback = revert the disable flags in config.

## 3. ai-specialist controls (ses_f745f5b3affeY8Qudq1VQEBkZO)

C1. Set native agent.build / agent.plan / agent.scout to disable:true in
  project config so they cannot be dispatched.
C2. Remove the 4 direct coder bindings (tdd-cycle, test-package,
  frontier.md, rag.md) if the bypass is confirmed, routing that work
  through lanes/skills instead.
C3. Evidence required before implement step: test-config pass + restart
  probe showing the disabled agents reject dispatch and lanes still work.
C4. Keep independence: ai-specialist stays read-only; @coder applies the
  approved design; @ai-auditor reviews the config change (section-2.5
  review matrix).

## 4. Revised meta-task rule (developer decision, overrides broad bypass)

The developer REVISED the permissive reading of [META-TASK]:

- [META-TASK] is NARROW: procedural tasks ONLY. Allowed: ticket creation
  (`scripts/tickets new`, `create ticket`), confirmed bookkeeping for
  CLOSED tickets. These exist to resolve the chicken-and-egg deadlock
  (a fresh ticket ID is unknown at creation time).
- Capability token path stays NARROW: bootstrap and ai-infra-application
  scopes only, minted by the orchestrator via mint_capability, auditable.
- NORMAL implementation / build / plan / scout dispatches MUST carry an
  OPEN DIA ticket ID in task text (literal DIA-NNN or DIA-YYMMDD-XXXX).
  No OPEN ticket = DIA-217 hook hard-blocks.
- [META-TASK] MUST NOT authorize engineering work. Any implementation,
  build, plan, or scout payload carrying only [META-TASK] and no OPEN
  ticket is a gate violation, not a bypass.

Rationale: a broad [META-TASK] carve-out would re-open the exact bypass
this containment closes. Narrow keeps ticket creation possible while
engineering stays gated.

## 5. Next steps (for design/implement lanes, not this file)

1. Design: @architector traces each disable/remove decision to a rule.
2. Implement: @coder applies disable:true + binding removals.
3. Validate: make test-config + restart probe (evidence attached).
4. Review: @ai-auditor independent review (config change matrix).
5. Register: changelog entry via scripts/changelog-add.

## 6. Invariants

- ASCII-only in lane payloads (DIA-079).
- Single-file write for this step; no config edits here.
- No engineering dispatch without an OPEN DIA ticket, except the two
  audited bypass paths above.

## 7. Outcome (2026-09-10, section-2.5 step 7 closure)

- **status**: VERIFIED CLOSED (ai-auditor session
  ses_f72bcc3bdffeKWcZ7pgv9FXj6h, PASS 4/4: anchored invocation,
  newline hard-block, 2 RED cases, OMO pins + version claims truthful).
- **outcome**: containment holds - build/plan/scout disable:true live in
  .opencode/opencode.jsonc; make test-config EXIT 0; containment 17/17
  green; restart probe primaries (compaction/summary/title/orchestrator)
  PASS; changelog entry registered via scripts/changelog-add.
