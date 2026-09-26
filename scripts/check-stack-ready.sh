#!/usr/bin/env bash
# check-stack-ready.sh -- canonical in-container stack-readiness probe.
#
# WHY: the old R3 merge-gate rule required `docker compose ps` output, which
# an agent inside the container cannot run. This script replaces it with a
# postgres wire-protocol exchange via python3 (the only client available in
# the image -- pg_isready, psql, nc, curl are NOT present).
#
# WHAT IS PROVEN: the target speaks the postgres wire protocol (the first
# response byte is R auth-request, E error, S parameter-status, or N notice).
# This rules out SSH banners, SMTP greetings, or any other byte-emitting
# listener that would pass a len(resp) > 0 check. It does NOT prove
# authentication will succeed or that the target database exists.
#
# FROZEN CONTRACT (DIA-260922-cp0m):
#   exit 0  => stdout is exactly the single token STACK_READY
#   exit !=0 => stdout is exactly the single token STACK_NOT_READY
#   stderr carries one diagnostic line (failure class) and is NEVER parsed
#   no other exit codes
#   no engine/compose invocation
#   no pg_isready/psql/nc/curl used for readiness
#   database host and port come from DATABASE_URL (same source the app uses)
#   explicit bounded timeout (no retry loops)
#   the "not running inside the dev container" case yields STACK_NOT_READY
#   sources scripts/in-container.sh for hostname-based detection
#
# Usage:
#   scripts/check-stack-ready.sh              # normal: reads DATABASE_URL
#   CHECK_TARGET=host:port bash script.sh     # override for testing
#
# Env:
#   CHECK_TARGET   override connection target (host:port); when set,
#                  DATABASE_URL is ignored. Used by bats tests to exercise
#                  the negative path without stopping postgres.
set -euo pipefail

# In-container detection: this script MUST run inside the dev container.
# When invoked outside (e.g. on the host), emit STACK_NOT_READY immediately.
# Sourced, not executed -- provides is_in_dev_container().
source "$(dirname "${BASH_SOURCE[0]}")/in-container.sh"
if ! is_in_dev_container; then
  diag "not running inside the dev container (hostname != poetry-dev)"
  emit "STACK_NOT_READY"
  exit 1
fi

# Emit exactly one token on stdout and exit. Stderr goes to the caller.
emit() {
  printf '%s\n' "$1"
}

# Diagnostic on stderr -- one line per failure class, never parsed.
diag() {
  printf 'check-stack-ready: %s\n' "$1" >&2
}

# Parse DATABASE_URL to extract host and port.
# Format: postgresql://user:pass@host:port/dbname
parse_db_url() {
  local url="$1"
  # Strip the scheme
  local without_scheme="${url#postgresql://}"
  without_scheme="${without_scheme#postgres://}"
  # Extract host:port (everything after @, before /)
  local host_port="${without_scheme#*@}"
  host_port="${host_port%%/*}"
  DB_HOST="${host_port%%:*}"
  DB_PORT="${host_port##*:}"
}

# Determine the connection target
if [ -n "${CHECK_TARGET:-}" ]; then
  DB_HOST="${CHECK_TARGET%%:*}"
  DB_PORT="${CHECK_TARGET##*:}"
elif [ -n "${DATABASE_URL:-}" ]; then
  parse_db_url "$DATABASE_URL"
else
  diag "no target: neither CHECK_TARGET nor DATABASE_URL is set"
  emit "STACK_NOT_READY"
  exit 1
fi

# Validate we have both parts
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ]; then
  diag "URL parse failure: could not extract host and port from target"
  emit "STACK_NOT_READY"
  exit 1
fi

# python3 IS present in the Dockerfile.dev image; pg_isready/psql/nc/curl
# are NOT. We send a minimal postgres startup message to provoke an auth
# response or error, then validate the first response byte is one of
# R (auth-request), E (error), S (parameter-status), or N (notice) -- the
# four bytes a real postgres server emits. Anything else (SSH banner, SMTP
# greeting, random bytes) is rejected as NOT_READY.
#
# DB_HOST and DB_PORT are passed as argv to avoid shell injection through
# untrusted URL content.
if python3 -c "
import socket, sys, struct

host = sys.argv[1]
port = int(sys.argv[2])
timeout = 5

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect((host, port))
    # Minimal postgres startup: length + protocol version 3.0 + params.
    user = b'x\x00'
    database = b'database\x00test\x00'
    body = struct.pack('!II', 196608, 0) + user + database
    s.send(struct.pack('!I', len(body) + 4) + body)
    resp = s.recv(1024)
    s.close()
    if len(resp) == 0:
        print('connection failure: server closed connection without response', file=sys.stderr)
        sys.exit(1)
    # Validate first byte is a real postgres message type.
    first = chr(resp[0])
    if first not in ('R', 'E', 'S', 'N'):
        print(f'non-postgres response: first byte 0x{resp[0]:02x} ({first!r}), not R/E/S/N', file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
except socket.timeout:
    print(f'connection failure: timeout after {timeout}s connecting to {host}:{port}', file=sys.stderr)
    sys.exit(1)
except ConnectionRefusedError:
    print(f'connection failure: refused by {host}:{port}', file=sys.stderr)
    sys.exit(1)
except OSError as e:
    print(f'connection failure: {e}', file=sys.stderr)
    sys.exit(1)
except struct.error:
    print('connection failure: protocol framing error', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'connection failure: {e}', file=sys.stderr)
    sys.exit(1)
" -- "$DB_HOST" "$DB_PORT"; then
  emit "STACK_READY"
  exit 0
else
  emit "STACK_NOT_READY"
  exit 1
fi
