# DIA-260913-ir3r - Fix root-owned npm cache for OpenCode background dependency installs

---

id: DIA-260913-ir3r
title: "Fix root-owned npm cache for OpenCode background dependency installs"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-13
source: inventory
date: 2026-09-13
created: 2026-09-13
updated: 2026-09-13

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

The running dev container had `/home/dev/.npm` owned by `root:root` while
OpenCode runs as the `dev` user. After the first rebuild, a runtime probe found
the same ownership failure at `/home/dev/.local/state/opencode/locks`.
OpenCode could not create npm cache entries or its background dependency lock,
so exact plugin installation failed with `EACCES`.

Keep the repair narrow: establish dev-writable npm and OpenCode lock-state
paths during image build and repair legacy ownership at entrypoint startup
before dropping privileges. Do not change package versions or provider
configuration in this ticket.

## Verification

- [ ] Rebuild the dev image with Podman and recreate the dev container.
- [ ] `/home/dev/.npm` and its writable cache paths are owned by the configured
      dev UID/GID.
- [ ] `/home/dev/.local/state/opencode/locks` is owned by and writable for the
      configured dev UID/GID.
- [ ] A non-mutating npm cache write probe succeeds as `dev`.
- [ ] `opencode debug config` exits 0 without a fresh npm-cache `EACCES` or
      `NpmInstallFailedError` log entry.
- [x] Container-engine focused Bats and `make test-config` exit 0.

## Fix

The image now creates `/home/dev/.npm` and the OpenCode lock directory and
assigns both to the configured development UID/GID. The root entrypoint
preflight repairs both ownership roots before dropping privileges. A hermetic
test guards the ownership repair.

## Re-verify

- `make test-config`: exit 0, 57/57.
- Focused Bats batch: 65/65, including npm ownership migration.
- Rebuild, ownership/write probe, and fresh-log check: pending developer host
  execution.
- First rebuilt runtime probe logged `EACCES` for
  `/home/dev/.local/state/opencode/locks`; a live root repair made it `dev:dev`
  and writable, and the permanent preflight now covers that path.
