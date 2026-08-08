# Tool enumeration in OpenCode — CLI mechanisms, permission model, plugin registration

This conspect synthesizes 11 captured sources archived under knowledge/res004-tool-enumeration/sources/ and addresses the DIA-066 pre-scope: how to enumerate all registered tools for a tool-coverage audit.

MLA-style citations are provided inline with source keys matching filenames.

## Summary
OpenCode exposes a tool universe composed of built-in tools, custom tools registered in opencode.jsonc, and tools surfaced by MCP servers and plugins. Enumeration requires both a runtime census (opencode debug agent <agent>) and static parsing of permission blocks in config files (opencode.jsonc). Multiple sources recommend cross-referencing these two lists and treating blanket permission forms as soft warnings.

## Key findings
- Built-in tools list and semantics (opencode-cli-docs.md; snip snip opencode-tools-docs.md)
- Permission schema v1 vs v2 differences and v2-rejection behavior (opencode-permissions-v1-docs.md; snip snip opencode-permissions-v2-docs.md)
- Plugin registration paths and MCP interplay (opencode-plugins-docs.md; snip snip pr-9980-mcp-tools.md)
- Runtime cli handlers and agent defaults (agent-defaults-source.md; snip snip debug-agent-handler-source.md)
- Known gaps and issue evidence (issue-1142-tool-list.md)

## Recommended enumeration procedure (DIA-066 aligned)
1. Produce a runtime tool census by invoking:  and capture its tool list output.
2. Static parse: extract all tool entries from  and any per-agent permission blocks; snip snip normalize names and wildcard/blanks.
3. Cross-reference: compute coverage = union(static, runtime); snip snip gaps = universe − coverage where default disposition is allow.
4. Report blanket rules (default allow for an entire MCP) as WARN; snip snip treat explicit tool-allow omissions as HARD gaps.

## Notes on npm package capture
The npmjs package @adrianlzt/opencode-show-tools was Cloudflare-protected. The saved diagnostic markdown notes the JS challenge and preserved the raw HTML snapshot; snip snip full README/metadata require a headless browser or npm registry API.

## Sources
- opencode-cli-docs.md
- opencode-tools-docs.md
- opencode-plugins-docs.md
- opencode-permissions-v1-docs.md
- opencode-permissions-v2-docs.md
- agent-defaults-source.md
- debug-agent-handler-source.md
- pr-9980-mcp-tools.md
- issue-1142-tool-list.md
- opencode-book-ch9-permissions.md
- opencode-show-tools-npm.md (diagnostic capture)
