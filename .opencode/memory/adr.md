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
