#!/usr/bin/env bats
# check-stack-ready.bats -- tests for the stack-readiness probe.
# Frozen contract: exit 0 => STACK_READY; exit !=0 => STACK_NOT_READY.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../check-stack-ready.sh"
}

@test "check-stack-ready: missing DATABASE_URL and CHECK_TARGET yields STACK_NOT_READY" {
  run env -u DATABASE_URL -u CHECK_TARGET "$SCRIPT"
  [ "$status" -ne 0 ]
  # stdout is exactly STACK_READY or STACK_NOT_READY; stderr diagnostics
  # are captured separately by bats run.
  [[ "$output" == *"STACK_NOT_READY"* ]]
}

@test "check-stack-ready: CHECK_TARGET pointing to a dead host yields STACK_NOT_READY" {
  run env CHECK_TARGET="192.0.2.1:1" "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"STACK_NOT_READY"* ]]
}

@test "check-stack-ready: positive path -- listener emits postgres auth-request byte (R)" {
  # Start a python TCP listener on a random port that responds with a valid
  # postgres authentication-request message (first byte R = 0x52).
  python3 -c "
import socket, struct, threading, sys

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', 0))
srv.listen(1)
port = srv.getsockname()[1]
with open('/tmp/csr_test_port', 'w') as f:
    f.write(str(port))

def handle(conn):
    try:
        conn.recv(1024)
        # Auth-request: length=12, type='R', auth-ok(0)
        msg = struct.pack('!II', 12, 82) + struct.pack('!I', 0)
        conn.send(msg)
    except:
        pass
    finally:
        conn.close()

t = threading.Thread(target=lambda: handle(srv.accept()[0]))
t.daemon = True
t.start()
srv.close()
t.join(timeout=5)
" &
  # Wait for the listener to start
  for i in $(seq 1 20); do
    [ -f /tmp/csr_test_port ] && break
    sleep 0.1
  done
  local port
  port=$(cat /tmp/csr_test_port 2>/dev/null || echo "")
  rm -f /tmp/csr_test_port
  [ -n "$port" ]

  run env CHECK_TARGET="127.0.0.1:$port" "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STACK_READY"* ]]

  # Clean up background python
  wait 2>/dev/null || true
}

@test "check-stack-ready: negative path -- listener emits non-postgres byte" {
  # Start a TCP listener that responds with byte 0x42 ('B', not in R/E/S/N).
  python3 -c "
import socket, struct, threading, sys

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', 0))
srv.listen(1)
port = srv.getsockname()[1]
with open('/tmp/csr_test_port_neg', 'w') as f:
    f.write(str(port))

def handle(conn):
    try:
        conn.recv(1024)
        # Send 4 bytes: first byte 0x42 ('B', not in R/E/S/N)
        conn.send(b'\\x42\\x00\\x00\\x00')
    except:
        pass
    finally:
        conn.close()

t = threading.Thread(target=lambda: handle(srv.accept()[0]))
t.daemon = True
t.start()
srv.close()
t.join(timeout=5)
" &
  for i in $(seq 1 20); do
    [ -f /tmp/csr_test_port_neg ] && break
    sleep 0.1
  done
  local port
  port=$(cat /tmp/csr_test_port_neg 2>/dev/null || echo "")
  rm -f /tmp/csr_test_port_neg
  [ -n "$port" ]

  run env CHECK_TARGET="127.0.0.1:$port" "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"STACK_NOT_READY"* ]]

  wait 2>/dev/null || true
}

@test "check-stack-ready: script does not interpolate DB_HOST/DB_PORT into python source" {
  # Verify the python code uses sys.argv, not shell interpolation, for host/port.
  grep -q 'sys.argv\[1\]' "$SCRIPT"
  grep -q 'sys.argv\[2\]' "$SCRIPT"
}
