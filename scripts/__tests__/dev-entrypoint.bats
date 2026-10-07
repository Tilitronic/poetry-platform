#!/usr/bin/env bats
# Unit tests for dev-entrypoint.sh (repo root).
#
# The script hardcodes /run/secrets and /tmp/.X11-unix/X99, which a non-root
# user cannot create on the host. Every test therefore runs inside
# `unshare -r -m` (user + mount namespace) with tmpfs over /run and /tmp,
# giving full control of the secret files and the Xvfb lock (see
# run_entrypoint_ns in test-helper.bash). No Docker, no root required.

load test-helper

@test "dev-entrypoint: loads whitelisted secrets and skips others" {
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  printf 'sk-123' > "$secrets/anthropic_api_key"
  printf 'sk-evil' > "$secrets/not_allowed"

  export NS_SECRETS_DIR="$secrets"
  run_entrypoint_ns bash -c 'printf "AK=[%s]\nNA=[%s]\n" "$ANTHROPIC_API_KEY" "${NOT_ALLOWED:-}"'

  assert_status 0
  assert_output_contains "AK=[sk-123]"
  # not_allowed is not on the ALLOWED_SECRETS whitelist -> never exported
  assert_output_contains "NA=[]"
}

@test "dev-entrypoint: loads multiple whitelisted secrets with env-style names" {
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  printf 'openai-key' > "$secrets/openai_api_key"
  printf 'gh-token' > "$secrets/github_token"

  export NS_SECRETS_DIR="$secrets"
  run_entrypoint_ns bash -c 'printf "%s|%s\n" "$OPENAI_API_KEY" "$GITHUB_TOKEN"'

  assert_status 0
  assert_output_contains "openai-key|gh-token"
}

@test "dev-entrypoint: does not load the removed aws/gcp secret names" {
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  # These names were removed from ALLOWED_SECRETS (M2): docker-compose.yml
  # never mounts them and no service uses them. Regression guard: even if a
  # developer creates the files, the entrypoint must not export the vars.
  printf 'gcp-creds' > "$secrets/google_application_credentials"
  printf 'aws-key' > "$secrets/aws_access_key_id"
  printf 'aws-secret' > "$secrets/aws_secret_access_key"

  export NS_SECRETS_DIR="$secrets"
  run_entrypoint_ns bash -c 'printf "GCP=[%s]\nAWSID=[%s]\nAWSSEC=[%s]\n" "${GOOGLE_APPLICATION_CREDENTIALS:-}" "${AWS_ACCESS_KEY_ID:-}" "${AWS_SECRET_ACCESS_KEY:-}"'

  assert_status 0
  assert_output_contains "GCP=[]"
  assert_output_contains "AWSID=[]"
  assert_output_contains "AWSSEC=[]"
}

@test "dev-entrypoint: proceeds normally when /run/secrets is absent" {
  export NS_NO_SECRETS=1
  run_entrypoint_ns bash -c 'echo no-secrets-ok'

  assert_status 0
  assert_output_contains "no-secrets-ok"
}

@test "dev-entrypoint: starts Xvfb with hardened flags and exports DISPLAY when available" {
  run_entrypoint_xvfb_ns bash -c 'sleep 0.2; printf "DISPLAY=[%s]\nXVFB_LOG=[%s]\n" "$DISPLAY" "$(cat /tmp/fake-xvfb.log 2>/dev/null)"'

  assert_status 0
  assert_output_contains "DISPLAY=[:99.0]"
  # hardened flags (M9): -ac disables access control for headless automation,
  # -noreset keeps the display alive across client disconnect/restarts
  assert_output_contains "XVFB_LOG=[:99 -screen 0 1024x768x24 -ac -noreset]"
}

@test "dev-entrypoint: clears a stale X99 lock and starts Xvfb anyway" {
  export NS_XVFB_LOCK=1

  run_entrypoint_xvfb_ns bash -c 'sleep 0.2; printf "DISPLAY=[%s]\nXVFB_LOG=[%s]\n" "$DISPLAY" "$(cat /tmp/fake-xvfb.log 2>/dev/null)"'

  assert_status 0
  # the lock check was removed: the entrypoint rm -f's a stale lock (crashed
  # container) unconditionally, so Xvfb must still start with the lock present
  assert_output_contains "DISPLAY=[:99.0]"
  assert_output_contains "XVFB_LOG=[:99 -screen 0 1024x768x24 -ac -noreset]"
}

@test "dev-entrypoint: does not start Xvfb when Xvfb is not installed" {
  if command -v Xvfb >/dev/null 2>&1; then
    skip "real Xvfb on PATH; cannot verify the not-installed branch"
  fi

  run_entrypoint_ns bash -c 'printf "DISPLAY=[%s]\n" "$DISPLAY"'

  assert_status 0
  assert_output_contains "DISPLAY=[]"
}

@test "dev-entrypoint: exec replaces the process and forwards the exit status" {
  run_entrypoint_ns bash -c 'echo hi-from-child; exit 7'

  assert_status 7
  assert_output_contains "hi-from-child"
}

@test "dev-entrypoint: succeeds when no command is passed" {
  run_entrypoint_ns

  assert_status 0
}

# --- dev-secrets-profile.sh (H5: interactive-shell secrets passthrough) -------
# Installed in the image as /etc/profile.d/secrets.sh. `docker compose exec`
# spawns a fresh shell that does NOT inherit the vars exported by
# dev-entrypoint.sh, so tools launched that way would run with 0 credentials.
# This hook re-loads the whitelisted secret files for interactive shells. It
# must mirror dev-entrypoint.sh's ALLOWED_SECRETS whitelist exactly.

@test "dev-secrets-profile.sh: loads whitelisted secrets into a fresh shell" {
  require_unshare
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  printf 'sk-123' > "$secrets/anthropic_api_key"
  printf 'aws-key' > "$secrets/aws_access_key_id"

  local ns="$BATS_TEST_TMPDIR/ns-profile.sh"
  cat > "$ns" <<'NS'
#!/usr/bin/env bash
set -euo pipefail
mount -t tmpfs tmpfs /run
mkdir -p /run/secrets
cp -a "$NS_SECRETS_DIR/." /run/secrets/
source "$REPO_ROOT/scripts/dev-secrets-profile.sh"
exec "$@"
NS
  chmod +x "$ns"

  run unshare -r -m env NS_SECRETS_DIR="$secrets" REPO_ROOT="$REPO_ROOT" \
    bash "$ns" bash -c 'printf "AK=[%s]\nAWS=[%s]\n" "$ANTHROPIC_API_KEY" "${AWS_ACCESS_KEY_ID:-}"'

  assert_status 0
  assert_output_contains "AK=[sk-123]"
  # aws_access_key_id was removed from the whitelist (M2) -> never exported
  assert_output_contains "AWS=[]"
}

@test "dev-entrypoint: skips zero-byte secret files and wires non-empty ones" {
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  # zero-byte placeholder = the documented "not configured" init state
  # (secrets/README.md) — must be SKIPPED, not exported as empty
  : > "$secrets/anthropic_api_key"
  # non-empty secret must still wire exactly as before (regression guard)
  printf 'sk-real' > "$secrets/openai_api_key"

  export NS_SECRETS_DIR="$secrets"
  run_entrypoint_ns bash -c 'printf "AK=[%s]\nOA=[%s]\n" "${ANTHROPIC_API_KEY:-}" "$OPENAI_API_KEY"'

  assert_status 0
  # zero-byte placeholder: env var stays UNSET (not wired, not empty)
  assert_output_contains "AK=[]"
  # non-empty secret wiring is unchanged
  assert_output_contains "OA=[sk-real]"
  # skip marker is logged to stderr, grep-able
  assert_output_contains "[dev-entrypoint] [skip] secret 'anthropic_api_key': file empty or zero-byte, not wiring"
}

@test "dev-secrets-profile.sh: skips zero-byte secret files (parity with entrypoint)" {
  require_unshare
  local secrets="$BATS_TEST_TMPDIR/secrets"
  mkdir -p "$secrets"
  : > "$secrets/anthropic_api_key"
  printf 'sk-real' > "$secrets/exa_api_key"

  local ns="$BATS_TEST_TMPDIR/ns-profile-empty.sh"
  cat > "$ns" <<'NS'
#!/usr/bin/env bash
set -euo pipefail
mount -t tmpfs tmpfs /run
mkdir -p /run/secrets
cp -a "$NS_SECRETS_DIR/." /run/secrets/
source "$REPO_ROOT/scripts/dev-secrets-profile.sh"
exec "$@"
NS
  chmod +x "$ns"

  run unshare -r -m env NS_SECRETS_DIR="$secrets" REPO_ROOT="$REPO_ROOT" \
    bash "$ns" bash -c 'printf "AK=[%s]\nEXA=[%s]\n" "${ANTHROPIC_API_KEY:-}" "$EXA_API_KEY"'

  assert_status 0
  # zero-byte placeholder: env var stays UNSET
  assert_output_contains "AK=[]"
  # non-empty secret wiring is unchanged (parity regression guard)
  assert_output_contains "EXA=[sk-real]"
  # skip marker uses the profile-script prefix so loaders are distinguishable
  assert_output_contains "[dev-secrets-profile] [skip] secret 'anthropic_api_key': file empty or zero-byte, not wiring"
}
