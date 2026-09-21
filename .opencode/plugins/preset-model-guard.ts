/**
 * preset-model-guard - DIA-260918-ok9m slice T2 (GREEN instance B).
 *
 * WHY a separate file: the guard must be independently revertible (one-file
 * delete) without touching delegation-observer's registry/ticket duties (D1).
 * WHY env-only intent: OH_MY_OPENCODE_SLIM_PRESET is the launch-time intent
 * carrier; re-reading the preset block would duplicate OMO merge logic (D3).
 *
 * Scope of this slice (tasks.md 4.1): T2 decision path plus explicit
 * override exemption (info.override model|agent, event or session.get) and
 * the S2 setup shape probe. Version-sync registration and test-config
 * wiring stay out of the guard file.
 */

const ENV_KEY = "OH_MY_OPENCODE_SLIM_PRESET"

// D2: in-process fire-once set (sessions are process-scoped; no disk state).
const fired = new Set<string>()

function parseIntent(raw: string | undefined): { providerID: string; id: string } | undefined {
  if (!raw) return undefined
  const trimmed = raw.trim()
  if (!trimmed) return undefined
  const slash = trimmed.indexOf("/")
  if (slash <= 0 || slash === trimmed.length - 1) return undefined
  const providerID = trimmed.slice(0, slash).trim()
  const id = trimmed.slice(slash + 1).trim()
  if (!providerID || !id) return undefined
  return { providerID, id }
}

function sameModel(
  a: { providerID?: string; id?: string } | undefined,
  b: { providerID: string; id: string } | undefined,
): boolean {
  if (!a || !b) return false
  return a.providerID === b.providerID && a.id === b.id
}

async function logLine(ctx: any, message: string, level = "info"): Promise<void> {
  try {
    await ctx?.client?.app?.log?.({ body: { service: "preset-model-guard", level, message } })
  } catch {
    // Logging never breaks session creation.
  }
}

async function server(ctx: any): Promise<{ event: (input: any) => Promise<void> }> {
  async function event(input: any): Promise<void> {
    try {
      const ev = input?.event
      if (!ev || ev.type !== "session.created") return
      const props = ev.properties ?? {}
      const sessionID: string | undefined = props.sessionID ?? props.info?.id
      if (!sessionID) return

      // Explicit-override exemption: info.override "model" (--model flag) or
      // "agent" (agent-model selection) is never clobbered. The marker rides
      // redundantly at properties.info.override and in session.get(); either
      // read path exempts. Absent marker (T1 fixtures) defaults to act.
      const eventOverride = props.info?.override
      if (eventOverride === "model" || eventOverride === "agent") return
      if (eventOverride == null) {
        try {
          const current = await ctx?.session?.get?.()
          const mirrored = current?.override ?? current?.info?.override
          if (mirrored === "model" || mirrored === "agent") return
        } catch {
          // Fail-open: an unreadable session falls through to the act path.
        }
      }

      const intent = parseIntent(process.env[ENV_KEY])
      if (!intent) {
        // Env absent/empty/unparsable: no-op (unparsable logs one line).
        const raw = process.env[ENV_KEY]
        if (typeof raw === "string" && raw.trim().length > 0) {
          await logLine(ctx, `[preset-model-guard] unparsable preset intent, leaving session ${sessionID} untouched`)
        }
        return
      }

      // Newborn model rides redundantly at properties.info.model and via
      // session.get(); either read path yields the same model.
      let newborn = props.info?.model
      if (!newborn) {
        try {
          const current = await ctx?.session?.get?.()
          newborn = current?.model ?? current?.info?.model
        } catch {
          return
        }
      }
      if (sameModel(newborn, intent)) return
      if (fired.has(sessionID)) return
      // Recorded BEFORE the call so a throwing first attempt still blocks
      // duplicates: no retry by design (spec fail-soft requirement).
      fired.add(sessionID)

      try {
        await ctx?.session?.switchModel?.({ sessionID, model: { providerID: intent.providerID, id: intent.id } })
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err)
        await logLine(ctx, `[preset-model-guard] switchModel failed for ${sessionID}, session continues: ${detail}`, "warn")
      }
    } catch {
      // Fail-soft boundary: the guard never breaks session creation.
    }
  }

  return { event }
}

async function setup(ctx: any): Promise<void> {
  // D4 shape probe (S2): without switchModel on the v2 session surface (v1
  // runtime or shape drift) the guard registers nothing and degrades to a
  // no-op with exactly one log line. A present switchModel needs no action
  // here; the event handler owns the decision path.
  if (typeof ctx?.session?.switchModel !== "function") {
    await logLine(ctx, "[preset-model-guard] v1 runtime or shape drift: session.switchModel absent, guard registers nothing")
  }
}

export default { id: "preset-model-guard", server, setup }
