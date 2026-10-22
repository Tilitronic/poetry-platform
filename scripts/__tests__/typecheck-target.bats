#!/usr/bin/env bats
# Wiring regression for the `make test-typecheck` target (campaign
# DIA-260928-gpcc, task T5). Static grep over the root Makefile with fixed
# strings: the target must exist, use the pinned npx form scoped to the
# plugin tsconfig, stay in .PHONY, and the project file must exist.
# Deliberately NOT asserted: whether test-config depends on this target
# (that dependency is wired in a later step; pinning it now would freeze
# a false state).

load test-helper

@test "typecheck wiring: Makefile declares pinned test-typecheck target" {
  run grep -Fq 'test-typecheck:' "$REPO_ROOT/Makefile"
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
