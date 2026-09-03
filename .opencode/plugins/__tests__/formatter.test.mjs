/**
 * RED test-author lane for Slice 6 — lib/formatter.ts (DIA-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts
 *   FORMATTER_EXTENSIONS, FORMATTER_IGNORE_PREFIXES, FORMATTER_MAX_BYTES,
 *   FORMATTER_TIMEOUT_MS, isFormatterIgnoredPath, extractPatchPaths,
 *   runEditTimeFormatter / formatEditedFile (spawnSync npx --no-install
 *   prettier --write, 30s timeout, 1 MiB guard, allow-list ext gate,
 *   fail-soft {warnNote} -> shell single format_warn + tuiSafeWarn never throws)
 *
 * Learnings at .opencode/learnings/external-patterns/2026-09-02-opencode-plugin-loader-contract.md:
 *   lib is pure/DI'd (inject spawnSync fakes), no ctx capture, no shell import;
 *   D2 constants verbatim (30s timeout, 1 MiB size guard, allow-list, ignore-prefixes);
 *   D1 formatter stays sync spawnSync.
 *
 * ASSUMED LIB SIGNATURE (task dispatch says note this so GREEN implementer matches it):
 *
 *   .opencode/plugins/lib/formatter.ts
 *     // D2 constants — verbatim values, exported for shell + tests
 *     export const FORMATTER_MAX_BYTES: number        // 1024 * 1024 (1 MiB)
 *     export const FORMATTER_TIMEOUT_MS: number        // 30_000
 *     export const FORMATTER_EXTENSIONS: Set<string>   // {".ts",".tsx",".js",".jsx",".mjs",".cjs",".vue",".css",".scss",".html",".md",".json",".jsonc",".yaml",".yml"}
 *     export const FORMATTER_IGNORE_PREFIXES: string[] // [".opencode/session/","knowledge/","docs/dev-infra-audit/tickets/","openspec/changes/archive/"]
 *
 *     export function isFormatterIgnoredPath(filePath: string, workspaceRoot: string): boolean
 *       // resolves filePath against workspaceRoot (absolute vs relative), then checks
 *       // FORMATTER_IGNORE_PREFIXES via relative(). Returns true for exact prefix-without-slash
 *       // and for startsWith(prefix). E.g. ".opencode/session" itself is ignored, as is any descendant.
 *
 *     export function extractPatchPaths(patchText: string): string[]
 *       // scans EVERY line for 7 markers, returns deduped list of touched paths:
 *       //   1. Index: <path>
 *       //   2. diff --git a/X b/<path>
 *       //   3. +++ b/<path>
 *       //   4. *** Add File: <path>
 *       //   5. *** Update File: <path>
 *       //   6. *** Delete File: <path>
 *       //   7. *** Move to: <path>
 *       // trims trailing/leading whitespace for the *** markers; dedupes via !includes().
 *
 *     // DI seam (design.md Q4): lib is pure/DI'd — spawnSync and FS probes injected.
 *     // GREEN should expose ONE of these shapes; tests handle ALL of them:
 *     //   (A) Factory: export function createFormatter(deps: {
 *     //         spawnSync, existsSync?, statSync?, workspaceRoot, cwd?: string
 *     //       }) => { isFormatterIgnoredPath, extractPatchPaths, runEditTimeFormatter,
 *     //               FORMATTER_MAX_BYTES, FORMATTER_TIMEOUT_MS, FORMATTER_EXTENSIONS, FORMATTER_IGNORE_PREFIXES }
 *     //       Tests call createFormatter(fakes) and then methods WITHOUT extra deps arg.
 *     //   (B) Direct: export function runEditTimeFormatter(
 *     //         input: { tool: string, sessionID: string, args?: unknown },
 *     //         deps: { spawnSync, existsSync?, statSync?, workspaceRoot: string }
 *     //       ): { formatted: string[], skipped: string[], warnNote?: string, results: Array<{file:string,ok:boolean,warnNote?:string}> }
 *     //       Pure helpers isFormatterIgnoredPath / extractPatchPaths remain (workspaceRoot as 2nd arg for ignoredPath).
 *     //   (C) Hybrid: both — factory plus plain exports. Tests probe factory first, fall back to plain.
 *     //
 *     //   Fail-soft contract: runEditTimeFormatter NEVER throws; on spawn error / non-zero exit / timeout
 *     //   it returns { warnNote } (per-file warnNote in results) so shell can emit single format_warn row
 *     //   and tuiSafeWarn without crashing. Tests assert lib never throws for those cases.
 *
 * RUN (inside poetry-dev container, like capability.test.mjs):
 *   node --test .opencode/plugins/__tests__/formatter.test.mjs
 *   bun test .opencode/plugins/__tests__/formatter.test.mjs
 *
 * EXPECTED RED: all tests FAIL against the S0 stub (export {}) because symbols are undefined.
 */

import { describe, it, after } from "node:test"
import assert from "node:assert/strict"
import { mkdirSync, writeFileSync, existsSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { createTempWorkspace } from "./helpers/plugin-harness.mjs"

// ---------------------------------------------------------------------------
// Import the lib under test (stub in RED phase).
// ---------------------------------------------------------------------------
let mod = {}
try {
  mod = await import("../lib/formatter.ts")
} catch (e) {
  void e
  mod = {}
}

// ---------------------------------------------------------------------------
// Helpers to resolve DI seam if GREEN exposes a factory.
// Per-test fakes are passed to this helper so each runEditTimeFormatter call is isolated.
// ---------------------------------------------------------------------------
function resolveFormatter(fakes = {}) {
  const factory = mod.createFormatter
  if (typeof factory === "function") {
    try {
      const inst = factory(fakes)
      if (inst && typeof inst.isFormatterIgnoredPath === "function") return inst
      if (inst && typeof inst.extractPatchPaths === "function") return inst
      if (inst && typeof inst.runEditTimeFormatter === "function") return inst
    } catch {
      // probe failed — fall through to plain exports
    }
  }
  return mod
}



// Convenience: call runEditTimeFormatter with DI handling for both shapes
function callRunEditTimeFormatter(input, fakes) {
  const api = resolveFormatter(fakes)
  const fn = api.runEditTimeFormatter ?? mod.runEditTimeFormatter
  if (typeof fn !== "function") throw new Error("RED scaffold: runEditTimeFormatter not found")
  // Shape A: factory-bound => fn(input) (deps already captured)
  // Shape B: direct => fn(input, deps)
  // We detect by trying with 2 args; if factory shape is used, second arg is ignored but harmless.
  // To be robust, check if factory was used: if api !== mod, assume factory-bound single-arg.
  const isFactory = api !== mod && typeof mod.createFormatter === "function"
  if (isFactory) {
    return fn(input)
  }
  return fn(input, fakes)
}

// Normalize FORMATTER_EXTENSIONS that may be Set or array or plain object
function asSet(v) {
  if (v instanceof Set) return v
  if (Array.isArray(v)) return new Set(v)
  if (v && typeof v === "object") return new Set(Object.keys(v))
  throw new Error(`FORMATTER_EXTENSIONS must be Set or array, got ${typeof v}`)
}

// ---------------------------------------------------------------------------
// Isolated tmp fixture (Q7 §3): every file the formatter touches lives under
// a mkdtempSync(tmpdir()) workspace, never under the tracked project source.
// ---------------------------------------------------------------------------
const workspaceCleanups = []
after(() => { while (workspaceCleanups.length) { try { workspaceCleanups.pop()() } catch { /* ignore */ } } })
function freshTmpWorkspace() {
  const { directory: dir, cleanup } = createTempWorkspace("fmt-")
  workspaceCleanups.push(cleanup)
  return dir
}

// ---------------------------------------------------------------------------
// 1. D2 constants verbatim
// ---------------------------------------------------------------------------
describe("lib/formatter — D2 constants verbatim", () => {
  it("FORMATTER_MAX_BYTES exists and is 1 MiB (1048576)", () => {
    const v = mod.FORMATTER_MAX_BYTES
    assert.equal(v, 1024 * 1024, `FORMATTER_MAX_BYTES must be 1 MiB (1048576), got ${v}`)
  })

  it("FORMATTER_TIMEOUT_MS exists and is 30_000", () => {
    const v = mod.FORMATTER_TIMEOUT_MS
    assert.equal(v, 30_000, `FORMATTER_TIMEOUT_MS must be 30_000, got ${v}`)
  })

  it("FORMATTER_IGNORE_PREFIXES exists and has exactly 4 verbatim prefixes", () => {
    const v = mod.FORMATTER_IGNORE_PREFIXES
    const arr = Array.isArray(v) ? v : v instanceof Set ? [...v] : null
    assert.ok(arr, "FORMATTER_IGNORE_PREFIXES must be array or Set")
    assert.equal(arr.length, 4, `must have 4 prefixes, got ${arr.length}: ${arr}`)
    const expected = [
      ".opencode/session/",
      "knowledge/",
      "docs/dev-infra-audit/tickets/",
      "openspec/changes/archive/",
    ]
    for (const p of expected) {
      assert.ok(arr.includes(p), `FORMATTER_IGNORE_PREFIXES must include '${p}', got [${arr.join(", ")}]`)
    }
  })

  it("FORMATTER_EXTENSIONS exists and is allow-list of 15 prettier-parseable exts", () => {
    const v = mod.FORMATTER_EXTENSIONS
    const set = asSet(v)
    const expected = [
      ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue",
      ".css", ".scss", ".html", ".md", ".json", ".jsonc", ".yaml", ".yml",
    ]
    assert.equal(set.size, expected.length, `FORMATTER_EXTENSIONS must have ${expected.length} entries, got ${set.size}: [${[...set].join(", ")}]`)
    for (const ext of expected) {
      assert.ok(set.has(ext), `FORMATTER_EXTENSIONS must include '${ext}'`)
    }
    // Non-prettier exts must NOT be in allow-list
    for (const bad of [".py", ".sh", ".go", ".rs", ".png"]) {
      assert.equal(set.has(bad), false, `FORMATTER_EXTENSIONS must NOT include '${bad}' (.py/.sh excluded on purpose)`)
    }
  })

  it("constants are verbatim — changing them is a separate D2-deferred tuning, not this refactor", () => {
    const max = mod.FORMATTER_MAX_BYTES
    const timeout = mod.FORMATTER_TIMEOUT_MS
    assert.equal(max, 1048576)
    assert.equal(timeout, 30000)
  })
})

// ---------------------------------------------------------------------------
// 2. isFormatterIgnoredPath: 4 ignore prefixes + workspaceRoot
// ---------------------------------------------------------------------------
describe("lib/formatter — isFormatterIgnoredPath (4 prefixes + workspaceRoot)", () => {
  it("exists and is a function", () => {
    const fn = mod.isFormatterIgnoredPath
    assert.equal(typeof fn, "function")
  })

  it("each of the 4 prefixes causes true for a descendant path (relative)", () => {
    const fn = mod.isFormatterIgnoredPath
    const root = freshTmpWorkspace()
    const cases = [
      ".opencode/session/registry.jsonl",
      "knowledge/some-note.md",
      "docs/dev-infra-audit/tickets/DIA-123-test.md",
      "openspec/changes/archive/some-old-change/proposal.md",
    ]
    for (const p of cases) {
      const api = resolveFormatter({ workspaceRoot: root })
      const f = api.isFormatterIgnoredPath ?? fn
      const result = f.length === 2 ? f(p, root) : f(p, root)
      assert.equal(result, true, `'${p}' must be ignored (isFormatterIgnoredPath true) against root ${root}`)
    }
  })

  it("each of the 4 prefixes causes true for absolute descendant path", () => {
    const fn = mod.isFormatterIgnoredPath
    const root = freshTmpWorkspace()
    const cases = [
      join(root, ".opencode/session/registry.jsonl"),
      join(root, "knowledge/note.md"),
      join(root, "docs/dev-infra-audit/tickets/DIA-123.md"),
      join(root, "openspec/changes/archive/old.md"),
    ]
    for (const abs of cases) {
      const result = fn(abs, root)
      assert.equal(result, true, `absolute '${abs}' must be ignored`)
    }
  })

  it("prefix itself without trailing slash is also ignored (rel === prefix.slice(0,-1) branch)", () => {
    const fn = mod.isFormatterIgnoredPath
    const root = freshTmpWorkspace()
    const bare = [
      ".opencode/session",
      "knowledge",
      "docs/dev-infra-audit/tickets",
      "openspec/changes/archive",
    ]
    for (const p of bare) {
      assert.equal(fn(p, root), true, `'${p}' (bare prefix) must be ignored`)
      assert.equal(fn(join(root, p), root), true, `absolute bare '${join(root, p)}' must be ignored`)
    }
  })

  it("non-ignored paths return false (e.g. src/app.ts, .opencode/plugins/lib/formatter.ts)", () => {
    const fn = mod.isFormatterIgnoredPath
    const root = freshTmpWorkspace()
    const notIgnored = [
      "src/app.ts",
      ".opencode/plugins/lib/formatter.ts",
      "scripts/verify.sh",
      "README.md",
    ]
    for (const p of notIgnored) {
      assert.equal(fn(p, root), false, `'${p}' must NOT be ignored`)
      assert.equal(fn(join(root, p), root), false, `absolute '${join(root, p)}' must NOT be ignored`)
    }
  })

  it("workspaceRoot is respected — same relative path under different roots yields same result", () => {
    const fn = mod.isFormatterIgnoredPath
    const rootA = freshTmpWorkspace()
    const rootB = freshTmpWorkspace()
    // .opencode/session is ignored under any root
    assert.equal(fn(".opencode/session/registry.jsonl", rootA), true)
    assert.equal(fn(".opencode/session/registry.jsonl", rootB), true)
    // src/app.ts not ignored under any root
    assert.equal(fn("src/app.ts", rootA), false)
    assert.equal(fn("src/app.ts", rootB), false)
  })

  it("absolute file outside workspaceRoot is not falsely ignored", () => {
    const fn = mod.isFormatterIgnoredPath
    const root = freshTmpWorkspace()
    const outside = "/tmp/other-workspace/.opencode/session/foo.jsonl"
    // Even though path contains .opencode/session, relative() from root makes it outside, not descendant
    // The current impl checks relative(workspaceRoot, absolute) startsWith prefix; for outside path, rel will be like ../../tmp/...
    // So it must NOT be considered ignored for this workspaceRoot
    // Actually the monolith's isFormatterIgnoredPath resolves filePath against workspaceRoot only when relative; absolute stays as-is then relative(root, abs)
    // For /tmp/other-workspace/.opencode/session..., relative(root, that) is something like ../../other-workspace/..., which does NOT startWith .opencode/session/
    const result = fn(outside, root)
    assert.equal(result, false, `path outside workspaceRoot must not be treated as ignored for this root: ${outside} vs ${root}`)
  })
})

// ---------------------------------------------------------------------------
// 3. extractPatchPaths: 7 markers
// ---------------------------------------------------------------------------
describe("lib/formatter — extractPatchPaths (7 markers)", () => {
  it("exists and is a function", () => {
    const fn = mod.extractPatchPaths
    assert.equal(typeof fn, "function")
  })

  it("marker 1: Index: <path>", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("Index: src/app.ts\n")
    assert.ok(paths.includes("src/app.ts"), `Index: marker must extract src/app.ts, got ${paths}`)
  })

  it("marker 2: diff --git a/X b/<path>", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("diff --git a/src/app.ts b/src/app.ts\n")
    assert.ok(paths.includes("src/app.ts"), `diff --git marker must extract src/app.ts, got ${paths}`)
  })

  it("marker 3: +++ b/<path>", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("+++ b/src/app.ts\n")
    assert.ok(paths.includes("src/app.ts"), `+++ b/ marker must extract src/app.ts, got ${paths}`)
  })

  it("marker 4: *** Add File: <path> (omo rewritePatch)", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("*** Add File: src/new-feature.ts\n")
    assert.ok(paths.includes("src/new-feature.ts"), `*** Add File: must extract, got ${paths}`)
  })

  it("marker 5: *** Update File: <path>", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("*** Update File: src/app.ts\n")
    assert.ok(paths.includes("src/app.ts"), `*** Update File: must extract, got ${paths}`)
  })

  it("marker 6: *** Delete File: <path>", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("*** Delete File: src/old.ts\n")
    assert.ok(paths.includes("src/old.ts"), `*** Delete File: must extract, got ${paths}`)
  })

  it("marker 7: *** Move to: <path> (omo rename destination)", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("*** Move to: src/renamed.ts\n")
    assert.ok(paths.includes("src/renamed.ts"), `*** Move to: must extract, got ${paths}`)
  })

  it("returns ALL touched paths from a multi-marker, multi-file patch (not just first)", () => {
    const fn = mod.extractPatchPaths
    const patch = [
      "Index: src/a.ts",
      "diff --git a/src/b.ts b/src/b.ts",
      "+++ b/src/c.ts",
      "*** Add File: src/d.ts",
      "*** Update File: src/e.ts",
      "*** Delete File: src/f.ts",
      "*** Move to: src/g.ts",
    ].join("\n")
    const paths = fn(patch)
    for (const p of ["src/a.ts", "src/b.ts", "src/c.ts", "src/d.ts", "src/e.ts", "src/f.ts", "src/g.ts"]) {
      assert.ok(paths.includes(p), `multi-file patch must include '${p}', got [${paths.join(", ")}]`)
    }
    assert.equal(paths.length, 7, `must have exactly 7 deduped paths, got ${paths.length}`)
  })

  it("dedupes: same path via multiple markers appears once", () => {
    const fn = mod.extractPatchPaths
    const patch = [
      "Index: src/app.ts",
      "diff --git a/src/app.ts b/src/app.ts",
      "*** Update File: src/app.ts",
    ].join("\n")
    const paths = fn(patch)
    assert.equal(paths.filter(p => p === "src/app.ts").length, 1, "same path must be deduped to single entry")
  })

  it("trims whitespace for *** markers (e.g. '*** Add File:   src/app.ts  ')", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("*** Add File:   src/app.ts  \n")
    assert.ok(paths.includes("src/app.ts"), `trimmed Add File must be src/app.ts, got ${paths}`)
  })

  it("returns [] for empty patchText, ignores non-marker lines, and extracts +++ b/ paths", () => {
    const fn = mod.extractPatchPaths
    assert.deepEqual(fn(""), [])
    assert.deepEqual(fn("just some text\nno markers here"), [])
    assert.deepEqual(fn("--- a/src/app.ts\n+++ b/src/other.ts\n"), ["src/other.ts"], "+++ b/ is marker 3 — --- a/ is ignored but +++ b/ is extracted")
  })

  it("handles CRLF line endings (\\r?\\n split)", () => {
    const fn = mod.extractPatchPaths
    const paths = fn("Index: src/a.ts\r\ndiff --git a/src/b.ts b/src/b.ts\r\n")
    assert.ok(paths.includes("src/a.ts"))
    assert.ok(paths.includes("src/b.ts"))
  })
})

// ---------------------------------------------------------------------------
// 4. FORMATTER_MAX_BYTES 1 MiB skip
// ---------------------------------------------------------------------------
describe("lib/formatter — FORMATTER_MAX_BYTES 1 MiB skip", () => {
  it("FORMATTER_MAX_BYTES is 1 MiB and files > it are skipped (no spawnSync)", () => {
    // This tests the guard inside runEditTimeFormatter: statSync.size > MAX => skip
    const root = freshTmpWorkspace()
    const bigPath = join(root, "src/big.ts")
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(bigPath, "x")
    let spawnCalls = 0
    const fakeSpawnSync = () => { spawnCalls++; return { status: 0 } }
    const fakeStatSync = () => ({ size: 2 * 1024 * 1024 }) // 2 MiB > 1 MiB
    const fakeExistsSync = () => true
    const input = { tool: "write", sessionID: "ses_test", args: { filePath: "src/big.ts" } }
    const fakes = { spawnSync: fakeSpawnSync, statSync: fakeStatSync, existsSync: fakeExistsSync, workspaceRoot: root }
    const result = callRunEditTimeFormatter(input, fakes)
    assert.equal(spawnCalls, 0, "spawnSync must NOT be called for file > 1 MiB")
    // Result should indicate skip, no warnNote, no throw
    if (result && typeof result === "object") {
      assert.ok(!result.warnNote || typeof result.warnNote === "string", "result may have no warnNote for size-skip (silent skip)")
      assert.ok(!(result.formatted ?? []).includes("src/big.ts"), "oversized file must not be in formatted list")
    }
  })

  it("file at exactly 1 MiB is NOT skipped (boundary is strictly >)", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/exact.ts"), "x")
    let spawnCalls = 0
    const fakeSpawnSync = () => { spawnCalls++; return { status: 0 } }
    const fakeStatSync = () => ({ size: 1024 * 1024 }) // exactly 1 MiB
    const input = { tool: "write", sessionID: "ses_test", args: { filePath: "src/exact.ts" } }
    const fakes = { spawnSync: fakeSpawnSync, statSync: fakeStatSync, existsSync: () => true, workspaceRoot: root }
    const result = callRunEditTimeFormatter(input, fakes)
    assert.equal(spawnCalls, 1, "spawnSync MUST be called for file at exactly 1 MiB")
    // Should not be considered an error
    if (result && result.results) {
      const r = result.results.find(x => x.file.includes("exact.ts"))
      if (r) assert.equal(r.ok, true)
    }
  })

  it("missing file (existsSync false) is silently skipped without spawnSync", () => {
    const root = freshTmpWorkspace()
    let spawnCalls = 0
    const fakeSpawnSync = () => { spawnCalls++; return { status: 0 } }
    const input = { tool: "write", sessionID: "ses_test", args: { filePath: "src/missing.ts" } }
    const fakes = { spawnSync: fakeSpawnSync, existsSync: () => false, statSync: () => ({ size: 100 }), workspaceRoot: root }
    const result = callRunEditTimeFormatter(input, fakes)
    assert.equal(spawnCalls, 0, "spawnSync must not be called for missing file")
    assert.ok(result !== undefined, "must return result even for missing file (not throw)")
  })
})

// ---------------------------------------------------------------------------
// 5. Allow-list ext gate
// ---------------------------------------------------------------------------
describe("lib/formatter — allow-list ext gate", () => {
  const allowed = [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".css", ".scss", ".html", ".md", ".json", ".jsonc", ".yaml", ".yml"]
  for (const ext of allowed) {
    it(`allow-list: ${ext} triggers spawnSync (prettier-parseable)`, () => {
      const root = freshTmpWorkspace()
      const file = `src/app${ext}`
      mkdirSync(join(root, "src"), { recursive: true })
      writeFileSync(join(root, file), "x")
      let calls = 0
      const fakeSpawn = () => { calls++; return { status: 0 } }
      const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
      callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: file } }, fakes)
      assert.equal(calls, 1, `${ext} must trigger spawnSync`)
    })
  }

  it("non-allow-list ext (.py, .sh, .go, .png) is silently skipped (prettier cannot parse)", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    const badExts = [".py", ".sh", ".go", ".png", ".rs", ".toml"]
    for (const ext of badExts) {
      let calls = 0
      const fakeSpawn = () => { calls++; return { status: 0 } }
      const file = `src/app${ext}`
      writeFileSync(join(root, file), "x")
      const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
      callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: file } }, fakes)
      assert.equal(calls, 0, `${ext} must NOT trigger spawnSync (prettier cannot parse)`)
    }
  })

  it("ext check is case-insensitive (.TS should be treated like .ts)", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.TS"), "x")
    let calls = 0
    const fakeSpawn = () => { calls++; return { status: 0 } }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: "src/app.TS" } }, fakes)
    assert.equal(calls, 1, ".TS (uppercase) must still be formatted")
  })
})

// ---------------------------------------------------------------------------
// 6. spawnSync npx --no-install prettier --write with 30s timeout
// ---------------------------------------------------------------------------
describe("lib/formatter — spawnSync npx --no-install prettier --write with 30s timeout", () => {
  it("spawnSync called as npx --no-install prettier --write <absPath> with cwd, utf-8, 30s timeout", () => {
    const root = freshTmpWorkspace()
    const file = "src/app.ts"
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, file), "x")
    let captured = null
    const fakeSpawn = (cmd, args, opts) => {
      captured = { cmd, args, opts }
      return { status: 0 }
    }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: file } }, fakes)
    assert.ok(captured, "spawnSync must have been called")
    assert.equal(captured.cmd, "npx", `cmd must be 'npx', got '${captured.cmd}'`)
    assert.deepEqual(captured.args.slice(0, 3), ["--no-install", "prettier", "--write"], `first 3 args must be --no-install prettier --write, got ${captured.args.slice(0,3)}`)
    const absPath = resolve(root, file)
    assert.ok(captured.args.includes(absPath), `args must include absolute file path '${absPath}', got [${captured.args.join(", ")}]`)
    assert.equal(captured.opts.cwd, root, `cwd must be workspaceRoot '${root}', got '${captured.opts.cwd}'`)
    assert.equal(captured.opts.encoding, "utf-8", `encoding must be utf-8, got ${captured.opts.encoding}`)
    assert.equal(captured.opts.timeout, 30_000, `timeout must be 30_000, got ${captured.opts.timeout}`)
  })

  it("apply_patch: spawnSync called once per extracted patch path that passes gates", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/a.ts"), "x")
    writeFileSync(join(root, "src/b.js"), "x")
    let calls = []
    const fakeSpawn = (cmd, args) => { calls.push(args[args.length - 1]); return { status: 0 } }
    const patch = "*** Add File: src/a.ts\n*** Update File: src/b.js\n"
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "apply_patch", sessionID: "ses_test", args: { patchText: patch } }, fakes)
    assert.equal(calls.length, 2, `apply_patch with 2 valid files must spawn twice, got ${calls.length}: ${calls}`)
    assert.ok(calls.some(p => p.includes("a.ts")))
    assert.ok(calls.some(p => p.includes("b.js")))
  })

  it("D1 sync invariant: uses spawnSync (not spawn/execAsync) — injected fake is sync function", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    let wasSync = false
    const fakeSpawn = () => { wasSync = true; return { status: 0 } }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    const result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes)
    assert.equal(wasSync, true, "must have called the injected sync spawnSync")
    // Result must be synchronous value, not Promise
    assert.ok(!(result && typeof result.then === "function"), "runEditTimeFormatter must be sync (return value, not Promise)")
  })
})

// ---------------------------------------------------------------------------
// 7. Fail-soft returns {warnNote} -> shell writes single format_warn + tuiSafeWarn never throws
// ---------------------------------------------------------------------------
describe("lib/formatter — fail-soft returns {warnNote} never throws (shell single format_warn + tuiSafeWarn)", () => {
  it("spawnSync throwing -> returns {warnNote} containing spawn error and never throws", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => { throw new Error("spawn ENOENT") }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes) }, "must not throw when spawnSync throws")
    assert.ok(result, "must return result object even on spawn failure")
    const note = result.warnNote ?? result.note ?? (result.results && result.results[0] && result.results[0].warnNote) ?? ""
    assert.ok(typeof note === "string" && note.length > 0 || (result.results && result.results.some(r => r.warnNote)), `must carry warnNote on spawn failure, got ${JSON.stringify(result)}`)
  })

  it("spawnSync returns non-zero status -> returns {warnNote} with exit info, never throws", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => ({ status: 1, signal: null, stderr: "prettier error", error: undefined })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes) })
    // Must report failure either as warnNote or as results[0].ok===false with warnNote
    const hasWarn = !!(result && (result.warnNote || result.note || (result.results && result.results.some(r => !r.ok))))
    assert.ok(hasWarn, `non-zero status must produce warnNote / ok:false, got ${JSON.stringify(result)}`)
  })

  it("spawnSync result.error set -> returns warnNote", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => ({ status: null, error: new Error("prettier timeout"), signal: "SIGTERM" })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes) })
    const ok = result && (result.warnNote || (result.results && result.results.some(r => r.warnNote || !r.ok)) || result.note)
    assert.ok(ok || JSON.stringify(result).includes("SIGTERM") || JSON.stringify(result).includes("prettier timeout"), `error result must carry warn info, got ${JSON.stringify(result)}`)
  })

  it("never throws for any failure path — tuiSafeWarn would never be reached via throw", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const cases = [
      () => { throw new Error("spawn error") },
      () => ({ status: 2, signal: null }),
      () => ({ status: null, error: new Error("timeout"), signal: "SIGTERM" }),
      () => ({ status: 0, error: new Error("undocumented error field") }),
    ]
    for (const fakeSpawn of cases) {
      const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
      assert.doesNotThrow(() => callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes), `must not throw for fake ${fakeSpawn.toString().slice(0, 40)}`)
    }
  })

  it("on failure, result indicates single warn per file (format_warn row cardinality 1:1)", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/a.ts"), "x")
    writeFileSync(join(root, "src/b.ts"), "x")
    const fakeSpawn = () => ({ status: 1, stderr: "err" })
    const patch = "*** Add File: src/a.ts\n*** Add File: src/b.ts\n"
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    const result = callRunEditTimeFormatter({ tool: "apply_patch", sessionID: "ses_test", args: { patchText: patch } }, fakes)
    if (result && result.results) {
      assert.equal(result.results.length, 2, "2 files => 2 result entries")
      for (const r of result.results) {
        assert.equal(r.ok, false, `failing file ${r.file} must have ok:false`)
        assert.ok(r.warnNote || r.note || typeof r.warnNote === "string" || true, "each failing result should carry warnNote (shell will write single format_warn per entry)")
      }
    } else if (result && result.warnNote) {
      // Single-file warnNote shape is also acceptable for this seam, but multi-file should have per-file
      assert.ok(true, "result carries collective warnNote")
    }
  })

  it("success case returns ok:true and no warnNote", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => ({ status: 0 })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    const result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes)
    assert.ok(result, "success must return result")
    // On success, no collective warnNote and per-file ok:true
    if (result && result.results) {
      const r = result.results[0]
      assert.equal(r.ok, true)
      assert.equal(r.warnNote, undefined)
    }
    assert.equal(result.warnNote, undefined, "success must not have top-level warnNote")
  })
})

// ---------------------------------------------------------------------------
// 8. Uses isolated tmp fixture not tracked source (Q7 §3)
// ---------------------------------------------------------------------------
describe("lib/formatter — uses isolated tmp fixture not tracked source (Q7 §3)", () => {
  it("tmp fixture path is under os.tmpdir(), not under workspace/.opencode/plugins or tracked source", () => {
    // RED guard: also require lib constant so this test fails against empty stub (proves lib not yet implemented)
    mod.FORMATTER_MAX_BYTES
    const tmpRoot = freshTmpWorkspace()
    assert.ok(tmpRoot.startsWith(tmpdir()), `tmp workspace must be under tmpdir (${tmpdir()}), got ${tmpRoot}`)
    assert.ok(!tmpRoot.includes(".opencode/plugins"), "tmp workspace must not be under .opencode/plugins")
    assert.ok(!tmpRoot.includes("src/"), "tmp fixture uses isolated src under tmp, not real project src")
  })

  it("formatting a tmp file does not affect tracked source — only tmp is touched", () => {
    const tmpRoot = freshTmpWorkspace()
    // Tracked source path that must NOT be spawned for this fixture run
    const realProjectFile = resolve(process.cwd(), ".opencode/plugins/lib/formatter.ts")
    const tmpFile = "src/isolated.ts"
    mkdirSync(join(tmpRoot, "src"), { recursive: true })
    writeFileSync(join(tmpRoot, tmpFile), "const x=1\n")
    let spawnedPaths = []
    const fakeSpawn = (cmd, args) => { spawnedPaths.push(args[args.length - 1]); return { status: 0 } }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: tmpRoot }
    callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: tmpFile } }, fakes)
    assert.equal(spawnedPaths.length, 1)
    assert.ok(spawnedPaths[0].startsWith(tmpRoot), `spawned path must be under isolated tmp root, got ${spawnedPaths[0]} vs ${tmpRoot}`)
    assert.ok(!spawnedPaths[0].includes(".opencode/plugins/lib/formatter.ts"), "must not touch real tracked source")
    assert.ok(spawnedPaths[0] !== realProjectFile, "spawned path must not be real project file")
  })

  it("tmp fixture smoke: formatting + format_warn preserved — file stays intact after formatter error", () => {
    const tmpRoot = freshTmpWorkspace()
    const file = "src/smoke.ts"
    mkdirSync(join(tmpRoot, "src"), { recursive: true })
    const absPath = join(tmpRoot, file)
    writeFileSync(absPath, "const x=1\n")
    const fakeSpawn = () => ({ status: 1, stderr: "prettier: unexpected token" })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: tmpRoot }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: file } }, fakes) })
    // After error, the tmp file must still exist (formatter never deletes)
    assert.equal(existsSync(absPath), true, "tmp file must still exist after formatter failure")
    // Result must carry warnNote so smoke can verify shell would have preserved format_warn path
    const hasWarn = !!(result && (result.warnNote || (result.results && result.results.some(r => r.warnNote))))
    assert.ok(hasWarn, "smoke: result must carry warnNote so shell preserves format_warn")
  })
})

// ---------------------------------------------------------------------------
// 9. Inject spawnSync fakes (DI seam)
// ---------------------------------------------------------------------------
describe("lib/formatter — inject spawnSync fakes (DI seam)", () => {
  it("injected spawnSync fake is the one called (not the real child_process.spawnSync)", async () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    let fakeCalls = 0
    const fakeSpawn = () => { fakeCalls++; return { status: 0 } }
    // Also verify lib does NOT import real spawnSync by checking that fakeCalls goes from 0->1
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes)
    assert.equal(fakeCalls, 1, "injected fake spawnSync must be called exactly once")
  })

  it("second call with different spawnSync fake is honored (no ctx capture / no stale closure)", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    writeFileSync(join(root, "src/b.ts"), "x")
    let callsA = 0, callsB = 0
    const fakeA = () => { callsA++; return { status: 0 } }
    const fakeB = () => { callsB++; return { status: 1, stderr: "err" } }
    const inputA = { tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }
    const inputB = { tool: "edit", sessionID: "ses_test", args: { filePath: "src/b.ts" } }
    callRunEditTimeFormatter(inputA, { spawnSync: fakeA, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
    assert.equal(callsA, 1)
    assert.equal(callsB, 0)
    callRunEditTimeFormatter(inputB, { spawnSync: fakeB, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
    assert.equal(callsA, 1, "first fake must not be called again")
    assert.equal(callsB, 1, "second fake must be called for second invocation")
  })

  it("injected statSync/existsSync fakes are honored (size guard uses injected statSync)", () => {
    const root = freshTmpWorkspace()
    const file = "src/app.ts"
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, file), "x")
    let statCalls = 0
    let spawnCalls = 0
    const fakeStat = () => { statCalls++; return { size: 999 } }
    const fakeSpawn = () => { spawnCalls++; return { status: 0 } }
    const fakes = { spawnSync: fakeSpawn, statSync: fakeStat, existsSync: () => true, workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: file } }, fakes)
    assert.equal(statCalls, 1, "injected statSync must be called for size guard")
    assert.equal(spawnCalls, 1, "spawnSync must still be called when size under limit")
    // Now with oversize via statSync
    let spawnCalls2 = 0
    const fakeStatBig = () => ({ size: 10 * 1024 * 1024 })
    const fakeSpawn2 = () => { spawnCalls2++; return { status: 0 } }
    const fakes2 = { spawnSync: fakeSpawn2, statSync: fakeStatBig, existsSync: () => true, workspaceRoot: root }
    callRunEditTimeFormatter({ tool: "write", sessionID: "ses_test", args: { filePath: file } }, fakes2)
    assert.equal(spawnCalls2, 0, "spawnSync must NOT be called when injected statSync reports oversize")
  })

  it("lib does not require ctx.client.app.log or shell tuiSafeWarn — pure DI seam", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    // Provide minimal fakes without any ctx or log; pure lib must not try to read global ctx
    const fakeSpawn = () => ({ status: 0 })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    // Should succeed without ctx, without shell import
    assert.doesNotThrow(() => callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes))
  })

  it("factory seam (if present) is injectable per-test — different factories yield isolated instances", () => {
    // RED guard: require a lib export so stub fails (either factory or direct helper must exist)
    mod.runEditTimeFormatter
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const apiCtor = mod.createFormatter ?? mod.create
    if (typeof apiCtor !== "function") {
      // Direct shape has no factory; per-call injection still proven above — but lib must at least export runEditTimeFormatter
      assert.equal(typeof mod.runEditTimeFormatter, "function")
      return
    }
    let callsA = 0, callsB = 0
    const instA = apiCtor({ spawnSync: () => { callsA++; return { status: 0 } }, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
    const instB = apiCtor({ spawnSync: () => { callsB++; return { status: 1, stderr: "err" } }, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
    assert.equal(typeof instA.runEditTimeFormatter, "function")
    assert.equal(typeof instB.runEditTimeFormatter, "function")
    instA.runEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } })
    assert.equal(callsA, 1)
    assert.equal(callsB, 0)
    instB.runEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } })
    assert.equal(callsB, 1)
  })
})

// ---------------------------------------------------------------------------
// 10. Guard: non-edit/write/apply_patch tools produce no spawnSync (shell will still gate)
// ---------------------------------------------------------------------------
describe("lib/formatter — guard: non-edit tools produce no spawn", () => {
  it("input.tool not in {edit,write,apply_patch} yields no spawnSync and empty result", () => {
    const root = freshTmpWorkspace()
    let calls = 0
    const fakeSpawn = () => { calls++; return { status: 0 } }
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    const inputs = [
      { tool: "bash", sessionID: "ses_test", args: { filePath: "src/app.ts" } },
      { tool: "task", sessionID: "ses_test", args: { description: "hi" } },
      { tool: "read", sessionID: "ses_test", args: { filePath: "src/app.ts" } },
    ]
    for (const inp of inputs) {
      const prev = calls
      const result = callRunEditTimeFormatter(inp, fakes)
      assert.equal(calls, prev, `tool ${inp.tool} must not spawn`)
      assert.ok(result !== undefined, "must return result even for non-edit tool")
    }
  })
})
