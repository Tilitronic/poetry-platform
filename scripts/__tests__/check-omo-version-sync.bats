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

# ---- Task 1.3 (S1.1): per-service OMO sources (V1 root + V2 worktree) -------
# Campaign DIA-261119-vioa. Design D2 INVARIANT: the gate resolves PER-SERVICE
# sources (V1: root config/tui/Dockerfile; V2: the v2 worktree's config/tui and
# its build source) instead of one global set, because V1 stays on 2.2.19 while
# the V2 side moves to 3.0.7 together - a single cross-service equality is
# forbidden, and a gate that resolves only the V1 root (never the worktree)
# cannot fail on V2 drift. Fixture: V1 stays aligned (setup), V2-side config
# and tui.json drift against each other, so the run must exit non-zero and
# name the V2 side.
@test "OMO sync resolves per-service sources: V2 worktree pin drift fails while V1 stays aligned (task 1.3)" {
  local v2opencode="$OMO_SYNC_ROOT/.worktrees/opencode-v2/.opencode"
  mkdir -p "$v2opencode/oh-my-opencode-slim/knowledge"
  printf '%s\n' '{' '  "plugin": [' '    "oh-my-opencode-slim@3.0.7",' '  ]' '}' > "$v2opencode/opencode.jsonc"
  printf '%s\n' '{"plugin":["oh-my-opencode-slim@3.0.6"]}' > "$v2opencode/tui.json"
  # V2 build source + full override/knowledge layer, so a stricter
  # per-service gate sees every V2 file present: drift, not missing-source,
  # is the reported failure class.
  printf '%s\n' 'ARG OMO_VERSION=3.0.7' > "$OMO_SYNC_ROOT/.worktrees/opencode-v2/Dockerfile.dev"
  local name
  for name in analyzer_append.md coder.md coder_append.md orchestrator_append.md reviewer.md; do
    printf 'prompt\n' > "$v2opencode/oh-my-opencode-slim/$name"
  done
  printf 'sources\n' > "$v2opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml"
  printf 'best\n' > "$v2opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md"

  run bash "$REPO_ROOT/scripts/check-omo-version-sync.sh"

  [ "$status" -ne 0 ] || {
    echo "RED task 1.3: gate ignored the V2 worktree sources (V1 aligned at 2.2.19, V2 config 3.0.7 vs tui 3.0.6) and exited 0" >&2
    return 1
  }
  # The failure must name the V2 side (drifted value or worktree/dev-v2 path):
  # a V1-only global-set failure cannot carry any of these.
  [[ "$output" == *3.0.6* || "$output" == *[Ww]orktree* || "$output" == *dev-v2* ]] || {
    echo "failure does not name the V2 source (expected 3.0.6 / worktree / dev-v2):" >&2
    echo "$output" >&2
    return 1
  }
}
