# DIA-260909-csds - Activate Muse Qwen balanced preset and persist project default

---

id: DIA-260909-csds
title: "Activate Muse Qwen balanced preset and persist project default"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: fix-lane
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

`/preset muse-qwen-balanced` works for the current process but does not survive
a full OpenCode restart in this project. OMO 2.2.17 writes the selection only to
the user config (best effort), while `.opencode/oh-my-opencode-slim.jsonc` is
the project config and therefore takes precedence at startup. Its root pointer
was still `promo`.

Make `muse-qwen-balanced` the persistent project default and change only its
orchestrator primary from Qwen3.8 Flash to paid OpenCode Go Muse Spark 1.3
Contributor with high reasoning. Preserve the existing fallback chain. This
does not change arbitrary future `/preset` selections: user-config persistence
is intentionally lower priority than the project config, except for the
higher-priority `OH_MY_OPENCODE_SLIM_PRESET` environment override.

## Verification

- [ ] JSONC and project config validation pass.
- [ ] Static effective config resolves `preset: muse-qwen-balanced` and the
      orchestrator primary is `opencode-go/muse-spark-1.3-contributor` / high.
- [ ] In the actual OpenCode container, `/models` lists the paid Muse ID and a
      fresh restart reports `muse-qwen-balanced` as active.
- [ ] One minimal orchestrator dispatch completes using the expected model.
- [ ] Independent AI-auditor review and changelog registration complete.

## UPDATE (2026-09-09, coder verification lane, campaign ticket DIA-260909-csds)

Developer privacy acceptance (VERBATIM):

"Yes. I explicitly accept routing the orchestrator to paid opencode-go/muse-spark-1.3-contributor with high reasoning. I understand it is training-enabled, non-ZDR, and region-limited. No secrets, API keys, credentials, private tokens, or sensitive personal data may appear in user prompts, dispatch payloads, handoffs, tickets, or agent results. Keep the existing DeepSeek Flash and MiMo Free fallbacks."

## Fix

Already-applied state; this lane made NO JSONC edits and NO commits.

The working tree already contains the fix (uncommitted, applied by a prior
lane): `.opencode/oh-my-opencode-slim.jsonc` root pointer `"preset": "promo"`
-> `"preset": "muse-qwen-balanced"`, and the `muse-qwen-balanced`
orchestrator block primary `"opencode-go/qwen3.8-flash"` ->
`"opencode-go/muse-spark-1.3-contributor"` with `"variant": "medium"` ->
`"variant": "high"`. Fallback chain unchanged:
`opencode-go/deepseek-v4-flash`, `opencode/mimo-v2.5-free`.

Gate file reference: ai-specialist gate learnings at
`.opencode/learnings/external-patterns/2026-09-09-dia-260909-csds-preset-precedence-and-muse-high-gate.md`
(documents OMO 2.2.17 project-config precedence over user-config `/preset`
persistence, plus the paid-Muse privacy gate). Origin preset block:
DIA-260909-tp5e 'add muse qwen balanced agent routing preset' (commit 918ff65).

## Re-verify

Static + gate evidence (2026-09-09, coder lane):

- `make test-config`: exit 0 (all structural gates PASS, incl.
  validate-plugin-structure.sh).
- `PRESETS="promo muse-qwen-balanced" bash
scripts/check-orchestrator-prompt-drift.sh`: exit 0
  ("2 preset(s) checked, 9 markers each, 0 gaps, byte-identical").
  Closes drift-guard gap F4 for the new preset.
- Static effective-config resolve (node JSONC parse): root
  `preset == muse-qwen-balanced`; `presets.muse-qwen-balanced.orchestrator`
  `model[0] == opencode-go/muse-spark-1.3-contributor`,
  `model[1] == opencode-go/deepseek-v4-flash`,
  `model[2] == opencode/mimo-v2.5-free`, `variant == high`. ASSERTS PASS.
- Env guard: `OH_MY_OPENCODE_SLIM_PRESET` unset on host (printenv grep empty).
  In-container check BLOCKED (see below); no override file observed in tree.
- Runtime restart smoke: BLOCKED. No Docker daemon reachable from this lane
  (`docker ps` fails: no /var/run/docker.sock), so `poetry-dev` restart,
  `/models` listing, OMO active-preset report, and minimal orchestrator
  dispatch could not be executed here. Requires a lane with Docker access.

Remaining for closure: runtime smoke (needs Docker), independent ai-auditor
review, changelog registration.

### Runtime smoke lane 2026-09-09T17:21:57Z (coder, inside poetry-dev)

- Host env check: NOT EXECUTED from this lane. Lane runs inside poetry-dev
  (hostname=poetry-dev, PWD=/workspace); no Docker socket
  (/var/run/docker.sock absent, `docker ps` fails) so host-side `printenv`
  and `docker exec` are unreachable. No host claim made.
- Inside poetry-dev env: `printenv | grep -i OH_MY_OPENCODE_SLIM_PRESET`
  -> empty output, grep exit 1 (UNSET). Confirmed twice
  (2026-09-09T17:21:57Z).
- Restart step NOT EXECUTED (blocked, by design): sole opencode server is
  PID 2740096 (`/proc/2740096/cmdline` = `opencode `), the parent of this
  lane (env OPENCODE_PID=2740096, OPENCODE=1). Killing it ends this session.
  `make opencode` target runs `docker compose exec -it ...` which needs host
  Docker, unavailable inside the container. No `make down/up`, no
  `docker restart`, no kill attempted. No JSONC edits, no commit.
- 3b headless PASS: `timeout 30 opencode models` exit 0; grep verbatim line:
  `opencode-go/muse-spark-1.3-contributor` (paid ID, distinct from
  `opencode/muse-spark-1.3-contributor-free` also listed).
- 3a `/preset` verbatim: BLOCKED (needs fresh interactive TUI; no fresh
  process started per above).
- 3c minimal orchestrator dispatch on paid Muse high: BLOCKED (no fresh
  process; no dispatch attempted to avoid cost/side effects from this lane).
- Static read-only: `.opencode/oh-my-opencode-slim.jsonc` line 3 root
  `"preset": "muse-qwen-balanced"` (checked, not edited).
