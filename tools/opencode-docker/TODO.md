# Security TODO — opencode-docker

Audit date: 2026-05-28 (refreshed 2026-08-02 to match current code)

## CRITICAL

- [x] **F1** — Pin OpenCode installer with SHA256 verification (`Dockerfile:39-44`)
- [x] **F2** — Create `.dockerignore` to exclude `.git/`, `node_modules/`, `secrets/`, etc.
- [x] **F3** — Pin external plugins: `superpowers` to commit SHA, `@tarquinen/opencode-dcp` to exact version (`config/opencode.json`)

## HIGH

- [x] **F4** — Pin global npm packages (`@upstash/context7-mcp@1.0.17`, `@modelcontextprotocol/server-sequential-thinking@2025.12.18`) (`Dockerfile:46`)
- [x] **F5** — Pin base image to SHA256 digest (`Dockerfile:1,115`)
- [x] **F6** — Brainstorm port exposed on `0.0.0.0` — removed entirely
- [ ] **F7** — Add BuildKit `--secret` infrastructure for build-time secrets (`Dockerfile`)

## MEDIUM

- [ ] **F8** — Secrets loaded into process env — load selectively, only set required vars (`bootstrap.py:12-20`)
- [x] **F9** — Host `.gitconfig` mounted read-only — mitigated: copied into `~/.opencode-docker/.gitconfig` and mounted `:ro,Z` (copy avoids the home-dir relabel failure; `:ro` keeps the host file out of the container writable surface) (`bin/opencode-docker:113-118`)
- [x] **F10** — Overlapping volume mounts (`/app` + `/app/.config/opencode`) — resolved: no bare `/app` root mount remains; only `/app/...` subdir mounts exist (`bin/opencode-docker:136-144`)
- [ ] **F11** — No custom seccomp/AppArmor profile — add minimal syscall allowlist (`bin/opencode-docker:126-144`)
- [x] **F12** — `node_modules/` on disk — excluded via `.dockerignore`; remove from working tree if desired

## LOW

- [x] **F13** — `OPENCODE_VERSION=unknown` default — changed to `1.18.4` (`Dockerfile:6`)
- [x] **F14** — HEALTHCHECK instruction added — `HEALTHCHECK CMD opencode --version || exit 1`
- [x] **F15** — `docs/` exposed in build context — excluded via `.dockerignore`
- [x] **F16** — `$RANDOM` for port selection — removed with brainstorm functionality
