# OpenCode Docker

A security-hardened Docker environment for running the [OpenCode](https://opencode.ai) CLI in complete isolation. Features a read-only container with dropped Linux capabilities (principle of least privilege), seccomp profile preventing privilege escalation, and file-based secrets management.

## Star History

<a href="https://www.star-history.com/?repos=pkhamre%2Fopencode-docker&type=timeline&logscale=&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=pkhamre/opencode-docker&type=timeline&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=pkhamre/opencode-docker&type=timeline&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=pkhamre/opencode-docker&type=timeline&legend=bottom-right" />
 </picture>
</a>

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed on your machine.
- Make
- `curl` and `jq` (required for `make build-latest`)

### Quick Start

```bash
# Build the image
make build

# Set up your secrets (one-time)
mkdir -p ~/.opencode-docker/secrets
echo "your-api-key" > ~/.opencode-docker/secrets/context7_api_key
chmod 600 ~/.opencode-docker/secrets/*

# Run using the wrapper script (recommended)
bin/opencode-docker
```

### Recommended: Using the Wrapper Script

The `bin/opencode-docker` script is the recommended way to run OpenCode Docker. It:

- Persists all data to `~/.opencode-docker/` (sessions, cache, settings)
- Reads secrets from `~/.opencode-docker/secrets/`
- Uses the current directory as the workspace
- Works from any directory once added to your PATH

#### Adding to PATH

##### Bash

Add to your `~/.bashrc`:

```bash
export PATH="$HOME/git/opencode-docker/bin:$PATH"
```

Then reload:

```bash
source ~/.bashrc
```

##### Fish

Run the following command to add opencode-docker to your path. Replace the Path with the correct path for your environment.

```fish
fish_add_path $HOME/git/opencode-docker/bin
```

#### Usage

Once added to your PATH, you can run from any directory:

```bash
# Run in current directory
opencode-docker

# Continue a session
opencode-docker -s ses_2d068fdfaffefxNTts5doK0upT

# Override workspace directory
OPENCODE_WORKSPACE=/path/to/project opencode-docker
```

## Security Features

This container implements defense-in-depth with multiple security layers:

- **Debian 13 slim runtime:** Standard shell (`/bin/bash`) available for debugging, but no unnecessary packages
- **Read-only filesystem:** Root filesystem is immutable; only `/tmp` (tmpfs) and mounted volumes are writable
- **Dropped capabilities:** `--cap-drop ALL` removes all Linux capabilities (principle of least privilege)
- **Privilege escalation prevention:** `--security-opt no-new-privileges` blocks setuid/setgid exploits
- **Unprivileged user:** Runs as non-root UID 1000 (configurable at build time)
- **Resource limits:** Memory (4GB), CPU (4 cores), and shared memory (1GB) constraints prevent resource exhaustion
- **File-based secrets:** Secrets loaded from files (not environment variables) to avoid exposure in process listings or logs

## Host Container Socket Access

The wrapper mounts the host's container-management socket read-only into the container at `/var/run/docker.sock` (when found) and sets `DOCKER_HOST` accordingly, so `docker compose` commands - e.g. the poetry-platform pre-commit hook delegating to its dev container - work from inside OpenCode sessions. Candidates are checked in order: `$XDG_RUNTIME_DIR/podman/podman.sock`, `/run/user/<uid>/podman/podman.sock`, `/var/run/docker.sock`. If none is found, the wrapper warns on stderr but still launches (opencode works without docker; only commit hooks need it).

Security: the socket is mounted `:ro` with no added capabilities or privileges, and the container runs with `--security-opt label=disable`. On SELinux enforcing hosts, container SELinux confinement is disabled because the `:z` relabel alone is insufficient: podman relabels the socket to `container_file_t:s0` (fixes stat) but `container_t` still lacks connectto permission on a `container_file_t` SOCKET, so docker API calls fail with permission denied, and manual `chcon` to `container_runtime_t` is policy-denied. label=disable makes the socket fully functional at the cost of SELinux confinement for this dev container - an accepted trade-off mitigated by non-root UID 1000, read-only rootfs, and `--cap-drop ALL`. The socket grants the container the host user's container-management rights only - with rootless podman that is the user's own containers, NOT host root (a rootful Docker socket would be host-root-equivalent; this wrapper only auto-mounts the user-level socket).

A rebuild is required for the socket mount to take effect (the docker client is baked into the image): `make build` in `tools/opencode-docker/`, then relaunch via `bin/opencode-docker`. The current session ends on relaunch; resume via the handoff file `.opencode/session/current-handoff.json`.

## Git push from the container (SSH agent forwarding)

The wrapper forwards the host's SSH agent socket into the container, read-only, at `/tmp/ssh-agent.sock` and sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock`, so `git push` to SSH remotes works from inside the container.

**How it works:** only the agent socket is forwarded — no key material ever enters the container. There is no `~/.ssh` mount and no key file is copied in; the container makes sign-requests to the host agent over the socket and the host signs with the keys, which stay on the host. Do not "fix" this by mounting `~/.ssh` or copying keys into the container: that would put your private keys at risk inside the container and is explicitly unsupported.

**No-agent warning:** if no SSH agent socket is found at launch (`$SSH_AUTH_SOCK` unset and no keyring fallback), the wrapper prints a warning to stderr and continues — opencode works fine, but `git push` fails with `Permission denied (publickey)`. This is expected and safe; it just means no agent was available to forward.

**Host prerequisites:** the host SSH agent must be running, unlocked, and have the key loaded. Verify with:

```bash
ssh-add -L
```

If the key is missing, unlock the agent / add the key on the host, then relaunch the container. Also note `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` is set inside the container (the read-only `/app` cannot write `known_hosts`), so the first connection to a new host auto-accepts its key (TOFU).

**Known caveat (hardware keys):** gnome-keyring may mishandle YubiKey `ed25519-sk` keys, and a push can fail with `agent refused operation`. If you use a hardware key and hit this, start a dedicated agent for the session on the host and relaunch:

```bash
eval "$(ssh-agent)"
ssh-add
bin/opencode-docker
```

Note: `poetry-dev` does NOT need SSH agent forwarding (its delegated gates are make/pnpm only).

## Secrets Management

This project uses file-based secrets instead of environment variables for improved security. Secrets stored in files are not visible in `docker inspect`, process listings, error messages, or logs.

### Setting Up Secrets

1. Create your secrets directory:
   ```bash
   mkdir -p ~/.opencode-docker/secrets
   chmod 700 ~/.opencode-docker/secrets
   ```

2. Add your API keys as individual files:
   ```bash
   echo "your-api-key" > ~/.opencode-docker/secrets/anthropic_api_key
   echo "your-api-key" > ~/.opencode-docker/secrets/openai_api_key
   echo "your-api-key" > ~/.opencode-docker/secrets/context7_api_key
   chmod 600 ~/.opencode-docker/secrets/*
   ```

3. The runtime bootstrap (`bootstrap.py`) automatically loads all files from `/run/secrets` as environment variables:
   - Filenames are converted to uppercase
   - Dashes and dots are replaced with underscores
   - Example: `anthropic_api_key` becomes `ANTHROPIC_API_KEY`

### Supported Secrets

| Filename | Environment Variable | Provider |
|----------|---------------------|----------|
| `anthropic_api_key` | `ANTHROPIC_API_KEY` | Anthropic |
| `openai_api_key` | `OPENAI_API_KEY` | OpenAI |
| `context7_api_key` | `CONTEXT7_API_KEY` | Context7 MCP |
| `google_application_credentials` | `GOOGLE_APPLICATION_CREDENTIALS` | Vertex AI |
| `aws_access_key_id` | `AWS_ACCESS_KEY_ID` | AWS Bedrock |
| `aws_secret_access_key` | `AWS_SECRET_ACCESS_KEY` | AWS Bedrock |

**Note:** Environment variables can still be passed directly if needed, but file-based secrets are strongly recommended for security.

## Data Persistence & Configuration

When using the wrapper script (`bin/opencode-docker`):

| Data | Location | Description |
|------|----------|-------------|
| **Home Directory** | `~/.opencode-docker/` | OpenCode cache, plugins, settings, sessions |
| **Secrets** | `~/.opencode-docker/secrets/` | API keys and credentials |
| **Config** | `./config/` (this repo) | OpenCode configuration, MCP servers, custom skills |
| **Workspace** | Current directory | Your project files |

When using `make run` (development only):

| Data | Location | Description |
|------|----------|-------------|
| **Home Directory** | `./homebase/` | Local persistent home |
| **Secrets** | `./secrets/` | Local secrets |
| **Config** | `./config/` | OpenCode config |
| **Workspace** | `./workspace/` | Local workspace |

## Browser Automation

The container includes **Playwright (Chromium)** and **crawl4ai** for browser automation and web crawling:
- Chromium browser pre-installed in the image
- Requires `--shm-size=1g` at runtime (configured in both Makefile and wrapper script)
- Xvfb headless display server started automatically by `bootstrap.py`
- Set `DISPLAY=:99` env var for Playwright to use

## Advanced Usage

### Development Commands

```bash
make build                      # Build with auto-detected UID/GID
make build VERSION=1.3.17       # Build with specific version tag
make build-latest               # Build latest OpenCode version
make tag-latest VERSION=1.3.17  # Tag a version as latest
make run                        # Dev run (uses ./homebase, ./workspace, ./secrets)
make shell                      # Debug shell (builder-tools stage with bash)
make clean                      # Remove image
```

### Manual Podman Run

For advanced users who need custom container configuration:

```bash
podman run --rm -it \
  --userns=keep-id \
  --read-only \
  --tmpfs /tmp:exec,size=512m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --memory=4g \
  --cpus=4 \
  -v ~/.opencode-docker/.local/share:/app/.local/share:rw,Z \
  -v ~/.opencode-docker/.local/state:/app/.local/state:rw,Z \
  -v ~/.opencode-docker/config:/app/.config/opencode:rw,Z \
  -v ~/.opencode-docker/.cache:/app/.cache:rw,Z \
  -v ~/.opencode-docker/secrets:/run/secrets:ro,Z \
  -v $(pwd):/workspace:rw,z \
  opencode-docker:latest /workspace
```

> **Note:** the workspace is mounted `:z` (shared label) so other containers that mount the same directory with `:z` - e.g. the poetry-platform dev container - can still read it. Do NOT use `:Z` for the workspace mount: it relabels workspace files with private MCS categories that lock out those containers (SELinux MCS dominance). The container itself needs no relabel (it runs with `--security-opt label=disable`). If workspace files were already privatized by an older `:Z` run, restore the shared label on the host with:
> `sudo chcon -Rv "system_u:object_r:container_file_t:s0" /path/to/workspace`

### Building Manually

```bash
# Default UID/GID (1000)
podman build -t opencode-docker .

# With custom UID/GID (recommended)
podman build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t opencode-docker .

# With version tag
podman build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t opencode-docker:1.17.7 .
```

### Runtime Details

The image uses a multi-stage build with Debian 13 slim runtime:

- **Base:** `debian:13-slim` (bash, apt, standard tooling)
- **Node.js:** Node 24 from NodeSource, runtime dependencies extracted via `collect-runtime-deps.sh`
- **Python:** Python 3 with venv support from Debian 13
- **Playwright:** Chromium pre-installed for browser automation
- **crawl4ai:** Pre-installed for web crawling
- **OpenCode:** Installed via official installer in build stage
- **Bootstrap:** `bootstrap.py` loads secrets from `/run/secrets`, starts Xvfb, then execs OpenCode
