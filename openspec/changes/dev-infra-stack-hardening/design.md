# Design: dev-infra-stack-hardening

> **Proposal:** `openspec/changes/dev-infra-stack-hardening/proposal.md`
> **Scope:** dev-infra only — no system architecture decisions, no `.sdd/` escalation required.

## Approach

This change stays within the existing dev-infra module boundary. No new module is introduced, no cross-cutting technology decision is made, and `architecture.md` is not affected. The design follows established patterns in the codebase:

- **Dockerfile layer ordering pattern:** fix the Playwright path issue by moving the `ENV PLAYWRIGHT_BROWSERS_PATH` declaration **before** the install step and creating `/opt/ms-playwright` with correct ownership. This matches the existing pattern used for `RUSTUP_HOME=/opt/rust/rustup` (lines 110-112), which is also set before the install and chowned to `dev`.
- **apt-get package list pattern:** extend the existing single `apt-get install --no-install-recommends` block (lines 41-55) rather than adding a separate RUN layer.
- **tini pattern:** use the existing bats-core vendor pattern (install a pinned binary, no apt dependency) — download `tini` from GitHub releases with SHA256 verification, matching the snip/uv install patterns already in the Dockerfile.
- **Secrets whitelist pattern:** reduce `ALLOWED_SECRETS` in `dev-entrypoint.sh` to match what `docker-compose.yml` actually mounts (the existing 5 names). This follows the principle of "whitelist only what you use."
- **.gitignore catch-all pattern:** replace the per-name allowlist with `secrets/*` + `!secrets/README.md`. This matches standard gitignore patterns for directories where all contents except one file should be ignored.
- **Smoke test extension pattern:** append assertions to `scripts/test-docker-smoke.sh` using the existing `docker compose exec -T dev <tool> --version` shape.
- **bats test extension pattern:** extend `scripts/__tests__/dev-entrypoint.bats` for the Xvfb flag changes, following the existing namespace-isolated harness.
- **Makefile ordering pattern:** restructure `test-infra` dependencies so `test-python` runs last (after the smoke test has started the stack).

## Files changed

| File                                    | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Traced to          |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `Dockerfile.dev`                        | (1) Move `PLAYWRIGHT_BROWSERS_PATH` ENV before Playwright install; (2) add `RUN mkdir -p /opt/ms-playwright && chown -R ${USER_UID}:${USER_GID} /opt/ms-playwright` before user switch; (3) add `python3 -m playwright install-deps chromium`; (4) bump `OPENSPEC_VERSION` to `1.7.0`; (5) add `make` to apt-get list; (6) install `tini` (pinned, SHA256-verified); (7) change ENTRYPOINT to `[\"tini\", \"--\", \"/usr/local/bin/dev-entrypoint.sh\"]`; (8) `COPY scripts/dev-secrets-profile.sh` + install to `/etc/profile.d/secrets.sh` | C1, C2, C3, M9, H5 |
| `dev-entrypoint.sh`                     | (1) Add `-ac -noreset` to Xvfb invocation; (2) add `rm -f /tmp/.X11-unix/X99` before lock check; (3) reduce `ALLOWED_SECRETS` to 5 names matching compose mounts                                                                                                                                                                                                                                                                                                                                                                             | C1, M2, M9         |
| `docker-compose.yml`                    | (1) Remove `google_application_credentials`, `aws_access_key_id`, `aws_secret_access_key` from secrets allowlist — they were never in the `secrets:` top-level key or `dev.secrets:` list; (2) add `restart: unless-stopped` to `dev` service; (3) add `environment:` block on `dev` service passing the 5 API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `EXA_API_KEY`) from `${VAR:-}` host env at compose-up time                                                                                   | M2, M9, H5         |
| `Makefile`                              | Reorder `test-infra`: move `test-python` to run after the smoke test body, not as a prereq                                                                                                                                                                                                                                                                                                                                                                                                                                                   | M1                 |
| `.gitignore`                            | Replace the explicit secrets per-name allowlist with `secrets/*` + `!secrets/README.md`                                                                                                                                                                                                                                                                                                                                                                                                                                                      | M7                 |
| `CONTAINER-SETUP.md`                    | Fix line 76: `.opencode/opencode.json` → `.opencode/opencode.jsonc`                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | M8                 |
| `docs/docker-dev.md`                    | (1) Fix turbo service count claim (only author-studio has `dev` script); (2) add note about host `make` install requirement                                                                                                                                                                                                                                                                                                                                                                                                                  | M8, C3             |
| `secrets/README.md`                     | Reduce the allowed-filenames table to match the 5 active secrets; add a note that files must be non-empty and 0600                                                                                                                                                                                                                                                                                                                                                                                                                           | M2                 |
| `scripts/test-docker-smoke.sh`          | Add assertions for: Playwright version + chromium launch, OpenSpec version, make presence, tini PID 1, Xvfb flags, restart policy                                                                                                                                                                                                                                                                                                                                                                                                            | All                |
| `scripts/__tests__/dev-entrypoint.bats` | Update Xvfb test to assert `-ac -noreset` flags are present in the invocation                                                                                                                                                                                                                                                                                                                                                                                                                                                                | M9                 |
| `scripts/__tests__/bats-wrapper.sh`     | One line added: syntax-check of the new `scripts/dev-secrets-profile.sh` (extends the existing "syntax-check all scripts" loop to cover the new file)                                                                                                                                                                                                                                                                                                                                                                                        | H5                 |

## Data flow

### Playwright path fix (C1)

**Before (broken):**

```
Dockerfile.dev (as root):
  ENV PLAYWRIGHT_BROWSERS_PATH is NOT yet set
  RUN python3 -m playwright install chromium
    → installs to /root/.cache/ms-playwright (default, root-owned)

  ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright  # set AFTER install
  USER dev
  → Runtime: playwright looks in /opt/ms-playwright (empty, nonexistent)
  → chromium also missing system libs → dies on libglib-2.0.so.0
```

**After (fixed):**

```
Dockerfile.dev (as root):
  ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright  # set BEFORE install
  RUN mkdir -p /opt/ms-playwright
  RUN python3 -m playwright install-deps chromium   # system libs (apt)
  RUN python3 -m playwright install chromium
    → installs to /opt/ms-playwright (correct path)
  RUN chown -R ${USER_UID}:${USER_GID} /opt/ms-playwright  # dev-user accessible (UID/GID vars, matches tasks.md)

  USER dev
  → Runtime: playwright finds browsers at /opt/ms-playwright
  → chromium starts: system libs present, correct path, correct perms
```

This mirrors the Rust toolchain pattern at lines 107-117 of the current Dockerfile: ENV set before install, dedicated directory under /opt, chowned to dev.

### test-infra ordering fix (M1)

**Before (broken):**

```makefile
test-infra: gen-jsconfig test-shell test-python
	bash scripts/test-docker-smoke.sh
```

`test-python` runs as a prerequisite → `docker compose exec` fails on a cold start because the stack is not up.

**After (fixed):**

```makefile
test-infra: gen-jsconfig test-shell
	bash scripts/test-docker-smoke.sh   # builds/starts the stack
	$(MAKE) test-python                  # runs AFTER stack is up
```

The smoke test builds and starts the stack (it already does `docker compose up -d --build`). `test-python` runs after the smoke test, when the container is guaranteed to be up.

Alternative considered: making `test-python` a dependency of the smoke test body. Rejected because the smoke test tears down the stack on exit (`trap cleanup EXIT`), so `test-python` would have no stack to run against. The correct fix is to run `test-python` between the smoke test's "up" and "down" phases — but that would require restructuring the smoke test itself. The simpler approach is to make the smoke test NOT tear down on success (keep the trap for failure only), then run `test-python`, then tear down.

**Revised decision:** Change the smoke test's cleanup trap to only tear down on failure. On success, leave the stack running. Then `test-python` can run in the Makefile after the smoke test. Add a separate `make test-infra-cleanup` target for explicit teardown. This keeps `make test-infra` self-contained while allowing `test-python` to use the running stack.

Actually, on further review: the smoke test's current teardown-on-exit is intentional (it says "Note this STOPS any stack you had running"). The cleanest fix that does not change the smoke test's semantics is:

```makefile
test-infra: gen-jsconfig test-shell
	bash scripts/test-docker-smoke.sh
	docker compose up -d   # ensure stack is up (no-op if smoke test left it)
	$(MAKE) test-python
	docker compose down    # cleanup
```

But this starts the stack twice if the smoke test's trap already cleaned up. The simplest correct fix:

```makefile
.PHONY: test-infra-up
test-infra-up:
	docker compose up -d --build

test-infra: gen-jsconfig test-shell test-infra-up test-python
	bash scripts/test-docker-smoke.sh
```

No — this runs the smoke test AFTER test-python, but the smoke test also builds and starts. The ordering of prerequisites in Make is left-to-right but they run in parallel if possible with `-j`.

**Final decision:** Restructure as a recipe, not prerequisites:

```makefile
test-infra: gen-jsconfig test-shell
	set -euo pipefail; \
	docker compose up -d --build; \
	bash scripts/test-docker-smoke.sh --skip-build; \
	$(MAKE) test-python; \
	docker compose down
```

This is the cleanest approach: one recipe, explicit ordering, stack lifecycle managed in one place. The smoke test gets a `--skip-build` flag to avoid rebuilding when called from `test-infra`.

**SIMPLEST correct decision (final):** Keep the smoke test's self-contained build+start+teardown behavior. Restructure `test-infra` to:

```makefile
test-infra: gen-jsconfig test-shell
	bash scripts/test-docker-smoke.sh
	docker compose up -d --build
	$(MAKE) test-python
	docker compose down
```

The smoke test builds, probes, and tears down. Then we build+start again (fast, layers are cached), run test-python, then tear down. The double-build is acceptable because Docker layer caching makes the second build near-instant. This keeps the smoke test fully self-contained and adds minimal complexity.

### Secrets consistency fix (M2)

**Before (broken):**

```
dev-entrypoint.sh ALLOWED_SECRETS (8 names):
  anthropic_api_key, openai_api_key, context7_api_key,
  google_application_credentials, aws_access_key_id, aws_secret_access_key,
  github_token, exa_api_key

docker-compose.yml secrets (5 names):
  anthropic_api_key, openai_api_key, context7_api_key,
  github_token, exa_api_key

→ 3 whitelisted names are never mounted → env vars are empty strings
→ secrets/* files are 0644 (world-readable) AND 0-byte → empty env vars
```

**After (fixed):**

```
dev-entrypoint.sh ALLOWED_SECRETS (5 names):
  anthropic_api_key, openai_api_key, context7_api_key,
  github_token, exa_api_key
  (matches docker-compose.yml exactly)

secrets/README.md: documents the 5 active secrets + 0600 permission requirement
secrets/* files: documented as 0600 + non-empty developer responsibility
```

### .gitignore catch-all (M7)

**Before:**

```gitignore
secrets/*.key
secrets/anthropic_api_key
secrets/openai_api_key
secrets/context7_api_key
secrets/github_token
secrets/exa_api_key
secrets/aws_*
secrets/google_application_credentials
```

A new file like `secrets/foobar_api_key` would NOT be ignored → committed to git.

**After:**

```gitignore
secrets/*
!secrets/README.md
```

All files in `secrets/` are ignored except `README.md`. Future-named keys are automatically protected.

### Process hygiene (M9)

**tini install (Dockerfile.dev):**

```dockerfile
ARG TINI_VERSION=0.19.0
ARG TINI_SHA256_AMD64=...   # pinned per-release, matches snip/uv pattern
ARG TINI_SHA256_ARM64=...
RUN TINI_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "amd64" ;; aarch64|arm64) echo "arm64" ;; esac) && \
    TINI_SHA=$(case "${TINI_ARCH}" in amd64) echo "${TINI_SHA256_AMD64}" ;; arm64) echo "${TINI_SHA256_ARM64}" ;; esac) && \
    curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-${TINI_ARCH}" -o /usr/local/bin/tini && \
    echo "${TINI_SHA}  /usr/local/bin/tini" | sha256sum -c - && \
    chmod +x /usr/local/bin/tini && \
    tini --version
```

Uses `tini-static` (no glibc dependency concerns) with the same arch-detection + pinned-version + **SHA256 verification** pattern as snip/uv. The original design sketch omitted the SHA256 step; implementation added it per the open question in tasks.md T5 #4 ("Recommend: follow the SHA256 pattern for consistency with snip/uv"). The verification matches the project's established pattern for self-contained binary installs where supply-chain integrity matters.

**ENTRYPOINT change:**

```dockerfile
ENTRYPOINT ["tini", "--", "/usr/local/bin/dev-entrypoint.sh"]
```

tini becomes PID 1, reaps zombies, forwards signals to the entrypoint's children.

**Xvfb hardening (dev-entrypoint.sh):**

```bash
# Before:
Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &

# After:
rm -f /tmp/.X11-unix/X99  # clear stale lock from crashed container
Xvfb :99 -screen 0 1024x768x24 -ac -noreset >/dev/null 2>&1 &
```

- `-ac`: disable access control (required for headless Playwright/crawl4ai connecting without xauth).
- `-noreset`: prevent Xvfb from resetting on last client disconnect (keeps the display alive across process restarts).
- `rm -f /tmp/.X11-unix/X99`: handle stale lock from a previous crashed container (the existing lock check `[ ! -e /tmp/.X11-unix/X99 ]` would otherwise skip Xvfb startup).

Wait — if we `rm -f` the lock unconditionally, the existing lock check becomes useless. The correct approach:

```bash
if command -v Xvfb >/dev/null 2>&1; then
  # Clear stale lock (safe: if Xvfb is actually running, the socket is in use
  # and rm will succeed but Xvfb will fail to bind — caught by the launch).
  # In a fresh container, the lock does not exist, so rm is a no-op.
  rm -f /tmp/.X11-unix/X99
  Xvfb :99 -screen 0 1024x768x24 -ac -noreset >/dev/null 2>&1 &
  export DISPLAY=:99.0
fi
```

This is simpler than the current approach (which checks for the lock and skips Xvfb if present). In a Docker container, there is no risk of conflicting with a host Xvfb because the container has its own /tmp. The stale-lock scenario is: the container was killed mid-run, the lock file persisted in the container's writable layer (or on a mounted tmpfs). Removing it unconditionally is safe.

**docker-compose.yml restart policy:**

```yaml
services:
  dev:
    restart: unless-stopped
    # ... rest unchanged
```

Matches the postgres service's restart policy.

### exec-session secrets passthrough (H5)

**Why this is needed (post-implementation finding):**

The existing secrets mechanism works for the entrypoint: `dev-entrypoint.sh` reads files from `/run/secrets/` and exports them as env vars. But `docker compose exec` spawns a _new_ process inside the running container — it does NOT inherit the entrypoint's exports. So `docker compose exec dev bash -c 'echo $ANTHROPIC_API_KEY'` returns empty, breaking `make opencode` and interactive sessions that need the API keys.

**Mechanism (two complementary layers):**

```
Layer 1 — compose-time environment passthrough (docker-compose.yml):

services:
  dev:
    environment:
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
      OPENAI_API_KEY:    ${OPENAI_API_KEY:-}
      CONTEXT7_API_KEY:  ${CONTEXT7_API_KEY:-}
      GITHUB_TOKEN:      ${GITHUB_TOKEN:-}
      EXA_API_KEY:       ${EXA_API_KEY:-}

  → At `docker compose up` time, the 5 vars are read from the HOST env and
    baked into the dev service's process env. Every `exec` of any process
    inside that container inherits these vars (they live in the container's
    env namespace, not in the entrypoint's shell state).
  → The `:-` default means: if the host doesn't have the var, pass empty
    string rather than failing compose-up. This preserves the
    "developer must populate secrets/ files" workflow — compose-up does
    not fail just because a secret file is empty.

Layer 2 — profile.d script (scripts/dev-secrets-profile.sh → /etc/profile.d/secrets.sh):

  #!/usr/bin/env bash
  # KEEP IN SYNC with dev-entrypoint.sh ALLOWED_SECRETS — both whitelists
  # must contain exactly the same 5 names. A bats test enforces this.
  _SECRETS_WHITELIST="anthropic_api_key openai_api_key context7_api_key github_token exa_api_key"
  for _name in $_SECRETS_WHITELIST; do
    if [ -r "/run/secrets/$_name" ]; then
      _val="$(cat "/run/secrets/$_name")"
      _upper="$(echo "$_name" | tr '[:lower:]' '[:upper:]')"
      # Only set if not already set (compose env takes precedence).
      eval "export \${_upper}=\${${_upper}:-\$_val}"
    fi
  done
  unset _name _val _upper _SECRETS_WHITELIST

  → Installed in Dockerfile.dev as /etc/profile.d/secrets.sh.
  → Sourced automatically by interactive bash shells (login or interactive
    non-login, depending on system config — /etc/profile.d/* is sourced by
    bash's /etc/profile and by /etc/bash.bashrc on Debian).
  → Acts as a no-op fallback for exec sessions that already got the keys
    from compose env (the `${VAR:-}` expansion does not overwrite).
  → Acts as the load mechanism for any scenario where compose env is not
    enough (e.g., a manually started container without compose, or a
    developer who adds a new key file to /run/secrets between compose-up
    and exec — though this is not a supported workflow).
```

**Trade-off (documented, accepted):**

compose `environment:` passthrough widens `/proc/1/environ` visibility for the 5 API keys — any process inside PID 1's env namespace can read them. The alternative — relying solely on `/run/secrets` mounts — would require exec sessions to manually re-source secrets, breaking `make opencode` / `docker compose exec dev bash` interactive workflows.

Accepted for the dev container because:

- (a) the dev container is single-tenant per developer,
- (b) the secrets are the developer's own keys,
- (c) production containers use a different, stricter secrets mechanism.

This trade-off is NOT applicable to production images. The dev-container-only nature of this decision should be preserved if this code is ever refactored.

**Shotgun-surgery risk (reviewer Minor):**

The 5-name whitelist lives in TWO places:

- `dev-entrypoint.sh`: `ALLOWED_SECRETS="anthropic_api_key openai_api_key context7_api_key github_token exa_api_key"`
- `scripts/dev-secrets-profile.sh`: `_SECRETS_WHITELIST="anthropic_api_key openai_api_key context7_api_key github_token exa_api_key"`

Both files carry `# KEEP IN SYNC with <other-file>` comments. A bats test asserts both whitelists stay in sync (extract both and `diff` them — see T7 acceptance criteria).

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live."

| Seam                                                            | What it is                                                 | Test location                                                                  | Test type                                                                                                            |
| --------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| **Container image** (Dockerfile.dev build output)               | The built dev container with all fixes                     | `scripts/test-docker-smoke.sh`                                                 | Smoke: binary presence, version probes, path checks                                                                  |
| **Entrypoint script** (`dev-entrypoint.sh`)                     | Secrets loading + Xvfb startup                             | `scripts/__tests__/dev-entrypoint.bats`                                        | Behavioral: Xvfb flags, secret whitelist                                                                             |
| **Profile.d secrets script** (`scripts/dev-secrets-profile.sh`) | Interactive-shell secrets sourcing (exec-session fallback) | `scripts/__tests__/dev-entrypoint.bats` (lines ~113–146) + whitelist-sync test | Behavioral: whitelisted keys load; non-whitelisted do NOT; whitelist matches entrypoint's                            |
| **Makefile `test-infra` target**                                | Orchestrates the full test lifecycle                       | `make test-infra` (cold start)                                                 | End-to-end: ordering must work without manual `make up`                                                              |
| **.gitignore**                                                  | Secrets protection pattern                                 | `git check-ignore` (manual or bats)                                            | Shape: future-named keys are ignored, README.md is not                                                               |
| **docker-compose.yml**                                          | Stack definition                                           | `docker compose config`                                                        | Shape: valid YAML, restart policy present, secrets list matches whitelist; `environment:` passthrough for 5 API keys |

### New seams vs. existing seams

- **Container image** — existing seam (already tested for node, python3, language servers). Extended with Playwright, OpenSpec, make, tini assertions.
- **Entrypoint script** — existing seam (already tested by dev-entrypoint.bats). Extended with Xvfb flag assertions and the new profile-script whitelist-sync test.
- **Profile.d secrets script** (`scripts/dev-secrets-profile.sh`) — **new seam** introduced by T7/H5. Tested via the same `dev-entrypoint.bats` harness (namespace-isolated, same test-helper pattern as existing entrypoint tests). Coverage: whitelisted keys load, non-whitelisted do NOT, whitelist matches entrypoint's.
- **Makefile, .gitignore, docker-compose.yml** — existing seams, extended (docker-compose.yml gains the `environment:` passthrough block).

## Design constraints and trade-offs

### Why tini-static instead of tini (dynamic) or dumb-init

- **Static binary:** no glibc version dependency, works on any Debian version. Matches the project's pattern of self-contained binary installs (snip, uv).
- **tini over dumb-init:** tini is smaller (one binary, no config), has signal forwarding + zombie reaping, and is the Docker-recommended init. dumb-init is also fine but adds a config file.
- **Why not just use `exec` in the entrypoint?** The entrypoint already uses `exec "$@"`, which replaces the shell process. But Playwright/crawl4ai spawn child processes that may not be properly reaped without an init. tini as PID 1 ensures all zombies are reaped regardless of how children are spawned.

### Why remove AWS/GCP secrets instead of mounting them

- **No service uses them:** `docker-compose.yml` does not define them in the `secrets:` top-level key. No application code references `AWS_ACCESS_KEY_ID` or `GOOGLE_APPLICATION_CREDENTIALS`.
- **Dead code in the whitelist creates confusion:** developers see them in `secrets/README.md` and think they should create the files. Removing them eliminates the confusion.
- **Easy to re-add:** if a future service needs AWS/GCP, the developer adds to both `docker-compose.yml` and `ALLOWED_SECRETS` in the same change.

### Why `secrets/*` + `!secrets/README.md` instead of per-name entries

- **Future-proof:** any new secret file is automatically ignored. No need to update .gitignore for each new key.
- **Simpler:** 2 lines instead of 8.
- **Standard pattern:** this is the idiomatic gitignore pattern for "ignore everything in a directory except one file."

### Why not change the smoke test's teardown behavior

- **Current behavior is intentional:** the smoke test says "Note this STOPS any stack you had running." Changing it to leave the stack up would surprise developers who run it while working.
- **Double-build is cheap:** Docker layer caching makes the second `docker compose up -d --build` near-instant (all layers are cached from the smoke test's build).
- **Separation of concerns:** the smoke test verifies the stack; the Makefile orchestrates the workflow. Keeping them independent is cleaner.

### Why `--skip-build` is NOT added to the smoke test

- **Simplicity:** the smoke test already builds the image. Running it again after the Makefile's build would be redundant. But the smoke test's build is near-instant (cached), so the redundancy is acceptable.
- **Self-contained:** the smoke test can be run standalone (`bash scripts/test-docker-smoke.sh`) without any Makefile orchestration. Adding a `--skip-build` flag adds complexity for a marginal gain.

### Why compose `environment:` passthrough instead of relying solely on `/run/secrets` (H5)

- **The problem:** `docker compose exec` spawns a new process that does NOT inherit the entrypoint's env-var exports. The `/run/secrets` files are mounted, but they need to be sourced; the entrypoint sources them for its own process tree, but an `exec`'d bash starts a new tree. So `docker compose exec dev bash -c 'echo $ANTHROPIC_API_KEY'` returns empty, breaking `make opencode` and interactive sessions that need API keys.
- **Alternative considered:** require every exec session to manually `source /etc/profile.d/secrets.sh`. Rejected because: (a) it's easy to forget, (b) non-interactive commands (`docker compose exec -T dev <tool>` used by CI/Makefile) do not source profile.d by default, (c) it makes the API-key-availability invariant implicit rather than structural.
- **Trade-off accepted:** compose `environment:` passthrough widens `/proc/1/environ` visibility for the 5 API keys inside the container. This is acceptable because:
  - Dev container is single-tenant (one developer per container).
  - The secrets are the developer's own keys, not shared credentials.
  - Production containers use a different, stricter secrets mechanism (this decision is dev-container-only).
  - The alternative (manual sourcing per exec) trades a small information-disclosure risk for a large usability regression.
- **Defense in depth:** the profile.d whitelist is enforced to match the entrypoint whitelist by a bats test; both files carry `# KEEP IN SYNC` cross-references. The compose `environment:` block uses the same 5 names.
