#!/usr/bin/env bash
# in-container.sh — shared in-container detection (S6, DIA-260922-cp0m).
#
# WHY: hostname "poetry-dev" (V1) and "poetry-dev-v2" (D1a V2 stack) were
# repeated as raw primitives in scripts (check-compose-config.sh,
# verify-pre-push.sh, verify-pre-commit.sh, check-stack-ready.sh). This
# helper provides one canonical definition: an explicit exact-match allowlist
# of the two accepted hostnames, never a prefix match (a prefix match would
# wrongly accept "poetry-dev-evil"). Any other hostname is rejected and the
# caller's existing not-in-container message applies unchanged.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/in-container.sh"

# Accepted in-container hostnames (exact match, space-separated).
DEV_CONTAINER_HOSTNAMES="poetry-dev poetry-dev-v2"

is_in_dev_container() {
  local host
  host="$(hostname 2>/dev/null || true)"
  [ -n "$host" ] || return 1
  # Pad both sides with spaces so the match is whole-token, not a prefix.
  case " $DEV_CONTAINER_HOSTNAMES " in
    *" $host "*) return 0 ;;
    *) return 1 ;;
  esac
}
