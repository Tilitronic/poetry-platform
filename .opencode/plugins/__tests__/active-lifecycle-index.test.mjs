/**
 * RED-C: exact lifecycle generations and bounded active projection.
 * Campaign ticket DIA-260914-tqor.
 *
 * The public seam is intentionally small: the GREEN implementation should
 * expose createActiveLifecycleIndex({ rows? }) from lib/registry.ts. The
 * index consumes ordered registry rows and returns only sweep-eligible
 * generations. No production code is changed in this RED lane.
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as registry from "../lib/registry.ts"

function makeIndex(rows = [], options = {}) {
  assert.equal(
    typeof registry.createActiveLifecycleIndex,
    "function",
    "GREEN must expose createActiveLifecycleIndex from lib/registry.ts",
  )
  return registry.createActiveLifecycleIndex({ rows, ...options })
}

function row(seq, event, dispatchState = "running", extra = {}) {
  return {
    seq,
    timestamp: new Date(1_000 + seq).toISOString(),
    session_id: "ses_generation",
    event,
    dispatch_state: dispatchState,
    ...extra,
  }
}

describe("DIA-260914-tqor RED-C exact lifecycle generations", () => {
  it("anchors on the first authoritative nonterminal row and keeps progress/spawn/stall/success in it", () => {
    const index = makeIndex([
      row(10, "dispatch", "running"),
      row(11, "progress", "running"),
      row(12, "session_spawn", "running"),
      row(13, "stall_detected", "running"),
      row(14, "task_success", "completed"),
    ])
    const entries = index.entries()
    assert.equal(entries.length, 0, "terminal success closes the anchored generation")
    assert.equal(index.generationFor("ses_generation"), 10)
  })

  it("starts a new anchor after terminal closure and explicit recovery/dispatch", () => {
    const index = makeIndex([
      row(10, "dispatch", "running"),
      row(11, "stopped_without_result", "running", { terminalUnreconciled: true }),
      row(20, "resume", "running", { recovery: "exact-session" }),
    ])
    assert.equal(index.generationFor("ses_generation"), 20)
    assert.deepEqual(index.entries().map((entry) => entry.lifecycle_generation), [20])
  })

  it("does not advance the generation on restart/bootstrap", () => {
    const first = makeIndex([row(10, "dispatch", "running"), row(11, "progress")])
    const second = makeIndex(first.exportRows())
    assert.equal(first.generationFor("ses_generation"), 10)
    assert.equal(second.generationFor("ses_generation"), 10)
  })

  it("does not create a new generation for repeated nonterminal rows without dispatch evidence", () => {
    const index = makeIndex([
      row(10, "dispatch", "running"),
      row(11, "event", "running"),
      row(12, "progress", "invoked"),
    ])
    assert.equal(index.generationFor("ses_generation"), 10)
    assert.equal(index.entries().length, 1)
  })

  it("keeps progress/running rows without an authoritative dispatch historical and ineligible", () => {
    const index = makeIndex([
      row(1, "progress", "running", { session_id: "ses_orphan" }),
      row(2, "event", "invoked", { session_id: "ses_orphan" }),
    ])
    assert.equal(index.generationFor("ses_orphan"), undefined)
    assert.equal(index.entries().some((entry) => entry.session_id === "ses_orphan"), false)
  })

  it("keeps dead diagnostic evidence in the current generation without making it terminal", () => {
    const index = makeIndex([
      row(10, "dispatch", "running"),
      row(11, "stall_detected", "running", { escalation: "dead" }),
    ])
    assert.equal(index.generationFor("ses_generation"), 10)
    const entry = index.entries()[0]
    assert.equal(entry.lifecycle_generation, 10)
    assert.equal(entry.dispatch_state, "running")
    assert.equal(entry.escalation, "dead")
  })

  it("keeps terminal-only and missing-ID chains out of the sweep-eligible projection", () => {
    const index = makeIndex([
      row(1, "task_success", "completed", { session_id: "ses_terminal_only" }),
      row(2, "stall_detected", "running", { session_id: undefined, task_id: undefined }),
    ])
    assert.equal(index.generationFor("ses_terminal_only"), undefined)
    assert.equal(index.entries().some((entry) => !entry.session_id), false)
    assert.equal(index.entries().some((entry) => entry.session_id === "ses_generation"), false)
  })

  it("orders legacy rows by seq, timestamp, then file offset deterministically", () => {
    const index = makeIndex([
      { ...row(31, "dispatch", "running"), timestamp: "2026-01-01T00:00:03.000Z", _offset: 30 },
      { ...row(30, "task_success", "completed"), timestamp: "2026-01-01T00:00:02.000Z", _offset: 20 },
      { ...row(30, "dispatch", "running"), timestamp: "2026-01-01T00:00:01.000Z", _offset: 10 },
    ])
    assert.equal(index.generationFor("ses_generation"), 31)
    assert.deepEqual(index.entries().map((entry) => entry.lifecycle_generation), [31])
  })

  it("records task_success against the open anchor before removing it from active entries", () => {
    const index = makeIndex([
      row(10, "dispatch", "running"),
      row(11, "task_success", "completed"),
    ])
    assert.equal(index.entries().length, 0)
    const terminal = index.history().find((entry) => entry.event === "task_success")
    assert.equal(terminal.lifecycle_generation, 10)
  })

  it("anchors a real child whose first durable row is session_spawn and closes on session_complete", () => {
    const index = makeIndex([
      row(40, "session_spawn", "running", {
        session_id: "ses_real_child",
        task_id: "task_real_child",
      }),
      row(41, "progress", "running", {
        session_id: "ses_real_child",
        task_id: "task_real_child",
      }),
      row(42, "session_complete", "completed", {
        session_id: "ses_real_child",
        task_id: "task_real_child",
      }),
    ])
    assert.equal(index.generationFor("ses_real_child"), 40)
    assert.equal(index.entries().some((entry) => entry.session_id === "ses_real_child"), false)
    assert.equal(
      index.history().find((entry) => entry.event === "session_complete").lifecycle_generation,
      40,
    )
  })

  it("rejects projection admission at its explicit bound without evicting existing live entries", () => {
    const index = makeIndex([], { maxEntries: 1 })
    index.apply(row(50, "dispatch", "running", { session_id: "ses_live" }))
    assert.throws(
      () => index.apply(row(51, "dispatch", "running", { session_id: "ses_second" })),
      /active projection bound/i,
      "capacity exhaustion must fail loudly",
    )
    assert.deepEqual(index.entries().map((entry) => entry.session_id), ["ses_live"])
  })

  it("lets a steady sweep consume projection and appended bytes without rereading the full registry", () => {
    const index = makeIndex([row(60, "dispatch", "running", { session_id: "ses_incremental" })])
    assert.equal(typeof index.consumeAppendedBytes, "function", "GREEN must expose incremental byte consumption")
    const fullReads = []
    assert.equal(
      index.consumeAppendedBytes({
        bytes: Buffer.from(JSON.stringify(row(61, "progress", "running", { session_id: "ses_incremental" })) + "\n"),
        readFullRegistry: () => fullReads.push(true),
      }),
      1,
    )
    assert.equal(fullReads.length, 0, "steady sweep must not perform a full registry read")
    assert.equal(index.generationFor("ses_incremental"), 60)
  })
})
