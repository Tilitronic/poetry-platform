# DIA-261023-kkjr - deliver the reviewer git envelope post-spawn instead of mutating the task args

---

id: DIA-261023-kkjr
title: "deliver the reviewer git envelope post-spawn instead of mutating the task args"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-261023-d6b9
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: fix-lane
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-23

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

`tool.execute.before` exposes only `{ args: any }`
(`@opencode-ai/plugin/dist/index.d.ts:239-241`); there is no `parts` or
`message` surface on tool-dispatch hooks, and the child prompt comes from
`args.prompt`. Injection therefore must mutate text: the envelope is
constructed at `.opencode/plugins/delegation-observer.ts:1927` and written
back via `taskArgRecord.prompt = ...` at
`.opencode/plugins/delegation-observer.ts:1951`.

Consequence: the injected block is indistinguishable from authored text,
which is what let three fabrication incidents through
(`.opencode/learnings/external-patterns/2026-10-22-orchestrator-envelope-fabrication.md`).

Feasible alternative from the layer-4 recon: delete the write at
`:1951`; keep the block for marker validation and pinning only; deliver
the envelope to the spawned child as a separate message after spawn
(`tool.execute.after` already resolves the lane taskId; `ctx.client` is
already used in the same reviewer-envelope block at
`.opencode/plugins/delegation-observer.ts:1976`).

Risks to weigh:

- the child may begin reasoning before the envelope arrives;
- `.opencode/plugins/__tests__/reviewer-immutable-git-envelope.test.mjs:237-243`
  asserts the prompt mutation and must be rewritten by design;
- the ticket-gate / capability / meta-task / section-10 scans would then
  see authored text only (a deliberate behaviour delta that also removes
  diff-content ticket-ID false correlation).

Explicitly UNVERIFIED: whether the parent transcript renders pre- or
post-hook args. OpenCode core ships as a compiled bun binary; the SDK
confirms only that `ToolPart.state.input` exists. The causal benefit of
re-homing is therefore unproven - a precondition for doing this work is
establishing that render path.

Note: the provenance line added in DIA-261023-d6b9
(`.opencode/plugins/delegation-observer.ts:1937`) is the interim
mitigation.

## Verification

- [ ] Precondition first: the parent-transcript render path (pre- vs
      post-hook args) is established with evidence; work does not start
      without it.
- [ ] `.opencode/plugins/delegation-observer.ts` no longer mutates
      `taskArgRecord.prompt` for the reviewer envelope; the envelope is
      delivered to the spawned child as a separate post-spawn message.
- [ ] `reviewer-immutable-git-envelope` tests rewritten to assert the
      post-spawn delivery instead of prompt mutation; plugin test suite
      exits 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
