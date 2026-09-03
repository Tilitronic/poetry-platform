import { mkdirSync, mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

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
