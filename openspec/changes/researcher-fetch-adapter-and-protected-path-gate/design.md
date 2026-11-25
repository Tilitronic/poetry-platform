# Design: researcher fetch adapter and protected-path gate

> DIA-104 gate decision (for orchestrator transcription into the ticket
> frontmatter):
>
> gate_state: grilled
> gate_triggers: cross-cutting, new-public-api, hard-to-reverse, cross-boundary, new-module
> gate_waivers: none
> gate_override: none

## Context

See `proposal.md` for motivation. The governing surfaces are the permission
maps in `.opencode/opencode.jsonc`, the config gate in
`.opencode/scripts/lib/jsonc-parse.js` (invoked by
`.opencode/scripts/validate-opencode-config.sh` from `make test-config`), and
the delegation-observer plugin's `tool.execute.before` hook. No `.sdd/`
document governs this module. The change follows the existing
`architecture.md` principles of validation at the edge, high cohesion, and
testable seams; it adds no application module and no system architecture
boundary.

The developer's interview decisions are settled: elimination for the
researcher lane, a typed tool plus a narrow tripwire, tripwire scope limited
to `coder` and `coder-escalated`, and explicit deny-scoped bash maps for
`designer` and `memory-manager`.

## Goals / Non-Goals

**Goals:**

- Make the researcher write property provable at one validated boundary.
- Keep the researcher Phase A workflow (3-tier capture, per-source evaluation,
  `.source-urls.txt` manifest) intact through the typed tool.
- Close the inherited-global-allow debt for `designer` and `memory-manager` in
  config.
- Add a cheap accident tripwire for the two implementation lanes that must
  keep a shell, and label it honestly.
- Extend the existing config gate rather than adding a parallel gate.

**Non-Goals:**

- Building a general shell sandbox or a complete shell parser.
- Restricting coder interpreter permissions (`node`, `bun`, `python3`).
- Protecting `.opencode/` or `AGENTS.md` from `coder`: coder is the config
  implementer and must write them.
- Changing the artifact content format or the `.source-urls.txt` semantics.
- Editing the ticket ledger, adding a runtime dependency, or touching the
  stale duplicate change directory.

## Decisions

### D1: Remove the researcher shell and replace it with a typed tool

**Choice:** Set `researcher.bash` to the flat string `"deny"`. Add a custom
tool `fetch-source` that takes `{url, output_path}`, validates the destination,
fetches internally, and publishes atomically.

**Rationale:** The campaign proved that a text allow-list over a shell cannot
be made complete: every hole found was a tool with an execution or write mode.
Removing the shell is the only provable control. A typed tool also removes the
caller-selected command string, which is the class of input the allow-list
could not constrain.

**Alternatives considered:** narrowing the four write modes (rejected: the
same incomplete allow-list); keeping bash and adding a parser (rejected: the
parser must handle redirection and substitution, which is the same problem).

### D2: Tool registration and permission (open question 1)

**Choice:** Register the tool at `.opencode/tools/fetch-source.ts`. The tool
name is derived from the filename stem (`fetch-source`). Add an explicit
`"fetch-source": "allow"` entry to the `researcher` permission map. The tool
also enforces `context.agent === "researcher"` internally.

**Evidence:** `.opencode/tools/get-my-session-id.ts` is a working custom tool
in this repo. Its header states that the tool name is derived from the file
name, and it is callable by agents whose permission maps contain no entry for
it, which shows a custom tool's visibility follows the default tool baseline
rather than the `bash` key. The plural `.opencode/tools/` path is the proven
surface; the singular `.opencode/tool/` spelling from some upstream docs is
not used here. Permission maps key tool names directly (`webfetch`,
`ast_grep_replace`, `envsitter_*` in `.opencode/opencode.jsonc`).

**Why the allow is load-bearing, not cosmetic:** custom tools are NOT
permission-gated at runtime. The plugin-tool execute wrapper performs no
`ctx.ask`, and the `edit` key governs only edit/write/apply_patch. The only
pre-execute control is the visibility gate: a flat deny hides the tool from
that agent's schema entirely, while an object map with trailing allows is a
no-op. The global permission block therefore gains a flat
`"fetch-source": "deny"`, which hides the tool from every lane, and
`researcher` keeps `"fetch-source": "allow"`; because agent rules append last,
the allow wins for that lane. Remove either entry and the tool either
disappears from the researcher or appears for every lane.

**Why the in-tool agent guard is required:** because the runtime performs no
per-tool permission check, the `context.agent === "researcher"` guard is the
real runtime access control. The visibility gate is the schema-level control;
the guard is the execution-level control.

**Evidence for the visibility-gate mechanism:**
`.opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md:50-58`
records that core performs no generic per-tool-name permission check and that
the tool wrapper only fires `tool.execute.before/after`, so deny-by-default at
the tool-availability level is the only lever.

**Verification step (first task):** register the tool, then run
`opencode debug agent researcher` to confirm the tool and the flat-deny bash,
and `opencode debug agent coder` to confirm `fetch-source` is absent from that
lane's tool surface. Record both outputs as runtime evidence.

### D3: Destination validation is resolved-path based

**Choice:** Resolve the workspace root, join the caller's `output_path`,
create the parent directory, canonicalize the parent, and require the resolved
target to stay under one of the two roots with a path-separator boundary.
Reject `..` that escapes, absolute paths outside the roots, and any symlink
target that resolves outside. Accept only `http` and `https` URLs. Write to a
temporary sibling and rename into place only after the fetch succeeds.

**Rationale:** Lexical prefix checks are defeated by traversal and symlinks.
Atomic publication prevents a failed fetch from leaving a partial artifact
that downstream synthesis treats as complete.

### D4: The tool owns the tier order and degrades (open question 3)

**Choice:** The tool implements the order: npm registry JSON API, then
trafilatura, then crwl as last resort. It returns `{status, tier, bytes,
resolved_path}`. Tier 3 is optional: if `crwl` is missing, the tool reports
the tier as unavailable and is not in error.

**Evidence:** `Dockerfile.dev:226` installs `crawl4ai` system-wide with
`uv pip install --system --break-system-packages playwright crawl4ai`, and the
`crawl4ai` package ships the `crwl` entry point. Unlike trafilatura, there is
no smoke probe for `crwl` (`scripts/test-docker-smoke.sh:154-168` probes
trafilatura only). The design therefore does not depend on the binary: the
first implementation task confirms `crwl --version` inside the dev container,
and absence is handled as a degraded tier rather than an error.

### D5: The tripwire is narrow, scoped, and not a boundary (open question 2)

**Choice:** Add a bash branch to `tool.execute.before`. Read the command from
`output.args.command`. Scope it to `coder` and `coder-escalated` by looking up
`childSessionAgent.get(input.sessionID) ?? sessionAgent.get(input.sessionID)`
(the first is populated at `.opencode/plugins/delegation-observer.ts:2748`;
the second is the best-effort backfill described below). Block a command whose
literal write destination resolves under `.git/`, `.opencode/session/`, or
`docs/dev-infra-audit/tickets/`. Throw before execution and append a registry
row naming the denied target and the rule.

**Ordering fact:** `tool.execute.before` runs BEFORE the permission check; the
permission evaluation happens inside each built-in tool's `execute` via
`ctx.ask`. Throwing from the hook therefore skips `item.execute` entirely.
Evidence:
`.opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md:50-58`
records that core performs no generic per-tool-name check and that the tool
wrapper only fires `tool.execute.before/after`, while asks live in execute
bodies (for example `oh-my-opencode-slim@2.2.19/dist/index.js:43111-43132`);
the repo's own thrown-Error gates (`delegation-observer.ts:1781-1784`,
`1850-1855`) are the precedent that a throw prevents the call. This ordering
is why the tripwire is meaningful rather than redundant: it is the only
pre-execution check for a bash command.

**Evidence for the command key:** `@opencode-ai/plugin/dist/index.d.ts:235-241`
declares `tool.execute.before(input, output)` with `output.args: any` as the
mutable tool-args object. The repo's own learning
`.opencode/learnings/external-patterns/2026-08-07-plugin-hook-args-contract.md`
records that tool arguments live in `output.args`. The committed conspect
`knowledge/archive/res009-snip-jq-filter-truncation/res009-snip-jq-filter-truncation-conspect.md:28`
records the exact key: the opencode-snip plugin rewrote
`output.args.command`. The classifier reads the value only when it is a
string.

**Extraction scope:** an explicit form set: redirection (`>`, `>>`, `1>`,
`2>`, `&>`), `tee`, `dd of=`, `sed -i`, `sort -o`, `uniq` with a positional
output, `curl -o`/`--output`/`-O`, `wget -O`/`-P`, `trafilatura -o`, and
`crwl -o`. Anything outside that set passes unless a protected literal is
present in a write-shaped context.

**Why this is not a boundary:** the tripwire reads a command string and cannot
see interpreter writes (`python3 -c`, `node -e`) or arbitrary future tools.
The config gate's dangerous-shape probe list and the review process remain the
layers for that class. The design and all docs MUST call the tripwire accident
protection and MUST NOT claim it is provable. The provable control in this
change is D1-D4.

**Honest coverage ceiling (fail-open set):** the lane lookup is best-effort
and silently skips four cases: (1) root sessions never dispatched through
`task()`; (2) sessions created before an OpenCode or plugin restart, because
the map is in-memory only and is never seeded; (3) sessions revived via
`task_revive`, which produces no new `task()` output; (4) dispatches whose
task output carried no parseable id. Nobody may read the tripwire as covering
resumed coder sessions. A best-effort widening is adopted: populate a
`sessionAgent` map from the `session.created` event (`info.agent`, precedent
`.opencode/plugins/needs-input-observer.ts:1407-1416`) and resolve
`childSessionAgent.get(id) ?? sessionAgent.get(id)`. This covers sessions
created after plugin load, including root sessions and the no-parseable-id
case, but it does NOT close case (2) pre-restart or case (3) revive. It stays
a widening, not a boundary, and the honesty label in the docs and the registry
row MUST keep that wording.

**Alternatives considered:** reuse `isProtectedPath()` (rejected: it protects
`.opencode/` and `AGENTS.md`, which coder must write); apply to all lanes
(rejected by the developer's scope decision); block every unknown command
(rejected: it would break ordinary coder work and still not be complete).

### D6: Close the inherited-shell debt in config

**Choice:** `designer` gets `"bash": "deny"`. `memory-manager` gets a
deny-first map with `"*": "deny"`, read-only git (`git log *`, `git diff *`,
`git show *`, `git status *`), and
`"bash scripts/validate-memory-shelf.sh *"`. The pattern MUST be the `bash ...`
form with the trailing ` *`: permission patterns match the whole raw command
string, so the bare `"scripts/validate-memory-shelf.sh"` pattern matches only
a bare invocation and not `bash scripts/validate-memory-shelf.sh`, which would
fall through to the catch-all deny. The trailing ` *` also matches the bare
form. `.opencode/agents/memory-manager.md` MUST prescribe exactly
`bash scripts/validate-memory-shelf.sh` so the document and the permission
pattern cannot drift apart. Its inline `python3 -c` YAML check is replaced by
that invocation.

**Rationale:** allowing `python3 *` would re-open the exact dangerous
execution shape the config gate probes for, so the map cannot admit it. The
existing validator script gives the lane the same check without a shell
primitive.

**Consequence:** remove `researcher` and `memory-manager` from
`EXEMPT_EDIT_BASH` in `.opencode/scripts/lib/jsonc-parse.js`. The set becomes
empty, so a new agent appearing in that state fails loudly.

### D7: Extend the existing config gate

**Choice:** Add the four reproduced shapes to
`DANGEROUS_EXECUTION_SHAPES`: `curl -O x`, `wget -P x http://x`,
`trafilatura -o x`, and `crwl -o x`. Extend the doc-drift `FORBIDDEN` list
with the shell-claim spellings a now-restricted lane must not keep (`bash
allow-list`, `bash (allow-list`, `curl *`, `wget *`). Add bats cases that
execute the former hole through the resolver and a fixture that re-adds
`curl *` and fails.

**Rationale:** the gate already has the resolver, the probe list, the
invariant, and the doc-drift tripwire. Extending it keeps one source of truth
and makes the former hole a regression test rather than a comment.

### D8: Delta spec is required, and the changelog-lookup text goes stale (open question 4)

**Choice:** create `specs/write-scope-enforcement/spec.md`. Update the
changelog-lookup eligibility text in
`.opencode/oh-my-opencode-slim/orchestrator_append.md`.

**Evidence for the spec:** `openspec/schemas/spec-driven/schema.yaml:38-69`
makes the `specs` artifact a required dependency of `design`, and
`openspec status --change ... --json` lists `specs` as blocked on the
proposal. `skip_specs` is not appropriate because behavior changes.

**Changelog-lookup finding:** `orchestrator_append.md:477-484` says `designer`
and `memory-manager` are not eligible lookup lanes because "neither declares a
bash key, so their bash resolves to the global `*: allow` baseline" and "they
stay off this list until their maps are closed." After D6 their maps ARE
closed, so that reason is stale. The eligibility OUTCOME does not change:
neither lane can run the `python3` lookup. The text needs updating to state
the new reason (deny-scoped map admits no `python3`) and to drop the
"until their maps are closed" clause. This design does not edit that file; a
task assigns it to the implementation lane.

### D9: The stale duplicate change directory is left alone

`openspec/changes/dia-260827-ft3z-fetch-artifact-write-containment/` already
exists for the same ticket and describes a `resource-manager` lane that no
longer exists. It is out of scope for this change and MUST NOT be edited or
archived as part of it. The orchestrator should archive or remove it
separately so two changes do not archive the same capability.

## Seams

These are the pre-agreed boundaries where tests live.

- **Pure destination policy:** a module with no plugin imports that resolves a
  candidate path against the workspace root and returns allowed or rejected
  with a reason. Tested by a Node `.mjs` suite under `scripts/__tests__/`
  wired into `make test-config`. Cases: both roots accepted; `../` escape;
  absolute outside; symlink escape; non-http scheme.
- **Typed tool handler:** `.opencode/tools/fetch-source.ts` calls the pure
  policy, fetches, and publishes. Tested for the agent guard and the tier
  result; the network path is exercised by one smoke case, not by a live
  external fetch in the gate.
- **Bash tripwire classifier:** `.opencode/plugins/lib/bash-write-gate.ts`, a
  pure classifier over the command string and the caller lane. Tested by a
  Node suite for the form set and the protected set, and by the real
  `tool.execute.before` hook under the bun plugin harness for the
  `output.args.command` contract.
- **Config gate:** `.opencode/scripts/lib/jsonc-parse.js` plus bats fixtures in
  `scripts/__tests__/test-config-wiring.bats`. This is where the former hole
  is executed as a negative test.

## Risks / Trade-offs

- **The tripwire cannot see interpreter writes** -> documented non-boundary;
  the provable control is the typed tool, and the dangerous-shape probe list
  covers the config side. [INFERENCE] Residual risk is accepted by the
  developer's scope decision.
- **Agent lookup is unavailable in the hook for some sessions** -> the
  tripwire applies only when the lane resolves, and the fail-open set is:
  (1) root sessions never dispatched through `task()`; (2) sessions created
  before an OpenCode or plugin restart (the map is in-memory and is never
  seeded); (3) sessions revived via `task_revive` (no new `task()` output);
  (4) dispatches whose task output carried no parseable id. A best-effort
  `session.created` backfill widens coverage for sessions created after plugin
  load but does not close (2) or (3). Nobody may read the tripwire as covering
  resumed coder sessions.
- **The tool becomes a cross-lane write primitive** -> the in-tool agent guard
  rejects every caller except `researcher`.
- **Symlink race between validation and write** -> create the parent first,
  canonicalize it, then write a temp sibling and rename; a post-mkdir
  canonicalization closes the common case.
- **memory-manager loses its inline YAML check** -> replace it with the
  existing `scripts/validate-memory-shelf.sh`; update the agent document.
- **Doc drift after the config change** -> the doc-drift gate extension plus a
  docs task covers researcher, memory-manager, the slim prompt, and the
  changelog-lookup text.
- **Rollback restores the hole** -> rollback is a single revert, but it MUST be
  paired with re-opening DIA-260827-ft3z.

## Migration Plan

1. Write the failing seam tests: pure destination policy, tripwire classifier,
   and the config-gate negative case.
2. Register the tool and record `opencode debug agent researcher` output.
3. Implement the destination policy, then the tool handler and tier chain.
4. Migrate the config: researcher flat deny, designer flat deny,
   memory-manager deny-scoped map, remove the two exemptions.
5. Wire the tripwire into `tool.execute.before` for the two coder lanes, with
   the best-effort `session.created` agent backfill.
6. Update the docs and the changelog-lookup eligibility text.
7. Run `make test-config`, the plugin harness tests, restart OpenCode, and
   perform one permitted fetch smoke test plus one protected-path denial smoke
   test. Obtain ai-auditor review, then register the change in the changelog.

## Rollback

Revert the implementation as one commit: restore the previous researcher bash
map, delete `.opencode/tools/fetch-source.ts`, remove the tripwire branch and
`lib/bash-write-gate.ts`, restore the two `EXEMPT_EDIT_BASH` entries, and
restore the previous docs. Because the revert restores a documented
write-scope hole, it MUST be paired with re-opening DIA-260827-ft3z; a silent
rollback is not acceptable.

## Open Questions

None. The four interview open questions are resolved above; the only remaining
items are verification steps assigned to tasks (runtime permission report and
`crwl` presence), and neither changes the specs, the approach, or the task
breakdown.
