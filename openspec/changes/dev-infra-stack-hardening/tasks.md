# Tasks: dev-infra-stack-hardening

> **Proposal:** `openspec/changes/dev-infra-stack-hardening/proposal.md`
> **Design:** `openspec/changes/dev-infra-stack-hardening/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
T1 (Playwright/browser fix) ─────────────────┐
                                              │
T2 (OpenSpec bump + make install) ───────────┤
                                              ├──▶ T6 (test-infra ordering)
T3 (Secrets + .gitignore) ───────────────────┤
                                              │
T4 (Docs fixes) ─────────────────────────────┤
                                              │
T5 (Process hygiene: tini + Xvfb + restart) ─┘

T7 (exec-session secrets passthrough — H5) ── (independent, blocks on nothing)
```

**Critical path:** T1 (heaviest Dockerfile change) → T6 (Makefile orchestration)
**Parallel tracks:** T2, T3, T4, T5, T7 can proceed independently while T1 is in flight.
**Final task:** T6 depends on ALL of T1–T5 (it orchestrates the full test-infra pipeline that verifies all fixes).
**T7 (added post-implementation):** independent of T1–T6. Was not in the original scope but was requested by the orchestrator during implementation and formalized here to address reviewer-flagged scope creep. Touches `docker-compose.yml` (env passthrough), `Dockerfile.dev` (profile.d install), and adds a new script + bats tests.

---

## T1 — Playwright/crawl4ai browser automation fix

**Blockers:** none
**Vertical slice:** fix the triple-fault (wrong install path, missing system libs, root-only perms) so chromium actually launches inside the container.
**Traces to:** C1

### What changes

1. `Dockerfile.dev` — Playwright section (currently lines 119-122):
   - Move `PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright` from the post-user-switch ENV block (line 143) to **before** the Playwright install RUN step.
   - Add `RUN mkdir -p /opt/ms-playwright` before the install.
   - Add `python3 -m playwright install-deps chromium` to install system libraries (libglib-2.0, libnss3, libatk, libgtk, libgbm, etc.).
   - After install, add `RUN chown -R ${USER_UID}:${USER_GID} /opt/ms-playwright` so the non-root `dev` user can access the browsers.
   - Remove `PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright` from the post-user-switch ENV block (it is now set earlier).
2. `scripts/test-docker-smoke.sh` — append a "verifying browser automation" section:
   - `docker compose exec -T dev python3 -m playwright --version >/dev/null` → `echo "ok: playwright present"`
   - `docker compose exec -T dev bash -c 'test -d /opt/ms-playwright'` → `echo "ok: browser cache path exists"`
   - `docker compose exec -T dev bash -c 'stat -c %U /opt/ms-playwright'` → assert output is `dev` (ownership check)
   - `docker compose exec -T dev python3 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); b.close(); p.stop()"` → `echo "ok: chromium launches"`

### Acceptance criteria (user perspective)

- After `docker compose build dev`, opening a shell and running `python3 -m playwright --version` prints a version string and exits 0.
- `python3 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); b.close(); p.stop()"` exits 0 (chromium actually starts).
- `/opt/ms-playwright` exists and is owned by the `dev` user (not root).
- `make test-infra` passes, including the new browser automation assertions in the smoke test.
- No existing smoke test assertions are removed or weakened.

### Testing

- The smoke test assertions ARE the test for this task. They verify: (a) playwright CLI is on PATH, (b) browser cache is at the correct path with correct ownership, (c) chromium actually launches (the end-to-end proof that the triple-fault is resolved).
- **RED-GREEN:** write the smoke test assertions first (they fail because the current Dockerfile has the path/perm/deps bugs), then fix the Dockerfile until they pass.

---

## T2 — OpenSpec version bump + `make` install

**Blockers:** none
**Vertical slice:** fix the version skew (C2) and install the missing `make` binary (C3) so the documented Makefile workflow is reachable.
**Traces to:** C2, C3

### What changes

1. `Dockerfile.dev`:
   - Change `ARG OPENSPEC_VERSION=1.6.0` (line 29) → `ARG OPENSPEC_VERSION=1.7.0`.
   - Add `make` to the `apt-get install --no-install-recommends` list (line 41-55). Place it alphabetically after `jq`.
2. `docs/docker-dev.md` — add a note in the "Quick Start" section about the host `make` requirement:
   ```markdown
   **Prerequisite:** `make` must be installed on the host. On Debian/Ubuntu: `sudo apt-get install make`. The container has `make` for in-container use; the host needs it to run the Makefile targets (`make up`, `make shell`, etc.).
   ```
3. `scripts/test-docker-smoke.sh` — append:
   - `docker compose exec -T dev openspec --version` → assert output contains `1.7.0`
   - `docker compose exec -T dev make --version >/dev/null` → `echo "ok: make present in dev container"`

### Acceptance criteria (user perspective)

- `docker compose exec dev openspec --version` prints `1.7.0` (not `1.6.0`).
- `docker compose exec dev make --version` prints a version string and exits 0.
- `make up`, `make shell`, `make test-shell` all work from the host (assuming `make` is installed on the host).
- `make test-infra` passes, including the new version/presence assertions.
- `docs/docker-dev.md` documents the host `make` install step.

### Testing

- Smoke test assertions verify the version and presence.
- **RED-GREEN:** write the smoke test assertions first (the `openspec --version` assertion fails because the container has 1.6.0; the `make --version` assertion fails because make is not installed), then fix the Dockerfile.

---

## T3 — Secrets consistency + .gitignore catch-all

**Blockers:** none
**Vertical slice:** align the secrets whitelist with what compose actually mounts, fix the .gitignore to catch future-named key files, and document the permission requirement.
**Traces to:** M2, M7

### What changes

1. `dev-entrypoint.sh`:
   - Reduce `ALLOWED_SECRETS` from 8 entries to 5 (remove `google_application_credentials`, `aws_access_key_id`, `aws_secret_access_key`). These names are never mounted by `docker-compose.yml` and no service uses them.
2. `docker-compose.yml` — no change needed (the `secrets:` top-level and `dev.secrets:` already list only the 5 active names).
3. `.gitignore` — replace the explicit per-name secrets allowlist (lines 66-73) with:
   ```gitignore
   # === Secrets (all files ignored except README) ===
   secrets/*
   !secrets/README.md
   ```
4. `secrets/README.md`:
   - Reduce the allowed-filenames table to 5 entries (remove google/aws rows).
   - Add a "File permissions" section:

     ````markdown
     ## File permissions

     Secret files should be `0600` (owner read/write only) to prevent other users on the host from reading them:

     ```bash
     chmod 600 secrets/anthropic_api_key
     ```
     ````

     Secret files must be non-empty. Empty files result in empty env vars (the entrypoint loads the file content verbatim).

     ```

     ```

5. `scripts/test-docker-smoke.sh` — append a "verifying secrets" section:
   - For each of the 5 active secrets: `docker compose exec -T dev bash -c "test -f /run/secrets/<name>"` → `echo "ok: <name> mounted"` (only if the file actually exists on the host; skip with a message if the placeholder is empty/absent).
6. bats test (optional but recommended): add a test to `scripts/__tests__/dev-entrypoint.bats` that verifies the 3 removed names are NOT loaded:
   - Create fixture files for `google_application_credentials`, `aws_access_key_id`, `aws_secret_access_key` in the namespace's `/run/secrets`.
   - Run the entrypoint and assert that `GOOGLE_APPLICATION_CREDENTIALS`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` are NOT set.

### Acceptance criteria (user perspective)

- `ALLOWED_SECRETS` in `dev-entrypoint.sh` contains exactly 5 names: `anthropic_api_key`, `openai_api_key`, `context7_api_key`, `github_token`, `exa_api_key`.
- `.gitignore` uses `secrets/*` + `!secrets/README.md`. Running `git check-ignore secrets/any_new_api_key` exits 0 (ignored); `git check-ignore secrets/README.md` exits 1 (not ignored).
- `secrets/README.md` documents the 5 active secrets and the `0600` permission requirement.
- `make test-infra` passes, including the new secrets assertions.
- The existing bats tests for the entrypoint still pass (they test with names that are still in the whitelist).

### Testing

- **Smoke test:** verifies mounted files inside the running container.
- **bats test:** verifies the removed names are NOT loaded (regression prevention).
- **git check-ignore:** verifies the .gitignore catch-all works for future-named keys.
- **RED-GREEN:** write the bats test for removed names first (fails because the current entrypoint loads them), then remove them from the whitelist.

---

## T4 — Stale documentation fixes

**Blockers:** none
**Vertical slice:** fix the two documentation references that point to deleted/stale information.
**Traces to:** M8

### What changes

1. `CONTAINER-SETUP.md` (line 76):
   - Change `.opencode/opencode.json` → `.opencode/opencode.jsonc`.
   - Audit: search the entire file for any other references to `opencode.json` (without the `c`) and fix them.
2. `docs/docker-dev.md`:
   - Fix the architecture diagram (lines 14-17) which claims turbo runs 3 services. Correction:
     ```
     pnpm dev  →  turbo runs author-studio (Quasar dev server)
                   api-server and publishing-platform are NOT started by turbo
                   (api-server is Python/FastAPI; publishing-platform has no dev script)
     ```
   - Update the "Quick Start" section: `make dev` starts author-studio only (not 3 services). Add a note about how to start the other services manually.
   - Add the host `make` prerequisite note (may already be added by T2; coordinate).

### Acceptance criteria (user perspective)

- `grep 'opencode\.json[^c]' CONTAINER-SETUP.md` returns no results (no dangling references to the deleted file).
- `docs/docker-dev.md` accurately describes what `pnpm dev` starts (author-studio only, not 3 services).
- A new developer following the Quick Start is not misled about the number of services started.

### Testing

- No automated test for documentation content. Verified by manual review and grep.
- The documentation fixes are low-risk (text-only changes).

---

## T5 — Process hygiene: tini + Xvfb hardening + restart policy

**Blockers:** none
**Vertical slice:** install tini for zombie reaping, harden Xvfb for headless automation, and add a restart policy to the dev service.
**Traces to:** M9

### What changes

1. `Dockerfile.dev`:
   - Add `ARG TINI_VERSION=0.19.0` to the ARG block.
   - Add a RUN step to install tini-static (pinned, arch-detected, matching the snip/uv install pattern):
     ```dockerfile
     RUN TINI_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "amd64" ;; aarch64|arm64) echo "arm64" ;; esac) && \
         curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-${TINI_ARCH}" -o /usr/local/bin/tini && \
         chmod +x /usr/local/bin/tini && \
         tini --version
     ```
   - Change `ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]` → `ENTRYPOINT ["tini", "--", "/usr/local/bin/dev-entrypoint.sh"]`.
2. `dev-entrypoint.sh` — Xvfb section (lines 32-36):
   - Add `rm -f /tmp/.X11-unix/X99` before the Xvfb launch (clear stale lock from crashed container).
   - Add `-ac -noreset` flags to the Xvfb invocation.
   - Remove the `[ ! -e /tmp/.X11-unix/X99 ]` lock check (no longer needed; we clear the lock unconditionally).
   - Result:
     ```bash
     if command -v Xvfb >/dev/null 2>&1; then
       rm -f /tmp/.X11-unix/X99
       Xvfb :99 -screen 0 1024x768x24 -ac -noreset >/dev/null 2>&1 &
       export DISPLAY=:99.0
     fi
     ```
3. `docker-compose.yml`:
   - Add `restart: unless-stopped` to the `dev` service (after `tty: true`).
4. `scripts/test-docker-smoke.sh` — append:
   - `docker compose exec -T dev cat /proc/1/comm` → assert output contains `tini` (note: implementation uses `/proc/1/comm` instead of `ps -p 1 -o comm=` because `procps` is absent from `debian:slim`)
   - `docker compose exec -T dev bash -c 'for p in /proc/[0-9]*/cmdline; do tr "\0" " " <"$p" 2>/dev/null; done | grep -q "[X]vfb.*-ac.*-noreset" && echo ok'` → assert `-ac` and `-noreset` flags are present (note: scans `/proc/[0-9]*/cmdline` instead of `ps aux | grep "[X]vfb"` because `procps` is absent)
5. `scripts/__tests__/dev-entrypoint.bats`:
   - Update the Xvfb test ("starts Xvfb and exports DISPLAY when available") to assert the flags:
     - Change `assert_output_contains "XVFB_LOG=[:99 -screen 0 1024x768x24]"` → `assert_output_contains "XVFB_LOG=[:99 -screen 0 1024x768x24 -ac -noreset]"`.
   - Update the "does not start Xvfb when the X99 lock already exists" test: the lock check is removed, so this test should be removed or changed to verify the lock is cleared.
6. `scripts/__tests__/bats-wrapper.sh`:
   - No change needed (already syntax-checks all scripts including dev-entrypoint.sh).

### Acceptance criteria (user perspective)

- `docker compose exec dev cat /proc/1/comm` prints `tini` (PID 1 is tini, not the entrypoint script). Note: implementation uses `/proc/1/comm` instead of `ps -p 1 -o comm=` because `procps` is absent from `debian:slim`.
- Xvfb runs with `-ac -noreset` flags (visible by scanning `/proc/[0-9]*/cmdline` inside the container — `procps` absent, so no `ps aux`).
- Stale Xvfb locks from crashed containers are cleared automatically (Xvfb starts even if a lock existed from a previous run).
- `docker compose config` shows `restart: unless-stopped` for the `dev` service.
- `make test-shell` passes (bats tests updated for new Xvfb flags).
- `make test-infra` passes (smoke test assertions for tini and Xvfb flags).

### Testing

- **Smoke test:** verifies tini is PID 1 and Xvfb has the correct flags inside the running container.
- **bats test:** verifies the entrypoint invokes Xvfb with the new flags (namespace-isolated, no Docker needed).
- **RED-GREEN:** update the bats test first (it fails because the current entrypoint does not pass `-ac -noreset`), then fix the entrypoint.

---

## T6 — `make test-infra` ordering fix

**Blockers:** T1, T2, T3, T4, T5
**Vertical slice:** restructure the `test-infra` target so it works on a cold start (no manual `make up` required).
**Traces to:** M1

### What changes

1. `Makefile`:
   - Change the `test-infra` target from prerequisites-based to recipe-based:

     ```makefile
     # Before:
     test-infra: gen-jsconfig test-shell test-python
     	bash scripts/test-docker-smoke.sh

     # After:
     test-infra: gen-jsconfig test-shell
     	docker compose up -d --build
     	bash scripts/test-docker-smoke.sh
     	$(MAKE) test-python
     	docker compose down
     ```

   - The smoke test's existing `docker compose up -d --build` and teardown trap are redundant with this orchestration. Two options:
     - (a) Keep the smoke test self-contained (it builds/starts/teardowns on its own); the Makefile's `docker compose up -d --build` before the smoke test is a no-op (already up). The smoke test's teardown stops the stack, then the Makefile restarts it for `test-python`, then tears down again. Double-build is cheap (Docker layer cache).
     - (b) Add a `--skip-build` flag to the smoke test to avoid the redundant build.
   - **Decision:** option (a) — keep the smoke test fully self-contained. The double-build is near-instant with Docker layer caching, and adding a flag to the smoke test increases complexity for marginal gain.

2. `scripts/test-docker-smoke.sh` — no change needed (remains self-contained: builds, starts, probes, tears down).

### Acceptance criteria (user perspective)

- `make down && make test-infra` passes end-to-end without any manual `make up` step.
- The ordering is: (1) gen-jsconfig, (2) test-shell (bats), (3) stack build+start, (4) smoke test probes, (5) test-python (needs stack up), (6) teardown.
- `test-python` always runs against a running stack (never on a cold start).
- If any step fails, `make test-infra` exits non-zero and the stack is torn down.

### Testing

- The test IS the cold-start execution: `make down && make test-infra` must pass.
- **RED-GREEN:** run `make down && make test-infra` first (it fails because test-python runs before the stack is up), then restructure the Makefile.

---

## T7 — exec-session secrets passthrough (H5)

**Blockers:** none (independent of T1–T6)
**Origin:** added post-implementation per orchestrator request during implementation; the reviewer flagged it as scope creep, so it is now formalized here as a new task.
**Vertical slice:** ensure `make opencode` / `docker compose exec dev bash` interactive sessions see the 5 API keys, while preserving the whitelist discipline.
**Traces to:** H5

### What changes

1. `docker-compose.yml` — `dev` service `environment:` block passes the 5 API keys from host env at compose-up time:

   ```yaml
   services:
     dev:
       environment:
         ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
         OPENAI_API_KEY: ${OPENAI_API_KEY:-}
         CONTEXT7_API_KEY: ${CONTEXT7_API_KEY:-}
         GITHUB_TOKEN: ${GITHUB_TOKEN:-}
         EXA_API_KEY: ${EXA_API_KEY:-}
   ```

   The `:-` default means: if the host does not have the var, pass empty string rather than failing compose-up.

2. `scripts/dev-secrets-profile.sh` (new file) — installed as `/etc/profile.d/secrets.sh` in `Dockerfile.dev`:
   - Whitelist mirrors `dev-entrypoint.sh` `ALLOWED_SECRETS` (same 5 names).
   - Sources `/run/secrets` files into interactive bash shells as a no-op fallback (compose env takes precedence).
   - Carries a `# KEEP IN SYNC with dev-entrypoint.sh ALLOWED_SECRETS` comment.
   - bats tests cover it (lines ~113–146 of `scripts/__tests__/dev-entrypoint.bats`): each whitelisted key loads, `aws_access_key_id` (not in whitelist) does NOT load.

3. `Dockerfile.dev` — `COPY scripts/dev-secrets-profile.sh` + `RUN install -m 0644 ... /etc/profile.d/secrets.sh`.

4. `scripts/__tests__/bats-wrapper.sh` — one line added: syntax-check of the new `scripts/dev-secrets-profile.sh` (extends the existing "syntax-check all scripts" loop to cover the new file).

5. `scripts/__tests__/dev-entrypoint.bats` — new tests (lines ~113–146) cover the profile script's whitelist behavior AND a whitelist-sync test that extracts the whitelist from BOTH `dev-entrypoint.sh` and `scripts/dev-secrets-profile.sh` and asserts they are identical (shotgun-surgery guard, see Acceptance Criteria).

6. `docs/docker-dev.md` — mention the exec-session secrets passthrough. Add a note in the secrets section that `docker compose exec` sessions see the 5 API keys via compose `environment:` passthrough, in addition to the `/run/secrets` mount mechanism.

### Acceptance criteria (user perspective)

- `make opencode` / `docker compose exec dev bash` sessions see `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `EXA_API_KEY` (they are set, not empty).
- `docker compose exec dev bash -lc 'echo "${AWS_ACCESS_KEY_ID:-}"'` returns empty (whitelist honored — AWS is not in the whitelist).
- `scripts/dev-secrets-profile.sh` and `dev-entrypoint.sh` `ALLOWED_SECRETS` carry `# KEEP IN SYNC` cross-reference comments.
- **Shotgun-surgery guard (reviewer Minor):** a bats test asserts the whitelist in `dev-entrypoint.sh` (`ALLOWED_SECRETS`) and the whitelist in `scripts/dev-secrets-profile.sh` (`_SECRETS_WHITELIST`) are byte-identical. The test extracts both (e.g., `grep -E '^ALLOWED_SECRETS=|^_SECRETS_WHITELIST=' <file>` + normalize) and diffs them. If a future change adds a key to one but not the other, this test fails — preventing drift.
- `docs/docker-dev.md` mentions the exec-session passthrough.
- `make test-shell` passes (bats tests for the profile script + whitelist-sync).
- `make test-infra` passes end-to-end.

### Testing

- **bats tests:** namespace-isolated tests in `dev-entrypoint.bats` cover the profile script's load behavior (whitelisted keys load, non-whitelisted do NOT) AND the whitelist-sync check.
- **Live probe:** `docker compose exec -T dev bash -lc 'echo "${ANTHROPIC_API_KEY:+set}"'` → `set`.
- **RED-GREEN:** write the whitelist-sync bats test first (fails when the two files have different whitelists), then write the profile script.

---

## Implementation order (suggested)

1. **Start with T1** (Playwright fix) — it is on the critical path and has the most complex Dockerfile change. While it builds, work on T2-T5 in parallel (they are independent).
2. **T2, T3, T4, T5** can proceed in any order or in parallel. T2 and T3 touch the Dockerfile, so they may conflict with T1 if run concurrently — sequential is safer.
3. **T7 (exec-session secrets)** — independent of T1–T6; can be done at any time (or in parallel with the above). Note: it was added post-implementation per orchestrator request, so in practice it was implemented alongside the other tasks.
4. **T6 last** — it depends on all other tasks being complete (the Makefile orchestrates the full pipeline that verifies all fixes).

## Open questions for the user before implementation

1. **T1 — Playwright install-deps scope:** should we install deps for ALL browsers (`playwright install-deps` without the `chromium` argument) or only chromium? The Dockerfile only installs chromium, so `install-deps chromium` is sufficient. But if a future change adds firefox/webkit, the deps would need to be re-installed. Recommend: `install-deps chromium` (minimal, matches current scope).

2. **T2 — Host `make` install documentation:** should the `docs/docker-dev.md` note include platform-specific instructions (Debian/Ubuntu `apt-get`, macOS `xcode-select --install`, Arch `pacman`)? Or just the Debian/Ubuntu command (matching the project's WSL/Debian focus)?

3. **T3 — Should the 3 removed secret names be preserved as comments in `ALLOWED_SECRETS`?** This makes it easy to re-enable them if a future service needs AWS/GCP. Alternative: just remove them cleanly; the git history preserves the names.

4. **T5 — tini version:** ~~`0.19.0` is the latest release (2023-09-19). Should we pin to a SHA256-verified download (matching the snip/uv pattern)?~~ **RESOLVED (implemented):** yes, SHA256 verification was added to the tini install block in `Dockerfile.dev`, matching the snip/uv pattern. The decision followed the original recommendation ("follow the SHA256 pattern for consistency with snip/uv"). See `design.md` for the updated install block.

5. **T6 — Smoke test idempotency:** the smoke test tears down the stack on exit. If `test-python` runs after the smoke test's teardown, the stack must be restarted. The proposed design does `docker compose up -d --build` before the smoke test, then the smoke test tears down, then `test-python` needs the stack again. Should we:
   - (a) Accept the double-start (cheap with cached layers)?
   - (b) Change the smoke test to NOT tear down on success (leave stack running for test-python)?
   - (c) Restructure so the Makefile manages the lifecycle entirely (smoke test gets a `--skip-build --skip-teardown` mode)?

   Recommendation: option (a) — simplest, keeps the smoke test self-contained.

## Out of scope for these tasks

- Adding new secrets beyond the existing 5.
- Creating a production Dockerfile for `api-server`.
- Configuring language servers (covered by `dev-infra-language-servers`).
- OpenCode config changes (covered by the AI Devtools Modernization Workflow).
- Tightening the smoke test's author-studio probe (currently skipped if node_modules is absent).
