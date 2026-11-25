# DIA-261110-03hs - Update Docker image to OpenCode 2.x and OmO slim 3.x

---

id: DIA-261110-03hs
title: "Update Docker image to OpenCode 2.x and OmO slim 3.x"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-10
source: inventory
date: 2026-11-10
created: 2026-11-10
updated: 2026-11-10

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

The dev image in `Dockerfile.dev` installs OpenCode from the v1 GitHub release
asset URL and verifies v1 asset SHA256 digests. OpenCode v2 is distributed as
`@opencode/cli` (official install docs: https://opencode.ai/docs/), so the
existing download URL and checksums cannot install v2. The current published
CLI package is 2.2.7. OmO slim 3.0.7 is also published and has v2-host changes.

Update the dev image installation to pin the current stable OpenCode v2 CLI
and OmO slim versions. Keep the OmO pin synchronized across `Dockerfile.dev`,
`.opencode/opencode.jsonc`, and `.opencode/tui.json`; update relevant install
comments and ensure the project configuration remains compatible with the new
CLI/plugin versions. Preserve deterministic, architecture-correct installs
and the existing user/cache ownership behavior.

The current session is running on the host rather than inside `poetry-dev`.
Implementation and container validation must wait until performed from the
dev container.

## Verification

- [ ] OpenCode is installed as the selected stable v2 CLI in the dev image;
      `opencode --version` reports the pinned version.
- [ ] OmO slim is pinned to the selected stable release in the image and both
      project plugin declarations; `scripts/check-omo-version-sync.sh` passes.
- [ ] The image builds on the supported container architecture(s) and a
      recreated `poetry-dev` starts successfully.
- [ ] OpenCode loads the project configuration and OmO slim without startup
      errors; run a bounded runtime smoke test.
- [ ] Relevant config and pin-sync validation passes.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
