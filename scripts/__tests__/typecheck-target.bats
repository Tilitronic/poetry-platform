#!/usr/bin/env bats
# Wiring regression for the `make test-typecheck` target (campaign
# DIA-260928-gpcc, task T5). Static grep over the root Makefile with fixed
# strings: the target must exist, use the pinned npx form scoped to the
# plugin tsconfig, stay in .PHONY, the project file must exist, and
# test-config lists it as a prerequisite (wired in DIA-260928-gpcc T6).

load test-helper

@test "typecheck wiring: Makefile declares pinned test-typecheck target" {
  run grep -Fq 'test-typecheck:' "$REPO_ROOT/Makefile"
  [ "$status" -eq 0 ]
  run grep -Fq 'test-config: test-interview test-skills test-typecheck' "$REPO_ROOT/Makefile"
  [ "$status" -eq 0 ]
  run grep -Fq 'npx --no-install tsc --noEmit -p .opencode/plugins/tsconfig.json' "$REPO_ROOT/Makefile"
  [ "$status" -eq 0 ]
  local phony_line
  phony_line="$(grep -F '.PHONY:' "$REPO_ROOT/Makefile")"
  run grep -Fq 'test-typecheck' <<<"$phony_line"
  [ "$status" -eq 0 ]
  run test -f "$REPO_ROOT/.opencode/plugins/tsconfig.json"
  [ "$status" -eq 0 ]
}
