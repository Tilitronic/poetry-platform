# OpenCode Plugin Loader Contract (delegation-observer SRP refactor gate)

## Verdict: APPROVE with 3 must-fix amendments (A1-A3) + 2 advisories

## Key facts (source-verified 2026-09-02)
1. lib/ is structurally NOT a phantom plugin: ConfigPlugin.load scans Glob.scan("{plugin,plugins}/*.{ts,js}", {cwd}) — single-level * never crosses a directory separator, so plugins/lib/*.ts is excluded from discovery at dev HEAD.
2. Wy .server guard remains mandatory indefinitely: getLegacyPlugins still throws TypeError("Plugin export is not a function") on any non-function, non-{server} export; the throw kills the WHOLE module's registration silently (issue #41234). PR #43785 (fail-soft skip) is OPEN, not merged — no release through v1.18.26 contains it.
3. Reference-identity dedup preserves factory-call cardinality: getLegacyPlugins uses seen.has(entry) on values; re-exporting the same function/regex objects from the shell keeps today's exact call set. Misuse guards (return {} when passed PluginInput) must move verbatim.
4. Static .ts imports, no bundler: correct for both runtimes (node --experimental-strip-types + Bun Wy check in validate-plugin-loads.sh).
5. Hook-order preservation: loader applies plugins sequentially; event dispatch is synchronous fire-and-forget; trigger awaits each hook — sync hook bodies are valid.
6. globalThis Symbol.for dedup: necessary, not optional. Local-plugin dedup is by exact file URL per config load; reload re-evaluates. Clearing prior interval on reload is the right pattern.
7. Circuit breaker shape matches converged practice: count-based sliding window (resilience4j COUNT_BASED), CLOSED/OPEN/HALF_OPEN FSM, per-tool scope, single HALF_OPEN probe, session-scoped in-memory state, never-throws + fail-soft. Verbatim 5/3/5min is right.
8. DAG shell->lib, DI of env deps, persistence-adapter exceptions: sound.

## Must-fix amendments for @coder
- A1: Shell re-exports verbatim: export { CAPABILITY_SECRET, mintCapabilityToken, verifyCapabilityToken } from "./lib/capability.ts" + the 3 TICKET_ID_* regexes from "./lib/ticket-gate.ts" + export default. Attach .server guards at lib definition sites (property travels through re-export). Misuse guards move verbatim.
- A2: Keep Symbol.for strings identical (delegation-observer.stallSweepInterval, delegation-observer.bootEmitted); shell owns the singleton handles per D1.
- A3: One shared TICKET_ID_FIND_RE instance; match/matchAll-only consumption in ticket-gate.ts (never .test()/.exec() — lastIndex drift silently skips matches).
- Shell gains zero new exports; every slice gated by scripts/validate-plugin-loads.sh + full bun test .opencode/plugins/__tests__/ + make test-config.
- New per-lib tests: use the design's DI (injected fs/clock/spawnSync/timers) instead of mock.module.

## Advisories
- Spec line-count drift (4,985 stated vs 5,048 at HEAD): re-derive ranges at implementation.
- validate-plugin-loads.sh hardcodes an absolute host path; coder must confirm it executes in-container.

## Re-check trigger
PR #43785 merge/release (fail-soft plugin export skip) — re-verify .server guard necessity on major upgrade.

## Sources
S1 discovery glob: raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/config/plugin.ts
S2 loader throw/dedup/order: .../dev/packages/opencode/src/plugin/index.ts
S3 silent whole-plugin death: github.com/anomalyco/opencode/issues/41234 (+#31575, #42451)
S4 fail-soft fix OPEN: github.com/anomalyco/opencode/pull/43785
S5 lib-extraction pattern: github.com/marcusrbrown/systematic/issues/309
S6 bundler/CJS interop: github.com/diegosouzapw/OmniRoute/pull/3883
S7 plugin API: opencode.ai/docs/plugins/
S8 breaker practice: resilience4j.readme.io/docs/circuitbreaker; martinfowler.com/bliki/CircuitBreaker.html
S9 local ground truth: delegation-observer.ts, lib/errors.ts, __tests__ import graph, validate-plugin-loads.sh
