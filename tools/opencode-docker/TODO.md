# Security TODO — opencode-docker

Audit date: 2026-05-28

## CRITICAL

- [x] **F1** — Pin OpenCode installer with SHA256 verification (`Dockerfile:30-35`)
- [x] **F2** — Create `.dockerignore` to exclude `.git/`, `node_modules/`, `secrets/`, etc.
- [x] **F3** — Pin external plugins: `superpowers` to commit SHA, `@tarquinen/opencode-dcp` to exact version (`config/opencode.json`)

## HIGH

- [x] **F4** — Pin global npm packages (`@upstash/context7-mcp@1.0.17`, `@modelcontextprotocol/server-sequential-thinking@2025.12.18`) (`Dockerfile:37`)
- [x] **F5** — Pin `debian:13-slim` to SHA256 digest (`Dockerfile:1`); distroless pinning blocked on gcr.io auth (TODO added at `Dockerfile:77`)
- [x] **F6** — Brainstorm port exposed on `0.0.0.0` — removed entirely
- [ ] **F7** — Add BuildKit `--secret` infrastructure for build-time secrets (`Dockerfile`)

## MEDIUM

- [ ] **F8** — Secrets loaded into process env — load selectively, only set required vars (`bootstrap.py:17-26`)
- [ ] **F9** — Host `.gitconfig` mounted read-only — remove or sanitize (`bin/opencode-docker:96-98`)
- [ ] **F10** — Overlapping volume mounts (`/app` + `/app/.config/opencode`) — remove redundant mount or document (`bin/opencode-docker:111-113`)
- [ ] **F11** — No custom seccomp/AppArmor profile — add minimal syscall allowlist (`bin/opencode-docker:100-116`)
- [x] **F12** — `node_modules/` on disk — excluded via `.dockerignore`; remove from working tree if desired

## LOW

- [x] **F13** — `OPENCODE_VERSION=unknown` default — changed to `1.15.12` (`Dockerfile:6`)
- [ ] **F14** — No `HEALTHCHECK` instruction — add `HEALTHCHECK CMD opencode --version || exit 1`
- [x] **F15** — `docs/` exposed in build context — excluded via `.dockerignore`
- [x] **F16** — `$RANDOM` for port selection — removed with brainstorm functionality
