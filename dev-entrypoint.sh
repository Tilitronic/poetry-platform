#!/usr/bin/env bash
# Dev container entrypoint:
#  1. Load secrets from /run/secrets into env (whitelisted only)
#  2. Start Xvfb for browser automation
#  3. exec the passed command (default: bash)
set -euo pipefail

# --- Secrets: load whitelisted files from /run/secrets into env ---
# Secret files are mounted read-only via compose `secrets:`. Only known names
# are honored; anything else is skipped with a warning. The whitelist matches
# docker-compose.yml `secrets:` exactly — names here must never drift from what
# compose actually mounts (google/aws names were removed in M2: no service
# uses them, and dead whitelist entries created empty env vars). Keep in sync
# with scripts/dev-secrets-profile.sh.
ALLOWED_SECRETS=(
  "anthropic_api_key"
  "openai_api_key"
  "context7_api_key"
  "github_token"
  "exa_api_key"
)

if [ -d /run/secrets ]; then
  for secret in "${ALLOWED_SECRETS[@]}"; do
    file="/run/secrets/${secret}"
    if [ ! -f "$file" ]; then
      continue
    fi
    # Zero-byte files are the documented "not configured" placeholder state
    # (secrets/README.md) — skip them (degraded boot, never crash) so an empty
    # value never overwrites a developer-provided env var. Strict `-s` check
    # (E1): whitespace-only files are non-empty and still load.
    if [ ! -s "$file" ]; then
      echo "[dev-entrypoint] [skip] secret '${secret}': file empty or zero-byte, not wiring" >&2
      continue
    fi
    var_name=$(echo "${secret}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    export "${var_name}=$(cat "$file")"
  done
fi

# --- Xvfb for browser automation (Playwright/crawl4ai) ---
# Hardened invocation (M9):
#   -ac       disable access control — headless automation connects without xauth
#   -noreset  keep the display alive across client disconnect/restarts
# The lock file is cleared unconditionally: in a fresh container it does not
# exist (rm -f is a no-op), and after a crashed container it would otherwise
# make the old lock check skip Xvfb entirely. Each container has its own /tmp,
# so there is no host Xvfb to conflict with.
if command -v Xvfb >/dev/null 2>&1; then
  rm -f /tmp/.X11-unix/X99
  Xvfb :99 -screen 0 1024x768x24 -ac -noreset >/dev/null 2>&1 &
  export DISPLAY=:99.0
fi

# --- Exec the requested command ---
exec "$@"
