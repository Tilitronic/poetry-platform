# OpenCode V2 Native Capabilities vs. This Project's Custom Mechanisms

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 28
phase-a-failures: 4
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to memory-manager
-->

Campaign ticket DIA-261112-exon. Pure synthesis from the archived Phase A sources in
`knowledge/res-261113-hi88-opencode-v2-native-capabilities/sources/` only. No network fetch
was performed. Claims marked VERIFIED are grounded in an archived source and cited by
filename; claims marked UNVERIFIED say what was searched or what is missing. Project-side
facts (mechanism names, file paths, LOC) are local repository measurements taken at conspect
time (2026-11-13) and are not cited as external sources.

---

## 1. EXECUTIVE VERDICT

| Mechanism | Native primitive in V2 | Verdict | Current LOC | Est. V2 LOC |
|---|---|---|---|---|
| Session waiting / needs-input tracking | `permission.request.list`, `form.list`, `session.active`, events `permission.asked` + `form.created` + `session.idle`, `ctx.session.wait` (docs-api.md; docs-build-plugins-server.md) | PARTIAL | 1728 (`needs-input-observer.ts`) | ~200 |
| Permission-stall watchdog | none (no ask timeout); plugin timer + `ctx.permission.reply({decision:"reject"})` (docs-build-plugins-server.md) | ABSENT | 1728 shared + 349 (`lib/stall-sweep.ts`) | ~70 |
| Unattended auto-approval | `opencode run --auto` for headless; in-server `permission.hook("evaluate")` may set `effect="allow"` (docs-cli-commands.md; docs-build-plugins-server.md) | PARTIAL | 216 (`lib/permission-fast-resolve.ts`) | ~40 in-server, 0 headless |
| Cross-session awareness / concurrency safety | `session.list`, `session.active`, location-wide `permission.request.list` + `form.list`, `event.subscribe`, worktree CRUD (docs-api.md; docs-build-plugins-server.md) | PARTIAL | 1209 (`lib/registry.ts`, shared) | ~150 plus own file locks |
| Journal | per-session `experimental.session.log` (durable subset) + `ctx.storage`; server event stream is live-only (docs-api.md; docs-build-client.md) | PARTIAL | 1451 (`lib/registry.ts` 1209 + `lib/journal-persistence.ts` 242) | ~250 |
| Handoff | none; closest carriers are `session.metadata` and `ctx.storage` (docs-build-plugins-server.md; gh-plugin-host-core.ts) | ABSENT | 221 (`lib/handoff.ts`) | ~130 |
| Typed decision tool | `ctx.experimental.generate.decisions` (predicate/choice/score) + `question` tool / forms + `ctx.storage` (docs-build-plugins-server.md; docs-api.md) | PARTIAL | ~370 (`log_decision` block, `delegation-observer.ts` L3544-3917) | ~90 |
| Ticket gate | no ticket domain; `policies` action enum is closed (config-schema.json); custom actions are allowed only as permission action strings (docs-permissions.md) | ABSENT | 383 (`lib/ticket-gate.ts`) + 136 (`lib/capability.ts`) | ~400, stays custom |
| Reviewer envelope | `tool.hook("execute.before")` can rewrite `subagent` prompt input (docs-build-plugins-server.md; gh-tool-subagent.ts) | PARTIAL | 37 (`lib/envelope-gate.ts`) + injection block in `delegation-observer.ts` | ~70 |
| Routing gate | `session.hook("experimental.model.resolve")`, `ctx.model.transform`, `ctx.session.switchModel` (docs-build-plugins-server.md) | PARTIAL | 427 (`lib/routing-gate.ts` 152 + `preset-model-guard.ts` 275) | ~90 |
| Protected-path edit gate | `edit` permission rules + `policies` `tool.use` hard deny + shell scanner inferred-directory checks (docs-permissions.md; docs-policies.md) | PARTIAL | 289 (`lib/bash-write-gate.ts`) | ~60 config + ~200 bash classifier retained |
| Fetch-source | `webfetch` tool (permission `webfetch`, URL resource) and Code Mode `fetch` (docs-tools.md) | PARTIAL | 321 (`.opencode/tools/fetch-source.ts` 218 + `lib/destination-policy.ts` 103) | ~250, chain retained |
| Session-id helper | tool execution `context.sessionID` / `context.agent`; hook `event.sessionID` (docs-build-plugins-server.md; gh-tool-subagent.ts) | NATIVE | 25 (`.opencode/tools/get-my-session-id.ts`) | 0 |

LOC column = total lines of the implementing file(s) at conspect time; rows marked "shared"
count a file that serves more than one mechanism. Estimated V2 LOC is a design estimate, not
a measurement.

**The three primitives that do the most work:** (1) plugin storage KV, a durable,
plugin-id-scoped JSON key-value store with an ordered prefix scan
(docs-build-plugins-server.md; gh-plugin-storage-type.ts; gh-kv-service.ts); (2) the
`permission.hook("evaluate")` hook, which runs after configured rules and can rewrite the
decision (docs-build-plugins-server.md); (3) `tool.hook("execute.before")`, which can inspect
or replace tool input and reject a call with a model-visible `Tool.Error`
(docs-build-plugins-server.md; github-releases.md). **The three things V2 does NOT provide:**
no compare-and-set or lock primitive on storage KV (gh-kv-service.ts exposes only
get/set/remove/scan); no permission-ask timeout, no auto-deny, and no
`OPENCODE_UNATTENDED`-style server flag (searched config-schema.json, docs-config.md,
docs-permissions.md, docs-policies.md, and both releases captures for `timeout`,
`auto-deny`, and `UNATTENDED`: zero hits on permission asks); and no replayable journal or
ticket/handoff domain - the server event stream is explicitly live-only with no replay
(docs-build-client.md).

---

## 2. PLUGIN STORAGE

What it is: `ctx.storage` stores, reads, and removes durable JSON values scoped to the
plugin, with an ordered prefix scan and cursor pagination (`prefix`, `after`, `limit`,
`entries`, `next`) (docs-build-plugins-server.md). The type contract is
`StorageEntry { key, value: Schema.Json }` plus `StorageScanOptions` / `StorageScanResult`
(gh-plugin-storage-type.ts). The migration guide states the intent plainly: "Use
`ctx.storage` instead of inventing a global file when state belongs to a plugin; its JSON
values are durable and scoped to the plugin" (docs-build-plugins-migrate-v1.md).

Operations (all four, VERIFIED): `get(key)`, `set(key, value)`, `remove(key)`,
`scan({prefix, after, limit})` (docs-build-plugins-server.md).

Implementation and scoping (VERIFIED from upstream source): the plugin context binds
`storage: storage(kv, pluginID)`, which prefixes every key with
`plugin:<hex-encoded plugin id>:` before delegating to the shared KV service
(gh-plugin-host-core.ts). The KV service is a SQL-backed map: `get` selects by key, `set` is
an insert with `onConflictDoUpdate`, `remove` deletes, and `scan` is a range query ordered by
key with a computed prefix end and a limit clamped to 1..1000 (gh-kv-service.ts).

Lifetime (VERIFIED as durable; INFERRED as unload-safe): docs call the values durable
(docs-build-plugins-migrate-v1.md) and the backing rows live in the server database table
with upsert semantics (gh-plugin-host-core.ts; gh-kv-service.ts); hook and transform
registrations are what get disposed on unload, not stored rows
(docs-build-plugins-migrate-v1.md). That storage therefore survives plugin reload and server
restart follows from those two facts but is not stated as such in any archived source
[INFERRED].

Cross-session visibility (VERIFIED): the namespace contains only the plugin ID - no session
ID, no location ID (gh-plugin-host-core.ts). One plugin instance's keys are therefore readable
by every session that reaches the same server database, which is exactly what a cross-session
ticker needs. Whether two separate OpenCode server processes with different data directories
share rows is UNVERIFIED (the archived sources do not discuss multi-process KV; the CLI docs
only note that the database path respects `OPENCODE_DB` (docs-cli.md, grep-confirmed line 49)).

The ABSENT piece (VERIFIED negative): the KV interface has four methods and nothing else -
no CAS, no version stamps, no lock acquire/release, no transactional multi-key write
(gh-kv-service.ts `Interface`). `set` blindly upserts, so two concurrent writers race with
last-write-wins. Search scope for a lock primitive elsewhere: the plugin server reference, the
plugin host source, and the KV service contain no lock/CAS symbol
(docs-build-plugins-server.md; gh-plugin-host-core.ts; gh-kv-service.ts). Any port that needs
atomic check-and-set (capability token issuance, handoff slot claims, journal sequence
reservation) must keep its own file-lock or reservation-counter logic.

---

## 3. PERMISSION LAYER (highest-consequence subsection)

### 3.1 The `permissions` rules layer

- One ordered array of `{action, resource, effect}` rules; "The last matching rule wins, so
  the specific exceptions follow the broad rule" (docs-permissions.md).
- Load order: lower-priority configuration first, global rules appended next, agent rules
  appended last; agent rules do not replace the global array (docs-permissions.md).
- Default when nothing matches: `ask` (docs-permissions.md).
- Wildcards: `*` is zero or more characters and crosses `/`; `?` is one character; matching is
  whole-value on the normalized path, case-insensitive on Windows; a shell pattern ending in
  `*` also matches the bare command without arguments (docs-permissions.md).
- Multi-resource operations: "Any `deny` denies the operation; otherwise any `ask` asks;
  otherwise the operation is allowed" (docs-permissions.md).
- Action renames from V1 (VERIFIED): "`bash` is now `shell`, `task` is now `subagent`, and
  `write` and `patch` are now `edit`" (docs-migrate-v1.md). V2 built-in actions and resources
  are enumerated in docs-permissions.md (`read`, `edit`, `glob`, `grep`, `shell`, `subagent`,
  `skill`, `question`, `webfetch`, `websearch`, `external_directory`, MCP-derived
  `<server>_<tool>`, `execute`); `doom_loop` and `lsp` are explicitly not V2 actions
  (docs-permissions.md).
- Action names are open strings: "V2 action names are strings, so plugins may define more
  actions" (docs-permissions.md). This is why a plugin can assert its own action (for example
  a ticket-like action) through `ctx.permission.assert`, even though no such action ships.
- Saved approvals from an "Allow always" reply are durable, project-scoped `allow` rules that
  "never override a configured `deny`" (docs-permissions.md).
- Reply choices: `once`, `always`, `reject`; `reject` rejects the request "and every other
  pending permission request in that session" (docs-permissions.md; enum confirmed as
  `Permission.Reply = "once" | "always" | "reject"` in docs-api.md).

### 3.2 The `policies` layer

- Separate from permissions: policies are binary, never prompt, and "only ever tighten what
  permissions and providers would otherwise allow" (docs-policies.md).
- Closed action enum (VERIFIED from ground-truth schema): `provider.use`, `tool.use`,
  `integration.connect`, `integration.use`, `mcp.use`, `skill.use`, `plugin.use`,
  `websearch.use`, with `effect` limited to `allow` | `deny`
  (config-schema.json; docs-policies.md). There is no ticket, handoff, envelope, or session
  action, and no `ask` effect - so no policy can express a project gate that should prompt.
- `tool.use` resource is `<action>:<value>` and "applies after agent rules and saved
  approvals, so it overrides an `ask` and an 'Allow always' approval alike"; a denied check
  fails with `Blocked by configuration policy` instead of prompting (docs-policies.md).
- A `tool.use` `allow` never grants access; it only lifts an earlier broader `deny`
  (docs-policies.md).
- Project-committable: policies live in `opencode.json(c)`; broader configuration is evaluated
  later so it overrides narrower configuration, and Console/managed sources outrank user and
  project files (docs-policies.md). Invalid statements are dropped with a warning while the
  rest still apply (docs-policies.md).

### 3.3 CRITICAL constraint: explicit `deny` skips the evaluate hook

VERIFIED verbatim from the plugin server docs: "Hooks run for `allow` and `ask` decisions. An
explicit configured `deny` is final and does not invoke the hook. A hook may change `effect`
to `allow`, `ask`, or `deny`" (docs-build-plugins-server.md). Policies reach the same place:
a policy hard-denies a check after rules and saved approvals run and "never grants access"
(docs-permissions.md; docs-policies.md).

Consequence: any token-based or condition-based exception gate must be written as an `ask`
base rule whose decision is rewritten by `permission.hook("evaluate")`. If the base rule is
`deny` (or the check is covered by a `policies` `tool.use` deny), the hook never runs and no
token can lift the block.

Worked example - protected-path exception gate:

Wrong (dead code, never fires the hook):

```jsonc
{
  "permissions": [
    { "action": "edit", "resource": "/workspace/.opencode/*", "effect": "deny" }
  ],
  "policies": [
    { "action": "tool.use", "resource": "edit:/workspace/.opencode/*", "effect": "deny" }
  ]
}
```

Both variants are final: the configured rule skips the evaluate hook
(docs-build-plugins-server.md) and the policy overrides `ask` and saved approvals alike
(docs-policies.md).

Right (ask base + hook grant):

```jsonc
{
  "permissions": [
    { "action": "edit", "resource": "/workspace/.opencode/*", "effect": "ask" }
  ]
}
```

```ts
await ctx.permission.hook("evaluate", (event) => {
  if (event.action !== "edit") return
  const token = (event.metadata ?? {}).capability as string | undefined
  if (token && verifyCapabilityToken(token, "edit:/workspace/.opencode/")) {
    event.effect = "allow"          // or keep "ask" to escalate with a message
    event.message = "capability token accepted"
  }
})
```

The token reaches the hook because `ctx.permission.assert` accepts a `metadata` field that
"passes extra detail to permission prompts and `evaluate` hooks"
(docs-build-plugins-server.md), and `assert` resolves once the action is allowed or rejects
with a model-visible `Tool.Error` carrying the reason (docs-build-plugins-server.md;
gh-plugin-host-core.ts shows the `Permission.BlockedError` -> `Tool.Error` mapping).

Design corollary (VERIFIED): because saved "always" approvals can never override a configured
`deny` (docs-permissions.md) and policies beat saved approvals (docs-policies.md), the project
must not try to solve persistent exceptions by saving approvals against a deny. The `ask` +
hook path is the only place where a project-defined condition can grant access.

---

## 4. HOOK SURFACE

Registration shape: hooks are registered per domain with `ctx.<domain>.hook(name, callback)`
and return a disposable registration; multiple plugins run in registration order
(docs-build-plugins-server.md).

| Surface | Carries from V1 | Notes (VERIFIED) |
|---|---|---|
| `ctx.tool.hook("execute.before")` | V1 `tool.execute.before` | "Inspect or replace tool input before execution"; a hook can rewrite `event.input` (upstream does exactly this for the `subagent` tool) (docs-build-plugins-server.md; gh-tool-subagent.ts). Can reject with a model-visible `Tool.Error`: "`@opencode/plugin/effect` now exports `Tool`, so an `execute.before` hook can reject a call with `Tool.Error`" (github-releases.md). |
| `ctx.tool.hook("execute.after")` | V1 `tool.execute.after` | Sees a completed-or-error status and can rewrite `event.result` (docs-build-plugins-server.md). |
| `ctx.permission.hook("evaluate")` | V1 `permission.ask` (migration table) | Runs after configured rules, before prompt publish; may set `effect` and `message`; runs for `allow`/`ask` only (docs-build-plugins-server.md; docs-build-plugins-migrate-v1.md). |
| `ctx.session.hook("prompt")` | V1 `chat.message` | Runs once at durable prompt admission, not before every model call; owned mutable draft (`prompt`, `metadata`, `delivery`); session/message IDs readonly; no typed rejection API (docs-build-plugins-server.md; docs-build-plugins-migrate-v1.md). |
| `ctx.session.hook("context")` | V1 `chat.params` + `experimental.chat.system.transform` + `experimental.chat.messages.transform` | Edits `system`, `messages`, `tools`, `options` immediately before an agent-loop model call (docs-build-plugins-migrate-v1.md; docs-build-plugins-server.md). |
| `ctx.session.hook("compaction")` | V1 `experimental.session.compacting` | Can set `result` to record the summary itself and skip the model call (docs-build-plugins-server.md). |
| `ctx.session.hook("title")` | (V1 title flow) | Can set `result`; explicitly has no `agent` and no `tools` (docs-build-plugins-server.md). |
| `ctx.shell.hook("create.before")` | V1 `shell.env` | Rewrites command, cwd, timeout, executable, env (docs-build-plugins-migrate-v1.md). |
| `ctx.event.subscribe()` | V1 `event` | Typed stream, optional `types` filter, abort in cleanup; unknown types ignored with a warning (docs-build-plugins-server.md). |
| domain `transform(...)` | V1 `config`, `tool` map, `auth`, `provider` | No single mutable global config object in V2 (docs-build-plugins-migrate-v1.md). |

Also present in V2 with no V1 counterpart: `session.hook("generate")`, `"model.request"`,
`"http.request"`/`"http.response"`, `"retry"`, `"fork"`, and experimental
`"experimental.model.resolve"` (docs-build-plugins-server.md).

Per-agent conditioning (VERIFIED): the `agent` field rides the hook event -
`SessionContextHook.agent` for `context`/`compaction`/`generate`, `SessionModelResolveHook.agent`,
the HTTP/WebSocket/retry hooks, and `PermissionEvaluation.agent` for evaluate
(docs-build-plugins-server.md). The tool execution context carries `context.agent` and
`context.sessionID` (docs-build-plugins-server.md). The `prompt` hook's own event type is not
expanded in the archived reference, so whether it exposes `agent` directly is UNVERIFIED
(searched docs-build-plugins-server.md session reference block and docs-api.md).

V1 hooks with NO equivalent (VERIFIED): "There is no direct V2 hook corresponding to every
experimental V1 hook. Re-evaluate plugins that use `experimental.compaction.autocontinue`,
`experimental.provider.small_model`, or `experimental.text.complete`"
(docs-build-plugins-migrate-v1.md). `command.execute.before` "also has no one-to-one global
hook" (docs-build-plugins-migrate-v1.md). The first of these matters directly: the current
needs-input ticker suppresses compaction auto-continue messages via the V1
`experimental.compaction.autocontinue` hook (project code,
`.opencode/plugins/needs-input-observer.ts` L23), and V2 offers no replacement - the closest
V2 behavior is the `compaction` hook's `result` override plus synthetic-message inspection on
the `prompt` path (docs-build-plugins-server.md) [design gap, not a drop-in].

---

## 5. EVENT TAXONOMY CHANGES

VERIFIED V2 event names come from the `V2Event` union and the `/api/event` `types` parameter
in docs-api.md; schema entries confirm each shape exists.

Renames and removals that break a port:

1. `question.*` -> `form.created`, `form.replied`, `form.cancelled`. The three `form.*` events
   are in the V2 union (docs-api.md), and the question tool's docs describe it as "an
   interactive form" (docs-tools.md). The V1 spellings (`question.asked`, `question.replied`,
   `question.rejected`, plus `question.v2.*` variants) are what the current plugin listens for
   (project code, `.opencode/plugins/needs-input-observer.ts` L13-L26), but the manifest
   explicitly excludes the V1-era event list, so the canonical V1 names are UNVERIFIED from
   archived external sources (`.source-urls.txt` exclusion note).
2. `permission.asked` / `permission.replied` are still present and unchanged in V2
   (docs-api.md).
3. There is no `permission.rejected` event: rejection is a reply decision value inside
   `permission.replied` (`Permission.Reply = "once" | "always" | "reject"`)
   (docs-api.md; docs-permissions.md reply table).
4. `session.compacted` is gone in favour of `session.compaction.started`,
   `session.compaction.delta`, `session.compaction.ended`, `session.compaction.failed`
   (docs-api.md). Negative finding: the string `session.compacted` does not occur anywhere in
   the archived corpus (searched all of `sources/` including both releases captures and the
   API reference).
5. `session.execution.*` (`started`, `succeeded`, `failed`, `interrupted`) and
   `session.tool.*` (`called`, `success`, `failed`, plus streaming `session.tool.input.*` and
   `session.tool.progress`) exist as V2 events (docs-api.md).
6. DURABILITY SPLIT (important for a journal): a per-session durable set
   `Session.Event.Durable` includes the execution, step, text, tool, retry, compaction, revert,
   inbox, and usage events, but does NOT include `permission.asked`, `permission.replied`,
   `form.*`, `session.idle`, or `session.tool.progress` (docs-api.md). So permission and form
   transitions are live-only; a journal that must record them has to subscribe rather than
   replay.
7. Other V1-era names the current code consumes that must be re-mapped: `chat.message`
   (-> `prompt` hook or user-message events), `session.status` (-> `session.idle` /
   `SessionStatusUpdated`), `session.error` (-> `session.execution.failed` /
   `session.step.failed`), `experimental.compaction.autocontinue` (no equivalent; see
   section 4). The V2-side targets are VERIFIED (docs-api.md;
   docs-build-plugins-migrate-v1.md); the V1-side canonical spellings remain UNVERIFIED from
   archived sources per the manifest exclusion.

Events worth adding on a port (all VERIFIED present): `session.idle`,
`session.inbox.delivered/enqueued/cancelled`, `session.permissions`,
`session.metadata.updated`, `worktree.updated`, `config.updated`, `location.shutdown`
(docs-api.md).

---

## 6. WAIT AND CONCURRENCY

Direct answer: **No, V2 does not replace the needs-input plugin.** It supplies the inputs and
the output channels, but not the state machine.

What V2 does NOT provide (negative findings with search scope):

- No permission-ask timeout or expiry. Searched docs-permissions.md, docs-policies.md,
  docs-config.md, config-schema.json, docs-api.md, and both releases captures for permission
  timeout/expiry/auto-deny: nothing. The only documented way pending permissions disappear
  without a reply is `location.reload`, which cancels them (docs-api.md). A permission `ask`
  therefore never expires on its own; a stale ask stays pending until replied to or the
  location reloads (docs-permissions.md; docs-api.md).
- No auto-deny, and no `OPENCODE_UNATTENDED` (or any unattended-mode env var). Searched
  config-schema.json, docs-config.md, docs-cli.md, docs-cli-commands.md, and releases for
  `UNATTENDED`: zero hits. What exists instead: docs state "Non-interactive clients must
  decide how to handle approval requests" (docs-permissions.md).
- No built-in cross-session "waiting" ticker or aggregated notification. Searched
  docs-cli-tui.md and both releases captures for waiting/idle status surfaces: only
  `session.active` (API) and per-session idle events (docs-api.md); whether the TUI shows a
  per-session "waiting for input" badge is UNVERIFIED.

What V2 DOES provide (all VERIFIED):

- Headless auto-approval: `opencode run --auto "..."` - "Auto-approve permissions that are
  not explicitly denied" (docs-cli-commands.md). This is a CLI flag for scripted runs, not a
  server-wide mode; explicit `deny` rules still apply by construction of the wording.
- State rebuild APIs: location-wide `GET /api/permission/request` (`permission.request.list`),
  session-scoped `session.permission.list/get/reply`, location-wide `form.list`, session
  `session.form.list/get/reply/cancel`, `session.active`, `session.list`, and in-plugin
  `ctx.permission.list/get/reply` and `ctx.session.wait` (docs-api.md;
  docs-build-plugins-server.md).
- Notification channels: Desktop question notifications with their own settings path -
  "independently configurable question notifications and sounds under Settings ->
  Notifications -> Questions" (github-releases.md); in-TUI `tui.showToast({body})`
  (docs-sdk.md).
- Native concurrency mechanism: worktrees. `ctx.worktree.create/list/refresh/remove` with
  pluggable strategies, `worktree.updated` events, `opencode run -w` / `--worktree=<name>`,
  Code Mode `worktree_create/list/remove`, and `session.move` into a worktree
  (docs-build-plugins-server.md; github-releases.md; docs-tools.md; docs-api.md).
- Worktrees have NO locking and NO dirty-file detection (VERIFIED negative): searched
  permissions, policies, config, API, plugin-server, and both releases captures for
  `lock`, `dirty`, `concurrent`. The only dirty-state handling is `force: false|true` on
  removal ("Set `force` to discard uncommitted changes" / a strategy may throw with
  `forceRequired: true`) (docs-tools.md; docs-build-plugins-server.md). Nothing prevents two
  sessions from writing the same worktree or racing a create/remove pair.

Minimal replacement and rough size: keep one small plugin (roughly 200-300 LOC, versus the
current 1728) built from (a) `event.subscribe({types: ["permission.asked",
"permission.replied", "form.created", "form.replied", "form.cancelled", "session.idle"]})`,
(b) boot-time rebuild from `permission.request.list` + `form.list` (replacing the current
disk-seeded ticker), (c) `ctx.storage` keys for the waiting map instead of
`.opencode/session/ticker.json`, (d) notifications via TUI toast / Desktop question
notifications rather than a hand-rolled PowerShell toast, and (e) a retained ~60 LOC watchdog
that calls `ctx.permission.reply({decision: "reject"})` after a threshold, because V2 will
never expire the ask itself. Note the reject semantics: one reject clears every pending
request of that session (docs-permissions.md), which the watchdog must treat as a
session-wide action.

---

## 7. TOOL DEFINITION AND ARTIFACTS

`ctx.tool.transform` (VERIFIED): register tools with a synchronous editor; `input` is JSON
Schema; `execute(input, context)` returns structured content (`{ content: ... }`), not a bare
string (docs-build-plugins-server.md; docs-build-plugins-migrate-v1.md). The editor supports
`namespace`, `add`, `update`, `remove`, `list`, `get`, and `reload`; later registrations
override earlier ones and models capture a stable tool snapshot per request
(docs-build-plugins-server.md). Structured output schemas are `Tool.Content`,
`Tool.TextContent`, `Tool.FileContent` (docs-build-plugins-server.md). Freeform input
(regex/lark) and Code Mode `codemode: true` are optional modes of the same definition
(docs-build-plugins-server.md).

Executor context (VERIFIED): `context.signal` is an AbortSignal for cooperative cancellation
("Pass it to cancellable work such as `fetch`"), `context.progress(...)` emits progress, and
`context.sessionID`, `context.agent`, `context.messageID`, `context.id` identify the caller
(docs-build-plugins-server.md; gh-tool-subagent.ts uses `context.sessionID` upstream).
Failures use `ToolFailure` / `Tool.Error` so the reason is model-visible
(gh-tool-subagent.ts; github-releases.md; docs-build-plugins-server.md).

`ctx.permission.assert` (VERIFIED): in-tool permission assertion taking `action`, `resources`,
`save` (patterns stored on "always"), `agent` (whose rules apply), `source` (attaches the
prompt to a tool call), and `metadata` (reaches prompts and evaluate hooks). It resolves when
allowed; a deny or a rejection with feedback fails with a `Tool.Error` the model sees
(docs-build-plugins-server.md).

Session-id helper: unnecessary (NATIVE). The same execution context carries `sessionID` and
`agent`, hooks carry `event.sessionID` (and `event.agent` where applicable), and permission
evaluation carries `sessionID`/`agent` (docs-build-plugins-server.md). The project's
25-line `.opencode/tools/get-my-session-id.ts` can be deleted rather than ported - this is the
one mechanism where V2 strictly supersedes the custom code.

Artifacts: tool content is structured, and OpenCode also has a first-class artifact surface
(`artifact.updated` event, artifact providers, `POST /api/experimental/artifacts/...`
(docs-api.md)) for files a run produces. Nothing in the archived corpus maps an external
"artifact" concept to plugin storage, so tool-content and artifact APIs are the only native
carriers.

---

## 8. WHAT REMAINS CUSTOM, AND WHAT IS UNVERIFIED

### Remains custom (no native equivalent in the archived record)

- Ticket-id scanning and OPEN resolution: no ticket domain anywhere - the `policies` action
  enum is closed (config-schema.json), the API surface has no ticket route (docs-api.md), and
  nothing in the plugin context reads a ledger (docs-build-plugins-server.md). Custom actions
  are possible as permission action strings (docs-permissions.md), but the scanning, ID
  parsing, and OPEN-status resolution logic stays in-project.
- The project's own gate ordering rules (capability mint -> ticket gate -> envelope ->
  routing -> verification-only markers, as encoded in `lib/*.ts`): V2 defines hook execution
  order only as plugin registration order (docs-build-plugins-server.md); cross-gate ordering
  is a project contract.
- The 4-tier fetch chain and its atomicity (npm registry JSON -> trafilatura -> curl -> crwl,
  temp-file + rename publication, agent-scoped execution guard). V2 native `webfetch` is one
  URL-to-markdown/text/html fetch with a `webfetch` permission and a 120 s timeout
  (docs-tools.md); it has no tiering, no registry-body mode, no destination policy, and no
  atomic rename. Custom tool visibility is now expressible as permission rules, which is the
  one part that gets simpler (docs-permissions.md; project code
  `.opencode/tools/fetch-source.ts` L15-L22).
- The handoff checksum contract (slot identity, `active.json` pointer, checksum validation):
  V2 gives storage and session metadata but no handoff primitive, no pointer semantics, and
  no integrity contract (docs-build-plugins-server.md; gh-plugin-host-core.ts).

### UNVERIFIED (with what would settle each)

- `Session.Info` / metadata read-back shape: the API reference lists `Session.Info` as an
  opaque `object` with no field table, while `session.create` accepts `metadata`,
  `session.update` sets it, and `session.metadata.updated` is emitted (docs-api.md;
  gh-plugin-host-core.ts). The exact read-back fields and merge semantics are UNVERIFIED.
- Durable event replay: NONE for the server stream - "Subscriptions are live-only, with no
  replay or automatic reconnection... a late native subscriber receives the current
  `server.connected` marker, not past business events" (docs-build-client.md); `/api/event`
  is "Volatile by contract... events during disconnection are missed" (docs-api.md). A
  per-session durable log does exist (`experimental.session.log` with `after` + `follow`),
  but its payload coverage excludes permission/form events (`Session.Event.Durable`,
  docs-api.md), so a journal built on it would silently miss exactly the transitions the
  ticker needs. Coverage beyond the documented union is UNVERIFIED.
- KV concurrency without CAS: absence of CAS is VERIFIED in gh-kv-service.ts; whether any
  other sanctioned serialization point exists (for example a SQLite transaction helper
  exposed to plugins) is UNVERIFIED (searched the plugin server reference and plugin host
  source).
- Whether `agent.transform` can mutate `permissions`: the editor exposes
  `list/get/default/update/remove` and the docs example updates only `description`
  (docs-build-plugins-server.md); `Agent.Info`'s field list is not expanded in docs-api.md.
  UNVERIFIED.
- Whether the TUI surfaces a per-session "waiting" status: searched docs-cli-tui.md and both
  releases captures for waiting/idle indicators; nothing found. UNVERIFIED.

---

## 9. DECISION IMPLICATIONS FOR A PORT

- Base every protected-path and capability-token rule on an `ask` permission rule plus
  `permission.hook("evaluate")`. A configured `deny` (or a `policies` `tool.use` deny) is
  final, skips the hook, and beats saved approvals, so it can never carry an exception path
  (docs-build-plugins-server.md; docs-policies.md; docs-permissions.md).
- Do not rebuild the session-id tool. `context.sessionID` / `context.agent` are already on
  every tool execution, and hooks carry `event.sessionID`; delete the helper instead of
  porting it (docs-build-plugins-server.md).
- Do not assume a permission ask ever expires. V2 has no timeout, no auto-deny, and no
  unattended env flag; keep a plugin-side watchdog that replies `reject` (and remember one
  reject clears all pending asks of that session) (docs-permissions.md; docs-api.md).
- Keep the ticket gate custom. No `policies` action covers tickets, no API route reads a
  ticket ledger; at most, assert a project-defined permission action string from
  `ctx.permission.assert` for the allow/ask side (config-schema.json; docs-api.md;
  docs-permissions.md).
- Treat the event stream as firehose, not history. Live-subscribe for journal rows, and if
  historical state is needed, rebuild it from list APIs (`permission.request.list`,
  `form.list`, `session.list`, `session.active`) plus the per-session durable log for the
  subset it covers (docs-api.md; docs-build-client.md).
- Expect to own atomicity while still moving state into `ctx.storage`: it is durable, JSON,
  prefix-scannable, and shared across sessions of that plugin (better than hand-managed files
  under `.opencode/session/`), but it is last-write-wins with no CAS or lock, so handoff slot
  claims, journal sequence counters, and capability issuance keep the project's existing
  file-lock/reservation approach and a version field makes lost updates detectable
  (docs-build-plugins-server.md; gh-plugin-host-core.ts; gh-kv-service.ts).
- Port hook consumers by mapping, not by renaming: `chat.message` -> `prompt`,
  `chat.params`/system/messages transforms -> `context`, `permission.ask` -> `evaluate`,
  `shell.env` -> `shell.create.before`, `event` -> `ctx.event.subscribe`; plan a separate
  design for `experimental.compaction.autocontinue`, which has no V2 successor
  (docs-build-plugins-migrate-v1.md).
- Use worktrees as the concurrency primitive and accept that they do not serialize anything:
  no lock, no dirty check beyond `force` on removal, so cross-session file discipline stays a
  project concern (docs-build-plugins-server.md; docs-tools.md).

---

## 10. UNVERIFIED GAPS AND HOW TO CLOSE THEM

One concrete probe per gap, runnable as a pre-port spike:

1. `Session.Info` / metadata read-back shape. Probe: `opencode api session.create --data
   '{"title":"probe","metadata":{"k":"v"}}'` then `opencode api GET /api/session/<id>` (and
   `session.update` with metadata) and inspect the returned fields; compare with
   `session.metadata.updated` payloads (docs-cli-commands.md shows the `opencode api` form;
   docs-api.md the routes).
2. Durable event replay / journal coverage. Probe: `GET
   /api/experimental/session/<id>/log?after=0&follow=false` for a session that has seen a
   permission ask and a question, and diff the returned types against
   `Session.Event.Durable`; separately reconnect to `/api/event` after a gap to confirm the
   documented loss (docs-api.md; docs-build-client.md).
3. KV concurrency without CAS. Probe: a 40-line scratch plugin that fires two
   `ctx.storage.set("probe", ...)` calls concurrently from two sessions (or two plugin
   instances with the same id) and reads back which value won, plus a grep of the installed
   `@opencode/plugin` typings for any CAS/lock method not shown in the archived contract
   (gh-plugin-storage-type.ts; gh-kv-service.ts).
4. Whether `agent.transform` can mutate permissions. Probe: in a scratch plugin run
   `ctx.agent.transform(e => e.update("probe", a => { a.permissions = [{action:"edit",
   resource:"*", effect:"deny"}] }))`, then `ctx.agent.get({agentID:"probe"})` and launch a
   subagent session to see whether the rule is enforced and where it sits in order
   (docs-build-plugins-server.md; docs-permissions.md ordering rules).
5. TUI per-session "waiting" status. Probe: start two sessions, leave a `permission.asked`
   pending in one, and inspect the session list view plus `GET /api/session/<id>` status
   fields and any `SessionStatusUpdated` payload for a waiting/waiting-for-input marker
   (docs-api.md; docs-cli-tui.md).
6. V1 event spellings (question.* etc.). Probe: grep the installed V1 package for its event
   union - `rg -n "question\\.(asked|replied|rejected)|session\\.(status|error)" node_modules/@opencode-ai`
   - because the manifest excluded the V1-era event list from this archive
   (`.source-urls.txt`).
7. Permission-ask timeout existence at runtime. Probe: leave a permission pending and poll
   `GET /api/permission/request` for 30 minutes while watching the server log for expiry
   wording; expected result is no change, matching the documented absence
   (docs-api.md; docs-permissions.md).
8. Worktree locking. Probe: two concurrent `POST /api/worktree` creates with the same
   `name`, then a create/remove pair racing a session writing inside the worktree; expected
   result is last-writer-wins, confirming no lock (docs-api.md;
   docs-build-plugins-server.md).
9. `execute.before` rejection visibility to the model. Probe: scratch plugin that rejects the
   `read` tool with `Tool.Error` once, then inspect the assistant transcript for the reason
   string and the next model turn (github-releases.md; docs-build-plugins-server.md).

---

## Works Cited

All entries were archived in Phase A on 13 Nov. 2026 under
`knowledge/res-261113-hi88-opencode-v2-native-capabilities/sources/`. Access date for every
web source: 13 Nov. 2026. Release captures carry version headers but no publish dates in the
archived copy.

- OpenCode. "Permissions." opencode.ai/docs/permissions. Accessed 13 Nov. 2026. Archived as
  docs-permissions.md.
- OpenCode. "Policies." opencode.ai/docs/policies/. Accessed 13 Nov. 2026. Archived as
  docs-policies.md.
- OpenCode. "Config." opencode.ai/docs/config. Accessed 13 Nov. 2026. Archived as
  docs-config.md.
- OpenCode. "Config schema." opencode.ai/config.json. Accessed 13 Nov. 2026. Archived as
  config-schema.json.
- OpenCode. "Commands." opencode.ai/docs/cli/commands/. Accessed 13 Nov. 2026. Archived as
  docs-cli-commands.md.
- OpenCode. "API." opencode.ai/docs/api. Accessed 13 Nov. 2026. Archived as docs-api.md.
- OpenCode. "Server." opencode.ai/docs/build/plugins/server. Accessed 13 Nov. 2026. Archived
  as docs-build-plugins-server.md.
- OpenCode. "Migrate plugins from V1." opencode.ai/docs/build/plugins/migrate-v1/. Accessed
  13 Nov. 2026. Archived as docs-build-plugins-migrate-v1.md.
- OpenCode. "Overview (plugins)." opencode.ai/docs/build/plugins/. Accessed 13 Nov. 2026.
  Archived as docs-build-plugins.md.
- OpenCode. "Migrate from V1." opencode.ai/docs/migrate-v1/. Accessed 13 Nov. 2026. Archived
  as docs-migrate-v1.md.
- OpenCode. "Tools." opencode.ai/docs/tools/. Accessed 13 Nov. 2026. Archived as
  docs-tools.md.
- OpenCode. "JavaScript (client)." opencode.ai/docs/build/client. Accessed 13 Nov. 2026.
  Archived as docs-build-client.md.
- OpenCode. "SDK." opencode.ai/docs/sdk. Accessed 13 Nov. 2026. Archived as docs-sdk.md.
- OpenCode. "Terminal UI." opencode.ai/docs/cli/tui/. Accessed 13 Nov. 2026. Archived as
  docs-cli-tui.md.
- OpenCode. "Intro (CLI)." opencode.ai/docs/cli. Accessed 13 Nov. 2026. Archived as
  docs-cli.md.
- sst/opencode. "Releases" (v2.3.0 through v2.2.1 stream). github.com/sst/opencode/releases.
  Accessed 13 Nov. 2026. Archived as github-releases.md.
- sst/opencode. "Releases, page 2" (v2.2.0 and v1.19.x stream).
  github.com/sst/opencode/releases?page=2. Accessed 13 Nov. 2026. Archived as
  github-releases-page2.md.
- anomalyco/opencode contributors. "packages/plugin/src/storage.ts (dev branch)."
  raw.githubusercontent.com/anomalyco/opencode/dev/packages/plugin/src/storage.ts. Accessed
  13 Nov. 2026. Archived as gh-plugin-storage-type.ts.
- anomalyco/opencode contributors. "packages/core/src/kv.ts (dev branch)."
  raw.githubusercontent.com/anomalyco/opencode/dev/packages/core/src/kv.ts. Accessed 13 Nov.
  2026. Archived as gh-kv-service.ts.
- anomalyco/opencode contributors. "packages/core/src/plugin/host.ts (dev branch)."
  raw.githubusercontent.com/anomalyco/opencode/dev/packages/core/src/plugin/host.ts. Accessed
  13 Nov. 2026. Archived as gh-plugin-host-core.ts.
- anomalyco/opencode contributors. "packages/core/src/tool/plugin/subagent.ts (dev branch)."
  raw.githubusercontent.com/anomalyco/opencode/dev/packages/core/src/tool/plugin/subagent.ts.
  Accessed 13 Nov. 2026. Archived as gh-tool-subagent.ts.

---

## Unarchived and Excluded Sources

These sources are listed here only, with the manifest's stated reason, and are never cited in
the body (`.source-urls.txt`).

NOT ARCHIVED (failed fetches):

- docs-cli-reference.md - content is a 21-byte "Not found" 404 placeholder; superseded by
  /docs/cli/commands/ which IS archived (docs-cli-commands.md).
- gh-plugin-context-v2-promise.ts - 404, path moved (live tree shows
  packages/plugin/src/promise/); file on disk is a 26-byte placeholder.
- gh-plugin-context-v2-promise.md - GitHub 404 HTML page; superseded by
  gh-plugin-storage-type.ts and gh-plugin-host-core.ts, which carry the storage contract.
- gh-tool-task.ts - 404, packages/opencode was removed; superseded by gh-tool-subagent.ts at
  packages/core/src/tool/plugin/subagent.ts; file on disk is a 26-byte placeholder.

EXCLUDED:

- https://github.com/anomalyco/opencode/releases - sst/opencode releases archived instead
  (both point at the same changelog stream).
- V1-era event list (question.asked and similar from old V1 docs) - not served on the current
  V2 docs site; V1 event names are therefore UNVERIFIED from archived sources.
- Any third-party blog/tutorial about opencode permissions - primary sources (docs, schema,
  releases) answer every sub-question.
- https://opencode.ai/docs/build/plugins/effect/ - Effect entrypoint variant; the Promise docs
  already answer all hook and storage questions.
- https://api.github.com/repos/anomalyco/opencode/... tree/contents listings - used for live
  path discovery only; ephemeral JSON, not archived. Every substantive file they pointed at
  was archived via raw fetch instead.

Note: gh-plugin-host-promise.ts was archived but rated RELEVANCE=Low and was not needed for
any claim in this conspect, so it is not cited.
