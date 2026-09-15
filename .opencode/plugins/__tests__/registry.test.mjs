/**
 * lib/registry.ts tests (DIA-260909-sazr; settled API, DI via dia-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts seam:
 *   appendRow (seq = maxRegistrySeq()+1 at write time, timestamp, group_key synthetic, fail-soft),
 *   appendMessageRow (row_id = MAX(maxRowIdInJsonl, lastMessagesMdRowNumber)+1 at write time, event_uuid, timestamp, gen_ai.provider.name, writer),
 *   maxRowIdInJsonl / lastMessagesMdRowNumber / maxRegistrySeq (malformed line skip, MAX seq vs lineCount),
 *   captureConfigLoadSignal (mtimes before I/O, statSync on .opencode/opencode.jsonc + oh-my-opencode-slim.jsonc),
 *   atomicWriteBootMarker (shares bootId/seq with registry session_boot row, same fsync discipline tmp->fsync->rename->fsync-dir, boot.json fields)
 *
 * Learnings: .opencode/learnings/external-patterns/2026-09-02-opencode-plugin-loader-contract.md
 *   lib is pure/DI'd (inject fs fakes), no ctx capture, no shell import;
 *   registry lib is the SINGLE writer of registry.jsonl/messages.jsonl;
 *   boot.json shares bootId/seq with registry session_boot row.
 *
 * Settled seam: createRegistry(deps) factory with injected fs/path/clock/
 * randomUUID fakes plus registry/messages/boot path overrides.
 *
 *   createRegistry(deps: {
 *     fs: { appendFileSync, readFileSync, existsSync, writeFileSync, openSync,
 *       fsyncSync, closeSync, renameSync, mkdirSync, unlinkSync, statSync },
 *     path?: { join, dirname },
 *     clock?: { now, isoNow },
 *     randomUUID?: () => string,
 *     directory?: string, registryPath?: string, messagesPath?: string,
 *     messagesMdPath?: string, bootPath?: string, bootTmpPath?: string,
 *     handoffDir?: string, processStartedAt?: string, opencodeVersion?: string,
 *   }) => { appendRow, appendMessageRow, captureConfigLoadSignal,
 *     atomicWriteBootMarker, maxRowIdInJsonl, lastMessagesMdRowNumber,
 *     maxRegistrySeq }
 *
 * RUN: cd .opencode/plugins && bun test ./__tests__/registry.test.mjs
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { readFileSync as nodeReadFileSync } from "node:fs"
import * as nodeFs from "node:fs"
import { tmpdir } from "node:os"
import { join as nodeJoin } from "node:path"
import { createHash } from "node:crypto"
import * as mod from "../lib/registry.ts"

// Settled DI seam: direct factory use only.
function tryFactory(deps) {
  return mod.createRegistry(deps)
}

// ---------------------------------------------------------------------------
// RED-D: canonical durable stall compare-and-append boundary
// ---------------------------------------------------------------------------
describe("RED-D — registry locked stall compare-and-append", () => {
  function realRegistry(root) {
    const session = nodeJoin(root, ".opencode/session")
    nodeFs.mkdirSync(session, { recursive: true })
    return mod.createRegistry({
      directory: root,
      registryPath: nodeJoin(session, "registry.jsonl"),
      messagesPath: nodeJoin(session, "messages.jsonl"),
      messagesMdPath: nodeJoin(session, "messages.md"),
      registrySeqPath: nodeJoin(session, "registry.seq"),
      messagesRowIdPath: nodeJoin(session, "messages.row-id"),
      journalLockPath: nodeJoin(session, "journal.lock"),
    })
  }

  function candidate(generation) {
    return {
      session_id: "ses_cross_process",
      lifecycle_generation: generation,
      tier: "dead",
      row: {
        event: "stall_detected",
        escalation: "dead",
        session_id: "ses_cross_process",
        lifecycle_generation: generation,
        dispatch_state: "running",
      },
    }
  }

  it("two Bun processes racing the same generation/tier persist exactly one row", async () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-stall-race-"))
    const moduleUrl = new URL("../lib/registry.ts", import.meta.url).href
    const childSource = `
      import { createRegistry } from ${JSON.stringify(moduleUrl)};
      import * as fs from "node:fs";
      const root = process.env.TQOR_STALL_ROOT;
      const session = root + "/.opencode/session";
      fs.mkdirSync(session, { recursive: true });
      const registry = createRegistry({
        directory: root,
        registryPath: session + "/registry.jsonl",
        messagesPath: session + "/messages.jsonl",
        messagesMdPath: session + "/messages.md",
        registrySeqPath: session + "/registry.seq",
        messagesRowIdPath: session + "/messages.row-id",
        journalLockPath: session + "/journal.lock",
      });
      process.stdout.write("READY\\n");
      fs.readFileSync(0, "utf8");
      let result;
      try {
        result = registry.compareAndAppendStall({
          session_id: "ses_cross_process",
          lifecycle_generation: 7,
          tier: "dead",
          row: { event: "stall_detected", escalation: "dead", session_id: "ses_cross_process", lifecycle_generation: 7, dispatch_state: "running" },
        });
      } catch (error) {
        result = { ok: false, stage: "api", error: error instanceof Error ? error.message : String(error) };
      }
      process.stdout.write("RESULT " + JSON.stringify(result) + "\\n");
    `

    async function launch() {
      const child = globalThis.Bun.spawn([process.execPath, "--eval", childSource], {
        cwd: new URL("..", import.meta.url).pathname,
        env: { ...process.env, TQOR_STALL_ROOT: root },
        stdin: "pipe",
        stdout: "pipe",
        stderr: "pipe",
      })
      const reader = child.stdout.getReader()
      const first = await reader.read()
      const ready = new TextDecoder().decode(first.value)
      assert.match(ready, /READY/, "child must reach the deterministic start barrier")
      return { child, reader, prefix: ready }
    }

    async function release(handle) {
      handle.child.stdin.write("go")
      handle.child.stdin.end()
      let output = handle.prefix
      const decoder = new TextDecoder()
      for (;;) {
        const chunk = await handle.reader.read()
        if (chunk.done) break
        output += decoder.decode(chunk.value, { stream: true })
      }
      const code = await handle.child.exited
      const stderr = await new Response(handle.child.stderr).text()
      assert.equal(code, 0, `child process failed: ${stderr}`)
      return JSON.parse(output.match(/RESULT (.+)/)?.[1] ?? "null")
    }

    try {
      const left = await launch()
      const right = await launch()
      const [leftResult, rightResult] = await Promise.all([release(left), release(right)])
      assert.equal([leftResult, rightResult].filter((result) => result?.ok === true).length, 1, "named RED: exactly one racing writer must append")
      assert.equal([leftResult, rightResult].filter((result) => result?.reason === "duplicate").length, 1, "named RED: the losing writer must receive a durable duplicate result")
      const path = nodeJoin(root, ".opencode/session/registry.jsonl")
      const rows = nodeFs.readFileSync(path, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse)
      assert.equal(rows.filter((row) => row.event === "stall_detected" && row.session_id === "ses_cross_process" && row.lifecycle_generation === 7 && row.escalation === "dead").length, 1)
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })

  it("fresh registry instances suppress a durable tier but allow a new generation", () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-stall-restart-"))
    try {
      const first = realRegistry(root)
      assert.equal(typeof first.compareAndAppendStall, "function", "named RED: registry must export compareAndAppendStall")
      assert.equal(first.compareAndAppendStall(candidate(7)).ok, true)

      const restarted = realRegistry(root)
      const duplicate = restarted.compareAndAppendStall(candidate(7))
      assert.equal(duplicate.ok, false, "restart must suppress the durable generation/tier")
      assert.equal(duplicate.reason, "duplicate")
      assert.equal(restarted.compareAndAppendStall(candidate(8)).ok, true, "explicit recovery/new generation permits a new tier")
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })

  it("RED-E: returns discriminated lock, counter, append, and index failures", () => {
    const registryPath = "/workspace/.opencode/session/registry.jsonl"
    const lockPath = "/workspace/.opencode/session/journal.lock"
    const baseCandidate = {
      session_id: "ses_failure_stages",
      lifecycle_generation: 1,
      tier: "dead",
      row: { event: "stall_detected", escalation: "dead", session_id: "ses_failure_stages", lifecycle_generation: 1, dispatch_state: "running" },
    }

    const lockedFs = makeFakeFs({ [lockPath]: JSON.stringify({ pid: 777, startedAt: "owner", leaseDeadline: 9000 }) })
    const locked = mod.createRegistry({
      ...makeRegistryDepsForRedE(lockedFs),
      processIdentity: { pid: 888, startedAt: "contender" },
      isProcessAlive: () => true,
      clock: { now: () => 2000, isoNow: () => "2026-09-15T00:00:02.000Z" },
    })
    const lockResult = locked.compareAndAppendStall(baseCandidate)

    const counterFs = makeFakeFs({}, { renameShouldThrow: "counter publication failed" })
    const counterResult = makeRegistry(counterFs).compareAndAppendStall(baseCandidate)

    const appendFs = makeFakeFs({})
    appendFs.appendFileSync = (path, data) => {
      if (path === registryPath) throw new Error("append failed")
      const previous = appendFs.files.get(path) ?? ""
      appendFs.files.set(path, previous + data)
    }
    const appendResult = makeRegistry(appendFs).compareAndAppendStall(baseCandidate)

    const indexFs = makeFakeFs({
      [registryPath]: JSON.stringify({ seq: 1, session_id: "ses_existing", lifecycle_generation: 1, event: "dispatch", dispatch_state: "running" }) + "\n",
    })
    const indexResult = makeRegistry(indexFs, { activeLifecycleMaxEntries: 1 }).compareAndAppendStall(baseCandidate)

    assert.deepEqual(
      [lockResult?.stage, counterResult?.stage, appendResult?.stage, indexResult?.stage],
      ["lock", "counter", "append", "index"],
      "named RED-E: compare-and-append failures must preserve their actual stage",
    )
  })
})

// ---------------------------------------------------------------------------
// RED-F: explicit operator-invoked rotation (DIA-260914-tqor)
// ---------------------------------------------------------------------------
describe("RED-F — verified registry rotation", () => {
  function rotationFixture() {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-rotation-"))
    const session = nodeJoin(root, ".opencode/session")
    const archive = nodeJoin(session, "registry-archive")
    nodeFs.mkdirSync(session, { recursive: true })
    const source = [
      JSON.stringify({ seq: 4, event: "session_spawn", session_id: "ses_live", lifecycle_generation: 4, dispatch_state: "running" }),
      "legacy malformed row {{{",
      JSON.stringify({ seq: 9, event: "task_success", session_id: "ses_done", lifecycle_generation: 7, dispatch_state: "completed" }),
      JSON.stringify({ seq: 12, event: "stopped-without-result", session_id: "ses_tombstone", lifecycle_generation: 12, terminalUnreconciled: true }),
    ].join("\n") + "\n"
    const registryPath = nodeJoin(session, "registry.jsonl")
    const messagesPath = nodeJoin(session, "messages.jsonl")
    const messagesMdPath = nodeJoin(session, "messages.md")
    nodeFs.writeFileSync(registryPath, source)
    nodeFs.writeFileSync(messagesPath, JSON.stringify({ row_id: 21, event: "message" }) + "\n")
    nodeFs.writeFileSync(messagesMdPath, "| 33 | legacy message |\n")
    const make = () => mod.createRegistry({
      directory: root,
      registryPath,
      messagesPath,
      messagesMdPath,
      registrySeqPath: nodeJoin(session, "registry.seq"),
      messagesRowIdPath: nodeJoin(session, "messages.row-id"),
      journalLockPath: nodeJoin(session, "journal.lock"),
      archiveDir: archive,
    })
    return { root, session, archive, registryPath, messagesPath, make, source }
  }

  function requireRotation(registry) {
    assert.equal(typeof registry.rotateRegistry, "function", "RED-F: registry must expose explicit rotateRegistry operator boundary")
    return registry.rotateRegistry()
  }

  it("creates an immutable byte-preserving archive and verified manifest while retaining live/tombstone rows", () => {
    const fixture = rotationFixture()
    try {
      const result = requireRotation(fixture.make())
      assert.equal(result.ok, true, "RED-F: rotation must publish only after archive verification")
      assert.ok(result.archivePath)
      assert.ok(result.manifestPath)
      const archived = nodeFs.readFileSync(result.archivePath)
      assert.equal(archived.toString(), fixture.source, "RED-F: archive must preserve exact source bytes")
      const manifest = JSON.parse(nodeFs.readFileSync(result.manifestPath, "utf8"))
      assert.equal(manifest.sha256, createHash("sha256").update(archived).digest("hex"))
      const active = nodeFs.readFileSync(fixture.registryPath, "utf8")
      assert.match(active, /ses_live/)
      assert.match(active, /ses_tombstone/)
      assert.match(active, /registry_rotated/)
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("preserves registry and message counter high-water marks and appends rotation only after publication", () => {
    const fixture = rotationFixture()
    try {
      const registry = fixture.make()
      const result = requireRotation(registry)
      assert.equal(result.ok, true, "RED-F: rotation must succeed")
      const nextRegistry = registry.appendRow({ event: "after_rotation" })
      const nextMessage = registry.appendMessageRow({ event: "after_rotation_message" })
      assert.equal(nextRegistry.id > 12, true, "RED-F: registry seq must not decrease after rotation")
      assert.equal(nextMessage.id > 33, true, "RED-F: message row_id must not decrease after rotation")
      const rows = nodeFs.readFileSync(fixture.registryPath, "utf8").trim().split("\n").map(JSON.parse)
      assert.equal(rows.filter((row) => row.event === "registry_rotated").length, 1)
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("recreates the registry after rotation without lowering either durable sidecar high-water mark", () => {
    const fixture = rotationFixture()
    try {
      const first = fixture.make()
      const rotated = requireRotation(first)
      assert.equal(rotated.ok, true, "RED-F: rotation must succeed before restart check")
      const restarted = fixture.make()
      const registry = restarted.appendRow({ event: "post_restart_registry" })
      const message = restarted.appendMessageRow({ event: "post_restart_message" })
      assert.ok(registry.id > 12, "RED-F: registry seq sidecar must survive restart")
      assert.ok(message.id > 33, "RED-F: message row_id sidecar must survive restart")
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("serializes rotation with a concurrent append and leaves one authoritative active file", () => {
    const fixture = rotationFixture()
    try {
      const registry = fixture.make()
      const append = registry.appendRow({ event: "concurrent_append", session_id: "ses_live" })
      const rotation = requireRotation(registry)
      assert.equal(append.ok, true, "RED-F: append must serialize with rotation")
      assert.equal(rotation.ok, true, "RED-F: rotation must serialize with append")
      const rows = nodeFs.readFileSync(fixture.registryPath, "utf8").trim().split("\n").map(JSON.parse)
      assert.ok(rows.some((row) => row.event === "concurrent_append") || rows.some((row) => row.event === "registry_rotated"))
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("fails closed on publication failures without replacing the original active registry", () => {
    const fixture = rotationFixture()
    try {
      const registry = mod.createRegistry({
        directory: fixture.root,
        registryPath: fixture.registryPath,
        messagesPath: fixture.messagesPath,
        messagesMdPath: nodeJoin(fixture.session, "messages.md"),
        registrySeqPath: nodeJoin(fixture.session, "registry.seq"),
        messagesRowIdPath: nodeJoin(fixture.session, "messages.row-id"),
        journalLockPath: nodeJoin(fixture.session, "journal.lock"),
        archiveDir: fixture.archive,
        fs: { ...nodeFs, renameSync() { throw new Error("RED-F injected rename failure") } },
      })
      assert.equal(typeof registry.rotateRegistry, "function", "RED-F: failure test requires rotation boundary")
      const result = registry.rotateRegistry()
      assert.equal(result.ok, false, "RED-F: rotation failure must fail closed")
      assert.equal(nodeFs.readFileSync(fixture.registryPath, "utf8"), fixture.source)
      assert.doesNotMatch(nodeFs.readFileSync(fixture.registryPath, "utf8"), /registry_rotated/)
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("publishes an explicit manifest with archive identity, counts, sequence range, malformed rows, and bytes", () => {
    const fixture = rotationFixture()
    try {
      const result = requireRotation(fixture.make())
      assert.equal(result.ok, true, "RED-F: verified rotation must succeed")
      const archiveName = nodeFs.realpathSync(result.archivePath).split("/").pop()
      const manifest = JSON.parse(nodeFs.readFileSync(result.manifestPath, "utf8"))
      assert.equal(manifest.archive, archiveName, "RED-F: manifest must identify the published archive exactly")
      assert.equal(manifest.byte_count, Buffer.byteLength(fixture.source))
      assert.equal(manifest.row_count, 3, "RED-F: malformed line is not a valid row")
      assert.equal(manifest.malformed_row_count, 1)
      assert.equal(manifest.first_seq, 4)
      assert.equal(manifest.last_seq, 12)
      assert.equal(manifest.sha256, createHash("sha256").update(fixture.source).digest("hex"))
      assert.equal(createHash("sha256").update(nodeFs.readFileSync(result.archivePath)).digest("hex"), manifest.sha256, "RED-F: independent archive read must retain integrity")
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("retains pending, recoverable, and unreconciled lifecycle rows while removing terminal history", () => {
    const fixture = rotationFixture()
    const extra = [
      JSON.stringify({ seq: 13, event: "needs_input", session_id: "ses_pending", lifecycle_generation: 13, dispatch_state: "pending" }),
      JSON.stringify({ seq: 14, event: "resume_available", session_id: "ses_recoverable", lifecycle_generation: 14, recoverable: true }),
      JSON.stringify({ seq: 15, event: "stopped-without-result", session_id: "ses_unreconciled", lifecycle_generation: 15, terminalUnreconciled: true }),
    ].join("\n") + "\n"
    nodeFs.appendFileSync(fixture.registryPath, extra)
    try {
      const result = requireRotation(fixture.make())
      assert.equal(result.ok, true, "RED-F: rotation must succeed")
      const active = nodeFs.readFileSync(fixture.registryPath, "utf8")
      assert.match(active, /ses_pending/)
      assert.match(active, /ses_recoverable/)
      assert.match(active, /ses_unreconciled/)
      assert.doesNotMatch(active, /ses_done/)
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("uses the shared lock for a true cross-process append-versus-rotate race", async () => {
    const fixture = rotationFixture()
    const moduleUrl = new URL("../lib/registry.ts", import.meta.url).href
    const childSource = `
      import { createRegistry } from ${JSON.stringify(moduleUrl)};
      import * as fs from "node:fs";
      const root = process.env.TQOR_ROTATION_ROOT;
      const session = root + "/.opencode/session";
      const registry = createRegistry({ directory: root, registryPath: session + "/registry.jsonl", messagesPath: session + "/messages.jsonl", messagesMdPath: session + "/messages.md", registrySeqPath: session + "/registry.seq", messagesRowIdPath: session + "/messages.row-id", journalLockPath: session + "/journal.lock", archiveDir: session + "/registry-archive" });
      process.stdout.write("READY\\n");
      fs.readFileSync(0, "utf8");
      let result;
      try { result = process.env.TQOR_ROTATE === "1" ? registry.rotateRegistry() : registry.appendRow({ event: "cross_process_append", session_id: "ses_live" }); }
      catch (error) { result = { ok: false, error: error instanceof Error ? error.message : String(error) }; }
      process.stdout.write("RESULT " + JSON.stringify(result) + "\\n");
    `
    function spawn(role) {
      const child = globalThis.Bun.spawn([process.execPath, "--eval", childSource], { cwd: new URL("..", import.meta.url).pathname, env: { ...process.env, TQOR_ROTATION_ROOT: fixture.root, TQOR_ROTATE: role }, stdin: "pipe", stdout: "pipe", stderr: "pipe" })
      return { child, reader: child.stdout.getReader() }
    }
    async function ready(handle) {
      const chunk = await handle.reader.read()
      assert.match(new TextDecoder().decode(chunk.value), /READY/)
    }
    async function release(handle) {
      handle.child.stdin.write("go")
      handle.child.stdin.end()
      let output = ""
      const decoder = new TextDecoder()
      for (;;) { const chunk = await handle.reader.read(); if (chunk.done) break; output += decoder.decode(chunk.value) }
      assert.equal(await handle.child.exited, 0)
      return JSON.parse(output.match(/RESULT (.+)/)?.[1] ?? "null")
    }
    try {
      const append = spawn("0")
      const rotate = spawn("1")
      await Promise.all([ready(append), ready(rotate)])
      const [appendResult, rotateResult] = await Promise.all([release(append), release(rotate)])
      assert.equal(appendResult.ok, true, "RED-F: append must complete under shared lock")
      assert.equal(rotateResult.ok, true, "RED-F: rotate must complete under shared lock")
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("fails closed at distinct pre-replacement publication stages and emits no success row", () => {
    const stages = ["copy", "archive fsync", "checksum", "manifest write", "manifest fsync", "verification", "archive publish", "manifest publish", "active replacement"]
    for (const stage of stages) {
      const fixture = rotationFixture()
      try {
        const failingFs = { ...nodeFs }
        const fdPaths = new Map()
        const readCounts = new Map()
        const originalOpen = nodeFs.openSync
        failingFs.openSync = (path, flags) => { const fd = originalOpen(path, flags); fdPaths.set(fd, path); return fd }
        failingFs.readFileSync = (path, encoding) => {
          const count = (readCounts.get(path) ?? 0) + 1
          readCounts.set(path, count)
          if (stage === "checksum" && path.endsWith(".jsonl.tmp") && count === 1) throw new Error("RED-F injected checksum failure")
          if (stage === "verification" && path.endsWith(".jsonl.tmp") && count === 2) throw new Error("RED-F injected verification failure")
          return nodeFs.readFileSync(path, encoding)
        }
        failingFs.writeFileSync = (path, data) => {
          if (stage === "copy" && path.endsWith(".jsonl.tmp")) throw new Error("RED-F injected copy failure")
          if (stage === "manifest write" && path.endsWith(".manifest.json.tmp")) throw new Error("RED-F injected manifest write failure")
          return nodeFs.writeFileSync(path, data)
        }
        failingFs.fsyncSync = (fd) => {
          const openedPath = fdPaths.get(fd) ?? ""
          if (stage === "archive fsync" && openedPath.endsWith(".jsonl.tmp")) throw new Error("RED-F injected archive fsync failure")
          if (stage === "manifest fsync" && openedPath.endsWith(".manifest.json.tmp")) throw new Error("RED-F injected manifest fsync failure")
          return nodeFs.fsyncSync(fd)
        }
        failingFs.renameSync = (from, to) => {
          if (stage === "archive publish" && from.endsWith(".jsonl.tmp") && to.endsWith(".jsonl")) throw new Error("RED-F injected archive publish failure")
          if (stage === "manifest publish" && from.endsWith(".manifest.json.tmp") && to.endsWith(".manifest.json")) throw new Error("RED-F injected manifest publish failure")
          if (stage === "active replacement" && to === fixture.registryPath) throw new Error("RED-F injected active replacement failure")
          return nodeFs.renameSync(from, to)
        }
        const registry = mod.createRegistry({ directory: fixture.root, registryPath: fixture.registryPath, messagesPath: fixture.messagesPath, messagesMdPath: nodeJoin(fixture.session, "messages.md"), registrySeqPath: nodeJoin(fixture.session, "registry.seq"), messagesRowIdPath: nodeJoin(fixture.session, "messages.row-id"), journalLockPath: nodeJoin(fixture.session, "journal.lock"), archiveDir: fixture.archive, fs: failingFs })
        assert.equal(typeof registry.rotateRegistry, "function", `RED-F ${stage}: rotation boundary required`)
        const result = registry.rotateRegistry()
        assert.equal(result.ok, false, `RED-F ${stage}: failure must fail closed`)
        assert.equal(nodeFs.readFileSync(fixture.registryPath, "utf8"), fixture.source)
        assert.doesNotMatch(nodeFs.readFileSync(fixture.registryPath, "utf8"), /registry_rotated/)
      } finally {
        nodeFs.rmSync(fixture.root, { recursive: true, force: true })
      }
    }
  })

  it("restores the original authoritative registry after post-replacement failures", () => {
    const stages = ["index rebuild", "counter publication", "rotation event append"]
    for (const stage of stages) {
      const fixture = rotationFixture()
      try {
        const failingFs = { ...nodeFs }
        let activeReplaced = false
        failingFs.renameSync = (from, to) => {
          if (to === fixture.registryPath) activeReplaced = true
          if (stage === "counter publication" && activeReplaced && to.endsWith("registry.seq")) throw new Error("RED-F injected counter publication failure")
          return nodeFs.renameSync(from, to)
        }
        failingFs.statSync = (path) => {
          if (stage === "index rebuild" && activeReplaced && path === fixture.registryPath) throw new Error("RED-F injected index rebuild failure")
          return nodeFs.statSync(path)
        }
        failingFs.appendFileSync = (path, data) => {
          if (stage === "rotation event append" && activeReplaced && path === fixture.registryPath && String(data).includes('"event":"registry_rotated"')) throw new Error("RED-F injected rotation event append failure")
          return nodeFs.appendFileSync(path, data)
        }
        const registry = mod.createRegistry({ directory: fixture.root, registryPath: fixture.registryPath, messagesPath: fixture.messagesPath, messagesMdPath: nodeJoin(fixture.session, "messages.md"), registrySeqPath: nodeJoin(fixture.session, "registry.seq"), messagesRowIdPath: nodeJoin(fixture.session, "messages.row-id"), journalLockPath: nodeJoin(fixture.session, "journal.lock"), archiveDir: fixture.archive, fs: failingFs })
        const result = registry.rotateRegistry()
        assert.equal(result.ok, false, `RED-F ${stage}: failure must fail closed`)
        const active = nodeFs.readFileSync(fixture.registryPath, "utf8")
        assert.equal(active, fixture.source, `RED-F ${stage}: original active registry must be restored`)
        assert.doesNotMatch(active, /registry_rotated/)
      } finally {
        nodeFs.rmSync(fixture.root, { recursive: true, force: true })
      }
    }
  })

  it("appends registry_rotated only after archive, manifest, and active replacement publication", () => {
    const fixture = rotationFixture()
    const operations = []
    try {
      const observedFs = { ...nodeFs }
      observedFs.renameSync = (from, to) => { operations.push(["rename", from, to]); return nodeFs.renameSync(from, to) }
      observedFs.appendFileSync = (path, data) => { if (String(data).includes('"event":"registry_rotated"')) operations.push(["rotation-event", path]); return nodeFs.appendFileSync(path, data) }
      const registry = mod.createRegistry({ directory: fixture.root, registryPath: fixture.registryPath, messagesPath: fixture.messagesPath, messagesMdPath: nodeJoin(fixture.session, "messages.md"), registrySeqPath: nodeJoin(fixture.session, "registry.seq"), messagesRowIdPath: nodeJoin(fixture.session, "messages.row-id"), journalLockPath: nodeJoin(fixture.session, "journal.lock"), archiveDir: fixture.archive, fs: observedFs })
      assert.equal(registry.rotateRegistry().ok, true)
      const eventIndex = operations.findIndex(([operation]) => operation === "rotation-event")
      const archiveIndex = operations.findIndex(([operation, from]) => operation === "rename" && from.endsWith(".jsonl.tmp"))
      const manifestIndex = operations.findIndex(([operation, from]) => operation === "rename" && from.endsWith(".manifest.json.tmp"))
      const activeIndex = operations.findIndex(([operation, , to]) => operation === "rename" && to === fixture.registryPath)
      assert.ok(eventIndex > archiveIndex && eventIndex > manifestIndex && eventIndex > activeIndex, "RED-F: success event must follow all verified publications")
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("archives the exact source bytes even when malformed input contains non-UTF8 octets", () => {
    const fixture = rotationFixture()
    const binarySource = Buffer.concat([
      Buffer.from(JSON.stringify({ seq: 41, event: "session_spawn", session_id: "ses_binary", lifecycle_generation: 41, dispatch_state: "running" }) + "\n"),
      Buffer.from([0xff, 0xfe, 0x00, 0x80, 0x0a]),
      Buffer.from(JSON.stringify({ seq: 42, event: "task_success", session_id: "ses_old", dispatch_state: "completed" }) + "\n"),
    ])
    nodeFs.writeFileSync(fixture.registryPath, binarySource)
    try {
      const result = fixture.make().rotateRegistry()
      assert.equal(result.ok, true, "RED-F: binary source rotation must succeed")
      assert.deepEqual(nodeFs.readFileSync(result.archivePath), binarySource, "RED-F: archive must preserve the exact source Buffer")
    } finally {
      nodeFs.rmSync(fixture.root, { recursive: true, force: true })
    }
  })

  it("derives all sidecars from explicit temp registry/messages/archive paths and leaves repo session sidecars unchanged", () => {
    const repo = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-repo-sidecars-"))
    const temp = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-temp-sidecars-"))
    const repoSession = nodeJoin(repo, ".opencode/session")
    const tempArchive = nodeJoin(temp, "registry-archive")
    nodeFs.mkdirSync(repoSession, { recursive: true })
    nodeFs.writeFileSync(nodeJoin(repoSession, "registry.seq"), "100\n")
    nodeFs.writeFileSync(nodeJoin(repoSession, "messages.row-id"), "200\n")
    try {
      const registry = mod.createRegistry({
        directory: repo,
        registryPath: nodeJoin(temp, "registry.jsonl"),
        messagesPath: nodeJoin(temp, "messages.jsonl"),
        messagesMdPath: nodeJoin(temp, "messages.md"),
        archiveDir: tempArchive,
      })
      assert.equal(registry.appendRow({ event: "temp-registry" })?.ok, true)
      assert.equal(registry.appendMessageRow({ event_type: "temp-message" })?.ok, true)

      assert.equal(nodeFs.readFileSync(nodeJoin(repoSession, "registry.seq"), "utf8"), "100\n", "repo registry.seq must not be touched by temp registry")
      assert.equal(nodeFs.readFileSync(nodeJoin(repoSession, "messages.row-id"), "utf8"), "200\n", "repo messages.row-id must not be touched by temp messages")
      assert.equal(nodeFs.existsSync(nodeJoin(repoSession, "journal.lock")), false, "repo journal.lock must not be used for temp paths")
      assert.equal(Number(nodeFs.readFileSync(nodeJoin(temp, "registry.seq"), "utf8")), 1, "temp registry.seq is derived beside explicit registry path")
      assert.equal(Number(nodeFs.readFileSync(nodeJoin(temp, "messages.row-id"), "utf8")), 1, "temp messages.row-id is derived beside explicit messages path")
      assert.equal(nodeFs.existsSync(nodeJoin(temp, "journal.lock")), false, "temp journal.lock is cleaned after use")
    } finally {
      nodeFs.rmSync(repo, { recursive: true, force: true })
      nodeFs.rmSync(temp, { recursive: true, force: true })
    }
  })

  it("rejects split-parent explicit paths instead of mixing temp files with repo sidecars", () => {
    const repo = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-split-repo-"))
    const temp = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-split-temp-"))
    try {
      assert.throws(
        () => mod.createRegistry({
          directory: repo,
          registryPath: nodeJoin(temp, "registry.jsonl"),
          messagesPath: nodeJoin(repo, ".opencode/session/messages.jsonl"),
        }),
        /split-parent|same parent|sidecar|explicit/i,
        "registry and messages paths from different parents must fail closed",
      )
      assert.throws(
        () => mod.createRegistry({
          directory: repo,
          registryPath: nodeJoin(temp, "registry.jsonl"),
          messagesPath: nodeJoin(temp, "messages.jsonl"),
          archiveDir: nodeJoin(repo, ".opencode/session/registry-archive"),
        }),
        /split-parent|same parent|sidecar|explicit/i,
        "archive path from a different parent must fail closed",
      )
      assert.doesNotThrow(() => mod.createRegistry({
        directory: repo,
        registryPath: nodeJoin(temp, "registry.jsonl"),
        messagesPath: nodeJoin(temp, "messages.jsonl"),
      }), "matching explicit registry/messages parent may derive sidecars")
      assert.doesNotThrow(() => mod.createRegistry({
        directory: repo,
        messagesPath: nodeJoin(temp, "messages.jsonl"),
        messagesMdPath: nodeJoin(temp, "messages.md"),
      }), "helper-only message path overrides remain allowed")
    } finally {
      nodeFs.rmSync(repo, { recursive: true, force: true })
      nodeFs.rmSync(temp, { recursive: true, force: true })
    }
  })
})

function makeRegistryDepsForRedE(fakeFs) {
  return {
    fs: fakeFs,
    path: fakePath(),
    randomUUID: () => "red-e-uuid",
    directory: "/workspace",
    registryPath: "/workspace/.opencode/session/registry.jsonl",
    messagesPath: "/workspace/.opencode/session/messages.jsonl",
    messagesMdPath: "/workspace/.opencode/session/messages.md",
    bootPath: "/workspace/.opencode/session/boot.json",
    bootTmpPath: "/workspace/.opencode/session/.boot.json.tmp",
    handoffDir: "/workspace/.opencode/session",
    registrySeqPath: "/workspace/.opencode/session/registry.seq",
    messagesRowIdPath: "/workspace/.opencode/session/messages.row-id",
    journalLockPath: "/workspace/.opencode/session/journal.lock",
    processStartedAt: "2026-09-15T00:00:00.000Z",
  }
}



// ---------------------------------------------------------------------------
// Fake FS builder (injectable per design.md)
// ---------------------------------------------------------------------------
function makeFakeFs(initialFiles = {}, opts = {}) {
  const files = new Map(Object.entries(initialFiles))
  const calls = []
  const dirs = new Set()
  const mtimes = opts.mtimes ?? {} // path -> mtimeMs
  const sizes = opts.sizes ?? {}
  let nextFd = 100

  const fs = {
    files, calls, dirs, mtimes,
    appendFileSync(p, data) {
      calls.push(["appendFileSync", p])
      const prev = files.get(p) ?? ""
      files.set(p, prev + data)
    },
    readFileSync(p) {
      calls.push(["readFileSync", p])
      if (!files.has(p)) {
        const err = new Error(`ENOENT: no such file '${p}'`)
        err.code = "ENOENT"
        throw err
      }
      return files.get(p)
    },
    existsSync(p) {
      calls.push(["existsSync", p])
      return files.has(p) || dirs.has(p)
    },
    writeFileSync(p, data) {
      calls.push(["writeFileSync", p])
      files.set(p, data)
    },
    openSync(p, flags) {
      calls.push(["openSync", p, flags])
      const fd = nextFd++
      return fd
    },
    fsyncSync(fd) {
      calls.push(["fsyncSync", fd])
    },
    closeSync(fd) {
      calls.push(["closeSync", fd])
    },
    renameSync(src, dst) {
      calls.push(["renameSync", src, dst])
      if (opts.renameShouldThrow) throw new Error(opts.renameShouldThrow)
      if (!files.has(src)) {
        // tmp file must exist — create empty if not for test leniency
        files.set(src, files.get(src) ?? "")
      }
      const data = files.get(src)
      files.delete(src)
      files.set(dst, data)
    },
    mkdirSync(p) {
      calls.push(["mkdirSync", p])
      dirs.add(p)
    },
    unlinkSync(p) {
      calls.push(["unlinkSync", p])
      files.delete(p)
    },
    statSync(p) {
      calls.push(["statSync", p])
      if (opts.statShouldThrow) throw new Error(opts.statShouldThrow)
      if (mtimes[p] !== undefined) {
        return { mtimeMs: mtimes[p], size: sizes[p] ?? 100, isFile: () => true }
      }
      if (files.has(p)) {
        return { mtimeMs: Date.now(), size: (files.get(p) ?? "").length, isFile: () => true }
      }
      // for existence check of config files, throw if not in mtimes and not in files
      const err = new Error(`ENOENT stat '${p}'`)
      err.code = "ENOENT"
      throw err
    },
  }
  return fs
}

function fakePath() {
  return {
    join: (...parts) => parts.join("/").replace(/\/+/g, "/"),
    dirname: (p) => p.split("/").slice(0, -1).join("/") || "/",
  }
}

// Helper to build a registry factory instance with fakes.
function makeRegistry(fakeFs, extra = {}) {
  const deps = {
    fs: fakeFs,
    path: fakePath(),
    randomUUID: extra.randomUUID ?? (() => "test-uuid-0001"),
    clock: extra.clock,
    directory: extra.directory ?? "/workspace",
    registryPath: extra.registryPath ?? "/workspace/.opencode/session/registry.jsonl",
    messagesPath: extra.messagesPath ?? "/workspace/.opencode/session/messages.jsonl",
    messagesMdPath: extra.messagesMdPath ?? "/workspace/.opencode/session/messages.md",
    bootPath: extra.bootPath ?? "/workspace/.opencode/session/boot.json",
    bootTmpPath: extra.bootTmpPath ?? "/workspace/.opencode/session/.boot.json.tmp",
    handoffDir: extra.handoffDir ?? "/workspace/.opencode/session",
    registrySeqPath: extra.registrySeqPath ?? "/workspace/.opencode/session/registry.seq",
    messagesRowIdPath: extra.messagesRowIdPath ?? "/workspace/.opencode/session/messages.row-id",
    journalLockPath: extra.journalLockPath ?? "/workspace/.opencode/session/journal.lock",
    processStartedAt: extra.processStartedAt ?? "2026-09-02T00:00:00.000Z",
    opencodeVersion: extra.opencodeVersion,
    ...extra,
  }
  return tryFactory(deps)
}

// ---------------------------------------------------------------------------
// 1. appendRow — serialization + monotonic seq at write time, malformed skip
// ---------------------------------------------------------------------------
describe("lib/registry — appendRow", () => {
  it("serializes as one JSON line with seq and timestamp at write time", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs)
    const fn = inst.appendRow
    fn({ event: "test_event", session_id: "ses_1", ticket: "DIA-260902-eqgg" })
    const content = fs.files.get(regPath)
    assert.ok(content, "registry file must have been written")
    const line = content.trim().split("\n").pop()
    const row = JSON.parse(line)
    assert.equal(row.event, "test_event")
    assert.equal(row.session_id, "ses_1")
    assert.equal(typeof row.seq, "number", "seq must be number")
    assert.equal(typeof row.timestamp, "string", "timestamp must be ISO string")
    // timestamp is ISO
    assert.ok(!Number.isNaN(Date.parse(row.timestamp)), "timestamp must be parseable ISO")
  })

  it("monotonic seq = MAX(max seq, lineCount)+1 at write time (not cached)", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    // Pre-seed file with two rows: seq 1 and seq 5 (gap), lineCount 2 => MAX is 5 => next is 6
    const pre = [
      JSON.stringify({ seq: 1, event: "a" }),
      JSON.stringify({ seq: 5, event: "b" }),
    ].join("\n") + "\n"
    const fs = makeFakeFs({ [regPath]: pre })
    const inst = makeRegistry(fs)
    assert.ok(inst)
    inst.appendRow({ event: "next" })
    const lines = fs.files.get(regPath).trim().split("\n")
    assert.equal(lines.length, 3)
    const last = JSON.parse(lines[2])
    assert.equal(last.seq, 6, "seq must be MAX(5,2)+1=6")
    // Second write increments to 7
    inst.appendRow({ event: "next2" })
    const lines2 = fs.files.get(regPath).trim().split("\n")
    const last2 = JSON.parse(lines2[3])
    assert.equal(last2.seq, 7)
  })

  it("lineCount floor: legacy rows without seq still advance counter", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    // 3 lines with no seq field => maxSeq 0, lineCount 3 => next seq 4
    const pre = [
      JSON.stringify({ event: "legacy1" }),
      JSON.stringify({ event: "legacy2" }),
      JSON.stringify({ event: "legacy3" }),
    ].join("\n") + "\n"
    const fs = makeFakeFs({ [regPath]: pre })
    const inst = makeRegistry(fs)
    assert.ok(inst)
    inst.appendRow({ event: "after_legacy" })
    const lines = fs.files.get(regPath).trim().split("\n")
    const last = JSON.parse(lines[3])
    assert.equal(last.seq, 4, "without seq, lineCount (3)+1=4 must be used")
  })

  it("lineCount remains the floor when sequenced and legacy rows are mixed", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const fs = makeFakeFs({
      [regPath]: [
        JSON.stringify({ seq: 1 }),
        JSON.stringify({ event: "legacy-a" }),
        JSON.stringify({ event: "legacy-b" }),
      ].join("\n") + "\n",
    })
    const inst = makeRegistry(fs)
    inst.appendRow({ event: "after-mixed-history" })
    const rows = fs.files.get(regPath).trim().split("\n").map((line) => JSON.parse(line))
    assert.equal(rows.at(-1).seq, 4, "MAX(max seq 1, lineCount 3)+1 prevents ID reuse")
  })

  it("malformed JSON lines are skipped when computing max seq / lineCount", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const pre = [
      JSON.stringify({ seq: 2, event: "ok" }),
      "NOT JSON {{{",
      JSON.stringify({ seq: 10, event: "ok2" }),
      "", // empty line
      "also malformed",
    ].join("\n") + "\n"
    const fs = makeFakeFs({ [regPath]: pre })
    const inst = makeRegistry(fs)
    assert.ok(inst)
    // maxSeq among parseable is 10, but there are 4 non-empty lines (including malformed)
    // The monolith skips malformed for maxSeq but still counts lineCount over split including malformed?
    // Actually maxRegistrySeq iterates split("\n"), skips empty, then try/catch JSON, lineCount++ before try.
    // So lineCount = 4 (non-empty lines), maxSeq=10 => MAX=10 => next 11
    inst.appendRow({ event: "after_malformed" })
    const lines = fs.files.get(regPath).trim().split("\n")
    const last = JSON.parse(lines[lines.length - 1])
    assert.equal(last.seq, 11, "malformed lines must be skipped for maxSeq but counted for lineCount floor — MAX(10,4)+1=11")
  })

  it("coordinates interleaved canonical writers without out-of-band appends", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const fs = makeFakeFs({ [regPath]: JSON.stringify({ seq: 1, event: "a" }) + "\n" })
    const inst = makeRegistry(fs)
    assert.ok(inst)
    inst.appendRow({ event: "first" })
    const external = makeRegistry(fs, {
      processIdentity: { pid: 202, startedAt: "external" },
    })
    external.appendRow({ event: "external" })
    inst.appendRow({ event: "second" })
    const lines = fs.files.get(regPath).trim().split("\n")
    const last = JSON.parse(lines[lines.length - 1])
    assert.equal(last.seq, 4, "canonical writers allocate 2, 3, then 4")
  })

  it("synthetic group_key __task_no_id__ resolved with seq suffix", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs)
    assert.ok(inst)
    // The monolith resolves TASK_NO_ID_GROUP_KEY by appending seq
    inst.appendRow({ event: "task_no_id", group_key: "__task_no_id__" })
    const line = fs.files.get(regPath).trim()
    const row = JSON.parse(line)
    assert.ok(String(row.group_key).startsWith("__task_no_id__"), "group_key must start with prefix")
    assert.ok(String(row.group_key).length > "__task_no_id__".length, "group_key must have seq suffix")
    assert.ok(String(row.group_key).includes(String(row.seq)), "group_key suffix must contain seq")
  })

  it("fail-soft: appendFileSync throw does not propagate (never crashes plugin)", () => {
    const fs = makeFakeFs({})
    // Make append throw
    fs.appendFileSync = () => { throw new Error("disk full") }
    const inst = makeRegistry(fs)
    assert.ok(inst)
    assert.doesNotThrow(() => inst.appendRow({ event: "should_not_throw" }), "appendRow must not throw on write failure")
  })
})

// ---------------------------------------------------------------------------
// 2. appendMessageRow — row_id = MAX(max jsonl row_id, last md row)+1, malformed skip
// ---------------------------------------------------------------------------
describe("lib/registry — appendMessageRow", () => {
  it("serializes with row_id, event_uuid, timestamp, gen_ai.provider.name, writer", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs, { messagesPath: msgPath })
    assert.ok(inst)
    const fn = inst.appendMessageRow
    fn({ event_type: "decision", task_ref: "DIA-1" }, "ses_1")
    const content = fs.files.get(msgPath)
    assert.ok(content, "messages.jsonl must have been written")
    const row = JSON.parse(content.trim().split("\n").pop())
    assert.equal(typeof row.row_id, "number")
    assert.equal(typeof row.event_uuid, "string")
    assert.equal(typeof row.timestamp, "string")
    assert.equal(row["gen_ai.provider.name"], "opencode-go")
    assert.equal(row.writer, "plugin")
    assert.equal(row.event_type, "decision")
  })

  it("row_id = MAX(max jsonl row_id, last md row)+1 at write time — jsonl dominates", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const mdPath = "/workspace/.opencode/session/messages.md"
    const pre = [
      JSON.stringify({ row_id: 3, event_type: "a" }),
      JSON.stringify({ row_id: 7, event_type: "b" }),
    ].join("\n") + "\n"
    const md = "| 5 | something |\n| 4 | other |\n"
    const fs = makeFakeFs({ [msgPath]: pre, [mdPath]: md })
    const inst = makeRegistry(fs, { messagesPath: msgPath, messagesMdPath: mdPath })
    assert.ok(inst)
    inst.appendMessageRow({ event_type: "next" })
    const rows = fs.files.get(msgPath).trim().split("\n").map(l => JSON.parse(l))
    const last = rows[rows.length - 1]
    // MAX(7, 5)+1 = 8
    assert.equal(last.row_id, 8, "row_id must be MAX(7 jsonl, 5 md)+1=8")
  })

  it("row_id uses md floor when jsonl has no row_id (legacy migration)", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const mdPath = "/workspace/.opencode/session/messages.md"
    const pre = [
      JSON.stringify({ event_type: "legacy", task_ref: "x" }), // no row_id
      JSON.stringify({ event_type: "legacy2" }),
    ].join("\n") + "\n"
    const md = "| 601 | last legacy row |\n"
    const fs = makeFakeFs({ [msgPath]: pre, [mdPath]: md })
    const inst = makeRegistry(fs, { messagesPath: msgPath, messagesMdPath: mdPath })
    assert.ok(inst)
    inst.appendMessageRow({ event_type: "after_legacy" })
    const rows = fs.files.get(msgPath).trim().split("\n").map(l => JSON.parse(l))
    const last = rows[rows.length - 1]
    assert.equal(last.row_id, 602, "legacy jsonl with no row_id must fall back to md row 601+1=602")
  })

  it("malformed lines in messages.jsonl are skipped for max row_id", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const pre = [
      JSON.stringify({ row_id: 4 }),
      "BAD JSON",
      JSON.stringify({ row_id: 2 }),
      "",
      "also bad",
    ].join("\n") + "\n"
    const fs = makeFakeFs({ [msgPath]: pre })
    const inst = makeRegistry(fs, { messagesPath: msgPath, messagesMdPath: "/workspace/.opencode/session/messages.md" })
    assert.ok(inst)
    inst.appendMessageRow({ event_type: "next" })
    const rows = fs.files.get(msgPath).trim().split("\n").map(l => { try { return JSON.parse(l) } catch { return null } }).filter(Boolean)
    const last = rows[rows.length - 1]
    assert.equal(last.row_id, 5, "malformed lines must be skipped — MAX(4,2,0)+1=5")
  })

  it("lastMessagesMdRowNumber uses regex /^\\|\\s*(\\d+)\\s*\\|/ and skips non-numeric VP rows", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const mdPath = "/workspace/.opencode/session/messages.md"
    const md = [
      "| 1 | first |",
      "| VP-1 | evidence without numeric |", // VP row — skipped
      "| 10 | tenth |",
      "|   3   | padded |",
      "not a table row",
      "| 7 | seventh |",
    ].join("\n")
    const fs = makeFakeFs({ [mdPath]: md })
    const inst = makeRegistry(fs, { messagesPath: msgPath, messagesMdPath: mdPath })
    assert.ok(inst)
    assert.equal(inst.lastMessagesMdRowNumber(mdPath), 10, "must return max numeric first column (10), skipping VP rows")
  })

  it("coordinates message row_id across canonical writer instances", () => {
    const msgPath = "/workspace/.opencode/session/messages.jsonl"
    const fs = makeFakeFs({ [msgPath]: JSON.stringify({ row_id: 1 }) + "\n" })
    const inst = makeRegistry(fs, { messagesPath: msgPath, messagesMdPath: "/nonexistent.md" })
    assert.ok(inst)
    inst.appendMessageRow({ event_type: "a" })
    const external = makeRegistry(fs, {
      messagesPath: msgPath,
      messagesMdPath: "/nonexistent.md",
      processIdentity: { pid: 202, startedAt: "external" },
    })
    external.appendMessageRow({ event_type: "external" })
    inst.appendMessageRow({ event_type: "b" })
    const rows = fs.files.get(msgPath).trim().split("\n").map(l => JSON.parse(l))
    const last = rows[rows.length - 1]
    assert.equal(last.row_id, 4, "canonical writers allocate message rows 2, 3, then 4")
  })

  it("fail-soft: messages write error does not throw", () => {
    const fs = makeFakeFs({})
    fs.appendFileSync = () => { throw new Error("no space") }
    const inst = makeRegistry(fs)
    assert.ok(inst)
    assert.doesNotThrow(() => inst.appendMessageRow({ event_type: "x" }), "appendMessageRow must not throw on write error")
  })

  it("returns 0 for absent files (helpers)", () => {
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs, { registryPath: "/no/registry.jsonl", messagesPath: "/no/messages.jsonl", messagesMdPath: "/no/messages.md" })
    assert.ok(inst)
    assert.equal(inst.maxRowIdInJsonl("/no/messages.jsonl"), 0, "maxRowIdInJsonl absent must be 0")
    assert.equal(inst.lastMessagesMdRowNumber("/no/messages.md"), 0, "lastMessagesMdRowNumber absent must be 0")
  })
})

// ---------------------------------------------------------------------------
// 3. captureConfigLoadSignal — mtimes before I/O
// ---------------------------------------------------------------------------
describe("lib/registry — captureConfigLoadSignal", () => {
  it("returns mtimes for both config files as ISO strings (or null when absent)", () => {
    const dir = "/workspace"
    const opPath = "/workspace/.opencode/opencode.jsonc"
    const omoPath = "/workspace/.opencode/oh-my-opencode-slim.jsonc"
    const t1 = Date.parse("2026-09-01T10:00:00.000Z")
    const t2 = Date.parse("2026-09-02T12:00:00.000Z")
    const fs = makeFakeFs({}, { mtimes: { [opPath]: t1, [omoPath]: t2 } })
    fs.files.set(opPath, "{}")
    fs.files.set(omoPath, "{}")
    fs.dirs.add("/workspace/.opencode")
    const inst = makeRegistry(fs, { directory: dir })
    assert.ok(inst)
    const fn = inst.captureConfigLoadSignal
    const sig = fn(dir)
    assert.equal(sig.opencode_jsonc_mtime, new Date(t1).toISOString(), "opencode_jsonc mtime must be ISO")
    assert.equal(sig.omo_jsonc_mtime, new Date(t2).toISOString(), "omo_jsonc_mtime must be ISO")
  })

  it("returns null for missing config file (not throw)", () => {
    const dir = "/workspace"
    const fs = makeFakeFs({}, { mtimes: {} })
    // no files set — both missing
    const inst = makeRegistry(fs, { directory: dir })
    assert.ok(inst)
    const fn = inst.captureConfigLoadSignal
    const sig = fn(dir)
    assert.equal(sig.opencode_jsonc_mtime, null, "missing file must be null")
    assert.equal(sig.omo_jsonc_mtime, null)
  })

  it("captures mtimes BEFORE any registry/messages I/O (statSync called, not after append)", () => {
    const dir = "/workspace"
    const opPath = "/workspace/.opencode/opencode.jsonc"
    const fs = makeFakeFs({}, { mtimes: { [opPath]: Date.parse("2026-09-01T00:00:00.000Z") } })
    fs.files.set(opPath, "{}")
    fs.files.set("/workspace/.opencode/oh-my-opencode-slim.jsonc", "{}")
    const inst = makeRegistry(fs, { directory: dir })
    assert.ok(inst)
    const fn = inst.captureConfigLoadSignal
    fs.calls.length = 0
    fn(dir)
    const callNames = fs.calls.map(c => c[0])
    // statSync / existsSync must have been called for config paths
    assert.ok(callNames.includes("statSync") || callNames.includes("existsSync"), "must stat config files")
    // No appendFileSync/writeFileSync should occur during capture
    assert.ok(!callNames.includes("appendFileSync"), "capture must not write registry")
    assert.ok(!callNames.includes("writeFileSync"), "capture must not write boot marker")
  })

  it("never throws when statSync throws (unreadable config → null)", () => {
    const dir = "/workspace"
    const fs = makeFakeFs({}, { mtimes: {} })
    fs.statSync = () => { throw new Error("EACCES") }
    fs.existsSync = () => true
    const inst = makeRegistry(fs, { directory: dir })
    assert.ok(inst)
    const fn = inst.captureConfigLoadSignal
    let sig
    assert.doesNotThrow(() => { sig = fn(dir) }, "capture must be fail-soft on stat error")
    // At least one field should be null on error
    assert.ok(sig !== undefined, "signal must be returned even on stat error")
  })
})

// ---------------------------------------------------------------------------
// 4. atomicWriteBootMarker — shares bootId/seq with registry row + fsync discipline + fields
// ---------------------------------------------------------------------------
describe("lib/registry — atomicWriteBootMarker", () => {
  it("boot.json fields: version 1, event session_boot, boot_id, seq, process_started_at, timestamp, config_load_signal, writer plugin", () => {
    const bootPath = "/workspace/.opencode/session/boot.json"
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    const handoffDir = "/workspace/.opencode/session"
    const fs = makeFakeFs({})
    const processStartedAt = "2026-09-02T09:00:00.000Z"
    const inst = makeRegistry(fs, { bootPath, bootTmpPath: bootTmp, handoffDir, processStartedAt })
    assert.ok(inst)
    const fn = inst.atomicWriteBootMarker
    const marker = { bootId: "boot-uuid-1234", bootSeq: 42, configSignal: { opencode_jsonc_mtime: "2026-09-01T00:00:00.000Z", omo_jsonc_mtime: null } }
    const res = fn(marker)
    // Accept either void or {ok:true}
    if (res !== undefined) assert.equal(res.ok ?? true, true, "write should succeed (ok:true or void)")
    const content = fs.files.get(bootPath)
    assert.ok(content, "boot.json must have been written via rename from tmp")
    const boot = JSON.parse(content)
    assert.equal(boot.version, 1, "version must be 1")
    assert.equal(boot.event, "session_boot")
    assert.equal(boot.boot_id, "boot-uuid-1234", "boot_id must match marker.bootId")
    assert.equal(boot.seq, 42, "seq must match marker.bootSeq (shared with registry row)")
    assert.equal(boot.process_started_at, processStartedAt, "process_started_at must be the captured load time, not write time")
    assert.ok(typeof boot.timestamp === "string" && !Number.isNaN(Date.parse(boot.timestamp)), "timestamp must be ISO")
    assert.deepEqual(boot.config_load_signal, marker.configSignal, "config_load_signal must be carried verbatim")
    assert.equal(boot.writer, "plugin")
  })

  it("shares bootId and seq with the registry session_boot row (same values)", () => {
    const regPath = "/workspace/.opencode/session/registry.jsonl"
    const bootPath = "/workspace/.opencode/session/boot.json"
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    const handoffDir = "/workspace/.opencode/session"
    const fs = makeFakeFs({})
    const processStartedAt = "2026-09-02T09:00:00.000Z"
    const inst = makeRegistry(fs, { registryPath: regPath, bootPath, bootTmpPath: bootTmp, handoffDir, processStartedAt })
    assert.ok(inst)
    // Simulate shell boot shot: appendRow then atomicWriteBootMarker with same bootId/seq
    const bootId = "shared-boot-id-xyz"
    const appendResult = inst.appendRow({ event: "session_boot", boot_id: bootId, process_started_at: processStartedAt, config_load_signal: { opencode_jsonc_mtime: null, omo_jsonc_mtime: null }, writer: "plugin" })
    const regLine = fs.files.get(regPath).trim().split("\n").pop()
    const regRow = JSON.parse(regLine)
    assert.equal(regRow.event, "session_boot")
    assert.equal(regRow.boot_id, bootId)
    // During the RED transition, accept the legacy numeric return so this
    // pre-existing boot test remains about marker identity. GREEN changes the
    // production return to AppendResult; then this consumes its durable ID.
    const bootSeq = typeof appendResult === "number" ? appendResult : appendResult.id
    assert.equal(typeof bootSeq, "number")
    assert.equal(regRow.seq, bootSeq, "persisted row seq must match append result ID")
    inst.atomicWriteBootMarker({ bootId, bootSeq, configSignal: { opencode_jsonc_mtime: null, omo_jsonc_mtime: null } })
    const boot = JSON.parse(fs.files.get(bootPath))
    assert.equal(boot.boot_id, bootId, "boot.json boot_id must equal registry row boot_id")
    assert.equal(boot.seq, bootSeq, "boot.json seq must equal registry row seq")
  })

  it("fsync discipline: write tmp -> fsync tmp fd -> close tmp fd -> rename -> fsync dir -> close dir", () => {
    const bootPath = "/workspace/.opencode/session/boot.json"
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    const handoffDir = "/workspace/.opencode/session"
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs, { bootPath, bootTmpPath: bootTmp, handoffDir })
    assert.ok(inst)
    const fn = inst.atomicWriteBootMarker
    fs.calls.length = 0
    fn({ bootId: "b1", bootSeq: 1, configSignal: { opencode_jsonc_mtime: null, omo_jsonc_mtime: null } })
    const names = fs.calls.map(c => c[0])
    // Must mkdir
    assert.ok(names.includes("mkdirSync"), "must mkdir handoffDir")
    // Must write tmp
    const writeIdx = names.indexOf("writeFileSync")
    const firstOpenIdx = names.indexOf("openSync")
    const firstFsyncIdx = names.indexOf("fsyncSync")
    const renameIdx = names.indexOf("renameSync")
    assert.ok(writeIdx !== -1, "must writeFileSync tmp")
    assert.ok(firstOpenIdx !== -1, "must openSync tmp")
    assert.ok(firstFsyncIdx !== -1, "must fsyncSync tmp")
    assert.ok(renameIdx !== -1, "must renameSync")
    assert.ok(writeIdx < firstOpenIdx, "write before openSync tmp")
    assert.ok(firstOpenIdx < firstFsyncIdx, "openSync tmp before fsync tmp")
    assert.ok(firstFsyncIdx < renameIdx, "fsync tmp before rename")
    // After rename, must fsync the directory
    const closeIndices = names.map((n, i) => n === "closeSync" ? i : -1).filter(i => i !== -1)
    assert.ok(closeIndices.length >= 2, "must closeSync at least tmp fd and dir fd")
    const secondOpenIdx = names.indexOf("openSync", firstOpenIdx + 1)
    assert.ok(secondOpenIdx !== -1, "must openSync dir after rename")
    assert.ok(renameIdx < secondOpenIdx, "rename before openSync dir")
    const secondFsyncIdx = names.indexOf("fsyncSync", firstFsyncIdx + 1)
    assert.ok(secondFsyncIdx !== -1, "must fsyncSync dir")
    assert.ok(secondOpenIdx < secondFsyncIdx, "openSync dir before fsync dir")
  })

  it("creates handoffDir recursively before writing", () => {
    const fs = makeFakeFs({})
    const handoffDir = "/workspace/.opencode/session"
    const inst = makeRegistry(fs, { handoffDir, bootPath: `${handoffDir}/boot.json`, bootTmpPath: `${handoffDir}/.boot.json.tmp` })
    assert.ok(inst)
    const fn = inst.atomicWriteBootMarker
    fn({ bootId: "b2", bootSeq: 2, configSignal: {} })
    const mkdirCalls = fs.calls.filter(c => c[0] === "mkdirSync")
    assert.ok(mkdirCalls.some(c => c[1] === handoffDir), `must mkdirSync ${handoffDir}`)
  })

  it("fail-soft: rename failure cleans up tmp and returns ok:false", () => {
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    const bootPath = "/workspace/.opencode/session/boot.json"
    const fs = makeFakeFs({}, { renameShouldThrow: "disk error" })
    fs.files.set(bootTmp, "tmp content")
    const inst = makeRegistry(fs, { bootTmpPath: bootTmp, bootPath })
    assert.ok(inst)
    const fn = inst.atomicWriteBootMarker
    let res
    assert.doesNotThrow(() => { res = fn({ bootId: "b3", bootSeq: 3, configSignal: {} }) }, "atomicWriteBootMarker must not throw on rename failure")
    // The settled contract returns {ok:false} with the rename error.
    assert.equal(res.ok, false, "on failure must return {ok:false}")
    assert.match(String(res.error ?? ""), /disk error/i, "error must carry the rename failure")
    // Fail-soft cleanup: tmp is unlinked and boot.json never lands.
    assert.ok(!fs.files.has(bootTmp), "tmp must be unlinked after rename failure")
    assert.ok(!fs.files.has(bootPath), "boot.json must not exist after rename failure")
  })

  it("opencode_version included when available, omitted when absent", () => {
    const bootPath = "/workspace/.opencode/session/boot.json"
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    let fs = makeFakeFs({})
    let inst = makeRegistry(fs, { bootPath, bootTmpPath: bootTmp, handoffDir: "/workspace/.opencode/session", opencodeVersion: "1.18.10" })
    assert.ok(inst)
    inst.atomicWriteBootMarker({ bootId: "b4", bootSeq: 4, configSignal: {} })
    let boot = JSON.parse(fs.files.get(bootPath))
    assert.equal(boot.opencode_version, "1.18.10", "when opencodeVersion provided, boot.json must carry it")

    // Without version
    fs = makeFakeFs({})
    inst = makeRegistry(fs, { bootPath, bootTmpPath: bootTmp, handoffDir: "/workspace/.opencode/session", opencodeVersion: undefined })
    assert.ok(inst)
    inst.atomicWriteBootMarker({ bootId: "b5", bootSeq: 5, configSignal: {} })
    boot = JSON.parse(fs.files.get(bootPath))
    assert.equal(boot.opencode_version, undefined, "when no opencodeVersion, field must be absent")
  })

  it("boot.json is pretty-printed JSON with trailing newline", () => {
    const bootPath = "/workspace/.opencode/session/boot.json"
    const bootTmp = "/workspace/.opencode/session/.boot.json.tmp"
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs, { bootPath, bootTmpPath: bootTmp, handoffDir: "/workspace/.opencode/session" })
    assert.ok(inst)
    inst.atomicWriteBootMarker({ bootId: "b6", bootSeq: 6, configSignal: {} })
    const raw = fs.files.get(bootPath)
    assert.ok(raw.endsWith("\n"), "boot.json must end with newline")
    assert.ok(raw.includes('  "version"'), "must be JSON pretty-printed (2-space indent)")
    assert.doesNotThrow(() => JSON.parse(raw), "must be valid JSON")
  })
})

// ---------------------------------------------------------------------------
// 5. Inject fs fakes — DI seam verification
// ---------------------------------------------------------------------------
describe("lib/registry — DI seam (inject fs fakes)", () => {
  it("factory accepts injected fs and does not touch real filesystem", () => {
    // DI contract: the lib accepts fs fakes and uses ONLY them. If it touched
    // the real FS instead, this fake would record no calls.
    const fs = makeFakeFs({})
    const inst = makeRegistry(fs)
    // Perform an operation and verify it went through the fake
    inst.appendRow({ event: "di_check" })
    const calls = fs.calls.map(c => c[0])
    assert.ok(calls.includes("appendFileSync"), "operation must have used injected fs (appendFileSync recorded)")
    assert.ok(calls.length > 0, "fake fs must have been called")
  })

  it("factory does not capture ctx or import shell — pure lib with injected deps only", () => {
    // Structural DI check: lib must not import shell.
    const src = nodeReadFileSync(new URL("../lib/registry.ts", import.meta.url), "utf-8")
    assert.ok(src.includes("appendRow"), "lib/registry.ts must implement registry logic")
    assert.ok(!src.includes("from \"../delegation-observer"), "registry lib must not import from delegation-observer (no shell import)")
    assert.ok(!src.includes("from './delegation-observer"), "registry lib must not import shell")
  })

})

// DIA-260914-tqor RED-A. These cases specify the approved production wrapper
// behavior without importing the not-yet-created persistence helper.
describe("DIA-260914-tqor RED-A - durable journal persistence", () => {
  const registryPath = "/workspace/.opencode/session/registry.jsonl"
  const messagesPath = "/workspace/.opencode/session/messages.jsonl"
  const registrySeqPath = "/workspace/.opencode/session/registry.seq"
  const messagesRowIdPath = "/workspace/.opencode/session/messages.row-id"
  const journalLockPath = "/workspace/.opencode/session/journal.lock"

  function expectSuccess(result, label) {
    assert.equal(typeof result, "object", `${label} returns a durable result`)
    assert.equal(result?.ok, true, `${label} reports ok:true after append`)
    assert.equal(typeof result?.id, "number", `${label} exposes its durable ID`)
    return result.id
  }

  it("persists independent registry seq and message row_id counters", () => {
    const fs = makeFakeFs({
      [registryPath]: JSON.stringify({ seq: 40 }) + "\n",
      [messagesPath]: JSON.stringify({ row_id: 900 }) + "\n",
    })
    const registry = makeRegistry(fs)
    assert.equal(expectSuccess(registry.appendRow({ event: "next" }), "appendRow"), 41)
    assert.equal(expectSuccess(registry.appendMessageRow({ event_type: "next" }), "appendMessageRow"), 901)
    assert.equal(Number(fs.files.get(registrySeqPath)), 41, "registry.seq stores registry high-water")
    assert.equal(Number(fs.files.get(messagesRowIdPath)), 901, "messages.row-id stores message high-water")
  })

  it("does not repeat full JSONL scans after counter initialization", () => {
    const fs = makeFakeFs({
      [registryPath]: JSON.stringify({ seq: 4 }) + "\n",
      [messagesPath]: JSON.stringify({ row_id: 8 }) + "\n",
    })
    const registry = makeRegistry(fs)
    registry.appendRow({ event: "one" })
    registry.appendRow({ event: "two" })
    registry.appendMessageRow({ event_type: "one" })
    registry.appendMessageRow({ event_type: "two" })
    const registryScans = fs.calls.filter(([name, path]) => name === "readFileSync" && path === registryPath)
    const messageScans = fs.calls.filter(([name, path]) => name === "readFileSync" && path === messagesPath)
    assert.ok(registryScans.length <= 1, `registry scanned ${registryScans.length} times`)
    assert.ok(messageScans.length <= 1, `messages scanned ${messageScans.length} times`)
  })

  it("gives two writer instances unique monotonic IDs through one sidecar", () => {
    const fs = makeFakeFs({})
    const writerA = makeRegistry(fs, { processIdentity: { pid: 101, startedAt: "a" } })
    const writerB = makeRegistry(fs, { processIdentity: { pid: 202, startedAt: "b" } })
    const ids = [
      expectSuccess(writerA.appendRow({ event: "a" }), "writer A"),
      expectSuccess(writerB.appendRow({ event: "b" }), "writer B"),
      expectSuccess(writerA.appendRow({ event: "c" }), "writer A again"),
    ]
    assert.deepEqual(ids, [1, 2, 3], "writers share one sequence")
    assert.equal(Number(fs.files.get(registrySeqPath)), 3)
  })

  it("refuses a live lock owner with a retryable lock result", () => {
    const fs = makeFakeFs({
      [journalLockPath]: JSON.stringify({ pid: 777, startedAt: "owner", leaseDeadline: 9000 }),
    })
    const registry = makeRegistry(fs, {
      processIdentity: { pid: 888, startedAt: "contender" },
      isProcessAlive: (owner) => owner.pid === 777 && owner.startedAt === "owner",
      clock: { now: () => 2000, isoNow: () => "2026-09-14T00:00:02.000Z" },
    })
    const result = registry.appendRow({ event: "blocked" })
    assert.deepEqual(
      { ok: result?.ok, stage: result?.stage, retryable: result?.retryable },
      { ok: false, stage: "lock", retryable: true },
      "live owner cannot be preempted",
    )
    assert.equal(fs.files.has(registryPath), false, "lock refusal prevents append")
  })

  it("reclaims an expired lock only for a confirmed dead exact owner", () => {
    const fs = makeFakeFs({
      [journalLockPath]: JSON.stringify({ pid: 777, startedAt: "old", leaseDeadline: 1500 }),
    })
    const registry = makeRegistry(fs, {
      processIdentity: { pid: 888, startedAt: "new" },
      isProcessAlive: () => false,
      clock: { now: () => 2000, isoNow: () => "2026-09-14T00:00:02.000Z" },
    })
    assert.equal(expectSuccess(registry.appendRow({ event: "reclaimed" }), "reclaim append"), 1)
    assert.equal(fs.files.has(journalLockPath), false, "lock released after append")
  })

  it("fails closed for unreadable lock metadata and PID reuse ambiguity", () => {
    for (const [label, lock] of [
      ["unreadable", "not-json"],
      ["pid-reuse", JSON.stringify({ pid: 777, startedAt: "old", leaseDeadline: 1500 })],
    ]) {
      const fs = makeFakeFs({ [journalLockPath]: lock })
      const registry = makeRegistry(fs, {
        isProcessAlive: () => ({ alive: true, startedAt: "different" }),
        clock: { now: () => 2000, isoNow: () => "2026-09-14T00:00:02.000Z" },
      })
      const result = registry.appendRow({ event: label })
      assert.equal(result?.ok, false, `${label} ownership fails closed`)
      assert.equal(result?.stage, "lock", `${label} identifies lock stage`)
      assert.equal(fs.files.has(registryPath), false, `${label} prevents append`)
    }
  })

  it("bootstraps absent and corrupt sidecars once from durable history", () => {
    for (const [label, sidecar] of [["absent", undefined], ["corrupt", "oops"]]) {
      const initial = { [registryPath]: JSON.stringify({ seq: 7 }) + "\n" }
      if (sidecar !== undefined) initial[registrySeqPath] = sidecar
      const fs = makeFakeFs(initial)
      const registry = makeRegistry(fs)
      assert.equal(expectSuccess(registry.appendRow({ event: label }), `${label} recovery`), 8)
      assert.equal(Number(fs.files.get(registrySeqPath)), 8, `${label} sidecar recovered`)
      registry.appendRow({ event: `${label}-again` })
      const scans = fs.calls.filter(([name, path]) => name === "readFileSync" && path === registryPath)
      assert.ok(scans.length <= 1, `${label} recovery scans once, observed ${scans.length}`)
    }
  })

  it("repairs a known-lower valid sidecar once during controlled initialization", () => {
    const fs = makeFakeFs({
      [registryPath]: JSON.stringify({ seq: 7 }) + "\n",
      [registrySeqPath]: "2\n",
    })
    const registry = makeRegistry(fs)
    assert.equal(expectSuccess(registry.appendRow({ event: "after-controlled-recovery" }), "recovered append"), 8)
    assert.equal(Number(fs.files.get(registrySeqPath)), 8, "append repairs sidecar above durable history max")
    const scansAfterRecovery = fs.calls.filter(([name, path]) => name === "readFileSync" && path === registryPath).length
    registry.appendRow({ event: "after-recovery" })
    const scansAfterAppend = fs.calls.filter(([name, path]) => name === "readFileSync" && path === registryPath).length
    assert.equal(scansAfterRecovery, 1, "initialization performs one controlled history scan")
    assert.equal(scansAfterAppend, scansAfterRecovery, "subsequent append trusts repaired sidecar without scanning")
  })

  it("returns discriminated append failure without a persisted entry", () => {
    const fs = makeFakeFs({})
    fs.appendFileSync = () => { throw new Error("disk full") }
    const result = makeRegistry(fs).appendRow({ event: "not-persisted" })
    assert.equal(result?.ok, false)
    assert.equal(result?.stage, "append")
    assert.equal(result?.retryable, false)
    assert.equal(result?.reserved_id, 1, "reserved gap remains diagnostic")
    assert.equal(result?.entry, undefined, "failure exposes no persisted entry")
  })

  it("prevents append when atomic counter publication fails", () => {
    const fs = makeFakeFs({}, { renameShouldThrow: "counter rename failed" })
    const result = makeRegistry(fs).appendRow({ event: "must-not-append" })
    assert.equal(result?.ok, false)
    assert.equal(result?.stage, "counter")
    assert.equal(
      fs.calls.some(([name, path]) => name === "appendFileSync" && path === registryPath),
      false,
      "counter failure prevents journal append",
    )
  })

  it("never reuses a reservation lost after counter persistence", () => {
    const fs = makeFakeFs({})
    const append = fs.appendFileSync
    let failOnce = true
    fs.appendFileSync = (path, data) => {
      if (path === registryPath && failOnce) {
        failOnce = false
        throw new Error("crash after reservation")
      }
      append(path, data)
    }
    const failed = makeRegistry(fs).appendRow({ event: "gap" })
    assert.equal(failed?.ok, false)
    assert.equal(failed?.reserved_id, 1)
    const next = makeRegistry(fs).appendRow({ event: "after-gap" })
    assert.equal(expectSuccess(next, "post-crash append"), 2, "ID 1 is never reused")
  })

  it("uses the canonical registry adapter from needs-input observer", () => {
    const src = nodeReadFileSync(new URL("../needs-input-observer.ts", import.meta.url), "utf-8")
    assert.equal(/from\s+["']\.\/lib\/registry\.ts["']/.test(src), true, "canonical adapter import exists")
    assert.doesNotMatch(src, /function\s+maxJsonlNumber\s*\(/, "observer owns no ID scan")
    assert.doesNotMatch(src, /appendFileSync\s*\(\s*(registryPath|messagesPath)/, "observer owns no journal append")
  })
})

describe("DIA-260914-tqor RED-A review gaps - real persistence", () => {
  function withTempRegistry(run) {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-registry-"))
    const sessionDir = nodeJoin(root, ".opencode/session")
    nodeFs.mkdirSync(sessionDir, { recursive: true })
    const paths = {
      root,
      sessionDir,
      registry: nodeJoin(sessionDir, "registry.jsonl"),
      messages: nodeJoin(sessionDir, "messages.jsonl"),
      messagesMd: nodeJoin(sessionDir, "messages.md"),
      seq: nodeJoin(sessionDir, "registry.seq"),
      rowId: nodeJoin(sessionDir, "messages.row-id"),
      lock: nodeJoin(sessionDir, "journal.lock"),
    }
    try {
      return run(paths)
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  }

  function realRegistry(paths, extra = {}) {
    return mod.createRegistry({
      directory: paths.root,
      registryPath: paths.registry,
      messagesPath: paths.messages,
      messagesMdPath: paths.messagesMd,
      registrySeqPath: paths.seq,
      messagesRowIdPath: paths.rowId,
      journalLockPath: paths.lock,
      ...extra,
    })
  }

  it("uses atomic lock-directory ownership while independent writers allocate unique IDs", () => {
    withTempRegistry((paths) => {
      const lockMkdirs = []
      let writerB
      let contendedResult
      let contentionTriggered = false
      const fs = {
        ...nodeFs,
        mkdirSync(path, options) {
          if (path.startsWith(`${paths.lock}.acquire-`)) lockMkdirs.push(path)
          return nodeFs.mkdirSync(path, options)
        },
        appendFileSync(path, data) {
          nodeFs.appendFileSync(path, data)
          if (path === paths.registry && !contentionTriggered) {
            contentionTriggered = true
            contendedResult = writerB.appendRow({ event: "contended-b" })
          }
        },
      }
      const writerA = realRegistry(paths, { fs, processIdentity: { pid: 101, startedAt: "a" } })
      writerB = realRegistry(paths, { fs, processIdentity: { pid: 202, startedAt: "b" } })
      const first = writerA.appendRow({ event: "a" })
      const second = writerB.appendRow({ event: "retry-b" })
      assert.deepEqual([first?.id, second?.id], [1, 2], "real writers allocate unique monotonic IDs")
      assert.equal(first?.ok, true)
      assert.equal(second?.ok, true)
      assert.deepEqual(
        { ok: contendedResult?.ok, stage: contendedResult?.stage, retryable: contendedResult?.retryable },
        { ok: false, stage: "lock", retryable: true },
        "contending writer refuses the live lock directory and retries after release",
      )
      assert.ok(
        lockMkdirs.some((path) => path.startsWith(`${paths.lock}.acquire-`)),
        "writers prepare private lock directories before atomic publication",
      )
    })
  })

  it("does not let an old nonce owner remove a replacement lock", () => {
    withTempRegistry((paths) => {
      const replacement = { nonce: "replacement", pid: 303, startedAt: "replacement" }
      const replacementOwnerPath = nodeJoin(paths.lock, "owner.json")
      const quarantine = `${paths.lock}.old-owner`
      const fdPaths = new Map()
      let replaced = false
      const fs = {
        ...nodeFs,
        openSync(path, flags, ...rest) {
          const fd = nodeFs.openSync(path, flags, ...rest)
          fdPaths.set(fd, path)
          return fd
        },
        closeSync(fd) {
          fdPaths.delete(fd)
          nodeFs.closeSync(fd)
        },
        fsyncSync(fd) {
          nodeFs.fsyncSync(fd)
          if (fdPaths.get(fd) === paths.registry && !replaced) {
            replaced = true
            nodeFs.renameSync(paths.lock, quarantine)
            nodeFs.mkdirSync(paths.lock)
            nodeFs.writeFileSync(replacementOwnerPath, JSON.stringify(replacement))
          }
        },
      }
      const result = realRegistry(paths, {
        fs,
        processIdentity: { pid: 101, startedAt: "old-owner" },
      }).appendRow({ event: "replace-lock-before-release" })
      assert.equal(result?.ok, true, "journal append succeeds before replacement")
      assert.equal(replaced, true, "replacement occurs after journal fsync and before release")
      assert.deepEqual(JSON.parse(nodeFs.readFileSync(replacementOwnerPath, "utf8")), replacement, "nonce mismatch preserves replacement lock")
    })
  })

  it("never reclaims a live owner after its lease deadline", () => {
    withTempRegistry((paths) => {
      const owner = { nonce: "live", pid: 777, startedAt: "owner", leaseDeadline: 1500 }
      nodeFs.mkdirSync(paths.lock)
      nodeFs.writeFileSync(nodeJoin(paths.lock, "owner.json"), JSON.stringify(owner))
      const result = realRegistry(paths, {
        processIdentity: { pid: 888, startedAt: "contender" },
        isProcessAlive: () => true,
        clock: { now: () => 9000, isoNow: () => "2026-09-14T00:00:09.000Z" },
      }).appendRow({ event: "must-not-land" })
      assert.deepEqual({ ok: result?.ok, stage: result?.stage }, { ok: false, stage: "lock" })
      assert.deepEqual(
        JSON.parse(nodeFs.readFileSync(nodeJoin(paths.lock, "owner.json"), "utf8")),
        owner,
        "live owner lock remains byte-equivalent",
      )
      assert.equal(nodeFs.existsSync(paths.registry), false, "live owner blocks append")
    })
  })

  it("fails closed for malformed real lock-directory ownership metadata", () => {
    withTempRegistry((paths) => {
      nodeFs.mkdirSync(paths.lock)
      nodeFs.writeFileSync(nodeJoin(paths.lock, "owner.json"), "{not-json")
      const result = realRegistry(paths).appendRow({ event: "must-not-land" })
      assert.deepEqual(
        { ok: result?.ok, stage: result?.stage, retryable: result?.retryable },
        { ok: false, stage: "lock", retryable: true },
      )
      assert.equal(nodeFs.existsSync(paths.registry), false)
      assert.equal(nodeFs.existsSync(paths.lock), true, "unverifiable ownership evidence is preserved")
    })
  })

  it("scans once on valid-sidecar cold start and never again in steady state", () => {
    withTempRegistry((paths) => {
      nodeFs.writeFileSync(paths.registry, JSON.stringify({ seq: 12 }) + "\n")
      nodeFs.writeFileSync(paths.seq, "12\n")
      let fullReads = 0
      const fs = {
        ...nodeFs,
        readFileSync(path, ...args) {
          if (path === paths.registry) fullReads++
          return nodeFs.readFileSync(path, ...args)
        },
      }
      const registry = realRegistry(paths, { fs })
      const result = registry.appendRow({ event: "cold-start" })
      assert.deepEqual({ ok: result?.ok, id: result?.id }, { ok: true, id: 13 })
      assert.equal(fullReads, 1, "cold start verifies the durable high-water floor once")
      assert.equal(registry.appendRow({ event: "steady-state" })?.id, 14)
      assert.equal(fullReads, 1, "steady-state append performs no full history scan")
    })
  })

  it("fails closed when directory fsync reports a real I/O error", () => {
    withTempRegistry((paths) => {
      const fdPaths = new Map()
      const fs = {
        ...nodeFs,
        openSync(path, flags, ...rest) {
          const fd = nodeFs.openSync(path, flags, ...rest)
          fdPaths.set(fd, path)
          return fd
        },
        closeSync(fd) {
          fdPaths.delete(fd)
          nodeFs.closeSync(fd)
        },
        fsyncSync(fd) {
          if (nodeFs.statSync(fdPaths.get(fd)).isDirectory()) {
            throw Object.assign(new Error("directory fsync failed"), { code: "EIO" })
          }
          nodeFs.fsyncSync(fd)
        },
      }
      const result = realRegistry(paths, { fs }).appendRow({ event: "must-not-land" })
      assert.deepEqual({ ok: result?.ok, stage: result?.stage }, { ok: false, stage: "lock" })
      assert.equal(nodeFs.existsSync(paths.registry), false)
    })
  })

  it("fails closed when a cached counter sidecar becomes corrupt", () => {
    withTempRegistry((paths) => {
      nodeFs.writeFileSync(paths.seq, "1\n")
      const registry = realRegistry(paths)
      assert.deepEqual(
        { ok: registry.appendRow({ event: "prime-cache" })?.ok },
        { ok: true },
      )
      nodeFs.writeFileSync(paths.seq, "999junk")
      const rejected = registry.appendRow({ event: "must-not-land" })
      assert.deepEqual(
        { ok: rejected?.ok, stage: rejected?.stage },
        { ok: false, stage: "counter" },
      )
      const rows = nodeFs.readFileSync(paths.registry, "utf8").trim().split("\n")
      assert.equal(rows.length, 1, "corrupt cached sidecar prevents a second append")
    })
  })

  it("fsyncs the journal after append before returning ok:true", () => {
    withTempRegistry((paths) => {
      const events = []
      const fdPaths = new Map()
      const fs = {
        ...nodeFs,
        appendFileSync(path, data) {
          events.push(["append", path])
          nodeFs.appendFileSync(path, data)
        },
        openSync(path, flags, ...rest) {
          const fd = nodeFs.openSync(path, flags, ...rest)
          fdPaths.set(fd, path)
          return fd
        },
        fsyncSync(fd) {
          events.push(["fsync", fdPaths.get(fd)])
          nodeFs.fsyncSync(fd)
        },
        closeSync(fd) {
          fdPaths.delete(fd)
          nodeFs.closeSync(fd)
        },
      }
      const result = realRegistry(paths, { fs }).appendRow({ event: "durable" })
      assert.equal(result?.ok, true)
      const appendAt = events.findIndex(([event, path]) => event === "append" && path === paths.registry)
      const fsyncAt = events.findIndex(([event, path]) => event === "fsync" && path === paths.registry)
      assert.ok(appendAt >= 0 && fsyncAt > appendAt, "journal fsync follows append before success")
    })
  })

  it("classifies identical injected errors by failed stage, not message", () => {
    const counterFs = makeFakeFs({}, { renameShouldThrow: "same failure" })
    const counterResult = makeRegistry(counterFs).appendRow({ event: "counter" })
    const appendFs = makeFakeFs({})
    appendFs.appendFileSync = () => { throw new Error("same failure") }
    const appendResult = makeRegistry(appendFs).appendRow({ event: "append" })
    assert.equal(counterResult?.stage, "counter", "counter operation determines counter stage")
    assert.equal(appendResult?.stage, "append", "append operation determines append stage")
    assert.equal(counterResult?.error, appendResult?.error, "same text does not determine stage")
  })
})

describe("DIA-260914-tqor RED-A review cycle 2 - strict ownership", () => {
  const registryPath = "/workspace/.opencode/session/registry.jsonl"
  const messagesPath = "/workspace/.opencode/session/messages.jsonl"
  const registrySeqPath = "/workspace/.opencode/session/registry.seq"
  const messagesRowIdPath = "/workspace/.opencode/session/messages.row-id"
  const invalidCounters = ["12junk", "12.5", "+12", "-12", "12 \n junk"]

  it("rejects partial decimal signed and whitespace-junk registry counters until explicit recovery", () => {
    for (const value of invalidCounters) {
      const fs = makeFakeFs({
        [registryPath]: JSON.stringify({ seq: 7 }) + "\n",
        [registrySeqPath]: value,
      })
      const registry = makeRegistry(fs)
      const rejected = registry.appendRow({ event: "must-recover" })
      assert.deepEqual(
        { ok: rejected?.ok, stage: rejected?.stage },
        { ok: false, stage: "counter" },
        `registry counter ${JSON.stringify(value)} fails closed`,
      )
      assert.equal(typeof registry.recoverCounters, "function")
      assert.equal(registry.recoverCounters()?.ok, true)
      assert.equal(expectDurableId(registry.appendRow({ event: "recovered" })), 8)
    }
  })

  it("rejects partial decimal signed and whitespace-junk message counters until explicit recovery", () => {
    for (const value of invalidCounters) {
      const fs = makeFakeFs({
        [messagesPath]: JSON.stringify({ row_id: 9 }) + "\n",
        [messagesRowIdPath]: value,
      })
      const registry = makeRegistry(fs)
      const rejected = registry.appendMessageRow({ event_type: "must-recover" })
      assert.deepEqual(
        { ok: rejected?.ok, stage: rejected?.stage },
        { ok: false, stage: "counter" },
        `message counter ${JSON.stringify(value)} fails closed`,
      )
      assert.equal(typeof registry.recoverCounters, "function")
      assert.equal(registry.recoverCounters()?.ok, true)
      assert.equal(expectDurableId(registry.appendMessageRow({ event_type: "recovered" })), 10)
    }
  })

  function expectDurableId(result) {
    assert.equal(result?.ok, true)
    assert.equal(typeof result?.id, "number")
    return result.id
  }

  it("recovers an empty lock directory left between owner removal and directory cleanup", () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-empty-lock-"))
    const sessionDir = nodeJoin(root, ".opencode/session")
    const lockPath = nodeJoin(sessionDir, "journal.lock")
    nodeFs.mkdirSync(lockPath, { recursive: true })
    try {
      const registry = mod.createRegistry({
        directory: root,
        registryPath: nodeJoin(sessionDir, "registry.jsonl"),
        messagesPath: nodeJoin(sessionDir, "messages.jsonl"),
        messagesMdPath: nodeJoin(sessionDir, "messages.md"),
        registrySeqPath: nodeJoin(sessionDir, "registry.seq"),
        messagesRowIdPath: nodeJoin(sessionDir, "messages.row-id"),
        journalLockPath: lockPath,
      })
      assert.equal(expectDurableId(registry.appendRow({ event: "after-empty-lock" })), 1)
      assert.equal(nodeFs.existsSync(lockPath), false, "empty crash-window lock is cleaned after success")
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })

  it("allocates unique IDs across separate OS processes with deterministic lock contention", async () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-processes-"))
    const sessionDir = nodeJoin(root, ".opencode/session")
    nodeFs.mkdirSync(sessionDir, { recursive: true })
    const moduleUrl = new URL("../lib/registry.ts", import.meta.url).href
    const childSource = `
      import * as fs from "node:fs";
      import { createRegistry } from ${JSON.stringify(moduleUrl)};
      const root = process.env.TQOR_ROOT;
      const session = root + "/.opencode/session";
      const registryPath = session + "/registry.jsonl";
      const lockPath = session + "/journal.lock";
      let gated = false;
      const wrapped = {
        ...fs,
        renameSync(source, destination) {
          const result = fs.renameSync(source, destination);
          if (process.env.TQOR_HOLD === "1" && destination === lockPath && !gated) {
            gated = true;
            process.stdout.write("LOCKED\\n");
            fs.readFileSync(0, "utf8");
          }
          return result;
        },
      };
      const registry = createRegistry({
        fs: wrapped,
        directory: root,
        registryPath,
        messagesPath: session + "/messages.jsonl",
        messagesMdPath: session + "/messages.md",
        registrySeqPath: session + "/registry.seq",
        messagesRowIdPath: session + "/messages.row-id",
        journalLockPath: lockPath,
      });
      const result = registry.appendRow({ event: process.env.TQOR_OWNER });
      process.stdout.write("RESULT " + JSON.stringify(result) + "\\n");
    `

    function launch(owner, hold) {
      const child = globalThis.Bun.spawn([process.execPath, "--eval", childSource], {
        cwd: new URL("..", import.meta.url).pathname,
        env: { ...process.env, TQOR_ROOT: root, TQOR_OWNER: owner, TQOR_HOLD: hold ? "1" : "0" },
        stdin: "pipe",
        stdout: "pipe",
        stderr: "pipe",
      })
      let stdout = ""
      let stderr = ""
      const listeners = new Set()
      const decode = new TextDecoder()
      const pump = async (stream, receive) => {
        for await (const chunk of stream) {
          receive(decode.decode(chunk, { stream: true }))
          for (const listener of listeners) listener()
        }
      }
      void pump(child.stdout, (chunk) => { stdout += chunk })
      void pump(child.stderr, (chunk) => { stderr += chunk })
      return { child, listeners, output: () => stdout, errors: () => stderr }
    }

    function waitFor(handle, pattern, label) {
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`${label} timed out: ${handle.output()} ${handle.errors()}`)), 5000)
        const inspect = () => {
          if (!pattern.test(handle.output())) return
          clearTimeout(timer)
          handle.listeners.delete(inspect)
          resolve(handle.output())
        }
        handle.listeners.add(inspect)
        void handle.child.exited.then((code) => {
          inspect()
          if (!pattern.test(handle.output())) {
            clearTimeout(timer)
            handle.listeners.delete(inspect)
            reject(new Error(`${label} exited ${code}: ${handle.output()} ${handle.errors()}`))
          }
        })
        inspect()
      })
    }

    function resultOf(handle) {
      const match = /^RESULT (.+)$/m.exec(handle.output())
      assert.ok(match, `child returned a result: ${handle.output()} ${handle.errors()}`)
      return JSON.parse(match[1])
    }

    try {
      const first = launch("first", true)
      await waitFor(first, /^LOCKED$/m, "first writer gate")
      const second = launch("second", true)
      await waitFor(second, /^RESULT /m, "contending writer result")
      const blocked = resultOf(second)
      assert.deepEqual({ ok: blocked?.ok, stage: blocked?.stage }, { ok: false, stage: "lock" })
      first.child.stdin.write("release\n")
      first.child.stdin.end()
      await waitFor(first, /^RESULT /m, "first writer result")
      const firstResult = resultOf(first)
      const retry = launch("second", false)
      await waitFor(retry, /^RESULT /m, "retry writer result")
      const retryResult = resultOf(retry)
      assert.deepEqual([firstResult?.id, retryResult?.id], [1, 2], "separate processes allocate unique monotonic IDs")
      assert.equal(firstResult?.ok, true)
      assert.equal(retryResult?.ok, true)
      const rows = nodeFs.readFileSync(nodeJoin(sessionDir, "registry.jsonl"), "utf8")
        .trim().split("\n").map((line) => JSON.parse(line))
      assert.deepEqual(rows.map((row) => row.event), ["first", "second"], "retry replays the blocked writer's exact payload")
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })

  it("puts lock counter and checked-append operations in functional journal persistence", () => {
    const helperUrl = new URL("../lib/journal-persistence.ts", import.meta.url)
    assert.equal(nodeFs.existsSync(helperUrl), true, "functional journal-persistence helper exists")
    const src = nodeFs.readFileSync(helperUrl, "utf8")
    for (const [operation, pattern] of [
      ["acquire", /acquire[A-Za-z]*Lock/],
      ["release", /release[A-Za-z]*Lock/],
      ["reserve", /reserve[A-Za-z]*Counter/],
      ["publish", /publish[A-Za-z]*Counter|atomic[A-Za-z]*Counter/],
      ["checked append", /appendChecked|checkedAppend/],
    ]) {
      assert.match(src, pattern, `journal-persistence owns ${operation}`)
    }
    const registrySrc = nodeReadFileSync(new URL("../lib/registry.ts", import.meta.url), "utf8")
    assert.match(registrySrc, /from\s+["']\.\/journal-persistence\.ts["']/, "registry composes the functional helper")
  })

  it("exposes bounded read-only registry health diagnostics without sensitive content", () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-health-"))
    const session = nodeJoin(root, ".opencode/session")
    nodeFs.mkdirSync(session, { recursive: true })
    const registryPath = nodeJoin(session, "registry.jsonl")
    nodeFs.writeFileSync(registryPath, [
      JSON.stringify({ seq: 4, event: "session_spawn", session_id: "ses_live", dispatch_state: "running" }),
      "malformed {{{",
    ].join("\n") + "\n")
    try {
      const registry = mod.createRegistry({
        directory: root,
        registryPath,
        messagesPath: nodeJoin(session, "messages.jsonl"),
        messagesMdPath: nodeJoin(session, "messages.md"),
        registrySeqPath: nodeJoin(session, "registry.seq"),
        messagesRowIdPath: nodeJoin(session, "messages.row-id"),
        journalLockPath: nodeJoin(session, "journal.lock"),
        archiveDir: nodeJoin(session, "registry-archive"),
      })
      assert.equal(typeof registry.getDiagnostics, "function", "RED-G: registry health diagnostics boundary required")
      const health = registry.getDiagnostics()
      for (const key of [
        "active_bytes", "active_count", "last_registry_seq", "last_message_row_id",
        "archive_count", "archive_bytes", "index_dirty", "last_rotation",
        "suppressed_duplicate_count", "malformed_examples",
      ]) assert.ok(Object.hasOwn(health, key), `RED-G: diagnostics missing ${key}`)
      assert.ok(Array.isArray(health.malformed_examples))
      assert.ok(health.malformed_examples.length <= 5, "RED-G: malformed diagnostics must be bounded")
      assert.equal(JSON.stringify(health).includes("prompt"), false, "RED-G: diagnostics must not expose prompt content")
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })

  it("reports durable sidecar high-water marks in diagnostics without writing", () => {
    const root = nodeFs.mkdtempSync(nodeJoin(tmpdir(), "tqor-health-sidecars-"))
    const session = nodeJoin(root, ".opencode/session")
    nodeFs.mkdirSync(session, { recursive: true })
    const registryPath = nodeJoin(session, "registry.jsonl")
    const messagesPath = nodeJoin(session, "messages.jsonl")
    const registrySeqPath = nodeJoin(session, "registry.seq")
    const messagesRowIdPath = nodeJoin(session, "messages.row-id")
    nodeFs.writeFileSync(registryPath, JSON.stringify({ seq: 4, event: "session_spawn", session_id: "ses_live", dispatch_state: "running" }) + "\n")
    nodeFs.writeFileSync(messagesPath, JSON.stringify({ row_id: 7, event_type: "delegation" }) + "\n")
    nodeFs.writeFileSync(registrySeqPath, "400\n")
    nodeFs.writeFileSync(messagesRowIdPath, "700\n")
    const before = {
      registry: nodeFs.readFileSync(registryPath, "utf8"),
      messages: nodeFs.readFileSync(messagesPath, "utf8"),
      registrySeq: nodeFs.readFileSync(registrySeqPath, "utf8"),
      messagesRowId: nodeFs.readFileSync(messagesRowIdPath, "utf8"),
    }
    try {
      const registry = mod.createRegistry({
        directory: root,
        registryPath,
        messagesPath,
        messagesMdPath: nodeJoin(session, "messages.md"),
        registrySeqPath,
        messagesRowIdPath,
        journalLockPath: nodeJoin(session, "journal.lock"),
        archiveDir: nodeJoin(session, "registry-archive"),
      })

      const health = registry.getDiagnostics()

      assert.equal(health.last_registry_seq, 400, "diagnostics must prefer durable registry.seq over lower JSONL history")
      assert.equal(health.last_message_row_id, 700, "diagnostics must prefer durable messages.row-id over lower JSONL history")
      assert.equal(nodeFs.readFileSync(registryPath, "utf8"), before.registry, "diagnostics must not write registry.jsonl")
      assert.equal(nodeFs.readFileSync(messagesPath, "utf8"), before.messages, "diagnostics must not write messages.jsonl")
      assert.equal(nodeFs.readFileSync(registrySeqPath, "utf8"), before.registrySeq, "diagnostics must not write registry.seq")
      assert.equal(nodeFs.readFileSync(messagesRowIdPath, "utf8"), before.messagesRowId, "diagnostics must not write messages.row-id")
      assert.equal(nodeFs.existsSync(nodeJoin(session, "journal.lock")), false, "diagnostics must not acquire the write lock")
    } finally {
      nodeFs.rmSync(root, { recursive: true, force: true })
    }
  })
})
