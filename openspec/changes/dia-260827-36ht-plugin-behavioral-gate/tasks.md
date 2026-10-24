## 1. DIA-189 harness WSL fixture

- [ ] 1.1 Scope WSL_DISTRO_NAME fixture to desktop-toast tests with save and restore in cleanup, keeping the existing spawn mock (blocks: none; .sdd/opencode-config/architecture.md)
- [ ] 1.2 Verify focused DIA-189 suite passes with the marker and non-desktop tests show no platform dependence (blocks: 1.1)
- [ ] 1.3 Verify platform-gate pure-Linux suite passes unchanged (blocks: 1.1)

## 2. Pre-push wiring

- [ ] 2.1 Add a host-local Bun leg after make test-omo and before pnpm verify:python that runs only the six DIA-189 desktop-toast tests with the pattern "desktop toast|Cyrillic|control chars|single quotes|180 chars|C1 control"; require Bun on host PATH, run no Docker, remain push-blocking under set -e, and preserve container-down warn-and-pass (blocks: none; .sdd/dev-infra/architecture.md)
- [ ] 2.2 Extend scripts/**tests**/verify-pre-push.bats with placement assertion for the new ladder line (blocks: 2.1)

## 3. Gate verification

- [ ] 3.1 Run the focused host-local Bun leg green: all six DIA-189 desktop-toast tests pass, the platform-gate suite remains unchanged, and bats pins the pre-push placement (blocks: 1.2, 2.1)
- [ ] 3.2 Run make test-shell filtered verify-pre-push bats plus make test-config (blocks: 2.2)
- [ ] 3.3 Confirm any DIA-189 desktop failure remaining after the marker is filed as a separate product-defect ticket, not fixed here (blocks: 1.2)
