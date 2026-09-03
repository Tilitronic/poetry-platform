 
/**
 * RED test-author lane for Slice 1 — lib/capability.ts (DIA-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts (CAPABILITY_SECRET,
 * base64url, CapabilityPayload, mintCapabilityToken, verifyCapabilityToken,
 * CAP- prefix, timingSafeEqual, 5-min expiry, per-process randomBytes(32)).
 *
 * ASSUMED LIB SIGNATURE (task dispatch says note this so GREEN implementer matches):
 *   .opencode/plugins/lib/capability.ts  (pure, no FS)
 *     export const CAPABILITY_SECRET: Buffer  // Buffer, .server guard attached
 *     export function mintCapabilityToken(scope: string, reason: string): string
 *       -> "CAP-{payloadB64}.{sigB64}" where payloadB64 = base64url(JSON {id, scope, reason, exp})
 *          sigB64 = base64url(HMAC-SHA256(CAPABILITY_SECRET, payloadB64))
 *          exp = Date.now() + 5*60*1000, id = randomUUID()
 *          Loader guard: if called as plugin factory (PluginInput object with directory/client) -> return {} as Hooks
 *     export function verifyCapabilityToken(token: string): { valid: boolean; payload?: CapabilityPayload; error?: string }
 *       -> strip "CAP-" prefix, split ".", HMAC verify via timingSafeEqual, JSON parse, expiry check
 *          errors: "invalid token type" | "malformed token" | "invalid signature" | "payload parse failed" | "token expired"
 *          Loader guard: if called with PluginInput object -> return {} as Hooks, never throw "token.startsWith is not a function"
 *
 * DI seam (design.md Q4): lib is pure/DI'd. GREEN may expose a factory like
 *   createCapability({ randomUUID?, now? }) or accept injected deps via optional params.
 * These tests handle BOTH shapes:
 *   - if lib exports a factory/default factory (createCapability / create / default), they use it with fakes
 *   - otherwise they fall back to the plain exported functions and monkey-patch Date.now/randomUUID where needed
 * Either way the contract above must hold for the plain-export path (A1 shell re-export).
 *
 * Wy loader guard: CAPABILITY_SECRET must carry a `.server` async function property so
 *   the legacy Bun loader (Wy) treats the Buffer export as a plugin object and does not throw
 *   "Plugin export is not a function".
 *
 * RUN (inside poetry-dev container, like other plugin tests):
 *   bun test .opencode/plugins/__tests__/capability.test.mjs
 *   node --test .opencode/plugins/__tests__/capability.test.mjs
 *
 * EXPECTED RED: all tests FAIL against the S0 stub (export {}) because
 * mintCapabilityToken/verifyCapabilityToken/CAPABILITY_SECRET are undefined.
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { createHmac, randomBytes } from "node:crypto"

// ---------------------------------------------------------------------------
// Import the lib under test (stub in RED phase).
// We use a dynamic import so the failure mode is observable as undefined
// exports rather than a static-import hard error against the stub.
// ---------------------------------------------------------------------------
let capMod = {}
try {
  capMod = await import("../lib/capability.ts")
} catch (e) {
  void e
}

// Helpers to resolve DI seam if GREEN exposes a factory.
function resolveCapabilityAPI(mod) {
  const factory = mod.createCapability
  if (typeof factory === "function") {
    try {
      const probe = factory({ randomUUID: () => "probe-id-"+String(Date.now()), now: () => Date.now() })
      if (probe && typeof probe.mintCapabilityToken === "function") {
        return { api: probe, isFactory: true }
      }
    } catch {
      // probe failed — fall through to plain exports
    }
  }
  return { api: mod, isFactory: false }
}

const { api: cap } = resolveCapabilityAPI(capMod)

// Local base64url helper (mirrors the lib's impl) for constructing
// cross-secret tokens and malformed fixtures.
function b64url(buf) {
  const b = typeof buf === "string" ? Buffer.from(buf) : buf
  return b.toString("base64url")
}

// ---------------------------------------------------------------------------
// 1. mintCapabilityToken produces CAP-{payloadB64}.{sigB64} format
// ---------------------------------------------------------------------------
describe("lib/capability — mintCapabilityToken format", () => {
  it("exists and is a function", () => {
    assert.equal(typeof cap.mintCapabilityToken, "function", "mintCapabilityToken must be exported as function")
  })

  it("produces CAP- prefix and exactly one dot after prefix", () => {
    const token = cap.mintCapabilityToken("ticket-creation", "test")
    assert.ok(typeof token === "string", "token must be string")
    assert.ok(token.startsWith("CAP-"), `token must start with CAP-, got ${token.slice(0, 20)}`)
    const raw = token.slice(4)
    const parts = raw.split(".")
    assert.equal(parts.length, 2, `token after CAP- must have exactly 2 parts separated by '.', got ${parts.length}: ${token}`)
    assert.ok(parts[0].length > 0, "payload part must be non-empty")
    assert.ok(parts[1].length > 0, "signature part must be non-empty")
  })

  it("payload and signature parts are base64url (no +, /, =)", () => {
    const token = cap.mintCapabilityToken("ticket-creation", "base64url check")
    const [payloadB64, sigB64] = token.slice(4).split(".")
    for (const part of [payloadB64, sigB64]) {
      assert.ok(!part.includes("+"), `base64url must not contain '+': ${part}`)
      assert.ok(!part.includes("/"), `base64url must not contain '/': ${part}`)
      assert.ok(!part.includes("="), `base64url must not contain '=': ${part}`)
    }
  })

  it("payload decodes to JSON with id, scope, reason, exp (exp ~5 min in future)", () => {
    const before = Date.now()
    const token = cap.mintCapabilityToken("bootstrap", "reason-xyz")
    const after = Date.now()
    const [payloadB64] = token.slice(4).split(".")
    const payload = JSON.parse(Buffer.from(payloadB64, "base64url").toString())
    assert.equal(typeof payload.id, "string", "payload.id must be string")
    assert.equal(payload.scope, "bootstrap")
    assert.equal(payload.reason, "reason-xyz")
    assert.equal(typeof payload.exp, "number")
    // exp should be ~5 min after mint time, allow 2s clock skew + 1s execution window
    const fiveMin = 5 * 60 * 1000
    assert.ok(payload.exp >= before + fiveMin - 2000, `exp too early: ${payload.exp} vs ${before}+${fiveMin}`)
    assert.ok(payload.exp <= after + fiveMin + 2000, `exp too late: ${payload.exp} vs ${after}+${fiveMin}`)
  })

  it("uses injected Date.now / randomUUID when DI seam is present", async () => {
    // If the lib exposes a factory with DI, verify fake clock/uuid are honored.
    // If it only exposes plain functions, this test is vacuous — we still
    // assert the format requirement via monkey-patched Date.now below.
    const hasFactory = typeof capMod.createCapability === "function" || typeof capMod.create === "function"
    if (!hasFactory) {
      // Fallback behavioral check: mint twice should yield different ids (randomUUID)
      const t1 = cap.mintCapabilityToken("ticket-creation", "di-check")
      const t2 = cap.mintCapabilityToken("ticket-creation", "di-check")
      const p1 = JSON.parse(Buffer.from(t1.slice(4).split(".")[0], "base64url").toString())
      const p2 = JSON.parse(Buffer.from(t2.slice(4).split(".")[0], "base64url").toString())
      assert.notEqual(p1.id, p2.id, "two mints must have different ids (randomUUID)")
      return
    }
    // Factory path: inject deterministic fakes
    const fakeNow = 1_700_000_000_000
    const fakeId = "test-uuid-1234"
    const factory = capMod.createCapability ?? capMod.create
    const injected = factory({ randomUUID: () => fakeId, now: () => fakeNow })
    const token = injected.mintCapabilityToken("ticket-creation", "injected")
    const [payloadB64] = token.slice(4).split(".")
    const payload = JSON.parse(Buffer.from(payloadB64, "base64url").toString())
    assert.equal(payload.id, fakeId, "injected randomUUID must be used")
    assert.equal(payload.exp, fakeNow + 5 * 60 * 1000, "injected now must determine exp")
  })
})

// ---------------------------------------------------------------------------
// 2. verifyCapabilityToken
// ---------------------------------------------------------------------------
describe("lib/capability — verifyCapabilityToken", () => {
  it("exists and is a function", () => {
    assert.equal(typeof cap.verifyCapabilityToken, "function", "verifyCapabilityToken must be exported as function")
  })

  it("valid token -> {valid:true, payload}", () => {
    const token = cap.mintCapabilityToken("ticket-creation", "verify-valid")
    const result = cap.verifyCapabilityToken(token)
    assert.equal(result.valid, true, `expected valid:true, got ${JSON.stringify(result)}`)
    assert.ok(result.payload, "payload must be present on valid")
    assert.equal(result.payload.scope, "ticket-creation")
    assert.equal(result.payload.reason, "verify-valid")
    assert.equal(typeof result.payload.id, "string")
    assert.equal(typeof result.payload.exp, "number")
    assert.equal(result.error, undefined)
  })

  it("invalid signature -> {valid:false, error:'invalid signature'}", () => {
    const token = cap.mintCapabilityToken("ticket-creation", "tamper-sig")
    const dotIdx = token.indexOf(".")
    const sigPart = token.slice(dotIdx + 1)
    // Flip first char of sig to guarantee mismatch but keep length equal
    const flipped = (sigPart[0] === "A" ? "B" : "A") + sigPart.slice(1)
    const tampered = token.slice(0, dotIdx + 1) + flipped
    const result = cap.verifyCapabilityToken(tampered)
    assert.equal(result.valid, false)
    assert.match(result.error ?? "", /invalid signature/i, `expected invalid signature, got ${result.error}`)
  })

  it("malformed token — no dot / no CAP- prefix handling / wrong parts count", () => {
    // No dot (single part after CAP-)
    const r1 = cap.verifyCapabilityToken("CAP-notavalidtoken")
    assert.equal(r1.valid, false, "single part must be invalid")
    assert.match(r1.error ?? "", /malformed/i, `expected malformed, got ${r1.error}`)

    // Empty string
    const r2 = cap.verifyCapabilityToken("")
    assert.equal(r2.valid, false)
    assert.match(r2.error ?? "", /malformed/i)

    // Three parts
    const r3 = cap.verifyCapabilityToken("CAP-part1.part2.part3")
    assert.equal(r3.valid, false)
    assert.match(r3.error ?? "", /malformed/i)
  })

  it("malformed token — bad base64 still yields valid:false (invalid signature or malformed or payload parse failed)", () => {
    const bad = cap.verifyCapabilityToken("CAP-!!!.???")
    assert.equal(bad.valid, false, "bad base64 must be invalid")
    assert.ok(typeof bad.error === "string" && bad.error.length > 0, "error must be present")
  })

  it("payload parse failure -> {valid:false, error:'payload parse failed'}", () => {
    // Build a payload that is not JSON, but sign it with the real secret so
    // signature passes and the JSON parse is the failure point.
    const secret = cap.CAPABILITY_SECRET ?? capMod.CAPABILITY_SECRET
    assert.ok(secret, "CAPABILITY_SECRET must be exported for this test")
    const notJsonB64 = b64url("not json at all {{{")
    const sig = b64url(createHmac("sha256", secret).update(notJsonB64).digest())
    const token = `CAP-${notJsonB64}.${sig}`
    const result = cap.verifyCapabilityToken(token)
    assert.equal(result.valid, false)
    assert.match(result.error ?? "", /payload parse failed/i, `expected payload parse failed, got ${result.error}`)
  })

  it("expired token rejected -> {valid:false, error:'token expired'}", () => {
    const secret = cap.CAPABILITY_SECRET ?? capMod.CAPABILITY_SECRET
    assert.ok(secret, "CAPABILITY_SECRET must be exported")
    const payload = {
      id: "test-exp-id",
      scope: "ticket-creation",
      reason: "expired",
      exp: Date.now() - 1000, // 1s ago
    }
    const payloadB64 = b64url(JSON.stringify(payload))
    const sig = b64url(createHmac("sha256", secret).update(payloadB64).digest())
    const token = `CAP-${payloadB64}.${sig}`
    const result = cap.verifyCapabilityToken(token)
    assert.equal(result.valid, false)
    assert.match(result.error ?? "", /token expired/i, `expected token expired, got ${result.error}`)
  })

  it("loader guard: verifyCapabilityToken called with PluginInput object must not throw token.startsWith", () => {
    // Simulate legacy Wy loader: Object.values(mod) includes verifyCapabilityToken, called with PluginInput
    const fakeCtx = { directory: "/tmp/fake", client: { app: { log: async () => {} } } }
    let threw = null
    let result
    try {
      result = cap.verifyCapabilityToken(fakeCtx)
    } catch (e) {
      threw = e
    }
    if (threw) {
      assert.fail(`verifyCapabilityToken threw when called with PluginInput: ${threw.message} — must have loader guard`)
    }
    assert.ok(result && typeof result === "object", "loader-guarded call must return object, not throw")
    assert.ok(!String(result).includes("token.startsWith"), "must not contain token.startsWith")
  })

  it("loader guard: mintCapabilityToken called with PluginInput must not throw", () => {
    const fakeCtx = { directory: "/tmp/fake", client: { app: { log: async () => {} } } }
    let threw = null
    try {
      const r = cap.mintCapabilityToken(fakeCtx)
      assert.ok(r !== undefined, "mint guard must return something (Hooks object)")
    } catch (e) {
      threw = e
    }
    if (threw) {
      assert.fail(`mintCapabilityToken threw when called as factory: ${threw.message}`)
    }
  })
})

// ---------------------------------------------------------------------------
// 3. CAPABILITY_SECRET per-process restart invalidation
// ---------------------------------------------------------------------------
describe("lib/capability — CAPABILITY_SECRET per-process invalidation", () => {
  it("CAPABILITY_SECRET exists, is a Buffer of 32 bytes", () => {
    const secret = cap.CAPABILITY_SECRET ?? capMod.CAPABILITY_SECRET
    assert.ok(secret, "CAPABILITY_SECRET must be exported")
    assert.ok(Buffer.isBuffer(secret), `CAPABILITY_SECRET must be Buffer, got ${typeof secret}`)
    assert.equal(secret.length, 32, `CAPABILITY_SECRET must be 32 bytes, got ${secret.length}`)
  })

  it("old token minted with a different secret -> invalid signature", () => {
    const currentSecret = cap.CAPABILITY_SECRET ?? capMod.CAPABILITY_SECRET
    assert.ok(currentSecret, "CAPABILITY_SECRET must be exported")
    // Forge a token with a DIFFERENT random secret (simulates pre-restart token)
    const otherSecret = randomBytes(32)
    // Ensure it's different (extremely likely)
    if (otherSecret.equals(currentSecret)) otherSecret[0] ^= 0xff
    const payload = {
      id: "cross-process-id",
      scope: "ticket-creation",
      reason: "restart-invalidation",
      exp: Date.now() + 5 * 60 * 1000,
    }
    const payloadB64 = b64url(JSON.stringify(payload))
    const sigOther = b64url(createHmac("sha256", otherSecret).update(payloadB64).digest())
    const oldToken = `CAP-${payloadB64}.${sigOther}`
    const result = cap.verifyCapabilityToken(oldToken)
    assert.equal(result.valid, false, "token signed with different secret must be invalid")
    assert.match(result.error ?? "", /invalid signature/i, `expected invalid signature, got ${result.error}`)
  })
})

// ---------------------------------------------------------------------------
// 4. .server guard present on CAPABILITY_SECRET export (Wy loader compat)
// ---------------------------------------------------------------------------
describe("lib/capability — Wy .server guard", () => {
  it("CAPABILITY_SECRET has .server async function property", async () => {
    const secret = cap.CAPABILITY_SECRET ?? capMod.CAPABILITY_SECRET
    assert.ok(secret, "CAPABILITY_SECRET must be exported")
    assert.ok(secret && typeof secret === "object", "CAPABILITY_SECRET must be object (Buffer)")
    const maybeServer = secret.server
    assert.equal(typeof maybeServer, "function", "CAPABILITY_SECRET.server must be a function (Wy guard)")
    // Must be callable and return something awaitable (the monolith uses async () => ({}))
    const ret = maybeServer({})
    assert.ok(ret !== undefined, ".server must return something")
    // If it returns a promise, await it
    if (ret && typeof ret.then === "function") {
      const awaited = await ret
      assert.ok(awaited !== undefined, ".server promise must resolve")
    }
  })

  it("every non-function export in the capability module is Wy-compatible (function or {server:function})", () => {
    // This mirrors plugin-load-smoke.test.mjs's Wy check but scoped to capability lib.
    function isFn(v) { return typeof v === "function" }
    function gy(v) {
      if (isFn(v)) return v
      if (!v || typeof v !== "object" || !("server" in v)) return undefined
      if (!isFn(v.server)) return undefined
      return v.server
    }
    const bad = []
    for (const [k, v] of Object.entries(capMod)) {
      if (k === "default") continue
      if (!gy(v)) bad.push(k)
    }
    assert.equal(bad.length, 0, `all capability exports must be Wy-compatible, bad: ${bad.join(", ")} — CAPABILITY_SECRET needs .server guard`)
  })
})

// ---------------------------------------------------------------------------
// 5. timingSafeEqual used for signature comparison (behavioral)
// ---------------------------------------------------------------------------
describe("lib/capability — timingSafeEqual usage", () => {
  it("verify uses timingSafeEqual (spy: constant-time compare called)", async () => {
    // Behavioral spy: if the lib imports timingSafeEqual from node:crypto,
    // ESM live bindings are read-only so direct patch may throw. We attempt
    // patch via Object.defineProperty fallback; if that also fails we fall
    // back to pure behavioral assertion (tampered same-length sig -> invalid signature).
    // Either way RED stub shows cap.mintCapabilityToken is not a function.
    const cryptoNs = await import("node:crypto")
    const original = cryptoNs.timingSafeEqual
    let called = 0
    let calledWithBuffers = false
    let patched = false
    try {
      try {
        cryptoNs.timingSafeEqual = function patchedFn(a, b) {
          called++
          if (Buffer.isBuffer(a) && Buffer.isBuffer(b)) calledWithBuffers = true
          return original(a, b)
        }
        patched = true
      } catch {
        try {
          Object.defineProperty(cryptoNs, "timingSafeEqual", {
            value: function patchedFn2(a, b) {
              called++
              if (Buffer.isBuffer(a) && Buffer.isBuffer(b)) calledWithBuffers = true
              return original(a, b)
            },
            writable: true,
            configurable: true,
          })
          patched = true
        } catch {
          patched = false
        }
      }
      const token = cap.mintCapabilityToken("ticket-creation", "timingSafeEqual-spy")
      const dotIdx = token.indexOf(".")
      const sigPart = token.slice(dotIdx + 1)
      const flipped = (sigPart[0] === "A" ? "B" : "A") + sigPart.slice(1)
      const tampered = token.slice(0, dotIdx + 1) + flipped
      const result = cap.verifyCapabilityToken(tampered)
      assert.equal(result.valid, false, "tampered token must still be rejected even with spy")
      if (patched && called > 0) {
        assert.ok(calledWithBuffers, "timingSafeEqual must be called with Buffers")
      } else {
        assert.equal(result.error, "invalid signature", "tampered same-length sig must be invalid signature (constant-time path)")
      }
    } finally {
      try {
        cryptoNs.timingSafeEqual = original
      } catch {
        try { Object.defineProperty(cryptoNs, "timingSafeEqual", { value: original, writable: true, configurable: true }) } catch { /* ignore */ }
      }
    }
  })

  it("tampered payload with same-length sig is rejected (constant-time path covers payload tamper)", () => {
    const token = cap.mintCapabilityToken("ticket-creation", "payload-tamper-constant-time")
    const dotIdx = token.indexOf(".")
    const payloadB64 = token.slice(4, dotIdx)
    const sigPart = token.slice(dotIdx + 1)
    const payload = JSON.parse(Buffer.from(payloadB64, "base64url").toString())
    payload.scope = "bootstrap"
    const newPayloadB64 = b64url(JSON.stringify(payload))
    const tampered = `CAP-${newPayloadB64}.${sigPart}`
    const result = cap.verifyCapabilityToken(tampered)
    assert.equal(result.valid, false)
    assert.equal(result.error, "invalid signature")
  })
})
