# Proposed design: `make test-runtime-config`
# Artifact of res039 (DIA-260821-n8sq recovery). NOT committed to project code.
# This is a DESIGN PROPOSAL for the implementing coder — do not treat as verified.
# Status: docs-corroborated design; the opencode binary was NOT executed in the
# research session (research-lane bash sandbox blocked all binary execution).
# The implementing coder MUST validate every command against the project's
# pinned opencode version (see tools/opencode-docker) before merging.

## Goal
A clean-HOME `make test-runtime-config` must REAL-BOOT OpenCode and OBSERVE the
effective preset / model / plugin behavior WITHOUT sending any LLM prompt.

## Why it is LLM-free
`opencode debug config` fully loads + merges config, loads plugins, discovers
agents, and resolves the effective runtime — then prints the result to stdout
and makes NO provider/LLM call. `debug paths`, `debug agent <name>`, and
`agent list` are likewise read-only introspection. No `opencode run`/prompt.

## Mechanism (proposed script: scripts/test-runtime-config.sh)
Mirrors the guard pattern in scripts/session-analytics.sh.

1. Guard (never silent success):
   - If `command -v opencode` succeeds -> use it directly (host-runnable).
   - Else fall back to `docker compose exec -T dev opencode` (container, like
     test-python). If neither works -> print clear error, exit 1.
2. Clean HOME:
   - TEST_HOME="$(mktemp -d)"; export HOME="$TEST_HOME"
   - This guarantees no real user config bleeds in.
3. Controlled config via inline env (precedence #6, overrides project config):
   - export OPENCODE_CONFIG_CONTENT='{"model":"anthropic/claude-sonnet-4-5","plugin":["@opencode-ai/plugin-prettier"],"agent":{"rt-test":{"description":"runtime config test agent","model":"anthropic/claude-haiku-4-5","tools":{"edit":false}}}}'
   - export OPENCODE_DISABLE_MODELS_FETCH=1   # keep offline/deterministic
   - export OPENCODE_DISABLE_AUTOUPDATE=1
4. Assertions (parse with `jq`; host tool validated by check-host-jq):
   a. `opencode debug config` -> JSON:
      - .model == "anthropic/claude-sonnet-4-5"
      - .plugin contains "@opencode-ai/plugin-prettier"
      - .agent.rt-test.model == "anthropic/claude-haiku-4-5"
   b. `opencode debug paths` -> assert `config` field == "$TEST_HOME/.config/opencode"
      (proves clean-HOME isolation: opencode used OUR home, not a real user dir)
   c. `opencode debug agent rt-test` -> prints resolved agent config (model+tools)
   d. `opencode agent list` -> non-empty (built-ins + rt-test present)
   e. Plugin isolation: `opencode --pure debug config` (same env) -> .plugin is EMPTY
      (proves --pure disables plugins; isolates plugin behavior)
   f. (optional/guarded) `opencode models` -> if it succeeds assert non-empty;
      if it fails (no network/keys) WARN, do not fail (not core to preset/model/plugin).
5. Cleanup: rm -rf "$TEST_HOME". Exit non-zero on first failed assertion with a
   clear message. Idempotent; writes nothing to the real HOME.

## Exact stable commands (core)
```
TEST_HOME="$(mktemp -d)"; export HOME="$TEST_HOME"
export OPENCODE_CONFIG_CONTENT='{"model":"anthropic/claude-sonnet-4-5","plugin":["@opencode-ai/plugin-prettier"],"agent":{"rt-test":{"description":"t","model":"anthropic/claude-haiku-4-5","tools":{"edit":false}}}}'
export OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1
opencode debug config | jq -e '.model=="anthropic/claude-sonnet-4-5" and (.plugin|index("@opencode-ai/plugin-prettier")>=0) and .agent.rt-test.model=="anthropic/claude-haiku-4-5"'
opencode debug paths | grep -q "config    $TEST_HOME/.config/opencode"
opencode debug agent rt-test
opencode agent list
opencode --pure debug config | jq -e '.plugin==[]'
rm -rf "$TEST_HOME"
```

## Makefile wiring (proposal)
```
test-runtime-config:
    docker compose exec -T dev bash scripts/test-runtime-config.sh
```
(or host-runnable: `bash scripts/test-runtime-config.sh` if opencode on PATH)

## Extension (recommended second variant)
Boot with the project's REAL `.opencode/opencode.jsonc` in a clean HOME (NO
OPENCODE_CONFIG_CONTENT) and assert the effective preset/model matches what
AGENTS.md declares. This catches config-path drift (see Limitations).

## Limitations
- Config file path is version-dependent: official docs (2026-08-21) say project
  config is `opencode.json` at root; cheat-sheet (2026-07-23) says `./.opencode.json`;
  this project uses `.opencode/opencode.jsonc`. `opencode debug config` is the
  runtime source of truth — the second variant above resolves which path loads.
- `opencode models` may need network/models.dev; guarded as WARN-only.
- Binary NOT executed during research (sandbox); validate against pinned version.
- OPENCODE_CONFIG_CONTENT precedence (#6) is below Managed config (#7/#8); in a
  managed/MDM environment the test config could be overridden. Unlikely in dev
  container; note for CI-on-mac.
