import { mkdirSync, mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

let _mock
try {
  _mock = (await import("bun:test")).mock
} catch {
  // bun:test not available (node run) - no-op
}

const registry = new Set()
let exitHandlerRegistered = false

function ensureExitHandler() {
  if (exitHandlerRegistered) return
  exitHandlerRegistered = true
  process.on("exit", () => {
    for (const dir of registry) {
      try {
        rmSync(dir, { recursive: true, force: true })
      } catch {
        // best-effort fail-safe only
      }
    }
  })
}

export function createTempWorkspace(prefix) {
  ensureExitHandler()
  const directory = mkdtempSync(join(tmpdir(), prefix))
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  registry.add(directory)
  function cleanup() {
    registry.delete(directory)
    try {
      rmSync(directory, { recursive: true, force: true })
    } catch {
      // best-effort
    }
  }
  return { directory, cleanup }
}

export function mockOpencodePlugin() {
  if (!_mock?.module) return
  const desc = { describe: () => desc }
  const withOptional = { optional: () => desc }
  const schema = { enum: () => withOptional, string: () => withOptional }
  const toolFn = (def) => def
  toolFn.schema = schema
  _mock.module("@opencode-ai/plugin", () => ({ tool: toolFn }))
}
