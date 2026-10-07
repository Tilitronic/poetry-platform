# Proposal: Makefile uses the engine-aware compose stack (UID/GID wiring parity)

## Why

`scripts/opencode-dev` is the canonical engine-aware compose launcher: it auto-detects the
container engine (Podman / rootless-Docker) and OS (WSL / native), sets `COMPOSE_FILE` to merge
`docker-compose.yml` with the engine-specific UID/GID override (`docker-compose.rootless-docker.yml`
→ `user: "0:0"`; `docker-compose.podman.yml` → `userns_mode: keep-id` + `security_opt: label=disable`)
plus the optional `docker-compose.wsl.yml`, and brings up the stack with the correct runtime UID/GID
mapping (res040 §1-4).

The Makefile's `build`/`up`/`down`/`shell`/`opencode` (and the other bare `docker compose` targets)
invoke `docker compose` with NO `COMPOSE_FILE`, so they read only the base `docker-compose.yml` and
silently DROP the engine override. On rootless Docker / Podman hosts, `make up`/`make shell`/
`make opencode` therefore run the container with the wrong runtime UID/GID mapping while
`scripts/opencode-dev` gets it right — the UID/GID wiring mismatch of DIA-260826-766f. The Makefile
also carries dead `UID`/`GID`/`export UID`/`export GID` lines (lines 36-39) that are never referenced
by any target, masking the fact that the real wiring flows through `.env` `USER_UID`/`USER_GID` build
args + the engine override.

## What Changes

- Add `scripts/compose-env.sh` (bash-3 compatible, per ADR 8): computes and prints the merged
  `COMPOSE_FILE` using the SAME engine/OS detection logic `scripts/opencode-dev` already implements.
  Docker-free at compute time (no daemon invocation).
- Refactor `scripts/opencode-dev` to source `scripts/compose-env.sh` for `COMPOSE_FILE` instead of
  inlining the detection — single source of truth, no behavior change.
- Makefile: remove the dead `UID`/`GID`/`export UID`/`export GID` lines; add one
  `export COMPOSE_FILE := $(shell scripts/compose-env.sh)` at the top so every bare `docker compose`
  target (`build`, `up`, `down`, `shell`, `opencode`, `dev`, `install`, `db-psql`, `logs`,
  `test-python`, `test-infra`) inherits the engine-aware stack.
- No change to `docker-compose.yml`, the engine override files, `Dockerfile.dev`, or `.env`
  `USER_UID`/`USER_GID` wiring.

## Capabilities

None — no spec-level capability changes. This is a dev-infra tooling/refactor that aligns the
Makefile to an already-shipped behavior; externally visible behavior (correct UID/GID mapping on
rootless engines) is preserved, not newly specified. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- Files: `Makefile`, `scripts/opencode-dev` (refactor), new `scripts/compose-env.sh`.
- Affected targets: `build`, `up`, `down`, `shell`, `opencode`, `dev`, `install`, `db-psql`, `logs`,
  `test-python`, `test-infra`.
- No image rebuild, no schema change, no persistent state. `make test-config`
  (`docker compose config --quiet`) now validates the merged engine-aware stack.
- `scripts/dev-stack.sh` (`make stack`) is intentionally NOT changed here (separate follow-up).

## Alternatives considered

- **A. Shared helper `scripts/compose-env.sh` sourced by both Makefile and `scripts/opencode-dev`**
  (CHOSEN): single source of truth, minimal diff, keeps `make test-shell` docker-free, no logic
  duplication. Replicates the exact detection logic already proven in `scripts/opencode-dev`
  (Tier-1: `scripts/opencode-dev` lines 28-61 + `docker-compose.rootless-docker.yml` /
  `docker-compose.podman.yml` evidence in repo).
- **B. Delegate each Makefile target to `scripts/opencode-dev`** (extend it with `--build`/`--down`/
  `--shell` modes): rejected — `scripts/opencode-dev` is a one-shot `up`-then-`exec` launcher;
  `make build`/`make down` don't fit that model and it forces a larger refactor of a working launcher
  for no behavior gain (Tier-1: `scripts/opencode-dev` interface).
- **C. Copy the detection bash into the Makefile**: rejected — duplicates logic, drift risk, violates
  the single-source-of-truth intent of the ticket (Tier-1: DIA-260826-766f body).
- **Status-quo / do nothing**: rejected — leaves the UID/GID wiring mismatch on rootless engines, so
  `make` and `scripts/opencode-dev` produce different containers (Tier-1: ticket body).
  Chosen option: A — shared helper — because it makes the Makefile use the literal same `COMPOSE_FILE`
  computation as the canonical launcher, with the smallest diff and zero new daemon dependency at
  parse time.

## Testing Decisions

What makes a good test for this change: a test that proves the Makefile and `scripts/opencode-dev`
resolve to the IDENTICAL engine-aware `COMPOSE_FILE` without invoking the docker daemon, and that the
Makefile no longer emits the dead `UID`/`GID` exports.

Modules tested:

- `scripts/compose-env.sh` (unit): mocked `command -v`/`readlink`/`grep` across engine/OS/override
  scenarios — asserts exact `COMPOSE_FILE` string and that `docker`/`podman` are never executed.
- Makefile (static assertion): asserts `export COMPOSE_FILE := $(shell scripts/compose-env.sh)` is
  present and the dead `UID`/`GID` lines are absent.

Prior art in the codebase:

- `scripts/__tests__/opencode-dev.bats` already mocks `docker version` / `/proc/version` to verify
  engine/OS detection and override selection (Tier-1: `dia-260821-x5nj-unified-docker-dev-runtime`
  design Seam 1/1b/2). The new `compose-env.bats` reuses the same mock pattern but targets the
  extracted helper, and adds a Makefile static check in the spirit of
  `scripts/check-opencode-docker.sh` (Tier-1: Makefile `test-opencode-docker` target).
- Primary gate = `make test-shell` (bats, Docker mocked, host-runnable). Secondary =
  `make test-infra` / `make test-config` (real daemon, validates merged stack).
