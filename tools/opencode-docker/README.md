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

- **Complete isolation:** Distroless base image with no shell or package manager
- **Read-only filesystem:** Root filesystem is immutable; only `/tmp` (tmpfs) and mounted volumes are writable
- **Dropped capabilities:** `--cap-drop ALL` removes all Linux capabilities (principle of least privilege)
- **Privilege escalation prevention:** `--security-opt no-new-privileges` blocks setuid/setgid exploits
- **Unprivileged user:** Runs as non-root UID 1000 (configurable at build time)
- **Resource limits:** Memory (2GB) and CPU (2 cores) constraints prevent resource exhaustion
- **File-based secrets:** Secrets loaded from files (not environment variables) to avoid exposure in process listings or logs

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

## Superpowers Visual Companion

The [Superpowers](https://github.com/obra/superpowers) plugin includes a visual brainstorming companion that serves mockups, diagrams, and design options in your browser.

The brainstorming server uses a randomly assigned port in the range 49152-65535:
- **Wrapper script:** Use the `-b` or `--brainstorm` flag with `bin/opencode-docker`
- **Development:** `make run` and `make shell` automatically configure and expose the port

When the brainstorming skill starts, it will display the assigned port. Access it at the URL shown (e.g., `http://localhost:XXXXX`).

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
  -v $(pwd):/workspace:rw,Z \
  opencode-docker:latest /workspace
```

> **Note:** `:Z` relabels workspace files for SELinux container access. The label persists after exit. Use `restorecon -R $(pwd)` to restore original labels if needed.

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

The image uses a multi-stage build with distroless runtime:

- **Base:** `gcr.io/distroless/base-debian13` (no shell, no package manager)
- **Node.js:** Node 24 from NodeSource, runtime dependencies extracted via `collect-runtime-deps.sh`
- **Python:** Python 3 with venv support from Debian 12
- **OpenCode:** Installed via official installer in build stage
- **Bootstrap:** `bootstrap.py` loads secrets from `/run/secrets`, starts Xvfb, then execs OpenCode
