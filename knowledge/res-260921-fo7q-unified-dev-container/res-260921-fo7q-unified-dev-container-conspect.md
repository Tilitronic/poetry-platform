# Unified Dev Container with Podman: Single-Container Pattern, Runtime Split, GPU/Debug, and Auth Handling

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 14
phase-a-failures: 1
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Scope and Verdict

This conspect synthesizes 14 archived sources on building one unified
single-container devcontainer that runs on both Fedora (native Podman) and
WSL2 (Podman machine / remote), with GPU and debug sidecars and safe auth
handling for an isolated `/home/dev` user. One candidate source was
blocked and is excluded (see "Unarchived/Excluded").

Verdict: use an image/Dockerfile-based single primary container (not a
Compose-based environment) as the unified baseline, add Podman shims
(`podman-docker` on Fedora, `dockerPath=podman` plus a Compose provider in
VS Code) for Docker-assuming tooling, branch only the runtime plumbing
between Fedora and WSL2, inject GPUs via CDI device strings (not
`--gpus`), enable debugging via `capAdd`/`runArgs`, and pass agent auth
(auth.json) by bind-mount plus copy (mode 0600), never by baking secrets
into the image.

## 2. Unified Single-Container Devcontainer Pattern

### 2.1 Spec primitives

The Development Container Specification defines an "environment" as one or
more development containers plus any sidecars, managed as one unit from a
single metadata set, so multiple environments can be created from the same
configuration ("Dev Container Specification"). Metadata lives in
`devcontainer.json` (searched at `.devcontainer/devcontainer.json`,
`.devcontainer.json`, then `.devcontainer/<folder>/devcontainer.json`) and
select properties can also ship inside the image as a `devcontainer.metadata`
label holding an array of snippets merged at creation time, with defined
merge rules (union for `capAdd`/`securityOpt`/`forwardPorts`, last-wins for
`containerUser`/`remoteUser`/`waitFor`/`hostRequirements`, per-variable
last-wins for `containerEnv`/`remoteEnv`) ("Dev Container Specification").

Three orchestration options exist:

- Image-based: only required parameter is `image`, pulled via the engine
  ("Dev Container Specification").
- Dockerfile-based: only required parameter is `build.dockerfile`, with
  `build.context`, `build.args`, `build.target`, `build.cacheFrom` controls
  ("Dev Container Specification"; "Dev Container Metadata Reference").
- Docker Compose-based: requires `dockerComposeFile` plus `service` naming
  the main container tools connect to, with optional `runServices`
  subsetting ("Dev Container Specification"; "Dev Container Metadata
  Reference").

For the unified pattern, prefer image- or Dockerfile-based configuration.
It keeps one primary container, avoids Compose-provider divergence (see
section 3.4), and still permits optional sidecars via the environment
notion when truly needed. Compose stays available for multi-service cases
(app plus database) with `service: app` and
`shutdownAction: stopCompose`, but it is the exception, not the baseline
("Dev Container Specification"; "Use Podman with VS Code Dev Containers").

Tooling evidence: the reference CLI was at version 0.89.0 at capture time
("@devcontainers/cli" registry entry), so pin `@devcontainers/cli` when
scripting unified-container builds rather than floating on `latest`.

### 2.2 What to set in `devcontainer.json`

- `image` or `build.dockerfile`: single source of truth for language,
  package manager, and tooling, so an agent inside the box cannot reach
  for whatever binary the host happens to have ("Opencode in Devcontainers";
  "Dev Container Metadata Reference").
- `features`: reusable build steps (example: `ghcr.io/devcontainers/features/git:1`,
  `ghcr.io/devcontainers/features/github-cli:1`, or an opencode feature
  such as `ghcr.io/dirien/devcontainer-features/opencode:0`) applied as a
  secondary build step, with `overrideFeatureInstallOrder` when ordering
  matters ("Dev Container Specification"; "Use Podman with VS Code Dev
  Containers"; "Dirien devcontainer-features: opencode").
- `mounts` (cross-orchestrator, Docker CLI `--mount` syntax) and
  `workspaceMount`/`workspaceFolder`: guarantee source lives outside the
  container so in-flight edits survive container replacement; `workspaceFolder`
  may be a sub-folder of the mount, which matters for monorepos
  ("Dev Container Specification"; "Dev Container Metadata Reference").
- `containerEnv` vs `remoteEnv`: `containerEnv` is baked at creation for
  every process (static for container life, needs rebuild to change);
  `remoteEnv` is applied by the supporting tool to its own processes
  (terminals, tasks) and can change without rebuild; `${containerEnv:PATH}`
  is the supported way to extend PATH in `remoteEnv` ("Dev Container
  Metadata Reference").
- `containerUser` vs `remoteUser`: the container user runs ENTRYPOINT; the
  remote user runs lifecycle scripts and tool processes and defaults to
  the container user ("Dev Container Specification"; "Dev Container
  Metadata Reference").
- `updateRemoteUserUID`: on Linux defaults to true, syncing the named
  user UID/GID to the local user to avoid bind-mount permission problems;
  implementations may skip it when no bind mounts are used or the engine
  translates IDs itself ("Dev Container Specification"; "Dev Container
  Metadata Reference"). Set false only for the authd/large-UID case (see
  section 6).
- Lifecycle scripts `onCreateCommand`, `updateContentCommand`,
  `postCreateCommand`, `postStartCommand`, `postAttachCommand` (string via
  `/bin/sh`, array direct-exec, or object for parallel named commands),
  gated by `waitFor` (default `updateContentCommand`); a failing script
  skips all later scripts ("Dev Container Specification"; "Dev Container
  Metadata Reference"). Keep `postCreateCommand` for user-scoped setup
  (secrets-adjacent work belongs there, not in `onCreateCommand`, which
  cloud prebuilds may run without user assets).
- `hostRequirements` (`cpus`, `memory`, `storage`, `gpu` with boolean,
  `"optional"`, or `{cores, memory}` object form): declare minimums so
  cloud backends size compute and local tools warn ("Dev Container
  Metadata Reference").
- Debug and init knobs: `capAdd: ["SYS_PTRACE"]`, `securityOpt`,
  `init` (tini against zombies), `privileged` (needed for Docker-in-Docker,
  security-sensitive especially on Linux), `runArgs` for raw engine args,
  `forwardPorts`/`portsAttributes`, `overrideCommand` (default true for
  image/Dockerfile, false for Compose) ("Dev Container Metadata Reference").

Security rationale for putting the agent in the container: the agent's
blast radius shrinks from the whole host (browser profile, SSH keys, saved
cards) to the project ("Opencode in Devcontainers").

## 3. Podman-vs-Docker Shims

### 3.1 Architecture split

Docker routes CLI calls through a persistent root daemon (`dockerd` to
containerd to OCI runtime); Podman runs daemonless (CLI to libpod to
`conmon` to OCI runtime), so each invocation loads state in-process and
detached containers outlive the CLI ("Podman vs Docker"; "Docker vs Podman:
A Hands-On Comparison"). Two corrections the sources stress: Docker does
support rootless via a rootless `dockerd` setup (it is opt-in, not
default), and Podman can expose a Docker-compatible API via
`podman system service` / `podman.socket` when clients demand a socket
("Podman vs Docker"). Practically, Podman is rootless-first on Fedora/RHEL
while Docker defaults to a root daemon, and only the file-ownership test
makes it visceral: a Docker bind-mount write lands root-owned on the host
while the Podman equivalent lands owned by the invoking user, because the
container's "root" is the user's UID mapped through user namespaces
(`uid_map`, `/etc/subuid`) ("Docker vs Podman: A Hands-On Comparison").

### 3.2 Command and image compatibility

Verb-for-verb parity (`run`, `ps`, `exec`, `build`, `logs`, `pull/push`,
`volume`, `network`, `login`, `save/load`) is deliberate, but identical
names do not mean identical defaults: retest networking, UID mapping,
SELinux labels, Compose provider behavior, and API integrations on your
exact files ("Docker-to-Podman Migration"; "Podman vs Docker"). Images are
the easy part: both engines consume OCI/Docker v2 from the same
registries, and most Dockerfiles build unchanged (`podman build`,
`Containerfile` accepted as a name), with BuildKit-only syntax the
documented breakage point ("Docker-to-Podman Migration"; "Podman vs
Docker"). Portable habit: fully qualify image names
(`docker.io/library/nginx:alpine`), because Podman registry resolution
follows distro config ("Docker vs Podman: A Hands-On Comparison").

Three shim patterns exist for automation that still says `docker`:

| Pattern | Mechanism |
|---|---|
| `podman-docker` package | `/usr/bin/docker` wrapper calling Podman; on RHEL links `/var/run/docker.sock` to the rootful Podman socket `/run/podman/podman.sock` (rootful only, not a rootless user socket) |
| Shell alias | `alias docker=podman` where no package exists |
| `podman system service` / socket | Docker-compatible REST API for socket readers |

("Podman vs Docker"; "Docker-to-Podman Migration".)

Rules: install Podman alongside Docker first and inventory with the real
Docker CLI (never the shim) before cutover; install `podman-docker` only
at cutover, after staging proves parity and the real Docker CLI/socket is
no longer needed for comparison ("Docker-to-Podman Migration"). The shim
prints an "Emulate Docker CLI using podman" notice (quiet via
`/etc/containers/nodocker`); `docker ps` under the shim lists
Podman-managed containers, which confuses inventories if enabled too early
("Docker-to-Podman Migration"; "Podman vs Docker").

### 3.3 Socket handling

| Mode | Socket |
|---|---|
| Podman rootful | `unix:///run/podman/podman.sock` |
| Podman rootless | `unix://${XDG_RUNTIME_DIR}/podman/podman.sock` |
| Legacy Docker path via `podman-docker` (RHEL, rootful) | `/var/run/docker.sock` to `/run/podman/podman.sock` |

("Docker-to-Podman Migration"; "Podman Compose with Podman".)

Enable persistently with `systemctl --user enable --now podman.socket`
plus `sudo loginctl enable-linger <USER>` so the rootless socket survives
logout, then `export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"`
for Docker-compatible clients ("Docker-to-Podman Migration"; "Use Podman
with VS Code Dev Containers"). Do not create global compatibility symlinks
until you know which tools need them and in which (rootful vs rootless)
context; audit every `docker.sock`/`DOCKER_HOST` consumer (Compose,
Testcontainers, CI runners, scanners, SDKs) against dockerd-specific
response assumptions, because speaking the Docker API is not full dockerd
fidelity ("Docker-to-Podman Migration"; "Podman vs Docker"). VS Code
guidance is explicit: `dev.containers.dockerPath: podman`,
`dev.containers.dockerComposePath: podman-compose`, and expose the Podman
socket only for tools that specifically need API access ("Use Podman with
VS Code Dev Containers").

### 3.4 Compose provider choice

`podman compose` is a thin wrapper that shells out to an external provider
(it parses nothing itself); the real workers are `docker-compose`,
`podman-compose` (Python, calls the Podman CLI directly, no Docker API
dependency, supports `x-podman` extensions), or `docker compose` pointed
at `podman.socket` ("Podman Compose with Podman"; "Podman vs Docker").
Precedence when both are installed favors `docker-compose`; pin with
`PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose` (per-session/CI) or
`compose_providers` in `containers.conf` (persistent)
("Podman Compose with Podman"). On RHEL 10, `podman-compose` 1.5.0 comes
from EPEL; a bare host prints "looking up compose provider failed" until a
provider is installed ("Podman Compose with Podman").

Tested 1.5.0 behaviors that break naive migrations:

- `in_pod` defaults true (a `pod_<project>` pod is created) but default
  pod args are `--infra=false --share=` (no namespaces shared), so
  `localhost:80` between services fails; use service-name DNS
  (`web.dns.podman`) and add `x-podman.pod_args: [--share=net]` only when
  shared localhost is deliberate; opt out with `--in-pod=false` or
  `x-podman.in_pod: false` ("Podman Compose with Podman").
- Top-level `networks` declared but unreferenced attaches differently than
  Docker Compose's implicit `default` network; fix with
  `x-podman.default_net_behavior_compat: true` or the
  `docker_compose_compat: true` bundle ("Podman Compose with Podman").
- Generated names use underscores (`project_service_1`) vs Docker's
  hyphens; fix with `x-podman.name_separator_compat: true`, or better stop
  hard-coding generated names and use service DNS/labels ("Podman Compose
  with Podman").
- Provider gaps remain (examples on 1.5.0: `volume.nocopy`, some
  build-secret forms, `depends_on`/health nuances); validate `build`,
  `depends_on`, volumes, mounts, networks, `env_file`, profiles, restart,
  secrets, and GPU passthrough per file with `podman-compose config` plus
  a staged up ("Podman Compose with Podman"; "Docker-to-Podman Migration").

This provider matrix is exactly why the unified devcontainer baseline
should avoid Compose: one Compose file can behave three ways depending on
which provider resolved it.

### 3.5 Restart, systemd, storage, secrets, Swarm

- Restart: `podman run --restart=always` covers container exits; host-reboot
  recovery is separate via `podman-restart.service`
  (`podman start --all --filter should-start-on-boot=true`), while
  systemd-managed services should use Quadlet `[Service] Restart=` instead
  of stacking systemd atop `--restart` ("Docker-to-Podman Migration").
  Quadlet `.container` units (also `.pod`/`.volume`/`.network`) give
  declarative `systemctl enable --now` services with journald integration;
  Docker has no first-party equivalent ("Podman vs Docker"; "Docker vs
  Podman: A Hands-On Comparison"). Rootless boot start additionally needs
  `loginctl enable-linger` ("Docker vs Podman: A Hands-On Comparison").
- Volumes: never copy `/var/lib/docker/volumes/*` into Podman storage
  (different metadata); export application bytes (tar/dump/rsync,
  database-native quiesce for live DBs), `podman volume create`, restore
  through a temp container ("Docker-to-Podman Migration").
- Bind mounts: `-v` syntax is identical, but on SELinux hosts add `:z`/`:Z`
  only with understanding (shared vs private labeling), and Podman
  documents `--security-opt=label=disable` only for the CDI GPU case below,
  not as a general bind default ("Docker-to-Podman Migration").
- Networks: Docker bridge/DNS vs Netavark/aardvark-dns/pasta (rootless
  default); plan for changed names, DNS paths, rootless port publishing,
  and subnet collisions ("Podman vs Docker").
- Secrets: Swarm secrets and Podman secrets are different systems;
  recreate via `podman secret create` or per-provider Compose handling, never
  by copying Swarm paths ("Docker-to-Podman Migration").
- Swarm (`swarm`, `service`, `stack`, `node`) has no Podman equivalent;
  pods are single-host localhost groupings, not a scheduler; plan
  Kubernetes/OpenShift separately ("Docker-to-Podman Migration"; "Podman vs
  Docker").
- CI triage: CLI-only jobs swap trivially; socket/BuildKit/auth/GPU jobs
  need staged testing; grep pipelines for `docker`, `docker.sock`,
  `DOCKER_HOST`, `docker compose`, `docker buildx`, `--gpus`, `docker
  login/push` and classify before switching ("Docker-to-Podman Migration").

## 4. Fedora-vs-WSL Runtime Split

Keep one `devcontainer.json`; branch only the engine plumbing.

Fedora/native Linux: Podman runs natively, VS Code points at `podman` /
`podman-compose`, rootless socket comes from
`systemctl --user enable --now podman.socket`, and `--userns=keep-id`
(with `containerUser`/`remoteUser`) fixes bind-mount ownership ("Use
Podman with VS Code Dev Containers"; "Docker-to-Podman Migration").
Privileged ports below 1024 are the characteristic rootless wall
(`rootlessport cannot expose privileged port`); use ports >= 1024 or tune
`net.ipv4.ip_unprivileged_port_start`, optionally behind a proxy
("Docker vs Podman: A Hands-On Comparison").

WSL2: Podman runs inside a lightweight Linux VM (`podman machine init/start`,
`podman machine set --cpus/--memory`, `--rootful` only when a workflow
specifically needs it), and cross-distro setups use the documented
remote/socket approach with the full binary path in VS Code
(`dockerPath` must be the real podman-remote path, not a bare name, or VS
Code errors with "Dev Containers require Docker to run" / `spawn podman
EACCES`) ("Use Podman with VS Code Dev Containers"; "Podman Dev Containers
on WSL2"). Tested WSL2 rules:

- Force cgroups v2 via `%UserProfile%\.wslconfig`
  `[wsl2] kernelCommandLine = cgroup_no_v1=all` (fixes `stats is not
  supported in rootless mode without cgroups v2`) ("Podman Dev Containers
  on WSL2").
- `sudo mount -o remount,shared /` plus `podman system reset` cures the
  "/"-not-shared warning, but it is session-scoped: it reverts after
  `wsl --shutdown` and must be re-run ("Podman Dev Containers on WSL2").
- Keep `--userns=keep-id` in `runArgs` for rootless file creation issues
  ("Podman Dev Containers on WSL2").
- Never set `[boot] systemd=true` inside `podman-machine-default`: a
  maintainer states Podman with systemd in WSL is unsupported ("Podman
  doesn't work with systemd enabled in WSL. Please disable it."), and it
  breaks `podman machine start` ("Podman Dev Containers on WSL2").
- Keep code where the machine can see it: cross-WSL checkouts under
  `~/.` are invisible to a machine in another distro; `/mnt/wsl/` is the
  performant shared location (Windows-filesystem storage works but
  slower) ("Podman Dev Containers on WSL2").
- Match client and server versions exactly (a 4.x vs 5.x mismatch cost a
  reporter a day); `podman version` both ends before debugging startup
  ("Podman Dev Containers on WSL2").
- Parallel WSL 2.5.x race: a systemd user-session regression broke
  `systemctl --user` (`Failed to connect to bus`), `podman ps` (systemd
  cgroup-manager fallback warnings, missing shared mount, pause-process
  sandbox errors); maintainer diagnosis points at dbus-user-session /
  cgroup-v2 handling, with `loginctl enable-linger` / dbus workarounds,
  fixed in WSL >= 2.6.0 per the thread ("Rootless Podman Fails ... WSL
  2.5.x").

Net decision: Fedora path leans on user systemd units and lingering;
WSL2 path leans on the machine lifecycle plus remote/socket config, with
no systemd inside the machine.

## 5. GPU and Debug Sidecars

### 5.1 GPU via CDI

Docker's `--gpus all` does not translate; modern Podman uses CDI device
strings ("Docker-to-Podman Migration"). Toolkit support for generating CDI
specs starts at v1.12.0; since v1.18.0 a `nvidia-cdi-refresh` service
(`nvidia-cdi-refresh.path` trigger plus `.service` generator) keeps
`/var/run/cdi/nvidia.yaml` current across toolkit/driver installs and
reboots, tunable via `/etc/nvidia-container-toolkit/nvidia-cdi-refresh.env`,
troubleshot via `journalctl -u nvidia-cdi-refresh.service` and
`nvidia-ctk --debug cdi list`; it does not handle driver removal or MIG
reconfiguration (regenerate manually), and JIT-CDI (`mode: auto` on NVML
or WSL2) builds an in-memory spec instead of a persistent file ("NVIDIA
CDI Support"). Run form (Podman >= 4.1.0):

`podman run --rm --device nvidia.com/gpu=all --security-opt=label=disable ubuntu nvidia-smi -L`

with per-GPU/MIG selection (`--device nvidia.com/gpu=0`,
`--device nvidia.com/gpu=1:0`); `--security-opt=label=disable` is NVIDIA's
documented Podman example and may be required on SELinux hosts, subject to
site policy ("NVIDIA CDI Support"; "Docker-to-Podman Migration").
Prerequisite on the target host: `nvidia-ctk cdi list` must show devices;
the migration lab had no GPU and documents the command unvalidated, so GPU
work must be proven on production-like hardware before cutover
("Docker-to-Podman Migration"). Conflict rule: CDI injection fights the
legacy `oci-nvidia-hook.json` hook, so delete the hook file or stop
setting `NVIDIA_VISIBLE_DEVICES` ("NVIDIA CDI Support"). Declare intent in
`devcontainer.json` with `hostRequirements.gpu` (boolean / `"optional"` /
`{cores, memory}`) even though injection itself stays a `runArgs`/`--device`
concern ("Dev Container Metadata Reference"). Non-CDI runtimes take the
`--runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=nvidia.com/gpu=all` (or
`mode=cdi`) path ("NVIDIA CDI Support").

### 5.2 Debug support

For ptrace-based debuggers (C++, Go, Rust) set
`"capAdd": ["SYS_PTRACE"]` (cross-orchestrator) or equivalently
`"runArgs": ["--cap-add=SYS_PTRACE", "--security-opt",
"seccomp=unconfined"]` ("Dev Container Metadata Reference"). Prefer the
declarative `capAdd` form; reserve `runArgs` for engine flags with no
spec-level property.

### 5.3 Sidecar services

When a database or sibling service is genuinely needed, add a Compose file
with the app service as `service:` plus named volumes and
`shutdownAction: stopCompose`, mirroring the documented app-plus-postgres
shape (app `sleep infinity`, `POSTGRES_USER/PASSWORD/DB`, `pgdata` volume)
("Use Podman with VS Code Dev Containers"). Keep sidecars optional: the
unified default is one container, and every added service re-enters the
provider-parity testing of section 3.4.

## 6. Auth for Isolated `/home/dev`: Mount-vs-Copy

Problem: the agent needs provider credentials, but the container user
(`dev`, isolated home) cannot see the host's
`~/.local/share/opencode/auth.json` by default, and credentials must never
be baked into images or committed to git ("Opencode in Devcontainers";
"Dirien devcontainer-features: opencode").

Two corroborating patterns, same shape (mount read-only-ish source, copy
into place at runtime):

- Hard-link plus bind mount: `mkdir .opencode` in the project, hard-link
  the host auth file into it, gitignore `.opencode/`, then
  `"mounts": [{source: "${localWorkspaceFolder}/.opencode/auth.json",
  target: "/mnt/opencode-auth.json", type: "bind"}]` so container opencode
  signs in with host providers while confined to container permissions
  ("Opencode in Devcontainers").
- Feature mount plus shell-time copy: declare the opencode feature with a
  pinned `version` (avoids unauthenticated GitHub API rate limits at 60
  req/hour), mount either `${localEnv:HOME}/.local/share/opencode/auth.json`
  (existing host install) or `${localWorkspaceFolder}/.opencode/auth.json`
  (project-scoped) to `/mnt/opencode-auth.json` / `/tmp/opencode-auth.json`
  with `consistency=cached`, and let the feature's shell helper copy it to
  `~/.local/share/opencode/auth.json` (creating dirs, mode 0600) on shell
  start, so host rotations are picked up on the next shell; absent mount
  means API-key setup is skipped ("Dirien devcontainer-features:
  opencode").

Recommendation for `/home/dev`: adopt the second (copy) variant. The
bind-mount alone leaves credentials at a fixed `/mnt` path with host
lifecycle coupling; the copy variant lands standard-path credentials owned
by the remote user with least-privilege bits, tolerates host updates, and
degrades cleanly when no auth is mounted. Either way, gitignore the
project-scoped auth file.

## 7. Failure-Mode Checklist

| Symptom | Likely cause | Fix (source) |
|---|---|---|
| `looking up compose provider failed` (`docker-compose` / `podman-compose` not in PATH) | No Compose provider installed; `podman compose` is only a wrapper | Install provider (`dnf install podman-compose` from EPEL on RHEL) or set `PODMAN_COMPOSE_PROVIDER` / `compose_providers` ("Podman Compose with Podman"; "Podman vs Docker") |
| `docker compose` runs `podman-compose` with external-provider warning | No real Docker Compose installed; `podman-docker` shim routes through wrapper | Install Docker Compose for the true parser path, or call `podman-compose` explicitly ("Podman Compose with Podman") |
| Service name does not resolve; `localhost` between services fails | Wrong network assumption; default pod shares no net namespace | Use service DNS (`web.dns.podman`); add `pod_args: [--share=net]` only deliberately ("Podman Compose with Podman") |
| Container names `project_service_1` vs expected `project-service-1` | Underscore/hyphen separator split | `x-podman.name_separator_compat: true`, or use DNS/labels not generated names ("Podman Compose with Podman") |
| Declared top-level network ignored / implicit `default` mismatch | Provider default-network divergence | `x-podman.default_net_behavior_compat` or `docker_compose_compat: true`; test per file ("Podman Compose with Podman") |
| Rootless vs rootful store mismatch (images/containers "missing") | Validating as wrong user / socket | Align user, `DOCKER_HOST`, and `podman ps` context; rootless `${XDG_RUNTIME_DIR}` vs rootful `/run` ("Podman Compose with Podman") |
| Tool cannot find `/var/run/docker.sock` | Socket not enabled or wrong mode | `systemctl --user enable --now podman.socket` + `loginctl enable-linger`; shim symlink or `DOCKER_HOST` ("Docker-to-Podman Migration") |
| `docker` prints emulation notice | `podman-docker` shim active | Expected; `/etc/containers/nodocker` quiets, or call `podman` directly ("Docker-to-Podman Migration") |
| Volume data missing after copy | Copied daemon-internal paths | Export app data, recreate volume, restore via temp container ("Docker-to-Podman Migration") |
| `docker swarm/service/stack/node` fails | No Swarm in Podman | Separate orchestration migration; pods are not a scheduler ("Docker-to-Podman Migration") |
| GPU container fails | CDI ungenerated or SELinux label block, or hook conflict | `nvidia-ctk cdi list`, restart `nvidia-cdi-refresh.service`, `--security-opt=label=disable` per policy, remove `oci-nvidia-hook.json` / unset `NVIDIA_VISIBLE_DEVICES` ("NVIDIA CDI Support"; "Docker-to-Podman Migration") |
| Privileged port bind denied rootless | Kernel reserves < 1024 | Use port >= 1024 or tune `net.ipv4.ip_unprivileged_port_start`, proxy in front ("Docker vs Podman: A Hands-On Comparison") |
| Bind-mount files root-owned / permission errors | Daemon-root writes / UID map gap | Podman rootless mapping; `--userns=keep-id` with matching `containerUser`/`remoteUser` ("Docker vs Podman: A Hands-On Comparison"; "Use Podman with VS Code Dev Containers") |
| Wayland UNC / container fails on Wayland host | Wayland socket propagation | `mountWaylandSocket: false` equivalent / disable Wayland mount ("Use Podman with VS Code Dev Containers") |
| Features fail to build under Podman | Features-on-Buildah gap | Expect provider/build gaps; test feature install per image ("Use Podman with VS Code Dev Containers") |
| WSL `podman stats` cgroup error | cgroups v1 | `.wslconfig` `kernelCommandLine = cgroup_no_v1=all` ("Podman Dev Containers on WSL2") |
| "/" not shared mount warning | Non-shared root mount | `sudo mount -o remount,shared /` + `podman system reset`, session-scoped, re-run after `wsl --shutdown` ("Podman Dev Containers on WSL2") |
| `podman machine start` ssh failure | `systemd=true` in `podman-machine-default` | Remove `[boot] systemd=true`; use remote/socket approach ("Podman Dev Containers on WSL2") |
| `systemctl --user` bus errors + cgroup fallback on WSL 2.5.x | systemd user-session race | linger/dbus workarounds; upgrade WSL >= 2.6.0 ("Rootless Podman Fails ... WSL 2.5.x") |
| Client/server version mismatch startup failure | Stale podman-remote in distro vs machine | `podman version` both ends; upgrade to match ("Podman Dev Containers on WSL2") |
| Code invisible to machine / slow Windows-fs builds | Checkout in wrong distro `~/` or on Windows fs | Move shared code under `/mnt/wsl/` ("Podman Dev Containers on WSL2") |
| Large corporate UID remap failure (authd, Ubuntu 25.10) | VS Code UID sync vs huge UID | `updateRemoteUserUID: false` + explicit `containerUser` ("VS Code Devcontainers with Podman on Ubuntu 25.10") |
| Snap VS Code update breaks Podman (`database configuration mismatch`) | Absolute snap-versioned paths in Podman DB | Stable `graphroot` in `storage.conf` outside snap dir; wipe snap-scoped data first ("VS Code Devcontainers with Podman on Ubuntu 25.10") |
| Stale login in `/etc/subuid`/`subgid` after authd migration | Old username entries | Rewrite both files to current UID/username with widened range ("VS Code Devcontainers with Podman on Ubuntu 25.10") |
| Feature install hits GitHub rate limit (60/hr unauthenticated) | Floating `latest` version lookup | Pin feature `version` explicitly ("Dirien devcontainer-features: opencode") |
| Container exits / reboot does not restore | `--restart` without reboot helper, or systemd double-management | `podman-restart.service` for `--restart` containers, or Quadlet `Restart=` for managed services, not both ("Docker-to-Podman Migration") |

## 8. Unarchived/Excluded

- https://markaicode.com/integrate/podman-with-docker/ -- NOT ARCHIVED,
  never cited above. Reason: trafilatura returned 403, curl returned a
  Cloudflare "Just a moment" challenge page, and the last-resort capture
  returned `success: false` (anti-bot Cloudflare JS challenge, Ray ID
  `a3eba7129b28f59d`; empty markdown artifact, challenge-only HTML). Its
  socket-compat claims (compat API, linger, symlink) are corroborated
  instead by the archived migration and comparison sources cited in
  sections 3.2-3.3.

## 9. Works Cited

- "Development Container Specification." containers.dev,
  https://containers.dev/implementors/spec/.
- "Dev Container Metadata Reference (devcontainer.json)."
  containers.dev, https://containers.dev/implementors/json_reference/.
- "@devcontainers/cli." npm registry,
  https://registry.npmjs.org/@devcontainers/cli.
- "Podman Compose with Podman." GoLinuxCloud,
  https://www.golinuxcloud.com/podman-compose/.
- "Podman vs Docker." GoLinuxCloud,
  https://www.golinuxcloud.com/podman-vs-docker/.
- "Docker-to-Podman Migration." GoLinuxCloud,
  https://www.golinuxcloud.com/docker-to-podman-migration/.
- "Docker vs Podman: A Hands-On Comparison and Migration."
  TechDevMantra, https://www.techdevmantra.com/guides/docker-vs-podman.
- "Support for Container Device Interface." NVIDIA Container Toolkit
  documentation,
  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html.
- Zilberdan, Dan. "Opencode in Devcontainers." danz.blog,
  https://danz.blog/blog/opencode-in-devcontainers.
- Dirien. "devcontainer-features: opencode." GitHub,
  https://github.com/dirien/devcontainer-features.
- Dhandala, Nawaz. "Use Podman with VS Code Dev Containers." OneUptime,
  https://oneuptime.com/blog/post/2026-03-18-use-podman-vscode-dev-containers/view.
- "Podman Dev Containers on WSL2 (Discussion #25607)." Podman GitHub
  Discussions, https://github.com/containers/podman/discussions/25607.
- "VS Code Devcontainers with Podman on Ubuntu 25.10 (authd)." Ubuntu
  Discourse,
  https://discourse.ubuntu.com/t/vs-code-devcontainers-with-podman-on-ubuntu-25-10-authd/80847.
- "Rootless Podman Fails Due to Issues with systemd User Instance in WSL
  2.5.x (#13053)." WSL GitHub Issues,
  https://github.com/microsoft/wsl/issues/13053.
