/**
 * RED test-author lane for Slice 7 — lib/circuit-breaker.ts (DIA-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts circuit-breaker seam
 *   CB_WINDOW_SIZE=5, CB_ERROR_THRESHOLD=3, CB_COOLDOWN_MS=5min (D3 verbatim)
 *   type CircuitState = "CLOSED" | "OPEN" | "HALF_OPEN"
 *   interface CircuitBreakerEntry { state, window, openedAt, testCallMade }
 *   class ToolCircuitBreaker { record(sessionId,isError): CircuitState; tryPass(sessionId): boolean; getState(sessionId): CircuitState }
 *     private circuits = Map<string, CircuitBreakerEntry>
 *     getEntry(sessionId) -> { state: CLOSED, window: [], openedAt: 0, testCallMade: false }
 *     record: CLOSED push isError / shift if >5, count >=3 -> OPEN (openedAt=now)
 *             OPEN: if now-openedAt>=5min -> HALF_OPEN (testCallMade false) then fall through
 *             HALF_OPEN: testCallMade false; if isError -> OPEN (openedAt=now, push true) else CLOSED (window=[])
 *             tryPass: no entry -> false; OPEN && cooldown expired -> HALF_OPEN; OPEN -> true (block)
 *                      HALF_OPEN && testCallMade -> true (block); HALF_OPEN -> testCallMade=true, false (allow)
 *                      CLOSED -> false
 *     getState: entry?.state ?? CLOSED
 *
 * Learnings: .opencode/learnings/external-patterns/2026-09-02-opencode-plugin-loader-contract.md
 *   lib is pure/DI'd (inject clock fakes), no ctx capture, no shell import; D3 constants verbatim;
 *   D1 sync; pure in-memory, no FS.
 *
 * ASSUMED LIB SIGNATURE (GREEN implementer must match; note per task dispatch):
 *
 *   .opencode/plugins/lib/circuit-breaker.ts  (pure in-memory, no FS, clock injected)
 *
 *     export const CB_WINDOW_SIZE = 5
 *     export const CB_ERROR_THRESHOLD = 3
 *     export const CB_COOLDOWN_MS = 5 * 60 * 1000  // 300_000
 *
 *     export type CircuitState = "CLOSED" | "OPEN" | "HALF_OPEN"
 *     // CircuitBreakerEntry is internal — not required as public export
 *
 *     export class ToolCircuitBreaker {
 *       constructor(deps?: { now?: () => number; clock?: () => number } | (() => number))
 *       // deps may be { now }, { clock }, { nowFn }, or bare function; GREEN should support at least { now }.
 *       record(sessionId: string, isError: boolean): CircuitState  // new state
 *       tryPass(sessionId: string): boolean  // true = BLOCK dispatch, false = allow
 *       getState(sessionId: string): CircuitState  // "CLOSED" default for unknown session
 *     }
 *
 *     // Factory alternative (probed first; plain class fallback if absent):
 *     export function createCircuitBreaker(deps?: { now?: () => number }): ToolCircuitBreaker
 *     // aliases probed: createToolCircuitBreaker, createBreaker, create
 *
 *   DI seam (design.md): lib is pure/DI'd. GREEN must inject clock so tests can fake time
 *   without monkey-patching global Date.now. Tests handle BOTH shapes:
 *     - if factory exists, they inject fakes via factory
 *     - otherwise they try `new ToolCircuitBreaker({ now: fake })`
 *     - fallback: plain `new ToolCircuitBreaker()` (then monkey-patch Date.now per test)
 *
 * RUN (like other plugin tests):
 *   node --test .opencode/plugins/__tests__/circuit-breaker.test.mjs
 *   # with strip-types for .ts lib:
 *   node --experimental-strip-types --test .opencode/plugins/__tests__/circuit-breaker.test.mjs
 *   bun test .opencode/plugins/__tests__/circuit-breaker.test.mjs
 *
 * EXPECTED RED: all tests FAIL against the S0 stub (export {}) because
 *   CB_* constants / ToolCircuitBreaker / createCircuitBreaker are undefined.
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"

// ---------------------------------------------------------------------------
// Import the lib under test (stub in RED phase).
// ---------------------------------------------------------------------------
let mod = {}
let importErr = null
try {
  mod = await import("../lib/circuit-breaker.ts")
} catch (e) {
  importErr = e
  mod = {}
}

// ---------------------------------------------------------------------------
// Helpers to resolve DI seam if GREEN exposes a factory or DI'd constructor.
// ---------------------------------------------------------------------------

function makeBreaker(clock) {
  const nowFn = typeof clock === "function" ? clock : clock?.now ?? null
  const deps = nowFn ? { now: nowFn } : {}
  const factory = mod.createCircuitBreaker
  if (typeof factory === "function") {
    try {
      const inst = Object.keys(deps).length ? factory(deps) : factory()
      if (inst && typeof inst.record === "function") return inst
    } catch { /* ignore */ }
  }
  const Cls = mod.ToolCircuitBreaker
  if (typeof Cls === "function") {
    if (Object.keys(deps).length) {
      try {
        const inst = new Cls(deps)
        if (inst && typeof inst.record === "function") return inst
      } catch { /* ignore */ }
    }
    try {
      const inst = new Cls()
      if (inst && typeof inst.record === "function") return inst
    } catch { /* ignore */ }
  }
  return null
}

function requireBreaker(clock) {
  if (importErr) throw new Error(`RED scaffold: cannot import ../lib/circuit-breaker.ts (${importErr.message})`)
  const b = makeBreaker(clock)
  if (!b) throw new Error("RED scaffold: lib/circuit-breaker.ts does not export ToolCircuitBreaker / createCircuitBreaker — GREEN must add it")
  return b
}

function requireConst(name, expected) {
  if (importErr) throw new Error(`RED scaffold: cannot import lib/circuit-breaker.ts (${importErr.message})`)
  const v = mod[name]
  if (v === undefined) throw new Error(`RED scaffold: lib/circuit-breaker.ts missing export '${name}' (expected ${expected}) — GREEN must add it`)
  return v
}

// Fake clock helper: returns { now: () => number, advance: (ms)=>void, set:(ms)=>void }
function fakeClock(startMs = 1_000_000) {
  let t = startMs
  return {
    now: () => t,
    advance: (ms) => { t += ms },
    set: (ms) => { t = ms },
    get: () => t,
  }
}

// ---------------------------------------------------------------------------
// 1. Constants verbatim D3
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — constants (D3 verbatim)", () => {
  it("CB_WINDOW_SIZE=5 exists and equals 5", () => {
    const v = requireConst("CB_WINDOW_SIZE", 5)
    assert.equal(v, 5, `CB_WINDOW_SIZE must be 5, got ${v}`)
  })

  it("CB_ERROR_THRESHOLD=3 exists and equals 3", () => {
    const v = requireConst("CB_ERROR_THRESHOLD", 3)
    assert.equal(v, 3)
  })

  it("CB_COOLDOWN_MS=5min (300000) exists and equals 300000", () => {
    const v = requireConst("CB_COOLDOWN_MS", 300000)
    assert.equal(v, 5 * 60 * 1000)
    assert.equal(v, 300_000)
  })

  it("constants are numbers (not strings)", () => {
    assert.equal(typeof requireConst("CB_WINDOW_SIZE", 5), "number")
    assert.equal(typeof requireConst("CB_ERROR_THRESHOLD", 3), "number")
    assert.equal(typeof requireConst("CB_COOLDOWN_MS", 300000), "number")
  })
})

// ---------------------------------------------------------------------------
// 2. ToolCircuitBreaker exists and basic shape
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — ToolCircuitBreaker shape", () => {
  it("ToolCircuitBreaker class or createCircuitBreaker factory is exported", () => {
    if (importErr) assert.fail(`import failed: ${importErr.message}`)
    const hasClass = typeof mod.ToolCircuitBreaker === "function" || typeof mod.CircuitBreaker === "function" || typeof mod.Breaker === "function"
    const hasFactory = typeof mod.createCircuitBreaker === "function" || typeof mod.createToolCircuitBreaker === "function" || typeof mod.create === "function" || typeof mod.createBreaker === "function"
    const hasInstance = typeof mod.record === "function"
    assert.ok(hasClass || hasFactory || hasInstance, "must export ToolCircuitBreaker class or createCircuitBreaker factory or direct record/tryPass")
  })

  it("breaker instance has record, tryPass, getState", () => {
    const b = requireBreaker()
    assert.equal(typeof b.record, "function", "record must be function")
    assert.equal(typeof b.tryPass, "function", "tryPass must be function")
    assert.equal(typeof b.getState, "function", "getState must be function")
  })

  it("getState returns CLOSED for unknown session", () => {
    const b = requireBreaker()
    assert.equal(b.getState("ses_unknown_" + Date.now()), "CLOSED")
  })

  it("tryPass returns false for unknown session (no entry -> not blocked)", () => {
    const b = requireBreaker()
    assert.equal(b.tryPass("ses_unknown2_" + Math.random()), false)
  })
})

// ---------------------------------------------------------------------------
// 3. CLOSED->OPEN on >=3/5 errors (sliding window)
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — CLOSED->OPEN on >=3/5 errors", () => {
  it("stays CLOSED with 2 errors in window", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_closed_2err"
    b.record(sid, true)
    b.record(sid, true)
    assert.equal(b.getState(sid), "CLOSED", "2 errors must not trip")
    assert.equal(b.tryPass(sid), false, "CLOSED must not block")
  })

  it("trips to OPEN on 3 consecutive errors", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_trip_3"
    b.record(sid, true)
    b.record(sid, true)
    const state = b.record(sid, true)
    assert.equal(state, "OPEN", "3rd error must trip to OPEN")
    assert.equal(b.getState(sid), "OPEN")
    assert.equal(b.tryPass(sid), true, "OPEN must block")
  })

  it("trips with 3 errors in last 5 (non-consecutive, scattered)", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_scattered"
    // pattern: err, ok, err, ok, err -> 3 errors in 5
    b.record(sid, true)   // 1 err
    b.record(sid, false)  // 1e 1
    b.record(sid, true)   // 2e
    b.record(sid, false)  // 2e
    const s = b.record(sid, true) // 3e -> trip
    assert.equal(s, "OPEN")
    assert.equal(b.getState(sid), "OPEN")
  })

  it("does NOT trip with 2 errors in last 5 after successes dilute", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_diluted"
    b.record(sid, true)
    b.record(sid, true)
    b.record(sid, false)
    b.record(sid, false)
    b.record(sid, false)
    assert.equal(b.getState(sid), "CLOSED", "2/5 must not trip")
  })

  it("sliding window keeps only last 5 — 7 calls window = last 5", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_window_last5"
    // first 2 errors, then 3 oks => window after 5 = [T,T,F,F,F] = 2 errors CLOSED
    b.record(sid, true)
    b.record(sid, true)
    b.record(sid, false)
    b.record(sid, false)
    b.record(sid, false) // 5 calls, 2 errors
    assert.equal(b.getState(sid), "CLOSED")
    // add 2 more errors => window after 7 total = last 5 = [F,F,F,T,T] = 2 errors still
    b.record(sid, true)
    b.record(sid, true)
    assert.equal(b.getState(sid), "CLOSED", "after sliding, still 2/5 -> CLOSED")
    // add 1 more error => window = [F,F,T,T,T] = 3 errors -> trip
    const s = b.record(sid, true)
    assert.equal(s, "OPEN", "slid window 3/5 must trip")
  })

  it("record returns new state (CLOSED until trip)", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_record_returns"
    assert.equal(b.record(sid, false), "CLOSED")
    assert.equal(b.record(sid, false), "CLOSED")
    assert.equal(b.record(sid, true), "CLOSED")
    assert.equal(b.record(sid, true), "CLOSED")
    assert.equal(b.record(sid, true), "OPEN")
  })
})

// ---------------------------------------------------------------------------
// 4. OPEN->HALF_OPEN after 5min (clock injected)
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — OPEN->HALF_OPEN after 5min", () => {
  it("stays OPEN before cooldown expires (tryPass blocks)", () => {
    const clk = fakeClock(1_000_000)
    const b = requireBreaker(clk)
    const sid = "s_open_before"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    assert.equal(b.getState(sid), "OPEN")
    clk.advance(4 * 60 * 1000) // 4 min
    assert.equal(b.tryPass(sid), true, "before 5min must still block")
    assert.equal(b.getState(sid), "OPEN", "state must remain OPEN before cooldown")
    // record while OPEN before cooldown should stay OPEN and not grow window beyond
    const s = b.record(sid, false)
    assert.equal(s, "OPEN", "record while OPEN before cooldown must stay OPEN")
  })

  it("transitions OPEN->HALF_OPEN after 5min via tryPass", () => {
    const clk = fakeClock(2_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_open_try"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    assert.equal(b.getState(sid), "OPEN")
    clk.advance(5 * 60 * 1000 + 1)
    // tryPass should transition to HALF_OPEN and allow the test call (false = not blocked)
    const blocked = b.tryPass(sid)
    assert.equal(blocked, false, "HALF_OPEN first call must be allowed (not blocked)")
    assert.equal(b.getState(sid), "HALF_OPEN", "after cooldown tryPass must move to HALF_OPEN")
  })

  it("transitions OPEN->HALF_OPEN after 5min via record (record drives transition too)", () => {
    const clk = fakeClock(3_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_open_record"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_000 + 1)
    // record after cooldown should first move to HALF_OPEN then process this record as test call
    // If we record success, it should go to CLOSED
    const s = b.record(sid, false)
    assert.equal(s, "CLOSED", "record after cooldown with success must transition via HALF_OPEN -> CLOSED")
    assert.equal(b.getState(sid), "CLOSED")
  })

  it("cooldown boundary: exactly 5min (300000) allows HALF_OPEN", () => {
    const clk = fakeClock(4_000_000)
    const b = requireBreaker(clk)
    const sid = "s_exact_5min"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_000) // exact
    assert.equal(b.tryPass(sid), false, "exact 5min must allow HALF_OPEN")
    assert.equal(b.getState(sid), "HALF_OPEN")
  })

  it("just before boundary (299999) stays OPEN", () => {
    const clk = fakeClock(5_000_000)
    const b = requireBreaker(clk)
    const sid = "s_just_before"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(299_999)
    assert.equal(b.tryPass(sid), true, "299999ms must still block")
    assert.equal(b.getState(sid), "OPEN")
  })
})

// ---------------------------------------------------------------------------
// 5. HALF_OPEN->CLOSED on test success / ->OPEN on fail
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — HALF_OPEN transitions", () => {
  it("HALF_OPEN->CLOSED on test success (record false)", () => {
    const clk = fakeClock(10_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_to_closed"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    b.tryPass(sid) // -> HALF_OPEN, consumes probe slot
    assert.equal(b.getState(sid), "HALF_OPEN")
    const s = b.record(sid, false) // success
    assert.equal(s, "CLOSED", "success in HALF_OPEN must close")
    assert.equal(b.getState(sid), "CLOSED")
    // window must be cleared so next errors start fresh
    assert.equal(b.tryPass(sid), false, "CLOSED after recovery must not block")
    // verify window cleared: 2 new errors should not trip (needs 3)
    // Use same breaker but check that after CLOSED window is empty: add 2 errors still CLOSED
    b.record(sid, true); b.record(sid, true)
    assert.equal(b.getState(sid), "CLOSED", "after HALF_OPEN->CLOSED window cleared, 2 errors must stay CLOSED")
  })

  it("HALF_OPEN->OPEN on test failure (record true)", () => {
    const clk = fakeClock(11_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_to_open"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    b.tryPass(sid) // HALF_OPEN
    const s = b.record(sid, true) // fail
    assert.equal(s, "OPEN", "failure in HALF_OPEN must reopen")
    assert.equal(b.getState(sid), "OPEN")
    assert.equal(b.tryPass(sid), true, "reopened must block")
    // openedAt reset: should need another full cooldown before next HALF_OPEN
    clk.advance(299_999)
    assert.equal(b.tryPass(sid), true, "after fail-reopen, just before next cooldown must still block")
  })

  it("failure in HALF_OPEN resets cooldown (needs another 5min)", () => {
    const clk = fakeClock(12_000_000)
    const b = requireBreaker(clk)
    const sid = "s_reset_cd"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    b.tryPass(sid)
    b.record(sid, true) // -> OPEN, openedAt = now (12_300_001)
    clk.advance(300_000) // to 12_600_001
    assert.equal(b.tryPass(sid), false, "after reset exactly 5min must allow again")
    assert.equal(b.getState(sid), "HALF_OPEN")
  })

  it("record after cooldown without prior tryPass also drives HALF_OPEN->CLOSED/OPEN", () => {
    const clk = fakeClock(13_000_000)
    const b = requireBreaker(clk)
    const sid = "s_record_drives"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    // no tryPass, direct record false -> should go HALF_OPEN then CLOSED
    const s = b.record(sid, false)
    assert.equal(s, "CLOSED")
  })
})

// ---------------------------------------------------------------------------
// 6. tryPass blocks only OPEN or second HALF_OPEN call
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — tryPass blocks only OPEN or second HALF_OPEN call", () => {
  it("CLOSED: tryPass never blocks (multiple calls)", () => {
    const b = requireBreaker()
    const sid = "s_try_closed"
    b.record(sid, true) // 1 error still closed
    assert.equal(b.tryPass(sid), false)
    assert.equal(b.tryPass(sid), false)
    assert.equal(b.tryPass(sid), false)
    assert.equal(b.getState(sid), "CLOSED", "repeated tryPass must not change CLOSED")
  })

  it("OPEN: tryPass blocks (true)", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_try_open"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    assert.equal(b.tryPass(sid), true)
    assert.equal(b.tryPass(sid), true, "second OPEN tryPass must still block")
    assert.equal(b.getState(sid), "OPEN")
  })

  it("HALF_OPEN first tryPass allows (false), second blocks (true)", () => {
    const clk = fakeClock(20_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_try"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    assert.equal(b.tryPass(sid), false, "first HALF_OPEN call must be allowed")
    assert.equal(b.getState(sid), "HALF_OPEN", "first call must stay HALF_OPEN")
    assert.equal(b.tryPass(sid), true, "second HALF_OPEN call must be blocked")
    assert.equal(b.tryPass(sid), true, "third HALF_OPEN call must also be blocked")
    assert.equal(b.getState(sid), "HALF_OPEN")
  })

  it("HALF_OPEN second call blocked, but after record success window resets and tryPass allows again", () => {
    const clk = fakeClock(21_000_000)
    const b = requireBreaker(clk)
    const sid = "s_half_block_then_recover"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    b.tryPass(sid) // first allows
    assert.equal(b.tryPass(sid), true, "second must block")
    // Now the test call actually executes and succeeds
    const s = b.record(sid, false)
    assert.equal(s, "CLOSED")
    assert.equal(b.tryPass(sid), false, "after CLOSED recovered must allow")
  })

  it("OPEN tryPass after cooldown allows exactly one then blocks again until record", () => {
    const clk = fakeClock(22_000_000)
    const b = requireBreaker(clk)
    const sid = "s_one_shot"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(300_001)
    assert.equal(b.tryPass(sid), false)
    assert.equal(b.tryPass(sid), true)
    // record failure -> back to OPEN then tryPass must still block before next cooldown
    b.record(sid, true)
    assert.equal(b.getState(sid), "OPEN")
    assert.equal(b.tryPass(sid), true)
  })
})

// ---------------------------------------------------------------------------
// 7. record transitions (comprehensive)
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — record transitions", () => {
  it("record true/false appends to window and shifts at >5", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_window_shift"
    // Fill 5 with mixed
    b.record(sid, false)
    b.record(sid, false)
    b.record(sid, false)
    b.record(sid, false)
    b.record(sid, false)
    assert.equal(b.getState(sid), "CLOSED")
    // Next 3 errors should trip (last 5 = F,F,T,T,T? wait we shifted)
    // Window after 5 Fs, then T -> [F,F,F,F,T] 1 err
    b.record(sid, true)  // [F,F,F,T]?? Actually after 5Fs, push T shift => [F,F,F,F,T]
    assert.equal(b.getState(sid), "CLOSED")
    b.record(sid, true)  // [F,F,F,T,T] 2 errs
    assert.equal(b.getState(sid), "CLOSED")
    b.record(sid, true)  // [F,F,T,T,T] 3 errs -> OPEN
    assert.equal(b.getState(sid), "OPEN")
  })

  it("record while OPEN before cooldown stays OPEN (no state change)", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    const sid = "s_rec_open"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    clk.advance(60_000)
    assert.equal(b.record(sid, true), "OPEN")
    assert.equal(b.record(sid, false), "OPEN", "even success while OPEN before cooldown must stay OPEN (circuit blocks recording)")
    assert.equal(b.getState(sid), "OPEN")
  })

  it("per-session isolation: record on A does not affect B", () => {
    const clk = fakeClock()
    const b = requireBreaker(clk)
    b.record("sess_A", true); b.record("sess_A", true); b.record("sess_A", true)
    assert.equal(b.getState("sess_A"), "OPEN")
    assert.equal(b.getState("sess_B"), "CLOSED", "other session must be CLOSED")
    assert.equal(b.tryPass("sess_B"), false, "other session tryPass must not block")
    b.record("sess_B", true)
    assert.equal(b.getState("sess_B"), "CLOSED", "1 error on B must stay CLOSED")
    assert.equal(b.getState("sess_A"), "OPEN", "A must remain OPEN")
  })

  it("never throws for any transition (fail-soft fortress)", () => {
    const b = requireBreaker()
    assert.doesNotThrow(() => b.record("s_never_throw", true))
    assert.doesNotThrow(() => b.record("s_never_throw", false))
    assert.doesNotThrow(() => b.tryPass("s_never_throw"))
    assert.doesNotThrow(() => b.getState("s_never_throw"))
    // Also with clock
    const clk = fakeClock()
    const b2 = requireBreaker(clk)
    assert.doesNotThrow(() => b2.record("x", true))
    assert.doesNotThrow(() => b2.tryPass("x"))
  })
})

// ---------------------------------------------------------------------------
// 8. Inject clock fakes (DI)
// ---------------------------------------------------------------------------
describe("lib/circuit-breaker — clock injection", () => {
  it("accepts injected clock via deps ({ now }) and respects it for cooldown", () => {
    const clk = fakeClock(100_000)
    const b = requireBreaker(clk)
    const sid = "s_injected_clk"
    b.record(sid, true); b.record(sid, true); b.record(sid, true)
    assert.equal(b.getState(sid), "OPEN")
    // Without advancing fake clock, still OPEN
    assert.equal(b.tryPass(sid), true)
    clk.advance(300_001)
    assert.equal(b.tryPass(sid), false, "injected clock advance must trigger HALF_OPEN")
  })

  it("two breakers with independent clocks have independent cooldowns", () => {
    const clk1 = fakeClock(500_000)
    const clk2 = fakeClock(500_000)
    const b1 = requireBreaker(clk1)
    const b2 = requireBreaker(clk2)
    const sid = "s_independent"
    b1.record(sid, true); b1.record(sid, true); b1.record(sid, true)
    b2.record(sid, true); b2.record(sid, true); b2.record(sid, true)
    clk1.advance(300_001)
    // clk2 not advanced
    assert.equal(b1.tryPass(sid), false, "b1 with advanced clock must be HALF_OPEN")
    assert.equal(b2.tryPass(sid), true, "b2 with same start but not advanced must still be OPEN")
  })

  it("works without injected clock (falls back to real Date.now) — no throw", () => {
    const b = requireBreaker() // no clock
    const sid = "s_real_clock_" + Math.random()
    assert.doesNotThrow(() => {
      b.record(sid, true)
      b.tryPass(sid)
      b.getState(sid)
    })
  })

  it("clock injection does not leak between sessions — per-entry openedAt uses injected now at trip time", () => {
    const clk = fakeClock(1_000_000)
    const b = requireBreaker(clk)
    b.record("sess_1", true); b.record("sess_1", true); b.record("sess_1", true) // openedAt 1_000_000
    clk.advance(100_000) // now 1_100_000
    b.record("sess_2", true); b.record("sess_2", true); b.record("sess_2", true) // openedAt 1_100_000
    clk.advance(250_000) // now 1_350_000
    // sess_1 has had 350s -> HALF_OPEN, sess_2 has had 250s -> still OPEN
    assert.equal(b.tryPass("sess_1"), false, "sess_1 cooldown elapsed (350s)")
    assert.equal(b.tryPass("sess_2"), true, "sess_2 cooldown not yet elapsed (250s)")
  })
})
