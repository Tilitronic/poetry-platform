# Context7 MCP registration: gate findings (2026-08-02)

Source: ai-specialist research (upstash/context7 server source + official docs)

Summary
-------
This document records the findings that drove the context7 remote MCP registration fix in `.opencode/opencode.jsonc` and `tools/opencode-docker/config/opencode.json`. They are NOT recoverable from the git diffs alone and must be persisted to prevent regression.

Findings
--------
- **Canonical auth header**: Context7 MCP server accepts `Authorization: Bearer <key>` as the canonical auth header. The server also accepts legacy aliases — `context7-api-key`, `x-api-key`, `context7_api_key`, `x_api_key` — per `extractApiKey` in `packages/mcp/src/index.ts`. Use the documented OpenCode form (`Authorization: Bearer`) in configs.

- **OAuth auto-detection**: The `/mcp` endpoint emits `WWW-Authenticate` headers even for anonymous requests, which can trigger OpenCode's OAuth auto-detection and break the handshake. `"oauth": false` must be set on the server entry to suppress it.

- **Default MCP timeout too tight**: OpenCode's default MCP timeout (5s) is too tight for a remote server; set `"timeout": 15000`.

- **`{env:VAR}` semantics**: `{env:VAR}` in OpenCode config resolves to the process env value; empty string when unset. MCP connects only at OpenCode startup — a restart is required for config changes to take effect.

- **Anonymous access works**: `/mcp` allows anonymous access (`requireAuth=false`); providing a key raises rate limits (free tier: 1000 calls/month).

Sources
-------
- upstash/context7 README
- context7.com/docs/resources/all-clients
- opencode.ai/docs/config

Context & verification
----------------------
Fix applied 2026-08-02 and validated via `make test-config` (JSONC syntax). Pending user action: ensure `CONTEXT7_API_KEY` is set in the environment and restart OpenCode so the MCP server reconnects at startup.
