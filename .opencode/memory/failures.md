Failed-loop lessons & preventive actions

- Failure mode: Boss/orchestrator making direct code edits for dev-infra/config (scripts, Makefile, opencode configs). Root cause: cultural shortcut and lack of process enforcement.
  Preventive action: HARD RULE added to boss_append.md requiring the boss to dispatch @coder for dev-infra and config edits; Change Routing table added. Educate team on the rule during onboarding and code review.

- Failure mode: Non-hermetic shell tests that relied on host Docker or system state. Root cause: tests executed against live host services.
  Preventive action: Use the hermetic testing pattern (mock docker binary, user namespaces, tmpfs over /run, vendor bats-core). Document the pattern in tests/README and require reviewer verification of hermeticity during review.

- Failure mode: Double-/api base URL composition bug escaped mocked tests and caused live runs to 404. Root cause: mock-mode used a different base composition than real API. Preventive action: add a real-API smoke run (gated) and a URL-join helper for base + path to avoid double prefixing.

- Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
 - Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
   Resolution: Fixed by updating the Context7 MCP registration in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json to use "Authorization: Bearer {env:CONTEXT7_API_KEY}", set "oauth": false to avoid false OAuth detection, and increase MCP timeout to 15000ms to accommodate remote latency. See .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md for source-verified details. Keep this failure entry for historical context; mark as resolved by the above config updates.
