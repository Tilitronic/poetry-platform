#!/usr/bin/env bats

load test-helper

setup() {
  export OMO_SYNC_ROOT="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$OMO_SYNC_ROOT/.opencode"
  printf '%s\n' '{' '  "plugin": [' '    "oh-my-opencode-slim@2.2.19",' '  ]' '}' > "$OMO_SYNC_ROOT/.opencode/opencode.jsonc"
  printf '%s\n' '{"plugin":["oh-my-opencode-slim@2.2.19"]}' > "$OMO_SYNC_ROOT/.opencode/tui.json"
  printf '%s\n' 'ARG OMO_VERSION=2.2.19' > "$OMO_SYNC_ROOT/Dockerfile.dev"
  # Seed the full prompt-override layer so every test starts from the
  # all-present state the script now requires (DIA-261022-5n2v).
  local omo="$OMO_SYNC_ROOT/.opencode/oh-my-opencode-slim"
  mkdir -p "$omo/knowledge"
  local name
  for name in analyzer_append.md coder.md coder_append.md orchestrator_append.md reviewer.md; do
    printf 'prompt\n' > "$omo/$name"
  done
  printf 'sources\n' > "$omo/knowledge/ai-assist-sources.yaml"
  printf 'best\n' > "$omo/knowledge/opencode-best-practices.md"
}

@test "OMO sync accepts aligned pins with all override files present" {
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

@test "OMO sync rejects a missing prompt override file" {
  rm "$OMO_SYNC_ROOT/.opencode/oh-my-opencode-slim/coder.md"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 2
  assert_output_contains "prompt override missing or empty"
  assert_output_contains "coder.md"
}

@test "OMO sync rejects an extra root override markdown file" {
  printf 'stray\n' > "$OMO_SYNC_ROOT/.opencode/oh-my-opencode-slim/orchestrator-append.md"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 2
  assert_output_contains "unexpected OMO prompt override file"
  assert_output_contains "orchestrator-append.md"
}

@test "OMO sync rejects a missing knowledge file" {
  rm "$OMO_SYNC_ROOT/.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml"
  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"
  assert_status 2
  assert_output_contains "knowledge file missing or empty"
  assert_output_contains "ai-assist-sources.yaml"
}
