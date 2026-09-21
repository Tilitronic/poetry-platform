/**
 * preset-model-guard - DIA-260918-ok9m slice T2 (GREEN instance B, fix-loop recovery).
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
 *
 * Override-exemption limit (rev-1 Critical, verified 2026-09-21 against the
 * vendored .opencode/oh-my-opencode-slim/dist/index.js): a REAL --model or
 * agent-model selection carries NO marker on session.created payloads in
 * OMO 2.2.19 (dist has zero info.override hits; its override hits are
 * config-level agent/prompt/model overrides only). The guard therefore
 * CANNOT exempt real --model sessions: a divergent real---model newborn is
 * switched like any other divergent newborn. The info.override exemption is
 * best-effort SYNTHETIC only (a future runtime or wrapper may set it;
 * session.get mirror likewise), pinned by T3a/T3b. The spec scopes the
 * never-clobber requirement to that synthetic marker.
 */

import { readFileSync } from "node:fs"

const ENV_KEY = "OH_MY_OPENCODE_SLIM_PRESET"

// D2: in-process fire-once set (sessions are process-scoped; no disk state).
// Uncapped by design (rev-1 Major): any cap with eviction would re-arm an
// evicted ID and break the at-most-once-per-ID spec. Entries are short
// session IDs for one process lifetime; no disk state, no registry writes.
const fired = new Set<string>()

// Minimal surfaces the guard touches (finding 4). Structural so both the
// real v2 ctx and the mocked fixture ctx satisfy them. No runtime change.
interface GuardModel {
  providerID?: string
  id?: string
}
interface GuardSession {
  get?: () => Promise<Record<string, unknown>>
  switchModel?: (input: { sessionID: string; model: { providerID: string; id: string } }) => Promise<unknown>
}
interface GuardCtx {
  client?: { app?: { log?: (input: { body: { service: string; level: string; message: string } }) => Promise<unknown> } }
  session?: GuardSession
}
interface CreatedInput {
  event?: { type?: string; properties?: { sessionID?: string; info?: { id?: string; model?: GuardModel; override?: string } } }
}

function splitRef(ref: string): { providerID: string; id: string } | undefined {
  const trimmed = ref.trim()
  if (!trimmed) return undefined
  const slash = trimmed.indexOf("/")
  // FALSIFICATION-2 strict split: exactly one slash, both sides non-empty.
  // Multi-slash (provider/model/extra) is unparsable, never forwarded.
  if (slash <= 0 || slash === trimmed.length - 1) return undefined
  if (trimmed.indexOf("/", slash + 1) !== -1) return undefined
  const providerID = trimmed.slice(0, slash).trim()
  const id = trimmed.slice(slash + 1).trim()
  if (!providerID || !id || providerID.includes("/") || id.includes("/")) return undefined
  return { providerID, id }
}

// Single owner of JSONC comment stripping (rev-1 Major): the guard and the
// T5 setup reader share this export instead of duplicating it. Drops //
// line comments and /* */ blocks outside string literals; the presets file
// carries URLs and prose with slashes inside strings, so a naive regex
// would corrupt values.
export function stripJsoncComments(text: string): string {
  let out = ""
  let i = 0
  let inString = false
  let escaped = false
  while (i < text.length) {
    const ch = text[i]
    const next = text[i + 1]
    if (inString) {
      out += ch
      if (escaped) escaped = false
      else if (ch === "\\") escaped = true
      else if (ch === '"') inString = false
      i += 1
      continue
    }
    if (ch === '"') {
      inString = true
      out += ch
      i += 1
      continue
    }
    if (ch === "/" && next === "/") {
      while (i < text.length && text[i] !== "\n") i += 1
      continue
    }
    if (ch === "/" && next === "*") {
      i += 2
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i += 1
      i += 2
      continue
    }
    out += ch
    i += 1
  }
  return out
}

// Preset-NAME lookup (spec Requirement "Slash-less env resolves as preset
// name", design D3 as amended rev-1): slash-less env resolves via
// presets[<name>].orchestrator.model first array entry, read live at
// runtime so config edits track without a guard change. Any failure
// (missing file, bad JSON, missing preset, unusable ref) returns
// undefined and the caller treats it as unparsable one-log no-op.
async function resolvePresetName(name: string): Promise<{ providerID: string; id: string } | undefined> {
  const key = name.trim()
  if (!key || key.includes("/")) return undefined
  const candidates: Array<URL | string> = []
  try {
    // Primary: alongside the plugin dir (works in both runtimes).
    candidates.push(new URL("../oh-my-opencode-slim.jsonc", import.meta.url))
  } catch {
    // import.meta.url unavailable: fall through to cwd candidates.
  }
  // Fallbacks for test harnesses and odd cwd layouts (each tried in
  // order, failures ignored).
  candidates.push(
    "file:///workspace/.opencode/oh-my-opencode-slim.jsonc",
    ".opencode/oh-my-opencode-slim.jsonc",
    "../oh-my-opencode-slim.jsonc",
    "../../oh-my-opencode-slim.jsonc",
  )
  let text: string | undefined
  for (const cand of candidates) {
    try {
      text = readFileSync(cand, "utf-8")
      break
    } catch {
      text = undefined
    }
  }
  if (text === undefined) return undefined
  try {
    const config = JSON.parse(stripJsoncComments(text)) as {
      presets?: Record<string, { orchestrator?: { model?: string | string[] } }>
    }
    const entry = config?.presets?.[key]?.orchestrator?.model
    const ref = Array.isArray(entry) ? entry[0] : entry
    if (typeof ref !== "string") return undefined
    return splitRef(ref)
  } catch {
    return undefined
  }
}

async function parseIntent(raw: string | undefined): Promise<{ providerID: string; id: string } | undefined> {
  if (!raw) return undefined
  const trimmed = raw.trim()
  if (!trimmed) return undefined
  if (trimmed.includes("/")) return splitRef(trimmed)
  return resolvePresetName(trimmed)
}

function sameModel(
  a: { providerID?: string; id?: string } | undefined,
  b: { providerID: string; id: string } | undefined,
): boolean {
  if (!a || !b) return false
  return a.providerID === b.providerID && a.id === b.id
}

async function logLine(ctx: GuardCtx, message: string, level = "info"): Promise<void> {
  try {
    // Shape verified against OMO 2.2.19 dist appLog (finding 6):
    // ctx.client.app.log({ body: { service, level, message } }).
    await ctx?.client?.app?.log?.({ body: { service: "preset-model-guard", level, message } })
  } catch {
    // Logging never breaks session creation.
  }
}

async function server(ctx: GuardCtx): Promise<{ event: (input: CreatedInput) => Promise<void> }> {
  async function event(input: CreatedInput): Promise<void> {
    try {
      const ev = input?.event
      if (!ev || ev.type !== "session.created") return
      const props = ev.properties ?? {}
      const sessionID: string | undefined = props.sessionID ?? props.info?.id
      if (!sessionID) return

      // Synthetic-override exemption (rev-1 Critical: real --model/agent
      // selections carry no payload marker in OMO 2.2.19, so only this
      // best-effort info.override signal exempts). info.override "model"
      // or "agent" is never clobbered. The marker rides redundantly at
      // properties.info.override and in session.get(); either read path
      // exempts. Absent marker (T1 fixtures) defaults to act.
      const eventOverride = props.info?.override
      if (eventOverride === "model" || eventOverride === "agent") return
      if (eventOverride == null) {
        try {
          const current = await ctx?.session?.get?.()
          const mirrored = (current as { override?: string; info?: { override?: string } } | undefined)?.override
            ?? (current as { info?: { override?: string } } | undefined)?.info?.override
          if (mirrored === "model" || mirrored === "agent") return
        } catch {
          // Fail-open: an unreadable session falls through to the act path.
        }
      }

      const intent = await parseIntent(process.env[ENV_KEY])
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
          newborn = (current as { model?: GuardModel; info?: { model?: GuardModel } } | undefined)?.model
            ?? (current as { info?: { model?: GuardModel } } | undefined)?.info?.model
        } catch {
          return
        }
      }
      if (sameModel(newborn, intent)) return
      if (fired.has(sessionID)) return
      // Event-time shape drift (finding 2): without switchModel on the
      // session surface there is nothing to call. Log exactly one line and
      // return WITHOUT consuming fired, so a later well-formed event for
      // the same session can still act.
      if (typeof ctx?.session?.switchModel !== "function") {
        await logLine(ctx, `[preset-model-guard] shape drift: session.switchModel absent, leaving session ${sessionID} untouched`)
        return
      }
      // Recorded BEFORE the call so a throwing first attempt still blocks
      // duplicates: no retry by design (spec fail-soft requirement).
      // Sync check-then-add with no await between: concurrent dispatches
      // in one tick stay atomic via run-to-completion (T5c). Uncapped Set:
      // every recorded ID stays recorded for the process lifetime.
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

async function setup(ctx: GuardCtx): Promise<void> {
  // D4 shape probe (S2): without switchModel on the v2 session surface (v1
  // runtime or shape drift) the guard registers nothing and degrades to a
  // no-op with exactly one log line. A present switchModel needs no action
  // here; the event handler owns the decision path.
  if (typeof ctx?.session?.switchModel !== "function") {
    await logLine(ctx, "[preset-model-guard] v1 runtime or shape drift: session.switchModel absent, guard registers nothing")
  }
}

export default { id: "preset-model-guard", server, setup }
