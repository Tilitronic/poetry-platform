# AGENTS.md

OpenCode Docker — containerized environment for running OpenCode CLI.

## Two usage modes

**`bin/opencode-docker`** (recommended for users) — uses `~/.opencode-docker/` for persistence, current dir as workspace.

**`make run`** (development only) — uses local `./homebase`, `./workspace`, `./secrets`. For working on this repo itself.

## Distroless runtime constraints

Final image is `gcr.io/distroless/base-debian13`:
- **No `/bin/bash` or `/bin/sh`** — cannot `docker exec` into production container
- To debug: `make shell` (uses builder-tools stage with bash)
- Available commands: `mkdir find grep rg jq cat head tail sed awk echo ls cp mv rm chmod wc sort cut env pwd date dirname basename`
- Python 3, Node 24, git, Xvfb also available

## Commit messages

Use conventional commits for persistent, searchable history:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation only
- `chore:` maintenance, refactoring, build changes
- `refactor:` code change that neither fixes nor adds

Format: `type: short description` (under 72 chars). Example: `feat: add -w/--websearch flag to enable Exa web search`
