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
## ADR: Codex/ClaudeCode client parity is UNVERIFIED - no .codex/ .claude/ configs exist (DIA-180)

### Status

Accepted - 2026-08-14

### Context

DIA-180 asked whether Codex and ClaudeCode follow the same worktree/branch/merge
conventions as the OpenCode-based lanes, by inventorying their .codex/ .claude/
configs. The ana022 analyzer report explicitly scopes client-parity OUT (report
line 16: "Codex/ClaudeCode client-parity is a SEPARATE lane (code-navigator) and
is NOT covered here"), and the DIA-180 ticket's CODE-CLIENT-PARITY section has
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
- The DIA-180 ticket does not yet carry the inventory result; without this ADR the
  UNVERIFIED state would live only in the gitignored session log and be lost.
- The ana022 report deliberately excludes the lane, so the report file must not be
  treated as covering it.

### Consequences

- Before relying on Codex/ClaudeCode in this repo, either add .codex/ .claude/
  configs wiring them to worktree-conventions.md / worktrees.sh, or accept the
  vanilla-git behavior explicitly.
- The DIA-180 CODE-CLIENT-PARITY verification remains an open work item (separate
  code-navigator lane), not resolved by this ADR.

### Metadata

- Created: 2026-08-14
- Related: DIA-180, knowledge/ana022-worktree-mechanism-analysis/ana022-worktree-mechanism-analysis-report.md, docs/dev-infra-audit/tickets/DIA-180-worktree-branch-merge-mechanism-analysis.md
