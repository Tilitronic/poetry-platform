# Design: Makefile uses the engine-aware compose stack

## Governing Constraints

- `AGENTS.md` §2.4 — dev-infra changes >~20 lines require OpenSpec; design.md must include test
  strategy + rollback plan.
- `AGENTS.md` §6 — container gates (DIA-094): this is dev-infra tooling, validated by
  `make test-shell` (Docker mocked) on the host; no running dev container required for the primary gate.
- ADR 8 (bash-3 compatibility) — `scripts/opencode-dev` and the new helper MUST be bash-3 compatible.
- `DIA-260826-766f` — fix UID/GID wiring mismatch Makefile vs compose.
- No `.sdd/` documents exist (glob empty); `architecture.md` is app-domain only and does not govern
  dev-infra compose wiring. No governing constraint is violated. The canonical source of truth is
  `scripts/opencode-dev` (Tier-1).

## Context

`scripts/opencode-dev` (introduced in `dia-260821-x5nj-unified-docker-dev-runtime`) is the canonical
engine-aware launcher. It computes `COMPOSE_FILE` = `docker-compose.yml` + `docker-compose.rootless-docker.yml`
(docker) or `docker-compose.podman.yml` (podman) + optional `docker-compose.wsl.yml`, then runs
`docker compose` against that merged set. The engine override files carry the runtime UID/GID mapping
(res040 §1-4). The Makefile's bare `docker compose` targets omit `COMPOSE_FILE`, so they miss the
override and run with base-only wiring — the mismatch. The Makefile also has dead `UID`/`GID`/
`export UID`/`export GID` lines (36-39) never used by any target.

## Goals / Non-Goals

**Goals:**

- Make every Makefile `docker compose` target use the identical engine-aware `COMPOSE_FILE` as
  `scripts/opencode-dev`.
- Single source of truth for engine/OS detection (one helper, sourced by both).
- Keep `make test-shell` host-runnable (no docker daemon at Makefile parse time).
- Remove the dead `UID`/`GID` Makefile lines.

**Non-Goals:**

- Changing `docker-compose.yml`, the engine override files, `Dockerfile.dev`, or `.env`
  `USER_UID`/`USER_GID` wiring.
- Pulling the config-validation / secrets-ownership preflights from `scripts/opencode-dev` into the
  Makefile (Future work).
- Aligning `scripts/dev-stack.sh` (`make stack`) — separate follow-up ticket (Future work).

## Decisions

**D1 — Shared helper `scripts/compose-env.sh`.** New bash-3 script that prints the merged
`COMPOSE_FILE` and is sourced by both the Makefile (top-level `export COMPOSE_FILE := $(shell scripts/compose-env.sh)`)
and `scripts/opencode-dev` (refactored to source it). Rationale: single source of truth, minimal diff,
no logic duplication. Alternatives B (delegate) and C (inline in Makefile) rejected in proposal.md.

**D2 — Docker-free detection at compute time.** The helper MUST NOT invoke `docker`/`podman`. Engine:
if `COMPOSE_ENGINE` env override is set use it; else `command -v docker` + `readlink -f "$(command -v docker)"`
(path contains `podman` → podman, else docker); if no docker client present, default `docker`. OS:
`grep -qiE 'microsoft|wsl' /proc/version` (docker-free). Rationale: the helper runs at every `make`
parse via `$(shell ...)`; `make test-shell` is host-runnable and must stay docker-free (Tier-1:
Makefile `test-shell` target has no docker prerequisite). Only `command -v`/`readlink`/`grep` are used
— no daemon call.

**D3 — Exact override mapping (replicated from `scripts/opencode-dev` lines 45-60).** docker →
`docker-compose.rootless-docker.yml` (`user: '0:0'`); podman → `docker-compose.podman.yml`
(`userns_mode: keep-id` + `security_opt: label=disable`); if os=wsl → append `docker-compose.wsl.yml`.
`COMPOSE_FILE` joined by `:` (e.g. `docker-compose.yml:docker-compose.rootless-docker.yml`).
Rationale: byte-for-byte the same merged set the canonical launcher uses, so `make` and
`scripts/opencode-dev` produce the same container.

**D4 — Global Makefile export.** One `export COMPOSE_FILE := $(shell scripts/compose-env.sh)` near the
top of the Makefile replaces the dead `UID`/`GID` lines and covers all bare `docker compose` targets
automatically. Rationale: minimal diff, no per-target edits, no future drift.

**D5 — `scripts/opencode-dev` refactor is behavior-preserving.** It sources `scripts/compose-env.sh`
for `COMPOSE_FILE` and keeps its existing preflights (config validation + secrets-ownership) and
`up`/`exec` flow. Output-equivalent to current behavior; verified by the bats test covering both paths.

## Risks / Trade-offs

- **R1 Detection differs from current `scripts/opencode-dev` (uses `docker version` grep).** →
  Mitigation: helper uses `readlink -f` podman probe instead of `docker version` so it is docker-free;
  the mapping result is identical for the real cases (podman shim vs docker). `COMPOSE_ENGINE` override
  covers any mis-detection. Unit test asserts equivalence.
- **R2 `make test-shell` accidentally gains a docker dependency.** → Mitigation: helper never calls
  docker (D2); on a docker-less host it defaults to `docker` and emits a harmless unused string.
  Verified by the unit test asserting no `docker`/`podman` execution.
- **R3 Bad `COMPOSE_FILE` breaks `make up`.** → Mitigation: `docker compose config` (run by
  `make test-config`) validates the merged set; `make up` fails fast on invalid merge. Rollback is
  trivial (R4).
- **R4 Rollback complexity.** → Mitigation: three files only; `git revert` restores prior state. No
  migration, no schema, no persistent state.

## Seams

### Seam 1: Engine/OS detection (extracted)

- **Location:** `scripts/compose-env.sh`
- **Contract:** input = `COMPOSE_ENGINE`/`COMPOSE_OS` overrides + host `command -v docker`/`readlink -f`/
  `/proc/version`; output = merged `COMPOSE_FILE` string on stdout; never invokes docker/podman.
- **Test:** `scripts/__tests__/compose-env.bats` mocks `command -v`/`readlink`/`grep` and asserts exact
  `COMPOSE_FILE` per scenario + no docker/podman execution.

### Seam 2: Makefile COMPOSE_FILE export

- **Location:** `Makefile` top-level `export COMPOSE_FILE := $(shell scripts/compose-env.sh)`
- **Contract:** every bare `docker compose` target inherits `COMPOSE_FILE`; dead `UID`/`GID` lines removed.
- **Test:** static assertion in `scripts/__tests__/compose-env.bats` (or a
  `check-makefile-compose-parity.sh` in the spirit of `scripts/check-opencode-docker.sh`) greps the
  Makefile for the export and absence of dead lines.

### Seam 3: `scripts/opencode-dev` sourcing (behavior-preserving)

- **Location:** `scripts/opencode-dev`
- **Contract:** sources `scripts/compose-env.sh` for `COMPOSE_FILE`; preflights + `up`/`exec` unchanged.
- **Test:** `scripts/__tests__/opencode-dev.bats` (existing) continues to pass; add an assertion that
  `COMPOSE_FILE` equals the helper's output.

## Test Strategy

### Primary gate — `make test-shell` (bats, Docker mocked, host-runnable)

- **`scripts/__tests__/compose-env.bats`** (new): unit-tests `scripts/compose-env.sh` across:
  (1) default docker+native → `docker-compose.yml:docker-compose.rootless-docker.yml`;
  (2) podman → `...:docker-compose.podman.yml`; (3) wsl → append `docker-compose.wsl.yml`;
  (4) `COMPOSE_ENGINE=podman` override; (5) no docker client → defaults to docker. Asserts the helper
  never executes `docker`/`podman` (docker-free).
- **Static Makefile assertion** (new, in same bats file or a `check-makefile-compose-parity.sh` wired
  into `test-shell`): Makefile exports `COMPOSE_FILE` via `$(shell scripts/compose-env.sh)` and the dead
  `UID`/`GID`/`export UID`/`export GID` lines are gone.

### Secondary gate — `make test-infra` / `make test-config` (real daemon)

- `make test-config` runs `docker compose config --quiet` which now validates the merged engine-aware
  stack (bonus coverage).
- `make test-infra` ends in `docker compose down` using the merged stack; if a daemon is present it
  exercises the real engine override. Not required every run (heavy).

### Limitation

Mock tests prove the resolved `COMPOSE_FILE` and Makefile wiring, not runtime UID/GID behavior. Runtime
UID/GID mapping is already covered by `scripts/__tests__/engine-override-uid.bats` (from
`dia-260821-x5nj`) and is unchanged by this ticket.

## Migration Plan

### Deploy

1. Add `scripts/compose-env.sh` (bash-3, executable).
2. Refactor `scripts/opencode-dev` to source it for `COMPOSE_FILE`.
3. Edit `Makefile`: remove dead `UID`/`GID` lines (36-39); add
   `export COMPOSE_FILE := $(shell scripts/compose-env.sh)` after the `.PHONY` line.
4. Add `scripts/__tests__/compose-env.bats` + wire the Makefile static check into `test-shell`.

### Rollback Plan

- `git revert` the three files (`Makefile`, `scripts/opencode-dev`, `scripts/compose-env.sh`); delete
  `scripts/compose-env.sh` and the new bats file.
- No data migration, no schema change, no persistent state. Worst case if the helper mis-emits:
  `make up` fails fast on a bad `COMPOSE_FILE`, or falls back to the docker default (pre-fix base-only
  wiring) — never data loss. Trivially reversible.

## Open Questions / Future Work

- **F1:** Align `scripts/dev-stack.sh` (`make stack`) to source `scripts/compose-env.sh` (currently uses
  bare `docker compose`). Separate follow-up ticket.
- **F2:** Optionally pull the config-validation + secrets-ownership preflights from `scripts/opencode-dev`
  into the Makefile `up`/`shell`/`opencode` targets for full parity. Separate follow-up; out of scope
  here to keep the diff minimal.
