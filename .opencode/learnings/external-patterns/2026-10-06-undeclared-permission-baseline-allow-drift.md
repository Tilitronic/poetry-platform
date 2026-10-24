# Undeclared permission keys resolve to ALLOW on every agent (2026-10-06)

Ticket: DIA-261006-ldfs. Related: DIA-260929-nc6w (Analysis A, code-navigator).
Source: read-only permission audit + delegation-dependency check (2026-10-06), implemented by the DIA-261006-ldfs config lane.

## The drift class

OpenCode resolves a permission key by walking the merged ruleset in order and taking the
LAST matching rule (findLast). The resolved list has three layers, in this order:

1. OpenCode's built-in baseline — rule `[0]` is always `*  allow  *`.
2. The project global `permission` block (`.opencode/opencode.jsonc:25-118`), which
   declares ONLY `edit` and `bash`. It has no catch-all `*` entry and no `task`,
   `ast_grep_replace`, or `ast_grep_search` key.
3. The per-agent `agent.<name>.permission` block, appended last.

Consequence: **any UNDECLARED permission key resolves to ALLOW on every agent**, because
nothing between layer 1 and layer 3 speaks for it and layer 1 says `* allow *`.

Second consequence, and the one that matters for remediation design: **a GLOBAL deny is a
default, not a lock.** Because agent rules are appended AFTER global rules and findLast
decides, a later per-agent entry with the same pattern overrides a global entry. A global
`"ast_grep_replace": "deny"` therefore covers every agent that does not mention the key,
and an explicit per-agent `"ast_grep_replace": "allow"` (or an `ast_grep_search: deny`)
still wins for that agent. This is the property that lets the change set use one global
deny instead of 17 mirrored per-agent keys — and it is also why the coder/coder-escalated
permission lockstep (`.opencode/scripts/lib/jsonc-parse.js`, `TASK_KEYS = ['task']`) is
not engaged by a global key.

Verified with `opencode debug agent <name>` (rule order + resolved `tools` map) on 2026-10-06.

## Findings (2026-10-06 audit)

- **task (delegation) was silently allowed** on `code-navigator`, `observer`, `designer`,
  `memory-manager`, `council` and `coder` — none of those blocks declares a `task` key, so
  all six inherited `* allow *`. A read-only lane with `task` enabled can delegate to a
  write-capable lane and mutate the repo transitively, defeating its own `edit: deny`.
  Usage evidence: **only the orchestrator has ever called `task()` — 1005 calls; every
  other agent 0** (opencode.db `part` join `message`, window 2026-08-12 .. present).
- **ast_grep_replace was silently allowed everywhere except `orchestrator` and
  `ai-auditor`** (the only two blocks that name the key). Usage evidence: **1 invocation
  ever, a dry run with 0 writes** (`prt_044af8ab4001z0y1GW0PX6IZQ4`, 2026-08-27, coder,
  `dryRun: true`, output `No matches found for replacement.`).
- **ast_grep_search was silently allowed everywhere, INCLUDING the orchestrator** — whose
  own design comment says it "knows NOTHING about the codebase except what delegation
  results report" (`.opencode/opencode.jsonc:153-154`) and which denies `grep` outright
  (`:216`) while path-scoping `read` and `glob`. Usage evidence: 9 calls (orchestrator 6,
  coder 2, code-navigator 1).

## Why these two tools cannot be hardened in the usual way

- The `ast_grep_replace` / `ast_grep_search` implementations ship from the OMO plugin
  (`oh-my-opencode-slim/dist/tools/ast-grep/`), not from OpenCode core, and their
  `execute()` bodies **never call a permission `ask()`**. Core performs no generic
  per-tool-name permission check either (the tool wrapper only fires
  `tool.execute.before/after`). So neither tool is path-scopable and neither is
  ask-gated: any GRANT is a silent, unrestricted use. The only lever is deny-by-default
  at the tool-availability level.
- Both shell out to the `sg` (ast-grep) binary. `ast_grep_search` can additionally trigger
  a **network fetch of the ast-grep release plus cache writes on a cold cache** (OMO's
  `ensureAstGrepBinary` / `downloader` / `getCachedBinaryPath` surface), which is an
  unsolicited side effect on an agent that may otherwise be network-denied.

## Decision

- **Delegation is the orchestrator's monopoly.** `"task": "deny"` added to the six blocks
  that inherited allow; the orchestrator keeps its named allow-list map unchanged.
- **ast_grep_replace denied fleet-wide** via a GLOBAL `"ast_grep_replace": "deny"`.
- **ast_grep_search allowed fleet-wide but EXPLICITLY** — a global
  `"ast_grep_search": "allow"` replaces the inherited baseline default with stated intent —
  with per-agent `"ast_grep_search": "deny"` on **orchestrator** (reads nothing by design)
  and **conspecter** (pure synthesis of already-archived sources; no search needed).
  It is deliberately NOT denied elsewhere: it is read-only and in active use.

## Deferred drifts (routed to a separate follow-up ticket)

1. `envsitter_*` mutators — only `ai-auditor` and `orchestrator` deny them; the other
   agents inherit allow.
2. `coder` `webfetch` / `websearch` — the implementation lane has both undeclared (allow)
   despite `websearch` being denied on the orchestrator.
3. `designer` `bash` — the designer block has no `permission` key at all, so bash is allow.

## References

- `.opencode/opencode.jsonc` (global block :25-118, orchestrator :157-253, coder comment
  :313-315, code-navigator :512-515, observer :553-556, designer :546-549,
  memory-manager :564-571, conspecter :585-593, council :617-622).
- `opencode debug agent <name>` -> `.permission` (ordered rules) and `.tools` (resolved
  availability booleans).
- `.opencode/scripts/lib/jsonc-parse.js` (`--lockstep`, `TASK_KEYS = ['task']`).
- `scripts/audit-agent-tool-coverage.sh` (coverage = agent block UNION global block;
  canonical write-capable list already includes `task` and `ast_grep_replace`).
- Study ticket DIA-260929-nc6w (Analysis A, code-navigator).
