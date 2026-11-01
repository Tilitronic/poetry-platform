#!/usr/bin/env bats
# Meta-tests for scripts/validate-model-ids.sh (DIA-261022-6vcz). The script
# cross-references every dispatch-actuating model ID (preset `model` arrays
# - ALL elements, fallbacks dispatch too; `agents` block; `council` seats in
# .opencode/oh-my-opencode-slim.jsonc; agent-block `model` keys in
# .opencode/opencode.jsonc) against the live `opencode models` catalog.
# knowledge/model-registry.yaml model_id entries are documentation-only WARN.
#
# Exit contract under test:
#   0  all dispatch IDs valid, OR catalog unavailable -> clean SKIP
#   1  invalid dispatch-actuating ID (file:line + bad ID + nearest match)
#   2  missing config source
#
# Isolation: each test builds a hermetic fixture tree under $BATS_TEST_TMPDIR
# and points the validator at it via the MODEL_IDS_ROOT env override - the
# real project config is never touched (the invalid case is a FIXTURE, not an
# injection into the real config). A fake `opencode` on PATH serves a canned
# 4-model catalog so cases (a)/(b) do not depend on the live CLI; case (c)
# runs with a PATH on which opencode cannot resolve at all.

load test-helper

VALIDATOR="$REPO_ROOT/scripts/validate-model-ids.sh"

# install_fake_opencode: plants a fake `opencode` whose `models` subcommand
# prints a small canned catalog (the IDs the fixtures below use), and
# prepends the fake dir to PATH for the calling test.
install_fake_opencode() {
  local dir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$dir"
  cat > "$dir/opencode" <<'FAKE'
#!/usr/bin/env bash
# fake opencode CLI: canned catalog for validate-model-ids tests only.
[ "${1:-}" = "models" ] || exit 1
cat <<'CATALOG'
opencode-go/deepseek-v4.1-flash
opencode-go/gemini-4-argon
opencode-go/mimo-v2.6-flash
openai/gpt-5.6-terra
CATALOG
FAKE
  chmod +x "$dir/opencode"
  PATH="$dir:$PATH"
  export PATH
}

# write_fixture <name> <primary-id>: minimal fixture tree whose preset array
# element 0 is <primary-id> (the ID under test). Element 1, the council seat,
# and the opencode.jsonc agent entry are always valid canned-catalog IDs, so
# a pass means element 0 validated too, and a fail isolates exactly element 0.
write_fixture() {
  local name="$1" id="$2"
  local tree="$BATS_TEST_TMPDIR/$name"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "presets": {
    "fixture": {
      "architector": {
        "model": [
          "$id",
          "opencode-go/mimo-v2.6-flash"
        ]
      }
    }
  },
  "council": {
    "presets": {
      "default": {
        "deepseek": { "model": "opencode-go/deepseek-v4.1-flash" }
      }
    }
  }
}
JSONC
  cat > "$tree/.opencode/opencode.jsonc" <<JSONC
{
  "agent": { "coder": { "model": "opencode-go/deepseek-v4.1-flash" } }
}
JSONC
  echo "$tree"
}

@test "validate-model-ids: valid config passes (exit 0)" {
  install_fake_opencode
  local tree
  tree="$(write_fixture valid opencode-go/gemini-4-argon)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "4 passed, 0 failed"
  assert_output_not_contains "FAIL:"
  # Proves the catalog was live and validation ran (not silently skipped).
  assert_output_not_contains "SKIPPED"
}

@test "validate-model-ids: invalid ID exits 1 and names the ID (fixture)" {
  install_fake_opencode
  # Fixture-only bad ID - the real config is never modified.
  local tree
  tree="$(write_fixture invalid opencode-go/gemini-4-argon-contributor)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "opencode-go/gemini-4-argon-contributor"
  # Nearest valid catalog match is the standard-tier ID (shared prefix).
  assert_output_contains "nearest: opencode-go/gemini-4-argon"
  assert_output_contains "3 passed, 1 failed"
}

@test "validate-model-ids: missing opencode models skips with exit 0" {
  # Fixture deliberately holds a BAD id: the skip must short-circuit before
  # any validation, proving an unavailable catalog never hard-fails (the
  # cold-checkout contract), not even on a config that would otherwise fail.
  local tree
  tree="$(write_fixture skip opencode-go/gemini-4-argon-contributor)"
  # PATH without the real opencode (/usr/local/bin) -> `command -v opencode`
  # fails -> clean SKIP. bash/awk/grep resolve under /usr/bin:/bin.
  MODEL_IDS_ROOT="$tree" PATH="/usr/bin:/bin" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "SKIPPED: opencode models unavailable"
}
