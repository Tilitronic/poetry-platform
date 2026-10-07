# Copilot PR #2 config fixes: gate findings (2026-08-05)

date: 2026-08-05

## Source

- Copilot PR #2 review (GitHub Copilot review comments, 8 findings owner-confirmed), OpenSpec change `dev-infra-copilot-fixes`; §10 Phase 1 gate research by @ai-specialist (session `ses_02f7d3527ffe7vY9c5406DJ6Lb`). This file registers the Phase 1 findings per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs.

Summary
-------
The 8 Copilot review fixes for PR #2 split into two commits along the AGENTS.md routing boundary: Commit A (dev-infra, §2.4 → @reviewer) and Commit B (AI-tooling config, §10 → @ai-specialist). Findings 1–4 below are the AI-tooling-side gate findings (Commit B scope) that drove the config fixes; finding 3 documents a corrected rationale discovered during implementation.

Findings
--------
- **Finding 1 — hardcoded user paths in `.opencode/commands/` (telemetry-report.md, telemetry-inspect.md).** The `bun run "/home/qualt/.../report.ts"` / `inspect.ts` lines hardcoded a user-specific absolute path. Fix: replace `/home/qualt` with `${HOME:?HOME must be set}/.cache/opencode/packages/opencode-telemetry@0.1.19/...` in both the `bun run` and `node` fallback paths — POSIX fail-fast guard that hard-exits with a clear message if `HOME` is unset. Best practice: portability (no machine-specific literals in committed commands); idiom per OpenCode commands docs and standard POSIX/bash parameter expansion.

- **Finding 2 — committed runtime-generated cache: `.config/opencode/skills/book-rag/knowledge-bases.yaml`.** This file is a runtime cache produced by the `book-rag` skill (environment-specific `cached_at`/`ttl_seconds` + test data `test_kb`), regenerated on demand. Version-controlling it produced noise diffs. Fix: delete the committed file + add a path-scoped root `.gitignore` entry (`# Generated RAG index cache (book-rag skill); regenerate via book-rag skill`). Best practice: generated artifacts stay out of version control; matches the project's existing `knowledge/*/sources/` ignore pattern.

- **Finding 3 (CORRECTED RATIONALE) — `query_rag.py` is NOT orphaned.** The spec's initial "orphaned script" framing was false: the consumer script exists at `.opencode/scripts/query_rag.py` (1328 lines) and regenerates the cache on demand — `get_kb_list` (:292) → `_load_kb_cache()` call (:314) → `_save_kb_cache` atomic write (:236-263). The deletion + gitignore fix stands (the cache still belongs out of version control), but the rationale was corrected to "committed runtime cache, not orphaned script". Lesson: verify file-existence and ownership claims against the actual tree (grep/glob the repo) BEFORE committing them to spec artifacts — a false rationale propagated into a proposal undermines review trust.

- **Finding 4 — memory file hygiene.** `.opencode/memory/failures.md` carried a duplicated "MCP header-name mismatch risk" bullet (identical content twice + Resolution). Fix: dedup to a single bullet + Resolution; keep memory files concise and consistent so future failure-mode lookups stay unambiguous.

Outcome
-------
Implemented (Commit B of `dev-infra-copilot-fixes`): telemetry commands use `${HOME:?...}` guards (0 `/home/qualt` literals), `knowledge-bases.yaml` deleted + gitignored, `failures.md` deduped. The 1-char Minor follow-up (failures.md Resolution indent 3→2 spaces) was applied separately by the executor lane 2026-08-05.
