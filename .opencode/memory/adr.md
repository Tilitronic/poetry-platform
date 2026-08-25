# ADR: Memory Storage Strategy

## Status

Accepted — 2026-07-20

## Context

We evaluated two external memory solutions against our current hand-written memory manager to determine if adopting an established tool would improve our knowledge persistence layer.

**Current setup**: A 36-line agent file (`.opencode/agents/memory-manager.md`) that writes 4 markdown files to `.opencode/memory/` — `adr.md`, `lessons.md`, `repo.md`, `failures.md`. Triggered by the boss orchestrator after task completion or after >=2 failed loop iterations. Core principle: "If recoverable from git log, diff, tests, or code — do not store." Zero external dependencies.

**Candidates evaluated**:

1. **Claude-Mem** (thedotmack/claude-mem) — 88k stars, Apache-2.0, npm package. Persistent context compression via 5 lifecycle hooks, SQLite + ChromaDB, Bun worker service. Has `npx claude-mem install --ide opencode`.

2. **Honcho** (plastic-labs/honcho) — 6.1k stars, AGPL-3.0, Python FastAPI server. Peer-centric memory infrastructure with background reasoning pipeline (deriver), Postgres + pgvector. Has `opencode plugin "@honcho-ai/opencode-honcho" --global`.

**Evaluation was performed by three agents in parallel**: Council (holistic product comparison), Architector (architectural fit analysis), and AI Assist (integration analysis — unavailable, supplemented by Council).

## Decision

**Keep the current hand-written memory manager.** Neither Claude-Mem nor Honcho should be adopted.

## Rationale

### Why not Claude-Mem

1. **Philosophy mismatch**: Captures everything automatically via hooks. We need selective persistence of irrecoverable knowledge only. Our core principle is the opposite of Claude-Mem's design.
2. **OpenCode integration is broken**: Two open issues confirm the installer doesn't register the plugin or MCP server correctly (#2669, #2295).
3. **Architectural conflict**: Claude-Mem's lifecycle hooks compete with OMO Slim's foreground-fallback hooks for the same session lifecycle events.
4. **High coupling**: Hooks run inside the session process. Replacing it means removing hook registrations, not swapping a storage backend.
5. **Security concerns**: Unauthenticated HTTP API on port 37777, prompt injection vectors via stored observations (#1251).
6. **Overkill**: 87k-star project solving a problem we solved in 36 lines. Massive dependency chain (Bun + uv + SQLite + ChromaDB) for 4 markdown files.
7. **Release velocity risk**: 297 releases in ~10 months = high breakage probability.

### Why not Honcho

1. **Wrong abstraction model**: Peer-centric (users, agents, groups, projects as entities). Designed for user profiling and stateful conversational agents. We need ADRs, failure patterns, and repo facts — not psychological representations.
2. **Infrastructure bloat**: FastAPI server + Postgres + pgvector + background deriver worker for ~2KB of markdown content.
3. **Unnecessary AI pipeline**: Background reasoning triggers LLM API calls per message to derive "conclusions" about agent psychology we don't track.
4. **API-bound latency**: Deriver pipeline adds async latency to what should be a fast filesystem write.

### Why current is correct

1. **Zero coupling**: Agent reads filesystem, writes filesystem. No hooks, no services, no external deps. Replace = delete the files.
2. **Perfect data flow alignment**: Fires at the persist step only, not during session (like Claude-Mem) or through an API pipeline (like Honcho).
3. **Git-native storage**: Markdown files are version-controlled, diffable, PR-reviewable. SQLite and Postgres are opaque binary stores.
4. **OMO Slim native**: memory-manager is a proper OMO Slim agent with orchestratorPrompt, preset entry, and boss-controlled dispatch.
5. **Clean separation of concerns**: Memory logic lives in the agent. Storage is dumb files. No infrastructure layer.
6. **Trivially extensible**: Add a new `.md` file + update orchestratorPrompt. No schema migrations, no service restarts.

## Consequences

- Zero infrastructure overhead. Memory is human-readable, diffable, PR-reviewable.
- No external API costs or vendor lock-in.
- Memory scale is bounded by what fits in 4 markdown files (currently adequate, hundreds of entries possible before needing escalation).
- If memory grows beyond ~50 entries per file, add `index.yml` as TOC. If >100 entries with fuzzy search needs, add SQLite FTS5. If semantic similarity needed, add sqlite-vec.

## Escalation Path

| Level | Trigger | Solution |
|-------|---------|----------|
| 0 (current) | <50 entries/file | 4 markdown files, zero deps |
| 1 | >50 entries/file | Add `index.yml` as table of contents |
| 2 | >100 entries + fuzzy search | Add SQLite FTS5 |
| 3 | Semantic similarity needed | Add sqlite-vec |
| 4 | Multi-agent cross-project sharing | Evaluate Honcho-style API |

We are at Level 0. Level 4 is for a different problem.

## ADR Metadata

- **Created**: 2026-07-20
- **Supersedes**: N/A (first memory storage ADR)
- **Related**: memory-shelf.yaml, .opencode/agents/memory-manager.md

## ADR: Dev-infra orchestration boundary — turbo vs host Docker

### Status

Accepted — 2026-08-01

### Context

During a recent change we added dev-infrastructure helper scripts (dev-stack.sh, Makefile targets, test harnesses) and formalised workflow rules about who may implement dev-infra changes. A recurring confusion surfaced: where should orchestration live when using turbo (task runner) together with docker-compose and other host-level tooling?

Turbo (task runner) executes inside project containers and cannot control host-level services such as Docker daemon, host network, or starting sibling processes (docker-compose). Attempts to have turbo "bring up" Docker or manage host containers result in layering and permission problems.

### Decision

Place host-level orchestration (docker-compose up, starting DBs, Xvfb display setup, health-check wrappers) in host-side scripts (scripts/dev-stack.sh and similar). Keep turbo tasks inside the dev container focused on build/test steps that run within that container. Use thin host-side wrappers to manage host resources; do not rely on turbo to perform host orchestration.

### Rationale

- Separation of concerns: turbo manages in-container tasks; host scripts manage the host environment and services.
- Practical constraints: turbo lacks privileges and visibility to start host Docker; wrappers avoid permission/namespace complexity.
- Test hermeticity: host wrappers allow setting up isolated user namespaces, tmpfs mounts, and mock binaries for fast, safe CI/local runs.

### Consequences

- Keep dev orchestration scripts under scripts/ and document their role in the dev workflow. Do not attempt to replicate host orchestration inside turbo tasks.

## ADR: Dev-infra audit methodology (accepted)

### Status

Accepted — 2026-08-02

### Context

During the dev-infra audit (branch further-dev-infrastructure-development) we formalised a repeatable verification loop to ensure infra changes do not regress CI or governance gates.

### Decision

Adopt the audit methodology: inventory → vertical per-feature testing → fix-per-ticket → full re-verification loop until reaching 1 clean cycle. Define clean-cycle as: all automated gates pass and zero open Blocker/Critical tickets. Keep the local ticket ledger under docs/dev-infra-audit/tickets/ and record fix commits on a branch for traceability.

### Rationale

This process ensures fixes are small, reviewable, and verifiable independently; the local ticket ledger provides human-readable context for why each change was made.

### Consequences

- Use per-ticket branches or disjoint worktree lanes for parallel fixes; close the ledger only after a verified clean cycle. Keep the tickets folder as the canonical operational ledger for the audit run.

- Tests that require host resources should be exercised via host-side targets (Makefile test-shell / test-infra) which call the orchestration wrappers.

## ADR: Context7 docs pipeline — verification & error semantics

### Status

Accepted — 2026-08-02

### Context

The context7-docs-pipeline fetches library docs from Context7 (context7.com/api/v2) for monorepo workspace package.json deps and writes markdown under knowledge/context7-docs/. Mock mode supports offline and CI tests; real API runs are required to catch URL/auth and redirect semantics.

### Decision

1. Use https://context7.com/api as the canonical base (api.context7.com is dead as of 2026-08-02).
2. Treat 301 responses with a JSON body containing redirectUrl as an application-level redirect; if redirectUrl absent or not resolvable, record the library as "skipped" (not failed). If redirect loops exceed depth cap, mark as "failed".
3. Add a mandatory real-API smoke run (gated by CONTEXT7_API_KEY_REAL_RUN env) in verification before merging network-touching dev-infra changes.

### Rationale

- DNS/host state is external to the repo and can change over time; recording the canonical base avoids regressions.
- Mock-mode tests can't catch URL composition or server auth header mismatches; a single real-API smoke reduces regressions while keeping CI hermetic by gating behind opt-in env.

### Consequences

- Verification must include at least one real API run when adding or changing networked dev-infra scripts.
- The pipeline's error semantics (skipped vs failed) are preserved and should be consulted when interpreting run reports.

## ADR: Orchestrator operating model — delegation-only, read-restricted, session-continuity handoff

### Status

Accepted — 2026-08-02

### Context

Following the dev-infra audit and owner directive (DIA-036), the team formalised an operating model for the orchestrator to reduce risk from an agent that can edit or read repository state. The change was approved after ai-specialist review and independent review (followed §10 gate). The WHAT (commit pointers, CHANGELOG, and DIA-036.md) remain in git; this ADR records the irrecoverable WHY/context and operational gotchas that guided the decision.

### Decision

1. The orchestrator will be delegation-only: it must not perform direct code edits. Its role is messaging, workflow orchestration, and strict delegation to human or coder agents.
2. Read-restriction: the orchestrator is forbidden from reading repo files except for its own session messages-log under .opencode/session/, the ticket ledger under docs/dev-infra-audit/tickets/, and a small set of boot/rules files: AGENTS.md, .opencode/practice-protected.md, docs/dev-infra-audit/NEXT-RUN.md. The messages-log is gitignored and treated ephemeral.
3. Session-continuity handoff: when the orchestrator's session context usage reaches the configured threshold (owner-specified threshold — manual: token_stats vs model-window lookup table in NEXT-RUN.md), the orchestrator performs a manual handoff: a human-instigated restart of a new orchestrator instance that resumes from HANDOFF.md + messages.md. Child-dispatch automatic handoff is NOT used; the owner explicitly approved manual handoff.

### Rationale (irrecoverable context)

- Owner intent: the owner required read strictness and delegation-only operations to reduce accidental repo changes and governance risk; this is a policy-level decision not reconstructible from code.
- Manual handoff rationale: manual handoff gives an explicit human checkpoint and prevents silent session forks or runaway automated restarts that could circumvent policy. The approval explicitly chose manual handoff over child-dispatch — record this as an operational constraint.
- Messages-log gitignored: keeping the orchestrator's session log out of git reduces secret/leak risk and prevents session artifacts from being treated as authoritative repo history. This gitignore choice plus the expectation that boot tolerates a missing .opencode/session/ directory (fresh clone) is an operational gotcha to record: boot must not fail if session messages are absent.
- Token window & handoff frequency gotcha (CORRECTED 2026-08-03): deepseek-v4-flash's actual context window is **1,000,000 tokens** (verified against models.dev 2026-08-03 — V4-Flash, NOT the V3-Flash 64k window). The 50% threshold therefore maps to ≈500K tokens, and sessions run ~15.6× longer than the old 64k assumption suggested. Operational consequence: ALWAYS verify context windows against models.dev before handoff decisions (verify-on-use); the old 50% → ~32k mapping is wrong and superseded. Cross-ref repo.md / lessons.md for the correction trail.
- Permission ordering: the owner required a catch-all "*" permission rule ordered FIRST to make read restrictions explicit per OpenCode docs. The ordering fix was applied during review; record that path-scoped permission semantics and ordering are an implementation gotcha. CONFIRMED by DIA-126 (2026-08-13): OpenCode's tool-visibility gate uses findLast over the flattened permission rules, so a TRAILING "*": "deny" hides the ENTIRE tool from the agent's function schema (same mechanism as DIA-081 for the task tool). The runtime tool manifest, not the config read, is the ground truth for whether a tool is exposed. Catch-all-FIRST is therefore a hard requirement, not a style preference.

### Consequences

- Implementations must make boot tolerant of a missing .opencode/session/ (no messages.md) to support fresh clones and scripted CI runs.
- Monitoring: add a small operational monitor that alerts when session context usage crosses the 50% threshold to schedule a manual handoff. Token->window math should be documented in NEXT-RUN.md.
- Policy: reviewers and auditors should confirm orchestrator code and configs only reference permitted files; runtime checks should enforce read restrictions where possible.

## ADR: Agent-naming contract — declared-⊆-resolved containment

### Status

Accepted — 2026-08-04

### Context

During the DIA-045 dev-infra-config-validators cycle we attempted to codify a strict 4-source equality contract for canonical agent names (AGENTS.md §9, .opencode/opencode.jsonc agent block, .opencode/oh-my-opencode-slim.jsonc, and `.opencode/agents/` files). Runtime discovery showed two irreconcilable facts: `.opencode/agents/` is an auto-loaded runtime source (creating .md files registers agents at startup), and the `council` block in oh-my-opencode-slim.jsonc holds model/preset seats, not agent-name declarations.

### Decision

Adopt a containment contract: AGENTS.md §9 remains the human-canonical list (S1). The enforced invariant is declared-⊆-resolved containment: every canonical name in AGENTS.md must resolve in at least one runtime source (S2 ∪ S3 ∪ S4), and every name declared in S2 ∪ S3 must appear in the canonical list (AGENTS.md) when they represent canonical agent names. Council entries are treated as model/preset seats and are not canonical agent names.

### Rationale

- Practical runtime semantics: `.opencode/agents/` auto-loads agent .md files at startup; treating S4 as authoritative for runtime-enablement prevents accidental name drift.
- The council block contains model seat identifiers; conflating them with agent names caused false assumptions during validator design.
- Containment is easier to enforce and aligns with OpenCode's runtime behaviour.

### Consequences

- Validators implement containment checks (declared -> resolves) rather than strict 4-way equality. Update AGENTS.md language to mirror the algorithmic contract and reference this ADR for traceability.
- When adding or disabling agent names, update AGENTS.md and ensure at least one runtime source will resolve the name (create or remove .opencode/agents/*.md as needed).

## ADR: Plugins-as-hooks — delegation-observer plugin

### Status

Accepted — 2026-08-04

### Context

During the Tickets System 2.0 campaign we experimented with a lightweight plugin that observes and records delegation lifecycle events (dispatch, start, complete, compact) to an append-only registry (registry.jsonl) to detect silent dispatch failures and enable exact subagent-session recall. There was a debate whether to treat plugins as full lifecycle hooks or keep a separate bespoke hook mechanism. The implementation (`.opencode/plugins/delegation-observer.ts`) subscribes to the runtime's tool.execute.before/after events and a generic event catch-all; it also writes an experimental.session.compacting record when sessions are compacted for long-term storage.

### Decision

Treat OpenCode plugins as the canonical lightweight hook mechanism for lifecycle observation in this repository. The delegation-observer plugin pattern (subscribe -> record -> emit sidecar) is accepted as the standard for non-invasive lifecycle instrumentation and monitoring where a full hook subsystem is unnecessary.

### Rationale (irrecoverable context)

- Owner preference for minimal, git-ignored sidecars: the registry.jsonl is append-only and gitignored by design to avoid leaking ephemeral session payloads into commits. This operational choice and the rationale (reduce leaks, keep tracked commits clean) are policy-level and not reconstructible solely from code diffs.
- Reduced blast radius: plugins run as observers and do not change dispatch semantics; they can detect silent drops (A3) without altering runtime behaviour. This makes them suitable for forensic recording and automated monitoring while preserving the delegatory operating model.
- Practicality: subscribing to tool.execute.before/after provides reliable dispatch/start/finish signals without invasive runtime patches; the pattern proved effective in the Tickets System 2.0 run.

### Consequences

- Adopt the delegation-observer plugin pattern for future lifecycle monitoring needs instead of introducing a separate hook subsystem.
- Document plugin subscriptions and the registry.jsonl schema in the session/ README and memory entries when their semantics are policy-relevant.

### Amendment (2026-08-09) — enforcement-gate exception

Plugins remain the canonical OBSERVER hook mechanism — but enforcement gates are an accepted extension for workflow invariants (precedent: §10 edit-gate + DIA-063 ticket-creation gate in `.opencode/plugins/delegation-observer.ts`). An enforcement gate may intentionally block dispatches/edits where the workflow contract requires it. Any enforcement gate must:

1. be additive — never alter the observed lifecycle rows or the registry schema;
2. fail-soft on scan errors — a broken gate is worse than no gate (warn + allow + `ticket_gate_scan_failed` row);
3. log every blocked attempt to registry.jsonl (e.g. `ticket_gate_blocked`, `a1_violation`, §10 gate) for observability;
4. carry a rollback plan — `git checkout .opencode/plugins/delegation-observer.ts` + restart OpenCode restores observer-only behavior.

## ADR-003 verification result (c-20260804-0900)

- Date: 2026-08-04
- Verified-by: coder (ses_031c09d51ffeZwaUAF5Yk00rs8)
- Verdict: PASS-WITH-EXPECTED-RESIDUAL

Notes:
- Fresh-session independence checks (NEXT-RUN.md §3) executed verbatim; all gates exit 0 except two expected residuals:
  - audit-python exit 2: known pip-audit finding (ecdsa 0.19.2 PYSEC-2026-1325). Fix Versions empty; DIA-034 accepted-with-justification.
  - check-tools exit 2: host-conditional behaviour (host lacks `mise` on PATH; `mise` ships in dev container). Matches Makefile comment and campaign reviewer flag F5.

Decision rationale:
- Record the PASS-WITH-EXPECTED-RESIDUAL state so the ADR's compliance history is preserved outside the gitignored session log. The session messages (rows 346-348) are gitignored and therefore not a durable archive.


## ADR: Per-agent token tool deny model (DIA-055) — closure of default-allow surface

### Status

Accepted — 2026-08-08

### Decision

Adopt the per-agent "token_*": "deny" permission model as the canonical permission-hardening approach for token-related tools (token_export, token_stats, token_history). Do not rely on a global deny + per-agent allow pattern; enforce deny entries per-agent in .opencode/opencode.jsonc to ensure consistent, auditable tool surfaces.

### Rationale (irrecoverable context)

The decision was driven by observed runtime behaviour where plugin arrays and config layers concatenate, making global-level deny semantics unreliable without per-agent overrides. The owner-approved fix explicitly enumerated per-agent deny entries for agents that previously had default access.

### Consequences

Applied closure: added per-agent token_* deny entries for six residual agents (coder, code-navigator, researcher, designer, observer, memory-manager) bringing the repository total to 13 token_* deny entries (7 pre-existing + 6 newly-denied). This change is an operational permission model decision and should be audited per-release.

### Related / Follow-up

DIA-066 spun off as a follow-up low-priority ticket to implement a tool-coverage audit script (investigate tool enumeration gaps across config layers).


## ADR: Interim guard → vendored patch → upstream PR pattern (DIA-069)

### Status

Accepted — 2026-08-08

### Context

When a third-party or vendored plugin performs destructive or non-idempotent writes to tracked repository files at runtime (for example, rewriting command docs with absolute HOME paths), the working tree can be polluted repeatedly even when pre-commit guards block commits. Such pollution is a runtime behaviour and is not recoverable from git history alone. A repeatable, low-risk mitigation pattern was exercised during DIA-069 and deserves ADR-level capture so future teams follow the safe containment→fix→reconcile flow.

### Decision

Adopt the following pattern when a vendored plugin clobbers tracked files on load:

1. Immediate containment: commit a portable baseline of the affected files (templates that include $HOME placeholders or safe defaults) and add an owner-run restore script + Makefile target to restore the baseline quickly. Add watcher.ignore for the affected paths to avoid watcher-trigger loops during verification.
2. Short-term durability: apply a vendored runtime patch in the local package cache (with backups, e.g. .bak-dia069) to make the plugin respect existing files or be idempotent. This reduces local noise for developers and CI while the upstream fix is prepared.
3. Durable upstream fix: prepare an upstream patch/PR with an audit-able changelist and submit it through normal repo/owner flows. Do not rely solely on vendored patches as a long-term solution.
4. Reconciliation: after upstream merges and a version bump, remove the interim guard artifacts (restore script, watcher.ignore) and prefer the upstream package as the single source of truth.

### Rationale

- Containment minimises blast radius: committing a guarded baseline and a restore script prevents accidental commits of polluted files and gives developers a simple recovery path.
- Vendored runtime patch reduces developer friction during verification and restart cycles while the upstream process completes.
- Upstream PR ensures the fix reaches all users and avoids long-lived local forks in caches.

### Consequences

- Document and version the vendored patch (path, backups) and keep a regenerated PR branch in a host-accessible staging location. Do not assume devcontainer /tmp clones are visible to host-side reviewers or CI.
- The interim guard must be removed promptly after upstream resolution to avoid drift and maintenance burden.

### Metadata

- Created: 2026-08-08
- Related: DIA-069, .opencode/learnings/external-patterns/2026-08-08-dia069-telemetry-plugin.md, scripts/restore-telemetry-commands.sh, Makefile targets: make restore-telemetry-commands, make test-telemetry-guard

## ADR: Gate scripts that invoke the full test suite must carry a re-entrancy guard

### Status

Accepted — 2026-08-12

### Context

A recursion fork-bomb regression (DIA-161) occurred when `make test-shell` was
wired into `scripts/verify-pre-push.sh` (commit 49d587a). Invoked inside the
dev container, the script takes the direct branch (hostname==poetry-dev) and
re-enters the full suite: verify-pre-push.sh -> make test-shell -> bats ->
verify-pre-push.bats -> same script -> infinite loop (~18s cycle, 6+ levels
deep, dozens of /tmp/bats-run-* dirs). The test-side hermetic hostname/PATH
shim (commit bb18099, DIA-071) covers only the bats suite and does not protect
manual or husky invocations.

### Decision

Any gate script that can invoke the full test suite MUST guard against nested
invocation with an env-flag that propagates through process spawns (the
`VERIFY_PRE_PUSH_RUNNING` pattern): set the flag before running the suite and
short-circuit early if the flag is already present. Do not rely on test-side
PATH/hostname shims as the primary defense — they are necessary-but-not-sufficient.

### Rationale

- The recursion vector lives in the gate script itself, so the guard belongs
  there (root-cause fix, one location) rather than patching every caller or
  relying on test-environment shims that only apply inside the bats harness.
- An env-flag survives process spawns naturally (child processes inherit the
  environment), so it is the minimal mechanism that closes the loop at the source.
- A one-line test-side `unset` preserves the direct-run test case so the guard
  itself remains covered.

### Consequences

- New gates that wrap the full suite must include an env-flag re-entrancy
  guard from the start.
- Test-side hermetic shims remain valuable as defense-in-depth but are no
  longer treated as sufficient protection for gate-script recursion.
- Test-side corollary (DIA-166): when a gate script exports the guard flag
  before running the full suite, the hook context propagates the flag into
  every test, so test setup() must `unset` the inherited flag to exercise the
  script's public entry behavior; a test that must verify the guarded path
  re-exports the flag inside the test body after setup. Verify hook-triggered
  suites with the hook-exact command (`VERIFY_PRE_PUSH_RUNNING=1 make
  test-shell`), not only standalone.

### Metadata

- Created: 2026-08-12
- Related: DIA-161, DIA-165, knowledge/ana015-recursion-fork-bomb/ana015-recursion-fork-bomb-report.md

## ADR: Git worktrees parallel-dev model (DIA-100) - decision record + ticket-lifecycle convention

### Status

Accepted - 2026-08-12

### Context

We adopted the worktrees-only parallel dev model (DIA-073 option d, developer
decision 2026-08-09). The mechanical design decisions are fully recoverable
from the repository: branch naming, worktree location, path mapping, the
squash-merge strategy plus its rationale, the DIA-096 safe/destructive
mapping, cleanup policy, conflict escalation criteria, session isolation
mechanism, and the orchestrator dispatch pattern are all recorded in
`docs/dev-infra-audit/worktree-conventions.md` and implemented in
`scripts/worktrees.sh` with coverage in `scripts/__tests__/worktrees.bats`
(T1-T16). This ADR records ONLY what is not recoverable from those files: the
governance convention for ticket status during a worktree feature lifecycle,
and the ticket-gate interaction that motivated it.

### Decision

1. Ticket lifecycle convention: a feature ticket's status stays OPEN through
   implementation. The ticket Fix section carries the implementation evidence
   (commit hashes, verification exit codes, verification matrix). The status is
   flipped to CLOSED only after final verification (review complete and
   findings disposed). Never invent intermediate status values (e.g. FIXED);
   keep to the canonical set OPEN/CLOSED and any explicitly-documented states.
2. When a ticket had been (non-canonically) set to FIXED, revert it to OPEN
   once the fix is implemented and the ticket awaits review/re-verification.

### Rationale (irrecoverable context)

- The section-10 ticket gate resolves DIA-id references only against OPEN
   tickets. A non-canonical FIXED status is not recognized by the gate and
   silently blocks re-review dispatch (the gateway pitfall) even though the
   work is legitimately in-progress. This is runtime gate behavior; its
   interaction with ticket status values is not recoverable from the
   conventions doc or from git diffs alone.
- OPEN through implementation (Fix = evidence) keeps the gate permissive for
   the implementation and review lanes while still recording progress; CLOSED
   is a terminal, human-verified state.

### Consequences

- When a DIA ticket reports a blocked re-review dispatch or a non-canonical
   status complaint, check the ticket status is OPEN (not FIXED or any
   invented value) and revert to OPEN before re-dispatching.
- Keep status values to the canonical set; document any new state explicitly
   before using it.

### Metadata

- Created: 2026-08-12
- Related: DIA-100, DIA-096, docs/dev-infra-audit/worktree-conventions.md, scripts/worktrees.sh, scripts/__tests__/worktrees.bats

## ADR: Hermetic sandbox seeding for faked external tools (DIA-162)

### Status

Accepted - 2026-08-12

### Context

A bats sandbox that fakes an external tool (pnpm / npx) by placing a fake binary
earlier in PATH and isolating HOME (temp-HOME) is only hermetic if the outcome
does not depend on WHICH tool resolves. The DIA-162 investigation proved the
contrary: a real login shell sourced the real ~/.profile which prepended
$VOLTA_HOME/bin, so the REAL pnpm/npx shadowed the fake in an empty sandbox and
failed with ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND. A fake-dir PATH that can be
appended to by a login profile defeats the fixture. The concrete sandbox
content (the seeded package.json and node_modules/.bin stubs) is recoverable
from `scripts/__tests__/verify-pre-push.bats` and `verify-pre-commit.bats`; this
ADR records the durable test-architecture DECISION and the tool-resolution facts
that the code alone does not explain.

### Decision

Test sandboxes that fake external tools MUST be made resolution-independent by
seeding the artifacts the real tool needs, so the outcome is identical whether
the fake or the real tool resolves:

1. Seed an importer manifest (`package.json`) so a real package manager sees a
   valid project and does not error on an empty sandbox.
2. For npx-invoked tools, place the stub at `node_modules/.bin/<cmd>` and mark it
   executable. package.json `scripts` entries are DEAD CODE for `npx`: real npx
   resolves commands from `node_modules/.bin`, not from scripts.
3. Stubs must log identically regardless of which tool invokes them. When real
   npx invokes a .bin stub it passes only the args AFTER the binary name, so
   rebuild the full command from `$0` (`basename "$0"`), never from `$*` alone.

### Rationale (irrecoverable context)

- The temp-HOME guard alone is insufficient because a login shell can re-introduce
  the host tool via the real profile's PATH mutation; hermeticity must be achieved
  by making the outcome resolution-independent, not by fighting PATH.
- These are empirically-verified tool-resolution facts (npx -> node_modules/.bin;
  real-npx vs fake-npx argument passing to stubs) that are not stated anywhere in
  the committed bats files. A future sandbox author reading only the test code
  would not know WHY the manifest and .bin stub are required, or that the
  $0-reconstruction is mandatory for byte-identical logs.

### Consequences

- New sandboxes faking npm/pnpm/npx-family tools follow the seed-manifest +
  .bin-stub + $0-reconstruction pattern.
- The temp-HOME guard is retained but no longer relied on as the sole hermeticity
  defense.

### Metadata

- Created: 2026-08-12
- Related: DIA-162, DIA-161, scripts/__tests__/verify-pre-push.bats, scripts/__tests__/verify-pre-commit.bats, lessons.md S18 "temp-HOME hermeticity breach pattern"

## ADR: git-sync of a binary DB is not viable - keep the text ledger (DIA-125 res-2)

### Status

Accepted - 2026-08-13

### Context

During DIA-125 research (Idea B) we evaluated whether a local Forgejo issue
tracker could be kept in sync across parallel sessions by pushing its database
to git. The investigation determined Forgejo's DB is SQLite BINARY
(DB_TYPE=sqlite3, PATH=data/forgejo.db), not text: git cannot merge two
divergent binary DB files (unresolvable binary conflict / lost updates / WAL
sidecar -wal/-shm corruption). The git-fetch-before-take claim protocol is
valid ONLY on text - which is exactly the existing .md ledger. git-bug
confirms text/object-based CRDT trackers (Lamport clocks) are the git-native
pattern.

### Decision

Reject git-syncing a binary DB (Forgejo or any SQLite/Postgres store) as a
sync mechanism. Keep the ticket ledger as git-backed TEXT markdown
(docs/dev-infra-audit/tickets/). Any claim/coordination protocol
(fetch-before-take, lease_expires_at + session_id single-writer token) must
operate on text files that git merges cleanly.

### Rationale

- Binary DB files are opaque to git merge; divergence is unresolvable and
  risks corruption (WAL sidecars add more opaque files). Text .md files merge
  cleanly and are ASCII-safe (DIA-079).
- A binary-DB git-sync collapses back onto needing a shared git remote anyway,
  so the text-ledger approach dominates on both the merge and remote axes.

### Consequences

- Future architecture decisions about DB sync must NOT route binary stores
  through git. Keep the durable record in text files.
- Full verdict, evidence, and source research are in the DIA-125 ticket
  (res-2 UPDATE) and knowledge/res018-ticket-management-automation/; this ADR
  records only the durable architectural rule to prevent re-research.

### Metadata

- Created: 2026-08-13
- Related: DIA-125, knowledge/res018-ticket-management-automation/,
  docs/dev-infra-audit/tickets/COORDINATION.md
## ADR: Needs-input ticker as a SIBLING observer module (DIA-122)

### Status

Accepted - 2026-08-13

### Context

Many opencode sessions run in parallel (DIA-085 worktree model) and the developer
needs to know WHICH session is blocked waiting for input. The native TUI
attention feature plays sounds but does not name the session nor maintain a
persistent multi-session ticker. Community notification plugins (opencode-alert,
opencode-simple-notify, opencode-notify, opencode-notifier, opencode-notifications,
OCX Notify) all fire an OS/terminal notification per event but NONE maintain a
persistent list of which sessions are waiting. The DIA-122 decision was whether
to build this in-house, and if so whether to extend the existing delegation-observer
plugin or add a sibling.

### Decision

1. Build the needs-input ticker + notifications in-house as a NEW SIBLING
   observer module (`.opencode/plugins/needs-input-observer.ts`) rather than
   extending `delegation-observer.ts`. No new npm dependencies are introduced.
2. Extend the established project session/telemetry pattern (silent JSONL state +
   derived view) with a second module sharing the same conventions: silent state
   file `.opencode/session/ticker.json` + derived `ticker.md` regenerated by
   `scripts/ticker-render.sh`.
3. Multi-session needs-input state machine:
   - ENTER on `question.asked` / `permission.asked` (handle BOTH v1 and v2 event
     names, e.g. `question.v2.asked`), orchestrator `session.idle` after
     delegations (delegation counter; subagent idle EXCLUDED), and a
     `wait_for_user` tool-hook as belt-and-suspenders (dedup makes double-entry
     harmless).
   - CLEAR on `question.replied`/`rejected`, `permission.replied`, a GENUINE
     `chat.message` (with a compaction auto-continue synthetic-message guard),
     non-idle `session.status`, and `session.deleted`.
   - Errors go to a SEPARATE `errors` bucket in ticker.json: never notified, only
     listed in the ticker view. An errored turn also clears the session from waiting.
   - Notifications fire on ENTER transitions only, globally debounced (~2s).

### Rationale (irrecoverable context)

- Sibling over extension: `delegation-observer.ts` is already ~1715 lines; folding
  the ticker in would violate single-responsibility and bloat a file that handles
  dispatch/session lifecycle instrumentation. A sibling keeps each plugin's concern
  narrow and independently testable while reusing the same conventions (atomic
  JSONL state, derived view, fail-soft, TUI-safe logging).
- In-house over community: the core ask is a persistent multi-session ticker, which
  no scanned community plugin provides; building it in-house keeps zero new
  dependencies and full control of session identification. This is a policy-level
  decision about the plugin ecosystem, not reconstructible from a single diff.
- Notification channel: the gate research (ai-specialist, 2026-08-12) contradicted
  the original dbus-send -> WSLg "zero-install" assumption; freedesktop Notifications
  REQUIRES a daemon absent on this WSL2 host. Final channel: in-TUI toast
  (`tui.showToast`) as primary + powershell.exe WinRT desktop toast as the
  away-from-terminal channel (WSL interop, zero installs). Full lesson is persisted
  in `.opencode/learnings/external-patterns/2026-08-12-wsl2-notifications-daemon-required.md`
  - do NOT duplicate its body here; this ADR only records the decision and channel
  choice.
- Trusted-plugin exception (accepted): the plugin spawns `powershell.exe` from
  plugin code for desktop toasts; this execution path is NOT mediated by agent
  `permission.bash` rules. Documented as an accepted trusted-plugin exception
  (command hardcoded, args sanitized, stdio fully discarded `["ignore","ignore","ignore"]`
  so stdout can never corrupt the TUI - res007).

### Consequences

- A second observer plugin now exists alongside delegation-observer, establishing a
  family of lifecycle observers sharing the silent-state + derived-view pattern.
  Future lifecycle instrumentation should follow the same sibling-module convention
  rather than further extending an existing large plugin.
- The runtime artifacts (`ticker.json`, `ticker.md`) are gitignored and regenerated;
  they are a convenience view, never authoritative repo history.
- Desktop notifications on WSL2 are constrained to the zero-install channels until a
  notification daemon is installed (see the external-patterns cross-reference).

### Metadata

- Created: 2026-08-13
- Related: DIA-122, .opencode/plugins/needs-input-observer.ts, scripts/ticker-render.sh, scripts/__tests__/ticker-render.bats, .opencode/learnings/external-patterns/2026-08-12-wsl2-notifications-daemon-required.md

## ADR: Escalated-lane steps-cap execution limit (DIA-132)

### Status

Accepted - 2026-08-13

### Context

The DIA-132 escalation-hardening cycle followed the DIA-130 incident in which
@coder-escalated (kimi-k3) ran ~9.5 minutes ONE-SHOT and returned an EMPTY
result with zero writes (silent failure). The ai-specialist hardening research
(knowledge/res020-opencode-agent-config-watchdog/) established that OpenCode
AgentConfig has NO native per-agent wall-clock timeout; the ONLY native
execution limit is the "steps" field, which caps agentic ITERATIONS (not
elapsed time) before forcing a text-only response. That finding is recoverable
from res020; what is NOT recoverable from that conspect is this repository's
Tiered mitigation DECISION, its scope, and its trade-offs.

### Decision

1. Tier 1 (implemented now): add a "steps": 50 cap to BOTH escalated lanes -
   analyzer-escalated (.opencode/opencode.jsonc L265) and coder-escalated
   (L321). 50 is an ITERATION cap, NOT a wall-clock timeout.
2. Tier 2 (plugin alerts on session events via delegation-observer) and Tier 3
   (proactive timeout watchdog) are DOCUMENTED but DEFERRED. They are deferred
   because a plugin CAN alert but CANNOT auto-cancel a subagent in the current
   OpenCode runtime; a true mitigation needs an upstream OpenCode feature.
3. DIA-132 stays OPEN pending a restart-verify (DIA-123 pattern) at the next
   session boot, because config limit changes are only verifiable against the
   runtime after a true process restart.

### Rationale (irrecoverable context)

- "steps" is the ONLY native execution limit AgentConfig exposes; there is no
  native per-agent timeout field (verified against the live
  opencode.ai/config.json AgentConfig schema in res020). A wall-clock timeout
  therefore must be layered by the plugin/runtime, which is why Tiers 2/3 are
  deferred rather than omitted from the plan.
- The 50 value is a STARTING heuristic balancing silent-failure containment
  against not truncating legitimate complex escalations. It is not derived from
  any documented sizing rule and is expected to be tuned after observation.

### Consequences

- Monitor: legitimate complex escalations may hit the 50-step text-only cutoff.
  On limit the agent receives a system prompt to summarize remaining work, so
  partial progress is surfaced, not silently lost. This is the intended
  fail-safe, not a fault.
- Track: per-dispatch iteration usage vs the kimi-k3 ~490 req/mo cap, so steps
  tuning stays inside the provider budget and escalation lanes are not
  throttled by quota.
- DIA-132 requires a restart-verify (runtime tool/limit manifest) at next boot
  before the change is considered effective.

### Metadata

- Created: 2026-08-13
- Related: DIA-132, DIA-130, knowledge/res020-opencode-agent-config-watchdog/,
  .opencode/opencode.jsonc L265/L321, CHANGELOG (DIA-132 Tier 1)

## ADR: Dual-runtime OMO precedence divergence - verify config semantics against the INSTALLED runtime (DIA-128)

### Status

Accepted - 2026-08-13

### Context

The project wires the oh-my-opencode-slim plugin from a LOCAL VENDORED source
(`.opencode/opencode.jsonc` line ~541 as `file:///workspace/.opencode/oh-my-opencode-slim`)
while the running OpenCode resolves the INSTALLED npm build (OMO 2.2.13). These two
runtimes carry OPPOSITE prompt-precedence semantics: the installed 2.2.13
`dist/index.js:19282` uses `inlinePrompt ?? filePrompt ?? fallback` (INLINE wins over
the prompt file), whereas the local vendored source uses `filePrompt ?? base`
(FILE wins). A config change validated under one runtime is therefore NOT
behavior-equivalent under the other.

### Decision

1. Treat "local vendored source" and "installed npm runtime" as two potentially
   divergent truth sources. When designing ANY OMO config fix (prompt precedence,
   agent behavior, permission wiring), verify semantics against the INSTALLED
   package version actually loaded at runtime, NOT the local source tree.
2. Project-level prompt files resolve at loader step 2 for BOTH runtimes (project
   preset > project root > user preset > user root), making them the idiomatic,
   runtime-agnostic way to override global prompts. Prefer relocating inline
   content to `<agent>.md` / `<agent>_append.md` over relying on inline `prompt`
   keys whose precedence differs between runtimes.
3. Re-verify inline-vs-file precedence on EVERY OMO upgrade (regression note
   added to coder.md + analyzer_append.md, 2026-08-13).

### Rationale (irrecoverable context)

- The dual-runtime split is a project-specific invariant: the vendored plugin
  source is a fork divergence from the published npm build, so behavior must be
  re-verified after every upgrade. A fix designed against the local source would
  have silently dropped the project coder checklist under the installed runtime.
- Full finding detail (exact line, warning condition, fix sequence) is captured in
  the DIA-128 learnings file - do NOT duplicate its body here.

### Consequences

- OMO config changes are validated by `make test-config` AND a runtime restart
  check to confirm precedence semantics match the installed package.
- Future config work must re-check inline-vs-file precedence after an OMO version
  bump rather than assuming the vendored source reflects the installed behavior.

### Metadata

- Created: 2026-08-13
- Related: DIA-128, commit 15f68a4 + 144a332, .opencode/oh-my-opencode-slim/coder.md, .opencode/oh-my-opencode-slim/analyzer_append.md, .opencode/learnings/external-patterns/2026-08-13-dia128-inline-prompt-relocation.md

## ADR: Batch-D shared tracked test seams must be declared in the spec slice-ownership table (DIA-179)

### Status

Accepted - 2026-08-14

### Context

The DIA-179 test-suite-audit-fixes OpenSpec change defined 5 disjoint slices
(A/B/C/D/F) with per-slice file-ownership lists under the batch D parallel-worktree
model (DIA-172 pattern D + DIA-175 strict instance separation). The ownership table
assigned each slice a disjoint FILE set, but two slices (B and C) BOTH extended the
same tracked test file `scripts/__tests__/batch-d-infra.test.mjs` in their own
worktrees, each appending assertions against its own infra change. The squash-merges
for B and C therefore collided on that single tracked file and had to be resolved
manually, keeping both describe blocks. The collision was recoverable (it is in the
merge history) but the PROCESS gap was not: the spec's "disjoint file sets" guarantee
silently excluded the shared test seam.

### Decision

1. A batch-D slice-ownership table is NOT disjoint merely because each slice names a
   distinct set of source files. Any tracked file a slice will MODIFY (including a
   test file it appends to) must be listed in that slice's owned-files set.
2. When two or more slices must extend the SAME tracked test seam (or any shared
   file), the spec MUST either (a) assign that seam to a single owning slice whose
   tests assert all sibling slices' behavior, or (b) declare the anticipated
   squash-merge conflict up front AND plan the serialized merge ORDER (e.g. merge B
   before C) so the conflict is expected and deterministic rather than discovered at
   merge time.

### Rationale (irrecoverable context)

- The batch D model's correctness rests on "disjoint file sets, zero cross-slice
  collisions" (DIA-172 LESSON-4). That guarantee held only for SOURCE files; the
  test seam was an unplanned shared write. The divergence between the ownership
  table's stated disjointness and the actual shared test file is not recoverable
  from the merged diffs (which show only the resolved, both-blocks result).
- Appending to a shared test file is a common, low-cost pattern for slice authors;
  without this rule it recurs on the next multi-slice infra change.

### Consequences

- Future batch-D spec authoring must audit the OWNED-FILES list (not just the source
  deltas) for shared tracked test files and apply either single-owner or declared-
  conflict-plus-merge-order before dispatching parallel coders.
- Merge-order planning becomes an explicit field in the spec's parallel-implementation
  model when any shared seam is present.

### Metadata

- Created: 2026-08-14
- Related: DIA-179, openspec/changes/test-suite-audit-fixes/, lessons.md DIA-179 section

## ADR: Overnight profile permission overlay - explicit ALLOW entries + guard-denies placed AFTER broad allows (DIA-186)

### Status

Accepted - 2026-08-15

### Context

The overnight AFK campaign (DIA-177/180/181/182 parallel coder lanes) was defeated
by TUI permission prompts that stalled unattended lanes. The overnight profile
(`.opencode/opencode-overnight.jsonc`) needed an allow-list so autonomous runs never
prompt, while preserving the destructive invariants of the DIA-134 baseline v1 (11
deny rules). The subtlety: OpenCode permission rules are evaluated by pattern match
with the LAST matching rule winning (NOT longest-pattern-wins). This was verified
empirically via `opencode debug agent coder` and cross-referenced with the
knowledge/res004 sources.

### Decision

1. The overnight permission payload is structured as: global `"*": "allow"` catch-all
   first, then the DIA-134 baseline v1 deny rules, then the developer-approved
   allow-list delta, then explicit GUARD-DENIES that re-assert the destructive
   invariants AFTER the broad allows they constrain (e.g. the `"git push *"` allow is
   re-constrained by guard-denies for `git push --force*`, `-f`, `--force-with-lease`,
   and the various `git branch -d/-D/--delete` forms).
2. Because LAST-MATCH-WINS (not longest-pattern), a broad allow placed after a
   narrower deny would override it; guard-denies MUST therefore appear after the
   allows they constrain to win the evaluation.
3. The resulting payload carries 29 guard denies + 17 unique allows beyond the 11-rule
   baseline (verified by counting the config: 40 deny rules = 11 baseline + 29 guard;
   20 allow lines = `*` catch-all + 2 duplicate `.slim/worktrees/*` rows + 17 unique).

### Rationale (irrecoverable context)

- The LAST-MATCH-WINS ordering semantic is the load-bearing constraint for where to
  place guard-denies. It is NOT recoverable from the config alone (which shows the
  resolved ordering but not why the ordering was chosen), and it was verified
  empirically because the docs wording is easy to misread as longest-pattern-wins.

### Consequences

- Any future edit to the overnight payload must respect the ordering invariant: broad
  allows AFTER baseline denies, guard-denies AFTER the allows they constrain. A rule
  added in the wrong position silently changes effective permission resolution.
- The overnight.bats test uses subset-presence contract arrays (not exact-string), so
  additive changes to the payload do not break the gate; the test is the independent
  oracle for whether baseline/guard/allow invariants still resolve to the intended
  decision.

### Metadata

- Created: 2026-08-15
- Related: DIA-186, DIA-134, .opencode/opencode-overnight.jsonc,
  scripts/__tests__/overnight.bats, knowledge/res004-tool-enumeration

## ADR: Overnight profile guard-denies/allow-list composition is oracle-tested via subset-presence contract arrays (DIA-186)

### Status

Accepted - 2026-08-15

### Context

The overnight.bats test previously asserted exact-string payload equality, which
broke when the payload was expanded (the DIA-186 test-drift failure: expanded payload
without updating overnight.bats, gate broken at merge). The test needed to become
robust against additive changes while still being a real oracle for the permission
invariants.

### Decision

The overnight.bats test uses subset-presence contract arrays: it asserts that the
baseline v1 keys, the guard-denies, and the allow-list each resolve to the intended
"deny"/"allow" decision in the effective payload, rather than asserting exact-string
equality with the full rule map. Additive changes (new baseline-compatible rules) do
not break the gate; removing or re-ordering an invariant rule does.

### Rationale (irrecoverable context)

- The subset-presence contract design (test as independent oracle) is a deliberate
  test-philosophy choice, not recoverable from the test diff alone (which shows the
  arrays but not the invariant-vs-string-equality rationale).

### Consequences

- The test now tolerates additive payload growth, removing the coupling that caused
  the DIA-186 gate break.
- The test remains the independent oracle for the permission invariants; the ADR above
  documents the ordering rule that the arrays assert.

### Metadata

- Created: 2026-08-15
- Related: DIA-186, DIA-134, scripts/__tests__/overnight.bats,
  .opencode/opencode-overnight.jsonc

## ADR: DCP config loss + prompt gap patterns (DIA-260819-9oxi, DIA-260819-880v)

### Status

Accepted - 2026-08-19

### Context

Two critical agentic infrastructure bugs share a common root-cause class:
config or prompt changes that were IMPLEMENTED but not VERIFIED in-session,
leaving them invisible to subsequent sessions. DIA-260819-9oxi found the DCP
plugin still injecting system-reminders despite DIA-197 V2 config -- the
project .opencode/dcp.jsonc was never created/committed, so DCP ran with
all defaults. DIA-260819-880v found the orchestrator not using todowrite for
planned items -- the tool was permitted in the permission allow-list but had
ZERO mentions across all prompt surfaces.

### Decision

1. **Config file existence is a runtime invariant.** After implementing any
   config-file-dependent fix (plugin config, .jsonc, .yaml), the file MUST
   exist on disk AND be verified at runtime (restart-verify) in the same
   session. If restart-verify cannot complete in-session, the pending verify
   MUST be explicitly tracked as an open_ticket in the handoff prognosis so
   the next session resumes verification.

2. **Permitted-but-undocumented tools are invisible bugs.** When adding a tool
   to the permission allow-list, the change MUST include corresponding prompt
   guidance (mentions in agent prompts, drift-checker markers, or explicit
   rules) in the same change. A tool that is permitted but never mentioned in
   any prompt surface is functionally invisible to the LLM -- it will not
   self-discover the tool's existence or usage discipline.

### Rationale (irrecoverable context)

- The DCP config loss pattern: DIA-197 V2 was "implemented" but the project
  config file was never created. The next session discovered DCP still running
  with defaults -- an invisible regression because no runtime check confirmed
  the file existed. This is a "config-file phantom" pattern: the code change
  is committed but the runtime artifact is absent.
- The prompt gap pattern: todowrite was in the permission allow-list but
  never mentioned in orchestrator_append.md, oh-my-opencode-slim.jsonc presets,
  or the drift-checker. The LLM could not discover the tool's discipline
  rules because they did not exist. This is a "permitted-but-undocumented"
  pattern: permission without prompt guidance = invisible tool.
- Both patterns share a root cause: implementation without same-session
  verification. The fix landed but the runtime proof was never collected.

### Consequences

- Config-file-dependent fixes require a "file exists on disk" check as part
  of the fix's acceptance criteria, not just a code commit.
- Permission allow-list changes require prompt-surface coverage in the same
  change (ADR-260819-880v prompt gap rule).
- Handoff prognosis MUST explicitly track any restart-verify that is deferred
  to the next session.

### Metadata

- Created: 2026-08-19
- Related: DIA-260819-9oxi, DIA-260819-880v, DIA-197

## ADR-007: Autocrine gate for researcher dispatch (DIA-211/DIA-212)

### Status

Accepted - 2026-08-17

### Context

During DIA-211 Phase 1 (consolidation of delegation-observer hooks into biological
namespace labels), the researcher dispatch path lacked a check for whether a res ID
had been pre-allocated. The researcher cannot write to knowledge/ without a res ID
path; dispatching without one forces an extra retroactive cycle. The question was
whether to hard-block (gate) or soft-warn (autocrine) the dispatch.

### Decision

Adopt a soft gate (warn+allow) using the appendRow standard writer, with NO isPhaseA
exception. The gate emits a warning row to registry.jsonl when a researcher is
dispatched without a pre-allocated res ID, but allows the dispatch to proceed.

### Rationale (irrecoverable context)

- Fail-soft preserves backward compatibility: existing orchestrator flows that dispatch
  researcher without Phase 1 pre-allocation continue to work; the warning surfaces the
  gap without breaking the pipeline.
- Hard gate deferred to Phase 3 YAML declarative rules: the full enforcement will be
  declarative and rule-based once the Phase 3 rule engine is in place. The autocrine
  gate is the Phase 1/2 bridge.
- isPhaseA exception removed: the earlier exception allowed Phase A (ID allocation)
  dispatches to bypass the gate, but this created an inconsistency. The standard
  appendRow writer is the single code path; no special-casing.

### Consequences

- Orchestrators that skip Phase 1 will see a warning in registry.jsonl but the
  dispatch will proceed. The warning is a signal, not a blocker.
- Phase 3 will replace this with a declarative YAML rule that can enforce the gate
  as a hard block when the rule engine is ready.
- Three ai-auditor findings were fixed in this change: isPhaseA exception removed,
  appendRow standardization, header accuracy.

### Metadata

- Created: 2026-08-17
- Related: DIA-211, DIA-212, .opencode/plugins/delegation-observer.ts (biological
  namespace section headers at ~line 1844), tests: make test-config 56 pass,
  make test-shell 404 pass
## ADR: Codex/ClaudeCode client parity is UNVERIFIED - no .codex/ .claude/ configs exist (DIA-200)

### Status

Accepted - 2026-08-14

### Context

DIA-200 asked whether Codex and ClaudeCode follow the same worktree/branch/merge
conventions as the OpenCode-based lanes, by inventorying their .codex/ .claude/
configs. The ana022 analyzer report explicitly scopes client-parity OUT (report
line 16: "Codex/ClaudeCode client-parity is a SEPARATE lane (code-navigator) and
is NOT covered here"), and the DIA-200 ticket's CODE-CLIENT-PARITY section has
no evidence recorded yet (Fix section unfilled). Live repo state verified
2026-08-14: NO .codex/ or .claude/ directory (or .claude.json / .config/codex)
exists anywhere in the repository, and no gitignore entry references them.

### Decision

Record Codex/ClaudeCode parity as UNVERIFIED: with no .codex/ .claude/ configs
present anywhere, those tools - IF used in this repo - silently follow vanilla
git conventions (plain branch + push, no squash-merge convention, no worktrees.sh
cleanup, no batch-D workflow) unless configured. No claim of parity is made or
assumed.

### Rationale (irrecoverable context)

- The finding is a negative-evidence snapshot (absence of config files at a point
  in time), which is not reconstructible from git history or diffs once configs
  are later added - a future reader cannot tell whether parity was ever verified.
- The DIA-200 ticket does not yet carry the inventory result; without this ADR the
  UNVERIFIED state would live only in the gitignored session log and be lost.
- The ana022 report deliberately excludes the lane, so the report file must not be
  treated as covering it.

### Consequences

- Before relying on Codex/ClaudeCode in this repo, either add .codex/ .claude/
  configs wiring them to worktree-conventions.md / worktrees.sh, or accept the
  vanilla-git behavior explicitly.
- The DIA-200 CODE-CLIENT-PARITY verification remains an open work item (separate
  code-navigator lane), not resolved by this ADR.

### Metadata

- Created: 2026-08-14
- Related: DIA-200, knowledge/ana022-worktree-mechanism-analysis/ana022-worktree-mechanism-analysis-report.md, docs/dev-infra-audit/tickets/DIA-200-worktree-branch-merge-mechanism-analysis.md

## ADR: Conspecter shelf registration DELEGATED to @memory-manager (DIA-190, Option B)

### Status

Accepted (policy decision made 2026-08-15, developer-approved Option B, ai-auditor
APPROVE-WITH-NITS F6/F7 applied).

### Context

DIA-190: the conspecter lane contract asserted it registers conspects in
memory-shelf.yaml, but its edit permission denies that (conspecter edit =
knowledge/* only). This is a doc-drift defect: contract says shelf registration,
permission denies it. Two options: (A) expand conspecter edit to include
memory-shelf.yaml, or (B) change the conspecter contract + research-pipeline skill
to delegate shelf registration to @memory-manager.

### Decision

Option B: conspecter shelf registration is DELEGATED to @memory-manager. Conspecter
edit scope = knowledge/* only. Conspecter REPORTS the conspect artifact path;
@memory-manager performs the memory-shelf.yaml registration under shelf.conspects.
This preserves the DIA-143 sole-writer invariant for memory-shelf.yaml. @analyzer
already models this delegation (analyzer writes knowledge/* + analysis report,
registration delegated). Implemented via doc-config alignment: conspecter.md,
oh-my-opencode-slim.jsonc step 4, research-pipeline SKILL.md L53/L87, and an
opencode.jsonc comment fix (F6); config edit permission unchanged (still
knowledge/* only).

### Rationale (irrecoverable context)

- The choice between expanding the writer scope (A) vs delegating (B) is a policy
  decision, not recoverable from the config diff. The deciding factor was preserving
  the DIA-143 sole-writer invariant (a single memory-shelf writer) over expanding a
  writer's scope.
- The analyzer precedent (write artifact, delegate registration) establishes the
  delegation pattern this ADR extends to conspecter.

### Consequences

- Conspecter never writes memory-shelf.yaml; it reports the artifact path and the
  orchestrator dispatches @memory-manager to register.
- memory-shelf.yaml stays single-writer (DIA-143), avoiding concurrent-writer
  conflicts on the shelf.

### Metadata

- Created: 2026-08-15
- Related: DIA-190, DIA-143 (sole-writer invariant), conspecter.md,
  research-pipeline SKILL.md, oh-my-opencode-slim.jsonc, memory-shelf.yaml

## ADR: Rename-if-not-suffixed terminal identity guard (DIA-189)

### Status

Accepted (2026-08-16, merged 9d96310).

### Context

DIA-189: the needs-input-observer plugin renames terminal/session titles. The
prior predicate approach failed to keep titles suffixed with the expected tag
after an upstream default drift (runtime 1.18.18 changed default title
behavior). Candidates: (A) rename-if-not-suffixed guard, (B) broaden the
predicate, (C) harness-side fix.

### Decision

Option A - rename-if-not-suffixed terminal identity guard: only rename when the
title is not already suffixed with the expected tag. Chosen because it is robust
to upstream default drift (never re-clobbers a title the SDK already set) and
avoids clobbering user-provided titles.

### Rationale (irrecoverable context)

- The decision between guard (A) vs broaden-predicate (B) vs harness-fix (C) is
  a policy choice not recoverable from the plugin diff; the deciding factor was
  resilience to upstream default drift and non-destruction of user titles.
- Upstream default drift (1.18.18) is a runtime behavior change that made the
  simpler predicate approach unreliable.

### Consequences

- Terminal/session entries are only renamed when the expected suffix is missing,
  so SDK-defaulted and user-set titles are preserved.
- The guard pattern generalizes to future plugin title-renaming logic.

### Metadata

- Created: 2026-08-16
- Related: DIA-189, needs-input-observer.ts, lessons L20260815-005..010,
  L20260816-001 (branch topology in the same merge campaign).

## ADR: Ponytail cache-economics plugin now, headroom spike later (DIA-183 Variant D)

### Status

Accepted (2026-08-16, merged 47064d0).

### Context

DIA-183: prompt-cache economics for the DeepSeek/OpenCode workflow. Candidates
considered for the cache-cost reduction. Ponytail and headroom are the two
candidate cache-economics plugins.

### Decision

Variant D - add the ponytail plugin now and spike headroom later. Ponytail was
chosen first because it has zero cache interaction (safe additive layer) and
delivers an immediate ~-20% cost reduction, whereas headroom cache-mode requires
a dedicated spike.

### Rationale (irrecoverable context)

- The staging choice (ponytail now, headroom later) is a sequencing policy not
  recoverable from the plugin array diff.
- Ponytail's zero-cache-interaction property made it the low-risk first step;
  headroom was deferred to a separate spike to avoid bundling two cache-economics
  tools whose interaction was not yet characterized.

### Consequences

- ponytail is present in the project plugin array (DIA-183 Variant D);
  headroom remains a future spike.
- Cache-economics reasoning is captured in learnings
  (2026-08-15-ponytail-headroom-cache-economics).

### Metadata

- Created: 2026-08-16
- Related: DIA-183, ponytail plugin, headroom, res029 (DCP sibling cache work).

## ADR: context_usage reweight formula V1 (DIA-191)

### Status

Accepted (2026-08-16, merged 47064d0; calibrated by ana025).

### Context

DIA-191: the delegation-observer `context_usage` tool proxy overestimated ~2x vs
the TUI indicator (lesson L20260815-011). The prior formula
(`delegation*3000 + message*1000 + session*10000`) was recalibrated.

### Decision

V1 reweight formula: `delegation*5000 + message*500 + 30000 flat`. The V2
candidate (read cumulative tokens from opencode-db/sqlite) was REJECTED: cumulative
token counts are the wrong metric after compaction, so a cumulative-token-based
proxy would still misreport post-compaction usage.

### Rationale (irrecoverable context)

- The reweight arithmetic and the V2 rejection reasoning are calibration
  decisions not recoverable from the plugin formula diff alone.
- The V2 rejection turns on a subtle point: post-compaction the accumulated
  token total no longer reflects live context pressure, so a database-derived
  cumulative metric cannot ground the proxy.

### Consequences

- context_usage uses the V1 reweight formula; V2 (opencode-db) is documented as
  rejected with rationale.
- Calibration evidence is captured in ana025.

### Metadata

- Created: 2026-08-16
- Related: DIA-191, context_usage tool, delegation-observer.ts, ana025,
  lesson L20260815-011.

## ADR: Full DCP removal, superseding V2 keep-but-disable (DIA-197 V1)

### Status

Accepted (2026-08-17, commit 69dcdaf on omo-slim-changes branch).
SUPERSEDES the earlier V2 keep-but-disable ADR (2026-08-16).

### Context

DIA-197 evaluated the dual-compaction-pipeline (DCP) plugin for removal because
of a cache-hit degradation (85% vs 90%) without noticeable benefit. res029
established that DCP has NO cache-preserving mode. The initial decision (V2,
2026-08-16) was to keep DCP in the plugin array but disable autonomous pruning.
On further evaluation, the developer chose full removal (V1) as the cleaner
outcome.

### Decision

V1 - Full DCP removal. Seven touchpoints edited: removed from plugin arrays
(project + global), deleted dcp.jsonc, removed from config validator, removed
from Dockerfiles (Dockerfile.dev + Dockerfile), and removed runtime deps.
Rationale: DCP was disabled since Aug 16, zero manual usage, dead weight.

### Rationale (irrecoverable context)

- The shift from V2 (keep-but-disable) to V1 (full removal) is a developer
  preference decision: when a plugin is disabled and unused, full removal is
  cleaner than keep-but-disable. The intermediate V2 state created config
  complexity (manualMode + deny + strategies-off) with zero benefit.
- DCP's zero-cache-preserving property made even the disabled state pointless:
  there was no future scenario where re-enabling DCP would help (it clears
  the cache either way).

### Consequences

- DCP is fully removed from the codebase. Seven touchpoints cleaned in one commit.
- No remaining DCP config surface (no dcp.jsonc, no plugin array entries, no
  Docker references).
- Future DCP-related work would require re-adding from scratch.

### Correction (2026-08-21, DIA-260821-8kpc)

The claims in this ADR that DCP was "removed from plugin arrays (project +
global)" on 2026-08-17 and "disabled since Aug 16" with "no remaining DCP
config surface" are FALSE. Reality: DIA-197 (2026-08-17) removed DCP from the
PROJECT config only. The GLOBAL config (in /app/.config/opencode/: opencode.json
plugin array, tui.json, dcp.jsonc) kept DCP ENABLED until 2026-08-21, when
DIA-260821-8kpc removed it from both project and global config. As of
2026-08-21 DCP is fully removed from project + global config. The "disabled
since Aug 16 / enabled:false" belief was misinformation that caused repeated
re-investigation.

### Metadata

- Created: 2026-08-17 (supersedes V2 entry from 2026-08-16)
- Related: DIA-197, res029, commit 69dcdaf, dcp.jsonc (deleted).

## ADR: ai-specialist model-array fallback - gpt-5.3-codex behind qwen3.7-plus (DIA-189)

### Status

Accepted - 2026-08-17

### Context

The ai-specialist lane (cebula preset) ran on qwen3.7-plus. On 2026-08-17 the lane
failed with empty subagent results (DIA-099 signal D2 = session errors). The res029
research (knowledge/res029-model-fallback-semantics/) established that OMO model
arrays are ordered fallback chains with a foreground-fallback manager that
auto-switches on rate-limit/quota/error/session-status signals, and that
github-copilot/gpt-5.3-codex is a valid second entry: Copilot-credit billing
(req_per_month null, quota guard skips the lane), no exclusivity constraint in the
model registry, and the D2 session-error class is exactly the session.error event
the fallback manager handles.

### Decision

Add github-copilot/gpt-5.3-codex as the SECOND entry of the ai-specialist model
array (cebula preset), keeping qwen3.7-plus primary. The first entry stays active
at startup; the foreground-fallback manager auto-switches to codex on detected
error signals (the 2026-08-17 failure class). Implemented in commit 6fb7f14.

### Rationale (irrecoverable context)

- The choice of codex as fallback (vs the alternatives below) is a model-routing
  policy decision not recoverable from the one-line config diff (6fb7f14).
- codex carries no Go request-meter quota (Copilot credits, req_per_month null in
  knowledge/model-registry.yaml), so a fallback switch does not consume the Go
  quota; the registry row has no exclusivity constraint, so dual use (reviewer
  lane + ai-specialist fallback) is permitted.
- The failure class (session errors, D2) is precisely the session.error event
  class the foreground-fallback manager handles (res029 finding 3), so the
  fallback is expected to engage for this incident class.

### Alternatives considered

- gemini-3.1-pro-preview: not chosen - Copilot-only model with no established
  lane precedent in this repo's routing tables.
- Route ai-specialist research to other lanes (e.g. @coder read-only, precedent
  L20260816-006): remains the manual fallback when the endpoint is dead, but does
  not fix the lane's own model reliability.
- Status-quo (no fallback): rejected - the 2026-08-17 empty-result failures would
  recur with no automatic recovery.

### Consequences

- Auto-fallback on error signals: ai-specialist sessions switch to codex on
  rate-limit/quota/error/session-status patterns. Silent-empty-without-error may
  NOT trigger fallback (retry_on_empty is council-only) - monitor for silent
  empties separately.
- Credit consumption watch: codex consumes Copilot AI credits, not Go quota; the
  quota guard skips Copilot-credit lanes.
- Restart required: the config change takes effect on the next OpenCode restart.
- If qwen3.7-plus continues failing, consider a permanent model reassignment via
  knowledge/model-registry.yaml (tracked in L20260817-004).

### Metadata

- Created: 2026-08-17
- Related: DIA-189, commit 6fb7f14, knowledge/res029-model-fallback-semantics/,
  knowledge/model-registry.yaml, lessons.md L20260817-004

## ADR: context_usage direct live in-context read (DIA-191 V2)

### Status

Accepted (2026-08-17, commits a69cb45 + 5be1df1, ai-auditor APPROVE after 2
cycles, registered b469791).

### Context

The V1 reweight proxy (ana025) still overestimated vs the TUI indicator
(L20260815-011). ana025's V1 rationale claimed "the plugin has no model
metadata access" (ana025 report L394) - PROVEN FALSE: the plugin SDK exposes
the model's context limit via Model.limit.context (chat.params /
client.provider.list()) and AssistantMessage carries the per-message token
breakdown. The direct read computes the SAME value the TUI indicator shows:
the last completed assistant message's tokens
(input+output+reasoning+cache.read+cache.write) divided by the model's
limit.context.

### Decision

context_usage now performs a DIRECT LIVE IN-CONTEXT READ via the plugin SDK
(TUI-equivalent computation, compaction-aware by construction). The V1 proxy
formula remains as the fallback path for fresh sessions (no completed
assistant message yet) and client/provider failure.

### Rationale (irrecoverable context)

- The direct read supersedes part of ana025's V1 rationale: the "no model
  metadata access" constraint is false, so the proxy is no longer the only
  viable estimator.
- The direct read is compaction-aware BY CONSTRUCTION: after compaction the
  last completed assistant message reflects live context pressure - which is
  exactly the flaw that rejected the V2 (opencode-db cumulative tokens)
  candidate for the proxy. The direct read does not suffer that flaw.
- The V1 proxy is retained as fallback, not removed, because a fresh session
  or a client/provider failure has no completed assistant message to read.

### Consequences

- Restart-verify (F8) is PENDING: the change activates only after an OpenCode
  restart loads the updated plugin.
- Future context-usage work should start from the runtime surface (SDK token
  data), not the proxy formula.

### Metadata

- Created: 2026-08-17
- Related: DIA-191, commits a69cb45/5be1df1/b469791, delegation-observer.ts,
  ana025, lessons L20260815-011.

## ADR: OpenCode Go pricing/budgets are volatile - refresh model-registry.yaml with web-fresh research before every model-selection decision (DIA-208)

### Status

Accepted (2026-08-17, commits 1baee98f + bedfaddb + a7b9c21, res030).

### Context

DIA-208 compared archived OpenCode Go pricing (res013/res021, dated
2026-08-12/13) against web-fresh research (res030, 2026-08-17) and found
massive within-days deltas for the SAME model: deepseek-v4-flash price rose
$0.14/$0.28 -> $0.22/$0.66 off-peak / $0.44/$1.32 peak (+57-371%), monthly
request budget collapsed 158,150 -> 18,900 (-88%), usage bucket $60 -> $15,
and the 2x promo was removed. This repositioned mimo-v2.5 (non-pro) as the
volume king ($0.14/$0.28, 150,400 req/mo, $60 bucket) and drove the cebula
preset swap. Availability also churns (models added/deprecated/renamed).

### Decision

OpenCode Go per-model pricing and request budgets change within days, not
weeks. Before ANY model-selection decision (preset swap, escalation rebalance,
model-registry.yaml edit), the governing data MUST be refreshed from
web-fresh research (official docs opencode.ai/docs/go + models.dev + a
community tracker) rather than trusted from archived conspects or the
in-repo model-registry.yaml lookup table alone.

### Rationale (irrecoverable context)

- The archived data (res013/res021, days old) was materially wrong for
  model-selection purposes by the time DIA-208 ran, yet nothing in git
  signaled the drift - the pricing is external to the repo and only a live
  web fetch detects it.
- A stale lookup table silently steers a wrong (or merely outdated) model
  choice, and the error is invisible in commits. This mirrors the earlier
  model-window-drift lesson (2026-08-03): in-repo model metadata is not
  authoritative without a verify-on-use step.

### Consequences

- model-registry.yaml entries that drive selection must record the research
  date (res030: 2026-08-17) so staleness is visible.
- Future preset/rebalance/model-selection work: fetch fresh pricing first,
  then reference the dated conspect; do not reuse an undated prior finding.
- The DIA-208 swap decision itself (Variant A, cebula -> opencode-go/mimo-v2.5)
  is recoverable from the ticket (EBDV Variant A) and is NOT duplicated here.

### Metadata

- Created: 2026-08-17
- Related: DIA-208, commits 1baee98f/bedfaddb/a7b9c21, res030/res013/res021,
  model-registry.yaml, lessons L20260817-008.

## ADR-008: Stigmergic State via active.json (DIA-211 Phase 2)

### Status

Accepted - 2026-08-17

### Context

DIA-211 Phase 2 introduced active.json as a workflow state hint written by the
delegation-observer plugin on terminal handoff. The stigmergic choreography
pattern means agents navigate by environment traces (artifacts left in the
workspace) rather than direct commands. active.json is the primary such trace:
it tells the next agent what state the workflow is in, what action to take,
and which agent should act next.

### Decision

active.json is the workflow state hint, written atomically on terminal handoff
only. Schema: `{ schema_version, workflow_state, next_agent, next_action,
context, updated_at, updated_by }`. Atomic write pattern: temp file + fsync +
rename. Action map covers: review, implement, plan, research, analyze,
investigate, continue, escalate. Schema is versioned (schema_version: 1) for
future evolution.

### Rationale (irrecoverable context)

- Stigmergic choreography enables decentralized coordination: agents read the
  environment state and decide their own next action, rather than being
  dispatched via explicit commands. This reduces orchestrator coupling and
  enables autonomous overnight runs.
- active.json is a HINT, not a command. Agents may ignore it if the workspace
  state has changed since the hint was written. The handoff remains the
  authoritative terminal event; active.json is derived from it.
- Atomic write (temp + fsync + rename) prevents race conditions when multiple
  agents or plugin hooks write concurrently. A partial write would leave a
  corrupt state file that the next agent reads.
- Schema versioning allows future evolution without breaking existing consumers.
  The version field enables migration logic when the schema changes.

### Consequences

- active.json must be written INSIDE the handoff success path (see
  L20260817-010). A failed handoff must not leave active.json pointing to a
  non-existent handoff.
- The action map is extensible but must be updated in the plugin code, not in
  the consumer. Consumers should treat unknown actions as "continue".
- active.json is gitignored (session-scoped ephemeral state) and not part of
  the repository history.

### Metadata

- Created: 2026-08-17
- Related: DIA-211, DIA-212, .opencode/plugins/delegation-observer.ts,
  .opencode/session/active.json, lessons L20260817-010

## ADR-009: Adaptive Performance Routing + Circuit Breaker + Resource Pressure (DIA-211 Phase 3)

### Status

Accepted - 2026-08-17

### Context

DIA-211 Phase 3 introduced three interrelated mechanisms into the
delegation-observer plugin to improve dispatch routing under real-world
conditions:

1. **Adaptive performance routing (Phase 3b):** epsilon-greedy selection over
   agent alternatives based on EMA (exponential moving average) duration tracking.
   Dispatch durations are measured via a pendingAdaptiveDispatches map (start
   timestamp on dispatch, elapsed computed on completion).

2. **Circuit breaker recovery (Phase 3b):** per-agent circuit breaker with
   active/isolated states. Recovery requires recovery_streak >= 3 consecutive
   successes. Recovery probe cooldown is 5 minutes, anchored to the OPEN
   transition time (failure time), not per-probe.

3. **Resource pressure adaptation (Phase 3c):** three context_usage thresholds
   (50% YAGNI constraint append, 80% non-critical dispatch block, 95% all
   dispatch block). YAGNI constraint propagates to args.prompt (the dispatch
   payload), not a local variable.

### Decision

Implement all three mechanisms as in-memory state with debounced async write to
persistent state files. No external dependencies. State files:
adaptive-routing-state.json, adaptive-performance.json, with .bak backup.

### Rationale (irrecoverable context)

- Plugin API limits: the delegation-observer plugin cannot directly spawn agents
  or hook into agent lifecycle events. It can only observe dispatches and modify
  dispatch payloads. In-memory state is sufficient for routing heuristics that
  operate within a single plugin lifecycle.
- Debounced async write reduces I/O overhead: writing state files on every
  dispatch would create excessive filesystem churn. Debouncing (writing after a
  short delay with no further mutations) reduces writes while keeping state
  reasonably fresh.
- The three thresholds (50/80/95%) and the recovery_streak threshold (3) are
  starting heuristics, not derived from formal analysis. They are expected to be
  tuned based on observed agent behavior under load.
- YAGNI propagation to args.prompt (not local copy) was an ai-auditor finding:
  a local variable holding the constraint text is invisible to the agent and
  produces a silent no-op.

### Consequences

- Routing decisions are best-effort heuristics, not guarantees. Agents may still
  fail or perform poorly despite adaptive routing.
- Circuit breaker recovery is conservative (3 consecutive successes required)
  to avoid flapping between active and isolated states.
- Resource pressure thresholds are tunable; the initial values are documented
  in the plugin source and can be adjusted without architectural changes.
- State files are gitignored (session-scoped ephemeral state).

### Metadata

- Created: 2026-08-17
- Related: DIA-211, DIA-212, .opencode/plugins/delegation-observer.ts,
  lessons L20260817-011, L20260817-012, L20260817-013

## ADR: Advisory routing-order enforcement for section 2.5 config-work (DIA-230)

### Status

Accepted - 2026-08-18

### Context

The orchestrator LLM cannot be trusted to self-police the AGENTS.md section 2.5
routing rules under context pressure. A retrospective audit (DIA-204/212/214/215/
229) found that config-work changes had bypassed the required @ai-specialist
research gate and @ai-auditor review, sending @coder directly on "investigate and
fix" tasks. The delegation-observer plugin lacked mechanical enforcement of the
routing contract.

### Decision

Adopt advisory-only mechanical enforcement of section 2.5 routing rules via the
delegation-observer plugin's `tool.execute.before` hook. The gate detects when
@coder is dispatched on config-work (file paths matching `.opencode/plugins/`,
`.opencode/oh-my-opencode-slim/`, `orchestrator_append.md`) without a prior
@ai-specialist dispatch in the session, and emits a `ROUTING_VIOLATION` warning
to `registry.jsonl` + `messages.jsonl`. Advisory-only (warning, not blocking) to
avoid breaking existing workflows.

### Rationale (irrecoverable context)

- Advisory-only over hard-block: a hard block would break in-flight sessions and
  override the owner's discretion. The warning signals the violation without
  halting the pipeline; the owner can accept or reject the routing at review time.
- Session-scanning (not registry.jsonl) for prior ai-specialist dispatch: the
  registry sidecar does not reliably carry agent identity for older rows, so the
  gate scans messages.jsonl for a prior @ai-specialist dispatch in the current
  session as the stronger signal.
- 11 config-work path patterns covered: the gate matches against a broad set of
  .opencode/ paths to catch config-work dispatched under various aliases.

### Consequences

- Future config-work dispatches without @ai-specialist research produce a visible
  ROUTING_VIOLATION warning. The orchestrator can review and accept/reject the
  routing.
- The gate is advisory-only; a determined orchestrator can still bypass it. The
  mechanical enforcement is a signal layer, not a policy enforcement layer.
- The gate was reviewed by @ai-auditor with 4 findings (F1-F4) all resolved in the
  same coder session (DIA-175 R5 same-session fix pattern).

### Metadata

- Created: 2026-08-18
- Related: DIA-230, DIA-204, DIA-212, DIA-214, DIA-215, DIA-229,
  .opencode/plugins/delegation-observer.ts, AGENTS.md section 2.5

## ADR: Routing gate deadlock fix - paracrine dispatch signal scan replaces delegation-row dependency (DIA-235)

### Status

Accepted - 2026-08-19

### Context

DIA-235 identified a structural deadlock in the routing gate (delegation-observer.ts
L2730-2741). The gate scanned for delegation rows containing a session_id to detect
whether an @ai-specialist had already been dispatched in the current session. However,
delegation rows in registry.jsonl do NOT include session_id in their payload -- only
paracrine dispatch.started rows include session_id + agent fields. The gate therefore
never matched, producing a false hasAiSpecialist=false that could hard-block legitimate
dispatches or produce false ROUTING_VIOLATION warnings.

### Decision

Replace the delegation-row dependency with a scan of paracrine dispatch.started rows
(which carry session_id + agent fields). The gate now searches messages.jsonl for a
prior @ai-specialist dispatch in the current session using the dispatch.started signal
rather than the delegation-row signal.

### Rationale (irrecoverable context)

- The delegation-row vs dispatch.started payload difference is a runtime data-shape
  fact: delegation rows carry dispatch metadata (writer, description) but NOT
  session_id, while dispatch.started rows carry session_id + agent fields. This
  distinction is not documented in any schema or spec; it was discovered during
  DIA-235 debugging.
- The deadlock was invisible in code review because the scan logic LOOKED correct
  (searching for agent identity in rows) -- the mismatch was in the row-type payload
  shape, not the scan algorithm.
- Fix committed 10b02d1: changed the scan to match paracrine dispatch.started rows.

### Consequences

- The routing gate now correctly detects prior @ai-specialist dispatches via
  dispatch.started rows, eliminating the false-negative deadlock.
- Future routing-gate changes must verify which row types carry the fields the gate
  depends on; delegation rows and dispatch.started rows have different payload shapes.

### Metadata

- Created: 2026-08-19
- Related: DIA-235, commit 10b02d1, .opencode/plugins/delegation-observer.ts
  (L2730-2741 routing gate scan)

## ADR: Exempt read-only lanes from DIA-224 empty_result_detected crisis detector (DIA-206)

### Status

Accepted (2026-08-17).

### Context

DIA-224 introduced an `empty_result_detected` crisis detector in the
delegation-observer plugin to catch silent failures (subagent returns an empty
result). The detector checks whether a subagent completed with no output.
However, read-only lanes (code-navigator, researcher, ai-specialist in
read-only mode) are designed to return findings in their final message without
writing repo files. The edit-count check fired a false positive for these
lanes because they legitimately never edit files.

### Decision

Exempt read-only lanes from the edit-count check in the DIA-224 crisis
detector. The 3-line change adds a lane-name allowlist so that lanes known
to be read-only (code-navigator, researcher, ai-specialist in read-only mode)
are not flagged by the empty_result detector.

### Rationale (irrecoverable context)

- The DIA-224 detector's edit-count signal is the wrong discriminator for
  read-only lanes: these lanes produce findings in their final text message,
  not in repo file edits. A lane that never edits files is not failing by
  design; the detector treats the absence of edits as absence of work.
- The allowlist approach (explicit exemption per lane name) was chosen over
  removing the edit-count check entirely because the check IS valuable for
  write-capable lanes (coder, code-executor) where empty results are genuine
  failures.
- Root cause is DIA-224: the detector was added without accounting for the
  read-only lane class. The fix is surgical (3 lines) because the lane
  classification already exists in the plugin's dispatch metadata.

### Consequences

- Read-only lanes no longer trigger false-positive crisis alerts on completion.
- Write-capable lanes (coder, code-executor) retain the edit-count check as
  a genuine failure signal.
- Future read-only lane additions must be added to the exemption list.

### Metadata

- Created: 2026-08-17
- Related: DIA-206, DIA-224, .opencode/plugins/delegation-observer.ts (3-line
  change), .opencode/agents/ai-specialist.md (created in same session)

## ADR: HMAC stateless capability tokens for meta-task authorization (DIA-260820-jlu0)

### Status

Accepted - 2026-08-20

### Context

The DIA-217 ticket gate created a chicken-and-egg problem: meta-tasks
(ticket creation, bootstrap operations, procedural authorizations) needed
an OPEN ticket to pass the gate, but creating tickets IS engineering work
that triggers the gate. The gate's tri-state correlation logic (DIA-076
C1) requires an explicit DIA-id in the dispatch prompt that resolves to
an OPEN ticket. Meta-tasks have no pre-existing ticket to correlate
against.

### Decision

Adopt HMAC stateless capability tokens as the authorization mechanism for
meta-tasks. Tokens are signed by a server secret using HMAC-SHA256,
encoded as base64url, and carry a 5-minute TTL. The token format is:
`CAP-<tokenId>:<timestamp>:<hmacSignature>`. The gate accepts a valid
capability token as an alternative to ticket correlation when the token's
operation matches the dispatched task.

### Rationale (irrecoverable context)

- Stateless over stateful: capability tokens carry their own authority
  (signed by server secret), so no central token store or lookup is needed.
  This is critical for meta-tasks that run before the ticket system is
  bootstrapped. A stateful token store would itself need authorization to
  access, recreating the chicken-and-egg.
- HMAC over UCAN/JWT: UCAN (decentralized authorization) and JWT (JSON Web
  Token) both require external dependencies and complex verification logic.
  HMAC-SHA256 via Node.js built-in `crypto` module provides equivalent
  security properties for a single-service gate (issuer = verifier) at ~200
  lines vs ~2000+ for UCAN/JWT. The ponytail ladder applied: stdlib does it.
- 5-minute TTL: short lifetime limits exposure window. Tokens are generated
  on-demand for specific meta-tasks and expire quickly. No revocation needed
  because the TTL is the revocation mechanism.
- base64url encoding: URL-safe encoding prevents transport corruption when
  tokens are passed in dispatch prompts or URLs. The decode path must
  handle the full base64url alphabet (- and _ characters) to avoid the
  silent-drop bug discovered during implementation (see lessons.md
  L20260820-001).

### Consequences

- Meta-tasks can bypass the ticket gate by presenting a valid capability
  token instead of an OPEN ticket reference. The gate validates: (1) token
  format, (2) HMAC signature against server secret, (3) TTL expiry.
- The server secret must be available to the gate at runtime. For this
  project it is stored in the delegation-observer plugin's in-memory state
  (not persisted to disk) to avoid secret leakage.
- Token scope is per-operation: each capability token is valid for a
  specific operation (e.g. "create_ticket", "bootstrap_authorization"). A
  token for one operation cannot authorize a different operation.
- The CAP- prefix was added for type identification but caused a
  verification bug (prefix not stripped before HMAC check). The prefix is
  now stripped before verification; this interaction is recorded in
  lessons.md L20260820-002.

### Metadata

- Created: 2026-08-20
- Related: DIA-260820-jlu0, DIA-217, .opencode/plugins/delegation-observer.ts,
  .sdd/capability-authorization/architecture.md, lessons L20260820-001..004

### ADR: ana001 repo-wide ponytail over-engineering audit - four-lane review consensus (DIA-260825-wprb)

#### Context

ana001 (knowledge/ana001-repo-overengineering-audit/) proposed ~671 net removable
lines including workspace package deletions. Four-lane review: architector (arc-1),
reviewer (rev-1), ai-auditor (ai--1), ai-specialist (ai--2).

#### Decision

CONSENSUS (all four lanes; caveats became execution requirements): findings 1, 2,
5 (gated on plugin-loader feasibility check), 6, 7 (needs developer sign-off +
PONYTAIL-DEBT ledger update - overrides DIA-169/ana021 dispositions), 8,
9 (coordinated: gen-jsconfig.bats assertion + author-studio dep + docs),
10 (+context7-docs list), 11, 12 (+capability-tokens.test.mjs sync), 13,
14 (+author-studio/AGENTS.md W2 doc sync), 15, 16.

VARIANT CONSENSUS - finding 3: WIRE check-secrets-ownership.sh into the
opencode-dev preflight, do NOT delete (open spec dia-260821-x5nj T7.0a mandates it).

NO CONSENSUS - finding 4 (delete packages/data-contracts/): architector DISAGREE -
architecture.md-declared single-source-of-truth seam with real content
(schemas/contract.json) plus gate wiring in dev-infra tsconfig paths; other three
agreed-with-caveats. AWAITING DEVELOPER DISPOSITION.

Execution split into tickets: DIA-260825-n5x4 (plugin dead code + base64url),
DIA-260825-oyh (shared lib gated), DIA-260825-b80t (editor-engine dead code),
DIA-260825-aapj (scaffold workspaces coordinated), DIA-260825-f1o7 (misc + doc
sync), DIA-260825-j0s4 (wire secrets script).

#### Consequences

- Finding 4 stays unexecuted until the developer disposes the architector objection.
- Findings 5 and 7 carry preconditions (feasibility check; sign-off + ledger update).
- Coordinated findings must land together with their listed sync artifacts.

#### Metadata

- Created: 2026-08-25
- Related: DIA-260825-wprb, ana001 report, lessons.md L20260825-006,
  DIA-169, ana021, dia-260821-x5nj T7.0a, docs/PONYTAIL-DEBT.md

#### UPDATE - Outcome (2026-08-25, final persistence pass)

All 6 cleanup tickets executed and merged to DIA-260822-medh-red. Commits:
15338aa (n5x4 plugin dead code + native base64url), a9a2842 (b80t editor-engine),
f4362d9 (aapj scaffold workspaces), 69aa970 (f1o7 misc), 9115bb5 (j0s4 secrets
preflight wiring), 9495160 (merge integration fixes), a25be98 (oyh shared
lib/errors.ts, gate PASS), d65102a (review fix-all), d9418d3 (re-review residual
closure). Re-review cycle 1/2: 5/6 verified-closed + 1 partial closed by d9418d3;
0 still-open.

Developer dispositions recorded: finding 4 data-contracts KEPT
(architecture.md seam); finding 7 example-store KEPT (developer sign-off,
recorded in aapj ticket UPDATE block).

Operational lessons captured as L20260825-007..010 (worktree bootstrap gap,
userns both-foreign preflight pattern, package-entry-point repoint rule,
host-side lockfile refresh).
