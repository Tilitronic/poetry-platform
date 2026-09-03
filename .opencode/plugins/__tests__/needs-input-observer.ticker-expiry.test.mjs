/**
 * DIA-260822-unsn RED test - ticker expiry purge for needs-input-observer.
 *
 * Defect (DIA-260822-wr2e F4/F5, verified present):
 *   persist() (L614) and seedFromDisk() (L642) carry waiting/errors entries
 *   verbatim - no helper to drop invalid since, no age check. seedFromDisk
 *   falls back invalid since to nowISO instead of purging.
 *
 * Required behavior (the test encodes, does NOT implement):
 *   - single shared purge helper invoked from BOTH seedFromDisk and persist
 *   - drop entry whose `since` is not valid parseable ISO timestamp
 *   - drop question/permission waiting >24h
 *   - drop idle waiting >4h
 *   - drop errors >48h
 *   - valid current entries survive persist round-trip
 *
 * Harness mirrors needs-input-observer.dia189.test.mjs (bun:test, mock spawn,
 * per-test mkdtemp dir, globalThis singleton clear).
 */

import { mock, test, expect, beforeEach } from "bun:test"
import { existsSync, mkdirSync, readFileSync, writeFileSync, mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// DIA-260821-5r03 singleton guards - clear per test for isolation (same as dia189)
const NI_PERM_TIMERS_KEY = Symbol.for("needs-input-observer.permissionTimers")
const NI_TITLE_BOOT_KEY = Symbol.for("needs-input-observer.titleSuffixBootDone")
const NI_TOAST_KEY = Symbol.for("needs-input-observer.notifiedAsks")
const NI_TICKER_BOOT_KEY = Symbol.for("needs-input-observer.tickerBootSeeded")
beforeEach(() => {
  globalThis[NI_PERM_TIMERS_KEY] = undefined
  globalThis[NI_TITLE_BOOT_KEY] = undefined
  globalThis[NI_TOAST_KEY] = undefined
  globalThis[NI_TICKER_BOOT_KEY] = undefined
})

const spawnCalls = []
mock.module("node:child_process", () => ({
  spawn: (cmd, args, opts) => {
    spawnCalls.push({ cmd, args, opts })
    return { on: () => {} }
  },
  spawnSync: () => { throw new Error("spawnSync not mocked in ticker-expiry test") },
}))

const { default: createNeedsInputObserver } = await import("../needs-input-observer.ts")

function hoursAgo(h) {
  return new Date(Date.now() - h * 3600 * 1000).toISOString()
}
function nowISO() {
  return new Date().toISOString()
}
function tickerPath(dir) {
  return join(dir, ".opencode/session/ticker.json")
}
function writeTicker(dir, doc) {
  mkdirSync(join(dir, ".opencode/session"), { recursive: true })
  writeFileSync(tickerPath(dir), JSON.stringify(doc, null, 2) + "\n")
}
function readTicker(dir) {
  if (!existsSync(tickerPath(dir))) return null
  return JSON.parse(readFileSync(tickerPath(dir), "utf-8"))
}
function freshCtx(directory) {
  const ctx = {
    directory,
    client: {
      session: {
        get: async () => ({ data: { title: "Test" }, error: undefined }),
        update: async () => ({}),
        list: async () => [],
      },
      pty: { list: async () => [], update: async () => ({}) },
      tui: { showToast: async () => ({}) },
      app: { log: async () => {} },
      postSessionIdPermissionsPermissionId: async () => ({}),
    },
  }
  return ctx
}
async function compactSnapshot(hooks) {
  const output = { context: [] }
  const fn = hooks["experimental.session.compacting"]
  if (fn) await fn({}, output)
  return output.context.join("\n")
}
function questionAskedEvent(sessionID, detail = "need input") {
  return { event: { type: "question.asked", properties: { sessionID, questions: [{ question: detail }] } } }
}

// ---------------------------------------------------------------------------
// 1. Invalid/unparseable `since` dropped on seed AND on persist (AC 1)
// ---------------------------------------------------------------------------

test("AC1a RED: invalid since waiting entry dropped on seed (compact snapshot excludes it)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [
      { session_id: "sess-invalid", reason: "question", detail: "bad", since: "not-a-date" },
      { session_id: "sess-valid", reason: "question", detail: "good", since: nowISO() },
    ],
    errors: [],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  const snap = await compactSnapshot(hooks)
  // valid must be present, invalid must be absent - RED today both present
  expect(snap).toContain("sess-valid")
  expect(snap).not.toContain("sess-invalid")
})

test("AC1b RED: invalid since waiting entry dropped on persist (file after persist excludes it)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [
      { session_id: "sess-invalid", reason: "question", detail: "bad", since: "bogus-timestamp" },
      { session_id: "sess-valid", reason: "question", detail: "good", since: nowISO() },
    ],
    errors: [],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  // trigger persist via a new valid enter
  await hooks.event(questionAskedEvent("sess-trigger", "trigger"))
  const doc = readTicker(dir)
  const ids = (doc.waiting || []).map((e) => e.session_id)
  expect(ids).toContain("sess-valid")
  expect(ids).not.toContain("sess-invalid")
})

test("AC1c RED: invalid since error entry dropped on seed (errors bucket)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [],
    errors: [
      { session_id: "err-invalid", since: "not-a-date", error: "boom" },
      { session_id: "err-valid", since: nowISO(), error: "ok" },
    ],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  await hooks.event(questionAskedEvent("sess-trigger2", "trigger"))
  const doc = readTicker(dir)
  const ids = (doc.errors || []).map((e) => e.session_id)
  expect(ids).toContain("err-valid")
  expect(ids).not.toContain("err-invalid")
})

// ---------------------------------------------------------------------------
// 2. question/permission waiting >24h purged, younger retained (AC 2)
// ---------------------------------------------------------------------------

test("AC2 RED: question waiting >24h purged on seed, younger retained", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [
      { session_id: "sess-stale-q", reason: "question", detail: "old", since: hoursAgo(30) },
      { session_id: "sess-fresh-q", reason: "question", detail: "new", since: hoursAgo(1) },
      { session_id: "sess-stale-perm", reason: "permission", detail: "old", since: hoursAgo(30) },
      { session_id: "sess-fresh-perm", reason: "permission", detail: "new", since: hoursAgo(1) },
    ],
    errors: [],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  const snap = await compactSnapshot(hooks)
  expect(snap).toContain("sess-fresh-q")
  expect(snap).toContain("sess-fresh-perm")
  expect(snap).not.toContain("sess-stale-q")
  expect(snap).not.toContain("sess-stale-perm")
})

// ---------------------------------------------------------------------------
// 3. idle waiting >4h purged, younger retained (AC 3)
// ---------------------------------------------------------------------------

test("AC3 RED: idle waiting >4h purged on seed, younger retained", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [
      { session_id: "sess-stale-idle", reason: "idle", detail: "old idle", since: hoursAgo(5) },
      { session_id: "sess-fresh-idle", reason: "idle", detail: "new idle", since: hoursAgo(1) },
    ],
    errors: [],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  const snap = await compactSnapshot(hooks)
  expect(snap).toContain("sess-fresh-idle")
  expect(snap).not.toContain("sess-stale-idle")
})

// ---------------------------------------------------------------------------
// 4. errors >48h purged, younger retained (AC 4)
// ---------------------------------------------------------------------------

test("AC4 RED: errors >48h purged on seed via persist, younger retained", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [],
    errors: [
      { session_id: "err-stale", since: hoursAgo(50), error: "old" },
      { session_id: "err-fresh", since: hoursAgo(1), error: "new" },
    ],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  await hooks.event(questionAskedEvent("sess-trigger3", "trigger"))
  const doc = readTicker(dir)
  const ids = (doc.errors || []).map((e) => e.session_id)
  expect(ids).toContain("err-fresh")
  expect(ids).not.toContain("err-stale")
})

// ---------------------------------------------------------------------------
// 5. Mixed valid/invalid/stale yields only valid in-window entries (AC 5)
// ---------------------------------------------------------------------------

test("AC5 RED: mixed ticker with valid/invalid/stale entries yields only valid in-window after seed+persist", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  writeTicker(dir, {
    version: 1,
    updated_at: nowISO(),
    waiting: [
      { session_id: "sess-invalid-since", reason: "question", detail: "bad", since: "invalid" },
      { session_id: "sess-stale-question", reason: "question", detail: "old q", since: hoursAgo(30) },
      { session_id: "sess-stale-idle", reason: "idle", detail: "old idle", since: hoursAgo(5) },
      { session_id: "sess-fresh-question", reason: "question", detail: "new q", since: hoursAgo(2) },
      { session_id: "sess-fresh-idle", reason: "idle", detail: "new idle", since: hoursAgo(1) },
    ],
    errors: [
      { session_id: "err-invalid", since: "bad-date", error: "bad" },
      { session_id: "err-stale", since: hoursAgo(60), error: "old" },
      { session_id: "err-fresh", since: hoursAgo(1), error: "new" },
    ],
    permissions: [],
  })
  const ctx = freshCtx(dir)
  const hooks = await createNeedsInputObserver(ctx)
  await hooks.event(questionAskedEvent("sess-trigger-mixed", "trigger"))
  const doc = readTicker(dir)
  const waitingIds = (doc.waiting || []).map((e) => e.session_id)
  const errorIds = (doc.errors || []).map((e) => e.session_id)
  // valid in-window must survive
  expect(waitingIds).toContain("sess-fresh-question")
  expect(waitingIds).toContain("sess-fresh-idle")
  expect(errorIds).toContain("err-fresh")
  // trigger session also valid
  expect(waitingIds).toContain("sess-trigger-mixed")
  // invalid and stale must be purged
  expect(waitingIds).not.toContain("sess-invalid-since")
  expect(waitingIds).not.toContain("sess-stale-question")
  expect(waitingIds).not.toContain("sess-stale-idle")
  expect(errorIds).not.toContain("err-invalid")
  expect(errorIds).not.toContain("err-stale")
})

// ---------------------------------------------------------------------------
// 6. Valid current entries survive persist round-trip (AC 6 / no regression)
// ---------------------------------------------------------------------------

test("AC6 RED: valid current entries survive a persist round-trip", async () => {
  const dir = mkdtempSync(join(tmpdir(), "ticker-expiry-"))
  // first plugin creates a valid entry via event (fresh since)
  const ctx1 = freshCtx(dir)
  const hooks1 = await createNeedsInputObserver(ctx1)
  await hooks1.event(questionAskedEvent("sess-roundtrip", "keep me"))
  let doc = readTicker(dir)
  expect((doc.waiting || []).map((e) => e.session_id)).toContain("sess-roundtrip")

  // second plugin seeds from disk (simulates restart) and persists again
  globalThis[NI_PERM_TIMERS_KEY] = undefined
  globalThis[NI_TITLE_BOOT_KEY] = undefined
  globalThis[NI_TOAST_KEY] = undefined
  globalThis[NI_TICKER_BOOT_KEY] = undefined
  const ctx2 = freshCtx(dir)
  const hooks2 = await createNeedsInputObserver(ctx2)
  // trigger another persist with a new session, old valid should still be there
  await hooks2.event(questionAskedEvent("sess-roundtrip-2", "second"))
  doc = readTicker(dir)
  const ids = (doc.waiting || []).map((e) => e.session_id)
  expect(ids).toContain("sess-roundtrip")
  expect(ids).toContain("sess-roundtrip-2")
})
