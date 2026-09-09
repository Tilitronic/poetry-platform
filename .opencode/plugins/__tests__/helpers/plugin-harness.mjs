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

export async function createHarness(directory) {
  const { default: createDelegationObserver } = await import("../../delegation-observer.ts")
  return createDelegationObserver({ directory, client: { app: { log: async () => {} } } })
}

export function mockChildProcess(behavior) {
  if (behavior !== "porcelain" && behavior !== "needs-input") {
    throw new Error(`mockChildProcess: unknown behavior "${behavior}" (expected "porcelain" or "needs-input")`)
  }
  if (!_mock?.module) return { spawnCalls: [], setPorcelain: () => {} }
  const spawnCalls = []
  let porcelainProbeStdout = ""
  const isPorcelain = behavior === "porcelain"
  // Pinned to the production dirty-tree probe shape at
  // delegation-observer.ts:817-819:
  // spawnSync("git", ["-C", wtPath, "status", "--porcelain"], ...).
  // Near-miss arg shapes fall through to success-empty.
  const isPorcelainProbe = (cmd, args) =>
    cmd === "git" &&
    Array.isArray(args) &&
    args.length === 4 &&
    args[0] === "-C" &&
    args[2] === "status" &&
    args[3] === "--porcelain"
  _mock.module("node:child_process", () => ({
    spawn: isPorcelain
      ? () => ({ on: () => {} })
      : (cmd, args, opts) => {
          const listeners = {}
          const call = {
            cmd,
            args,
            opts,
            emitError: (err) => {
              for (const cb of listeners.error ?? []) cb(err)
            },
          }
          spawnCalls.push(call)
          return {
            on: (ev, cb) => {
              ;(listeners[ev] ??= []).push(cb)
            },
          }
        },
    spawnSync: (cmd, args, opts) => {
      if (isPorcelain) {
        spawnCalls.push({ cmd, args, opts })
        if (isPorcelainProbe(cmd, args)) {
          return { status: 0, stdout: porcelainProbeStdout, stderr: "" }
        }
        return { status: 0, stdout: "", stderr: "" }
      }
      throw new Error("spawnSync not mocked")
    },
  }))
  return {
    spawnCalls,
    setPorcelain: (v) => {
      porcelainProbeStdout = v
    },
  }
}
