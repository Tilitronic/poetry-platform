## 1. RED slice 1 - core decision tests at the session.created seam

- [ ] 1.1 Author failing tests for divergent-switch, already-correct no-op, and env-absent no-op at seam S1 with a mocked session service capturing switchModel calls. Blockers: none. Acceptance: from the user's view, a divergent `/new` would switch once, a matching or env-less start would stay untouched; tests fail before implementation. Lane: RED coder instance A (test-author only, never implements). Depends on .sdd/opencode-config/architecture.md ADR 3 seam confirmation.

## 2. GREEN slice 1 - core decision path implementation

- [ ] 2.1 Implement the guard decision path (env read, intent resolve, equality short-circuit, single switchModel) until slice-1 RED goes green, plus focused test run and test-config pass. Blockers: 1.1. Acceptance: divergent newborn session lands on preset intent; matching and env-absent sessions untouched; no per-turn behavior. Lane: GREEN coder instance B (different session from A per DIA-175). Depends on .sdd/opencode-config/architecture.md plugin seam precedent.

## 3. RED slice 2 - exemption, fire-once, and failure tests

- [ ] 3.1 Author failing tests for explicit-override exemption, duplicate-event exactly-once, throwing-switchModel survival with no retry, and the S2 setup shape-probe degradation. Blockers: 1.1. Acceptance: from the user's view, an explicit `--model` start is never clobbered, a double event switches once, and a guard failure never breaks the session; tests fail before implementation. Lane: RED coder instance A (same test-author session as 1.1). Depends on .sdd/opencode-config/architecture.md ADR 3.

## 4. GREEN slice 2 - exemptions, fire-once, fail-soft, and wiring

- [ ] 4.1 Implement override detection, per-session fired-set, try/catch fail-soft with single log line, and the setup shape probe until slice-2 RED goes green; register the plugin only if the v2 loader requires it, then run the version-sync triplet and full make test-config re-pass. Blockers: 2.1, 3.1. Acceptance: all six spec scenarios plus the probe pass, `openspec validate` passes, `make test-config` exits 0, and deleting the one new file restores prior behavior. Lane: GREEN coder instance B (same implementer session as 2.1; fix loops resume this session per ADR 4). Depends on .sdd/opencode-config/architecture.md ADR 4.
