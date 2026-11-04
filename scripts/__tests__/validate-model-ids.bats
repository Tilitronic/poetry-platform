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
# real project config is never touched (every invalid case is a FIXTURE, not
# an injection into the real config). A fake `opencode` on PATH serves a
# canned 4-model catalog so the pass/fail cases do not depend on the live
# CLI; the skip case runs with a PATH on which opencode cannot resolve at
# all. Negative cases (dead fallback at index >= 1, dead scalar, missing
# prefix, missing source file, comment stripping, typo'd vs allowlisted
# provider) pin each failure class from the DIA-261022-6vcz audit.

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

# write_fixture <name> <id> [id2]: minimal fixture tree whose preset array
# element 0 is <id> (the ID under test); element 1 defaults to a valid
# canned-catalog ID and may be overridden via the optional third arg (dead
# fallback at index >= 1). The council seat and the opencode.jsonc agent
# entry are always valid canned-catalog IDs, so a pass means the non-target
# slots validated too, and a fail isolates exactly the target slot.
write_fixture() {
  local name="$1" id="$2" id2="${3:-opencode-go/mimo-v2.6-flash}"
  local tree="$BATS_TEST_TMPDIR/$name"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "presets": {
    "fixture": {
      "architector": {
        "model": [
          "$id",
          "$id2"
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

# --- Negative cases pinning the failure classes (DIA-261022-6vcz audit) -------
# The historical incident was SEVEN dead fallback slots; element-0-only
# coverage let dead IDs at index >= 1 slip through. Each case below uses the
# same hermetic fixture style (fake opencode + MODEL_IDS_ROOT tree) - the
# real project config is never touched.

@test "validate-model-ids: dead fallback ID at array index 1 exits 1" {
  install_fake_opencode
  # opencode-go/deepseek-v4-flash is the historical dead ID, absent from the
  # canned catalog but on a KNOWN provider (dead-ID path, not typo path).
  local tree
  tree="$(write_fixture deadfallback opencode-go/gemini-4-argon opencode-go/deepseek-v4-flash)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "opencode-go/deepseek-v4-flash"
  assert_output_contains "3 passed, 1 failed"
}

@test "validate-model-ids: dead single-line scalar model entry exits 1" {
  install_fake_opencode
  local tree="$BATS_TEST_TMPDIR/deadscalar"
  mkdir -p "$tree/.opencode"
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "council": {
    "presets": {
      "default": {
        "deepseek": { "model": "opencode-go/gemini-4-argon-contributor" }
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

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "opencode-go/gemini-4-argon-contributor"
  assert_output_contains "1 passed, 1 failed"
}

@test "validate-model-ids: model ID with no provider prefix fails" {
  install_fake_opencode
  local tree
  tree="$(write_fixture noprefix mimo-v2.6-flash)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "has no provider prefix"
  assert_output_contains "'mimo-v2.6-flash'"
  assert_output_contains "3 passed, 1 failed"
}

@test "validate-model-ids: missing watched config file exits 2" {
  install_fake_opencode
  local tree="$BATS_TEST_TMPDIR/missingcfg"
  mkdir -p "$tree/.opencode"
  # slim present; opencode.jsonc deliberately absent.
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "council": {
    "presets": {
      "default": {
        "deepseek": { "model": "opencode-go/deepseek-v4.1-flash" }
      }
    }
  }
}
JSONC

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 2
  assert_output_contains "missing source"
  assert_output_contains "opencode.jsonc"
}

@test "validate-model-ids: inline // and /* */ comments neither hide a dead ID nor leak quoted strings" {
  install_fake_opencode
  local tree="$BATS_TEST_TMPDIR/commented"
  mkdir -p "$tree/.opencode"
  # A dead ID with a trailing inline // comment must still be checked; the
  # quoted IDs inside the comment and inside the block comment must NOT be
  # extracted (they are absent from the canned catalog, so any leak would
  # add a second FAIL and break the exact-count assertions below).
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "presets": {
    "fixture": {
      "architector": {
        "model": [
          "opencode-go/gemini-4-argon",
          "opencode-go/deepseek-v4-flash", // "opencode-go/not-a-real-model" inline comment
          /* "opencode-go/block-comment-dead" block comment */
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

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "opencode-go/deepseek-v4-flash"
  # Exactly one failure: the comment-quoted IDs contributed nothing.
  assert_output_contains "4 passed, 1 failed"
  assert_output_not_contains "not-a-real-model"
  assert_output_not_contains "block-comment-dead"
}

@test "validate-model-ids: typo'd provider prefix FAILS (not the old warn path)" {
  install_fake_opencode
  # opencode-goo is a typo of opencode-go: provider absent AND not allowlisted
  # -> hard failure (the pre-audit behavior was warn + exit 0).
  local tree
  tree="$(write_fixture typo opencode-goo/gemini-4-argon)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "'opencode-goo/gemini-4-argon'"
  assert_output_contains "opencode-goo"
  assert_output_not_contains "unverifiable"
  assert_output_contains "3 passed, 1 failed"
}

@test "validate-model-ids: allowlisted github-copilot seat stays WARN + exit 0" {
  install_fake_opencode
  local tree
  tree="$(write_fixture copilot github-copilot/gpt-5.3-codex)"

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "warn:"
  assert_output_contains "github-copilot"
  assert_output_not_contains "FAIL:"
  assert_output_contains "3 passed, 0 failed"
}

@test "validate-model-ids: multi-line block comment keeps the original file:line" {
  install_fake_opencode
  local tree="$BATS_TEST_TMPDIR/multiline-block"
  mkdir -p "$tree/.opencode"
  # The /* */ block spans lines 6-8 and a real dead ID sits on line 10, AFTER
  # the comment closes. The stripper re-emits the newlines inside a removed
  # block comment, so the FAIL must report :10:; a stripper that dropped them
  # would shift the ID up to :8: (and the quoted ID inside the comment must
  # never be extracted, so it must not appear in the output at all).
  cat > "$tree/.opencode/oh-my-opencode-slim.jsonc" <<JSONC
{
  "presets": {
    "fixture": {
      "architector": {
        "model": [
          /* multi-line block comment line 1
             line 2 of the block comment
             "opencode-go/comment-only-dead" */
          "opencode-go/gemini-4-argon",
          "opencode-go/gemini-4-argon-contributor"
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

  MODEL_IDS_ROOT="$tree" run bash "$VALIDATOR"

  assert_status 1
  # Original (un-shifted) line number of the dead ID, not 10 - 2.
  assert_output_contains "oh-my-opencode-slim.jsonc:10:"
  assert_output_not_contains "oh-my-opencode-slim.jsonc:8:"
  assert_output_contains "opencode-go/gemini-4-argon-contributor"
  assert_output_not_contains "comment-only-dead"
  assert_output_contains "3 passed, 1 failed"
}
