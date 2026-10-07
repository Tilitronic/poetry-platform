#!/usr/bin/env bats

load test-helper

setup() {
  export OMO_SYNC_ROOT="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$OMO_SYNC_ROOT/.opencode"
  printf '%s\n' '{' '  "plugin": [' '    "oh-my-opencode-slim@2.2.19",' '  ]' '}' > "$OMO_SYNC_ROOT/.opencode/opencode.jsonc"
  printf '%s\n' '{"plugin":["oh-my-opencode-slim@2.2.19"]}' > "$OMO_SYNC_ROOT/.opencode/tui.json"
  printf '%s\n' 'ARG OMO_VERSION=2.2.19' > "$OMO_SYNC_ROOT/Dockerfile.dev"
}

@test "OMO sync accepts aligned active pins" {
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 0
  assert_output_contains "aligned at 2.2.19"
}

@test "OMO sync rejects version drift" {
  sed -i 's/2.2.19/2.2.18/' "$OMO_SYNC_ROOT/.opencode/tui.json"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 1
  assert_output_contains "OMO version drift"
}

@test "OMO sync fails closed for a missing source" {
  rm "$OMO_SYNC_ROOT/Dockerfile.dev"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 2
  assert_output_contains "OMO pin source missing"
}

@test "OMO sync rejects duplicate TUI pins even on one line" {
  printf '%s\n' '{"plugin":["oh-my-opencode-slim@2.2.18","oh-my-opencode-slim@2.2.19"]}' > "$OMO_SYNC_ROOT/.opencode/tui.json"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 2
  assert_output_contains "tui.json must declare exactly one active OMO version pin"
}
