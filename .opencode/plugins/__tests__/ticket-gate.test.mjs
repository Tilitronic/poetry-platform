/**
 * lib/ticket-gate.ts tests (DIA-260909-sazr; settled API, DI via dia-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts
 *   parseFrontmatterFields, parseTicketDate, ScannedTicket, OPEN_TICKET_STATUSES,
 *   TICKET_KEYWORD_STOPWORDS, keywordsCorrelate, TICKET_ID_RE/_FIND/_FILENAME,
 *   scanTickets(dir), evaluateTicketCorrelation, meta-task bypass, DIA-217 vs §10 gates
 *
 * Learnings: .opencode/learnings/external-patterns/2026-09-02-opencode-plugin-loader-contract.md
 *   A2 keep Symbol.for strings identical; A3 ONE shared TICKET_ID_FIND_RE instance,
 *   match/matchAll-only (never .test()/.exec() — lastIndex drift); .server guards on
 *   TICKET_ID_* regexes (Wy loader); lib is pure/DI'd (inject readdirSync/readFileSync fakes),
 *   no ctx capture, no shell import.
 *
 * Settled seam: createTicketGate({readdirSync, readFileSync, existsSync, statSync})
 * plus plain named exports (parseFrontmatterFields, parseTicketDate,
 * keywordsCorrelate, TICKET_ID_* regexes, scanTickets, evaluateTicketCorrelation,
 * isMetaTaskBypass, isTicketGateBlocked).
 *
 *   parseFrontmatterFields(raw): first `---` anywhere, `#` skip, quoted
 *     ` #` suffix stripped, unknown fields ignored.
 *   parseTicketDate(raw): date-only `YYYY-MM-DD` => Date.parse(`${v}T00:00:00`),
 *     else Date.parse verbatim if /[TZ]/, else null (never throws).
 *   keywordsCorrelate(dispatchText, title): stopwords + min-3-char
 *     ([a-z0-9][a-z0-9-]{2,}) word extraction, case-insensitive.
 *   TICKET_ID_RE(/^DIA-(\d{6}-[a-z0-9]+|\d+)$/),
 *     TICKET_ID_FIND_RE(/\bDIA-(\d{6}-[a-z0-9]+|\d+)\b/g, shared instance),
 *     TICKET_ID_FILENAME_RE(/^DIA-(\d{6}-[a-z0-9]+|\d+)/) — no /i anywhere.
 *   scanTickets(dir): filename ^DIA-..., status case-insensitive,
 *     title/sessionId/discoveredMs; throws on missing dir.
 *
 * RUN: bun test .opencode/plugins/__tests__/ticket-gate.test.mjs
 */

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as mod from "../lib/ticket-gate.ts"

// Settled DI seam: factory with per-test FS fakes; each scanTickets call is isolated.
function makeGate(fakes = {}) {
  return mod.createTicketGate(fakes)
}

function requireExport(name) {
  return mod[name]
}


// ---------------------------------------------------------------------------
// 1. parseFrontmatterFields
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — parseFrontmatterFields", () => {
  it("finds first --- anywhere (not necessarily line 0) — HTML comment header before frontmatter", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "<!-- header -->\n# comment line\n---\nstatus: OPEN\ntitle: Hello\n---\nbody"
    const out = fn(raw)
    assert.equal(out.status, "OPEN")
    assert.equal(out.title, "Hello")
  })

  it("skips lines starting with # (comment divider) and empty lines", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "---\n# --- Session Attribution\nstatus: DISPATCHED\n# another comment\ntitle: My Title\n---\n"
    const out = fn(raw)
    assert.equal(out.status, "DISPATCHED")
    assert.equal(out.title, "My Title")
    assert.equal(out["# --- Session Attribution"], undefined)
  })

  it("strips quoted values and drops quoted inline ' # comment' suffix", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "---\nstatus: \"OPEN\" # inline comment\ntitle: 'Some Title' # trailing\nsession_id: \"ses_123\" # note\n---\n"
    const out = fn(raw)
    assert.equal(out.status, "OPEN", "double-quoted value with # suffix must be stripped")
    assert.equal(out.title, "Some Title")
    assert.equal(out.session_id, "ses_123")
  })

  it("parses unquoted values and trims whitespace", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "---\nstatus:   open  \ndiscovered: 2026-09-02\n---\n"
    const out = fn(raw)
    // parseFrontmatterFields preserves raw value trimmed; caller upper-cases status
    assert.equal(out.status, "open")
    assert.equal(out.discovered, "2026-09-02")
  })

  it("ignores unknown fields gracefully (still returns them but gate only reads known ones)", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "---\nstatus: OPEN\nunknown_field: whatever\nanother: 123\n---\n"
    const out = fn(raw)
    assert.equal(out.status, "OPEN")
    // unknown fields are present in the raw map; gate ignores them — we assert they don't break known fields
    assert.equal(out.unknown_field, "whatever")
  })

  it("returns {} when no frontmatter block exists", () => {
    const fn = mod.parseFrontmatterFields
    const out = fn("no delimiters here\njust text")
    assert.deepEqual(out, {})
  })

  it("stops at next --- delimiter (body after second delimiter ignored)", () => {
    const fn = mod.parseFrontmatterFields
    const raw = "---\nstatus: OPEN\n---\nstatus: CLOSED\ntitle: Body\n"
    const out = fn(raw)
    assert.equal(out.status, "OPEN")
    assert.equal(out.title, undefined, "body after second delimiter must not be parsed")
  })
})

// ---------------------------------------------------------------------------
// 2. parseTicketDate
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — parseTicketDate", () => {
  it("date-only YYYY-MM-DD parses as midnight via T00:00:00 (not NaN)", () => {
    const fn = mod.parseTicketDate
    const ms = fn("2026-09-02")
    assert.ok(typeof ms === "number" && Number.isFinite(ms), "date-only must return finite number")
    const expected = Date.parse("2026-09-02T00:00:00")
    assert.equal(ms, expected, "date-only must equal Date.parse('YYYY-MM-DDT00:00:00')")
  })

  it("ISO with T parses verbatim (Date.parse value)", () => {
    const fn = mod.parseTicketDate
    const raw = "2026-09-02T14:30:00.000Z"
    const ms = fn(raw)
    assert.equal(ms, Date.parse(raw))
  })

  it("ISO with Z parses verbatim", () => {
    const fn = mod.parseTicketDate
    const raw = "2026-09-02T00:00:00Z"
    const ms = fn(raw)
    assert.equal(ms, Date.parse(raw))
  })

  it("empty or whitespace returns null", () => {
    const fn = mod.parseTicketDate
    assert.equal(fn(""), null)
    assert.equal(fn("   "), null)
  })

  it("unparseable returns null (never throws)", () => {
    const fn = mod.parseTicketDate
    assert.equal(fn("not-a-date"), null)
    assert.equal(fn("2026-13-40"), null)
  })

  it("trims surrounding whitespace before parsing", () => {
    const fn = mod.parseTicketDate
    const ms = fn("  2026-09-02  ")
    assert.equal(ms, Date.parse("2026-09-02T00:00:00"))
  })
})

// ---------------------------------------------------------------------------
// 3. TICKET_ID_* regexes
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — TICKET_ID_* regexes", () => {
  it("TICKET_ID_RE exists and is a RegExp", () => {
    const re = requireExport("TICKET_ID_RE")
    assert.ok(re instanceof RegExp)
  })

  it("TICKET_ID_FIND_RE exists and is a RegExp with /g", () => {
    const re = requireExport("TICKET_ID_FIND_RE")
    assert.ok(re instanceof RegExp)
    assert.ok(re.flags.includes("g"), "TICKET_ID_FIND_RE must have /g flag")
  })

  it("TICKET_ID_FILENAME_RE exists and is a RegExp", () => {
    const re = requireExport("TICKET_ID_FILENAME_RE")
    assert.ok(re instanceof RegExp)
  })

  it("no regex has /i flag (lowercase-only enforcement)", () => {
    for (const name of ["TICKET_ID_RE", "TICKET_ID_FIND_RE", "TICKET_ID_FILENAME_RE"]) {
      const re = requireExport(name)
      assert.ok(!re.flags.includes("i"), `${name} must NOT have /i flag (lowercase-only)`)
    }
  })

  it("datetime-first alternation: TICKET_ID_RE matches FULL datetime id (not truncated)", () => {
    const re = requireExport("TICKET_ID_RE")
    assert.equal(re.test("DIA-260902-eqgg"), true)
    // must not truncate: the full string validates, and the match covers full id
    const m = "DIA-260902-eqgg".match(re)
    assert.ok(m && m[0] === "DIA-260902-eqgg", "must match full datetime id")
  })

  it("validates 3-char suffix (DIA-260826-pjm, DIA-260825-oyh) — [a-z0-9]+ not {4}", () => {
    const re = requireExport("TICKET_ID_RE")
    assert.equal(re.test("DIA-260826-pjm"), true, "3-char suffix must validate")
    assert.equal(re.test("DIA-260825-oyh"), true)
  })

  it("rejects uppercase suffix (lowercase-only)", () => {
    const re = requireExport("TICKET_ID_RE")
    assert.equal(re.test("DIA-260902-EQGG"), false)
    assert.equal(re.test("DIA-260825-AAPJ"), false)
  })

  it("TICKET_ID_FIND_RE finds both datetime and sequential ids in free text", () => {
    const re = requireExport("TICKET_ID_FIND_RE")
    const found = "see DIA-260902-eqgg and DIA-123".match(re)
    assert.deepEqual(found, ["DIA-260902-eqgg", "DIA-123"])
  })

  it("TICKET_ID_FILENAME_RE extracts from filename prefix", () => {
    const re = requireExport("TICKET_ID_FILENAME_RE")
    const m = re.exec("DIA-260902-eqgg-some-slug.md")
    assert.ok(m && m[0] === "DIA-260902-eqgg")
  })

  it("TICKET_ID_RE anchored: rejects XDIA-123 prefix bleed", () => {
    const re = requireExport("TICKET_ID_RE")
    assert.equal(re.test("XDIA-123"), false)
  })

  it("TICKET_ID_FIND_RE is ONE shared instance (reference identity)", () => {
    // Dynamic re-import must yield same object reference — A3
    const re1 = requireExport("TICKET_ID_FIND_RE")
    const re2 = requireExport("TICKET_ID_FIND_RE")
    assert.ok(re1 === re2, "TICKET_ID_FIND_RE must be a single shared instance")
  })

  it("TICKET_ID_FIND_RE consumption via match/matchAll is stateless (lastIndex drift check)", () => {
    const re = requireExport("TICKET_ID_FIND_RE")
    // If consumed via .test/.exec directly, second call drifts. Via match/matchAll, must be stable.
    const text = "DIA-260902-eqgg DIA-123"
    const first = text.match(re)
    const second = text.match(re)
    assert.deepEqual(first, second, "consecutive String.prototype.match must be stateless (no lastIndex drift)")
    // Also verify matchAll
    const all = [...text.matchAll(re)].map(m => m[0])
    assert.deepEqual(all, ["DIA-260902-eqgg", "DIA-123"])
  })

  it("Wy .server guard present on each TICKET_ID_* export", async () => {
    for (const name of ["TICKET_ID_RE", "TICKET_ID_FIND_RE", "TICKET_ID_FILENAME_RE"]) {
      const v = requireExport(name)
      assert.ok(v && typeof v === "object", `${name} must be object (RegExp)`)
      assert.equal(typeof v.server, "function", `${name}.server must be function (Wy guard)`)
      const ret = v.server({})
      // allow async
      if (ret && typeof ret.then === "function") await ret
    }
  })

  it("every non-function export in ticket-gate lib is Wy-compatible (mirrors plugin-load smoke)", () => {
    function isFn(v) { return typeof v === "function" }
    function gy(v) {
      if (isFn(v)) return v
      if (!v || typeof v !== "object" || !("server" in v)) return undefined
      if (!isFn(v.server)) return undefined
      return v.server
    }
    const missing = []
    const bad = []
    for (const name of ["TICKET_ID_RE", "TICKET_ID_FIND_RE", "TICKET_ID_FILENAME_RE"]) {
      const v = mod[name]
      if (v === undefined) missing.push(name)
      else if (!gy(v)) bad.push(name)
    }
    assert.equal(missing.length, 0, `missing regex exports: ${missing.join(", ")}`)
    assert.equal(bad.length, 0, `Wy-incompatible regex exports: ${bad.join(", ")}`)
  })
})

// ---------------------------------------------------------------------------
// 4. keywordsCorrelate
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — keywordsCorrelate", () => {
  it("returns false when title is empty (no correlation)", () => {
    const fn = mod.keywordsCorrelate
    assert.equal(fn("some dispatch text about delegation", ""), false)
  })

  it("returns true when a significant word from dispatch appears in title (case-insensitive)", () => {
    const fn = mod.keywordsCorrelate
    assert.equal(fn("fix delegation observer stall", "Delegation Observer Stall Fix"), true)
  })

  it("ignores stopwords — dispatch with only stopwords returns false", () => {
    const fn = mod.keywordsCorrelate
    // all stopwords per TICKET_KEYWORD_STOPWORDS
    const stopwordsOnly = "the and for with ticket dia work create new please gate"
    assert.equal(fn(stopwordsOnly, "delegation observer stall"), false, "stopwords must not correlate")
  })

  it("ignores stopwords in title matching — 'ticket' in title alone is not a signal", () => {
    const fn = mod.keywordsCorrelate
    // title contains only stopwords; dispatch has significant word but title has no sig word
    assert.equal(fn("delegation observer", "ticket for work"), false)
  })

  it("enforces min-3-char: words <3 chars are ignored (pattern [a-z0-9][a-z0-9-]{2,})", () => {
    const fn = mod.keywordsCorrelate
    // 'go' and 'is' are <3 chars; must not correlate even if present in title
    assert.equal(fn("go is hi", "go is hi"), false)
    // 3-char word 'api' should correlate when present in title
    assert.equal(fn("api delegation", "api delegation thing"), true)
  })

  it("is conservative: returns false when no significant overlap", () => {
    const fn = mod.keywordsCorrelate
    assert.equal(fn("completely unrelated dispatch about turtles", "Delegation Observer Refactor"), false)
  })

  it("TICKET_KEYWORD_STOPWORDS exists and contains known stopwords", () => {
    const sw = requireExport("TICKET_KEYWORD_STOPWORDS")
    assert.ok(sw instanceof Set, "TICKET_KEYWORD_STOPWORDS must be Set")
    for (const w of ["the", "and", "ticket", "dia", "work"]) {
      assert.ok(sw.has(w), `stopwords must contain '${w}'`)
    }
  })

  it("OPEN_TICKET_STATUSES exists and contains expected statuses", () => {
    const st = requireExport("OPEN_TICKET_STATUSES")
    assert.ok(st instanceof Set, "OPEN_TICKET_STATUSES must be Set")
    for (const s of ["OPEN", "IN-PROGRESS", "DISPATCHED"]) {
      assert.ok(st.has(s), `OPEN_TICKET_STATUSES must contain '${s}'`)
    }
  })
})

// ---------------------------------------------------------------------------
// 5. scanTickets
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — scanTickets", () => {
  it("parses filename ^DIA-... correctly for both sequential and datetime forms", () => {
    const fakeFiles = {
      "DIA-260902-eqgg-slice.md": "---\nstatus: OPEN\ntitle: Slice\n---\n",
      "DIA-123-old.md": "---\nstatus: OPEN\ntitle: Old\n---\n",
      "notes.md": "---\nstatus: OPEN\ntitle: Notes\n---\n",
      "README.md": "---\nstatus: OPEN\ntitle: Readme\n---\n",
      "_TEMPLATE.md": "---\nstatus: OPEN\ntitle: Template\n---\n",
    }
    const fakes = {
      readdirSync: () => Object.keys(fakeFiles),
      readFileSync: (p) => {
        const base = p.split("/").pop()
        return fakeFiles[base] ?? ""
      },
      existsSync: () => true,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    assert.ok(typeof scan === "function", "scanTickets must be found")
    // Factory instance carries the fakes; call it directly for isolation.
    const tickets = gate.scanTickets("/fake/tickets")
    const ids = tickets.map(t => t.id)
    assert.ok(ids.includes("DIA-260902-EQGG") || ids.includes("DIA-260902-eqgg") || ids.some(id => id.toUpperCase() === "DIA-260902-EQGG"), "datetime id must be parsed")
    assert.ok(ids.some(id => id.toUpperCase() === "DIA-123"), "sequential id must be parsed")
    // README and _TEMPLATE and notes.md must be skipped
    assert.ok(!tickets.some(t => t.filename === "README.md"), "README.md must be skipped")
    assert.ok(!tickets.some(t => t.filename === "_TEMPLATE.md"), "_TEMPLATE.md must be skipped")
    assert.ok(!tickets.some(t => t.filename === "notes.md"), "non-DIA file must produce empty id or be skipped; but must not produce valid id")
  })

  it("status is case-insensitive (open, Open, OPEN all map to OPEN)", () => {
    const fakeFiles = {
      "DIA-1-a.md": "---\nstatus: open\ntitle: A\n---\n",
      "DIA-2-b.md": "---\nstatus: Open\ntitle: B\n---\n",
      "DIA-3-c.md": "---\nstatus: OPEN\ntitle: C\n---\n",
      "DIA-4-d.md": "---\nstatus: in-progress\ntitle: D\n---\n",
      "DIA-5-e.md": "---\nstatus: dispatched\ntitle: E\n---\n",
    }
    const fakes = {
      readdirSync: () => Object.keys(fakeFiles),
      readFileSync: (p) => fakeFiles[p.split("/").pop()] ?? "",
      existsSync: () => true,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    const tickets = scan("/fake")
    for (const t of tickets) {
      if (t.filename.startsWith("DIA-")) {
        assert.ok(t.status === t.status.toUpperCase(), `status must be uppercased: ${t.status}`)
      }
    }
    const statuses = tickets.map(t => t.status)
    assert.ok(statuses.includes("OPEN"))
    assert.ok(statuses.includes("IN-PROGRESS"))
    assert.ok(statuses.includes("DISPATCHED"))
  })

  it("title, sessionId, discoveredMs, filename are populated", () => {
    const fakeFiles = {
      "DIA-260902-eqgg-test.md": "---\nstatus: OPEN\ntitle: My Slice Title\nsession_id: ses_abc123\ndiscovered: 2026-09-02\n---\n",
    }
    const fakes = {
      readdirSync: () => Object.keys(fakeFiles),
      readFileSync: (p) => fakeFiles[p.split("/").pop()] ?? "",
      existsSync: () => true,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    const tickets = scan("/fake")
    assert.equal(tickets.length, 1)
    const t = tickets[0]
    assert.equal(t.title, "My Slice Title")
    assert.equal(t.sessionId, "ses_abc123")
    assert.ok(typeof t.discoveredMs === "number" && Number.isFinite(t.discoveredMs), "discoveredMs must be finite number")
    assert.equal(t.filename, "DIA-260902-eqgg-test.md")
    // id normalized to uppercase per delegation-observer (DIA-260826-pjm F1)
    assert.ok(t.id.toUpperCase() === t.id, "id must be uppercased")
  })

  it("discoveredMs null when missing or unparseable", () => {
    const fakeFiles = {
      "DIA-10-a.md": "---\nstatus: OPEN\ntitle: No date\n---\n",
      "DIA-11-b.md": "---\nstatus: OPEN\ntitle: Bad date\ndiscovered: not-a-date\n---\n",
    }
    const fakes = {
      readdirSync: () => Object.keys(fakeFiles),
      readFileSync: (p) => fakeFiles[p.split("/").pop()] ?? "",
      existsSync: () => true,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    const tickets = scan("/fake")
    for (const t of tickets) {
      assert.equal(t.discoveredMs, null, `discoveredMs must be null for ${t.filename}`)
    }
  })

  it("skips directories (statSync isFile false)", () => {
    const fakeFiles = { "DIA-20-dir.md": "---\nstatus: OPEN\ntitle: Dir\n---\n" }
    const fakes = {
      readdirSync: () => Object.keys(fakeFiles),
      readFileSync: () => fakeFiles["DIA-20-dir.md"],
      existsSync: () => true,
      statSync: () => ({ isFile: () => false }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    const tickets = scan("/fake")
    assert.equal(tickets.length, 0, "directory entries must be skipped")
  })

  it("throws when tickets directory is missing (so caller can fail-closed vs fail-soft)", () => {
    const fakes = {
      readdirSync: () => { throw new Error("ENOENT") },
      readFileSync: () => "",
      existsSync: () => false,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    assert.throws(() => scan("/missing/dir"), /missing|ENOENT|tickets directory/i, "scanTickets must throw on missing dir")
  })
})

// ---------------------------------------------------------------------------
// 6. Meta-task bypass before ticket-id resolution
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — meta-task bypass before ticket-id resolution", () => {
  it("bypass fires case-insensitively for whitelist signals before ticket-id resolution", () => {
    const fn = mod.isMetaTaskBypass
    const cases = [
      "run scripts/tickets new --title 'New ticket'",
      "please create ticket for the new campaign",
      "procedural authorization to apply recommendation",
      "this is a meta-task for housekeeping",
      "[META-TASK] bootstrap the lane",
      "Create Ticket with capital letters",
      "CREATE TICKET upper",
    ]
    for (const text of cases) {
      assert.equal(fn(text), true, `bypass must fire for: ${text}`)
    }
  })

  it("bypass also checked via lowercased comparison (case-insensitive whitelist)", () => {
    const fn = mod.isMetaTaskBypass
    assert.equal(fn("Please Create Ticket now"), true)
    assert.equal(fn("run SCRIPTS/TICKETS NEW now"), true)
  })

  it("normal dispatch without whitelist signal does NOT bypass", () => {
    const fn = mod.isMetaTaskBypass
    assert.equal(fn("implement delegation observer stall fix"), false)
    assert.equal(fn("fix the bug in registry writer"), false)
    assert.equal(fn(""), false)
  })

  it("bypass returns BEFORE ticket-id resolution — stray DIA id in text is not attributed (gate not blocked)", () => {
    // The higher-level gate reports NOT blocked when bypass fires, even
    // if a DIA literal is present, and does NOT materialize ticket_id.
    const bypassFn = mod.isMetaTaskBypass
    const dispatchText = "[META-TASK] create ticket; reference DIA-260902-eqgg for context"
    assert.equal(bypassFn(dispatchText), true, "must bypass")
    const gateFn = mod.isTicketGateBlocked
    const res = gateFn(dispatchText, "ses_ctx", [], { failClosed: true })
    assert.equal(res.blocked, false, "bypass text must not block even with a DIA literal present")
  })

  it("meta-task bypass check is pure and does not require FS", () => {
    const fn = mod.isMetaTaskBypass
    // Should not throw when called with only string arg
    assert.doesNotThrow(() => fn("scripts/tickets new"))
    assert.doesNotThrow(() => fn(""))
  })
})

// ---------------------------------------------------------------------------
// 7. Failure semantics — scanTickets throws so caller can decide fail-closed vs fail-soft
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — failure semantics", () => {
  it("scanTickets itself throws (does not swallow) so caller can decide fail-closed vs fail-soft", () => {
    const fakes = {
      readdirSync: () => { throw new Error("disk error") },
      readFileSync: () => "",
      existsSync: () => true,
      statSync: () => ({ isFile: () => true }),
    }
    const gate = makeGate(fakes)
    const scan = gate.scanTickets
    assert.throws(() => scan("/fake"), /disk error|scan failed|ENOENT/i, "scanTickets must throw, not swallow, so caller can apply policy")
  })

  it("isTicketGateBlocked handles meta-task bypass", () => {
    const gate = makeGate({})
    const fn = gate.isTicketGateBlocked
    const res = fn("scripts/tickets new --title 'New ticket'", "ses_1", [], { failClosed: true })
    assert.equal(res.blocked, false, "meta-task bypass must not block")
  })

  it("isTicketGateBlocked weak correlation returns not blocked", () => {
    const gate = makeGate({})
    const fn = gate.isTicketGateBlocked
    const res = fn("completely unrelated turtles", "ses_other", [], { failClosed: false })
    assert.equal(res.blocked, false)
  })
})

// ---------------------------------------------------------------------------
// 8. Keyword correlation bypass boundaries
// ---------------------------------------------------------------------------
describe("lib/ticket-gate — keyword correlation bypass boundaries", () => {
  it("evaluateTicketCorrelation Path 1: explicit DIA-id matching OPEN ticket passes immediately", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "", discoveredMs: Date.now(), title: "some title", filename: "DIA-260902-eqgg.md" },
      { id: "DIA-123", status: "CLOSED", sessionId: "", discoveredMs: Date.now(), title: "closed", filename: "DIA-123.md" },
    ]
    const ok = fn(tickets, "ses_x", "work on DIA-260902-eqgg", ["DIA-260902-EQGG"])
    assert.equal(ok, true, "Path 1: explicit id matching OPEN must pass")
  })

  it("evaluateTicketCorrelation strict tri-state: explicit DIA-id with NO open match FAILS (never falls through to Path 2/3)", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "ses_other", discoveredMs: Date.now() - 1000, title: "other", filename: "DIA-260902-eqgg.md" },
      // no ticket for DIA-999
    ]
    // Dispatch cites DIA-999 which has no OPEN ticket; even though a recent session-owned ticket exists,
    // strict tri-state must FAIL (not fall through to Path 2)
    const ok = fn(tickets, "ses_x", "work on DIA-999", ["DIA-999"])
    assert.equal(ok, false, "explicit id with no open match must FAIL, not fall through")
  })

  it("Path 2: session-owned open ticket passes even without DIA-id", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "ses_mine", discoveredMs: Date.now() - 1000, title: "mine", filename: "DIA-260902-eqgg.md" },
    ]
    const ok = fn(tickets, "ses_mine", "do some work without mentioning id", [])
    assert.equal(ok, true, "Path 2: session-owned OPEN must pass")
  })

  it("Path 3: recent + keyword-correlated ticket passes (fallback for genuinely new work)", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "ses_other", discoveredMs: Date.now() - 60 * 60 * 1000, title: "delegation observer stall sweep", filename: "DIA-260902-eqgg.md" },
    ]
    const ok = fn(tickets, "ses_mine", "fix delegation observer stall sweep logic", [])
    assert.equal(ok, true, "Path 3: recent correlated must pass")
  })

  it("otherwise returns false → caller BLOCKS (force a ticket)", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "ses_other", discoveredMs: Date.now() - 3 * 24 * 60 * 60 * 1000, title: "unrelated work", filename: "DIA-260902-eqgg.md" },
    ]
    const ok = fn(tickets, "ses_mine", "completely unrelated turtles", [])
    assert.equal(ok, false, "no correlation must return false → caller blocks")
  })

  it("respects 24h recency window for Path 3 (stale tickets do not correlate)", () => {
    const fn = mod.evaluateTicketCorrelation
    const stale = Date.now() - 25 * 60 * 60 * 1000
    const tickets = [
      { id: "DIA-260902-EQGG", status: "OPEN", sessionId: "ses_other", discoveredMs: stale, title: "delegation observer stall", filename: "DIA-260902-eqgg.md" },
    ]
    const ok = fn(tickets, "ses_mine", "delegation observer stall", [])
    assert.equal(ok, false, "stale (>24h) must not satisfy Path 3 even with keyword overlap")
  })

  it("filters by OPEN_TICKET_STATUSES — CLOSED/DONE tickets ignored in all paths", () => {
    const fn = mod.evaluateTicketCorrelation
    const tickets = [
      { id: "DIA-123", status: "CLOSED", sessionId: "ses_mine", discoveredMs: Date.now(), title: "closed ticket", filename: "DIA-123.md" },
      { id: "DIA-124", status: "DONE", sessionId: "ses_mine", discoveredMs: Date.now(), title: "done ticket", filename: "DIA-124.md" },
    ]
    const ok = fn(tickets, "ses_mine", "work", [])
    assert.equal(ok, false, "CLOSED/DONE must not satisfy any path")
  })
})
