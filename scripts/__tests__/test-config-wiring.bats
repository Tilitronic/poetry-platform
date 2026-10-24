#!/usr/bin/env bats
# Wiring regression for the `make test-config` target (change
# dev-infra-config-validators, task T4). Structural checks over the root
# Makefile: static greps assert the test-config target body references both
# new validators (validate-agent-names.sh + validate-handoff.sh) alongside the
# pre-existing validate-opencode-config.sh, and a `make -n` dry-run asserts the
# host-scoped skip note and the test-typecheck prerequisite (DIA-260928-gpcc:
# the typecheck seam lives HERE now; scripts/__tests__/typecheck-target.bats
# was retired because its unanchored whole-file substring grep went false-green
# on a commented-out prerequisite and false-red on a harmless reorder).
#
# The validators themselves are unit-tested hermetically in
# validate-agent-names.bats / validate-handoff.bats; this suite only guards the
# Makefile wiring seam so a future edit cannot silently drop the validators
# (or the typecheck) from the config gate.

load test-helper

@test "test-config wiring: Makefile references both new validators" {
  # Each new validator must appear in the test-config target body. The recipe
  # line form is `bash scripts/<name>.sh` (same shape as validate-opencode-config.sh).
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-agent-names.sh"
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-handoff.sh"
  # Pre-existing baseline preserved: validate-opencode-config.sh still wired.
  assert_file_contains "$REPO_ROOT/Makefile" "bash .opencode/scripts/validate-opencode-config.sh"
}

@test "test-config wiring: Makefile emits visible host-scoped skip note (P2, DIA-260922-cp0m)" {
  # P2: the test-config recipe must print a visible @echo noting that
  # compose-config validation is host-scoped and runs host-side. This prevents
  # silent coverage shrinkage (the PHASE 3 false-green lesson).
  #
  # Discriminating pin: `make -n` (dry-run) outputs recipe lines but NOT
  # comments. The old `# NOTE:` comment form produces ZERO matches in
  # `make -n` output; the `@echo` form produces exactly one. This assertion
  # would FAIL against the unfixed Makefile.
  local dry_run_output
  dry_run_output="$(make -C "$REPO_ROOT" -n test-config 2>/dev/null)"
  echo "$dry_run_output" | grep -q "compose config validation is host-scoped"
  # DIA-260928-gpcc: same dry-run must schedule the typecheck. Asserting on
  # make's dependency GRAPH (the expanded recipe), not on the Makefile text,
  # so a commented-out prerequisite reddens while a harmless reorder stays
  # green - the exact false-green/false-red pair the retired
  # typecheck-target.bats whole-file substring grep had.
  echo "$dry_run_output" | grep -q "==> typecheck .opencode/plugins"
  echo "$dry_run_output" | grep -q "npx --no-install tsc --noEmit -p .opencode/plugins/tsconfig.json"
}

@test "typecheck wiring: scoped project pins isolatedModules and excludes .scratch (DIA-260928-gpcc)" {
  # The two established values of the plugin tsconfig, asserted by PARSING the
  # JSON rather than by text matching: the invariant is "the two syntax-model
  # flags (isolatedModules and erasableSyntaxOnly) are on" and "the scratch
  # tree is excluded", so a future `.scratch` ->
  # `**/.scratch` spelling change keeps the test green.
  cd "$REPO_ROOT" # the snippet below uses a relative path; pin the CWD
  run python3 -c "import json,sys; c=json.load(open('.opencode/plugins/tsconfig.json')); co=c['compilerOptions']; assert co['isolatedModules'] is True; assert co['erasableSyntaxOnly'] is True; ex=c['exclude']; assert any(e.endswith('.scratch') for e in ex)"
  [ "$status" -eq 0 ]
  # Real invariant kept from the retired suite: test-typecheck stays listed in
  # .PHONY (same idiom: pin the single .PHONY line, then fixed-string grep).
  local phony_line
  phony_line="$(grep -F '.PHONY:' "$REPO_ROOT/Makefile")"
  run grep -Fq 'test-typecheck' <<<"$phony_line"
  [ "$status" -eq 0 ]
}
