# OpenCode V1 to V2 Migration Conspect

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 32
phase-a-failures: 10
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to memory-manager
-->

Scope: a pure-synthesis conspect of what an OpenCode V1 -> V2 migration
requires, built only from the archived sources under
`knowledge/res-261112-1ima-opencode-version-migration/sources/`. Every claim
carries an in-text citation keyed to the archived filename. Source precedence
when sources disagree: official opencode.ai docs > official changelog > GitHub
releases page > npm registry metadata. Nothing below was fetched from the
network by this lane.

## 1. Version landscape

- Newest OpenCode release in the archive: **v2.2.7, released 2026-11-10**
  (changelog header `v2.2.7 - 2026-11-10`; GitHub Release `published_at`
  `2026-11-10T10:37:15Z`) (raw.githubusercontent.com, "Changelog",
  opencode-changelog-root.md) (api.github.com, "Releases", github-api-releases.json).
  The releases page also lists `process-daemon v0.5.2` (opencode-pty, published
  2026-11-11), which is a separate package artifact, not an OpenCode version
  (github.com, "Releases", github-releases-page.md)
  (api.github.com, "Releases", github-api-releases.json).
- npm dist-tag `latest` still resolves to the **1.x line: opencode-ai@1.19.5**
  (registry.npmjs.org, "opencode-ai latest", npm-opencode-ai-latest.json).
  This is intentional: v1.19.2 states that OpenCode 1 update checks use only
  the npm `latest` version so 1.x installs are never offered a 2.x build, the
  install script refuses to install 2.x, and Homebrew Core installs (which now
  track OpenCode 2) are skipped for 1.x updates (github.com, "Releases page 2",
  github-releases-page2.md).
- V2 ships through other channels: the **curl installer** (the V2 curl
  installer replaces the V1 binary) (opencode.ai, "Migrate from V1",
  docs-migrate-v1.md), **WinGet** (`winget install --id Anomaly.OpenCode -e`,
  official packages added in v2.0.28) (raw.githubusercontent.com, "Changelog",
  opencode-changelog-root.md), and **Homebrew Core**, which tracks OpenCode 2
  per the v1.19.2 notes (github.com, "Releases page 2", github-releases-page2.md).
- Cross-major upgrade is explicit only: v1.19.0 added `opencode upgrade --major`
  and v1.19.0 changed `/update` so updates are no longer installed automatically;
  v1.19.2 notes the "2.0 offer in /update" as the other explicit path
  (github.com, "Releases page 2", github-releases-page2.md).
- Consequence for automation: **an unattended `npm install -g opencode-ai` /
  `pnpm update` will never cross the major boundary** (npm `latest` is 1.19.5),
  and the 1.x install script actively refuses 2.x. A V2 upgrade requires the
  curl installer, WinGet, Homebrew, or `opencode upgrade --major` from a 1.x
  install (registry.npmjs.org, "opencode-ai latest", npm-opencode-ai-latest.json)
  (github.com, "Releases page 2", github-releases-page2.md)
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).

### 1.1 Release table: v1.18.0 -> newest

Dates come from the GitHub Releases API `published_at` values where Release
objects exist (api.github.com, "Releases", github-api-releases.json), from the
changelog for v2.0.26+ (raw.githubusercontent.com, "Changelog",
opencode-changelog-root.md), from tag-commit dates for v2.0.0 / v2.0.25 / v2.1.1
(api.github.com, "Commit v2.0.0", github-commit-v2.0.0.json)
(api.github.com, "Commit v2.0.25", github-commit-v2.0.25.json)
(api.github.com, "Commit v2.1.1", github-commit-v2.1.1.json), and from the
release-page scrapes for v1.18.0-v1.18.4 where no Release object exists
(github.com, "Releases page 6", github-releases-page6.md). A `-` in the
headline column means the archived release notes contain no "Breaking changes"
section for that version (verified across github-releases-page2.md through
github-releases-page6.md and the changelog). Rows the archive cannot date are
marked **UNVERIFIED**; no date was invented.

| Version | Date | Headline breaking change |
|---|---|---|
| v1.18.0 | 2026-07-14 (*) | - (Desktop v2 layout migration completed; not a breaking change) |
| v1.18.1 | 2026-07-14 (*) | - |
| v1.18.2 | 2026-07-15 (*) | - |
| v1.18.3 | 2026-07-16 (*) | - |
| v1.18.4 | 2026-07-20 (*) | - |
| v1.18.5 | 2026-07-24 | - |
| v1.18.6 | 2026-07-27 | - |
| v1.18.7 | 2026-07-27 | - |
| v1.18.8 | 2026-07-28 | - |
| v1.18.9 | 2026-07-28 | - |
| v1.18.10 | 2026-07-30 | - |
| v1.18.11 | 2026-08-01 | - |
| v1.18.12 | 2026-08-04 | - |
| v1.18.13 | 2026-08-04 | - |
| v1.18.14 | 2026-08-05 | - |
| v1.18.15 | 2026-08-07 | - |
| v1.18.16 | 2026-08-10 | - |
| v1.18.17 | 2026-08-12 | - |
| v1.18.18 | 2026-08-13 | - |
| v1.18.19 | 2026-08-20 | - |
| v1.18.20 | 2026-08-21 | - |
| v1.18.21 | 2026-08-21 | - |
| v1.18.22 | 2026-08-24 | - |
| v1.18.23 | 2026-08-25 | - |
| v1.18.24 | 2026-08-28 | - |
| v1.18.25 | 2026-08-28 | - |
| v1.18.26 | 2026-09-01 | - |
| v1.18.27 | 2026-09-02 | - |
| v1.18.28 | 2026-09-04 | - |
| v1.18.29 | 2026-09-04 | - (not breaking; first V1 release supporting object entrypoints for plugins that dual-expose V1 + V2) (opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md) |
| v1.18.30 | 2026-09-09 | - |
| v1.18.31 | 2026-09-14 | - |
| v1.18.32 | 2026-09-21 | - |
| v1.18.33 | 2026-09-28 | - |
| v1.18.34 | 2026-09-30 | - |
| v1.18.35 | 2026-10-06 | - |
| v1.19.0 | 2026-10-11 | Upgrade flow change: `opencode upgrade --major` added; `/update` no longer auto-installs updates |
| v1.19.1 | 2026-10-15 | Session sharing discontinued; existing share links and session-sharing commands no longer available; import from share URLs unsupported |
| v1.19.2 | 2026-10-16 | 1.x installs pinned to npm `latest` (never offered 2.x); install script refuses 2.x; Homebrew Core installs skipped for 1.x updates |
| v1.19.3 | 2026-10-16 | - |
| v1.19.4 | 2026-10-22 | - |
| v1.19.5 | 2026-10-28 | - (release notes body empty in archive; this is the npm `latest` version) |
| v2.0.0 | 2026-09-11 (tag commit date) | The three intentional V2 breaking changes: new plugin API; new server API and clients; layered `tui.json(c)` replaced by one global `cli.json` (auto-migrated) (opencode.ai, "Migrate from V1", docs-migrate-v1.md) |
| v2.0.1 - v2.0.24 | **UNVERIFIED** (24 versions) | No archived release notes: no GitHub Release objects exist for the v2.0.x tags, and the official changelog starts at v2.0.26 (api.github.com, "Releases", github-api-releases.json) (raw.githubusercontent.com, "Changelog", opencode-changelog-root.md) |
| v2.0.25 | 2026-10-08 (tag commit date) | Notes not in archive |
| v2.0.26 | 2026-10-08 | - |
| v2.0.27 | 2026-10-12 | - |
| v2.0.28 | 2026-10-13 | - (official WinGet packages added; not breaking) |
| v2.0.29 | 2026-10-14 | - |
| v2.0.30 | 2026-10-15 | Retired session-sharing backend and the unavailable `/share` command removed |
| v2.0.31 | **UNVERIFIED** | Tag exists in the tag list, but this version is absent from the changelog at both the dev branch and the v2.1.0 snapshot; no Release object; date and notes unknown (api.github.com, "Tags", github-api-tags-page1.json) (raw.githubusercontent.com, "Changelog", opencode-changelog-root.md) |
| v2.0.32 | 2026-10-16 | - |
| v2.1.0 | 2026-10-20 | Public SDK / HTTP / plugin contract break: replay data renamed to `native`; tool `providerState`/`providerResultState` collapse into `tool.native`; `Credential.Key.configuration` removed (use `metadata`); summary compaction `recent` replaced by `metadata.keepID`; `providerContext` replaced by `native.messages`; `session.compacted` event removed |
| v2.1.1 | 2026-10-20 (tag commit date) | No notes in archive (changelog skips v2.1.1) |
| v2.1.2 | 2026-10-21 | - |
| v2.1.3 | 2026-10-22 | - (not breaking; legacy `apply_patch` stored permissions auto-migrate to `edit`) |
| v2.1.4 | 2026-10-23 | - |
| v2.2.0 | 2026-10-27 | `@opencode/ai` root becomes the Promise API (`@opencode/ai/promise` removed, wildcard subpath replaced); OpenCode GitHub Action no longer published; TUI plugins require OpenTUI 0.7 |
| v2.2.1 | 2026-10-29 | `@opencode/ai`: fal, Black Forest Labs, Replicate, Stability providers removed; five legacy provider entry points removed; `configure()` input type renamed `Config` |
| v2.2.2 | 2026-10-29 | - |
| v2.2.3 | 2026-10-30 | TUI plugins require OpenTUI 0.8; managed policy `integration.use` narrowed to integrations only (new `mcp.use`, `skill.use`, `plugin.use`; old `mcp:`/`skill:`/`plugin:` resource prefixes auto-converted) |
| v2.2.4 | 2026-10-30 | - |
| v2.2.5 | 2026-10-30 | - (compat shim: calls to a tool named `bash` now run as `shell` with the same permissions) |
| v2.2.6 | 2026-11-06 | - |
| v2.2.7 | 2026-11-10 | `@opencode/ai`: `ImageResponse.image` removed (read `response.images[0]`); SDK: several endpoints (`agent.list`, `integration.list`, `usage.limits`, `vcs.init`, `rpc.call`, `artifact.*`) no longer wait up to 5 seconds for plugins to load |

(*) Year note: the GitHub releases-page scrape for v1.18.0-v1.18.4 shows day
and time only ("14 Jul 20:29" etc.). The year 2026 is cross-anchored, not
guessed: the same scrape format on page 5 gives v1.18.5 as "24 Jul 22:18", and
the Releases API records v1.18.5 `published_at` as `2026-07-24T22:18:16Z`
(github.com, "Releases page 5", github-releases-page5.md)
(github.com, "Releases page 6", github-releases-page6.md)
(api.github.com, "Releases", github-api-releases.json).

### 1.2 Source conflicts and precedence

- "Newest" depends on the source class: npm metadata says `latest` =
  1.19.5 (registry.npmjs.org, "opencode-ai latest", npm-opencode-ai-latest.json)
  while the changelog and releases page say newest = v2.2.7
  (raw.githubusercontent.com, "Changelog", opencode-changelog-root.md)
  (github.com, "Releases", github-releases-page.md). Not a data conflict: the
  v1.19.2 notes explain the 1.x pin is deliberate. Authoritative statements:
  npm metadata for what the npm dist-tag resolves to; official docs + changelog
  for the V2 version line.
- The releases page scrape and changelog disagree on format, not content: the
  releases-page scrapes for pages 1-2 carry no dates (JS-rendered page), so all
  v2.2.x and v1.19.x dates are taken from the changelog / Releases API instead
  (changelog and API outrank the releases page in precedence anyway)
  (github.com, "Releases page 1", github-releases-page.md)
  (api.github.com, "Releases", github-api-releases.json).
- Repo identity: manifest URLs target `github.com/sst/opencode/releases`, but
  the archived page-6 scrape renders as "Releases . anomalyco/opencode", and
  changelog URLs span both `sst/opencode` (dev branch) and `anomalyco/opencode`
  (v2.1.0 tag). Same project, moved org; the opencode.ai docs remain the primary
  authority (github.com, "Releases page 6", github-releases-page6.md).
- The v2.0.0 release-tag page archived as low-reliability contains no usable
  release notes (JS shell), so the v2.0.0 breaking-change row is sourced from
  the official migration guide instead (github.com, "Release tag v2.0.0",
  github-release-tag-v2.0.0.md) (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
  The v2.1.0 release-tag page yielded only the tag date (2026-10-20), which
  agrees with the changelog (github.com, "Release tag v2.1.0",
  github-release-tag-v2.1.0.md).

## 2. Plugin API migration map

V1 plugins are one function returning an object of tools and hooks; V2 plugins
default-export `Plugin.define({ id, setup(ctx) })`. Plugin implementation code
must be ported (config alone can be normalized automatically), and every V2
plugin needs a stable `id` (storage, status, and diagnostics are scoped to it)
(opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md).
The package import changes from `@opencode-ai/plugin` to `@opencode/plugin`
(opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md).

### 2.1 Context / registration surfaces

| V1 surface | V2 replacement |
|---|---|
| plugin function args `{ directory, project, client }` | `ctx.location.directory`, `ctx.location.project`, domain methods (`ctx.session`, `ctx.permission`, `ctx.agent`, ...) |
| plugin options argument | `ctx.options` |
| returned `dispose()` hook | cleanup function returned by `setup` |
| returned `event` hook | `ctx.event.subscribe()` (async iteration over the public server event stream; abort from the setup cleanup) |
| returned config / model / tool changes | a domain `transform(...)` editor (`ctx.agent`, `ctx.provider`, `ctx.model`, `ctx.command`, `ctx.integration`, `ctx.mcp`, `ctx.reference`, `ctx.skill`, `ctx.tool`, `ctx.vcs`, `ctx.websearch`, `ctx.worktree`) |
| `$` Bun shell helper | **NO V2 equivalent** - import and manage the process API your plugin uses |
| `tool()` helper building a `tool` map | `ctx.tool.transform((editor) => editor.add({ name, description, input: <JSON Schema>, execute }))`; execution returns structured content |
| registration lifetime | registrations live for the plugin lifetime and are disposed on unload; keep the returned registration only to call `registration.dispose()` early |

(opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md)
(opencode.ai, "Server", docs-build-plugins-server.md)

### 2.2 Hook map

V1 returns hooks by string key with separate `input`/`output` objects; V2
registers each hook on the domain that owns the operation, and the callback
receives one mutable event (opencode.ai, "Migrate plugins from V1",
docs-build-plugins-migrate-v1.md).

| V1 hook | V2 API |
|---|---|
| `event` | `ctx.event.subscribe()` |
| `dispose` | cleanup function returned by `setup` |
| `config` | transforms on the affected domains (no single mutable global config object) |
| `tool` map | `ctx.tool.transform(...)` |
| `auth` | `ctx.integration.transform(...)` and integration APIs |
| `provider` | `ctx.provider.transform(...)` and `ctx.model.transform(...)` |
| `chat.message` | `ctx.session.hook("prompt", ...)` |
| `chat.params` | `ctx.session.hook("context", ...)` |
| `chat.headers` | `ctx.session.hook("model.request", ...)` or `"http.request"` |
| `permission.ask` | `ctx.permission.hook("evaluate", ...)` |
| `command.execute.before` | **NO one-to-one global hook** - command transforms (`ctx.command.transform`) when the plugin owns that command, else the prompt hook |
| `tool.execute.before` | `ctx.tool.hook("execute.before", ...)` |
| `tool.execute.after` | `ctx.tool.hook("execute.after", ...)` |
| `shell.env` | `ctx.shell.hook("create.before", ...)` |
| `tool.definition` | `ctx.tool.transform(...)` |
| `experimental.chat.system.transform` | `ctx.session.hook("context", ...)` editing `event.system` |
| `experimental.chat.messages.transform` | `ctx.session.hook("context", ...)` editing `event.messages` |
| `experimental.session.compacting` | `ctx.session.hook("compaction", ...)` |

(opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md)

These are migration destinations, not always exact renames: the V2 `prompt`
hook runs before durable prompt admission while `context` runs immediately
before an agent model request; register `context`, `compaction`, `generate`,
and `title` separately if a transformation must apply to every model request
kind (opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md).

### 2.3 Surfaces with NO V2 equivalent

- `$` Bun shell helper - no direct replacement (opencode.ai, "Migrate plugins
  from V1", docs-build-plugins-migrate-v1.md).
- `experimental.compaction.autocontinue`, `experimental.provider.small_model`,
  `experimental.text.complete` - no direct V2 hook; re-evaluate the plugin
  against the V2 session, provider, model, and event APIs rather than
  preserving an internal lifecycle assumption (opencode.ai, "Migrate plugins
  from V1", docs-build-plugins-migrate-v1.md).
- `command.execute.before` as a global hook - no one-to-one replacement (see
  table) (opencode.ai, "Migrate plugins from V1", docs-build-plugins-migrate-v1.md).
- One mutable global config object - does not exist in V2; config changes are
  registered per owning domain (opencode.ai, "Migrate plugins from V1",
  docs-build-plugins-migrate-v1.md).
- Separate `input`/`output` hook arguments - replaced by a single mutable
  event object (shape change, not a rename) (opencode.ai, "Migrate plugins
  from V1", docs-build-plugins-migrate-v1.md).
- V1 object entrypoints (`server()` returning the hook map) are supported in
  OpenCode 1.18.29+ only so one package can expose both APIs side by side; the
  APIs stay separate and hooks are not translated automatically - remove the
  V1 implementation after the support window ends (opencode.ai, "Migrate
  plugins from V1", docs-build-plugins-migrate-v1.md).

### 2.4 Config-side plugin registration

`plugin` -> `plugins`; the package-and-options tuple becomes an object
(`{ "package": "./plugin/local", "options": { ... } }`). Local plugin paths
must be directories (a configured `./plugin/local.ts` file is skipped with a
log warning; move to `./plugin/local/index.ts`). Discovery covers both
`.opencode/plugin/` and `.opencode/plugins/`; use `.opencode/plugins/` for V2
files. Plugin arrays merge lowest-to-highest precedence instead of replacing
one another; `-id` disables, `*` matches all, a later ID re-enables
(opencode.ai, "Migrate from V1", docs-migrate-v1.md)
(opencode.ai, "Plugins", docs-plugins.md).

## 3. Config schema migration map

V2 reads the same config locations as V1 and normalizes supported V1 and native
V2 fields in memory without rewriting the source file; the V1 config format
remains supported (opencode.ai, "Migrate from V1", docs-migrate-v1.md). The
live JSON schema marks the V1 keys `permission`, `agent`, `provider`, `plugin`
and others with `"deprecated": true` (opencode.ai, "config.json schema",
config-schema.json).

### 3.1 Top-level renames

| V1 | V2 |
|---|---|
| `permission` (object grouped by tool) | `permissions` - one ordered array of `{ action, resource, effect }` |
| permission action `bash` | `shell` |
| permission action `task` | `subagent` |
| permission actions `write`, `patch` | `edit` (the `edit` action resource covers `edit`, `write`, and `patch` targets) |
| `agent` (and deprecated `mode` map) | `agents` (old `mode` entries become primary agents) |
| agent key `prompt` | `system` |
| agent key `disable` | `disabled` |
| agent key `maxSteps` | `steps` |
| agent key `permission` | `permissions` |
| separate `variant` on agent/model/command | joined onto the model reference: `provider/model#variant` |
| `plugin` | `plugins` (tuple -> object form) |
| `provider` | `providers` |
| `mcp.<name>` servers map | `mcp.servers.<name>` |
| MCP `enabled: true/false` | inverse `disabled: false/true` |
| MCP single `timeout` number | `timeout: { catalog, execution }` (V1 `experimental.mcp_timeout` seeds both defaults) |
| MCP remote OAuth camelCase (`clientId`, `clientSecret`, `callbackPort`, `redirectUri`) | snake_case (`client_id`, `client_secret`, `callback_port`, `redirect_uri`) |
| `snapshot` | `snapshots` (boolean unchanged) |
| `attachment` object | `media` (nested image keys unchanged) |
| `compaction.preserve_recent_tokens` / `reserved` | `compaction.keep.tokens` / `compaction.buffer` (buffer also accepts a window percentage) |
| `compaction.tail_turns`, `compaction.prune` | **no V2 equivalent** - ignored with a warning |
| `skills.paths` + `skills.urls` | one ordered `skills` array |
| `command` | `commands`; `subtask` -> `subagent` (legacy `subtask` still accepted) |
| `reference` | `references` |
| provider `npm` | `package` (AI SDK packages get the `aisdk:` prefix) |
| provider `api` | `settings.baseURL` |
| provider `options` | split by request role into `settings`, `headers`, `body`; `options.setCacheKey` -> `compatibility.supportsPromptCacheKey` |
| model `id` | `modelID` |
| model `tool_call` / `modalities` | `capabilities.tools` / `capabilities.input` / `capabilities.output` |
| model `status: "deprecated"` | `disabled: true` |
| model cache costs `cache_read` / `cache_write` | `cache.read` / `cache.write` |
| V1 `variants` object | V2 `variants` array with `id` on each entry |
| provider IDs `azure-cognitive-services`, `google-vertex-anthropic` | canonical `azure`, `google-vertex` (for unambiguous V1 fields; the shared top-level `model` keeps its exact provider ID until manually updated) |

(opencode.ai, "Migrate from V1", docs-migrate-v1.md)
(opencode.ai, "Permissions", docs-permissions.md)
(opencode.ai, "Agents", docs-agents.md)
(opencode.ai, "Config", docs-config.md)

Agent `request.body` is kept but not sent to the model, so V1 `temperature`,
`top_p`, and `options` on an agent have no effect; set them on a model variant
instead (opencode.ai, "Migrate from V1", docs-migrate-v1.md).

### 3.2 The mixed-format silent-ignore rule

- Top-level mixing is allowed: supported V1 and native V2 fields may coexist
  at the top level; when both forms set the same canonical value, a valid
  native V2 value takes precedence regardless of JSON key order
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
- Nested mixing is intentionally bounded: V1 and V2 members are recognized
  within `mcp`, `compaction`, and `experimental`, but OpenCode does not
  recursively infer formats inside individual agents, providers, commands, or
  models - keep each of those nested entries entirely in one format
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
- Supported V1 syntax stays quiet by itself; malformed values, unsupported
  legacy fields, and conflicting V1/V2 values only produce warnings while
  unrelated valid settings continue to load - nothing hard-fails
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
- File-based agent frontmatter is read as exactly one format per file: a file
  using any of `permissions`, `request`, `system`, `disabled` is read as V2 and
  its V1 fields (`name`, `tools`, `permission`, `temperature`) are ignored with
  a log warning; convert a file all at once rather than mixing
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).

## 4. Permission semantics (highest consequence)

This is the section to act on first for any project that relies on
undeclared-allow behavior.

### 4.1 The base allow policy

Every agent, including custom agents, starts with this ordered base policy
(opencode.ai, "Permissions", docs-permissions.md):

```
[
  { "action": "*", "resource": "*", "effect": "allow" },
  { "action": "read", "resource": "*.env", "effect": "ask" },
  { "action": "read", "resource": "*.env.*", "effect": "ask" },
  { "action": "read", "resource": "*.env.example", "effect": "allow" }
]
```

Shipped agents append their own policies on top (for example `plan` denies
edits except files under `~/.opencode/plan`; `explore` denies everything except
shell/reads/glob/grep/webfetch/websearch/external_directory; `title` and
`summary` deny all actions) (opencode.ai, "Permissions", docs-permissions.md).
There is also no default rule asking for `external_directory`, so reads and
edits outside the location and worktree proceed without a prompt unless you
add an `external_directory` `ask`/`deny` rule (opencode.ai, "Permissions",
docs-permissions.md).

### 4.2 No-match fallback is `ask`, not `allow`

Rules combine in order and the **last matching rule wins**: lower-priority
configuration loads first, global rules are appended next, agent rules are
appended last. If no rule matches, OpenCode uses `ask` (opencode.ai,
"Permissions", docs-permissions.md). Operations that touch several resources
resolve as: any `deny` denies the operation; otherwise any `ask` asks;
otherwise the operation is allowed (opencode.ai, "Permissions",
docs-permissions.md). Saved "Allow always" approvals become durable,
project-scoped `allow` rules that never override a configured `deny`, and a
managed `policies` entry can hard-deny any check after rules and saved
approvals run (opencode.ai, "Permissions", docs-permissions.md).

Interaction to keep in mind: because the base chain contains
`action: "*", resource: "*", effect: "allow"` as its first (lowest-priority)
rule, a check normally resolves by last match against whatever custom rules
survive; when custom rules vanish, the surviving last match is frequently the
base allow - which is exactly the undeclared-allow behavior. Where nothing
matches at all, the documented fallback is `ask`, so workflows degrade to
prompting rather than to silent allow (opencode.ai, "Permissions",
docs-permissions.md).

### 4.3 Why a half-migrated config silently loses allow (and deny) rules

State the risk plainly: **a half-migrated permission config fails open for
restrictions and fail-to-prompt or fail-closed for allows, with warnings at
most and no hard error.** The mechanisms, all documented:

1. Precedence shadowing. If a scope carries a V1 `permission` object and any
   valid native `permissions` array is added at that same scope, the native V2
   value takes precedence and the V1 block stops applying - every allow, ask,
   or deny rule that lived only in the V1 block is dropped in one edit while
   the file still loads cleanly (opencode.ai, "Migrate from V1",
   docs-migrate-v1.md).
2. Dead action names. V2 matching is whole-value wildcard matching, and the
   actions were renamed (`bash` -> `shell`, `task` -> `subagent`, `write`/
   `patch` -> `edit`). A native `permissions` rule written with a V1 action
   name never matches the corresponding V2 operation, so it silently does
   nothing; the check then falls through to the base allow (undeclared allow)
   or to an agent policy that appends later (opencode.ai, "Migrate from V1",
   docs-migrate-v1.md) (opencode.ai, "Permissions", docs-permissions.md).
3. Warnings instead of errors. Malformed values, unsupported legacy fields,
   and conflicting V1/V2 values produce warnings while unrelated valid
   settings continue to load; agent frontmatter mixing ignores the V1 fields
   with only a log warning (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
4. Consequence both directions. Lost deny/ask rules (for example a V1
   `bash`-scoped `deny`, or `tools: { websearch: false }` that never became a
   `websearch` deny rule) turn into base-allow access - a silent privilege
   grant. Lost allow rules leave later agent policies (which are appended
   last) as the effective last match, blocking or prompting operations that
   used to proceed (opencode.ai, "Permissions", docs-permissions.md)
   (opencode.ai, "Migrate from V1", docs-migrate-v1.md).

Required verification after any permission edit: exercise shell, edit, and
subagent flows under each affected agent, confirm the intended rules appear
after the base policy in effective order, and treat any config warning
emitted at load time as a migration failure, not noise (opencode.ai,
"Permissions", docs-permissions.md) (opencode.ai, "Migrate from V1",
docs-migrate-v1.md).

## 5. Removals table

| Removed surface | Lands in | Replacement / note |
|---|---|---|
| V1 plugin API (plugin functions returning `{ hooks, tools }`) | v2.0.0 | `Plugin.define({ id, setup(ctx) })` from `@opencode/plugin`; V1 plugin implementations do not run in V2 |
| V1 server API and V1 clients | v2.0.0 | `@opencode/client` against the revised HTTP API; `OPENCODE_PASSWORD` sets the password, username is always `opencode`, `OPENCODE_SERVER_USERNAME` removed |
| Layered `tui.json(c)` client config | v2.0.0 | one global `~/.config/opencode/cli.json` (auto-migrated on first V2 terminal client start) |
| LSP runtime (servers, tools, diagnostics) | v2.0.0 | V2 accepts and preserves `lsp` config but does not run language servers or expose LSP tools; use lint/typecheck/compile commands |
| `CLAUDE.md` fallback discovery | v2.0.0 | V2 discovers only `AGENTS.md` (global + ambient); move guidance into `AGENTS.md` |
| Accepted-but-unsupported V1 fields (ignored with warning): `logLevel`, top-level `server`, top-level `subagent_depth`, `compaction.tail_turns`, `compaction.prune`, agent `name` in V1 JSON, enabled-only MCP entry without `type`, V1 experimental `batch_tool`/`openTelemetry`/`primary_tools`/`continue_loop_on_deny`, V1 provider `id`/`whitelist`/`blacklist`, V1 provider-model `release_date`/`attachment`/`reasoning`/`temperature`/`experimental`/non-deprecated `status`/boolean `interleaved` | v2.0.0 | no V2 behavior; ignoring is intentional, not a regression |
| Session sharing (links, commands, import-from-share-URL) | v1.19.1 (discontinued), backend + `/share` command removed in v2.0.30 | none |
| Retired session-sharing backend and unavailable `/share` command | v2.0.30 | none |
| Provider replay fields `state` / `providerState` / `resultState` on text, reasoning, assistant, compaction, and tool messages | v2.1.0 | `native` (tool parts share `tool.native`) |
| `Credential.Key.configuration` | v2.1.0 | put setup-form answers in `metadata` (storage/import still reads the legacy shape) |
| Summary compaction `recent` flattened copy | v2.1.0 | reference the first retained message via `metadata.keepID` (pre-2.1 kept text still readable as `metadata.recent`) |
| Completed-compaction `providerContext` | v2.1.0 | `native.messages` (legacy rows converted on read) |
| `session.compacted` event | v2.1.0 | `session.compaction.started` / `session.compaction.ended` |
| `@opencode/ai/promise` subpath; wildcard subpath export | v2.2.0 | package root is the Promise API; Effect API at `@opencode/ai/effect`; explicit provider/protocol entry points |
| OpenCode GitHub Action | v2.2.0 | no longer published; remove from workflows |
| OpenTUI 0.6 support for TUI plugins (0.7 required), then 0.7 -> 0.8 required | v2.2.0, then v2.2.3 | upgrade `@opentui/core` / `@opentui/solid` |
| `@opencode/ai` providers fal, Black Forest Labs, Replicate, Stability plus five legacy provider entry points; `configure()` type name | v2.2.1 | nested import paths; type renamed `Config` (CLI/Desktop/HTTP API unaffected) |
| Managed policy `integration.use` covering MCP servers, skills, plugins | v2.2.3 | new `mcp.use`, `skill.use`, `plugin.use` actions (old resource prefixes auto-converted) |
| `ImageResponse.image` | v2.2.7 | `response.images[0]` (direct `@opencode/ai` importers only) |

(opencode.ai, "Migrate from V1", docs-migrate-v1.md)
(raw.githubusercontent.com, "Changelog", opencode-changelog-root.md)
(github.com, "Releases page 2", github-releases-page2.md)

## 6. Minimal migration sequence

Ordered steps adapted from the official practical migration path (opencode.ai,
"Migrate from V1", docs-migrate-v1.md). Tags: **[IRREVERSIBLE]** = cannot be
undone without restoring a backup; **[RESTART]** = requires an OpenCode /
client / service restart or reinstall to take effect.

1. **Snapshot the V1 setup** (copy `.opencode/`, `opencode.json(c)`,
   `tui.json(c)`, plugins). V1 and V2 share config locations, so this copy is
   the only safe rollback. [REVERSIBLE]
2. **Remove the package-managed V1 install, then install V2** via the curl
   installer (it replaces the V1 binary), WinGet, or Homebrew Core (already on
   the V2 line). Note: `npm`/`pnpm` will not take you here - npm `latest` is
   1.19.5 and the 1.x install script refuses 2.x; from 1.x use
   `opencode upgrade --major`. [IRREVERSIBLE without reinstalling V1]
   [RESTART]
3. **Keep existing config and file definitions; start V2 and verify** models,
   credentials, agents, permissions, and MCP servers. V1 config format still
   works - it is normalized in memory and the source file is not rewritten.
   [RESTART]
4. **Allow the first V2 terminal client start to auto-migrate client config**:
   when `~/.config/opencode/cli.json` is absent, supported global `tui.json`
   settings and persisted preferences are migrated there; V1 files are left
   unchanged; project-local client configuration is NOT migrated (V2 client
   config is global) - hand-port any project-local tui settings.
   [AUTO-MIGRATION] [RESTART of the terminal client] (one-way for
   project-local settings: [IRREVERSIBLE] unless you kept the V1 copy)
5. **Port plugins** (V1 plugin code does not run in V2): rename `plugin` ->
   `plugins`, tuple -> object, move local plugin entrypoints into directory
   form (`./plugin/local/index.ts`), then port each plugin to
   `Plugin.define` + `setup(ctx)` per the map in section 2. Confirm the plugin
   appears in the active list, exercise every hook/transform/tool/subscription,
   verify cleanup by reloading or removing it, and test options and persisted
   state with a clean project. If you must still support V1, ship dual
   entrypoints (object entrypoints work on 1.18.29+) and remove the V1
   implementation after the support window. [IRREVERSIBLE for the V1 code path
   once removed] [RESTART / `opencode service restart` for unwatched local
   dependencies]
6. **Port server-API integrations** to `@opencode/client` / the V2 HTTP API;
   auth changes: `OPENCODE_PASSWORD` sets the password (`OPENCODE_SERVER_PASSWORD`
   still works), username is always `opencode`, `OPENCODE_SERVER_USERNAME` is
   gone. [IRREVERSIBLE - the V1 server API is an intentional breaking change]
   [RESTART of the integration]
7. **Convert configuration to the native V2 shape when ready (optional).**
   Recommended route: ask OpenCode to migrate the configuration including
   file-based definitions while preserving behavior. Convert agent command
   files all-at-once per file (no format mixing), move files to the preferred
   paths (`.opencode/agents/`, `.opencode/commands/`, `.opencode/skills/<id>/SKILL.md`),
   and remember: do not point V1 at files after converting them.
   [IRREVERSIBLE for V1 consumption - keep the step-1 copy]
   [config directories are watched -> auto reload; RESTART for unwatched
   dependencies]
8. **Re-verify permissions last, explicitly** (section 4): shell/edit/subagent
   flows, effective rule order after the base policy, and zero load-time
   warnings. [RESTART if rules were cached in saved approvals]

Auto-migration behaviors already built into V2 (no action needed, but verify):

- `tui.json(c)` -> `~/.config/opencode/cli.json` on first V2 terminal client
  startup when `cli.json` is absent (global settings only; V1 files unchanged;
  project-local client config not migrated) (opencode.ai, "Migrate from V1",
  docs-migrate-v1.md).
- Stored legacy `apply_patch` permissions migrate to the `edit` permission
  (fixed in v2.1.3) (raw.githubusercontent.com, "Changelog",
  opencode-changelog-root.md).
- V1 and native V2 config fields are normalized in memory without rewriting
  source files; provider ID canonicalization applies to unambiguous V1 fields
  (opencode.ai, "Migrate from V1", docs-migrate-v1.md).
- Runtime compat: calls to a tool named `bash` run as `shell` with the same
  permissions since v2.2.5 (a plugin tool actually named `bash` still takes
  precedence) (raw.githubusercontent.com, "Changelog", opencode-changelog-root.md).

## 7. Unverified gaps

These are exactly the items the archive could not support. Do not paper over
them; re-research before relying on them.

1. **Per-patch dates for v2.0.1 through v2.0.24: UNVERIFIED.** No GitHub
   Release objects exist for the v2.0.x tags (the tags/release endpoints 404'd
   for v2.0.0), and the official changelog starts at v2.0.26; only v2.0.0
   (2026-09-11) and v2.0.25 (2026-10-08) tag commits carry dates in the
   archive. Their release notes are entirely absent (github.com,
   "Releases", github-api-releases.json) (raw.githubusercontent.com,
   "Changelog", opencode-changelog-root.md).
2. **v2.0.31: date and notes UNVERIFIED.** The tag exists in the archived tag
   list, but v2.0.31 appears in no archived changelog (root dev changelog and
   the v2.1.0 snapshot both skip it: 2.0.32 -> 2.0.30) and has no Release
   object (api.github.com, "Tags", github-api-tags-page1.json)
   (raw.githubusercontent.com, "Changelog", opencode-changelog-root.md)
   (raw.githubusercontent.com, "Changelog (v2.1.0 snapshot)",
   opencode-changelog-at-v2.1.0.md).
3. **v2.1.1 notes: UNVERIFIED.** Date available only as tag-commit
   2026-10-20; the changelog skips v2.1.1 (api.github.com, "Commit v2.1.1",
   github-commit-v2.1.1.json) (raw.githubusercontent.com, "Changelog",
   opencode-changelog-root.md).
4. **`disabled_agents` schema question: UNVERIFIED.** The string
   `disabled_agents` appears in zero archived sources, and the archived
   `config.json` schema contains no such property (only per-agent `disabled`
   exists, per the agents guide). Whether V2 accepts a top-level
   `disabled_agents` array cannot be answered from this archive (opencode.ai,
   "config.json schema", config-schema.json) (opencode.ai, "Agents",
   docs-agents.md).
5. **v1.19.5 headline: empty.** The GitHub release entry for v1.19.5 has no
   notes body in the archive, so its headline change is unknown (github.com,
   "Releases page 2", github-releases-page2.md).
6. **v2.0.0 and v2.1.0 release-tag pages yielded no usable notes** (JS shells;
   low/medium reliability). All v2.0.0 breaking-change claims in this conspect
   therefore come from the official migration guide, not release notes
   (github.com, "Release tag v2.0.0", github-release-tag-v2.0.0.md)
   (github.com, "Release tag v2.1.0", github-release-tag-v2.1.0.md).
7. **npm packument publish timestamps not consumed.** The archived
   `npm-opencode-ai-registry.json` (25 MB packument with `time[]`) could not be
   queried in this lane (no shell); all npm claims here rest on the small
   `/latest` snapshot and on GitHub Release `published_at` values
   (registry.npmjs.org, "opencode-ai latest", npm-opencode-ai-latest.json).
8. **Exact installer command lines** for curl and Homebrew are not in the
   archive (the install-instructions page itself was not archived); only the
   fact of the curl installer and Homebrew Core tracking V2 is supported
   (opencode.ai, "Migrate from V1", docs-migrate-v1.md)
   (github.com, "Releases page 2", github-releases-page2.md).
9. **v1.18.0-v1.18.4 years** are cross-anchored (footnote in section 1.1),
   not printed in the scrape itself; treat the year as high-confidence but
   inferred (github.com, "Releases page 6", github-releases-page6.md).
10. **Per-scope shadowing edge cases** of V1 `permission` vs native
    `permissions` beyond the documented "valid native V2 value takes
    precedence" rule were not spelled out by any archived source; verify
    effective rules empirically after migration rather than assuming them
    (opencode.ai, "Migrate from V1", docs-migrate-v1.md).

## Unarchived Sources (NOT ARCHIVED - never cited above)

| URL | Failure reason (from manifest) |
|---|---|
| https://opencode.ai/docs/migration/ | 404; correct path is /docs/migrate-v1/ |
| https://opencode.ai/docs/plugins/hooks/ | 404; hook docs live under /docs/build/plugins/server/ |
| https://opencode.ai/docs/plugins/tools/ | 404; tool docs live under /docs/build/plugins/server/ |
| https://raw.githubusercontent.com/sst/opencode/dev/packages/opencode/CHANGELOG.md | 404 |
| https://raw.githubusercontent.com/sst/opencode/v2.0.25/CHANGELOG.md | 404 (changelog at that tag/path does not exist; root changelog on dev starts at v2.0.26) |
| https://raw.githubusercontent.com/anomalyco/opencode/v2.0.25/CHANGELOG.md | 404 |
| https://raw.githubusercontent.com/anomalyco/opencode/v2.0.10/CHANGELOG.md | 404 |
| https://api.github.com/repos/sst/opencode/releases/tags/v2.0.0 | 404, no GitHub Release object for v2.0.0 (tag exists only) |
| https://api.github.com/repos/anomalyco/opencode/releases/tags/v2.0.0 | 404, no GitHub Release object |
| https://api.github.com/repos/anomalyco/opencode/releases/tags/v2.1.0 | 404, no GitHub Release object |

Note: the sources directory contains files whose URLs sit on this NOT ARCHIVED
list (`docs-migration.md`, `docs-plugins-hooks.md`, `docs-plugins-tools.md`,
`opencode-changelog-at-v2.0.10.md`, `opencode-changelog-at-v2.0.25.md`,
`opencode-changelog-packages.md`, `github-api-release-v2.0.0.json`,
`github-api-release-v2.0.0-anomaly.json`, `github-api-release-v2.1.0-anomaly.json`,
`github-release-tag-v2.0.0-html.md`). Per the manifest they are not certified
sources and were not cited in the body.

## Excluded Sources

| URL | Exclusion reason (from manifest) |
|---|---|
| https://opentui.com/docs/releases/0.8.0 | third-party TUI library notes, only referenced by OpenCode release text; not needed for this project's migration surface |
| https://opentui.com/docs/releases/0.7.0 | third-party TUI library notes; only relevant to TUI-plugin authors, not this project's server plugins |

## Works Cited

- OpenCode. "Migrate from V1." opencode.ai, n.d.,
  https://opencode.ai/docs/migrate-v1/, docs-migrate-v1.md.
- OpenCode. "Migrate plugins from V1." opencode.ai, n.d.,
  https://opencode.ai/docs/build/plugins/migrate-v1/,
  docs-build-plugins-migrate-v1.md.
- OpenCode. "Server." opencode.ai, n.d.,
  https://opencode.ai/docs/build/plugins/server/, docs-build-plugins-server.md.
- OpenCode. "Plugins." opencode.ai, n.d., https://opencode.ai/docs/plugins/,
  docs-plugins.md.
- OpenCode. "Config." opencode.ai, n.d., https://opencode.ai/docs/config/,
  docs-config.md.
- OpenCode. "Permissions." opencode.ai, n.d.,
  https://opencode.ai/docs/permissions/, docs-permissions.md.
- OpenCode. "Agents." opencode.ai, n.d., https://opencode.ai/docs/agents/,
  docs-agents.md.
- OpenCode. "Config JSON Schema." opencode.ai, n.d.,
  https://opencode.ai/config.json, config-schema.json.
- OpenCode. "Changelog." GitHub (sst/opencode dev branch; anomalyco/opencode),
  entries dated 2026-10-08 through 2026-11-10,
  https://raw.githubusercontent.com/sst/opencode/dev/CHANGELOG.md,
  opencode-changelog-root.md.
- OpenCode. "Changelog (snapshot at v2.1.0)." GitHub (anomalyco/opencode),
  2026-10-20,
  https://raw.githubusercontent.com/anomalyco/opencode/v2.1.0/CHANGELOG.md,
  opencode-changelog-at-v2.1.0.md.
- GitHub. "Releases." GitHub (sst/opencode / anomalyco/opencode), n.d.,
  https://github.com/sst/opencode/releases, github-releases-page.md.
- GitHub. "Releases (page 2)." GitHub, n.d.,
  https://github.com/sst/opencode/releases?page=2, github-releases-page2.md.
- GitHub. "Releases (page 3)." GitHub, n.d.,
  https://github.com/sst/opencode/releases?page=3, github-releases-page3.md.
- GitHub. "Releases (page 4)." GitHub, n.d.,
  https://github.com/sst/opencode/releases?page=4, github-releases-page4.md.
- GitHub. "Releases (page 5)." GitHub, n.d.,
  https://github.com/sst/opencode/releases?page=5, github-releases-page5.md.
- GitHub. "Releases (page 6)." GitHub, n.d.,
  https://github.com/sst/opencode/releases?page=6, github-releases-page6.md.
- GitHub. "Release tag v2.0.0." GitHub, 2026-09-11,
  https://github.com/sst/opencode/releases/tag/v2.0.0,
  github-release-tag-v2.0.0.md.
- GitHub. "Release tag v2.1.0." GitHub, 2026-10-20,
  https://github.com/sst/opencode/releases/tag/v2.1.0,
  github-release-tag-v2.1.0.md.
- GitHub API. "Releases (per_page=100)." GitHub, n.d.,
  https://api.github.com/repos/sst/opencode/releases?per_page=100,
  github-api-releases.json.
- GitHub API. "Tags (page 1)." GitHub, n.d.,
  https://api.github.com/repos/anomalyco/opencode/tags?per_page=100,
  github-api-tags-page1.json.
- GitHub API. "Commit for tag v2.0.0." 2026-09-11,
  https://api.github.com/repos/anomalyco/opencode/commits/v2.0.0,
  github-commit-v2.0.0.json.
- GitHub API. "Commit for tag v2.0.25." 2026-10-08,
  https://api.github.com/repos/anomalyco/opencode/commits/v2.0.25,
  github-commit-v2.0.25.json.
- GitHub API. "Commit for tag v2.1.1." 2026-10-20,
  https://api.github.com/repos/anomalyco/opencode/commits/v2.1.1,
  github-commit-v2.1.1.json.
- npm. "opencode-ai (dist-tag latest)." npm Registry, n.d.,
  https://registry.npmjs.org/opencode-ai/latest, npm-opencode-ai-latest.json.
