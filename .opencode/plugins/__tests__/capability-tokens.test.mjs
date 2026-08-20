/**
 * Capability token unit tests (DIA-260820-jlu0 S2).
 *
 * Tests the HMAC capability authorization system: mint/verify round-trip,
 * expiry, tamper detection, malformed tokens, and base64url encoding.
 *
 * The plugin's base64url/mint/verify functions are not exported, so these
 * tests replicate the algorithm to verify the contract. The implementation
 * in delegation-observer.ts must match this spec exactly.
 *
 * RUN (host, no Docker needed):
 *   node --test .opencode/plugins/__tests__/capability-tokens.test.mjs
 *
 * RUN (inside dev container):
 *   bun test .opencode/plugins/__tests__/capability-tokens.test.mjs
 */
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import {
  createHmac,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from "node:crypto"

// -- Replicated from delegation-observer.ts (must stay in sync) ---------------

const CAPABILITY_SECRET = randomBytes(32)

function base64url(buf) {
  const b = typeof buf === "string" ? Buffer.from(buf) : buf
  return b
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")
}

function mintCapabilityToken(scope, reason) {
  const payload = {
    id: randomUUID(),
    scope,
    reason,
    exp: Date.now() + 5 * 60 * 1000,
  }
  const payloadB64 = base64url(JSON.stringify(payload))
  const hmac = createHmac("sha256", CAPABILITY_SECRET)
    .update(payloadB64)
    .digest()
  const sigB64 = base64url(hmac)
  return `CAP-${payloadB64}.${sigB64}`
}

function verifyCapabilityToken(token) {
  // Strip the "CAP-" prefix before splitting: the mint format is
  // "CAP-{payloadB64}.{sigB64}" but HMAC covers only the raw payload bytes.
  const raw = token.startsWith("CAP-") ? token.slice(4) : token
  const parts = raw.split(".")
  if (parts.length !== 2) return { valid: false, error: "malformed token" }
  const [payloadB64, sigB64] = parts
  const expectedHmac = createHmac("sha256", CAPABILITY_SECRET)
    .update(payloadB64)
    .digest()
  const expectedSig = base64url(expectedHmac)
  const sigBuf = Buffer.from(sigB64)
  const expectedBuf = Buffer.from(expectedSig)
  if (
    sigBuf.length !== expectedBuf.length ||
    !timingSafeEqual(sigBuf, expectedBuf)
  ) {
    return { valid: false, error: "invalid signature" }
  }
  try {
    const b64 = payloadB64.replace(/-/g, "+").replace(/_/g, "/")
    const payload = JSON.parse(Buffer.from(b64, "base64").toString())
    if (Date.now() > payload.exp)
      return { valid: false, error: "token expired" }
    return { valid: true, payload }
  } catch {
    return { valid: false, error: "payload parse failed" }
  }
}

// -- Tests --------------------------------------------------------------------

describe("capability tokens", () => {
  it("mint -> verify round-trip (valid token accepted)", () => {
    const token = mintCapabilityToken("ticket-creation", "test reason")
    assert.ok(token.startsWith("CAP-"), "token starts with CAP-")

    const result = verifyCapabilityToken(token)
    assert.equal(result.valid, true)
    assert.ok(result.payload, "payload present")
    assert.equal(result.payload.scope, "ticket-creation")
    assert.equal(result.payload.reason, "test reason")
    assert.equal(typeof result.payload.id, "string")
    assert.equal(typeof result.payload.exp, "number")
    // Token should expire in ~5 minutes (within 4-6 min window)
    const ttl = result.payload.exp - Date.now()
    assert.ok(ttl > 4 * 60 * 1000, "TTL > 4 min")
    assert.ok(ttl < 6 * 60 * 1000, "TTL < 6 min")
  })

  it("expired token rejected", () => {
    // Mint a token with exp in the past by directly constructing it
    const payload = {
      id: randomUUID(),
      scope: "bootstrap",
      reason: "expired",
      exp: Date.now() - 1000, // 1 second ago
    }
    const payloadB64 = base64url(JSON.stringify(payload))
    const hmac = createHmac("sha256", CAPABILITY_SECRET)
      .update(payloadB64)
      .digest()
    const sigB64 = base64url(hmac)
    const token = `CAP-${payloadB64}.${sigB64}`

    const result = verifyCapabilityToken(token)
    assert.equal(result.valid, false)
    assert.equal(result.error, "token expired")
  })

  it("tampered signature rejected", () => {
    const token = mintCapabilityToken("ticket-creation", "tamper test")
    // Flip a character in the signature portion (after CAP-payload.)
    const dotIdx = token.indexOf(".")
    const sigStart = dotIdx + 1
    const sigChars = token.slice(sigStart).split("")
    sigChars[0] = sigChars[0] === "A" ? "B" : "A"
    const tampered = token.slice(0, sigStart) + sigChars.join("")

    const result = verifyCapabilityToken(tampered)
    assert.equal(result.valid, false)
    assert.equal(result.error, "invalid signature")
  })

  it("tampered payload rejected", () => {
    const token = mintCapabilityToken("ticket-creation", "payload tamper")
    // Decode payload, change scope, re-encode, keep original sig
    const dotIdx = token.indexOf(".")
    const payloadB64 = token.slice(4, dotIdx) // strip CAP- prefix
    const sigPart = token.slice(dotIdx + 1)
    const b64 = payloadB64.replace(/-/g, "+").replace(/_/g, "/")
    const payload = JSON.parse(Buffer.from(b64, "base64").toString())
    payload.scope = "ai-infra-application" // tamper
    const newPayloadB64 = base64url(JSON.stringify(payload))
    const tampered = `CAP-${newPayloadB64}.${sigPart}`

    const result = verifyCapabilityToken(tampered)
    assert.equal(result.valid, false)
    assert.equal(result.error, "invalid signature")
  })

  it("malformed token (no dot) rejected", () => {
    const result = verifyCapabilityToken("CAP-notavalidtoken")
    assert.equal(result.valid, false)
    assert.equal(result.error, "malformed token")
  })

  it("malformed token (empty string) rejected", () => {
    const result = verifyCapabilityToken("")
    assert.equal(result.valid, false)
    assert.equal(result.error, "malformed token")
  })

  it("malformed token (three parts) rejected", () => {
    const result = verifyCapabilityToken("CAP-part1.part2.part3")
    assert.equal(result.valid, false)
    assert.equal(result.error, "malformed token")
  })

  it("base64url encoding/decoding round-trips correctly", () => {
    // Test with various byte patterns that exercise +/-/_ characters
    const testCases = [
      Buffer.alloc(0), // empty
      Buffer.from([0xff, 0xfe, 0xfd]), // high bytes
      Buffer.from("hello world"), // ASCII
      randomBytes(64), // random
      randomBytes(256), // larger random
    ]

    for (const original of testCases) {
      const encoded = base64url(original)
      // base64url must not contain +, /, or =
      assert.ok(!encoded.includes("+"), `no + in "${encoded}"`)
      assert.ok(!encoded.includes("/"), `no / in "${encoded}"`)
      assert.ok(!encoded.includes("="), `no = in "${encoded}"`)
      // Decode back and verify round-trip
      const b64 = encoded.replace(/-/g, "+").replace(/_/g, "/")
      const decoded = Buffer.from(b64, "base64")
      assert.ok(decoded.equals(original), "round-trip buffer matches")
    }
  })

  it("base64url string input works (JSON round-trip)", () => {
    const json = JSON.stringify({ scope: "test", exp: 12345 })
    const encoded = base64url(json)
    const b64 = encoded.replace(/-/g, "+").replace(/_/g, "/")
    const decoded = JSON.parse(Buffer.from(b64, "base64").toString())
    assert.equal(decoded.scope, "test")
    assert.equal(decoded.exp, 12345)
  })

  it("all three scopes work", () => {
    for (const scope of [
      "ticket-creation",
      "ai-infra-application",
      "bootstrap",
    ]) {
      const token = mintCapabilityToken(scope, `test ${scope}`)
      const result = verifyCapabilityToken(token)
      assert.equal(result.valid, true, `${scope} should be valid`)
      assert.equal(result.payload.scope, scope)
    }
  })
})
