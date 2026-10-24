# DIA-106 - Container-first rust-analyzer for LSP gate (pin 1.83.0->1.97.1, container-aware check-host-lsp)

---

id: DIA-106
title: "Container-first rust-analyzer for LSP gate (pin 1.83.0->1.97.1, container-aware check-host-lsp)"
area: dev-infra
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-11
source: fix-lane
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Container-first rust-analyzer for the LSP gate. Follow-up to the DIA-071 family:
`make test-shell` / `make test-infra` were exiting rc=2 because the host-side
`check-host-lsp` gate in `scripts/check-host-lsp.sh` could not find
`rust-analyzer` on the HOST PATH. A lane installed rust-analyzer 1.83.0 on the
host to satisfy the current pin, but the developer directed that tooling work
THROUGH the dev Docker container instead (matching the pre-commit delegation
pattern, DIA-094: the husky hook delegates into the dev container, and tool
provisioning should follow the same shape).

### Change

1. Bump `scripts/lsp-versions.env` `RUST_ANALYZER_VERSION` 1.83.0 -> 1.97.1
   (rustup stable).
2. Provision rust-analyzer 1.97.1 INSIDE the dev container (`Dockerfile.dev` /
   `dev-entrypoint.sh` per the existing pinned-binary pattern).
3. Make `scripts/check-host-lsp.sh` container-aware:
   - Primary path: `docker compose exec -T dev rust-analyzer --version` with a
     version check against the pin.
   - Host PATH fallback when the container is down.
   - Preserve the `SKIP_RUST=1` neutral behavior and the exit-code contract
     (0/1) plus `ok:` / `fail:` / `summary:` output format.

### Current state inspected (docs lane, 2026-08-11)

- `scripts/lsp-versions.env`: `RUST_ANALYZER_VERSION=1.83.0` (line 6). Sourced
  by `scripts/install-host-lsp.sh`, `scripts/check-host-lsp.sh`, and
  `scripts/__tests__/check-host-lsp.bats`.
- `Dockerfile.dev` Rust section (lines 166-189): rustup installs with
  `--default-toolchain "${RUST_VERSION}"` (ARG `RUST_VERSION=1.83.0`) and then
  `rustup component add rust-analyzer`, so the in-container rust-analyzer is
  currently bound to `RUST_VERSION`, NOT to `scripts/lsp-versions.env`. There is
  NO `ARG RUST_ANALYZER_VERSION` in Dockerfile.dev today (only
  `TYPESCRIPT_LS_VERSION`, `TYPESCRIPT_VERSION`, `PYRIGHT_VERSION`); the T7-T10
  comment claims lsp-versions.env is the single source for "host + container LS
  versions", but rust-analyzer is not yet mirrored. Fix must add the mirror.
- `dev-entrypoint.sh`: only secret loading + Xvfb startup; no tool provisioning
  today (likely NOT applicable unless a version-sync step lands there - flag if
  used).
- `scripts/check-host-lsp.sh`: host-PATH probe via `probe_tool`; extracts the
  first dotted-version token from `--version` output; `SKIP_RUST=1` is neutral;
  exit 0/1 with `ok:` / `fail:` / `skip:` + `summary:` lines.
- Teammate commit de00917 (2026-08-11, "feat: update Docker setup and
  dependencies") touched Dockerfile.dev (+3), Makefile (UID/GID exports),
  docker-compose.yml (root user, SELinux volume mounts),
  scripts/dev-git-turbo-profile.sh, packages/\*/package.json, pnpm-lock.yaml.
  Inspected: no rust-analyzer pin change there; the Dockerfile.dev rust section
  is the one to extend.

### Scope guard

Only these files may change:
`scripts/lsp-versions.env`, `Dockerfile.dev`, `dev-entrypoint.sh` (if
applicable), `scripts/check-host-lsp.sh`. ANY 4th distinct file (beyond those
four) must be flagged before touching it.

DOCS-LANE FLAG (candidate 5th file): `scripts/__tests__/check-host-lsp.bats`
exercises `check-host-lsp.sh` and will likely need updates for the
container-aware path. That file is OUTSIDE the 4-file scope guard - flag it for
developer approval before modifying.

### Container-first consequence (expected, not a bug)

Host rustup default stays 1.83.0 (container-first chosen over host PATH). While
the container is down, the host PATH fallback will report `fail:` against the
new 1.97.1 pin because the host still carries 1.83.0. That is the designed
drift-detection behavior of the gate; the primary container path is what must
pass.

## Verification

- [ ] Container rebuilt + running (DIA-094 gate): Dockerfile.dev change applied, `make up` succeeds, `docker compose ps` shows the dev service healthy.
- [ ] In-container version: `docker compose exec -T dev rust-analyzer --version` reports 1.97.1.
- [ ] `scripts/check-host-lsp.sh` EXIT 0 via the container path with the container up (rust-analyzer 1.97.1 ok).
- [ ] `SKIP_RUST=1` still neutral: script exits 0 with a `skip:` line and no rust-analyzer probe.
- [ ] `make test-shell` EXIT 0 (193 ok / 0 not-ok).
- [ ] `make test-config` EXIT 0 (224 pre-existing WARNs baseline unchanged; no new warnings).
- [ ] `bash -n scripts/check-host-lsp.sh` passes (no syntax errors).
- [ ] Commit + push via the container-delegated pre-commit hook, no --no-verify (DIA-094 / DIA-096).
- [ ] Host rustup default remains 1.83.0 (container-first decision respected).

## Fix

> To be filled at fix time.

Fix direction: bump `RUST_ANALYZER_VERSION` to 1.97.1 in lsp-versions.env; add
an `ARG RUST_ANALYZER_VERSION=1.97.1` (or equivalent) to Dockerfile.dev and
provision the in-container rust-analyzer against it (decide: separate rustup
toolchain vs `rustup toolchain install 1.97.1 && rustup component add
rust-analyzer --toolchain 1.97.1` vs standalone rust-analyzer binary - pick per
existing pinned-binary pattern); make check-host-lsp.sh container-aware with
container primary + host fallback. Verify against the gate list above.

## Re-verify

> To be filled at re-verify time.

Expected proof: in-container `rust-analyzer --version` = 1.97.1, check-host-lsp
EXIT 0 via container path, `make test-shell` EXIT 0 (193 ok / 0 not-ok),
`make test-config` EXIT 0, `bash -n` clean, push without --no-verify.

## History

- 2026-08-11 (created): Ticket created by the docs lane from the cod-19
  rust-analyzer host-install follow-up. Developer disposition: bump the pin to
  1.97.1 (rustup stable) + container-first tooling (tooling THROUGH the dev
  Docker container, matching the pre-commit delegation pattern). Created for
  DIA-063 ticket-gate compliance.
- 2026-08-11 (rev-2 review APPROVE): rev-2 review approved BOTH axes
  (Standards + Spec fidelity). Developer post-facto approval of the 5th-file
  modification (scripts/**tests**/check-host-lsp.bats) noted per rev-2 S3.
  Close-out fold: S1 (extract duplicated version-extraction regex into a
  helper in scripts/check-host-lsp.sh), S3 (this History entry), S5 (doc and
  install-script version bumps 1.83.0 -> 1.97.1 + container-first note).
  S2, S4, P1, P2 accepted as-is.

## Session-11 close-out (2026-08-11)

CLOSED. All review findings dispositioned: rev-2 review APPROVE both axes
(Standards + Spec fidelity); developer post-facto approval of the 5th-file
modification (scripts/**tests**/check-host-lsp.bats) noted per rev-2 S3;
S1/S3/S5 folded into this close-out; S2/S4/P1/P2 accepted as-is.

Close-out changes applied:

- S1: extracted the duplicated version-extraction regex
  `grep -oE '[0-9]+(\.[0-9]+)+' | head -n1` (previously inlined in both
  probe_tool and probe_rust_analyzer_container) into the `extract_version`
  helper in scripts/check-host-lsp.sh; both probe paths now call it.
  Behavior identical; bats suite unchanged and green (9/9).
- S5: docs/dev-infra/host-lsp-setup.md install table + ok-line example
  bumped 1.83.0 -> 1.97.1, plus a container-first note (primary LSP probe
  path delegates into the dev container); scripts/install-host-lsp.sh
  tool_version comment example bumped 1.83.0 -> 1.97.1.
- S3: this History entry appended (rev-2 APPROVE + developer post-facto
  5th-file approval).

Verification evidence at close-out:

- `bash -n scripts/check-host-lsp.sh` exit 0 (no syntax errors).
- `bash scripts/check-host-lsp.sh` exit 0 via container path
  (rust-analyzer 1.97.1 ok).
- `make test-shell` exit 0 (193 ok / 0 not-ok; check-host-lsp.bats 9/9 green
  after the S1 refactor).
- `make test-config` exit 0 (224 pre-existing WARNs).
- Committed + pushed via the container-delegated pre-commit hook, no
  --no-verify (DIA-094 / DIA-096).
