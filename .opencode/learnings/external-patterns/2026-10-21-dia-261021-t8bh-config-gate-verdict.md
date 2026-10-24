# Config-gate verdict: handoff split-brain + command-reference validator precision - DIA-261021-t8bh

Date: 2026-10-21
Gate: post-hoc review of the 5 unpushed commits on branch omo-slim-changes (HEAD aae39879), dispatched as campaign ticket DIA-261021-t8bh.
Ticket: DIA-261021-t8bh 'review of 5 unpushed commits on omo-slim-changes'

## Context

Five unpushed commits (2c3ce945..aae39879) were reviewed post-hoc. Two Majors and one intentional non-defect were identified. Two independent lanes (reviewer + GREEN implementer verification) confirmed both Majors; RED regression tests were authored by a separate instance (DIA-175 instance separation) and pinned each defect before the fixes landed.

## Findings

1. MAJOR - active.json written after a skipped or failed slot write. In
   `.opencode/plugins/delegation-observer.ts`, the `next_action` block
   (DIA-211 Phase 2 stigmergic active.json) was a sibling of the handoff
   slot-write if/else and never checked whether the slot write landed. It
   fired even when the writer was SKIPPED for a missing runtime
   `context.sessionID`, and even when the writer returned `ok: false`.
   Result: a routing hint (workflow_state/next_agent) plus a stale
   context.session_id with no `handoffs/<sid>.json` - the split-brain state
   forbidden by lesson L20260817-010. Confirmed by two independent lanes.
2. MAJOR - validator precision, both directions. The body
   command-reference scanner in `.opencode/scripts/validate-skills.sh`
   (DIA-260831-n9o0) produced false positives (fenced examples, indented
   fences, built-in commands such as /init, plain single-segment
   filesystem-path prose such as "See /workspace") and false negatives
   (multi-token inline code spans such as `/cmd <arg>`, at-sign references).
3. NON-DEFECT - the containment helper in `lib/handoff.ts` is
   unreachable-but-correct: its throw-vs-return contract is intentional
   (throws for programmer-error inputs, returns ok:false for
   environmental write failures). No change made.

## Options

1. Chosen: backticked-HARD + plain/at-sign-WARN split. Fenced code blocks
   (including indented fences) are never scanned - one fence-stripped body
   feeds both streams; each backticked span's FIRST whitespace-delimited
   token is validated against the command manifest unioned with a
   documented OpenCode built-in + ponytail allow-list (unknown => FAIL);
   plain-text and at-sign slash references are reported as `warn:` but
   never change the exit status. Pros: closes the multi-token blind spot,
   removes path/prose false positives, keeps the gate deterministic and
   hermetic. Cons: at-sign WARNs can be noisy (2 on the real tree).
2. Rejected - sanitize every skill body to fit the old strict rule
   (edit SKILL.md files to remove fenced examples, backtick all prose).
   Rejected: churns vendored skill content and still cannot express
   legitimate prose paths.
3. Rejected - status quo (old strict single-class scanner). Rejected:
   false positives hard-fail the real repo gate on legitimate content and
   false negatives leave the multi-token blind spot open.

## Evidence

- Tier 1: `.opencode/plugins/delegation-observer.ts` (next_action block,
  now gated on slot landed); `.opencode/plugins/lib/handoff.ts`
  (atomicWriteHandoff ok:true/false contract).
- Tier 1: `.opencode/scripts/validate-skills.sh` (body command-reference
  class, allow-list block, contract header check 12).
- Tier 1: lessons L20260817-010 at `.opencode/memory/lessons.md:1570-1582`
  (split-brain invariant); `docs/dev-infra-audit/repo.md:245-247`
  (handoff/active.json contract).
- Tier 1: RED regression tests
  `.opencode/plugins/__tests__/parallel-handoff.test.mjs`
  (DIA-261021-t8bh block) and `scripts/__tests__/validate-skills.bats`
  (DIA-261021-t8bh block), authored by a separate instance per DIA-175.

## Decision

Fix both Majors. Validator classes exactly as implemented: fenced never
scanned; backticked first-token slash references HARD against
manifest-union-allow-list; plain-text and at-sign references WARN-only.
The active.json block is gated on the slot write having landed (writer
called AND returned ok === true), with one error-level app.log line
naming the reason when it did not land. Containment helper left unchanged.
Recorded during DIA-261021-t8bh GREEN phase, 2026-10-21.
