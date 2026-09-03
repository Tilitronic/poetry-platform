/**
 * Shared error-formatting helpers for the .opencode/plugins/* observers.
 *
 * Consolidation provenance (DIA-260825-oyh): errorMessage and
 * safeJsonStringify previously existed as duplicated copies in
 * delegation-observer.ts and needs-input-observer.ts. The canonical body
 * below is delegation-observer.ts's copy moved VERBATIM (never rewritten);
 * needs-input-observer.ts's copy was a line-for-line mirror of the same
 * DIA-098 fix, so consolidation loses no behavior.
 *
 * Loaded via relative import with explicit .ts extension because OpenCode
 * loads plugins through node --experimental-strip-types as individual files
 * (no bundler, no extensionless resolution). Plugin auto-discovery scans
 * .opencode/plugins/ top-level only (empirically verified via
 * `opencode debug config`, DIA-260825-oyh STEP 1a), so this lib/ submodule
 * is never picked up as a phantom plugin.
 */

/**
 * Best-effort extraction of a human-readable message from an error value.
 *
 * DIA-098 R1: the runtime session.error payload is one of the SDK error
 * shapes (ProviderAuthError / UnknownError / MessageOutputLengthError /
 * MessageAbortedError / ApiError) typed as { name, data: { message } },
 * NOT a JS Error with a top-level .message — so the previous String(err)
 * fallback produced the useless "[object Object]" in every session_failed
 * row (ana016 F2: 52/52 rows). Resolution order: string -> top-level
 * .message -> SDK data.message -> circular-safe JSON dump -> typed fallback
 * that can never be "[object Object]". DIA-098 ai-auditor finding 2: the
 * chain ALWAYS terminates in a string for any non-null error value —
 * safeJsonStringify returning undefined (an undumpable object) falls
 * through to the typed fallback, never to undefined (which would omit the
 * error field). undefined/null input still returns undefined (no error
 * present — the field is legitimately omitted).
 */
export function errorMessage(err: unknown): string | undefined {
  if (err === undefined || err === null) return undefined
  if (typeof err === "string") return err
  if (typeof err === "object") {
    // JS Error / any object carrying a top-level string .message.
    if (
      "message" in err &&
      typeof (err as { message?: unknown }).message === "string"
    ) {
      return (err as { message: string }).message
    }
    // SDK error shapes (ProviderAuthError & co): { name, data: { message } }.
    const data = (err as { data?: unknown }).data
    if (
      typeof data === "object" &&
      data !== null &&
      "message" in data &&
      typeof (data as { message?: unknown }).message === "string"
    ) {
      return (data as { message: string }).message
    }
    // Last-resort structured dump: JSON with a replacer that collapses
    // nested Errors and marks circular refs — never String(obj).
    const dumped = safeJsonStringify(err)
    if (dumped !== undefined) return dumped
    // DIA-098 ai-auditor finding 2: stringify failed (undumpable object) —
    // terminate in the typed fallback, never undefined, never
    // "[object Object]".
    const name = (err as { name?: unknown }).name
    return `[unserializable ${typeof name === "string" && name ? name : "object"}]`
  }
  return `[unserializable ${typeof err}]`
}

/**
 * Circular-safe JSON.stringify for error dumps (DIA-098 R1). Nested Error
 * instances collapse to {name, message, stack}; revisiting an
 * already-serialized object (a cycle or a shared reference) degrades to the
 * literal "[Circular]" marker instead of throwing. Returns undefined on
 * failure so callers can fall back to a typed placeholder.
 */
export function safeJsonStringify(value: unknown): string | undefined {
  const seen = new WeakSet<object>()
  function replacer(_key: string, v: unknown): unknown {
    if (typeof v === "object" && v !== null) {
      if (seen.has(v)) return "[Circular]"
      seen.add(v)
      if (v instanceof Error) {
        return { name: v.name, message: v.message, stack: v.stack }
      }
    }
    if (typeof v === "function") {
      return `[Function ${(v as { name?: string }).name ?? "anonymous"}]`
    }
    return v
  }
  try {
    return JSON.stringify(value, replacer)
  } catch {
    return undefined
  }
}
