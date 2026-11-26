/**
 * permission-ask timeout watchdog - OpenCode plugin (ADR 16:171, campaign
 * DIA-261112-exon / amendment DIA-261126-q9r9).
 *
 * ADR 16 keeps exactly one piece of the V1 needs-input observer: the ask
 * timeout. V2 has no native ask expiry (a pending ask lives until it is
 * replied to), so an unattended ask would hang its session forever.
 *
 * HOST GAP: the installed @opencode-ai/plugin is 1.17.7, whose PluginInput has
 * NO `permission` member - so this plugin is inert there by feature detection
 * (returns {}: no event hook, no timers). The V1 needs-input observer keeps
 * arming ask timeouts until the V2 cutover (Group 4b).
 *
 * Reply contract (docs-build-plugins-server.md:615-621): a pending item carries
 * `id`, the reply call wants `requestID`. `reject` resolves that ask AND every
 * other pending ask of the session (docs-permissions.md:225), so expiry is a
 * session-wide action, never a per-ask reply loop.
 */
import type { Plugin } from "@opencode-ai/plugin"

const DEFAULT_MINUTES = 5

// V2 permission surface, narrowed locally: 1.17.7's PluginInput does not
// declare it, so presence is decided at runtime by the host.
type PermissionApi = {
  list: (args: { sessionID: string }) => Promise<Array<{ id?: string }>>
  reply: (args: { sessionID: string; requestID: string; decision: "reject" }) => Promise<unknown>
}

// Event payloads are read structurally: the installed SDK's `Event` union has
// no `permission.v2.*` members, and the V1/V2 property names differ.
type WatchEvent = { type?: string; properties?: Record<string, unknown> }

function thresholdMs(): number {
  const raw = process.env.PERMISSION_STALL_TIMEOUT_MINUTES
  // Read at ARM time (operator-tunable per session, never cached at load).
  // Unset = 5-minute default; 0, empty, negative or non-numeric = disabled
  // (Number("") is 0; NaN covers the rest).
  if (raw === undefined) return DEFAULT_MINUTES * 60_000
  const minutes = Number(raw)
  return Number.isFinite(minutes) && minutes > 0 ? minutes * 60_000 : 0
}

// The runtime emits dotted names; the plain forms are the same events.
function eventKind(type: unknown): "asked" | "resolved" | "session-deleted" | undefined {
  switch (type) {
    case "permission.asked":
    case "permission.v2.asked":
      return "asked"
    case "permission.replied":
    case "permission.v2.replied":
    case "permission.rejected":
    case "permission.v2.rejected":
      return "resolved"
    case "session.deleted":
      return "session-deleted"
    default:
      return undefined
  }
}

const permissionAskWatchdog: Plugin = async (ctx) => {
  const permission = (ctx as unknown as { permission?: PermissionApi }).permission
  // Feature detection is a conjunction: half the surface is still a V1 host.
  if (typeof permission?.list !== "function" || typeof permission?.reply !== "function") return {}
  const { list, reply } = permission as PermissionApi

  // `${sessionID}:${askID}` -> timer plus the owning session, so session-wide
  // clearing never depends on ":" not appearing inside an id.
  const timers = new Map<string, { sessionID: string; timer: ReturnType<typeof setTimeout> }>()
  // Sessions with an expiry in flight: sibling asks of one session can come
  // due in the same tick, and only the first may reject.
  const settling = new Set<string>()

  function clearAsk(sessionID: string, askID: string): void {
    const key = `${sessionID}:${askID}`
    const entry = timers.get(key)
    if (entry === undefined) return
    clearTimeout(entry.timer)
    timers.delete(key)
  }

  function clearSession(sessionID: string): void {
    for (const [key, entry] of timers) {
      if (entry.sessionID !== sessionID) continue
      clearTimeout(entry.timer)
      timers.delete(key)
    }
  }

  async function expire(sessionID: string, askID: string): Promise<void> {
    clearAsk(sessionID, askID)
    if (settling.has(sessionID)) return
    settling.add(sessionID)
    try {
      const pending = await list({ sessionID })
      const ask = Array.isArray(pending) ? pending.find((entry) => entry?.id === askID) : undefined
      // Gone from the pending list = already answered or rejected.
      if (ask === undefined) return
      await reply({ sessionID, requestID: askID, decision: "reject" })
      // One reject resolves the whole session: sibling timers must stay silent.
      clearSession(sessionID)
    } finally {
      settling.delete(sessionID)
    }
  }

  function arm(sessionID: string, askID: string): void {
    const delayMs = thresholdMs()
    if (delayMs <= 0) return
    const key = `${sessionID}:${askID}`
    if (timers.has(key)) return
    const timer = setTimeout(() => {
      void expire(sessionID, askID).catch((error: unknown) => {
        // Fail-soft: a watchdog must never take the host down on an SDK error.
        console.warn(`[permission-ask-watchdog] expiry failed for ${sessionID}: ${error instanceof Error ? error.message : String(error)}`)
      })
    }, delayMs)
    timers.set(key, { sessionID, timer })
  }

  return {
    event: async ({ event }) => {
      const { type, properties } = event as unknown as WatchEvent
      const sessionID = properties?.sessionID
      if (typeof sessionID !== "string" || !sessionID) return
      switch (eventKind(type)) {
        case "asked": {
          const askID = properties?.id
          if (typeof askID === "string" && askID) arm(sessionID, askID)
          return
        }
        case "resolved": {
          // requestID is the V2 name, permissionID the V1 one; both carry the
          // asked event's id.
          const askID = properties?.requestID ?? properties?.permissionID
          if (typeof askID === "string" && askID) clearAsk(sessionID, askID)
          return
        }
        case "session-deleted":
          clearSession(sessionID)
          return
      }
    },
    dispose: async () => {
      for (const { timer } of timers.values()) clearTimeout(timer)
      timers.clear()
    },
  }
}

export default permissionAskWatchdog
