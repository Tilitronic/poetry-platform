# 2026-09-09 - Section 2.5 gate findings (DIA-260903-o7n0 D4 fix lanes)

## Verdict
Plugin test code IS section 2.5 scope (opencode-config lane). The D4 fix
lanes (2350ee8 + 921394d + e3744fa + a1fffb2) ran under 8 fix-lane
conditions with ai-auditor as independent reviewer. Zero scope conflicts.

## Scope ruling (fold into future lanes)
- Plugin test code (helpers, mocks, contract tests under
  .opencode/plugins/__tests__/) IS 2.5 scope: it binds the opencode runtime
  surface (module registry, mock semantics) and can leak across the suite.
- Production plugin code + test code travel together through the 2.5 gate;
  neither lands without the gate verdict (GO / GO-WITH-CONDITIONS / NO-GO).

## The 8 fix-lane conditions (imposed on every fix commit)
1. No new helper exports (4 exports max, hard cap).
2. Fail-loud behavior allowlist (unknown mock behavior throws).
3. Predicate pinned to the production call shape
   (delegation-observer.ts:817-819).
4. Contract tests live in test/scenario files, never in the helper.
5. Exit codes + summary lines per fix (evidence, not prose).
6. Both gates (bun suite + harness replay) after each commit.
7. Budget numbers in the ticket backfill (prod/shell/test LOC).
8. ASCII-only per DIA-079.
- Commit hygiene (enforced alongside): stage only fix files + ticket update.

## Routing notes
- opencode config changes -> @ai-auditor as independent reviewer (not
  @reviewer; the review matrix in AGENTS.md 2.5 assigns config to ai-auditor).
- Same-session fix loops per DIA-175: the implementer session that authored
  the code owns its fix loop (test-author/implementer separation still holds
  across slices; fixes resume the author session).
- Carryover for @resource-manager: bun.sh source gap stands (no
  Bun-testing-docs entry in ai-assist-sources.yaml at time of writing);
  recommend adding bun.sh/docs/test/mocks + bun.sh/docs/test/parallel under
  tier2_volatile_web (non-blocking, same as the 2026-09-03 note).

## Source-gap note
Same gap as 2026-09-03-debloat-gate-research.md: mock.restore() vs
mock.module() semantics were verified by local probe (Bun 1.3.14), not by a
cached Tier-1 source. Probe result stands as lane evidence until the
Tier-1 entry lands.
