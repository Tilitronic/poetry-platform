## 1. Trusted artifact-fetch containment

- [ ] 1.1 Use the tdd-craftsman workflow to create focused failing seam tests
      for trusted researcher and resource-manager allocations, arbitrary
      destination rejection, traversal, symlink escape, and failed atomic
      publication. **Acceptance:** both allow-listed roots publish only within
      their allocations; every escape case leaves no final artifact. **Blocks:**
      none. **Boundary:** existing OpenCode configuration/plugin boundary; no
      governing `.sdd/` document exists.
- [ ] 1.2 Implement the smallest typed fetch-to-artifact boundary that derives
      the root and safe artifact name from the trusted allocation, resolves and
      verifies containment, and atomically publishes a successful fetch.
      **Acceptance:** all focused artifact-fetch seam tests pass without a new
      runtime dependency or a caller-selected output path. **Blocks:** 1.1.

## 2. Protected workflow-path bash gate

- [ ] 2.1 Use the tdd-craftsman workflow to add failing delegation-observer
      seam tests for downloader output flags, redirection, and `tee` targeting
      `.opencode/*`, `scripts/*`, `AGENTS.md`, and Git metadata; include a
      trusted artifact target that is not denied merely by the protected-path
      rule. **Acceptance:** each protected target is demonstrably denied before
      execution, with no test that executes an actual write. **Blocks:** none.
      **Boundary:** existing OpenCode configuration/plugin boundary; no
      governing `.sdd/` document exists.
- [ ] 2.2 Implement the minimum delegation-observer pre-execution
      protected-path decision using resolved write targets and an explicit
      protected-path set. **Acceptance:** the focused gate tests pass and the
      gate reports a clear pre-execution denial. **Blocks:** 2.1.

## 3. Fetch-lane permission migration

- [ ] 3.1 Migrate researcher and resource-manager artifact publication to the
      trusted boundary, then remove their universal `curl *` and `wget *`
      permissions. **Acceptance:** both lanes retain the approved source-fetch
      workflow without either universal downloader permission. **Blocks:** 1.2.
- [ ] 3.2 Add or extend configuration validation that proves the two universal
      downloader rules are absent and general coder `node`, `bun`, and
      `python3` permissions are unchanged. **Acceptance:** the configuration
      validation seam passes on the intended policy and fails on a fixture that
      restores a prohibited wildcard rule. **Blocks:** 3.1.

## 4. Integrated security verification and policy closure

- [ ] 4.1 Run the focused artifact-fetch and delegation-observer suites,
      `make test-config`, and the applicable plugin harness tests; restart
      OpenCode for a permitted source-fetch smoke test and a protected-path
      denial smoke test. **Acceptance:** all gates exit 0; the permitted fetch
      writes only under its allocation and the denial path executes no write.
      **Blocks:** 2.2, 3.2.
- [ ] 4.2 Dispatch `@ai-auditor` for independent Section 2.5 review, then
      register the approved policy change through the OpenCode changelog
      workflow. **Acceptance:** critical findings are resolved or explicitly
      dispositioned before the changelog entry is validated and rendered.
      **Blocks:** 4.1.
