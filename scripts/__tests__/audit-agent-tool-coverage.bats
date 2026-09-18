#!/usr/bin/env bats
# Meta-tests for scripts/audit-agent-tool-coverage.sh (change
# dia-066-tool-coverage-audit). The script audits OpenCode agent x tool
# permission coverage and surfaces tools NOT explicitly covered by permission
# rules — in the OpenCode v1 permission model, unlisted tools fall through to
# permissive default-allow.
#
# Exit-code contract under test (design.md Decision 2):
#   0  run completed, no HARD (write-capable) gaps found (WARNs do not fail)
#   1  HARD (write-capable) gap found OR malformed JSONC (config defect)
#   2  INFRA error (no opencode / no python3 / no default model / v2 schema
#      detected / missing config file)
#
# Severity tiering (Decision 6 resolved ruling):
#   HARD  unlisted write-capable tool missing from EVERY agent's effective
#         coverage (global ∪ per-agent merge). Exit 1.
#   WARN  all other unlisted default-allow tools. Exit 0.
#
# Isolation: each test builds a hermetic fixture tree under $BATS_TEST_TMPDIR
# and stubs the runtime census via AUDIT_TOOL_CENSUS_FILE — no live `opencode`
# install is required. The real project config is never touched.

load test-helper

AUDIT_SCRIPT="$REPO_ROOT/scripts/audit-agent-tool-coverage.sh"

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# write_census <root> <tool...>: writes a hermetic census JSON with
# {"tools": {toolId: true, ...}} for each given tool.
write_census() {
  local root="$1"
  shift
  {
    echo '{'
    echo '  "tools": {'
    local first=1
    local tool
    for tool in "$@"; do
      if [ "$first" -eq 1 ]; then first=0; else echo ','; fi
      printf '    "%s": true' "$tool"
    done
    echo ''
    echo '  }'
    echo '}'
  } > "$root/census.json"
}

# run_audit <root> <config-name> [extra args...]: runs the auditor against a
# config in the fixture root with the hermetic census, capturing status+output.
run_audit() {
  local root="$1"
  local config="$2"
  shift 2
  AUDIT_TOOL_CENSUS_FILE="$root/census.json" run bash "$AUDIT_SCRIPT" "$root/$config" "$@"
}

# setup_tree <name>: creates a hermetic fixture root for one test.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$tree"
  echo "$tree"
}

# ---------------------------------------------------------------------------
# T1 — script skeleton + args + exit-code contract (tests 1–3)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: no config file exits 2 with 'config file not found'" {
  run bash "$AUDIT_SCRIPT" /nonexistent-config.jsonc

  assert_status 2
  assert_output_contains "config file not found"
}

@test "audit-tool-coverage: no python3 exits 2 with 'python3 is required'" {
  local tree bindir
  tree="$(setup_tree no-python3)"
  write_census "$tree" read write
  printf '{ "agent": {} }\n' > "$tree/config.jsonc"
  # Minimal PATH: a shim dir containing ONLY bash (no python3, no opencode).
  # The INFRA gate fires after the config-exists gate.
  bindir="$BATS_TEST_TMPDIR/no-python3-bin"
  mkdir -p "$bindir"
  ln -sf /bin/bash "$bindir/bash"
  PATH="$bindir" run bash "$AUDIT_SCRIPT" "$tree/config.jsonc"

  assert_status 2
  assert_output_contains "python3 is required"
}

@test "audit-tool-coverage: no opencode (no census file) exits 2 with 'opencode binary not found'" {
  local tree
  tree="$(setup_tree no-opencode)"
  printf '{ "agent": {} }\n' > "$tree/config.jsonc"
  # PATH with python3 but WITHOUT the opencode binary dir. AUDIT_TOOL_CENSUS_FILE
  # is NOT set, so the opencode INFRA gate must fire.
  PATH="/usr/bin:/bin" run bash "$AUDIT_SCRIPT" "$tree/config.jsonc"

  assert_status 2
  assert_output_contains "opencode binary not found"
}

@test "audit-tool-coverage: census file set skips the opencode requirement" {
  local tree
  tree="$(setup_tree census-skips-opencode)"
  write_census "$tree" read
  printf '{ "agent": {} }\n' > "$tree/config.jsonc"

  # PATH with no opencode binary at all; AUDIT_TOOL_CENSUS_FILE is set so the
  # INFRA gate is skipped and the audit runs to completion.
  run env PATH="/bin:/usr/bin" AUDIT_TOOL_CENSUS_FILE="$tree/census.json" bash "$AUDIT_SCRIPT" "$tree/config.jsonc"

  assert_status 0
  assert_output_contains "0 agents audited, 0 gaps, 0 warnings"
}

# ---------------------------------------------------------------------------
# T2 — static JSONC parse (tests 4–6)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: valid v1 config parses and lists agents (exit 0)" {
  local tree
  tree="$(setup_tree valid-v1)"
  write_census "$tree" read write edit
  cat > "$tree/config.jsonc" <<'JSONC'
{
  // fixture JSONC (comment allowed)
  "permission": {
    "edit": "allow"
  },
  "agent": {
    "alpha": {
      "permission": {
        "write": "deny",
        "edit": "deny"
      }
    },
    "beta": {
      "permission": {
        "write": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "ok: agent=alpha"
  assert_output_contains "ok: agent=beta"
  assert_output_contains "2 agents audited, 0 gaps"
}

@test "audit-tool-coverage: v2 schema (permissions array) exits 2" {
  local tree
  tree="$(setup_tree v2-schema)"
  write_census "$tree" read write
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "permissions": [
    { "tool": "write", "allow": true }
  ]
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 2
  assert_output_contains "v2 permission schema detected"
}

@test "audit-tool-coverage: blanket-form config WARNs and skips enumeration" {
  local tree
  tree="$(setup_tree blanket-form)"
  write_census "$tree" read write edit
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "agent": {
    "alpha": {
      "permission": "allow"
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "WARN:"
  assert_output_contains "blanket permission=allow"
  assert_output_contains "1 agents audited, 0 gaps, 1 warnings"
}

# ---------------------------------------------------------------------------
# T3 — runtime census (tests 7–8)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: AUDIT_TOOL_CENSUS_FILE loads the tool universe" {
  local tree
  tree="$(setup_tree census-file)"
  write_census "$tree" read write edit
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "agent": {
    "alpha": {
      "permission": {
        "write": "deny",
        "edit": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  # read is unlisted everywhere but is not write-capable -> WARN only
  assert_output_contains "tool=read"
  assert_output_contains "severity=WARN"
  assert_output_contains "1 agents audited, 0 gaps"
}

@test "audit-tool-coverage: opencode debug agent failure exits 2" {
  local tree
  tree="$(setup_tree debug-failure)"
  printf '{ "agent": { "alpha": {} } }\n' > "$tree/config.jsonc"
  # PATH has opencode? No — we force the runtime census path by NOT setting
  # AUDIT_TOOL_CENSUS_FILE and pointing opencode at a failing fake.
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/opencode" <<'FAKE'
#!/usr/bin/env bash
echo "no default model resolvable" >&2
exit 1
FAKE
  chmod +x "$bindir/opencode"

  PATH="$bindir:$PATH" run bash "$AUDIT_SCRIPT" "$tree/config.jsonc"

  assert_status 2
  assert_output_contains "opencode debug agent failed"
}

# ---------------------------------------------------------------------------
# T4 — cross-reference + gap detection (tests 9–11)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: no gaps -> exit 0 + ok lines + '0 gaps'" {
  local tree
  tree="$(setup_tree no-gaps)"
  write_census "$tree" read write edit
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "permission": {
    "edit": "allow"
  },
  "agent": {
    "alpha": {
      "permission": {
        "write": "deny",
        "edit": "deny",
        "read": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "ok: agent=alpha"
  assert_output_contains "0 gaps"
  assert_output_not_contains "FAIL:"
  assert_output_not_contains "WARN:"
}

@test "audit-tool-coverage: malformed census file exits 2 (crossref INFRA propagates)" {
  local tree
  tree="$(setup_tree malformed-census)"
  printf '{ this is : not json }\n' > "$tree/census.json"
  printf '{ "agent": { "alpha": {} } }\n' > "$tree/config.jsonc"

  run_audit "$tree" config.jsonc

  # Decision 2 contract: a non-empty malformed census is an INFRA error —
  # crossref.py exits 2 and the wrapper must propagate it verbatim (P1 review
  # fix), NOT collapse it onto the exit-1 config-defect path.
  assert_status 2
  assert_output_contains "cannot parse tool census"
}

@test "audit-tool-coverage: write-capable gap (write unlisted everywhere) exits 1 + FAIL severity=HARD" {
  local tree
  tree="$(setup_tree hard-gap)"
  write_census "$tree" read write edit
  # No global rules; alpha denies edit/bash but leaves `write` unlisted. write
  # is write-capable AND missing from every agent's effective coverage -> HARD.
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "agent": {
    "alpha": {
      "permission": {
        "edit": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "agent=alpha"
  assert_output_contains "tool=write"
  assert_output_contains "severity=HARD"
}

@test "audit-tool-coverage: effective coverage merge (tool covered globally is not a gap)" {
  local tree
  tree="$(setup_tree effective-merge)"
  write_census "$tree" read write edit
  # `write` is NOT in alpha's block but IS in the global block -> covered via
  # the global ∪ per-agent merge -> no gap at all.
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "permission": {
    "write": "deny"
  },
  "agent": {
    "alpha": {
      "permission": {
        "edit": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "ok: agent=alpha"
  assert_output_not_contains "tool=write"
  assert_output_not_contains "FAIL:"
}

@test "audit-tool-coverage: WARN-only gap (read unlisted) exits 0 + severity=WARN + warnings incremented" {
  local tree
  tree="$(setup_tree warn-only)"
  write_census "$tree" read write edit
  # read is unlisted and NOT write-capable -> WARN (exit 0), never FAIL.
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "agent": {
    "alpha": {
      "permission": {
        "write": "deny",
        "edit": "deny"
      }
    }
  }
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "WARN:"
  assert_output_contains "tool=read"
  assert_output_contains "severity=WARN"
  assert_output_contains "1 agents audited, 0 gaps, 1 warnings"
  assert_output_not_contains "FAIL:"
}

# ---------------------------------------------------------------------------
# T5 — blanket-form + v2 detection (tests 12–13)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: blanket-form config exit 0 + blanket WARN + '0 gaps, 1 warnings'" {
  local tree
  tree="$(setup_tree blanket-exit0)"
  write_census "$tree" read write edit
  # Global blanket form (docker profile shape): WARN only, no per-tool flood.
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "permission": "allow"
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 0
  assert_output_contains "WARN:"
  assert_output_contains "blanket permission=allow"
  assert_output_contains "0 agents audited, 0 gaps, 1 warnings"
}

@test "audit-tool-coverage: v2 schema config exits 2 with clear message" {
  local tree
  tree="$(setup_tree v2-exit2)"
  write_census "$tree" read write
  cat > "$tree/config.jsonc" <<'JSONC'
{
  "permissions": []
}
JSONC

  run_audit "$tree" config.jsonc

  assert_status 2
  assert_output_contains "v2 permission schema detected"
  assert_output_contains "last-match-wins"
}

# ---------------------------------------------------------------------------
# T6 — Makefile wiring + integration (test 14)
# ---------------------------------------------------------------------------

@test "audit-tool-coverage: real configs audited via make test-config exit 0" {
  # The Makefile wires the auditor into test-config for BOTH
  # .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json.
  # Hermeticity: the census mirrors the REAL runtime tool universe. Note the
  # real config comment: "edit is path-scoped ... (covers write+apply_patch per
  # OpenCode docs — flat `write` key removed)" — so the runtime census has NO
  # separate `write` tool; write-capable coverage is via edit/bash/webfetch/
  # task/envsitter_* which the fleet covers globally + per-agent. Including a
  # phantom `write` tool here would fabricate HARD gaps the runtime cannot have.
  local tree
  tree="$(setup_tree make-integration)"
  write_census "$tree" \
    read glob grep edit ast_grep_replace bash webfetch task \
    envsitter_set envsitter_delete envsitter_format envsitter_reorder \
    envsitter_unset envsitter_add envsitter_copy list lsp skill

  # Run only the audit recipe lines the Makefile adds (invoked for both config
  # profiles), not the full test-config target (which needs node+opencode and
  # is covered by the project's own CI). This asserts the wiring contract:
  # both configs audit clean with zero HARD write-capable gaps.
  AUDIT_TOOL_CENSUS_FILE="$tree/census.json" run bash "$AUDIT_SCRIPT" "$REPO_ROOT/.opencode/opencode.jsonc"
  assert_status 0
  assert_output_contains "agents audited, 0 gaps"

  AUDIT_TOOL_CENSUS_FILE="$tree/census.json" run bash "$AUDIT_SCRIPT" "$REPO_ROOT/tools/opencode-docker/config/opencode.json"
  assert_status 0
  # docker profile is blanket-form -> WARN exposure mode, still exit 0
  assert_output_contains "blanket permission=allow"
}
