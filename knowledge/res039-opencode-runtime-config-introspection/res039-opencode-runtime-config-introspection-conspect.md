# OpenCode Runtime Config Introspection (res039)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 4
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Purpose and Scope

This conspect supports the design of a `make test-runtime-config` target: an
LLM-free, real-boot introspection gate that proves, at OpenCode startup, which
preset, model, and plugins are actually effective in the running environment
(no model call, no network inference). It synthesizes four archived external
sources plus three verified-local in-repo files. All claims are grounded in
those sources; the verified-local vs docs-only distinction is tracked
explicitly because only the in-repo files were read directly in this session,
and the OpenCode binary itself was NOT executed (the research-lane bash sandbox
was deny-first, so no `opencode` invocation occurred).

## 2. LLM-Free Introspection Primitives (exact `opencode debug` commands)

The official CLI documents `opencode debug [command]` as the debugging and
troubleshooting entry point (OpenCode, "CLI"). The community cheat sheet
supplies the concrete, runnable subcommand set with real fresh-box output
(Mutai). The corroborated, LLM-free introspection commands are:

- `opencode debug config` -- prints the resolved config AFTER merging user +
  project + env overrides. This is the single most important command for the
  test: it is the runtime source of truth for effective preset/model/plugin
  state (OpenCode, "CLI"; Mutai; OpenCode, "Config").
- `opencode debug paths` -- prints all data, config, cache, state directories
  (home, data, bin, log, cache, config, state, tmp). Useful to prove a
  clean-HOME boot landed config under the intended directory (Mutai).
- `opencode debug agent <name>` -- prints a named agent's full resolved config
  (model, tools, permissions). Proves the effective model/preset per agent
  (OpenCode, "CLI"; Mutai).
- `opencode debug skill` -- lists discovered skills (Mutai).
- `opencode debug startup` -- prints startup timing in ms (Mutai).
- `opencode debug lsp` / `opencode debug rg` / `opencode debug file` --
  bridge/binary sanity checks (Mutai).
- `opencode debug snapshot` / `opencode debug scrap` / `opencode debug wait` --
  session snapshot inspection, project listing, protocol probe (Mutai).

Additional LLM-free primitives (no model call):

- `opencode models [provider]` -- lists models from configured providers /
  models.dev cache; explicitly NOT an LLM call (OpenCode, "CLI"; OpenCode,
  "Config"). Flags: `--refresh`, `--verbose`.
- `opencode agent list` -- lists all agents (OpenCode, "CLI").
- `opencode db path` and `opencode db "<sql>"` (flags `--format json|tsv`) --
  read-only access to the native SQLite telemetry store (OpenCode, "CLI";
  verified-local in session-analytics.sh).
- `opencode stats --models N` / `--tools N` / `--days N` / `--project SLUG` --
  aggregate token/tool usage, no LLM (OpenCode, "CLI"; verified-local in
  session-analytics.sh).
- `opencode --version` / `-v` -- prints version number; critical for the
  version-caveat section below (OpenCode, "CLI").

Context7 independently corroborated `opencode debug [command]`,
`OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, and `--pure` against the official
CLI docs (Context7).

## 3. Clean-HOME and Config Overrides

The config precedence model is MERGE, not replace: later sources override
earlier ones ONLY for conflicting keys; non-conflicting settings are preserved
(OpenCode, "Config"). Documented load order (lowest to highest precedence):

1. Remote config (.well-known/opencode)
2. Global config (~/.config/opencode/opencode.json)
3. Custom config (OPENCODE_CONFIG env var)
4. Project config (opencode.json in project root)
5. .opencode directories (agents/, commands/, plugins/, skills/, etc.)
6. Inline config (OPENCODE_CONFIG_CONTENT env var)
7. Managed config (/etc/opencode on Linux; macOS MDM highest, not
   user-overridable) (OpenCode, "Config").

Override mechanisms relevant to a clean-HOME boot test:

- `OPENCODE_CONFIG=/path/to/file` -- point at a custom config file; loaded
  between global and project config (OpenCode, "Config"; Mutai).
- `OPENCODE_CONFIG_DIR=/path/to/dir` -- point at a custom config DIRECTORY
  (searched for agents/commands/modes/plugins like .opencode); loaded AFTER
  global and .opencode dirs, so it CAN override them (OpenCode, "Config").
- `OPENCODE_CONFIG_CONTENT='<json>'` -- inline JSON config; highest-priority
  among non-managed sources (precedence #6). Ideal for tests: supply a full
  controlled config with no file on disk (OpenCode, "Config"; Mutai).
- `OPENCODE_DISABLE_MODELS_FETCH=1` -- disable any remote models fetch,
  keeping the boot fully offline/LLM-free (OpenCode, "Config").
- `opencode --pure` -- global flag; runs without external plugins. Proves
  plugin isolation for one invocation (OpenCode, "CLI"; OpenCode, "Config";
  Mutai; Context7).
- `OPENCODE_DISABLE_DEFAULT_PLUGINS` (boolean) -- disable default plugins
  (OpenCode, "CLI").

The project's own isolation pattern (tools/opencode-docker) persists OpenCode
home under `~/.opencode-docker/` with config under `./config/`, demonstrating
the clean-HOME booting design the test should emulate (opencode-docker README).

## 4. Effective Preset / Model / Plugin Proof

To prove what is EFFECTIVE (not merely declared) at boot, the test should
assert on the RESOLVED state, not the on-disk file:

- Effective config: parse `opencode debug config` output. It shows the merged
  `agent`, `mode`, `plugin`, `command`, `username` keys (Mutai real output:
  `{"agent":{},"mode":{},"plugin":[],"command":{},"username":"root"}`). An
  empty `plugin:[]` in a clean boot is itself evidence of plugin state.
- Effective model per agent: `opencode debug agent <name>` returns the resolved
  model + permissions (Mutai shows `opencode debug agent build` with its full
  permission array). This proves the effective preset/model, not the declared
  one.
- Effective plugins: combine `opencode debug config` (`plugin` array) with
  `opencode --pure` runs; if behavior is identical under `--pure`, no external
  plugin is active (OpenCode, "Config").
- Effective model list: `opencode models` (no LLM) enumerates what providers
  actually expose; `OPENCODE_DISABLE_MODELS_FETCH=1` keeps it offline
  (OpenCode, "Config").

The verified-local session-analytics.sh proves the GUARD PATTERN the test
should reuse: `command -v opencode` plus `opencode db path` as a hard
availability check, failing non-zero when the native surface is unavailable
(session-analytics.sh). This is the only OpenCode binary behavior corroborated
in this session, and it is corroborated via project source, not by running the
binary.

## 5. Verified-Local vs Docs-Only Distinction

- VERIFIED-LOCAL (read directly from the repo in this session, highest
  reliability for THIS environment):
  - scripts/session-analytics.sh -- proves `opencode db path`, `opencode db
    "<sql>"`, `opencode stats --models N`, `opencode stats --tools N`, and the
    `command -v opencode` + `opencode db path` guard pattern work as described
    (session-analytics.sh).
  - tools/opencode-docker/README.md -- proves the project's clean-HOME
    packaging approach (HOME under ~/.opencode-docker/, config under ./config/)
    (opencode-docker README).
  - Makefile -- CONFIRMS no `test-runtime-config` target exists today; the
    target is a DESIGN PROPOSAL, not existing behavior. Lists existing test-*
    targets (test-shell, test-config, test-infra, test-opencode-docker,
    session-analytics) for wiring guidance (Makefile).
- DOCS-ONLY (archived external docs; NOT executed in this session): all
  `opencode debug` / `opencode models` / `OPENCODE_CONFIG*` claims come from
  official docs, the cheat sheet, and Context7. They are mutually corroborated
  but were NOT run against a live binary here. The test's value is precisely to
  convert these docs-only claims into verified-local proof.

## 6. Source Reliability Assessment

- HIGH reliability (official, current): opencode.ai/docs/cli (last updated 21
  Aug. 2026) and opencode.ai/docs/config (last updated 21 Aug. 2026)
  (OpenCode, "CLI"; OpenCode, "Config"). Context7 extraction of the same docs
  (Source Reputation High, benchmark 81.4) independently corroborates the core
  facts (Context7).
- MEDIUM reliability (third-party but with real, dated, version-pinned output):
  ComputingForGeeks cheat sheet, verified working May 2026 with OpenCode
  1.14.33 on Ubuntu 26.04, author Josphat Mutai, dated 2026-07-23. Its real
  command outputs corroborate the official docs and supply the concrete
  subcommand list the official docs only hint at via navigation (Mutai).
- HIGH-verified-local (read directly, authoritative for THIS repo): the three
  in-repo files (session-analytics.sh, opencode-docker README, Makefile).
- EXCLUDED (see section 8): the old github.com/opencode-ai/opencode repo,
  rated LOW/LOW, archived/renamed to "Crush" with an obsolete config schema.

## 7. Version and Schema Caveats

- Version drift in config PATH: the official config docs (2026-08-21) state the
  PROJECT config file is `opencode.json` in the project root (no leading dot),
  while the ComputingForGeeks cheat sheet (2026-07-23) states `./.opencode.json`.
  This is a version-drift discrepancy; `opencode debug config` is the runtime
  source of truth to resolve which path is actually loaded (OpenCode, "Config";
  Mutai). The poetry-platform project uses `.opencode/opencode.jsonc` (config
  INSIDE the .opencode/ directory), which is valid per the ".opencode
  directories" + JSONC rules (OpenCode, "Config").
- JSONC support: OpenCode supports both JSON and JSONC, so the project's
  `.opencode/opencode.jsonc` is valid (OpenCode, "Config").
- Version pinning matters: cheat-sheet evidence is pinned to OpenCode 1.14.33
  (2026-07-23); official docs are dated 2026-08-21. The test should assert
  `opencode --version` and treat version-specific behavior as a caveat, not a
  constant (OpenCode, "CLI"; Mutai).
- Schema stability: the old github repo used providers/agents/mcpServers schema
  that does NOT match current OpenCode (model/plugin/agent/mcp). Any historical
  reference must be discarded (see excluded source, section 8).
- Network-off guarantee: to keep the boot LLM-free and offline, set
  `OPENCODE_DISABLE_MODELS_FETCH=1` and avoid `opencode run` (which DOES call
  an LLM) (OpenCode, "CLI"; OpenCode, "Config").

## 8. Unarchived / Excluded Sources

- https://github.com/opencode-ai/opencode -- EXCLUDED. Rated relevance LOW,
  reliability LOW. The repository is archived/renamed (now "Crush" by
  charmbracelet) and uses an OLD config schema (providers/agents/mcpServers)
  that does NOT match current OpenCode (model/plugin/agent/mcp). Retained only
  as historical context; NOT cited in the body (per researcher manifest
  evaluation).
- No external source was left un-archived due to method failure. The research
  bash 3-tier chain (curl/wget/trafilatura/crwl) was deny-first blocked in
  this session, but `webfetch` (markdown extraction) and `context7` query were
  used as a functional superset and successfully archived all four intended
  external sources (researcher manifest, lines 5-13, 27-28).

## 9. Recommendations for `make test-runtime-config` (design synthesis)

1. Boot OpenCode in a clean HOME (emulate tools/opencode-docker: HOME under a
   temp dir, config via OPENCODE_CONFIG or OPENCODE_CONFIG_CONTENT) with
   OPENCODE_DISABLE_MODELS_FETCH=1 to guarantee LLM-free, offline introspection
   (OpenCode, "Config"; opencode-docker README).
2. Assert availability with the session-analytics.sh guard pattern:
   `command -v opencode` then `opencode db path` (session-analytics.sh).
3. Capture `opencode debug config` and assert the effective `plugin` array,
   `agent`, and `mode` keys match the intended preset (Mutai; OpenCode,
   "Config").
4. Capture `opencode debug agent <name>` and assert the resolved model equals
   the expected preset model (Mutai; OpenCode, "CLI").
5. Run a `--pure` invocation and compare `opencode debug config` to prove no
   external plugin is silently active (OpenCode, "Config").
6. Assert `opencode --version` and record it as a caveat anchor for
   version-specific behavior (OpenCode, "CLI").
7. Wire the new target alongside existing test-* targets in the Makefile; note
   it does NOT yet exist (Makefile).

## Works Cited

Context7. "OpenCode Debugging Tools." Context7 Library Extraction
(websites/opencode_ai), 21 Aug. 2026.

Mutai, Josphat. "OpenCode CLI Cheat Sheet - Commands and Workflows."
ComputingForGeeks, 23 Jul. 2026, computingforgeeks.com/opencode-cli-cheat-sheet/.

OpenCode. "CLI." OpenCode Documentation, 21 Aug. 2026, opencode.ai/docs/cli.

OpenCode. "Config." OpenCode Documentation, 21 Aug. 2026, opencode.ai/docs/config.

Poetry Platform. "Makefile." Local repository file, /workspace/Makefile.

Poetry Platform. "scripts/session-analytics.sh." Local repository file,
/workspace/scripts/session-analytics.sh.

Poetry Platform. "tools/opencode-docker/README.md." Local repository file,
/workspace/tools/opencode-docker/README.md.
