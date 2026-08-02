#!/usr/bin/env bash
# Interactive-shell secrets passthrough (H5).
#
# Installed in the dev image as /etc/profile.d/secrets.sh (see Dockerfile.dev)
# and sourced by interactive bash login shells inside the container.
#
# WHY this exists: `docker compose exec` spawns a fresh process that does NOT
# inherit the env vars exported by dev-entrypoint.sh (docker exec uses the
# container's configured env, not PID 1's runtime env), so tools launched via
# `make opencode` / `docker compose exec dev <cmd>` would run with 0
# credentials. This hook re-loads the whitelisted secret files from /run/secrets
# into interactive shells.
#
# The whitelist MUST mirror dev-entrypoint.sh ALLOWED_SECRETS — keep the two in
# sync (M2: only the 5 names compose actually mounts).
if [ -d /run/secrets ]; then
  for secret in /run/secrets/*; do
    [ -f "$secret" ] || continue
    name=$(basename "$secret")
    case "$name" in
      anthropic_api_key|openai_api_key|context7_api_key|github_token|exa_api_key)
        var_name=$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        export "${var_name}=$(cat "$secret")"
        ;;
    esac
  done
fi
