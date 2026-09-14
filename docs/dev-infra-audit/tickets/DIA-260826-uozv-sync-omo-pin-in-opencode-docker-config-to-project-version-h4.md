# DIA-260826-uozv - sync OMO pin in opencode-docker config to project version (H4)

---

id: DIA-260826-uozv
title: "sync OMO pin in opencode-docker config to project version (H4)"
area: opencode-config
severity: High
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-09-14

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

Reaudit on 2026-09-13 confirmed that the active project and TUI runtime used
2.2.17 while the dev image still baked 2.2.14. The source checkout under
`.opencode/oh-my-opencode-slim/src` is explicitly reference-only and is not a
runtime pin. The legacy `tools/opencode-docker` runtime is handled by
DIA-260824-8k62 "retire legacy tools/opencode-docker only after unified-runtime
acceptance" and is intentionally excluded from this active-runtime upgrade.

## Verification

- [x] `.opencode/opencode.jsonc`, `.opencode/tui.json`, and `Dockerfile.dev`
      declare one exact OMO version.
- [x] A host-safe config gate fails on drift or a missing active pin source.
- [x] Current runtime documentation identifies the source checkout as
      reference-only and names the same runtime version.
- [x] A rebuilt Podman dev container resolves OMO 2.2.19 and passes functional
      TUI/delegation smoke.

## Fix

Pinned the active runtime, TUI, and image bake to OMO 2.2.19. Added
`scripts/check-omo-version-sync.sh` plus focused Bats coverage and wired it into
`make test-config`. Updated current documentation without rewriting historical
evidence or falsely relabelling the reference-only source checkout.

## Re-verify

- `make test-config`: exit 0, 57/57.
- `check-omo-version-sync.bats`: 3/3 pass.
- Podman image rebuild completed successfully and the recreated `poetry-dev`
  container reports healthy. OpenCode resolved OMO 2.2.19; the TUI exposed
  `/preset`, selected `Orchestrator - GPT-5.6 Luna - OpenAI`, and a non-empty
  OAuth prompt returned `OMO_2219_OPENAI_OK`.
- A two-task orchestrator lifecycle smoke returned
  `A:poetry-platform-monorepo` and `B:2.2.19` (exit 0, 2026-09-14).
