## 1. Path fix (config correction)

- [ ] 1.1 Fix the two dead explicit paths in `.opencode/opencode.jsonc` (lines 603-604): change `./.opencode/plugins/delegation-observer.ts` to `./plugins/delegation-observer.ts` and `./.opencode/plugins/needs-input-observer.ts` to `./plugins/needs-input-observer.ts`. **Acceptance:** `grep -n "plugins/" .opencode/opencode.jsonc` shows lines 603-604 with `./plugins/...` (not `./.opencode/plugins/...`). **Blocks:** 2.1, 3.1.

## 2. Validation script (fail-hard gate)

- [ ] 2.1 Create `scripts/validate-local-plugins.sh`: bash-3 compatible, coreutils + jq only. Parse `.opencode/opencode.jsonc` with `jq`, extract `plugins[]` array, filter entries with `./` prefix, resolve each relative to `.opencode/` directory, check `-f` for each resolved path. Exit 1 with error message if any path is missing; exit 0 if all paths exist. **Acceptance:** script exits 0 against current config (after 1.1 fix); script exits 1 if a path is manually broken (e.g., change `./plugins/delegation-observer.ts` to `./plugins/nonexistent.ts`, run script, verify exit 1). **Blocks:** 3.1.

- [ ] 2.2 Make `scripts/validate-local-plugins.sh` executable: `chmod +x scripts/validate-local-plugins.sh`. **Acceptance:** `ls -l scripts/validate-local-plugins.sh` shows executable bit set.

## 3. Makefile integration (wire into test-config)

- [ ] 3.1 Wire `scripts/validate-local-plugins.sh` into `make test-config`: add `bash scripts/validate-local-plugins.sh` to the `test-config` target in `Makefile` (after existing `validate-*.sh` calls, before `test-ticket-gate.sh`). **Acceptance:** `make test-config` runs `validate-local-plugins.sh` and exits 0 (after 1.1 fix and 2.1 script creation).

## 4. Config chain verification (restart, audit, changelog)

- [ ] 4.1 Restart OpenCode + functional smoke test: after applying 1.1, restart OpenCode and verify plugins load correctly (check startup logs or `opencode debug config` output for plugin origins). **Acceptance:** startup logs show `delegation-observer.ts` and `needs-input-observer.ts` loaded from `.opencode/plugins/...` (not dead nested paths). **Blocks:** 4.2.

- [ ] 4.2 Dispatch `@ai-auditor` for independent review: ai-auditor reviews the implemented config change (1.1 + 2.1 + 3.1) against best practices + AIHero patterns. **Acceptance:** ai-auditor report shows no critical findings; any recommendations are addressed or explicitly deferred with rationale. **Blocks:** 4.3.

- [ ] 4.3 Append `CHANGELOG.yaml` entry: add one schema-valid entry to `.opencode/CHANGELOG.yaml` (see `scripts/schemas/changelog.schema.json` for schema). Validate with `scripts/validate-changelog.sh`. Regenerate derived MD with `scripts/changelog-render`. **Acceptance:** `scripts/validate-changelog.sh` exits 0; `.opencode/CHANGELOG.md` reflects the new entry.

## 5. Final validation (full gate)

- [ ] 5.1 Run full `make test-config`: verify all validation scripts pass (including new `validate-local-plugins.sh`). **Acceptance:** `make test-config` exits 0. **Blocks:** 5.2.

- [ ] 5.2 Run `make test-shell`: verify bats suite passes (no regression in shell tests). **Acceptance:** `make test-shell` exits 0.

- [ ] 5.3 Manual smoke test: create a test scenario where a local plugin path is broken (e.g., temporarily change `./plugins/delegation-observer.ts` to `./plugins/nonexistent.ts`), run `make test-config`, verify it exits 1 with error message. Restore the correct path, verify `make test-config` exits 0. **Acceptance:** broken path → exit 1; correct path → exit 0.
