#!/usr/bin/env bash
# Integration smoke test for the Docker dev stack (`make test-infra`).
#
# Heavier than the bats unit tests under scripts/__tests__: it actually builds
# the dev image, starts compose, and probes the running containers. Kept as a
# separate target so CI/local runs can skip it when Docker is unavailable.
#
# Verifies (aligned with docs/dev-infra-audit-plan.md + openspec/changes/dev-infra-stack-hardening):
#   1. docker compose builds + starts dev & postgres
#   2. postgres reports healthy and is reachable (pg_isready)
#   3. dev-entrypoint.sh is installed in the dev container
#   4. runtimes exist and run in the dev container (node, python3)
#   5. browser automation: playwright present, /opt/ms-playwright exists +
#      owned by dev, chromium actually launches headless (C1)
#   6. openspec is 1.7.0 and make is present (C2/C3)
#   6.5 trafilatura is present and version 2.2.0 (DIA-067)
#   7. secrets: /etc/profile.d/secrets.sh installed (H5); mounted-file probes
#      for the 5 active secrets only when the host file is non-empty (M2)
#   8. the entrypoint actually ran: Xvfb is up, DISPLAY is exported, and
#      Xvfb runs with the hardened -ac -noreset flags (M9)
#   9. tini is PID 1 (zombie reaping) (M9)
#  10. author-studio answers HTTP 200 on :9000 (see probe below)
#
# The stack is torn down on exit (trap). Note this STOPS any stack you had
# running — run it when you do not need the dev environment up.
#
# SMOKE_LEAVE_UP=1: leave the stack running on success (for callers
# that will use the stack immediately after, e.g. make test-infra).
#
# Design choices (review cleanup 2026-08-01 + dev-infra-stack-hardening):
#   - Secret FILES are probed only when the host file is non-empty: compose
#     requires the file to exist at `up` time (absent => compose fails), but an
#     empty placeholder is a developer responsibility, not a stack defect. The
#     entrypoint produces Xvfb/DISPLAY unconditionally, so that is the hermetic
#     "entrypoint ran" signal.
#   - PID 1 / Xvfb cmdline are read from /proc, not `ps`/`pgrep`: procps is not
#     guaranteed in debian:slim and would add a false dependency on apt state.
#   - The author-studio probe starts `pnpm dev` (turbo -> quasar dev on :9000)
#     inside the container, polls for HTTP 200, then kills the dev server.
#     Starting turbo dev is heavy, so when node_modules is not installed yet
#     (fresh clone before `make install`) the probe is SKIPPED with a pointer
#     to `make install` instead of failing the whole stack-health check.
#     DIA-048 Fix b: the skip guard is now a FRESHNESS guard
#     (scripts/author-studio-probe-guard.sh) — it also requires @quasar/app-vite
#     to resolve through the installed tree and FAILS loudly (exit 1) when the
#     tree is present but stale (stale pnpm_store named volume), instead of the
#     old presence-only `-x turbo` check that silently skipped or crashed with
#     MODULE_NOT_FOUND.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- Fail fast if Docker is unavailable --------------------------------------
if ! docker info >/dev/null 2>&1; then
  echo "error: Docker daemon is not running; cannot run the smoke test." >&2
  exit 1
fi

cleanup() {
  # F-3 (DIA-139): the SMOKE_LEAVE_UP guard lives here, in the teardown step,
  # NOT at bring-up, so the smoke test's validation logic is unchanged. On
  # success with SMOKE_LEAVE_UP=1 we keep the stack up (make test-infra reuses
  # it for test-python instead of rebuilding a second time); on failure we
  # still tear down so a broken stack does not linger.
  local rc=$?
  if [ "${SMOKE_LEAVE_UP:-}" = "1" ] && [ "$rc" -eq 0 ]; then
    echo "-> SMOKE_LEAVE_UP=1: leaving the stack running (caller will use it)"
    return 0
  fi
  echo "-> tearing down the stack..."
  docker compose down >/dev/null 2>&1 || true
}
trap cleanup EXIT

# wait_healthy <container> <timeout-seconds>
wait_healthy() {
  local container="$1"
  local timeout="${2:-120}"
  local waited=0
  local status="unknown"
  while [ "$waited" -lt "$timeout" ]; do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "$container" 2>/dev/null || echo unknown)"
    if [ "$status" = "healthy" ]; then
      echo "ok: $container healthy"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "error: $container not healthy after ${timeout}s (last status: $status)" >&2
  return 1
}

echo "-> building dev image and starting the stack (first run takes a while)..."
docker compose up -d --build

wait_healthy poetry-postgres 120
wait_healthy poetry-dev 180

echo "-> verifying dev-entrypoint.sh is installed..."
docker compose exec -T dev test -f /usr/local/bin/dev-entrypoint.sh
echo "ok: /usr/local/bin/dev-entrypoint.sh present in dev container"

echo "-> verifying runtimes exist and run..."
# Exact versions are owned by Dockerfile.dev; here we only assert that each
# runtime is installed and executes (a missing or misbuilt runtime fails loudly).
docker compose exec -T dev node --version >/dev/null
echo "ok: node present in dev container"
docker compose exec -T dev python3 --version >/dev/null
echo "ok: python3 present in dev container"

echo "-> verifying browser automation (C1: Playwright + crawl4ai)..."
# The triple-fault fix (wrong install path, missing system libs, root-only
# perms) is proven end-to-end: chromium must actually LAUNCH, not just install.
docker compose exec -T dev python3 -m playwright --version >/dev/null
echo "ok: playwright present in dev container"
docker compose exec -T dev bash -c 'test -d /opt/ms-playwright' || {
  echo "error: /opt/ms-playwright missing; PLAYWRIGHT_BROWSERS_PATH target not created" >&2
  exit 1
}
echo "ok: browser cache path /opt/ms-playwright exists"
owner="$(docker compose exec -T dev bash -c 'stat -c %U /opt/ms-playwright')"
if [ "$owner" != "dev" ]; then
  echo "error: /opt/ms-playwright owned by '$owner', expected dev" >&2
  exit 1
fi
echo "ok: browser cache path owned by dev"
docker compose exec -T dev python3 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True); b.close(); p.stop()"
echo "ok: chromium launches headless"

echo "-> verifying OpenSpec version and make (C2/C3)..."
# openspec is pinned in Dockerfile.dev; assert the exact version because 1.6.0
# validate --changes returns exit 0 on failure (false-green).
osver="$(docker compose exec -T dev openspec --version)"
if [[ "$osver" != *"1.7.0"* ]]; then
  echo "error: openspec --version is '$osver', expected 1.7.0" >&2
  exit 1
fi
echo "ok: openspec ${osver}"
docker compose exec -T dev make --version >/dev/null
echo "ok: make present in dev container"

echo "-> verifying trafilatura (DIA-067: source-capture for @conspecter)..."
# DIA-067: trafilatura is installed in Dockerfile.dev via the Option A fallback
# (`uv pip install --system --break-system-packages trafilatura==2.2.0`) —
# Option C (`uv tool install` + UV_TOOL_BIN_DIR) left the tool env under
# /root, unreadable by the dev user (see design.md §Risk 1).
# The probe asserts the binary is on PATH for the dev user and the version
# matches the pinned ARG. Follows the openspec version probe pattern (lines
# 118-128): `docker compose exec -T dev <tool> --version` + version-string
# assertion + `echo "ok: <tool> ${ver}"`.
traf_ver="$(docker compose exec -T dev trafilatura --version 2>&1)"
if [[ "$traf_ver" != *"2.2.0"* ]]; then
  echo "error: trafilatura --version is '$traf_ver', expected 2.2.0" >&2
  exit 1
fi
echo "ok: trafilatura ${traf_ver}"

# 7 probes (vs spec's 3): presence + resolution + pin parity (mise current == pins) + ENV + no-volta-remnants (AC1/AC2 runtime verification) — defensive testing for DIA-030 closure.
echo "-> verifying mise toolchain (replaces Volta; DIA-030 closure)..."
# DIA-030: Volta v2.0.2 was an unverified, unmaintained install (no upstream
# checksums). mise v2026.8.0 ships a SHASUMS256.txt manifest verified at image
# build time; these probes assert the binary is present, the mounted
# /workspace/.mise.toml resolves under MISE_TRUSTED_CONFIG_PATHS, the declared
# pins match the spec values, and the image sources carry no volta remnants.
docker compose exec -T dev mise --version >/dev/null
echo "ok: mise present in dev container"
# The mounted /workspace/.mise.toml must resolve under MISE_TRUSTED_CONFIG_PATHS
# (mise install downloads the pinned node/pnpm; mise which asserts the
# mise-managed tool is active — flag-a resolution, design.md §Context).
docker compose exec -T dev bash -c 'mise install >/dev/null && mise which node >/dev/null && mise which pnpm >/dev/null'
echo "ok: mise resolved .mise.toml pins (node + pnpm)"
node_pin="$(docker compose exec -T dev bash -c 'mise current node')"
if [ "$node_pin" != "24.18.0" ]; then
  echo "error: mise current node is '$node_pin', expected 24.18.0" >&2
  exit 1
fi
echo "ok: mise current node == 24.18.0"
pnpm_pin="$(docker compose exec -T dev bash -c 'mise current pnpm')"
if [ "$pnpm_pin" != "10.33.0" ]; then
  echo "error: mise current pnpm is '$pnpm_pin', expected 10.33.0" >&2
  exit 1
fi
echo "ok: mise current pnpm == 10.33.0"
docker compose exec -T dev bash -c '[ -n "${MISE_TRUSTED_CONFIG_PATHS:-}" ]' || {
  echo "error: MISE_TRUSTED_CONFIG_PATHS not set in the dev container" >&2
  exit 1
}
echo "ok: MISE_TRUSTED_CONFIG_PATHS set"
# Static source assertions: no volta install remnants in the image definitions
# (AC1/AC2). POSIX grep (not rg) — this script must run on hosts without
# ripgrep. The probe targets install tokens, NOT the historical "replaces
# Volta" mention in the design-sanctioned section header (design.md §2.4
# skeleton comment) — see the volta-to-mise implementation report for the
# deviation note on AC1's literal `grep -i volta` reading.
if grep -qiE 'volta-cli|VOLTA_VERSION|volta-shim|volta-migrate|volta\.tar|volta --version' Dockerfile.dev; then
  echo "error: Dockerfile.dev still references a volta install (DIA-030 not fully closed)" >&2
  exit 1
fi
echo "ok: no volta install remnants in Dockerfile.dev"
if grep -qiE 'volta-cli|VOLTA_VERSION|volta-shim|volta-migrate|volta\.tar|volta --version' tools/opencode-docker/Dockerfile; then
  echo "error: tools/opencode-docker/Dockerfile still references a volta install" >&2
  exit 1
fi
echo "ok: no volta install remnants in tools/opencode-docker/Dockerfile"

echo "-> verifying secrets passthrough (M2/H5)..."
# H5: compose exec shells do not inherit the entrypoint's exported vars; the
# /etc/profile.d/secrets.sh hook restores them for interactive shells.
docker compose exec -T dev test -f /etc/profile.d/secrets.sh
echo "ok: /etc/profile.d/secrets.sh present in dev container"
# Mounted-file probes only when the host file is non-empty: compose requires
# the file to exist at `up` time (absent => compose fails earlier), but an
# empty placeholder is a developer responsibility, not a stack defect.
for secret in anthropic_api_key openai_api_key context7_api_key github_token exa_api_key; do
  if [ -s "secrets/$secret" ]; then
    docker compose exec -T dev bash -c "test -f /run/secrets/$secret" || {
      echo "error: $secret not mounted at /run/secrets" >&2
      exit 1
    }
    echo "ok: $secret mounted"
  else
    echo "skip: secrets/$secret absent or empty; not asserting mount"
  fi
done

echo "-> verifying language servers exist and run..."
# Language server binaries are installed by Dockerfile.dev (pinned versions in
# the ARG block). We assert presence + execution, not analysis quality — each
# LS has its own test suite.
docker compose exec -T dev typescript-language-server --version >/dev/null
echo "ok: typescript-language-server present in dev container"
docker compose exec -T dev pyright --version >/dev/null
echo "ok: pyright present in dev container"
docker compose exec -T dev rust-analyzer --version >/dev/null
echo "ok: rust-analyzer present in dev container"

echo "-> verifying postgres is reachable..."
docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-poetry}" -d "${POSTGRES_DB:-poetry}"
echo "ok: postgres reachable"

echo "-> verifying the entrypoint set up Xvfb/DISPLAY..."
# DISPLAY alone is baked into the image ENV, so the Xvfb lock socket
# /tmp/.X11-unix/X99 is the real proof the entrypoint started Xvfb.
docker compose exec -T dev bash -c '[ -n "${DISPLAY:-}" ]' || {
  echo "error: DISPLAY not set in the dev container" >&2
  exit 1
}
docker compose exec -T dev test -e /tmp/.X11-unix/X99 || {
  echo "error: Xvfb lock socket /tmp/.X11-unix/X99 missing; entrypoint may not have started Xvfb" >&2
  exit 1
}
echo "ok: DISPLAY set and Xvfb lock present"

echo "-> verifying process hygiene (M9: tini PID 1 + Xvfb hardening)..."
# procps (ps/pgrep) is not guaranteed in debian:slim, so we read /proc
# directly — /proc/1/comm is the executable name of PID 1. tini must be PID 1
# for zombie reaping (docker's default PID 1 does not reap children).
pid1="$(docker compose exec -T dev cat /proc/1/comm)"
if [[ "$pid1" != *"tini"* ]]; then
  echo "error: PID 1 is '$pid1', expected tini" >&2
  exit 1
fi
echo "ok: tini is PID 1"
# Scan /proc for the Xvfb cmdline (no procps dependency). Must show the
# hardened flags: -ac (no access control) and -noreset (keep display alive).
xvfb_cmdline="$(docker compose exec -T dev bash -c '
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    cmdline=$(tr "\0" " " < "$d/cmdline" 2>/dev/null || true)
    case "$cmdline" in Xvfb*) printf "%s" "$cmdline"; break ;; esac
  done
')"
if [[ "$xvfb_cmdline" != *"-ac"* ]] || [[ "$xvfb_cmdline" != *"-noreset"* ]]; then
  echo "error: Xvfb missing hardened flags; got: '$xvfb_cmdline'" >&2
  exit 1
fi
echo "ok: Xvfb runs with -ac -noreset"

echo "-> probing author-studio on :9000..."
# DIA-048 Fix b: freshness guard, not presence-only. The guard lives in a
# separate host-testable script (scripts/author-studio-probe-guard.sh) invoked
# INSIDE the container — the repo is bind-mounted at /workspace, so the guard
# is always current there without an image rebuild. Exit codes: 0 = toolchain
# fresh (run the probe), 1 = node_modules present but stale/incomplete (FAIL
# loudly — the old guard silently skipped or crashed with MODULE_NOT_FOUND),
# 2 = node_modules absent (fresh clone before make install — skip with pointer).
guard_out="$(docker compose exec -T dev bash /workspace/scripts/author-studio-probe-guard.sh 2>&1)" && guard_rc=0 || guard_rc=$?
case "$guard_rc" in
  0)
    echo "$guard_out"
    ;;
  2)
    echo "$guard_out"
    echo "skip: author-studio probe not exercised (node_modules absent; stack-health checks still passed)"
    ;;
  *)
    echo "error: author-studio probe precheck failed (guard exit $guard_rc):" >&2
    echo "$guard_out" >&2
    exit 1
    ;;
esac

if [ "$guard_rc" = "0" ]; then
  # Start pnpm dev (turbo -> quasar dev on :9000) in the background, poll for
  # HTTP 200, then kill it. timeout guarantees the dev server dies even when
  # the probe fails; everything runs in-container so nothing leaks on the host.
  docker compose exec -T dev bash -c '
    set -euo pipefail
    timeout 180 pnpm dev >/tmp/smoke-pnpm-dev.log 2>&1 &
    pid=$!
    code=000
    for i in $(seq 1 90); do
      # --max-time 5: a dead/hung dev server would otherwise stall the probe
      # until the default curl timeout (minutes) instead of failing fast (T6).
      c=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:9000 2>/dev/null || true)
      [ -n "$c" ] && code=$c
      [ "$code" = "200" ] && break
      sleep 2
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    if [ "$code" != "200" ]; then
      echo "error: author-studio did not return HTTP 200 on :9000 (last code: $code)" >&2
      tail -n 40 /tmp/smoke-pnpm-dev.log >&2 || true
      exit 1
    fi
    echo "ok: author-studio returned HTTP 200 on :9000"
  '
fi

echo "ok: docker smoke test passed"
