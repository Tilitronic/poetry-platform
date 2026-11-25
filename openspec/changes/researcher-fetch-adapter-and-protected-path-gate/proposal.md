## Why

The `researcher` lane's bash allow-list (`curl *`, `wget *`, `trafilatura *`,
`crwl *`) is not a write boundary: every one of those tools has a write mode
that reaches any path (`curl -o`, `curl --output`, `curl -O`, `wget -O`,
`wget -P`, `trafilatura -o`, `crwl -o`). The lane's edit allow-list is
therefore irrelevant, and the config gate currently documents the hole with an
explicit `EXEMPT_EDIT_BASH` entry (`.opencode/scripts/lib/jsonc-parse.js`)
instead of closing it. This change closes it by removing the shell from the
lane and replacing it with a path-validating typed fetch tool, and adds a
narrow accident tripwire for the two implementation lanes that must keep a
shell.

## What Changes

- **BREAKING (researcher tool surface):** `researcher` loses bash entirely
  (flat `"deny"`). The four fetch CLIs are removed from its permission map.
- New custom tool `fetch-source` under `.opencode/tools/`, taking a `url` and
  an `output_path`. It resolves the destination, refuses anything outside
  `knowledge/` and `.opencode/oh-my-opencode-slim/knowledge/`, refuses
  traversal and symlink escape, fetches internally with an argv array (no
  shell), publishes atomically, and returns the tier used and the status.
- The tool owns the 3-tier order (npm registry JSON API, then trafilatura,
  then crwl as last resort). Tier 3 is optional and degradable: a missing
  `crwl` is not an error, and the tool reports which tier succeeded.
- Only the `researcher` agent may call `fetch-source`. The tool enforces this
  from its execution context so it cannot become a new write primitive for a
  read-only lane through the default tool baseline.
- `designer` gets an explicit flat-deny bash map. `memory-manager` gets an
  explicit deny-scoped map (read-only git plus the existing
  `scripts/validate-memory-shelf.sh`). This closes the inherited-global-allow
  debt in config rather than in the tripwire.
- New narrow protected-path tripwire in the delegation-observer
  `tool.execute.before` bash branch, scoped to `coder` and `coder-escalated`
  only. It blocks literal writes to `.git/`, `.opencode/session/`, and
  `docs/dev-infra-audit/tickets/`. It is accident protection, not a boundary,
  and is never described as provable.
- Config gate: remove the `researcher` and `memory-manager`
  `EXEMPT_EDIT_BASH` entries, add the four reproduced write shapes to the
  dangerous-shape probe list, and extend the doc-drift phrase set so a
  shell-free lane cannot document a shell it no longer has.
- Docs: the researcher agent file, the slim orchestrator prompt, the
  research-pipeline skill, and the changelog-lookup eligibility text in
  `orchestrator_append.md` are updated to match the new config.

## Capabilities

### New Capabilities

- `write-scope-enforcement`: confines researcher source-fetch writes to the
  two knowledge roots through a typed tool, removes the researcher shell, and
  defines the residual protected-path tripwire plus the inherited-shell
  closure for `designer` and `memory-manager`.

### Modified Capabilities

None.

## Impact

- `.opencode/tools/fetch-source.ts` (new).
- `.opencode/opencode.jsonc` (researcher, designer, memory-manager permission
  maps).
- `.opencode/plugins/delegation-observer.ts` and new
  `.opencode/plugins/lib/bash-write-gate.ts`.
- `.opencode/scripts/lib/jsonc-parse.js`,
  `.opencode/scripts/validate-opencode-config.sh`, and
  `scripts/__tests__/test-config-wiring.bats`.
- `.opencode/agents/researcher.md`, `.opencode/agents/memory-manager.md`,
  `.opencode/oh-my-opencode-slim.jsonc`,
  `.opencode/oh-my-opencode-slim/orchestrator_append.md`, and
  `.opencode/skills/research-pipeline/SKILL.md`.
- No application package, runtime dependency, or system architecture boundary
  changes.

## Testing Decisions

A good test here executes the former hole and fails if it succeeds, rather
than inspecting prose. Three seams carry the evidence:

1. **Path policy (pure):** a Node test asserts that `../`, an absolute path
   outside the roots, and a symlink escape are rejected, while paths under
   both knowledge roots are accepted. This is the seam that makes the
   containment property provable.
2. **Config gate (bats):** a case feeds the literal former commands
   (`curl -o /workspace/anything http://x`, `wget -O`, `trafilatura -o`,
   `crwl -o`) through the same resolver the runtime uses, against the real
   config, and asserts deny. A second case re-adds `curl *` to a fixture and
   asserts the gate fails. This is the negative test for the former hole.
3. **Plugin hook (bun harness):** a test drives the real `tool.execute.before`
   with `output.args.command` and asserts a protected-path write is blocked
   while an ordinary build command passes.

Modules tested: the fetch tool path policy and handler, the delegation-observer
bash branch, and the config gate. Prior art: the existing
`scripts/__tests__/test-config-wiring.bats` config cases, the
`.opencode/plugins/__tests__/*.test.mjs` plugin harness, the pure-seam Node
test pattern used by `scripts/__tests__/routing-order-gate.test.mjs`, and the
committed conspect `knowledge/archive/res009-snip-jq-filter-truncation/` which
records that the bash command argument is `output.args.command`.

## Rollback Plan

Revert the implementation as one commit: restore the previous researcher bash
map, delete `fetch-source.ts`, remove the tripwire branch, and restore the two
exemption entries. Reverting restores a documented write-scope hole, so it
MUST be paired with re-opening DIA-260827-ft3z. It is not a silent option.

## Alternatives considered

### Variant A: Narrow the four write modes with deny patterns

Reject the specific flags (`-o`, `-O`, `-P`) and shell redirection. Rejected.
Tier-1: `.opencode/learnings/external-patterns/2026-09-10-shell-redirection-write-scope-bypass.md`
and `.opencode/learnings/external-patterns/2026-11-01-opencode-permission-resolver-findlast-and-deny-first-maps.md`
record that prefix matching cannot parse quoting, flag variants, redirection,
or substitution; the campaign closed the analyzer lanes by removing the shell,
not by narrowing it.

### Variant B: Keep bash and add a general plugin command parser

Rejected. Tier-1: the same two findings, plus
`knowledge/archive/res009-snip-jq-filter-truncation/res009-snip-jq-filter-truncation-conspect.md`
which shows a real plugin can rewrite `output.args.command` but also documents
the quoting and pipe-splitting failures such a parser accumulates. A parser
that must handle redirection and substitution is the same incomplete
allow-list with extra steps.

### Variant C: Typed tool only, no tripwire

Rejected by the developer's scope decision: the named work includes a residual
protected-path gate for the implementation lanes that keep a shell. [INFERENCE]
Without it, the config gate's dangerous-shape probe list would gain shapes with
no runtime counterpart.

### Variant D: Typed tool plus a narrow tripwire

Chosen. Tier-1: the tool makes the researcher property provable (single
validated boundary, no shell), and the tripwire is cheap accident protection
for `coder`/`coder-escalated`, scoped to a fixed path set and documented as
non-provable.

### Variant E: Status-quo / do nothing

Rejected. Tier-1: `.opencode/scripts/lib/jsonc-parse.js` already carries
`researcher` in `EXEMPT_EDIT_BASH` with a pointer to this ticket, so the hole
is documented rather than closed, and the ticket's own verification line
remains false.

### Chosen: Variant D

Because the typed tool is the only provable control for the researcher lane
(Tier-1 campaign finding) and the narrow tripwire is the developer-approved
residual for the lanes that must keep a shell.
