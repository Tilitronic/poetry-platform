## Purpose

Defines a host-side engine contract so Docker and Podman can operate the same development stack while DIA-094 remains a strict, executable readiness gate.

## ADDED Requirements

### Requirement: Authoritative container-engine selection

The host-side container-engine adapter SHALL accept `COMPOSE_ENGINE=docker` or `COMPOSE_ENGINE=podman` as an authoritative selection. When the variable is unset, it SHALL autodetect one engine. An explicit selection SHALL use the selected native compose command for every host-side engine operation: `docker compose` for Docker and `podman compose` for Podman. The adapter SHALL reject an unsupported explicit value with an actionable engine-selection error.

#### Scenario: Explicit Podman selection uses native Podman compose

- **WHEN** `COMPOSE_ENGINE=podman` is set for a host-side engine operation
- **THEN** the operation uses `podman compose`
- **AND** it does not invoke `docker compose`
- **AND** the selection seam reports Podman as the selected engine

#### Scenario: Explicit Docker selection uses native Docker compose

- **WHEN** `COMPOSE_ENGINE=docker` is set for a host-side engine operation
- **THEN** the operation uses `docker compose`
- **AND** it does not invoke `podman compose`
- **AND** the selection seam reports Docker as the selected engine

#### Scenario: Autodetection selects an available engine

- **WHEN** `COMPOSE_ENGINE` is unset and the host exposes one detectable supported engine
- **THEN** the adapter selects that engine before the operation runs
- **AND** the operation uses that engine's native compose command
- **AND** the selection seam reports the selected engine

#### Scenario: Unsupported explicit engine is rejected

- **WHEN** `COMPOSE_ENGINE` has a value other than `docker` or `podman`
- **THEN** the adapter exits nonzero before invoking a compose operation
- **AND** its error identifies the invalid engine selection and the accepted values
- **AND** the selection seam reports no selected engine

### Requirement: Unified host-side engine operations

The adapter SHALL be the sole host-side contract for compose config, up, down, exec, engine reachability, and dev-service status operations. Host-side callers SHALL use the selected engine through this contract. Commands already executing inside the dev container SHALL remain unchanged.

#### Scenario: Selected engine is used for every host-side compose operation

- **WHEN** a host-side caller requests compose config, up, down, exec, reachability, or dev-service status
- **THEN** the caller uses the command selected by the adapter
- **AND** no direct host-side command for the other engine is invoked
- **AND** the host-operation contract seam records the requested operation and selected engine

#### Scenario: In-container command behavior is preserved

- **WHEN** a command runs from inside the dev container
- **THEN** it does not require the host-side engine adapter to execute that in-container command
- **AND** the in-container execution seam preserves its existing command behavior

### Requirement: Strict DIA-094 executable dev-service gate

The DIA-094 host gate SHALL succeed only when the selected engine is reachable, the selected compose stack reports the `dev` service running, and a non-mutating selected-engine `compose exec -T dev true` succeeds. The gate SHALL NOT treat dev-service status alone as sufficient proof of readiness.

#### Scenario: Running and executable dev service passes the gate

- **WHEN** the selected engine is reachable
- **AND** its compose stack reports `dev` running
- **AND** `compose exec -T dev true` succeeds through the selected engine
- **THEN** the DIA-094 host gate succeeds
- **AND** the readiness-gate seam records successful engine, status, and exec checks

#### Scenario: Selected engine is unavailable

- **WHEN** the selected engine cannot be reached
- **THEN** the DIA-094 host gate exits nonzero
- **AND** its error identifies an engine-reachability failure
- **AND** it does not try the other engine
- **AND** the readiness-gate seam records the engine failure

#### Scenario: Dev service is not running

- **WHEN** the selected engine is reachable
- **AND** its compose stack does not report `dev` running
- **THEN** the DIA-094 host gate exits nonzero
- **AND** its error identifies a dev-service-status failure
- **AND** it does not try the other engine
- **AND** the readiness-gate seam records the status failure

#### Scenario: Dev service cannot execute a non-mutating command

- **WHEN** the selected engine is reachable
- **AND** its compose stack reports `dev` running
- **AND** `compose exec -T dev true` fails
- **THEN** the DIA-094 host gate exits nonzero
- **AND** its error identifies a dev-service-exec failure
- **AND** it does not try the other engine
- **AND** the readiness-gate seam records the exec failure
