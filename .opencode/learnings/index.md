# Learnings Index

Last updated: 2026-07-11

## Knowledge Sources

- **Dynamic experience:** This directory (`.opencode/learnings/`)
- **Static curated literature:** `book-rag` skill (`#rag` queries)

## External Patterns

See `external-patterns/` for findings from external research (Anthropic blog,
OpenCode docs, oh-my-opencode-slim best practices).

## Registration

Each entry should include:
- `date`: ISO date
- `source`: Which agent/skill/session produced it
- `finding`: What was discovered
- `status`: `confirmed` | `no-effect` | `regressed`

## Index

| Date | Source | Finding | Status |
|------|--------|---------|--------|
| 2026-07-13 | ai-assist-specialist | `web: allow` is invalid — must be `webfetch: allow`. Fix applied to agents/ai-assist-specialist.md. | confirmed |
| 2026-07-13 | code-executor-design | Created agents/code-executor.md with inline writing guidelines (P1–P4, naming tables, smell checklist). Must be allowed in opencode.jsonc `build.task` permissions. | confirmed |
