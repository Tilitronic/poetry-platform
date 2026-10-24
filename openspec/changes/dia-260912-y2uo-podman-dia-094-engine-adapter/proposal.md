# Proposal: Podman support for the DIA-094 container-engine adapter

**Governing ticket:** DIA-260912-y2uo "podman support for DIA-094 container-engine adapter with engine-neutral checks, hard-fail preserved"

**Gate:** DIA-104 interview continuation. Trigger: cross-cutting host-side engine operations and a hard-to-reverse commit gate. The developer confirmed Q1-Q5 before synthesis.

**Ownership:** substance: developer; structure: AI; interview_depth: compressed; interview_reason: Developer supplied and confirmed the five governing decisions, then explicitly requested synthesis.

## Why

DIA-094 currently assumes Docker command syntax in host-side commit-gate operations. A Podman host needs an explicit, engine-neutral adapter that preserves the hard fail when the selected engine cannot reach a usable dev service.

## What Changes

- Add one host-side container-engine contract selected by authoritative `COMPOSE_ENGINE=docker|podman`, with autodetection only when the override is unset.
- Route every host-side engine operation through that contract: compose config, up, down, exec, engine reachability, and dev-service status.
- Invoke native `podman compose` for Podman and `docker compose` for Docker. In-container commands remain unchanged.
- Strengthen the DIA-094 host gate to require both a running `dev` service and non-mutating `compose exec -T dev true` success.
- Fail hard without fallback when the selected engine is unavailable, the dev service is not running, or the dev service cannot execute; diagnose engine, status, and exec failures distinctly.

## Capabilities

### New Capabilities

- `host-container-engine-adapter`: Selects and consistently invokes the host container engine for compose operations and the DIA-094 dev-service readiness gate.

### Modified Capabilities

- None.

## Impact

- **Affected systems:** host-side compose callers, `scripts/verify-pre-commit.sh`, and related shell-test seams.
- **Compatibility:** Docker keeps `docker compose`; Podman uses `podman compose`; commands already executing in the dev container do not change.
- **Governing references:** `.sdd/dev-infra/architecture.md` ADR 8 requires bash-3-compatible infrastructure scripts. `openspec/specs/container-engine-socket-selection/spec.md` defines the existing Podman/Docker socket context. `scripts/compose-env.sh` already establishes the `COMPOSE_ENGINE` selection vocabulary and compose-file mapping.
- **Rollback:** revert the adapter and its shell tests together. This restores the prior Docker-only host path; no data, migration, or persistent state is involved.

## Testing Decisions

A good test proves the selected engine command is used consistently for each host-side operation and proves the hard gate cannot pass from `compose ps` alone. Existing Bats shell tests and their command-recording mocks are the prior-art seam for host-side compose invocation. The test suite must cover Docker and Podman selection, explicit override precedence, autodetection when no override exists, no cross-engine fallback, and distinct engine/status/exec failures. A real selected-engine acceptance run must demonstrate a running `dev` service plus `compose exec -T dev true` success.

## Alternatives considered

- **Native selected-engine adapter (chosen):** run `docker compose` for Docker and `podman compose` for Podman through one host-side contract. Evidence: developer interview Q1-Q5; Tier-1 `scripts/compose-env.sh` already exposes `COMPOSE_ENGINE` and engine-specific compose files.
- **Docker-compatible API path for both engines:** keep `docker compose` even for Podman. Rejected by developer interview Q4 because the engine override should select the native engine command, not an API compatibility layer.
- **Automatic fallback to the other engine:** rejected by developer interview Q5 because it could operate on a different stack and conceal a broken selected engine.
- **Status-only DIA-094 check:** rejected by developer interview Q3 because a listed service can still reject execution.
- **Status-quo / Docker-only host calls:** rejected because Podman cannot satisfy the host gate through an engine-neutral contract.

Chosen option: native selected-engine adapter with a two-part hard gate, because developer interview Q1-Q5 requires an authoritative engine choice and proof that the selected dev service can execute commands.
