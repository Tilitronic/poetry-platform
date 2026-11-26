# Tool enumeration in OpenCode — CLI mechanisms, permission model, plugin registration

This conspect synthesizes eleven archived sources (see Sources) to answer DIA-066: how to enumerate all tools OpenCode can invoke for a tool-coverage audit. The synthesis combines a runtime probe (CLI), static manifests (config and plugins), and the permission system that determines effective availability. Inline citations reference filenames in the local archive directory.

Executive summary

OpenCode exposes tools from three origins: built-in core tools, custom tools registered via configuration or plugins, and tools delivered by MCP (Model Context Protocol) servers. A conservative inventory requires both (A) a runtime census produced by the CLI debug endpoint, and (B) a static harvest of config and plugin declarations. Because OpenCode evaluates permissions by concatenating ordered rulesets and applying last-match-wins semantics, the static presence of a tool does not guarantee runtime executability; effective availability must be computed per agent (opencode-tools-docs.md; opencode-cli-docs.md; opencode-permissions-v2-docs.md).

What a complete inventory must include

- Core built-in tools and their semantics (examples: bash, read, edit, write, grep, glob, webfetch, websearch, skill, question, apply_patch). These are documented in the Tools/CLI reference and are the starting point for any audit (opencode-tools-docs.md; opencode-cli-docs.md).
- Custom tools declared in configuration or registered by plugins. Plugins may supply tools programmatically; plugin discovery includes both project-level and global plugin directories as well as npm-installed plugin packages referenced in config (opencode-plugins-docs.md).
- MCP-provided tools: external tool providers surfaced by MCP servers. MCP tools may be namespaced and should be treated as distinct tool entries in the registry (pr-9980-mcp-tools.md; opencode-permissions-v2-docs.md).
- Effective availability: the resolved allow/ask/deny decision after merging defaults, global rules, and agent-specific rules. Defaults are permissive for many actions (notably read), while external-directory and sensitive resources commonly default to ask or deny (opencode-permissions-v1-docs.md; agent-defaults-source.md; opencode-book-ch9-permissions.md).

How the runtime census works (CLI)

- The CLI exposes a debug command that emits an agent’s available tools and a resolved map indicating whether each tool is enabled for that agent. When invoked without a specific --tool flag the handler prints an object with agent metadata and a tools map showing resolved booleans; when --tool is provided it executes the tool with given params (debug-agent-handler-source.md; opencode-cli-docs.md).
- The handler’s implementation retrieves registry tools, fetches MCP tools, and resolves tool enablement by evaluating the agent’s permission ruleset against each candidate tool ID (debug-agent-handler-source.md; pr-9980-mcp-tools.md).

Permission models and their impact on enumeration

- v1 vs v2: legacy (v1) permission fields are tool-keyed and object-oriented; v2 standardizes permissions as an ordered array of rules with explicit `action`, `resource`, and `effect` fields. v2 uses wildcard matching and the last-matching-rule-wins strategy, which makes rule order essential when reconstructing effective policies (opencode-permissions-v1-docs.md; opencode-permissions-v2-docs.md).
- Action/resource matching: v2 treats `action` as the permission category (eg. read, edit, shell) and `resource` as the value the tool will use (path, command text, URL, agent ID). MCP tools may appear with action names like `<server>_<tool>`; implementors normalize unsupported characters to underscores for matching (opencode-permissions-v2-docs.md).
- Defaults and merging: shipped agent defaults (build, plan, general, explore, etc.) are concatenated with global and agent-specific rules to produce the ordered ruleset evaluated at runtime. Because evaluation inspects rules from last to first, later agent overrides take precedence (agent-defaults-source.md; opencode-book-ch9-permissions.md).

Plugin and npm-sourced tools

- Plugins may declare custom tools via a `tool` helper that returns a tool definition (description, args schema, execute). Plugins are discovered in global and project plugin directories and via npm packages listed in config; npm packages are installed (using Bun in current implementation) and cached at startup (opencode-plugins-docs.md).
- When plugins or npm packages supply tools they appear in the runtime registry and therefore should show up in the debug agent output if the registry fetch includes plugin-provided and MCP-provided tools (opencode-plugins-docs.md; pr-9980-mcp-tools.md).
- Capture caveat: one archived npm page was blocked by Cloudflare’s JS challenge and only a diagnostic snapshot was preserved; that file is non-authoritative and should be re-fetched with a headless browser or registry API if package README/metadata are required (opencode-show-tools-npm.md).

Recommended enumeration procedure (concise)

1) Static harvest: parse global and project opencode config files (opencode.json / ~/.config/opencode/opencode.json) for declared tools, plugin package names, and configured MCP servers; list plugin directories (`.opencode/plugins/`, `~/.config/opencode/plugins/`) and referenced npm packages (opencode-plugins-docs.md; opencode-cli-docs.md).

2) Runtime census: for each agent of interest run the CLI debug command (documented in the CLI reference) and capture its JSON output. Save both the registry tool list and the resolved tools map (opencode-cli-docs.md; debug-agent-handler-source.md).

3) Permission reconstruction: assemble the effective ordered ruleset by concatenating base defaults, global permissions, and agent-specific permissions. Apply the ruleset semantics (wildcards, last-match-wins) to determine each tool’s effective state (opencode-permissions-v2-docs.md; opencode-book-ch9-permissions.md).

4) Cross-reference and classify: union the static list (declared tools, plugin packages, MCP entries) with the runtime registry. Classify tools as: confirmed-executable (appears at runtime and allowed), present-but-restricted (appears but ask/deny), declared-only (in config/plugins but not surfaced at runtime), and MCP-only (only exposed via MCP) (pr-9980-mcp-tools.md; issue-1142-tool-list.md).

5) Gap and risk reporting: flag declared-only items and any broad wildcard `allow` rules (eg. `*` or `server_*` catch-alls) that effectively permit large tool families. Broad `allow` catch-alls should be treated as warnings and require manual review (opencode-permissions-v1-docs.md; opencode-book-ch9-permissions.md).

Practical considerations and pitfalls

- Permissive defaults bias static scans: because many actions default to `allow`, a static list may overestimate reachability. Always compute effective permissions per agent before concluding coverage (opencode-permissions-v1-docs.md; agent-defaults-source.md).
- MCP naming and normalization: include namespacing and underscore normalization when reconciling MCP tool identifiers with permission rules (opencode-permissions-v2-docs.md; pr-9980-mcp-tools.md).
- Source capture limitations: when an archived source is only a diagnostic snapshot (eg. a Cloudflare challenge page), mark it as non-authoritative and re-fetch with a browser-capable tool or the registry API if necessary (opencode-show-tools-npm.md).

Audit checklist (short)

- Extract declared tools and plugin package names from config and plugin dirs (opencode-plugins-docs.md).
- For each agent: run CLI debug agent and save JSON output (opencode-cli-docs.md; debug-agent-handler-source.md).
- Reconstruct effective rulesets and resolve tool states (opencode-permissions-v2-docs.md; agent-defaults-source.md).
- Produce coverage classification and surface gaps/warnings for wildcard allows (pr-9980-mcp-tools.md; issue-1142-tool-list.md).

Sources

(All sources archived under knowledge/res004-tool-enumeration/sources/)

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
- opencode-show-tools-npm.md (diagnostic capture — Cloudflare-protected; see file for capture note)

(End of file)
