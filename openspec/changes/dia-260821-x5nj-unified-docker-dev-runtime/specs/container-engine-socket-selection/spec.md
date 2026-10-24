# Delta Spec: Container Engine Socket Selection (REMOVED)

The entire capability is removed. Every requirement below was implemented solely by
the retired `tools/opencode-docker` launcher, which was physically deleted in PHASE 3
(commit 63d6478). No implementer survives in the repository, so the behavior contract
is retired rather than rewritten.

## REMOVED Requirements

### Requirement: Socket probe order

**Reason:** The socket probe order was implemented only by the `tools/opencode-docker` launcher (retired, PHASE 3 commit 63d6478). The unified runtime never mounts an in-container engine socket, so there is nothing to probe.

**Migration:** Host-side engine orchestration is provided by the shared engine contract: `scripts/container-engine.sh` selects the native compose command and `scripts/compose-env.sh` computes the merged compose file without probing or mounting any socket (ADR 11; DIA-260824-iirx decision 3).

### Requirement: Engine socket opt-in (default off)

**Reason:** The `-E` / `--with-engine` flag and its sentinel behavior existed only in the retired launcher. With no engine socket mounted by design, the opt-in flag has no implementer or consumer.

**Migration:** No replacement flag. Infrastructure orchestration stays host-side and explicit; in-container tooling does not receive engine API authority (ADR 11; DIA-260824-iirx decision 3).

### Requirement: Podman socket failure handling

**Reason:** This diagnostic path belonged to the retired launcher's socket mount logic. It cannot occur once no socket is mounted.

**Migration:** Engine reachability is handled host-side by `scripts/container-engine.sh`, which fails closed with a distinct diagnostic and never falls back to another engine (`container_engine_gate`).

### Requirement: Socket authority documentation

**Reason:** The documentation requirement targeted `tools/opencode-docker/README.md`, which was deleted with the launcher (PHASE 3 commit 63d6478).

**Migration:** The unified runtime's security posture is documented by ADR 11: no engine socket is mounted, and engine access requires no in-container authority. Nothing in-container needs the socket-authority warning because no socket exists.

### Requirement: Migration guide documentation

**Reason:** The migration guide targeted `tools/opencode-docker/README.md` (deleted). There is no legacy launcher left to migrate from.

**Migration:** `docs/docker-dev.md` documents the unified runtime bring-up; no per-launcher migration guide is maintained.

### Requirement: Test coverage for socket selection

**Reason:** The referenced suite `scripts/__tests__/opencode-docker.bats` no longer exists; the launcher under test was retired.

**Migration:** The surviving host-side engine contract is covered by the `scripts/container-engine.sh` surface and its host tests. No socket-selection tests are maintained.

### Requirement: Platform verification evidence

**Reason:** The requirement asserted Fedora/WSL verification through the retired launcher's socket path, which no longer exists.

**Migration:** Platform verification now targets the unified runtime (`Dockerfile.dev` + engine-aware host scripts) as specified by the `unified-dev-container` capability.
