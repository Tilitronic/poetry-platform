# Tasks: Makefile uses the engine-aware compose stack

## 1. Shared helper

- [ ] 1.1 Create `scripts/compose-env.sh` (bash-3 compatible, executable)
  - Docker-free engine detection: `COMPOSE_ENGINE` override, else `command -v docker` + `readlink -f`
    podman probe, default `docker` if no client; OS via `grep -qiE 'microsoft|wsl' /proc/version`.
  - Replicate exact mapping from `scripts/opencode-dev` lines 45-60: docker →
    `docker-compose.rootless-docker.yml`; podman → `docker-compose.podman.yml`; wsl → append
    `docker-compose.wsl.yml`; join with `:`.
  - Print merged `COMPOSE_FILE` to stdout; never invoke `docker`/`podman`.
  - Acceptance: script exists, is executable, prints correct `COMPOSE_FILE` for default/override/no-client
    scenarios under mocked `command -v`/`readlink`/`grep`; never executes `docker`/`podman`.
  - Depends on: none
  - Blocks: 1.2, 2.1, 3.1

- [ ] 1.2 Create `scripts/__tests__/compose-env.bats` (unit + static Makefile assertion)
  - Mock `command -v`/`readlink`/`grep`; assert exact `COMPOSE_FILE` for: default docker+native,
    podman, wsl, `COMPOSE_ENGINE=podman`, no docker client.
  - Assert helper never executes `docker`/`podman` (docker-free).
  - Static check: Makefile exports `COMPOSE_FILE` via `$(shell scripts/compose-env.sh)`; dead `UID`/`GID`/
    `export UID`/`export GID` lines absent.
  - Acceptance: bats passes under the Docker-mocked harness (`make test-shell`); all assertions hold.
  - Depends on: 1.1
  - Blocks: 1.3, 3.1

- [ ] 1.3 Wire the Makefile static check into `make test-shell`
  - Invoke the static assertion from 1.2 via `bats-wrapper.sh` (or a `check-makefile-compose-parity.sh`
    in the spirit of `scripts/check-opencode-docker.sh` added to the `test-shell` prerequisites).
  - Acceptance: `make test-shell` fails if the Makefile drifts (missing export or dead lines return).
  - Depends on: 1.2
  - Blocks: 3.1

## 2. Makefile parity

- [ ] 2.1 Edit `Makefile`: remove dead `UID`/`GID` lines (36-39) and add global `COMPOSE_FILE` export
  - Delete `UID := $(shell id -u)`, `GID := $(shell id -g)`, `export UID`, `export GID`.
  - Add `export COMPOSE_FILE := $(shell scripts/compose-env.sh)` after the `.PHONY` line (line 28).
  - Acceptance: `make -n up`/`make -n build`/`make -n shell`/`make -n opencode`/`make -n down` show bare
    `docker compose` invocations that inherit `COMPOSE_FILE` (no `-f` needed); dead lines gone;
    `make test-shell` still runs docker-free.
  - Depends on: 1.1
  - Blocks: 3.1, 4.2

## 3. Launcher refactor (behavior-preserving)

- [ ] 3.1 Refactor `scripts/opencode-dev` to source `scripts/compose-env.sh` for `COMPOSE_FILE`
  - Replace inlined detection (lines 28-61) with `source "${launcher_dir}/compose-env.sh"` (or
    `eval "export COMPOSE_FILE=$(...)"`); keep preflights (config validation + secrets-ownership) and
    `up`/`exec` flow unchanged.
  - Acceptance: `scripts/opencode-dev` produces identical `COMPOSE_FILE` to the helper (asserted by
    extended `opencode-dev.bats` or `compose-env.bats`); preflights + `up`/`exec` unchanged;
    `make test-shell` passes.
  - Depends on: 1.1, 1.2, 1.3, 2.1
  - Blocks: 4.1

## 4. Verification

- [ ] 4.1 Run `make test-shell` (primary gate)
  - Acceptance: green (new `compose-env.bats` + Makefile static check pass).
  - Depends on: 3.1
  - Blocks: none

- [ ] 4.2 Run `make test-config` (secondary gate, validates merged stack)
  - Acceptance: green — `docker compose config --quiet` validates the merged engine-aware stack.
  - Depends on: 2.1
  - Blocks: none

## Blocking Edges Summary

```
1.1 → 1.2, 2.1, 3.1
1.2 → 1.3, 3.1
1.3 → 3.1
2.1 → 3.1, 4.2
3.1 → 4.1
```

## Critical Path

1.1 → 1.2 → 1.3 → 3.1 → 4.1 (primary gate)
1.1 → 2.1 → 4.2 (secondary gate)

## Parallel Opportunities

- 1.1 can start immediately (no blockers).
- 1.2 and 2.1 can run in parallel after 1.1.
- 1.3 and 3.1 can run in parallel after 1.2 + 2.1.
- 4.1 and 4.2 are independent final gates after their respective dependencies.
