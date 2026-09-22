/**
 * lib/formatter.ts tests (DIA-260909-sazr; settled API, DI via dia-260902-eqgg).
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
 * Settled seam: runEditTimeFormatter(input, deps) direct with injected
 *   { spawnSync, existsSync?, statSync?, workspaceRoot }; pure helpers
 *   isFormatterIgnoredPath(filePath, workspaceRoot) and
 *   extractPatchPaths(patchText); factory createFormatter(deps) binds
 *   workspaceRoot for single-arg calls.
 *   Fail-soft contract: runEditTimeFormatter NEVER throws; on spawn error /
 *   non-zero exit / timeout it returns { warnNote } (per-file warnNote in
 *   results) so shell can emit single format_warn row and tuiSafeWarn
 *   without crashing.
 *
 * RUN: bun test .opencode/plugins/__tests__/formatter.test.mjs
 */

import { describe, it, afterEach, after } from "node:test"
import assert from "node:assert/strict"
import { mkdirSync, writeFileSync, existsSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { createTempWorkspace } from "./helpers/plugin-harness.mjs"
import * as mod from "../lib/formatter.ts"

// Settled DI seam: direct two-arg call; the factory-bound single-arg shape
// accepts the same call (extra deps arg is ignored by the bound closure).
function callRunEditTimeFormatter(input, fakes) {
  const fn = mod.runEditTimeFormatter
  if (typeof fn !== "function") throw new Error("runEditTimeFormatter not found")
  return fn(input, fakes)
}

// ---------------------------------------------------------------------------
// Isolated tmp fixture (Q7 §3): every file the formatter touches lives under
// a mkdtempSync(tmpdir()) workspace, never under the tracked project source.
// ---------------------------------------------------------------------------
const workspaceCleanups = []
// ponytail: per-test afterEach is node:test native; suite after() would batch cleanups to end-of-file and
// leave workspaces alive across tests (exit-handler becomes primary if it() throws before push). Use afterEach
// so each freshTmpWorkspace is torn down per test; keep after() as fail-safe for any stray push outside it().
afterEach(() => {
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch (err) {
      console.error(`[cleanup] formatter workspace cleanup failed: ${err?.message ?? err}`)
    }
  }
})
after(() => {
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch (err) {
      console.error(`[cleanup] formatter suite cleanup failed: ${err?.message ?? err}`)
    }
  }
})
function freshTmpWorkspace() {
  const { directory: dir, cleanup } = createTempWorkspace("fmt-")
  // unconditional registration before any subsequent throw in the caller it() body
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
    const set = mod.FORMATTER_EXTENSIONS
    assert.ok(set instanceof Set, "FORMATTER_EXTENSIONS must be a Set")
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
      assert.equal(fn(p, root), true, `'${p}' must be ignored (isFormatterIgnoredPath true) against root ${root}`)
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
    // Oversized files are silently skipped: no spawn, no warnNote, absent from formatted.
    assert.equal(result.warnNote, undefined, "size-skip is silent: no warnNote")
    assert.ok(!result.formatted.includes("src/big.ts"), "oversized file must not be in formatted list")
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
    const r = result.results.find(x => x.file.includes("exact.ts"))
    assert.equal(r.ok, true, "file at exactly 1 MiB must format ok")
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
    // Settled warning shape: collective warnNote plus one per-file entry.
    assert.ok(typeof result.warnNote === "string" && result.warnNote.length > 0, `must carry collective warnNote, got ${JSON.stringify(result)}`)
    assert.match(result.warnNote, /spawn ENOENT/, "warnNote must contain the spawn error")
    assert.equal(result.results.length, 1)
    assert.equal(result.results[0].ok, false)
    assert.equal(typeof result.results[0].warnNote, "string")
  })

  it("spawnSync returns non-zero status -> returns {warnNote} with exit info, never throws", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => ({ status: 1, signal: null, stderr: "prettier error", error: undefined })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes) })
    // Settled warning shape: collective warnNote plus one per-file entry.
    assert.ok(typeof result.warnNote === "string" && result.warnNote.length > 0, `must carry collective warnNote, got ${JSON.stringify(result)}`)
    assert.match(result.warnNote, /prettier exit 1/, "warnNote must carry the exit status")
    assert.equal(result.results.length, 1)
    assert.equal(result.results[0].ok, false)
    assert.equal(typeof result.results[0].warnNote, "string")
  })

  it("spawnSync result.error set -> returns warnNote", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const fakeSpawn = () => ({ status: null, error: new Error("prettier timeout"), signal: "SIGTERM" })
    const fakes = { spawnSync: fakeSpawn, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root }
    let result
    assert.doesNotThrow(() => { result = callRunEditTimeFormatter({ tool: "edit", sessionID: "ses_test", args: { filePath: "src/app.ts" } }, fakes) })
    // Settled warning shape: collective warnNote plus one per-file entry.
    assert.ok(typeof result.warnNote === "string" && result.warnNote.length > 0, `must carry collective warnNote, got ${JSON.stringify(result)}`)
    assert.match(result.warnNote, /prettier timeout/, "warnNote must carry the spawn error text")
    assert.equal(result.results.length, 1)
    assert.equal(result.results[0].ok, false)
    assert.equal(typeof result.results[0].warnNote, "string")
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
    // Settled warning shape: collective warnNote plus one per-file entry each
    // carrying its own warnNote (format_warn row cardinality 1:1).
    assert.ok(typeof result.warnNote === "string" && result.warnNote.length > 0, "collective warnNote must be present")
    assert.equal(result.results.length, 2, "2 files => 2 result entries")
    for (const r of result.results) {
      assert.equal(r.ok, false, `failing file ${r.file} must have ok:false`)
      assert.equal(typeof r.warnNote, "string", `failing file ${r.file} must carry warnNote`)
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
    const r = result.results[0]
    assert.equal(r.ok, true)
    assert.equal(r.warnNote, undefined)
    assert.equal(result.warnNote, undefined, "success must not have top-level warnNote")
  })
})

// ---------------------------------------------------------------------------
// 8. Uses isolated tmp fixture not tracked source (Q7 §3)
// ---------------------------------------------------------------------------
describe("lib/formatter — uses isolated tmp fixture not tracked source (Q7 §3)", () => {
  it("tmp fixture path is under os.tmpdir(), not under workspace/.opencode/plugins or tracked source", () => {
    assert.equal(mod.FORMATTER_MAX_BYTES, 1024 * 1024, "lib constants must be present")
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

  it("factory seam is injectable per-test — different factories yield isolated instances", () => {
    const root = freshTmpWorkspace()
    mkdirSync(join(root, "src"), { recursive: true })
    writeFileSync(join(root, "src/app.ts"), "x")
    const apiCtor = mod.createFormatter
    let callsA = 0, callsB = 0
    const instA = apiCtor({ spawnSync: () => { callsA++; return { status: 0 } }, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
    const instB = apiCtor({ spawnSync: () => { callsB++; return { status: 1, stderr: "err" } }, existsSync: () => true, statSync: () => ({ size: 100 }), workspaceRoot: root })
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
