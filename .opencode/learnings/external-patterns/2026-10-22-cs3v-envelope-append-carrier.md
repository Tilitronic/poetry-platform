# Reviewer envelope diff re-arms the synthetic task-tool append (2026-10-22)

Date: 2026-10-22
Source: post-restart verification round (live reviewer child-prompt observation)
Ticket: DIA-261021-cs3v 'Dispatch gate warnings on compliant dispatches: satisfy FIXED_POINT and config-work routing checks up front'

## Finding

DIA-261006-y72h's mention-hygiene rule assumes the orchestrator dispatch payload is the ONLY carrier of the trigger: OpenCode core appends a synthetic "call the task tool with subagent: <name>" text part to a child prompt when that prompt carries an at-sign immediately before an agent name. The reviewer envelope is a second carrier. On a successful marker check the plugin builds an IMMUTABLE_GIT_ENVELOPE block (`.opencode/plugins/delegation-observer.ts:1984-1997`) and injects it into the CHILD prompt, and that block contains the raw three-dot diff plus the double-dot log of the review range - so whenever the reviewed range touches an agent-instruction file (`.opencode/memory/lessons.md`, a reviewer card, `.opencode/agents/*`, `AGENTS.md`), the hunks themselves carry at-sign-prefixed agent names into a prompt the payload rule never screened.

Observed live 2026-10-22: the child reviewer reported THREE synthetic append parts in its prompt while the dispatch payload itself contained ZERO literal agent mentions - the mentions came only from envelope content, namely diff hunks of `.opencode/memory/lessons.md` and of the reviewer card.

## Consequence

- Hygiene-scope gap: the DIA-261006-y72h rule constrains what the ORCHESTRATOR writes; the envelope is plugin-generated text appended after the payload check, so no payload-side rule can see or strip it.
- The rule is therefore defeated for exactly the diffs that matter - any review of an agent-instruction change re-introduces the append on a perfectly clean payload.
- Same carrier-miss class as the FIXED_POINT rule living only in `.opencode/memory/lessons.md` (not read at boot): trigger and controlling knowledge sit on surfaces the other side does not read.

## Rule (addition to DIA-261006-y72h)

1. Payload hygiene is necessary but NOT sufficient: after a reviewer dispatch, treat the injected envelope diff as a possible second source of agent mentions, and expect synthetic append parts on any range that touches agent-instruction files.
2. When such a range is unavoidable, tell the child in the payload to ignore synthetic append parts and to call no task/dispatch tool.

## Related finding from the same round

- The envelope base ref cannot be HEAD: the gate resolves the ref, computes the merge-base, then requires a non-empty range, so the FIXED_POINT base must be the PARENT commit (or older). Recorded next to the REVIEWER ENVELOPE entry in `.opencode/memory/lessons.md`.

## References

- `.opencode/plugins/delegation-observer.ts:1950-1983` (base-ref resolve, merge-base, non-empty range requirement).
- `.opencode/plugins/delegation-observer.ts:1984-1997` (envelope construction, injected into the child prompt at :1997).
- `external-patterns/2026-10-06-opencode-core-synthetic-task-tool-append.md` (original DIA-261006-y72h mechanism record).
- `external-patterns/2026-10-21-cs3v-dispatch-gate-contract.md` (envelope emitter, same campaign ticket).
