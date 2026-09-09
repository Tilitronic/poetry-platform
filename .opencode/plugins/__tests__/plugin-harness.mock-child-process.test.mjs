/**
 * D4 fix-lane contract tests for mockChildProcess (DIA-260903-o7n0).
 *
 * Covers rev-1 findings on top of 2350ee8, all in this scenario/test file
 * (no new helper exports; helper keeps 4 exports max):
 *   - behavior allowlist is fail-loud (unknown behavior throws)
 *   - porcelain predicate is pinned to the production dirty-tree probe
 *     shape at delegation-observer.ts:817-819, with near-miss arg cases
 *   - probe stdout contents classify per the production trim rule
 *     (delegation-observer.ts:834): empty/whitespace-only/newline-only
 *     are clean, real output is dirty
 *   - second registration replaces the first (re-registration contract)
 *
 * RUN: bun test plugin-harness.mock-child-process.test.mjs
 */
import { test, expect } from "bun:test"
import { mockChildProcess } from "./helpers/plugin-harness.mjs"

// Mirrors the production dirty check at delegation-observer.ts:834.
function isDirty(stdout) {
  return (stdout ?? "").trim().length > 0
}

test("mockChildProcess accepts the two known behaviors", () => {
  const p = mockChildProcess("porcelain")
  expect(Array.isArray(p.spawnCalls)).toBe(true)
  expect(typeof p.setPorcelain).toBe("function")
  const n = mockChildProcess("needs-input")
  expect(Array.isArray(n.spawnCalls)).toBe(true)
})

test("mockChildProcess throws on unknown behavior (fail-loud allowlist)", () => {
  expect(() => mockChildProcess("bogus")).toThrow()
  expect(() => mockChildProcess("")).toThrow()
  expect(() => mockChildProcess(undefined)).toThrow()
  expect(() => mockChildProcess(null)).toThrow()
})

test("porcelain probe matches the production call shape", async () => {
  const { setPorcelain } = mockChildProcess("porcelain")
  setPorcelain(" M dirty.ts\n")
  const { spawnSync } = await import("node:child_process")
  const probe = spawnSync("git", ["-C", "/wt", "status", "--porcelain"], {})
  expect(probe.status).toBe(0)
  expect(probe.stdout).toBe(" M dirty.ts\n")
})

test("porcelain near-miss arg shapes return success-empty", async () => {
  mockChildProcess("porcelain")
  const { spawnSync } = await import("node:child_process")
  const nearMiss = [
    ["worktree", "prune"],
    ["worktree", "remove", "/wt"],
    ["-C", "/wt", "status"],
    ["-C", "/wt", "log", "--porcelain"],
    ["-C", "status"],
  ]
  for (const args of nearMiss) {
    const res = spawnSync("git", args, {})
    expect(res.status).toBe(0)
    expect(res.stdout).toBe("")
  }
  const wrongCmd = spawnSync("hg", ["-C", "/wt", "status", "--porcelain"], {})
  expect(wrongCmd.status).toBe(0)
  expect(wrongCmd.stdout).toBe("")
})

test("probe stdout classifies per the production trim rule", async () => {
  const { setPorcelain } = mockChildProcess("porcelain")
  const { spawnSync } = await import("node:child_process")
  const probeArgs = ["-C", "/wt", "status", "--porcelain"]
  for (const clean of ["", "   ", "\n"]) {
    setPorcelain(clean)
    const res = spawnSync("git", probeArgs, {})
    expect(res.stdout).toBe(clean)
    expect(isDirty(res.stdout)).toBe(false)
  }
  for (const dirty of [" M dirty.ts\n", "?? src/newfile.ts\n"]) {
    setPorcelain(dirty)
    const res = spawnSync("git", probeArgs, {})
    expect(isDirty(res.stdout)).toBe(true)
  }
})

test("second mockChildProcess registration replaces the first", async () => {
  const first = mockChildProcess("porcelain")
  first.setPorcelain("FIRST\n")
  const second = mockChildProcess("porcelain")
  expect(second.spawnCalls).not.toBe(first.spawnCalls)
  second.setPorcelain("SECOND\n")
  const { spawnSync } = await import("node:child_process")
  const probe = spawnSync("git", ["-C", "/wt", "status", "--porcelain"], {})
  expect(probe.stdout).toBe("SECOND\n")
  expect(first.spawnCalls.length).toBe(0)
})
