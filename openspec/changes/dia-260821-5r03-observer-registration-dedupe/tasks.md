## 1. Config single-source-of-truth + doc drift fix

- [ ] 1.1 Correct `docs/dev-infra-audit/inventory.md` L60: remove or annotate the stale
      `file:///workspace/.opencode/plugins/delegation-observer.ts` and
      `file:///workspace/.opencode/plugins/needs-input-observer.ts` entries so the documented
      plugin array reflects auto-discovery (no explicit observer entries). **Acceptance:**
      `grep -n "file:///workspace/.opencode/plugins/delegation-observer.ts"
docs/dev-infra-audit/inventory.md` returns no match, OR the entry is explicitly annotated
      as auto-discovered / not present in the live plugin array. **Blocks:** 2.1.
- [ ] 1.2 State the single-source-of-truth rule in the doc: observers load via
      auto-discovery of `.opencode/plugins/` and MUST NOT be added as explicit plugin-array
      entries in any config layer. **Acceptance:** inventory.md (or NEXT-RUN.md) states the rule
      in one sentence.

## 2. Dedupe validator (make test-config gate)

- [ ] 2.1 Create `scripts/validate-observer-dedupe.sh`: bash-3 compatible, coreutils + jq
      only. Enumerate auto-discovered observer basenames from `.opencode/plugins/*.ts`; for each
      config layer (`opencode.jsonc`, `oh-my-opencode-slim.jsonc`, `tui.json`,
      `tools/opencode-docker/config/opencode.json`) parse the `plugin` array, resolve each
      entry to a canonical basename (strip `file:///`, `./`, `@scope/`, version `@x.y.z`,
      `.ts`/`.js`), and exit 1 if (i) that basename is in the auto-discovered observer set, or
      (ii) the same basename appears twice within one array. **Acceptance:** script exits 0
      against current configs; script exits 1 when an explicit observer entry is added to a temp
      config fixture. **Blocks:** 3.1.
- [ ] 2.2 Make `scripts/validate-observer-dedupe.sh` executable (`chmod +x`). **Acceptance:**
      `ls -l scripts/validate-observer-dedupe.sh` shows the executable bit set.
- [ ] 2.3 Wire `scripts/validate-observer-dedupe.sh` into `make test-config` (add
      `bash scripts/validate-observer-dedupe.sh` after the existing `validate-*.sh` calls).
      **Acceptance:** `make test-config` runs the new validator and exits 0 against current
      configs.

## 3. needs-input-observer globalThis guards

- [ ] 3.1 Add `NEEDS_INPUT_PERM_TIMERS_KEY = Symbol.for("needs-input-observer.permissionTimers")`
      guard around `pendingPermissionTimers` (arm/re-arm on boot clears any prior globalThis
      timers before creating new ones). **Acceptance:** a second factory invocation in the same
      process does not stack watchdog `setTimeout` handles (prior cleared/reused).
- [ ] 3.2 Add `NEEDS_INPUT_TITLE_BOOT_KEY = Symbol.for("needs-input-observer.titleSuffixBootDone")`
      guard around the title-suffix boot retro pass (rename existing sessions/ptys). **Acceptance:**
      boot retro pass runs once per process; reload skips it.
- [ ] 3.3 Add `NEEDS_INPUT_TOAST_KEY = Symbol.for("needs-input-observer.notifiedAsks")` Set
      guard around the TUI toast (keyed by `session_id+reason`). **Acceptance:** a reload does
      not re-toast an already-notified pending ask.
- [ ] 3.4 Add `NEEDS_INPUT_TICKER_BOOT_KEY = Symbol.for("needs-input-observer.tickerBootSeeded")`
      guard around the ticker boot-seed + watchdog re-arm. **Acceptance:** a reload does not
      double-seed the ticker.
- [ ] 3.5 Update the `dispose` hook to clear all four globalThis Symbols (mirror
      delegation-observer dispose). **Acceptance:** after `dispose()`, all four Symbols are
      undefined.
- [ ] 3.6 `node --experimental-strip-types --check .opencode/plugins/needs-input-observer.ts`
      exits 0. **Blocks:** 5.1.

## 4. delegation-observer completeness audit

- [ ] 4.1 Audit `.opencode/plugins/delegation-observer.ts` for any singleton side-effect
      beyond boot/stall-sweep that lacks a globalThis guard (candidate: `routingWriteTimer` at
      L1841). If found unguarded on reload, apply the same globalThis guard pattern. Boot/stall-
      sweep are already guarded (plugin-reload-boot-sweep-dedup) - do NOT re-implement them.
      **Acceptance:** every singleton timer/hook in delegation-observer.ts is either
      globalThis-guarded or documented as per-instance + cleared in dispose.

## 5. Unit tests

- [ ] 5.1 Create `.opencode/plugins/__tests__/needs-input-observer.reload-dedup.test.mjs`
      mirroring `delegation-observer.reload-dedup.test.mjs`: assert each guard suppresses on
      second factory invocation; assert `dispose()` clears the Symbols. **Acceptance:** bun test
      passes. **Blocks:** 6.2.
- [ ] 5.2 Run `make test-harness` (bun plugin suite); assert all plugin tests pass.
      **Blocks:** 6.2.

## 6. Validation + config chain

- [ ] 6.1 Run `openspec validate dia-260821-5r03-observer-registration-dedupe`; assert
      validation passes.
- [ ] 6.2 Run `make test-config`; assert exit 0 (including new
      `validate-observer-dedupe.sh`). **Blocks:** 6.3.
- [ ] 6.3 Run `make test-shell`; assert exit 0.
- [ ] 6.4 Dispatch `@ai-auditor` for independent review of the config + plugin change
      against best practices + AIHero patterns. **Acceptance:** no critical findings;
      recommendations addressed or deferred with rationale. **Blocks:** 6.5.
- [ ] 6.5 Append `.opencode/CHANGELOG.yaml` entry (schema-valid); validate with
      `scripts/validate-changelog.sh`; regenerate MD with `scripts/changelog-render`.
      **Acceptance:** `scripts/validate-changelog.sh` exits 0; `.opencode/CHANGELOG.md` reflects
      the new entry.
