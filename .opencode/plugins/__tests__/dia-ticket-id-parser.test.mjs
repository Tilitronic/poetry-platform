/**
 * DIA-260826-pjm test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: three named regex exports from delegation-observer.ts
 * that centralize DIA ticket-ID parsing (currently duplicated inline in 4+
 * places, one of them with a digit-first alternation that TRUNCATES
 * datetime IDs):
 *
 *   TICKET_ID_RE          /^DIA-(\d{6}-[a-z0-9]+|\d+)$/          validation
 *   TICKET_ID_FIND_RE     /\bDIA-(\d{6}-[a-z0-9]+|\d+)\b/g       free-text scan
 *   TICKET_ID_FILENAME_RE /^DIA-(\d{6}-[a-z0-9]+|\d+)/           filename scan
 *
 * Suffix is [a-z0-9]+ by pinned decision (F2/F3): ledger reality is 53
 * four-char plus 2 three-char suffixes (pjm, oyh) - the nominal DIA-234 {4}
 * would reject the campaign's own ticket id.
 *
 * Core regression being pinned (DIA-234): datetime IDs (DIA-YYMMDD-xxxx)
 * must parse as their FULL id everywhere - never truncated to DIA-YYMMDD.
 * Alternation order matters: the datetime branch is tried BEFORE \d+.
 *
 * RED-phase note: these exports do not exist yet. Every test resolves its
 * regex through requireExport(), which throws an explicit, actionable
 * message naming the missing export instead of an opaque loader error.
 *
 * ASCII-only per DIA-079 (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (bun on host, or inside the poetry-dev container):
 *   cd /workspace/.opencode/plugins/__tests__ && \
 *   bun test dia-ticket-id-parser.test.mjs
 */
import { mock, test, expect } from "bun:test"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
// Same mock shape as dia217-ticket-gate.test.mjs: the plugin module imports
// the tool helper at load time; resolution must not depend on node_modules.
const desc = { describe: () => desc }
const withOptional = { optional: () => desc }
const schema = { enum: () => withOptional, string: () => withOptional }
const toolFn = (def) => def
toolFn.schema = schema
mock.module("@opencode-ai/plugin", () => ({ tool: toolFn }))

// Dynamic import AFTER mock.module registration (defeats ESM hoisting).
// Wrapped so a hard import failure still yields per-test clear messages.
let observerModule = null
let moduleImportError = null
try {
  observerModule = await import("../delegation-observer.ts")
} catch (err) {
  moduleImportError = err instanceof Error ? err : new Error(String(err))
}

/**
 * Resolve one parser export, failing with an explicit RED-scaffold message
 * when the GREEN implementation has not landed yet (DIA-175: this lane
 * writes tests only; a different coder instance adds the exports).
 */
function requireExport(name) {
  if (moduleImportError) {
    throw new Error(
      `RED scaffold: cannot import ../delegation-observer.ts (${moduleImportError.message}) - fix the import before judging parser behavior`
    )
  }
  const value = observerModule[name]
  if (value === undefined) {
    throw new Error(
      `RED scaffold: delegation-observer.ts does not export '${name}' yet - GREEN implementer must add 'export const ${name}' (see DIA-260826-pjm)`
    )
  }
  return value
}

// ---------------------------------------------------------------------------
// TICKET_ID_RE (validation, anchored): accepts sequential + datetime formats
// ---------------------------------------------------------------------------

test("DIA-260826-pjm: TICKET_ID_RE validates sequential id DIA-123", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-123")).toBe(true)
})

test("DIA-260826-pjm: TICKET_ID_RE validates datetime id DIA-260825-aapj", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-260825-aapj")).toBe(true)
})

test("DIA-260826-pjm: TICKET_ID_RE validates datetime id DIA-260826-pjm", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-260826-pjm")).toBe(true)
})

test("DIA-260826-pjm: TICKET_ID_RE validates 3-digit sequential edge DIA-001", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-001")).toBe(true)
})

test("DIA-260826-pjm: TICKET_ID_RE validates 6-digit sequential DIA-999999 (falls through datetime branch)", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-999999")).toBe(true)
})

test("DIA-260826-pjm: TICKET_ID_RE rejects XDIA-123 (anchored, no prefix bleed)", () => {
  expect(requireExport("TICKET_ID_RE").test("XDIA-123")).toBe(false)
})

test("DIA-260826-pjm: TICKET_ID_RE rejects uppercase suffix DIA-260825-AAPJ (lowercase-only)", () => {
  expect(requireExport("TICKET_ID_RE").test("DIA-260825-AAPJ")).toBe(false)
})

// ---------------------------------------------------------------------------
// TICKET_ID_FILENAME_RE (filename scan, head-anchored)
// ---------------------------------------------------------------------------

test("DIA-260826-pjm: TICKET_ID_FILENAME_RE extracts FULL datetime id from filename (core regression: never truncated to DIA-260825)", () => {
  const match = requireExport("TICKET_ID_FILENAME_RE").exec(
    "DIA-260825-aapj-schema-pass-through.md"
  )
  expect(match).not.toBeNull()
  expect(match[0]).toBe("DIA-260825-aapj")
})

test("DIA-260826-pjm: TICKET_ID_FILENAME_RE extracts sequential id from filename", () => {
  const match = requireExport("TICKET_ID_FILENAME_RE").exec(
    "DIA-123-boot-row-fields.md"
  )
  expect(match).not.toBeNull()
  expect(match[0]).toBe("DIA-123")
})

test("DIA-260826-pjm: TICKET_ID_FILENAME_RE extracts 3-digit sequential edge from filename", () => {
  const match = requireExport("TICKET_ID_FILENAME_RE").exec(
    "DIA-001-first-ticket.md"
  )
  expect(match).not.toBeNull()
  expect(match[0]).toBe("DIA-001")
})

test("DIA-260826-pjm: TICKET_ID_FILENAME_RE returns null for filename without a DIA id", () => {
  expect(requireExport("TICKET_ID_FILENAME_RE").exec("changelog-notes.md")).toBeNull()
})

// ---------------------------------------------------------------------------
// TICKET_ID_FIND_RE (free-text scan, global)
// ---------------------------------------------------------------------------

test("DIA-260826-pjm: TICKET_ID_FIND_RE finds both FULL ids in free text (datetime + sequential)", () => {
  // String.prototype.match with a /g regex is stateless across calls, so
  // this avoids the lastIndex pitfall of reusing one global regex object.
  const found = "gate sees DIA-260825-aapj and DIA-123".match(
    requireExport("TICKET_ID_FIND_RE")
  )
  expect(found).toEqual(["DIA-260825-aapj", "DIA-123"])
})

test("DIA-260826-pjm: TICKET_ID_FIND_RE scans campaign marker with FULL datetime id (not truncated DIA-260825)", () => {
  const found =
    "campaign ticket DIA-260826-pjm - LANE-0 CHECKSUM VERIFICATION ONLY.".match(
      requireExport("TICKET_ID_FIND_RE")
    )
  expect(found).toEqual(["DIA-260826-pjm"])
})

test("DIA-260826-pjm: TICKET_ID_FIND_RE does not match XDIA-123 (word boundary)", () => {
  expect("XDIA-123".match(requireExport("TICKET_ID_FIND_RE"))).toBeNull()
})

// ---------------------------------------------------------------------------
// F2/F5 (fix loop): pinned over-acceptance + malformed-token edges.
// ---------------------------------------------------------------------------

test("DIA-260826-pjm F2: suffix length is deliberately unbounded [a-z0-9]+ (over-long and sub-nominal suffixes validate)", () => {
  // Pinned decision: [a-z0-9]+ over-accepts relative to the nominal DIA-234
  // {4} ON PURPOSE - ledger reality is 53 four-char plus 2 three-char
  // suffixes (pjm, oyh), so {4} would reject the campaign's own ticket.
  // Bounded impact: loose FORMAT validation only routes onward to
  // filename-existence checking (warn-and-allow on miss); it never bypasses
  // a gate. The sequential branch \d+ was already unbounded pre-fix.
  const re = requireExport("TICKET_ID_RE")
  expect(re.test("DIA-260825-abcde123")).toBe(true)
  expect(re.test("DIA-260825-ab")).toBe(true)
})

test("DIA-260826-pjm F5a: trailing word-char poisons a datetime id - the full malformed token never validates", () => {
  // Appending uppercase X kills the datetime branch ([a-z0-9] class + the
  // anchored $) and the \d+ fallback cannot cover the suffix. Silent-drop
  // intent: a mutated id must never pass validation AS that id.
  expect(requireExport("TICKET_ID_RE").test("DIA-260825-aapjX")).toBe(false)
})

test("DIA-260826-pjm F5a: free-text scan of a poisoned id degrades to the digit prefix, never the full token", () => {
  // FIND_RE falls back to its \d+ branch: extraction yields the truncated
  // digit prefix DIA-260825 (which cannot resolve to any datetime-format
  // ticket file downstream), never the malformed full string.
  expect(
    "gate saw DIA-260825-aapjX today".match(requireExport("TICKET_ID_FIND_RE"))
  ).toEqual(["DIA-260825"])
})

test("DIA-260826-pjm F5a: filename scan of a poisoned id truncates at the first non-lowercase char", () => {
  // FILENAME_RE is start-anchor only (no trailing \b), so greedy [a-z0-9]+
  // stops naturally before X.
  expect(
    requireExport("TICKET_ID_FILENAME_RE").exec("DIA-260825-aapjX.md")?.[0]
  ).toBe("DIA-260825-aapj")
})

// F5c: the Path-1 case-insensitive correlation contract is pinned by the
// integration regression test "DIA-260826-pjm F1: datetime ticket correlates
// through Path 1 regardless of citation case" in dia217-ticket-gate.test.mjs
// (lowercase-suffix ticket file must correlate; not duplicated here).
