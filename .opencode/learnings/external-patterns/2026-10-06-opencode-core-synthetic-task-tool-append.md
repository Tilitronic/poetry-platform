# OpenCode core appends a synthetic task-tool instruction when a dispatch payload mentions an agent (2026-10-06)

Ticket: DIA-261006-y72h (child of study DIA-260929-nc6w).
Source: ai-specialist read-only research (session ai--1).

## Mechanism
OpenCode CORE (upstream packages/opencode/src/session/prompt.ts) appends a synthetic text part to a CHILD prompt when the brief or message mentions an agent:

    { type: "text", synthetic: true,
      text: " Use the above message and context to generate a prompt and call the task tool with subagent: " + part.name + hint }

- It is invisible in the UI.
- It fires on the brief the ORCHESTRATOR writes.
- One synthetic part per named agent; two names produce the plural "subagents".
- Not our plugin: no handler in .opencode/plugins/ appends this; OMO only rewrites display names.

## Impact
- A child lane whose contract is task: deny receives an instruction to call a tool it does not have. Historically this caused coder-lane early termination (bails at step 1); in the 2026-10-06 agent-role study the task:deny lanes (analyzer, memory-manager) ignored it and completed.
- Risk escalates on lanes that DO resolve task: true (code-navigator, observer): the synthetic tail can drive unintended delegation.

## Rule (MANDATORY)
1. NEVER write a literal agent mention (at-sign immediately followed by an agent name) anywhere in a task dispatch payload. Refer to lanes descriptively (e.g. "the coder lane") or by internal name without the at-sign.
2. Optionally append an explicit clause: "do NOT call or look for any task/dispatch tool."

## Where it was previously recorded (ephemeral only; this file is the durable record)
- .opencode/session/coder-lane-early-termination-synthesis.md:20-43 ("CAUSE A")
- .opencode/session/handoffs/archive/ses_f1d0fc9b (lines 10, 39, 42, 47) and several later handoff slots
- NOT present in AGENTS.md, NEXT-RUN.md, .opencode/memory/*, CHANGELOG, or the ticket ledger before this work.

## References
- Upstream: opencode packages/opencode/src/session/prompt.ts (synthetic: true).
- Corroborating analyses (to be corrected): ana-261006-63z3 and ana-261006-jd0s framed the same text as an unresolved injection; it is deterministic core behavior, self-inflicted by an at-sign mention in the dispatch payload.
