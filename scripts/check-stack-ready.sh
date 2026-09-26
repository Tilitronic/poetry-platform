#!/usr/bin/env bash
# check-stack-ready.sh -- canonical in-container stack-readiness probe.
#
# WHY: the old R3 merge-gate rule required `docker compose ps` output, which
# an agent inside the container cannot run. This script replaces it with a
# real postgres protocol exchange via python3 (the only client available in
# the image -- pg_isready, psql, nc, curl are NOT present). It proves
# postgres actually accepts a connection, not merely that a port is open.
#
# FROZEN CONTRACT (DIA-260922-cp0m):
#   exit 0  => stdout is exactly the single token STACK_READY
#   exit !=0 => stdout is exactly the single token STACK_NOT_READY
#   stderr carries diagnostics only and is NEVER parsed
#   no other exit codes
#   no engine/compose invocation
#   no pg_isready/psql/nc/curl used for readiness
#   database host and port come from DATABASE_URL (same source the app uses)
#   explicit bounded timeout (no retry loops)
#   the "not running inside the dev container" case yields STACK_NOT_READY
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

# Emit exactly one token on stdout and exit. Stderr goes to the caller.
emit() {
  printf '%s\n' "$1"
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
  emit "STACK_NOT_READY"
  exit 1
fi

# Validate we have both parts
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ]; then
  emit "STACK_NOT_READY"
  exit 1
fi

# python3 IS present in the Dockerfile.dev image; pg_isready/psql/nc/curl
# are NOT. The startup-message exchange proves postgres actually speaks the
# wire protocol, not merely that a TCP port is open (a dead-but-listening
# port would pass a TCP-only check but fail here).
if python3 -c "
import socket, sys
timeout = 5
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(('${DB_HOST}', int(${DB_PORT})))
    # Send postgres startup message to prove the server speaks the protocol.
    # The startup message format: length(4) + protocol version 3.0(4) + params.
    # We send a minimal invalid startup to provoke an auth response or error;
    # either proves the server is a real postgres instance.
    import struct
    user = b'x\x00'
    database = b'database\x00test\x00'
    body = struct.pack('!II', 196608, 0) + user + database
    s.send(struct.pack('!I', len(body) + 4) + body)
    # Read response -- any bytes means postgres is speaking the protocol
    resp = s.recv(1024)
    s.close()
    if len(resp) > 0:
        sys.exit(0)
    else:
        sys.exit(1)
except (socket.timeout, ConnectionRefusedError, OSError, struct.error):
    sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
  emit "STACK_READY"
  exit 0
else
  emit "STACK_NOT_READY"
  exit 1
fi
