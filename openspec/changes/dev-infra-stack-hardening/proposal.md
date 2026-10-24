# Proposal: dev-infra-stack-hardening

> **Status:** implemented · **Scope:** dev-infra (Dockerfile.dev, Makefile, docker-compose.yml, dev-entrypoint.sh, scripts/dev-secrets-profile.sh, .gitignore, docs)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)
> **Supersedes:** findings from `docs/dev-infra-audit-plan.md` (C1, C2, C3, M1–M9 subset) + audit finding **H5** (exec-session secrets passthrough, added post-implementation)
> **Implementation note (2026-08-02):** all tasks T1–T7 are implemented and verified. Verification evidence: 24/24 bats tests passing, docker build success, live chromium launch, `openspec validate dev-infra-stack-hardening` pass. The post-implementation review flagged five spec-fidelity deviations (now folded into this artifact) and one scope-creep addition (T7 / H5, now formalized).

## Motivation

The dev container stack has accumulated a class of **silent infrastructure failures** that do not surface as build errors but render core workflows dead or unreliable. Three critical findings (C1, C2, C3) and four significant findings (M1, M2/M7, M8, M9) from the converged audit collectively mean:

- **Playwright/crawl4ai browser automation is dead** — chromium installs to the wrong path, lacks system libs, and cannot run at all.
- **OpenSpec tooling is version-skewed** — the container pins 1.6.0 while the host uses 1.7.0; features like `skip_specs` and reliable `validate` exit codes require 1.7.0.
- **The entire Makefile workflow is unreachable** — `make` is absent from both the host and the container.
- **Secrets are a facade** — placeholder files are 0-byte, world-readable, and half the whitelisted names are never mounted.
- **Documentation lies** — `CONTAINER-SETUP.md` references a deleted file, `docker-dev.md` overstates turbo service count.
- **Process hygiene is missing** — no zombie reaping (tini), no Xvfb hardening, no restart policy, stale-lock risk.

These are not theoretical risks; they actively block developers from running browser automation, OpenSpec validation, and the Make-based workflow documented in `docs/docker-dev.md`.

## Scope

### In scope

1. **C1 — Fix Playwright/crawl4ai browser automation** (Dockerfile.dev)
   - Reorder: set `PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright` **before** the `RUN python3 -m playwright install chromium` step.
   - Create `/opt/ms-playwright` and `chown` it to the `dev` user before switching from root.
   - Add `python3 -m playwright install-deps chromium` to install the missing system libraries (libglib-2.0, libnss3, libatk, libgtk, etc.).
   - Verify chromium actually starts (not just installs).

2. **C2 — Bump OpenSpec to 1.7.0** (Dockerfile.dev)
   - Change `ARG OPENSPEC_VERSION=1.6.0` → `1.7.0`.
   - Rationale: 1.6.0 `validate --changes` returns exit 0 on failure (false-green); `skip_specs` field in `.openspec.yaml` only works ≥1.7.0.

3. **C3 — Install `make`** (Dockerfile.dev + docs)
   - Add `make` to the `apt-get install` list in Dockerfile.dev.
   - Document the one-time host install step in `docs/docker-dev.md` (a container cannot apt-install on the host).

4. **M1 — Fix `make test-infra` ordering** (Makefile)
   - `test-python` requires the dev container to be up; it must run **after** the smoke test starts the stack, not before.
   - Reorder: `test-infra: gen-jsconfig test-shell` then the smoke test body (which builds/starts), then `test-python` as the final step.

5. **M2 — Secrets file permissions and mount consistency** (dev-entrypoint.sh, docker-compose.yml, docs)
   - Secret files should be 0600 (owner read/write only), not 0644 (world-readable).
   - Document that secret files must be populated (non-empty) by the developer.
   - Either (a) remove the three unmounted names from `ALLOWED_SECRETS` whitelist and `.gitignore` (`google_application_credentials`, `aws_access_key_id`, `aws_secret_access_key`), or (b) add them to `docker-compose.yml` secrets and document their use. Decision: option (a) — remove unused entries to reduce confusion; the AWS/GCP keys are not currently needed by any service.

6. **M7 — .gitignore secrets allowlist gap** (.gitignore)
   - Replace the explicit per-name allowlist with a catch-all pattern: `secrets/*` with an exception for `secrets/README.md`. This prevents future-named key files from being accidentally committed.

7. **M8 — Fix stale documentation references** (CONTAINER-SETUP.md, docs/docker-dev.md)
   - `CONTAINER-SETUP.md:76` references `.opencode/opencode.json` (deleted; now `.opencode/opencode.jsonc`). Fix the reference.
   - `docs/docker-dev.md` claims turbo runs 3 services. Correction: only `author-studio` has a `dev` script in `turbo.json`; `api-server` is Python (invited separately), `publishing-platform` has no `dev` script. Update the documentation to reflect reality.

8. **M9 — Process hygiene hardening** (Dockerfile.dev, dev-entrypoint.sh, docker-compose.yml)
   - Install `tini` as PID 1 wrapper for zombie reaping. Change `ENTRYPOINT` to use tini (`tini -- /usr/local/bin/dev-entrypoint.sh`).
   - Add `-ac -noreset` flags to the Xvfb invocation in `dev-entrypoint.sh` (disable access control for headless automation, prevent reset on client disconnect).
   - Add `rm -f /tmp/.X11-unix/X99` before the lock check in `dev-entrypoint.sh` to handle stale locks from crashed containers.
   - Add `restart: unless-stopped` to the `dev` service in `docker-compose.yml`.

9. **H5 — exec-session secrets passthrough** (docker-compose.yml, Dockerfile.dev, scripts/dev-secrets-profile.sh, docs) — _added post-implementation per orchestrator request during implementation phase; formalized here to address reviewer-flagged scope creep_
   - `docker-compose.yml` `dev` service `environment:` block now passes the five API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `EXA_API_KEY`) from `${VAR:-}` host env at compose-up time. This is distinct from the `/run/secrets` mount mechanism: compose `environment:` makes the vars visible to processes spawned by `docker compose exec`, which do not inherit the entrypoint's `/run/secrets`-sourced exports.
   - New script `scripts/dev-secrets-profile.sh` installed as `/etc/profile.d/secrets.sh` in `Dockerfile.dev` — its whitelist mirrors `dev-entrypoint.sh`'s `ALLOWED_SECRETS` (same 5 names). The profile script sources `/run/secrets` into interactive `bash` shells (which is the no-op fallback for exec sessions that already inherit from compose `environment:`).
   - bats tests in `scripts/__tests__/dev-entrypoint.bats` (lines ~113–146) cover the profile script: each whitelisted key is loaded, and `aws_access_key_id` (not in whitelist) is NOT loaded.
   - **Trade-off (documented, accepted):** compose `environment:` passthrough widens `/proc/1/environ` visibility for the 5 API keys (any process inside PID 1's env namespace can read them). The alternative — relying solely on `/run/secrets` — would require exec sessions to manually re-source secrets, breaking `make opencode` / `docker compose exec dev bash` interactive workflows. Accepted for the dev container because: (a) the dev container is single-tenant per developer, (b) the secrets are the developer's own keys, (c) production containers use a different, stricter secrets mechanism.
   - **Shotgun-surgery risk (reviewer Minor):** the 5-name whitelist lives in BOTH `dev-entrypoint.sh` (`ALLOWED_SECRETS`) AND `scripts/dev-secrets-profile.sh`. A bats test asserts both whitelists stay in sync (extract both and compare). Both files carry `# KEEP IN SYNC` comments referencing each other.

### Out of scope

- Configuring language servers beyond what `dev-infra-language-servers` already does.
- Adding new secrets beyond the existing five (anthropic/openai/context7/github/exa).
- Creating a production Dockerfile for `api-server` (covered by audit M6, separate change).
- Changes to application code, `tsconfig.json`, `turbo.json`, or any package's `package.json`.
- OpenCode config changes (covered by the AI Devtools Modernization Workflow, not this change).

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

## Rollback plan

Every artifact changed by this proposal is independently revertable:

| Artifact                                                              | Revert                                                            |
| --------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Dockerfile.dev Playwright block reorder + install-deps + tini         | `git checkout` to prior version; rebuild image                    |
| Dockerfile.dev `OPENSPEC_VERSION` bump                                | Change `1.7.0` back to `1.6.0`; rebuild image                     |
| Dockerfile.dev `make` in apt-get list                                 | Remove `make` from the list; rebuild image                        |
| Dockerfile.dev `dev-secrets-profile.sh` install                       | Remove the `COPY` + profile.d install RUN; rebuild image          |
| Makefile `test-infra` reordering                                      | `git checkout` to prior version                                   |
| docker-compose.yml secrets reduction / restart policy                 | `git checkout` to prior version                                   |
| docker-compose.yml `environment:` passthrough for the 5 API keys      | Remove the `environment:` block from `dev` service; rebuild image |
| dev-entrypoint.sh ALLOWED_SECRETS reduction / Xvfb flags / stale-lock | `git checkout` to prior version                                   |
| scripts/dev-secrets-profile.sh (new file)                             | Delete the file; rebuild image                                    |
| .gitignore secrets catch-all                                          | `git checkout` to prior version                                   |
| CONTAINER-SETUP.md / docker-dev.md doc fixes                          | `git checkout` to prior version                                   |

No existing production code is modified. No data migrations. Rollback is `git checkout` + image rebuild, with no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra hardening — tests verify **tool presence, configuration correctness, and runtime behavior** inside the container. A good test is one that fails loudly when a fix regresses and passes quietly otherwise. We test **inside the running container** (not mocks), because the bugs are about real runtime paths, permissions, and process behavior that cannot be reproduced in unit tests.

### Test strategy per finding

| Finding                       | Test method                           | Command / assertion                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **C1 — Playwright**           | Live container probe                  | `docker compose exec -T dev python3 -m playwright --version` (presence); `docker compose exec -T dev python3 -c "from playwright.sync_api import sync_playwright; p = sync_playwright().start(); b = p.chromium.launch(); b.close(); p.stop(); print('ok')"` (actual launch); `docker compose exec -T dev bash -c 'test -d /opt/ms-playwright && echo ok'` (path); `docker compose exec -T dev bash -c 'stat -c %U /opt/ms-playwright'` (ownership = `dev`)                                                                                                 |
| **C2 — OpenSpec version**     | Live container probe                  | `docker compose exec -T dev openspec --version` → must print `1.7.0`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **C3 — make**                 | Live container probe + host doc check | `docker compose exec -T dev make --version` (presence); `docker compose exec -T dev make test-shell` (end-to-end)                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **M1 — test-infra ordering**  | Behavioral: cold start                | `make down && make test-infra` must pass end-to-end without manual `make up` first. The Makefile must orchestrate the stack lifecycle.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **M2 — Secrets**              | Smoke test probe + file check         | `docker compose exec -T dev bash -c 'test -f /run/secrets/anthropic_api_key && echo mounted'` (mounted names); `stat -c %a secrets/anthropic_api_key` on host → must be `600` (documented in README)                                                                                                                                                                                                                                                                                                                                                        |
| **M7 — .gitignore**           | Behavioral: git check                 | `git check-ignore secrets/new_api_key` must exit 0 (ignored); `git check-ignore secrets/README.md` must exit 1 (not ignored)                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **M8 — Docs**                 | Manual review + grep                  | `grep -r 'opencode\.json' CONTAINER-SETUP.md` must not match the deleted file path; `grep '3 services' docs/docker-dev.md` must not appear                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **M9 — Process hygiene**      | Live container probe                  | `docker compose exec -T dev cat /proc/1/comm` → must print `tini` (note: implementation uses `/proc/1/comm` instead of `ps -p 1 -o comm=` because `procps` is absent from `debian:slim`); `docker compose exec -T dev bash -c 'for p in /proc/[0-9]\*/cmdline; do tr "\0" " " <"$p" 2>/dev/null; done                                                                                                                                                                                                                                                       | grep -q "[X]vfb._-ac._-noreset" && echo ok'`→ must show`-ac`and`-noreset`flags (note: scans`/proc/[0-9]\*/cmdline`instead of`ps aux | grep "[X]vfb"`because`procps`is absent);`docker compose config`→ must show`restart: unless-stopped` for dev service |
| **H5 — exec-session secrets** | Live container probe + bats           | `docker compose exec -T dev bash -lc 'echo "${ANTHROPIC_API_KEY:+set}"'` → must print `set` (exec session inherits compose-time env); `docker compose exec -T dev bash -lc 'echo "${AWS_ACCESS_KEY_ID:-}"'` → must be empty (whitelist honored, AWS excluded); bats tests in `scripts/__tests__/dev-entrypoint.bats` lines ~113–146 assert all 5 whitelisted keys load and the non-whitelisted `aws_access_key_id` does NOT load; whitelist-sync bats test asserts `dev-entrypoint.sh` `ALLOWED_SECRETS` matches `scripts/dev-secrets-profile.sh` whitelist |

### Two test layers

1. **Smoke layer** (`scripts/test-docker-smoke.sh`, extended) — adds assertions for each fix above. Runs as part of `make test-infra`.
2. **Behavioral layer** (bats tests where applicable) — `.gitignore` catch-all pattern is testable via `git check-ignore` in a bats test; Xvfb flag changes are testable in the existing `dev-entrypoint.bats` namespace-isolated harness.

### What we explicitly do NOT test

- Playwright's ability to load arbitrary web pages (out of scope; we verify it launches).
- OpenSpec's `validate` correctness (we verify the version; OpenSpec's own test suite covers correctness).
- Secret file contents (we verify they are mounted and have correct permissions; contents are developer-provided).
- Zombie process reaping under load (we verify tini is PID 1; actual reaping is tini's job).

### Prior art in the codebase

- Smoke test binary-presence pattern: existing `scripts/test-docker-smoke.sh` lines 76-93 (node, python3, language servers version checks).
- bats shell-script behavior pattern: existing `scripts/__tests__/dev-entrypoint.bats` (namespace-isolated tests with `test-helper.bash`).
- bats-wrapper with vendor-on-demand: existing `scripts/__tests__/bats-wrapper.sh` (syntax-checks all scripts, vendors bats-core if missing).
- Makefile `test-infra` composition: existing `Makefile` line 71.

### Test risk and mitigation

**Risk:** Playwright `install-deps` requires root and network access during build; if the Debian mirrors are down, the build fails. **Mitigation:** the existing Dockerfile already uses `apt-get` for base packages; `install-deps` is one more apt invocation, subject to the same failure modes. Document the fallback (retry build).

**Risk:** Changing `PLAYWRIGHT_BROWSERS_PATH` breaks existing cached browsers on developer machines. **Mitigation:** the cache is inside the container image (rebuilt from scratch on `docker compose build --no-cache`); no host-side cache exists.

**Risk:** Removing AWS/GCP secret names from `ALLOWED_SECRETS` breaks a developer who was using them. **Mitigation:** no service in `docker-compose.yml` references them; the `secrets/` directory has no files for them; `secrets/README.md` documents the active list. If a developer needs them, they can re-add to the whitelist in a follow-up change.
