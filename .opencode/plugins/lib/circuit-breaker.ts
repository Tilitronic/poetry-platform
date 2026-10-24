/**
 * circuit-breaker — tool-level breaker (Slice 7, DIA-260902-eqgg).
 *
 * Moved verbatim from .opencode/plugins/delegation-observer.ts
 * (DIA-218 seam). Pure in-memory, no FS, clock injected for DI.
 */

export const CB_WINDOW_SIZE = 5
export const CB_ERROR_THRESHOLD = 3
export const CB_COOLDOWN_MS = 5 * 60 * 1000 // 5 minutes

export type CircuitState = "CLOSED" | "OPEN" | "HALF_OPEN"

interface CircuitBreakerEntry {
  state: CircuitState
  /** Sliding window of booleans: true = error, false = success. */
  window: boolean[]
  /** Timestamp when the circuit tripped to OPEN (for cooldown). */
  openedAt: number
  /** True when a test call has been allowed in HALF_OPEN (only 1 allowed). */
  testCallMade: boolean
}

type ClockDeps = { now?: () => number } | (() => number) | undefined

function resolveNow(deps: ClockDeps): () => number {
  if (typeof deps === "function") return deps
  if (deps && typeof deps === "object" && typeof deps.now === "function") return deps.now
  return () => Date.now()
}

export class ToolCircuitBreaker {
  /** Per-session circuit state, keyed by session_id. */
  private circuits = new Map<string, CircuitBreakerEntry>()
  private now: () => number

  constructor(deps?: ClockDeps) {
    this.now = resolveNow(deps)
  }

  private getEntry(sessionId: string): CircuitBreakerEntry {
    let entry = this.circuits.get(sessionId)
    if (!entry) {
      entry = { state: "CLOSED", window: [], openedAt: 0, testCallMade: false }
      this.circuits.set(sessionId, entry)
    }
    return entry
  }

  /**
   * Record a tool execution result. Returns the new state.
   * On error: appends true to the window; on success: appends false.
   * Trips to OPEN when CB_ERROR_THRESHOLD errors appear in the last
   * CB_WINDOW_SIZE calls.
   */
  record(sessionId: string, isError: boolean): CircuitState {
    const entry = this.getEntry(sessionId)

    // If currently OPEN, check cooldown.
    if (entry.state === "OPEN") {
      if (this.now() - entry.openedAt >= CB_COOLDOWN_MS) {
        entry.state = "HALF_OPEN"
        entry.testCallMade = false
        // Allow exactly 1 test call -- don't add to window yet.
      } else {
        return entry.state
      }
    }

    // HALF_OPEN: this is the test call. Record result and decide.
    if (entry.state === "HALF_OPEN") {
      entry.testCallMade = false
      if (isError) {
        // Test call failed -> back to OPEN, reset cooldown.
        entry.state = "OPEN"
        entry.openedAt = this.now()
        entry.window.push(true)
        if (entry.window.length > CB_WINDOW_SIZE) entry.window.shift()
      } else {
        // Test call succeeded -> back to CLOSED.
        entry.state = "CLOSED"
        entry.window = []
      }
      return entry.state
    }

    // CLOSED: record and check threshold.
    entry.window.push(isError)
    if (entry.window.length > CB_WINDOW_SIZE) entry.window.shift()

    const errorCount = entry.window.filter(Boolean).length
    if (errorCount >= CB_ERROR_THRESHOLD) {
      entry.state = "OPEN"
      entry.openedAt = this.now()
    }

    return entry.state
  }

  /**
   * Try to pass through the circuit breaker. Returns true if the dispatch
   * should be BLOCKED (circuit is OPEN and not yet in HALF_OPEN test-call
   * slot), false if allowed. Side effect: transitions OPEN -> HALF_OPEN
   * and marks testCallMade so only ONE test call gets through.
   */
  tryPass(sessionId: string): boolean {
    const entry = this.circuits.get(sessionId)
    if (!entry) return false
    // Check cooldown expiry.
    if (entry.state === "OPEN" && this.now() - entry.openedAt >= CB_COOLDOWN_MS) {
      entry.state = "HALF_OPEN"
      entry.testCallMade = false
    }
    // BLOCK if OPEN (cooldown not expired) or if HALF_OPEN test call already used.
    if (entry.state === "OPEN") return true
    if (entry.state === "HALF_OPEN" && entry.testCallMade) return true
    if (entry.state === "HALF_OPEN") {
      entry.testCallMade = true
      return false
    }
    return false
  }

  /** Get the current state of a session's circuit. */
  getState(sessionId: string): CircuitState {
    const entry = this.circuits.get(sessionId)
    return entry?.state ?? "CLOSED"
  }
}

export function createCircuitBreaker(deps?: { now?: () => number } | (() => number)): ToolCircuitBreaker {
  return new ToolCircuitBreaker(deps)
}

// Aliases probed by RED tests — all point to the same factory.
