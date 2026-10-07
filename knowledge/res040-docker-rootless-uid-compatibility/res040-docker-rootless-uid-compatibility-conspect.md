# Rootless Docker vs Podman UID Mapping Blocker and Portable Remediation

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 11
phase-a-failures: 3
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. The Verified Blocker

Rootless Docker runs the daemon and all containers inside a user namespace
without root privileges; it is distinct from rootful `userns-remap`, where the
daemon still runs as root ("Rootless Mode Overview"). The UID/GID mapping rule
is the crux of the blocker:

- Container UID `0` maps to the **host UID of the user running rootless Docker**
  (the result of `id -u`).
- Container UID `n` (for `n >= 1`) maps to `subuid + (n - 1)` ("UID/GID
  Mapping").

The documented consequence: "files owned by your host user appear as owned by
`root` inside the container" ("UID/GID Mapping"). A non-root container process
(e.g. UID 1000) therefore cannot write to host-owned bind mounts, and
host-owned files are visible as root-owned inside the container. This is the
verified blocker for portable dev workflows that rely on bind-mounted source
trees and secrets owned by the host user.

RootlessKit implements this mapping ("User Namespaces"): the container's
`uid_map` shows `0 <hostuid> 1` followed by `1 <subuid> 65536`, confirming
that container UID 0 maps to the invoking host UID rather than to a subordinate
range.

Rootful `userns-remap` is not a substitute: there container UID 0 maps to the
first subordinate UID in `/etc/subuid` (e.g. 231072), and the daemon still runs
as root ("Userns-remap"). It does not provide Podman's keep-id semantics.

## 2. Podman's `keep-id` as the Working Mode

Podman's `--userns=keep-id` maps the host UID:GID to the **same values** inside
the container ("--userns Option"). Red Hat demonstrates the behavioral
difference on a bind mount owned by host user dwalsh (UID 3267):

- default (`""`) -> file shows `root:root`; writes succeed (container root
  writes as the host user).
- `keep-id` -> file shows `dwalsh:dwalsh`; writes succeed.
- `auto` / `nomap` -> file shows `nobody:nobody`; writes DENIED ("User
  Namespace Modes").

The Red Hat conclusion: "keep-id is the mode that preserves in-container
non-root Git writes and secret readability for a rootless Podman dev using bind
mounts owned by the host user" ("User Namespace Modes"). `keep-id` is
disallowed for containers created by the root user and is incompatible with
`--gidmap`, `--uidmap`, `--subuidname`, and `--subgidname` ("--userns Option").

## 3. The Portable Remediation Constraint

The core constraint: **Docker does not accept `keep-id` as a valid `--userns`
value**; keep-id is Podman-specific ("Compose Specification"; "Docker
Options"). The Compose `userns_mode` field is Docker-Compose-specific and
passes through to `docker run --userns`, so it cannot carry keep-id to Docker
("Compose Specification").

The portable trick ("Docker Options"; consulted issue
microsoft/vscode-remote-release#10399): set the environment variable
`PODMAN_USERNS=keep-id` before launching the container. Docker simply ignores
`PODMAN_USERNS`; Podman honors it. Podman selection precedence is
`default < containers.conf < PODMAN_USERNS < --pod < --userns` ("Docker
Options"). This yields a single Compose/env configuration that is a no-op on
Docker and activates keep-id on Podman.

Caveats ("Docker Options"): `keep-id` can break images with **no `USER` set**
(no matching home directory inside the container; setting `HOME` helps), and can
break startup when the container user is root. Apply keep-id only when the
container user is non-root.

podman-compose specifics ("Extensions"): `userns_mode: keep-id:uid=1000` must
be paired with `x-podman.in_pod: false`, because `--userns` and `--pod` cannot
be set together.

## 4. Remediation for Docker-Only Paths

Where Podman is unavailable, the Docker-side fix is to run the container process
as the host user via the Compose `user` field:
`user: "${UID:-1000}:${GID:-1000}"` ("Compose Specification"; "Shared
Volumes"). Caveat: bash does not export `UID`/`GID` by default, so they must be
exported inline or via `.env`, and some entrypoints (e.g. Postgres `initdb`)
fail if the UID is absent from `/etc/passwd` ("Shared Volumes").

Named volumes differ from bind mounts: Docker copies image-directory ownership
into an empty named volume on first mount, providing a translation layer that
bind mounts lack on Linux ("Shared Volumes"). The Compose Spec notes that
configs/secrets `uid`, `gid`, and `mode` are **not implemented** when the source
is a `file`, because the underlying bind mount does not allow UID remapping
("Compose Specification").

Build-time secrets: `RUN --mount=type=secret` defaults `uid` to `0` and `mode`
to `0400`; to make a build secret readable by a non-root build user, set
`uid=1000,mode=0444` ("secret"). This is a build-time mechanism, distinct from
runtime dev secrets.

## 5. Platform-Specific Notes

Docker Desktop on WSL2 splits rules by file location: files under
`/home/<user>/` follow normal Linux UID/GID; files under `/mnt/c` (Windows 9P)
follow Windows-style permissions translated by the WSL kernel ("Shared
Volumes"). A Dockerfile that works on macOS (where Docker Desktop fakes
ownership and `chown` is a no-op, default macOS UID 501) can break in
Linux/CI due to root-owned bind mounts ("Shared Volumes"). Recommendation:
always run with `--user` even on Docker Desktop so local behavior matches
Linux/CI ("Shared Volumes").

## Works Cited

"UID/GID Mapping." *Docker Documentation*, Docker, https://docs.docker.com/engine/security/rootless/uid-gid-mapping/. Accessed 22 Aug. 2026.

"Rootless Mode Overview." *Docker Documentation*, Docker, https://docs.docker.com/engine/security/rootless/. Accessed 22 Aug. 2026.

"--userns Option." *Podman Documentation*, v4.4, https://docs.podman.io/en/v4.4/markdown/options/userns.container.html. Accessed 22 Aug. 2026.

Walsh, Dan. "Understanding Rootless Podman's User Namespace Modes." *Red Hat*, https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes. Accessed 22 Aug. 2026.

"User Namespaces." *Rootless Containers*, https://rootlesscontaine.rs/how-it-works/userns/. Accessed 22 Aug. 2026.

"Extensions (x-podman)." *podman-compose Documentation*, https://github.com/containers/podman-compose/blob/main/docs/Extensions.md. Accessed 22 Aug. 2026.

"RUN --mount=type=secret." *Dockerfile Reference*, Docker, https://docs.docker.com/reference/dockerfile/#run---mounttypesecret. Accessed 22 Aug. 2026.

"Userns-remap." *Docker Documentation*, Docker, https://docs.docker.com/engine/security/userns-remap/. Accessed 22 Aug. 2026.

"How to Manage Permissions for Docker Shared Volumes." *Dash0*, https://www.dash0.com/faq/how-to-manage-permissions-for-docker-shared-volumes. Accessed 22 Aug. 2026.

"Compose Specification." *compose-spec*, GitHub, https://raw.githubusercontent.com/compose-spec/compose-spec/master/spec.md. Accessed 22 Aug. 2026.

"Docker Options (Podman)." *Visual Studio Code Documentation*, Microsoft, https://code.visualstudio.com/remote/advancedcontainers/docker-options. Accessed 22 Aug. 2026.

## Consulted Sources

microsoft/vscode-remote-release#10399 (GitHub issue). Relevance High,
Reliability Medium. Content folded into `vscode-docker-options.md`; provided the
`PODMAN_USERNS=keep-id` trick and Podman selection precedence. Not separately
archived; cited here as consulted per the Phase A manifest.

## Unarchived / Excluded Sources

The following were used only for problem framing and workaround corroboration
and were NOT archived; they are excluded from body citations per the Phase A
evaluation (community/forum reports, not primary citations):

- github.com/mamba-org/micromamba-docker/issues/407 (Medium/Medium) -- 4-option
  summary (--user root on rootless Docker; subuid remap; podman keep-id; named
  volume). Excluded: community issue, framing only.
- github.com/moby/moby/issues/45919 (Medium/Medium) -- rootless volume always
  owned by root; idmapped mounts not yet supported. Excluded: issue tracker,
  corroboration only.
- forums.docker.com/t/rootless-docker-unprivileged-user-bind-mounts/136684
  (Medium/Low) -- rootless bind mount perms. Excluded: forum, low reliability.
- stackoverflow.com/questions/77655209/rootless-docker-host-file-permissions
  (Medium/Medium) -- subuid remap workaround. Excluded: Q&A, framing only.
- forums.docker.com/t/wsl2-docker-desktop-bind-mounts-created-as-root-root-on-host/141322
  (Medium/Medium) -- WSL2 Docker Desktop bind mount root. Excluded: forum,
  framing only.
- github.com/docker/for-win/issues/6897 (Medium/Medium) -- userns-remap
  unsupported in Docker Desktop WSL2. Excluded: issue tracker, framing only.

## Phase A Capture Failures (404, substituted)

Three primary URLs returned 404 during Phase A and were substituted with
working equivalents (counted as `phase-a-failures: 3`):

- docs.podman.io/en/stable/markdown/options/userns.container.html -> 404; used
  v4.4 instead.
- docs.podman.io/en/latest/markdown/options/userns.container.html -> 404; used
  v4.4 instead.
- docs.docker.com/compose/compose-file/compose-file-v4/ -> 404; used Compose
  Spec raw instead.
