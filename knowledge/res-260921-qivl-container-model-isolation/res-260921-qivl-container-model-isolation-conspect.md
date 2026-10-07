# Container Model Isolation: Session/Agent Model Separation, Env Injection, and Container Boundaries

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 21
phase-a-failures: 1
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Scope

This conspect synthesizes archived sources on three linked questions for
running coding agents in containers: (1) how session, agent, and config
model selection interact in OpenCode V2 and oh-my-opencode-slim (OMO);
(2) how environment variables reach (or fail to reach) providers, tools,
and shells; and (3) which container patterns are maintainer-sanctioned
for OpenCode and Pi, with known failure modes. Campaign ticket
DIA-260918-ok9m. All claims below derive solely from the researcher's
archived sources; no network fetch was performed.

## 1. Session/Agent Model Separation and Precedence (V2 Docs)

OpenCode V2 keeps three distinct model slots, and they do not follow
each other implicitly:

- **Config default becomes the catalog default.** The configured `model`
  "becomes the catalog default when it is enabled and its provider is
  available," otherwise OpenCode falls back to the newest available
  supported model ("Models").
- **Session selection wins over config.** "A model already selected for
  a session takes precedence over the configured default," and
  "switching a session's model does not rewrite the config file"
  ("Models"). The session persists its own `model` (and `agent`) row,
  visible in the `V2Session` `Info` schema and `fromRow` persistence
  mapping ("V2 Session Source").
- **Selecting an agent does NOT change the session model.** "A session
  stores its selected model separately. Selecting a primary agent by ID
  does not change that model" ("Agents"). Switching agents fires an
  `AgentSwitched` event only; switching models fires `ModelSwitched`
  ("V2 Session Source").
- **Subagent inheritance is one-directional.** "A subagent uses its
  configured model, or inherits the parent session's model when none is
  configured" ("Agents"); the programmatic `subagent` call accepts an
  optional `model` override ("V2 Session Source").
- **Root model drops variants.** "The root `model` currently retains
  only the default provider and model, not a variant," and the expanded
  caveat repeats that "the V2 catalog default does not retain it.
  Select variants for a session, run, agent, or command instead"
  ("Models").

Practical consequence for containerized/headless runs: never assume
`--agent` implies that agent's model. Pin the model explicitly per
session/run, or switch it through the sanctioned API below.

## 2. `run --agent` Ignoring the Agent Model (Issue 42561)

Community issue 42561 reports that `opencode run --agent <name>` ignores
an agent file's declared `model:` and "silently resolves the global
default," with the run banner advertising the wrong model and no warning
("Issue 42561"). Key archived details:

- The agent model is parsed correctly (`debug agents` shows it), and the
  explicit `--model` CLI override is honored, so the defect is in
  headless session model resolution, not config parsing ("Issue 42561").
- The reporter also reproduced the sibling symptom in the TUI: switching
  agents does not move the model, consistent with the documented
  session/agent separation in section 1 ("Issue 42561").
- Impact is worst in automation (CI, benchmarking, harnesses): "runs
  happen on an unintended model with zero error or warning," and the
  wrong model changed tool-call behavior in the reporter's harness
  ("Issue 42561").
- Requested behavior: `run --agent` should prefer the agent's declared
  model with `--model` as override, and any substitution should warn
  visibly rather than substitute silently ("Issue 42561").

Status in archive: open community bug report (reliability Med); treat as
a live edge case to defend against, not as resolved upstream behavior.

## 3. `session.switchModel` as the Sanctioned Switch

Both the V2 plugin surface and the session service expose explicit model
switching as the supported path:

- Plugin API: `await ctx.session.switchAgent({ sessionID, agent:
  "build" })` and `await ctx.session.switchModel({ sessionID, model: {
  providerID: "anthropic", id: "claude-sonnet-4-5" } })`, documented as
  "change the agent or model used by subsequent requests" ("V2 Plugin
  Build").
- Service layer: `switchAgent` publishes `SessionEvent.AgentSwitched`
  and `switchModel` publishes `SessionEvent.ModelSwitched`, each stamped
  with the session ID and timestamp ("V2 Session Source").

For container harnesses, prefer `switchModel` (or per-session model at
creation) over config-file edits: it changes subsequent requests without
rewriting config, matching the documented "switching a session's model
does not rewrite the config file" rule ("Models").

## 4. OMO `/preset` via `config.update`, Merge Asymmetry, `stripOrchestratorModel`

OMO implements runtime preset switching through the OpenCode SDK's
`config.update()`, "which triggers a server-side cache invalidation";
agents covered by the new preset receive its values, while agents in the
previous preset but absent from the new one "are reset to their
config-file baseline values," and the next LLM call uses the new models
("Preset Switching").

Only four fields travel at runtime: `model`, `temperature`, `variant`,
`options` (arrays resolved to the first entry). `prompt`, `skills`,
`mcps`, and `displayName` require restart ("Preset Switching"). Runtime
switches persist across plugin re-inits within the process but revert on
restart; permanence requires writing the `"preset"` field into config
("Preset Switching").

**Merge asymmetry (startup vs. runtime):**

- At startup/config resolution, precedence is `ancestor < child < root
  agents < host config`: the child preset overrides its parent, the
  plugin's top-level `agents` object overrides the active preset, and the
  agent entry in `opencode.json` is the final override. A root `agents`
  entry is global, so per-preset values must live inside each preset
  block ("Configuration").
- At runtime, `/preset` applies preset values over the live registry and
  resets uncovered agents to baseline ("Preset Switching"). One archived
  passage additionally notes that `/preset` "persists the selected preset
  name and does not create an in-memory agent override or hot-swap the
  current agent registry. Reload OpenCode after changing the active
  preset" ("Configuration"), which sits in tension with the
  config.update/hot-switch account in "Preset Switching"; treat reload
  semantics as version-dependent and verify on the pinned OMO/OpenCode
  pair before relying on hot-switch in a container entrypoint.

**`stripOrchestratorModel`:** opt-in flag that preserves a runtime
`/model` selection for the orchestrator after subagent dispatch "by
omitting its configured model from the SDK config"; an explicit
preset-level `orchestrator.model` is still retained, and with no runtime
selection the initial orchestrator choice falls back to OpenCode's
session default ("Configuration"). Related: `inheritModelFrom:
"session"` omits an agent model so OpenCode uses the current session
model, and an explicit `model` alongside it wins ("Configuration").

**Prompt-file precedence limitation (#899):** prompt files beat inline
prompts everywhere, so an inline `prompt` coexisting with a prompt file
"is silently dropped in favor of the file"; keep shared prompts in files
and only `model`/`variant` in config ("Configuration").

## 5. Env Staleness and Write-Through Gaps (Issues 12698, 11481)

Two archived community issues describe complementary `Env` defects that
matter whenever a container or plugin sets credentials after startup:

- **`Env.all()` snapshot staleness (12698).** `Env.all()` freezes
  `process.env` into a singleton snapshot on first call via
  `Instance.state()` and never refreshes it; `Provider.list()` reads this
  snapshot for env-based provider detection, so variables set after first
  call (e.g. `AICORE_SERVICE_KEY`, `OPENAI_API_KEY`) never surface in the
  `connected` list. The shallow copy originated as test-isolation work
  (commits `ee4437ff3`, `90f39bf67`) ("Issue 12698").
- **`Env.set()` write-through gap (11481).** After commit `90f39bf`,
  `Env.set` updates only the shallow copy, not `process.env` itself,
  breaking providers whose SDKs read `process.env` directly (named:
  `sap-ai-core`, `amazon-bedrock`) ("Issue 11481").

Container implication: inject secrets **before** first `Env.all()` use
(entrypoint env, not late plugin writes), and do not rely on `Env.set`
for SDKs that read the real process environment.

## 6. `shell.env` as Sanctioned Injection (PR 12012, V1 Docs, V2 Hook)

The sanctioned answers to section 5 are the shell-env hooks:

- **V1 `shell.env` hook (merged PR 12012).** Motivated by running "a
  single opencode server against an arbitrary number of projects" with
  per-project environments without LLM-mediated `.env` loading, the hook
  lets a plugin inject variables into (1) LLM tool calls, (2) shell-mode
  `!command`s, and (3) PTY terminals; the author deliberately avoided
  instance-level caching so caching policy stays with the plugin
  implementation ("PR 12012"). The official V1 docs list `shell.env`
  under Shell Events with a dedicated "inject environment variables"
  example ("V1 Plugin Docs"; mirrored in "V1 Plugin Docs Mirror").
- **V2 `ctx.shell.hook("create.before", ...)`** carries a mutable `env`
  map (`Record<string, string | undefined>`) alongside command, cwd,
  timeout, and shell, e.g. `event.env.COMPANY_ENV = "development"` ("V2
  Plugin Build").

Prefer `shell.env` / `create.before` env injection over late
`process.env` mutation or `Env.set` for per-project container
credentials.

## 7. Pi Containerization Guidance

Pi "does not include a built-in permission system"; by default it runs
with the launching user's permissions, and stronger boundaries require
containerizing or sandboxing ("Pi Repo Readme"). The sanctioned patterns
("Pi Containerization"):

| Pattern | Isolation unit | Credential posture |
|---|---|---|
| Gondolin extension | Built-in tools + `!` commands in a local Linux micro-VM; host cwd mounted at `/workspace`, writes pass through | Auth stays on host |
| Plain Docker | Whole `pi` process in a local container; named volume for `/root/.pi/agent` keeps settings container-local | Provider API keys enter the container (`-e ANTHROPIC_API_KEY`) |
| OpenShell | Whole `pi` process in a policy-controlled sandbox (local or remote gateway) | Keys can stay outside; gateway injects credentials upstream, code calls `https://inference.local` |
| Docker Sandboxes (`sbx`) | Whole `pi` process in a managed sandbox | Sentinel/placeholder in-container; `sbx` proxy substitutes the real credential on egress; never `/login` inside |

Notes: host `pi` with a tool-routing extension still runs non-delegated
extension tools on the host ("Pi Containerization"); remote OpenShell
gateways do not bind-mount the project, so clone or transfer files
explicitly ("Pi Containerization").

## 8. `serve` First-Request Hang on Small Containers (Issue 43465)

Issue 43465 reports `opencode serve` (1.18.18, Bun 1.3.11, Debian
bookworm x86_64) hanging intermittently on the **first** HTTP request in
a 1-vCPU / 4 GB container: the process stays alive at 0% CPU with no
connections, children, disk activity, error, or further log lines, stuck
before `creating instance`; some process starts serve fine for life,
others wedge immediately, and restart sometimes clears it ("Issue
43465"). The reporter rules out network/registry, plugins, CPU count (2
CPUs did not help), and specific endpoints, and links similar
startup-hang reports (#38723, #41986) while distinguishing this case as a
pre-session, idle-CPU block ("Issue 43465"). No maintainer root-cause
fix is present in the archived file; treat accordingly. Operational
takeaway: front `serve` in constrained containers with an external
first-request readiness probe plus timeout-and-restart, rather than
assuming process-liveness equals readiness.

Related container notes: the official `serve` docs confirm the
TUI-starts-own-server model (`opencode serve` starts a new standalone
server; TUI picks a random port unless `--hostname`/`--port` are pinned)
and the `PATCH /config` update path backing OMO's `config.update`
preset switch ("Server Docs"). Docker's `sbx run opencode` pattern keeps
real keys in the host secret store (sentinel in-sandbox, proxy
substitution on egress, including `OPENCODE_API_KEY` as a custom
secret), but sandboxes do not inherit host user-level config, only
project-level config ("Docker Sandbox Guide"). Older container
report 5900 is an M1-Rosetta TUI rendering/launch failure (garbled
vertical help text), arch-specific and triaged against related container
issues, not a model-isolation signal ("Issue 5900"). The community
devcontainer/worktree plugin is explicitly unaffiliated, copies
gitignored secrets into isolated workspaces, and carries the known
upstream limitation that OpenCode's directory context does not follow
workspace switches (anomalyco/opencode#6697) ("Devcontainers Plugin").

## 9. Open Question: Container-Exec Env Gap

None of the archived sources document environment injection for a
container-exec execution path (commands routed into a container or
worktree backend rather than the server's own shell). The sanctioned
hooks cover the server's shells, tools, and PTYs (`shell.env`;
`create.before` env), and the devcontainer plugin covers secret-file
copying, but no archived source shows env flowing through container-exec.
Flag: verify on the pinned OpenCode version whether `shell.env` /
`create.before` env reaches container-exec'd commands, or whether
per-container env must be supplied at container creation (images, `sbx`
secrets, entrypoint env). Do not assume coverage.

## Unarchived/Excluded

- `https://opencode.ai/v2/docs/api/session/v2-session-switchmodel`
  (archived as empty `opencode-switchmodel-api.md` + 9-byte 404 HTML):
  NOT ARCHIVED, all fetch methods exhausted, HTTP 404. Replaced by the
  pinned-commit `session.ts` primary source and the `switchModel` section
  of the V2 plugin docs. Never cited in the body.

## Works Cited

- "Agents." *OpenCode V2 Docs*, archived as
  `sources/opencode-v2-agents.md`.
- "Configuration." *oh-my-opencode-slim Docs*, archived as
  `sources/omo-configuration.md`.
- "Containerization." *Pi Docs*, archived as
  `sources/pi-containerization.md`.
- "Issue 11481: Env.set." *anomalyco/opencode* (community issue),
  archived as `sources/opencode-issue-11481-env-set.md`.
- "Issue 12698: Env.all Snapshot." *anomalyco/opencode* (community
  issue), archived as `sources/opencode-issue-12698-env-all.md`.
- "Issue 42561: run --agent Model." *anomalyco/opencode* (community
  issue), archived as `sources/opencode-issue-42561-agent-model.md`.
- "Issue 43465: serve First-Request Hang." *anomalyco/opencode*
  (community issue), archived as
  `sources/opencode-issue-43465-serve-hang.md`.
- "Issue 5900: Devcontainer M1 Rosetta." *anomalyco/opencode* (community
  issue), archived as `sources/opencode-issue-5900-devcontainer.md`.
- "Models." *OpenCode V2 Docs*, archived as
  `sources/opencode-v2-models.md`.
- "OpenCode." *Docker Sandbox Docs*, archived as
  `sources/docker-sandbox-opencode.md`.
- "opencode-devcontainers." *Community Plugin Readme*, archived as
  `sources/opencode-devcontainers-plugin.md`.
- "Pi Repo Readme." *earendil-works/pi*, archived as
  `sources/pi-repo-readme.md`.
- "Plugins." *OpenCode Docs (dev)*, archived as
  `sources/opencode-plugins-docs.md`.
- "Plugins." *OpenCode Docs (mirror)*, archived as
  `sources/opencode-plugins-v1-docs.md`.
- "PR 12012: shell.env Hook." *anomalyco/opencode* (merged PR), archived
  as `sources/opencode-pr-12012-shell-env.md`.
- "Preset Switching." *oh-my-opencode-slim Docs*, archived as
  `sources/omo-preset-switching.md`.
- "Repo Readme." *alvinunreal/oh-my-opencode-slim*, archived as
  `sources/omo-repo-readme.md`.
- "Server." *OpenCode Docs*, archived as
  `sources/opencode-server-docs.md`.
- "V2 Plugin Build." *OpenCode V2 Docs*, archived as
  `sources/opencode-v2-plugins-build.md`.
- "V2 Session Source." *sst/opencode session.ts (pinned commit)*,
  archived as `sources/opencode-v2-session-ts.md`.
