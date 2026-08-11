# DIA-078 defense-in-depth — snip-deny permission rule on coder (ai--1 §10 gate Q1, 2026-08-10)

- **Date:** 2026-08-10
- **Source:** ai--1 §10 gate research disposition (approved by developer) — implement snip-deny (Q1), defer DIA-077 as monitoring note (Q2). Implemented by code-executor §10 Phase 4 lane.
- **Status:** APPLIED — `make test-config` exit 0; DIA-077 DEFERRED.
- **Outcome note:** DIA-092 Phase 5 validation PASSED 2026-08-11 - opencode-snip@1.6.1 removed from the global plugin array (make test-config exit 0, bash unlocked, no snip emissions); the four snip deny rules were KEPT as DORMANT guardrails (council 5/5), superseding the prior "snip-deny live pending restart" note - the rules never needed to fire live because the plugin that mechanically rewrote commands is gone. Orchestrator task allowlist (2026-08-10) additionally blocks global agents from project dispatch.

## Decision

Developer APPROVED the ai--1 gate disposition: add bash deny `{"snip": "deny", "snip *": "deny"}` to the `coder` agent permission in `.opencode/opencode.jsonc` (defense-in-depth on top of the existing prompt guardrail + `doom_loop: deny`); DIA-077 root-caused and DEFERRED as a monitoring note.

## Findings (ai--1 Q1: permission glob syntax, opencode.ai/docs/permissions)

- **Permission keys are globs.** `"snip *"` matches `snip make test-config`, `snip jq ...`, etc. (any command starting with `snip `).
- **A bare `snip` needs its own separate pattern** — the glob `snip *` requires a trailing space + arg, so the exact-command `snip` (no args) is NOT matched by `snip *`. Hence both `"snip": "deny"` AND `"snip *": "deny"` are required.
- **Agent rules are additive over the global baseline** — an agent-level `bash` object merges on top of the project/global `permission.bash`; it does not replace it wholesale for keys it doesn't mention.
- **Last-matching-rule-wins** within the merged rule set; `deny` blocks the action outright (no prompt).
- **Coexistence with `doom_loop: deny` confirmed** — independent permission keys; a `deny` on the bash tool short-circuits before any doom-loop counting matters, and doom_loop remains the 3×-identical-call halt for non-bash tools.

## Safety rationale

- `snip` is an interactive TUI display-trimming helper (filters/trims command output for human viewing) — it has **zero legitimate agent use**: it fork/execs the real command and can emit a `SyntaxError` on filter application, breaking agent workflows and producing misleading `EXIT_CODE=0` passthroughs (the DIA-075/DIA-078 loop mechanism).
- Denying it on `coder` is pure defense-in-depth: the mechanical deny makes the loop impossible at the platform level even if the prompt guardrail is ignored (proven failure mode — advisory rules alone did not stop the 7× recurrence).

## Rollback

- Remove the `"bash"` key from the `coder` permission object in `.opencode/opencode.jsonc` (revert to `"permission": { "doom_loop": "deny" }`) and restart OpenCode. Config is version-controlled; `git diff` shows the exact delta.

## Test plan

1. `snip *` deny fires on e.g. `snip make test-config` (permission prompt, action blocked).
2. Plain commands still pass (no interference — only `snip`-prefixed paths denied).
3. Bare `snip` (no args) also denied (separate `"snip": "deny"` pattern).
4. `make test-config` exit 0 — validates JSONC syntax + validate-agent-names (no new agent block added → no S2 contract drift).

## Follow-up: code-executor definition discrepancy

- **Observation:** the task runtime accepts `subagent_type: "code-executor"` (used for cod-1/cod-2), but `code-executor` is NOT in OMO `SUBAGENT_NAMES` (`src/config/constants.ts` — only code-navigator, researcher, architector, reviewer, designer, coder, observer, council, councillor).
- **Where it resolves from:** GLOBAL config — `~/.config/opencode/agents/code-executor.md` (frontmatter: `mode: subagent`, `permission: read: allow, edit: allow, bash: allow, webfetch: deny`), i.e. OpenCode's global agent-markdown discovery, not OMO, not the project.
- **Permission consequence:** code-executor carries its own explicit `bash: allow` — it does NOT inherit the project `coder`-only snip deny, and no `code-executor` block exists in project `opencode.jsonc` (so the deny was NOT added there; adding a project block would register it in S2 of the agent-name contract and require a coordinated AGENTS.md §9 table update — orchestrator follow-up).
- **Needs resolution:** reconcile the runtime-accepted-but-OMO-unknown agent name (either add to SUBAGENT_NAMES / document as global-only, or add a project block + §9 table row). Orchestrator decision.

## Tags

DIA-078, DIA-077, §10, permission-globs, snip-deny, doom_loop, code-executor, agent-name-contract, defense-in-depth
