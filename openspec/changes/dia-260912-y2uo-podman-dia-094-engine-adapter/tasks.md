# Tasks: Podman support for the DIA-094 container-engine adapter

**Governing ticket:** DIA-260912-y2uo "podman support for DIA-094 container-engine adapter with engine-neutral checks, hard-fail preserved"

## 1. Selected-engine contract

- [x] 1.1 **Blockers: none. Depends on `.sdd/dev-infra/architecture.md` ADR 8.** In separate RED and GREEN coder instances, establish the bash-3 host engine contract and its focused Bats seam. Acceptance: `COMPOSE_ENGINE=docker` and `COMPOSE_ENGINE=podman` are authoritative, use their respective native compose commands, reject invalid explicit values clearly, and autodetection works when the override is absent without making a daemon call during compose-file computation.

## 2. Unified host-side operations

- [x] 2.1 **Blockers: 1.1. Depends on `.sdd/dev-infra/architecture.md` ADR 8.** In separate RED and GREEN coder instances, migrate every host-side compose config, up, down, exec, reachability, and dev-status operation to the selected-engine contract. Acceptance: command-recording tests prove each operation uses the one selected engine with no direct bypass or cross-engine invocation; commands already inside the dev container keep their existing behavior.

## 3. Strict DIA-094 readiness gate

- [x] 3.1 **Blockers: 1.1, 2.1. Depends on `.sdd/dev-infra/architecture.md` ADR 8.** In separate RED and GREEN coder instances, make the pre-commit DIA-094 path require selected-engine reachability, selected-stack `dev` running status, and non-mutating `compose exec -T dev true`. Acceptance: focused Bats tests demonstrate success only when all three checks pass; engine, status, and exec failures each hard-fail with distinct actionable diagnostics; no failed check falls back to the other engine.

## 4. Verify selected-engine behavior

- [x] 4.1 **Blockers: 1.1, 2.1, 3.1.** Run the host shell suite and a real selected-engine acceptance check. Acceptance: `make test-shell` passes, the selected engine reports the `dev` service running, `compose exec -T dev true` succeeds through the selected native command, and the recorded evidence identifies the selected engine and command outcomes.
