/**
 * Plugin-load smoke test (DIA-260829-kxqu).
 *
 * Catches the class of failure where the OpenCode legacy loader iterates
 * Object.values(mod) and calls every exported function as plugin factory
 * with PluginInput. A helper exported for testability (verifyCapabilityToken)
 * then receives PluginInput (object) instead of string and throws
 * "token.startsWith is not a function", which aborts the entire module load
 * and disables task, log_decision, ticket gates, and lifecycle observer.
 *
 * This test actually imports the compiled plugin and invokes the factory
 * as the loader does, asserting no throw and that a valid hooks object is
 * returned. It also asserts the helper remains callable with string args
 * and does NOT throw when (mis)called as factory with PluginInput (loader
 * guard).
 *
 * Run (inside poetry-dev, Bun only - node --test hangs on active handles):
 *   bun test .opencode/plugins/__tests__/plugin-load-smoke.test.mjs
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { mkdirSync, mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// Try to mock @opencode-ai/plugin for bun; for node the real module is fine.
// We attempt bun's mock.module if available, otherwise skip.
let mocked = false
try {
  const { mock } = await import("bun:test")
  if (mock && typeof mock.module === "function") {
    const desc = { describe: () => desc }
    const withOptional = { optional: () => desc }
    const schema = { enum: () => withOptional, string: () => withOptional }
    const toolFn = (def) => def
    toolFn.schema = schema
    mock.module("@opencode-ai/plugin", () => ({ tool: toolFn }))
    mocked = true
  }
} catch {
  // bun:test not available or mock failed - fall through to real import
}

if (!mocked) {
  // For node:test, ensure @opencode-ai/plugin can be resolved via .opencode/node_modules
  // The plugin file imports from "@opencode-ai/plugin" which is available under
  // .opencode/node_modules but not necessarily in node's resolution. We rely on
  // import map via NODE_PATH or direct path. If import fails, the test will
  // report it clearly.
}

// Dynamic import after mock attempt
let mod
try {
  mod = await import("../delegation-observer.ts")
} catch (err) {
  // Fallback: try via file URL with experimental-strip-types
  throw new Error(`Failed to import delegation-observer.ts: ${err.message}\n${err.stack}`)
}

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "plugin-smoke-"))
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  return {
    directory,
    client: {
      app: { log: async () => {} },
      session: { messages: async () => ({ data: [] }) },
      provider: { list: async () => ({ data: { all: [] } }) },
    },
    _tmpDir: directory,
  }
}

describe("plugin-load smoke (DIA-260829-kxqu)", () => {
  it("default export is a function (plugin factory)", async () => {
    assert.equal(typeof mod.default, "function", "default export must be function")
  })

  it("default factory loads without throwing token.startsWith and returns hooks", async () => {
    const ctx = freshCtx()
    let hooks
    try {
      hooks = await mod.default(ctx)
    } catch (err) {
      assert.fail(`default factory threw: ${err.message}\n${err.stack}`)
    } finally {
      try { rmSync(ctx._tmpDir, { recursive: true, force: true }) } catch { /* ignore cleanup */ }
    }
    assert.ok(hooks && typeof hooks === "object", "factory must return hooks object")
    // Must contain at least one known hook; otherwise loader would have no effect
    const hasKnownHook =
      "tool.execute.before" in hooks ||
      "tool" in hooks ||
      "event" in hooks
    assert.ok(hasKnownHook, `hooks must contain tool/event, got keys: ${Object.keys(hooks).join(",")}`)
    // Ensure hooks object does not contain token.startsWith error string
    const serialized = JSON.stringify(hooks)
    assert.ok(!serialized.includes("token.startsWith"), "hooks must not contain error")
  })

  it("verifyCapabilityToken remains callable with string token and does not throw", async () => {
    assert.equal(typeof mod.verifyCapabilityToken, "function")
    const token = mod.mintCapabilityToken("test-scope", "smoke")
    assert.ok(typeof token === "string" && token.startsWith("CAP-"), "mint must produce CAP- token")
    const result = mod.verifyCapabilityToken(token)
    assert.equal(result.valid, true, "valid token must verify")
  })

  it("verifyCapabilityToken does NOT throw when called as plugin factory with PluginInput (loader guard)", async () => {
    assert.equal(typeof mod.verifyCapabilityToken, "function")
    const ctx = freshCtx()
    let result
    let threw = null
    try {
      // Simulate legacy loader: Object.values(mod) includes verifyCapabilityToken, called with PluginInput
      result = mod.verifyCapabilityToken(ctx)
    } catch (err) {
      threw = err
    } finally {
      try { rmSync(ctx._tmpDir, { recursive: true, force: true }) } catch { /* ignore cleanup */ }
    }
    if (threw) {
      assert.fail(`verifyCapabilityToken threw when called with PluginInput: ${threw.message} - this is the DIA-260829-kxqu crash`)
    }
    // When called as factory, it should return an object (empty Hooks or valid:false) not throw
    assert.ok(result && typeof result === "object", "loader-guarded call must return object, not throw")
    assert.ok(!String(result).includes("token.startsWith"), "must not contain token.startsWith")
  })

  it("mintCapabilityToken does NOT throw when called as plugin factory", async () => {
    assert.equal(typeof mod.mintCapabilityToken, "function")
    const ctx = freshCtx()
    let threw = null
    try {
      const result = mod.mintCapabilityToken(ctx)
      // Should return object (Hooks) or string but not throw
      assert.ok(result !== undefined, "mint guard must return something")
    } catch (err) {
      threw = err
    } finally {
      try { rmSync(ctx._tmpDir, { recursive: true, force: true }) } catch { /* ignore cleanup */ }
    }
    if (threw) {
      assert.fail(`mintCapabilityToken threw when called as factory: ${threw.message}`)
    }
  })

  it("legacy loader simulation: calling every exported function with PluginInput does not throw token.startsWith", async () => {
    const ctx = freshCtx()
    const failures = []
    for (const [name, value] of Object.entries(mod)) {
      if (typeof value === "function") {
        try {
          // Call as legacy loader does: fn(input)
          const result = await value(ctx)
          // For default, result should be hooks object; for helpers, guard returns {} or valid:false object
          // We only assert no throw containing token.startsWith
          if (result && typeof result === "object" && "token" in result) {
            // ignore
          }
        } catch (err) {
          if (String(err.message).includes("token.startsWith") || String(err.stack).includes("token.startsWith")) {
            failures.push(`${name}: ${err.message}`)
          } else {
            // Other throws are also failures for smoke, but we report
            failures.push(`${name}: ${err.message}`)
          }
        }
      } else if (value && typeof value === "object" && "server" in value) {
        try {
          const serverFn = value.server
          if (typeof serverFn === "function") {
            await serverFn(ctx)
          }
        } catch (err) {
          failures.push(`${name}.server: ${err.message}`)
        }
      }
    }
    try { rmSync(ctx._tmpDir, { recursive: true, force: true }) } catch { /* ignore cleanup */ }
    assert.equal(failures.length, 0, `loader simulation must not throw, failures: ${failures.join("; ")}`)
  })

  it("every export is Wy-compatible (function or {server:function})", async () => {
    function isFn(v) { return typeof v === "function" }
    function gy(v) {
      if (isFn(v)) return v
      if (!v || typeof v !== "object" || !("server" in v)) return undefined
      if (!isFn(v.server)) return undefined
      return v.server
    }
    const bad = []
    for (const [k, v] of Object.entries(mod)) {
      if (!gy(v)) bad.push(k)
    }
    assert.equal(bad.length, 0, `all exports must be Wy-compatible, bad: ${bad.join(",")}`)
  })
})
