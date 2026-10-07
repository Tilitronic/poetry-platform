# DIA-132 OpenCode Agent Config Watchdog Research - Conspect (res020)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 3
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-132 "coder-escalated (kimi-k3) ONE-SHOT silent failure on DIA-130 (empty result, zero writes) + hardening question": persist the ai-specialist hardening research on timeout/heartbeat/empty-result-detection mechanisms for the coder-escalated lane. Every external claim is grounded in the 3 locally archived source files under `sources/` (Phase A output, archived 2026-08-13): the live OpenCode agent-config JSON schema (`opencode-config-schema.json`, fetched raw via curl, 38,773 bytes), the Agents documentation page (`opencode-agents-docs.md`, trafilatura markdown, 11,416 bytes), and the Plugins documentation page (`opencode-plugins-docs.md`, trafilatura markdown, 4,953 bytes). All 3 provisioned URLs archived with zero failures. Version attribution: the archived schema/docs do not self-declare a version; the v1.18.12 reference in this conspect is carried over from the DIA-132 research context (project pins `@opencode-ai/plugin@1.18.10` in `.opencode/package.json`).

## 1. Decision context (project-internal, not external-source claims)

- **DIA-132 incident**: on 2026-08-13, @coder-escalated (kimi-k3) ran ~9.5 minutes reading 5 config files on DIA-130, wrote NOTHING, and returned an EMPTY result at 13:54:44Z - silent failure, no artifacts. State-inspection lane cod-6 verified zero partial writes; the fix was completed by the base coder fallback (8cae0cd, review-resolved fc75a90). The empty-result mode did NOT reproduce in a subsequent kimi-k3 reliability smoke test (ses_0045c1442ffeshCbVqQJ6mzg4F, RESULT: SUCCESS, scratch file byte-exact), supporting the transient-failure hypothesis.
- **Hardening question (ticket section "Open question")**: should coder-escalated be hardened via (a) per-request timeout / heartbeat monitoring, (b) empty-result detection (non-empty result contract), (c) config changes to the agent definition? Any config change is section-10 work (ai-specialist research -> user decision -> design -> coder -> validate -> ai-auditor) and must reference DIA-132.
- **Operational guard in force**: after ANY empty escalation result, run a dedicated state-inspection lane to confirm zero partial writes before re-dispatching any lane (empty result is not proof of clean state; a silent failure and a partial write are indistinguishable from the result message alone).
- **ID correction (flagged)**: the dispatch assumed res003 was the next free research ID, but the memory shelf and knowledge/ already register res001..res019 (res003 = "Telemetry re-entrancy guards", created 2026-08-08). This conspect therefore uses res020, the actual next free ID.

## 2. AgentConfig schema surface (archived: opencode-config-schema.json, $defs.AgentConfig, lines 169-255)

The AgentConfig definition object carries exactly these properties (name, JSON type, schema description where present):

| Field | Type | Schema description / notes (archived) |
|---|---|---|
| `model` | string ($ref models.dev Model) | Model override for the agent; docs format `provider/model-id` |
| `variant` | string | "Default model variant for this agent (applies only when using the agent's configured model)." |
| `temperature` | number | Randomness/creativity control; docs: default is model-specific (typically 0, 0.55 for Qwen) |
| `top_p` | number | Alternative to temperature for response diversity (0.0-1.0) |
| `prompt` | string | Custom system prompt FILE for this agent; path relative to the config file location |
| `tools` | object of boolean | "@deprecated Use 'permission' field instead" (docs: `true` == `{"*": "allow"}`, `false` == `{"*": "deny"}`) |
| `disable` | boolean | Set true to disable the agent |
| `description` | string | "Description of when to use the agent" (docs: required config option) |
| `mode` | string enum: subagent/primary/all | How the agent can be used; docs: defaults to `all` when unspecified |
| `hidden` | boolean | "Hide this subagent from the @ autocomplete menu (default: false, only applies to mode: subagent)"; docs: hidden agents still invocable via Task tool |
| `options` | object | Free-form pass-through; docs: "Any other options you specify ... passed through directly to the provider as model options" |
| `color` | hex (#RRGGBB) or theme string | UI appearance; theme enum: primary/secondary/accent/success/warning/error/info |
| `steps` | integer > 0 | "Maximum number of agentic iterations before forcing text-only response" |
| `maxSteps` | integer > 0 | "@deprecated Use 'steps' field instead." |
| `permission` | $ref PermissionConfig | Permission keys: read, edit, glob, grep, list, bash, task, external_directory, todowrite, question, webfetch, websearch, lsp, doom_loop, skill (PermissionConfig, lines 109-168) |

The `steps`/`maxSteps` deprecation chain (maxSteps -> steps) and the `tools`/`permission` deprecation chain (tools -> permission) are both encoded directly in the archived schema descriptions.

## 3. Meaning of "steps" (archived: opencode-config-schema.json line 243 + opencode-agents-docs.md "Max steps")

- Schema: "Maximum number of agentic iterations before forcing text-only response" (line 243). It is a POSITIVE INTEGER (exclusiveMinimum 0), i.e. a count of agentic iterations, NOT a wall-clock timeout in seconds or milliseconds - there is no time unit anywhere in the field definition.
- Docs ("Max steps", agents-docs lines 144-150): "Control the maximum number of agentic iterations an agent can perform before being forced to respond with text only. This allows users who wish to control costs to set a limit on agentic actions. If this is not set, the agent will continue to iterate until the model chooses to stop or the user interrupts the session. When the limit is reached, the agent receives a special system prompt instructing it to respond with a summarization of its work and recommended remaining tasks."
- Consequence for DIA-132 hardening: `steps` bounds the number of tool-call loops, not elapsed wall time. A 9.5-minute silent run that never returns a result is NOT bounded by `steps` if the model stays within the iteration count, and `steps` provides no clock-based deadline. Per-agent timeout would therefore have to be implemented OUTSIDE the native agent config (see section 5 for the absence finding and section 6 for plugin-side options).

## 4. Plugin API surface (archived: opencode-plugins-docs.md)

### 4.1 Event categories documented

Command (`command.executed`); File (`file.edited`, `file.watcher.updated`); Installation (`installation.updated`); LSP (`lsp.client.diagnostics`, `lsp.updated`); Message (`message.part.removed`, `message.part.updated`, `message.removed`, `message.updated`); Permission (`permission.asked`, `permission.replied`); Server (`server.connected`); Session (`session.created`, `session.compacted`, `session.deleted`, `session.diff`, `session.error`, `session.idle`, `session.status`, `session.updated`); Todo (`todo.updated`); Shell (`shell.env`); Tool (`tool.execute.after`, `tool.execute.before`); TUI (`tui.prompt.append`, `tui.command.execute`, `tui.toast.show`).

### 4.2 Session events (plugins-docs lines 110-119) - the full session lifecycle surface

`session.created` | `session.compacted` | `session.deleted` | `session.diff` | `session.error` | `session.idle` | `session.status` | `session.updated`.

### 4.3 Tool hooks (plugins-docs lines 129-132)

`tool.execute.before` and `tool.execute.after` - wrap every tool invocation.

### 4.4 Compaction hook (plugins-docs lines 176-184)

`experimental.session.compacting` "fires before the LLM generates a continuation summary. Use it to inject domain-specific context that the default compaction prompt would miss." Setting `output.prompt` completely replaces the default compaction prompt (the `output.context` array is ignored in that case).

### 4.5 No empty-result / timeout hooks exist in the documented event surface

The plugin event catalog contains NO event for "agent returned an empty result", NO per-dispatch deadline hook, and NO heartbeat mechanism. Empty-result detection via plugins can only be approximated from combinations of the above (e.g. `session.idle`/`session.complete` observation combined with artifact presence checks - exactly the pattern the project already runs as the S1 A3 silent-failure scan in delegation-observer).

## 5. Use in the project's delegation-observer plugin (project-internal grounding)

`.opencode/plugins/delegation-observer.ts` (1,736 lines, header comment "Hook surface (real @opencode-ai/plugin@1.18.10 shapes)") uses exactly the archived hook surface:

| Hook / event (archived) | delegation-observer usage (plugin source) |
|---|---|
| `tool.execute.before` | A1 pure-dispatch enforcement (line 729) |
| `tool.execute.after` | A2 task_id capture - task() result parsed for child session id (line 998; parser mirrors omo `src/utils/task.ts:20-38`, handles `<task id="...">` XML and `task_id: ses_...` text) |
| `event` (session lifecycle) | session.created -> RUNNING (line 1201), session.idle -> COMPLETE + S6 A5 gate + S1 A3 silent-failure scan (line 1221), session.error -> FAILED + A3 scan (line 1329); comment line 1189 notes these are dispatched through the generic `event` hook ("session.created / session.idle / session.error are NOT named hooks") |
| `experimental.session.compacting` | injects an active registry snapshot so delegations survive context compaction (line 1399) |

The plugin header (lines 17-25) explicitly documents this as the real `@opencode-ai/plugin@1.18.x` hook shape, matching the archived plugin docs event list section-for-section. Companion plugin `needs-input-observer.ts` uses the same surface (tool.execute.before/after, session.created/updated/idle/status/error/deleted, experimental.session.compacting) for its multi-session state machine.

## 6. Absence findings relevant to DIA-132 hardening (archived grounding)

1. **No native per-agent timeout.** AgentConfig ($defs, lines 169-255) has NO timeout field. The only timeouts in the entire archived schema are: `ProviderConfig.options.timeout` / `headerTimeout` / `chunkTimeout` (lines 306-342, per-request/header/SSE-chunk timeouts for the PROVIDER connection, settable `false` to disable) and MCP-server request timeouts (`timeout`, default 5000 ms, lines 601 and 681; `mcp_timeout` line 1280). None of these bound the wall-clock duration of a single agent dispatch. Docs "Max steps" is iteration-count based (section 3), not clock-based.
2. **No native empty-result handling.** AgentConfig has no field declaring a non-empty result contract, and the plugin event catalog (section 4.5) has no empty-result event. Nothing in the archived schema or plugin docs forces a non-empty result or emits an alert on an empty one - the DIA-130 silent failure was detected by orchestrator-observed empty result + registry inspection, not by any native mechanism.
3. **Plugin-side approximation is the available native path.** The documented surface that CAN support the ticket's hardening candidates: (a) heartbeat/timeout monitoring via session events (`session.idle`, `session.status`, `session.updated`) plus `tool.execute.after` as an activity tick - a plugin can detect a session that stays non-idle past a threshold and emit a loud alert; (b) empty-result detection via `session.idle`/`session.error` + artifact-presence assertion (the delegation-observer S1 A3 scan pattern). Both are plugin-level constructs, consistent with the "silent-failure detection path (state-inspection-before-redispatch guard)" lesson already persisted for DIA-132.

## 7. Cross-references

- res019 (OMO Slim Version-Gate): pinned `@opencode-ai/plugin@1.18.13` / `@opencode-ai/sdk@1.18.13` for the OMO npm build; project plugin package pins 1.18.10.
- res008 (Source-archival fallbacks, DIA-072): the curl/trafilatura strategy used here (raw curl for JSON endpoints, trafilatura markdown for docs pages) was validated there; archive-before-claim policy applied - all 3 sources archived with zero failures.
- res017 (Rung-3 evidence): kimi-k3 490 req/mo cap at $3/$15 is the constraint behind the ONE-SHOT no-retry rule that made the DIA-130 empty result costly.

## 8. Works cited (MLA)

OpenCode Documentation. "Agents." *opencode.ai*, opencode.ai/docs/agents. Accessed 13 Aug. 2026. [Archived: sources/opencode-agents-docs.md]

OpenCode Documentation. "Plugins." *opencode.ai*, opencode.ai/docs/plugins. Accessed 13 Aug. 2026. [Archived: sources/opencode-plugins-docs.md]

OpenCode. "Agent Config JSON Schema." *opencode.ai*, opencode.ai/config.json. Accessed 13 Aug. 2026. [Archived: sources/opencode-config-schema.json]
