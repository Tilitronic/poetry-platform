# DIA-260913-srn4 - Refresh rustup-init checksums blocking Podman dev image rebuild

---

id: DIA-260913-srn4
title: "Refresh rustup-init checksums blocking Podman dev image rebuild"
area: dev-infra
severity: Major
status: CLOSED
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

The Podman dev-image rebuild failed at Dockerfile step 33 because the mutable
`rustup/dist/.../rustup-init` artifact no longer matched the hard-coded SHA256.
No project runtime layer was produced, so the OMO 2.2.19, healthcheck, and npm
ownership fixes could not be exercised.

Pin the installer itself to the official Rust archive so the verified bytes do
not change independently of this repository.

## Verification

- [x] Rustup installer uses an immutable versioned archive URL.
- [x] x86_64 and aarch64 SHA256 values match the official archived artifacts.
- [x] Podman builds the dev image through the rustup layer.
- [x] Recreated dev service becomes healthy and remains executable.

## Fix

Added `RUSTUP_VERSION=1.28.2`, switched the download from the moving `dist`
path to `rustup/archive/1.28.2`, and recorded the verified digests for both
supported architectures.

## Re-verify

- Current moving x86_64 artifact was rustup-init 1.29.1 and hashed
  `dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71`,
  proving why the old digest failed.
- Archived 1.28.2 x86_64 digest:
  `20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c`.
- Archived 1.28.2 aarch64 digest:
  `e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c`.
- Podman rebuilt all 51 image steps successfully; the immutable rustup archive
  checksum passed, image `f7315f954ceb` was produced, and the recreated
  `poetry-dev` service reports `healthy` (2026-09-14).
