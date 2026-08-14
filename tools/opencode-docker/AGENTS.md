# AGENTS.md

OpenCode Docker — containerized environment for running OpenCode CLI.

## Two usage modes

**`bin/opencode-docker`** (recommended for users) — uses `~/.opencode-docker/` for persistence, current dir as workspace.

**`make run`** (development only) — uses local `./homebase`, `./workspace`, `./secrets`. For working on this repo itself.

## SSH agent forwarding (git push from the container)

`bin/opencode-docker` forwards the host's SSH agent socket into the container, read-only, at `/tmp/ssh-agent.sock`, and sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` so `git push` to SSH remotes works from inside the container. The socket is probed in order: `$SSH_AUTH_SOCK` first, then `${XDG_RUNTIME_DIR}/keyring/ssh`, then `${XDG_RUNTIME_DIR}/gcr/ssh`; the first found wins.

**Keys never leave the host.** Only the agent socket is mounted — no `~/.ssh` mount, no key files are copied into the container. The container makes sign-requests to the host agent through the forwarded socket; the keys themselves stay on the host. Do NOT "helpfully" add a `~/.ssh` mount or copy key material into the container — that would defeat the security model.

`GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/tmp/known_hosts -o IdentityAgent=/tmp/ssh-agent.sock"` is set unconditionally via EXTRA_ENV (harmless when no agent is present; design Q3). UserKnownHostsFile points at the writable `/tmp` tmpfs so the read-only `/app` cannot emit a `known_hosts` write warning and new host keys are accepted on first connection with TOFU state persisting for the container's lifetime (DIA-153).

For `git push` to work the host SSH agent must be running, unlocked, and have the key loaded (`ssh-add -L` shows it). If no agent socket is found at launch, the wrapper prints a warning to stderr and continues — opencode works, but `git push` then fails with `Permission denied (publickey)`.

Hardware-key caveat: gnome-keyring can mishandle YubiKey `ed25519-sk` keys (`agent refused operation`). The workaround is a dedicated `ssh-agent` on the host (`eval "$(ssh-agent)"`, `ssh-add`) before relaunching — it works because that agent's `$SSH_AUTH_SOCK` overrides the default one and wins the probe.

Optional: `ssh-add -c` (confirmation-per-use) makes the host agent prompt for a GUI confirmation on every sign request, so a compromised container cannot push silently. It works through the forwarded socket with no container-side change. Full recipe in README.md ("Optional: confirmation-per-use (ssh-add -c)").

Note: `poetry-dev` does NOT need SSH agent forwarding (its delegated gates are make/pnpm only).

## Debian 13 slim runtime

Final image is `debian:13-slim` with **Playwright (chromium)** and **crawl4ai**:
- Standard shell (`/bin/bash`) available for debugging and scripts
- To debug: `make shell` (or `docker exec -it <container> /bin/bash`)
- **Playwright chromium** pre-installed for browser automation
- **crawl4ai** pre-installed for web crawling
- Requires `--shm-size=1g` at runtime for Chromium shared memory (configured in Makefile)
- Requires `--read-only --tmpfs /tmp:exec` for transient writes (configured in Makefile)

## Commit messages

Use conventional commits for persistent, searchable history:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation only
- `chore:` maintenance, refactoring, build changes
- `refactor:` code change that neither fixes nor adds

Format: `type: short description` (under 72 chars). Example: `feat: add -w/--websearch flag to enable Exa web search`
