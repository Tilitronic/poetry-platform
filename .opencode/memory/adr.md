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
- Permission ordering: the owner required a catch-all "*" permission rule ordered FIRST to make read restrictions explicit per OpenCode docs. The ordering fix was applied during review; record that path-scoped permission semantics and ordering are an implementation gotcha.

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

## ADR: Hermetic sandbox seeding for faked external tools (DIA-119)

### Status

Accepted - 2026-08-12

### Context

A bats sandbox that fakes an external tool (pnpm / npx) by placing a fake binary
earlier in PATH and isolating HOME (temp-HOME) is only hermetic if the outcome
does not depend on WHICH tool resolves. The DIA-119 investigation proved the
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
- Related: DIA-119, DIA-118, scripts/__tests__/verify-pre-push.bats, scripts/__tests__/verify-pre-commit.bats, lessons.md S18 "temp-HOME hermeticity breach pattern"
