# Unified Dev Container Gap Analysis and Migration Plan (DIA-260824-iirx)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: knowledge/res-260921-fo7q-unified-dev-container/res-260921-fo7q-unified-dev-container-conspect.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## 1. Scope, inputs, and design center

Ticket DIA-260824-iirx ("one unified OpenCode dev container for Fedora and WSL
Ubuntu/Debian replacing legacy dual containers") carries an empty template body
(no Description / Verification text). Scope is therefore taken from the dispatch
payload: gaps in the current dual-container setup + migration plan to ONE
unified dev container.

Evidence base: knowledge/res-260921-fo7q-unified-dev-container conspect
(14 archived sources: devcontainer spec + metadata reference, podman-vs-docker,
migration, compose-provider, CDI GPU, opencode-in-devcontainer, dirien feature,
VS Code podman guide, WSL2 discussion #25607, Ubuntu authd, WSL 2.5.x #13053).

Design center (dispatch ground truth, first priority): Fedora + rootless podman,
no docker daemon, container poetry-dev Up healthy, auth store isolated at
/home/dev with no host mount, podman-compose present. WSL Ubuntu/Debian is
second priority and is designed from the conspect, not from a live WSL host.

Domain comprehension: COMPREHENDED. All required repo files were read directly
(compose base + 4 overlays, Dockerfile.dev 361 lines, dev-entrypoint.sh,
devcontainer.json, Makefile engine routing, compose-env.sh, container-engine.sh,
.env.example, secrets/README.md). No guessing, no cannot-comprehend report.

Methods used: gap matrix per axis (requested 7 axes), 5-Whys on the overlay
proliferation, inversion (what would break a naive unification), migration
waves with per-wave rollback, risk table, terminal-friendly summary.

## 2. Current-state inventory (what actually exists)

Base: docker-compose.yml (130 lines) = dev + postgres. dev builds from
Dockerfile.dev (debian:13-slim pinned digest), UID/GID build args
(USER_UID/USER_GID default 1000), image tag poetry-platform-dev:latest
(unqualified). dev volumes: bind .:/workspace:z, named pnpm_store over
/workspace/node_modules, dev_state over /home/dev/.local/share, dev_cache over
/home/dev/.cache. 5 compose file-secrets (anthropic/openai/context7/github/exa)
loaded by dev-entrypoint.sh whitelist into env. Ports 9000/8000/3000.
restart: unless-stopped both services. postgres 16-alpine with pgdata volume
and pg_isready healthcheck. dev healthcheck is opencode --version.

Overlays (4 files, the "dual-container" sprawl):
- docker-compose.fedora.yml: userns_mode keep-id + security_opt label=disable.
- docker-compose.podman.yml: IDENTICAL content to fedora file (byte duplicate).
- docker-compose.rootless-docker.yml: user "0:0".
- docker-compose.wsl.yml: effectively empty (services.dev: {} + commented memory
  block; the trailing indented comment lines under an empty mapping are
  comment-only and harmless but confusing).

Routing: scripts/compose-env.sh computes COMPOSE_FILE docker-free
(COMPOSE_ENGINE authoritative, else readlink probe of docker path for "podman",
plus /proc/version WSL probe; mapping podman->podman.yml,
docker->rootless-docker.yml, +wsl.yml when WSL). scripts/container-engine.sh
invokes the NATIVE binary (docker compose vs podman compose, no fallback, 3-stage
DIA-094 gate). Makefile routes every target through both. .env.example sets
COMPOSE_ENGINE=podman but documents that make does NOT source .env, so the
operator must export it; unset on an ambiguous host warns and defaults docker.

devcontainer.json: Compose-based (dockerComposeFile + service dev,
shutdownAction stopCompose), remoteUser dev, forwardPorts 3, postCreateCommand
pnpm install. No containerUser, no updateRemoteUserUID, no runArgs/userns, no
capAdd, no hostRequirements, no auth mount, no dockerPath/composePath settings.

Dockerfile.dev: full workstation (node 24.18.0 + sha, opencode 1.18.18 + sha,
pnpm/bun/openspec/LSP globals, snip/mise/uv/trafilatura sha-verified, rust
1.83.0 + rust-analyzer 1.97.1 split toolchain, playwright chromium in
/opt/ms-playwright, tini, gosu, non-root dev user, entrypoint root-start then
gosu drop with chown repair of .git/node_modules/state/cache/npm). Bakes
docker-ce-cli 29.7.2 + docker-compose-plugin 5.4.0 from download.docker.com
trixie repo (DIA-131; known TLS-failure history, static-bundle fallback
documented in DIA-131 ticket). No BuildKit-only syntax observed (plain RUN/COPY/
ARG/ENV/HEALTHCHECK/ENTRYPOINT) so podman build compatible.

Entrypoint/secrets: /run/secrets whitelist of 5, zero-byte = skip/degraded boot,
plus /etc/profile.d/secrets.sh re-load for exec login shells. No auth.json
handling at all. No socket mount on dev service (good).

5-Whys on overlay sprawl: why 4 files? Because engine x OS was modeled as files
not flags. Why? Because each engine quirk got its own slice ticket. Why did that
stick? Because compose-env.sh mapping hides the duplication (fedora vs podman
identical, wsl empty). Root cause: no single unified overlay with conditionals;
fix is merge, not a fifth file (inversion check below confirms).

## 3. Gap matrix: current vs target per axis

Legend: GAP = must change; OK = keep; DEBT = works but fragile; N/A = out of scope.

```
Axis        | Current                                  | Target (unified, Fedora-first)              | Verdict
------------+------------------------------------------+---------------------------------------------+--------
image       | debian:13-slim digest-pinned, portable     | Keep base; QUALIFY local tag or document    | GAP-small
            | Dockerfile, no BuildKit syntax; local tag  | podman registry handling; keep all pins;    |
            | poetry-platform-dev:latest (unqualified);  | retain TLS fallback note for docker CLI     |
            | docker-ce-cli baked from download.docker   | bake step (DIA-121/DIA-131 history)         |
            | .com with TLS-failure history              |                                             |
------------+------------------------------------------+---------------------------------------------+--------
compose     | base + 4 overlays; fedora==podman dup;     | ONE base + ONE podman overlay (+wsl tuning  | GAP-big
            | wsl overlay empty; mapping in compose-env  | only if measured); delete dup; fix wsl file |
            | .sh; provider = podman-compose (python,    | to real tuning or delete; pin               |
            | CLI-driven, in_pod/net/name quirks)        | PODMAN_COMPOSE_PROVIDER; keep service DNS   |
------------+------------------------------------------+---------------------------------------------+--------
socket/shim | no socket mount (good); native `podman     | Keep native-first; NO global docker.sock    | OK+doc
            | compose` routing; hooks use compose config | symlink; document DOCKER_HOST only for      |
            | (client-side, no daemon); in-container     | socket-needing tools; audit every docker    |
            | docker CLI present for config validation   | consumer before adding any shim             |
------------+------------------------------------------+---------------------------------------------+--------
user-ns     | build-time UID/GID args + keep-id overlay  | Keep BOTH layers (they solve different      | OK+doc
            | on podman path; entrypoint chown repair;   | problems: build-time identity vs runtime     |
            | devcontainer.json has NEITHER containerUser| mapping); ADD containerUser/remoteUser +    |
            | nor runArgs userns                         | runArgs --userns=keep-id to devcontainer    |
------------+------------------------------------------+---------------------------------------------+--------
secrets     | 5 file-secrets + whitelist loader,         | Keep as-is (correct, SEC-DOCKER-002 clean); | GAP-small
            | zero-byte=skip; 0600 documented; no auth   | ADD auth.json mount+copy (0600, gitignored) |
            | .json path at all (isolated /home/dev)     | per conspect s6 second variant; never bake  |
------------+------------------------------------------+---------------------------------------------+--------
GPU         | no GPU wiring anywhere (no --gpus, no CDI, | Optional CDI device string in a commented   | GAP-opt
            | no hostRequirements)                       | overlay/runArgs + hostRequirements.gpu      |
            |                                          | "optional"; prove on HW before cutover;     |
            |                                          | remove oci-hook/NVIDIA_VISIBLE_DEVICES if   |
            |                                          | legacy present                              |
------------+------------------------------------------+---------------------------------------------+--------
lifecycle   | restart unless-stopped; tini PID1; Xvfb;   | Keep; ADD linger docs (loginctl enable-     | GAP-small
            | opencode healthcheck; 3-stage engine gate; | linger + podman.socket user unit) Fedora;  |
            | no linger/socket docs in repo; devcontainer| machine-lifecycle docs WSL; add capAdd      |
            | has no capAdd/init/hostRequirements        | SYS_PTRACE + init:true + hostRequirements   |
------------+------------------------------------------+---------------------------------------------+--------
devcontaine | Compose-based service:dev; remoteUser only | Keep Compose (postgres sidecar REQUIRES it; | GAP-med
r.json      |                                          | conspect image-first advice does NOT apply  |
            |                                          | when a stateful sidecar exists); add the    |
            |                                          | missing fields above; set dockerPath/compose|
            |                                          | Path for Podman VS Code users               |
```

Key judgment call (documented dissent from conspect s2.1): the conspect verdict
prefers image/Dockerfile-based devcontainer to dodge compose-provider
divergence. That advice assumes a single container. THIS repo has a genuine
postgres sidecar with health-gated depends_on + pgdata volume, so Compose-based
devcontainer (service: dev, shutdownAction stopCompose) is the correct shape
here and matches conspect s5.3 sidecar exception. Do NOT re-platform to
image-based; fix the Compose path instead (pin provider, use service DNS,
validate per file with podman-compose config + staged up).

Inversion results (what would break a naive "just merge everything"):
- Merging user "0:0" (rootless-docker) with userns keep-id (podman) into one
  overlay breaks one engine or the other; overlays must stay engine-branched
  (one podman overlay, one docker overlay) with compose-env.sh selecting.
- Deleting the docker-ce-cli bake to "simplify" breaks make test-config and the
  pre-push delegation (DIA-131 regression).
- Adding a global /var/run/docker.sock symlink for tooling convenience breaks
  rootless isolation (shim is rootful-only) and confuses inventories.
- Baking auth.json into the image or bind-mounting it read-write breaks the
  SEC posture; mount+copy 0600 only.
- Setting systemd=true in any WSL machine config breaks podman machine start
  (conspect s4 hard rule).

## 4. Migration waves with rollback per wave (Fedora first, WSL second)

WAVE 0 - Freeze and proof (no behavior change). Pin PODMAN_COMPOSE_PROVIDER,
record `podman version`, `podman-compose --version`, `podman-compose config`
output, `container-engine.sh gate` output. Commit evidence to ticket.
Rollback: n/a (read-only).

WAVE 1 - Collapse overlays (the core unification). Merge fedora+podman into ONE
docker-compose.podman.yml (keep-id + label=disable), delete fedora file, update
compose-env.sh mapping + Makefile comments + docs that reference the fedora
filename. Fix wsl file: either add one measured tuning knob or delete the file
and drop the WSL branch from compose-env.sh. Qualify image reference handling
for podman (document short-name resolution or set fully qualified tag).
Verify: `podman-compose config`, full `up -d`, engine gate, test-config,
pre-commit hook sees poetry-dev. Rollback: git revert the merge commit; old
filenames restored; `compose down` (WITHOUT -v, keep pgdata) then up.

WAVE 2 - devcontainer.json alignment (Fedora Podman VS Code path). Add
containerUser dev, runArgs --userns=keep-id, capAdd SYS_PTRACE, init true,
hostRequirements {cpus,memory,storage,gpu optional}, dockerPath podman +
dockerComposePath podman-compose guidance (settings, not.json when engine
specific). Keep Compose-based shape. Verify: VS Code attach + postCreateCommand
on Fedora rootless. Rollback: revert json only; compose stack untouched.

WAVE 3 - Auth for isolated /home/dev. Add gitignored project or host-path
auth.json bind mount to /mnt or /tmp + shell-time copy to
~/.local/share/opencode/auth.json mode 0600 in postCreateCommand/profile
(conspect s6 second variant). Verify: rotation picked up on new shell, absent
mount degrades cleanly, perms 0600, git status clean of secrets. Rollback:
remove mount + helper; existing /run/secrets path unaffected.

WAVE 4 - Lifecycle hardening + optional GPU/debug. Document linger + user socket
unit (Fedora); machine lifecycle + no-systemd + cgroup-v2 + version-match +
/mnt/wsl code placement (WSL, from conspect s4, unvalidated here). GPU: commented
CDI runArgs + nvidia-ctk cdi list proof on HW before enabling. Verify per docs.
Rollback per doc revert; GPU stays opt-in commented until proven.

Explicit non-goals: no image-based devcontainer re-platform; no docker.sock
symlink; no Swarm; no volume-metadata copy (/var/lib/docker into podman);
no privileged ports <1024 on rootless (use >=1024 per conspect).

## 5. Risk table

```
# | Risk                                              | Prob | Impact | Mitigation
--+---------------------------------------------------+------+--------+-------------------------------------------
R1| fedora/podman filename referenced in docs/hooks | High | Low    | grep all refs in Wave 1 commit; keep symlink-free, update all
R2| podman-compose provider quirks (in_pod net,      | Med  | Med    | service DNS not localhost; config+staged up per file; pin provider
  | names, default_net) break dev<->postgres reach  |      |        |
R3| unqualified image tag resolves differently       | Med  | Low    | qualify tag or document short-name mode in Wave 1
R4| docker-ce-cli bake fails on TLS (DIA-121 repeat) | Low  | High   | static-bundle fallback per DIA-131 ticket Fix section
R5| WSL 2.5.x systemd race / version mismatch        | Med  | Med    | gate WSL on >=2.6.0, version-match check, no systemd in machine
R6| auth.json mount leaks perms or gets committed    | Low  | High   | 0600 copy variant, gitignore, absent-mount clean degrade
R7| GPU CDI without HW proof breaks unified image    | Low  | Med    | stay commented/opt-in until nvidia-ctk proof on target HW
R8| secrets whitelist drift (compose vs entrypoint)  | Low  | Med    | Wave 0 records both; H5 profile hook stays in sync (existing bats cover)
```

## 6. Terminal-friendly summary

```
Unified container verdict: KEEP Compose (postgres sidecar needs it), ONE podman overlay, Fedora first.
+-----------+---------------------------------------------------+
| Wave      | One-line job                                      |
+-----------+---------------------------------------------------+
| Wave 0    | Record versions + config + gate output (read-only)|
| Wave 1    | Merge fedora==podman dup, fix/drop wsl stub       |
| Wave 2    | devcontainer.json: user/ns/ptrace/init/reqs       |
| Wave 3    | auth.json mount+copy 0600, gitignored             |
| Wave 4    | linger/socket docs; GPU CDI opt-in on proven HW   |
+-----------+---------------------------------------------------+
Do NOT: image-based re-platform, docker.sock symlink, systemd-in-machine, baked secrets, --gpus flag.
Biggest win: deleting the duplicate overlay kills the "dual-container" confusion at the source.
WSL second: cgroup-v2 flag, no systemd, version match, code under /mnt/wsl, >=2.6.0.
```

## 7. Verdict and handoff

COMPREHENDED, High confidence on Fedora path (live repo evidence + 14-source
conspect agree), Medium on WSL specifics (conspect-only, no live WSL host here;
flagged as second-priority docs, not cutover gates). Recommended implementer
sequence: Wave 0+1 as one coder slice (Fedora unified compose), Wave 2+3 as the
next slice (devcontainer + auth), Wave 4 docs/GPU last and optional. No council
needed: no policy-class decision, single recommended variant with an explicit
documented dissent from conspect s2.1 (Compose retained for the postgres
sidecar). Shelf registration delegated to @memory-manager (do NOT edit
memory-shelf.yaml here).
