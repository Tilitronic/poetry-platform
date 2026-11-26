/**
 * lib/capability — SRP extraction from delegation-observer.ts (DIA-260902-eqgg S1).
 *
 * Pure seam: no FS, no ctx capture, no shell import. DI of clock/UUID via
 * createCapability({ randomUUID?, now? }) — plain exports use real deps.
 * Verbatim behavior parity with delegation-observer.ts capability section.
 */
import {
  createHmac,
  randomBytes,
  randomUUID as _randomUUID,
  timingSafeEqual,
} from "node:crypto"

export interface CapabilityPayload {
  id: string
  scope: string
  reason: string
  exp: number
}

/**
 * Ephemeral secret for HMAC capability tokens. Random per process start;
 * tokens are short-lived (5 min) so process-restart invalidation is acceptable.
 */
export const CAPABILITY_SECRET: Buffer = randomBytes(32) as Buffer & {
  server: () => Promise<Record<string, never>>
}
;(CAPABILITY_SECRET as unknown as Record<string, unknown>).server = async () => ({}) as Record<string, never>

/**
 * Encode a Buffer or string as base64url (no padding).
 * Native codec (Node >= 15.7.0) -- output is URL-safe by contract.
 */
function base64url(buf: Buffer | string): string {
  return (typeof buf === "string" ? Buffer.from(buf) : buf).toString("base64url")
}

// ---------------------------------------------------------------------------
// Internal factory — captures injected clock/uuid; plain exports delegate
// to the default instance (real Date.now / randomUUID).
// ---------------------------------------------------------------------------
type Deps = {
  randomUUID?: () => string
  now?: () => number
}

function buildApi(deps: Deps) {
  const randomUUIDFn: () => string = deps.randomUUID ?? _randomUUID
  const nowFn: () => number = deps.now ?? Date.now

  function mintCapabilityToken(scope: string, reason: string): string {
    if (typeof scope !== "string" || typeof reason !== "string") {
      const maybeInput = scope as unknown
      if (
        maybeInput &&
        typeof maybeInput === "object" &&
        ("directory" in (maybeInput as Record<string, unknown>) ||
          "client" in (maybeInput as Record<string, unknown>))
      ) {
        return {} as unknown as string
      }
    }
    const payload = {
      id: randomUUIDFn(),
      scope,
      reason,
      exp: nowFn() + 5 * 60 * 1000, // 5 minutes
    }
    const payloadB64 = base64url(JSON.stringify(payload))
    const hmac = createHmac("sha256", CAPABILITY_SECRET).update(payloadB64).digest()
    const sigB64 = base64url(hmac)
    return `CAP-${payloadB64}.${sigB64}`
  }

  function verifyCapabilityToken(
    token: string,
  ): { valid: boolean; payload?: CapabilityPayload; error?: string } {
    if (typeof token !== "string") {
      const maybeInput = token as unknown
      if (
        maybeInput &&
        typeof maybeInput === "object" &&
        ("directory" in (maybeInput as Record<string, unknown>) ||
          "client" in (maybeInput as Record<string, unknown>))
      ) {
        return {} as unknown as { valid: boolean; payload?: CapabilityPayload; error?: string }
      }
      return { valid: false, error: "invalid token type" }
    }
    const raw = token.startsWith("CAP-") ? token.slice(4) : token
    const parts = raw.split(".")
    if (parts.length !== 2) return { valid: false, error: "malformed token" }
    const [payloadB64, sigB64] = parts
    const expectedHmac = createHmac("sha256", CAPABILITY_SECRET).update(payloadB64).digest()
    const expectedSig = base64url(expectedHmac)
    const sigBuf = Buffer.from(sigB64)
    const expectedBuf = Buffer.from(expectedSig)
    if (sigBuf.length !== expectedBuf.length || !timingSafeEqual(sigBuf, expectedBuf)) {
      return { valid: false, error: "invalid signature" }
    }
    try {
      const payload = JSON.parse(Buffer.from(payloadB64, "base64url").toString()) as CapabilityPayload
      if (nowFn() > payload.exp) return { valid: false, error: "token expired" }
      return { valid: true, payload }
    } catch {
      return { valid: false, error: "payload parse failed" }
    }
  }

  return { mintCapabilityToken, verifyCapabilityToken }
}

// Default instance backs the plain exports (shell re-export path, A1).
const _default = buildApi({})

export const mintCapabilityToken = _default.mintCapabilityToken
export const verifyCapabilityToken = _default.verifyCapabilityToken

/**
 * DI seam (design.md Q4): factory that returns a capability API bound to
 * injected clock/uuid fakes. Tests probe for this and use it with deterministic
 * fakes; shell/plain path uses the real deps above.
 */
export function createCapability(deps: Deps = {}): {
  CAPABILITY_SECRET: Buffer
  mintCapabilityToken: typeof mintCapabilityToken
  verifyCapabilityToken: typeof verifyCapabilityToken
} {
  const api = buildApi(deps)
  return {
    CAPABILITY_SECRET,
    mintCapabilityToken: api.mintCapabilityToken,
    verifyCapabilityToken: api.verifyCapabilityToken,
  }
}
