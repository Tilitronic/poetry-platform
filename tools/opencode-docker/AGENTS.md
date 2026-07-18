# AGENTS.md

OpenCode Docker — containerized environment for running OpenCode CLI.

## Two usage modes

**`bin/opencode-docker`** (recommended for users) — uses `~/.opencode-docker/` for persistence, current dir as workspace.

**`make run`** (development only) — uses local `./homebase`, `./workspace`, `./secrets`. For working on this repo itself.

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
