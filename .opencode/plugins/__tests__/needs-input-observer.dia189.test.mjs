/**
 * DIA-189 RED test harness (test-author lane, DIA-175 instance separation).
 *
 * Defects under test (all in .opencode/plugins/needs-input-observer.ts, the
 * DIA-122 plugin):
 *   P1  every session shows the identical default TUI title "opencode <cwd>";
 *       nothing calls ctx.client.session.update to set unique titles.
 *   P2  notifications are not attributed to a session: body is
 *       "title + reason: detail" with no session-id discriminator.
 *   P3  fireDesktopToast ascii() does .replace(/[^\x20-\x7E]/g, " ") which
 *       strips ALL non-ASCII - Cyrillic Ukrainian text becomes invisible in
 *       the WinRT desktop toast.
 *
 * Approved fix design (Variant A, developer-approved 2026-08-15) that these
 * tests must encode:
 *   A1  on session.created, if title is missing/empty OR matches the default
 *       label pattern (starts with "opencode "), call
 *       ctx.client.session.update({ path: { id }, body: { title: derived } })
 *       where derived = baseTitle + " [" + id.slice(-6) + "]"
 *       (baseTitle = existing info.title if non-empty else the default label).
 *       Guards: skip when the title already ends with " [xxxxxx]" (no double
 *       rename); a session.update error must warn and continue, never crash.
 *   A2  notify() must include the short-id suffix " [<id.slice(-6)>]" in the
 *       notification title for BOTH the tui.showToast title and the desktop
 *       toast title (so the notification matches the renamed terminal label).
 *   A3  the desktop-toast sanitizer must PRESERVE printable Unicode (Cyrillic
 *       U+0400-U+04FF and other scripts) while still stripping control chars
 *       (U+0000-U+001F, U+007F-U+009F), collapsing CR/LF/TAB to spaces,
 *       doubling single quotes for PowerShell, and truncating to 180 chars.
 *       The old [^\x20-\x7E] strip is the bug - it must go.
 *
 * Hermetic: no filesystem writes outside a per-test mkdtemp dir (the plugin
 * writes its ticker.json under ctx.directory); powershell.exe spawn is
 * intercepted via bun mock.module("node:child_process", ...) so no real
 * subprocess ever runs; @opencode-ai/plugin is imported type-only by the
 * plugin (erased at transpile) so no node_modules resolution is needed.
 *
 * DIA-079 exemption: this file deliberately contains one Cyrillic literal
 * ("Потрібна допомога") - it is user-facing notification test DATA required
 * by DIA-189 A3, not source formatting. The ticket's Verification section
 * carves this out: "only user-facing notification text carries Unicode".
 * Everything else in this file is ASCII.
 *
 * RUN COMMAND (documented 2026-08-15, VERIFIED):
 *   bun was NOT installed on the host (`bun --version` -> command not found).
 *   The dev container has bun 1.3.14 at /usr/local/bin/bun but only mounts
 *   the main tree at /workspace - the sibling worktree is invisible there.
 *   Used the oven/bun:1.3.14 image (same 1.3.14) with the worktree
 *   bind-mounted read-write. NOTE: `bun test` skips dot-directories in its
 *   default file discovery, so a path filter like
 *   `.opencode/plugins/__tests__/<file>` does NOT match - the command must
 *   run FROM inside the __tests__ directory:
 *
 *   docker run --rm -v /home/qualt/Projects/poetry-platform-wt-dia189:/work \
 *     -w /work/.opencode/plugins/__tests__ --entrypoint bun oven/bun:1.3.14 \
 *     test needs-input-observer.dia189.test.mjs
 *
 *   DIA-189b worktree path: /home/qualt/Projects/poetry-platform-wt-dia189b
 *   (old worktree squash-merged and retired - do not reuse it):
 *
 *   docker run --rm -v /home/qualt/Projects/poetry-platform-wt-dia189b:/work \
 *     -w /work/.opencode/plugins/__tests__ --entrypoint bun oven/bun:1.3.14 \
 *     test needs-input-observer.dia189.test.mjs
 *
 *   Verified result today (2026-08-15): 6 pass, 5 fail - the RED tests fail
 *   for the RIGHT reasons (A1a/A1c: no session.update call at all; A2: toast
 *   title lacks [abcdef]; A3: Cyrillic replaced by spaces in the script) and
 *   the guard regressions A1b/A1d/A3b/A3c/A3d PASS.
 *
 *   Post-implementation: 11/11 green (after 60a1671 SHORT_ID fix), then 3
 *   ai-auditor F4 coverage tests added (A1f error-branch fail-soft, A2
 *   no-double-append, A3e C1-range strip) -> 13/13 green.
 *
 *   DIA-189b follow-up (2026-08-15): Variant A fixed Session.title, but the
 *   visible terminal strip is the PTY strip (Pty.title) - cod-7 recon:
 *   ctx.client.pty.list/update exist (PUT /pty/{id}, PtyUpdateData.title?),
 *   pty.created/updated events reach the event hook, and the plugin handles
 *   NO pty events today. New RED tests (P1a-P1d pty.created rename +
 *   guards, P2a-P2d boot retro pass over pty.list/session.list + guards).
 *
 *   CORRECTION vs dispatch spec (documented): the dispatch proposed
 *   id "pty_abcdef123456" with suffix "[3456]", but that id's slice(-6) is
 *   "123456" ("3456" is slice(-4)) and the guard regex / \[\w{6}\]$/ does
 *   NOT match "[3456]" (4 chars). All pty expectations below use the
 *   design-consistent slice(-6) suffix "[123456]".
 *
 *   DISPATCH-PREDICTION DEVIATION (documented): the dispatch predicted P1d
 *   "passes trivially today", but its own P1d spec requires "a console.warn
 *   mentioning 'pty' is emitted" - impossible today because the plugin has
 *   NO pty handling, so pty.update is never called and no warn can fire.
 *   The warn assertion is the meaningful fail-soft check (catches a
 *   silently-swallowing implementation), so P1d is RED today for the right
 *   reason and flips green with A1b. Actual split today: 18 pass / 4 fail
 *   (P1a, P1d, P2a, P2c RED; guards P1b/P1c/P2b/P2d pass).
 *
 *   DIA-189 fix follow-up (2026-08-15, runtime probe cod-4): the rename
 *   guard used isDefaultLabel (title === "" || startsWith("opencode ")), but
 *   opencode 1.18.18 defaults sessions to "New session - <ISO>" and ptys to
 *   "Terminal N" / "Terminal <id4>", so the rename NEVER fired (0 of 1,742
 *   all-time sessions ever carried a suffix). Developer-approved fix:
 *   rename-if-not-suffixed - append " [<id.slice(-6)>]" to ANY unsuffixed
 *   title (default OR user-set); the alreadySuffixed / \[\w{6}\]$/ dedupe
 *   guard is the only gate. DEFAULT_TITLE and DEFAULT_PTY_TITLE now carry the
 *   real runtime defaults; A1a/A1b/P1a/P1b/P2a/P2b/P2c/F5/F6a/G1 are RED
 *   against the old guard and flip GREEN with the fix (G2 stays a guard).
 */
import { mock, test, expect, beforeEach } from "bun:test"
import { mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { basename, join } from "node:path"

// DIA-260821-5r03: the plugin now keeps process-scoped singleton guards on
// globalThis (toast-dedupe Set, title-boot flag, ticker-boot flag, permission
// timer Map). bun shares globalThis across tests in one file, so clear them
// before each test to preserve per-test factory isolation (same pattern as
// delegation-observer.reload-dedup.test.mjs).
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

// ---- powershell.exe spawn interception (A3 desktop-toast path) ----
// The plugin imports `spawn` from node:child_process at module top, so the
// mock must be registered BEFORE the plugin module is loaded -> dynamic
// import below. The spy records (cmd, args, opts); args[2] is the
// PowerShell -Command script carrying the sanitized title/body.
const spawnCalls = []
mock.module("node:child_process", () => ({
  spawn: (cmd, args, opts) => {
    spawnCalls.push({ cmd, args, opts })
    // The plugin attaches child.on("error", cb) - return a stub with on().
    return { on: () => {} }
  },
  // ponytail: stub to prevent cross-file mock leakage from breaking
  // delegation-observer.ts (which imports spawnSync). The mock.module
  // leak is a bun 1.3.14 limitation; upgrade trigger: check if bun test
  // isolates mock.module per file in a future release.
  spawnSync: () => { throw new Error("spawnSync not mocked in dia189 test") },
}))

// Import AFTER mock.module registration (dynamic import defeats ESM hoisting).
const { default: createNeedsInputObserver, sessionWordPair } = await import(
  "../needs-input-observer.ts"
)

// DIA-189 fix (rename-if-not-suffixed, 2026-08-15): the stale DEFAULT_TITLE
// "opencode poetry-platform" assumed the old default TUI label, but the
// runtime probe (cod-4, 2026-08-15) verified opencode 1.18.18 actually
// defaults sessions to "New session - <ISO>" and ptys to "Terminal N" /
// "Terminal <id4>". The plugin's old guard (title === "" OR starts with
// "opencode ") never matched those, so the rename silently never ran (0 of
// 1,742 all-time sessions ever carried a suffix). These constants now carry
// the REAL runtime defaults so the regression tests pin the fix: the suffix
// must be appended to ANY unsuffixed title, default OR user-set.
const DEFAULT_TITLE = "New session - 2026-08-15T10:30:00.000Z"
// DIA-189 fix: the real 1.18.18 pty default is "Terminal 1" (probe-verified),
// not "opencode <cwd>".
const DEFAULT_PTY_TITLE = "Terminal 1"
const SESSION_ID = "ses_1234567890abcdef"
const PTY_ID = "pty_abcdef123456"
// DIA-189 word-pair naming: deterministic adjective-noun pairs from session IDs.
// Verified by running sessionWordPair() in node: "ses_1234567890abcdef" -> "jovial-elm",
// "pty_abcdef123456" -> "droll-ridge", "pty_custom000001" -> "urbane-moon".
// Hardcoded values must be updated if word lists change; format assertion ensures contract.
const SESSION_WORD_PAIR = "jovial-elm"
const PTY_WORD_PAIR = "droll-ridge"
// Format contract: word pairs are lowercase-hyphenated ASCII.
if (!/^[a-z]+-[a-z]+$/.test(SESSION_WORD_PAIR)) throw new Error("SESSION_WORD_PAIR format violated")
if (!/^[a-z]+-[a-z]+$/.test(PTY_WORD_PAIR)) throw new Error("PTY_WORD_PAIR format violated")

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia189-"))
  const updateCalls = []
  const toastCalls = []
  const ptyUpdateCalls = []
  const ctx = {
    directory,
    client: {
      session: {
        get: async () => ({
          data: { title: DEFAULT_TITLE },
          error: undefined,
        }),
        update: async (arg) => {
          updateCalls.push(arg)
          return {}
        },
        // DIA-189b P2c: boot retro pass reads existing sessions.
        list: async () => [],
      },
      // DIA-189b: the visible terminal strip is the PTY strip (Pty.title),
      // not Session.title - the follow-up fix renames PTYs and retro-passes
      // over pty.list() at boot.
      pty: {
        list: async () => [],
        update: async (arg) => {
          ptyUpdateCalls.push(arg)
          return {}
        },
      },
      tui: {
        showToast: async (arg) => {
          toastCalls.push(arg)
          return {}
        },
      },
      app: { log: async () => {} },
      postSessionIdPermissionsPermissionId: async () => ({}),
    },
  }
  return { ctx, updateCalls, toastCalls, ptyUpdateCalls }
}

async function makeHarness() {
  const { ctx, updateCalls, toastCalls, ptyUpdateCalls } = freshCtx()
  const hooks = await createNeedsInputObserver(ctx)
  return { hooks, ctx, updateCalls, toastCalls, ptyUpdateCalls }
}

// DIA-189b boot retro pass is async (awaits ctx.client.pty.list() and
// session.list()). The plugin fires it after seedFromDisk() at startup, so
// the harness must let the microtask/event-loop settle before asserting.
// Two macrotask turns (setTimeout 0) are more than enough for a promise
// chain of awaits on mocked async fns (each await is a microtask hop).
async function settleBootPass() {
  await new Promise((r) => setTimeout(r, 0))
  await new Promise((r) => setTimeout(r, 0))
}

function sessionCreatedEvent(title, id = SESSION_ID) {
  return {
    event: {
      type: "session.created",
      properties: { info: { id, title } },
    },
  }
}

// DIA-189b: Pty-shaped event info per recon (types.gen.d.ts:562-570).
function ptyCreatedEvent(title, id = PTY_ID) {
  return {
    event: {
      type: "pty.created",
      properties: {
        info: {
          id,
          title,
          command: "opencode",
          args: [],
          cwd: "/workspace",
          status: "running",
          pid: 1234,
        },
      },
    },
  }
}

// DIA-189b F5: same info shape, "pty.updated" event type - the plugin must
// apply the identical rename rule on title updates, not just creation.
function ptyUpdatedEvent(title, id = PTY_ID) {
  return {
    event: {
      type: "pty.updated",
      properties: {
        info: {
          id,
          title,
          command: "opencode",
          args: [],
          cwd: "/workspace",
          status: "running",
          pid: 1234,
        },
      },
    },
  }
}

// DIA-189b: Pty-shaped record as pty.list() returns (same shape).
function ptyRecord(title, id = PTY_ID) {
  return {
    id,
    title,
    command: "opencode",
    args: [],
    cwd: "/workspace",
    status: "running",
    pid: 1234,
  }
}

// DIA-189b: Session-shaped record as session.list() returns (cod-7 recon).
function sessionRecord(title, id = SESSION_ID) {
  return {
    id,
    title,
    projectID: "p",
    directory: "/workspace",
    version: "1",
    time: {
      created: "2026-08-15T00:00:00Z",
      updated: "2026-08-15T00:00:00Z",
    },
  }
}

function questionAskedEvent(
  question,
  sessionID = SESSION_ID,
  extraProps = {}
) {
  return {
    event: {
      type: "question.asked",
      properties: { sessionID, questions: [{ question }], ...extraProps },
    },
  }
}

function desktopScript() {
  // args[0] = -NoProfile, args[1] = -Command, args[2] = script
  const call = spawnCalls.find((c) => c.cmd === "powershell.exe")
  if (!call) throw new Error("no powershell.exe spawn captured")
  return call.args[2]
}

// ---------------------------------------------------------------------------
// A1: session.created rename to a unique title
// ---------------------------------------------------------------------------

test("A1a RED: runtime session default 'New session - <ISO>' on session.created triggers session.update with derived unique title", async () => {
  const { hooks, updateCalls, ctx } = await makeHarness()
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  // DIA-260830-3q7e: DEFAULT_SESSION_RE strips "New session - <ISO>" -> base is opencode <cwd>, word-pair FIRST.
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].path).toEqual({ id: SESSION_ID })
  expect(updateCalls[0].body.title).toBe(`[${SESSION_WORD_PAIR}] opencode ${basename(ctx.directory)}`)
})

test("A1b RED: user-set title 'My Custom Session' gets the suffix appended (rename-if-not-suffixed)", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent("My Custom Session"))
  // DIA-260830-3q7e: word-pair FIRST.
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].path).toEqual({ id: SESSION_ID })
  expect(updateCalls[0].body.title).toBe(`[${SESSION_WORD_PAIR}] My Custom Session`)
})

test("A1c RED: missing/empty title on session.created triggers session.update with default-label base + word-pair", async () => {
  const { hooks, updateCalls, ctx } = await makeHarness()
  await hooks.event(sessionCreatedEvent(""))
  // DIA-260830-3q7e: word-pair FIRST -> "[pair] opencode <cwd>"
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].body.title).toBe(`[${SESSION_WORD_PAIR}] opencode ${basename(ctx.directory)}`)
})

test("A1d guard: title already ending in [word-pair] is NOT renamed again (no double-rename)", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(
    sessionCreatedEvent(`[${SESSION_WORD_PAIR}] ${DEFAULT_TITLE}`, SESSION_ID)
  )
  // DIA-260830-3q7e: guard now checks prefix ^\[pair\] not suffix.
  expect(updateCalls).toHaveLength(0)
})

test("A1e guard: session.update failure warns and continues, never crashes the hook", async () => {
  const { ctx } = freshCtx()
  ctx.client.session.update = async () => {
    throw new Error("update boom")
  }
  const hooks = await createNeedsInputObserver(ctx)
  // Fail-soft A1 behavior: the event hook must resolve, not reject.
  await expect(hooks.event(sessionCreatedEvent(DEFAULT_TITLE))).resolves.toBeUndefined()
})

test("A1f guard: session.update { error } response branch warns and continues, never crashes the hook", async () => {
  // F4 coverage: the non-throwing error branch. The SDK returns
  // { error: { message } } instead of throwing - the plugin must warn via
  // console.warn (stderr) and the hook must still resolve.
  const { ctx } = freshCtx()
  ctx.client.session.update = async () => ({ error: { message: "boom" } })
  const hooks = await createNeedsInputObserver(ctx)
  const warnings = []
  const origWarn = console.warn
  console.warn = (...args) => warnings.push(args.join(" "))
  try {
    // Fail-soft A1: the event hook must resolve, not reject.
    await expect(
      hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
    ).resolves.toBeUndefined()
  } finally {
    console.warn = origWarn
  }
  // The { error } branch must produce a console.warn mentioning the rename.
  expect(warnings.some((w) => w.includes("session.update rename"))).toBe(true)
})

// ---------------------------------------------------------------------------
// A2: notification attribution - short-id suffix in both channels
// ---------------------------------------------------------------------------

test("A2 RED: notify() title carries the word-pair suffix in the TUI toast title", async () => {
  const { hooks, toastCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
  // DIA-189: body.title must contain " [crimson-elm]" so the toast matches
  // the renamed terminal label. RED today: title is just the default label,
  // no suffix.
  expect(toastCalls[0].body.title).toContain(`[${SESSION_WORD_PAIR}]`)
})

test("A2 RED: notify() title carries the word-pair suffix in the desktop toast title", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  // DIA-260830-3q7e: word-pair FIRST.
  expect(desktopScript()).toContain(`[${SESSION_WORD_PAIR}] ${DEFAULT_TITLE}`)
})

test("A2 guard: title already ending in the word-pair suffix is NOT double-appended", async () => {
  // DIA-260830-3q7e: word-pair FIRST, guard is prefix.
  const { hooks, toastCalls } = await makeHarness()
  await hooks.event(
    sessionCreatedEvent(`[${SESSION_WORD_PAIR}] ${DEFAULT_TITLE}`, SESSION_ID)
  )
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
  // Exact match proves exactly-once (a double-append would fail this).
  expect(toastCalls[0].body.title).toBe(`[${SESSION_WORD_PAIR}] ${DEFAULT_TITLE}`)
})

// ---------------------------------------------------------------------------
// A3: desktop-toast sanitizer must preserve printable Unicode
// ---------------------------------------------------------------------------

test("A3 RED: Cyrillic detail survives the desktop toast sanitizer", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  // Ukrainian detail - must NOT be replaced by spaces after A3.
  await hooks.event(questionAskedEvent("Потрібна допомога", SESSION_ID))
  const script = desktopScript()
  expect(script).toContain("Потрібна допомога")
})

test("A3b guard: control chars (CR/LF/TAB) still collapse to spaces in the toast script", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(questionAskedEvent("line1\n\tline2", SESSION_ID))
  const script = desktopScript()
  expect(script).not.toContain("\n")
  expect(script).not.toContain("\t")
  expect(script).toContain("line1 line2")
})

test("A3c guard: single quotes are still doubled for PowerShell in the toast script", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(questionAskedEvent("it's a test", SESSION_ID))
  expect(desktopScript()).toContain("it''s a test")
})

test("A3d guard: toast body text node is still truncated to 180 chars", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(questionAskedEvent("x".repeat(300), SESSION_ID))
  const script = desktopScript()
  // Body lives in the second CreateTextNode('...') of the script.
  const bodyTextNodes = [...script.matchAll(/CreateTextNode\('([^']*)'\)/g)]
  expect(bodyTextNodes).toHaveLength(2)
  const body = bodyTextNodes[1][1]
  expect(body.length).toBeLessThanOrEqual(180)
})

test("A3e guard: C1 control chars (U+0080-U+009F) are still stripped to spaces in the toast script", async () => {
  // F4 coverage: the A3 design strips control chars across BOTH C0
  // (U+0000-U+001F, covered by A3b) and C1 (U+007F-U+009F). Feed a detail
  // containing a C1 control (U+0085 NEL and U+009F APC are the classic
  // examples) through the desktop-toast path - the captured PowerShell
  // script arg must have each replaced by a space, never preserved.
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(
    questionAskedEvent(`alpha\u0085beta\u009Fgamma`, SESSION_ID)
  )
  const script = desktopScript()
  expect(script).not.toContain("\u0085")
  expect(script).not.toContain("\u009F")
  expect(script).toContain("alpha beta gamma")
})

// ---------------------------------------------------------------------------
// DIA-189b P1: pty.created rename (the visible terminal strip is Pty.title)
// ---------------------------------------------------------------------------

test("P1a RED: pty.created with runtime pty default 'Terminal 1' triggers pty.update with derived unique title", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyCreatedEvent(DEFAULT_PTY_TITLE))
  // DIA-260830-3q7e: word-pair FIRST.
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`)
})

test("P1b RED: pty.created with a user-set title gets the suffix appended (rename-if-not-suffixed)", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyCreatedEvent("My custom pty"))
  // DIA-260830-3q7e: word-pair FIRST.
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] My custom pty`)
})

test("P1c guard: pty.created with already-suffixed title is NOT renamed again", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(
    ptyCreatedEvent(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`, PTY_ID)
  )
  // DIA-260830-3q7e: guard now prefix.
  expect(ptyUpdateCalls).toHaveLength(0)
})

test("P1d guard: pty.update throw warns and continues, never crashes the hook", async () => {
  // Mirrors the A1e session.update fail-soft pattern: a cosmetic rename
  // failure must never crash the plugin - warn on stderr and resolve.
  const { ctx } = freshCtx()
  ctx.client.pty.update = async () => {
    throw new Error("pty update boom")
  }
  const hooks = await createNeedsInputObserver(ctx)
  const warnings = []
  const origWarn = console.warn
  console.warn = (...args) => warnings.push(args.join(" "))
  try {
    await expect(
      hooks.event(ptyCreatedEvent(DEFAULT_PTY_TITLE))
    ).resolves.toBeUndefined()
  } finally {
    console.warn = origWarn
  }
  // Fail-soft A1b: the warn must mention the pty rename path.
  expect(warnings.some((w) => w.includes("pty"))).toBe(true)
})

// ---------------------------------------------------------------------------
// DIA-189b P2: boot retro pass - rename pre-existing pty/session titles
// ---------------------------------------------------------------------------

test("P2a RED: boot retro pass renames pre-existing default-titled ptys from pty.list", async () => {
  const { ctx, ptyUpdateCalls } = freshCtx()
  ctx.client.pty.list = async () => [ptyRecord(DEFAULT_PTY_TITLE)]
  // Plugin instance creation IS the test subject here: the constructor fires
  // bootRetroPass, so the call must stay even though `hooks` is not needed.
  await createNeedsInputObserver(ctx)
  // Boot retro pass runs after seedFromDisk() at startup, asynchronously.
  await settleBootPass()
  // A2b: the pty existed before the plugin loaded - the retro pass must
  // apply the same rename rule. "Terminal 1" is the real 1.18.18 pty default:
  // RED against the old prefix guard (no "opencode " prefix, no rename).
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`)
})

test("P2b RED: boot retro pass renames an unsuffixed custom pty but skips an already-suffixed one", async () => {
  const { ctx, ptyUpdateCalls } = freshCtx()
  ctx.client.pty.list = async () => [
    ptyRecord("My custom pty", "pty_custom000001"),
    ptyRecord(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`, PTY_ID),
  ]
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  // DIA-260830-3q7e: word-pair FIRST.
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: "pty_custom000001" })
  expect(ptyUpdateCalls[0].body.title).toBe("[urbane-moon] My custom pty")
})

test("P2c RED: boot retro pass renames pre-existing default-title sessions from session.list", async () => {
  const { ctx, updateCalls } = freshCtx()
  ctx.client.session.list = async () => [sessionRecord(DEFAULT_TITLE)]
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  // DIA-260830-3q7e: DEFAULT_SESSION_RE strips New session -> opencode <cwd>, word-pair FIRST.
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].path).toEqual({ id: SESSION_ID })
  expect(updateCalls[0].body.title).toBe(`[${SESSION_WORD_PAIR}] opencode ${basename(ctx.directory)}`)
})

test("P2d guard: boot retro pass is fail-soft - pty.list throw must not crash plugin startup", async () => {
  const { ctx, toastCalls } = freshCtx()
  ctx.client.pty.list = async () => {
    throw new Error("pty list boom")
  }
  const hooks = await createNeedsInputObserver(ctx)
  await settleBootPass()
  // Fail-soft A2b: a list failure must not prevent instantiation NOR break
  // subsequent event handling - a question.asked must still produce a toast.
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
})

// ---------------------------------------------------------------------------
// DIA-189 F5: pty.updated rename (regression lock against eba07c8)
// ---------------------------------------------------------------------------

test("F5 lock: pty.updated with runtime pty default triggers pty.update with derived unique title", async () => {
  // DIA-260830-3q7e: word-pair FIRST.
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyUpdatedEvent(DEFAULT_PTY_TITLE))
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`)
})

// ---------------------------------------------------------------------------
// DIA-189 F6: envelope-shape tolerance (SDK { data, error } vs raw arrays)
// ---------------------------------------------------------------------------

test("F6a lock: boot retro pass tolerates the SDK { data, error } envelope from pty.list", async () => {
  // F6a (ai-auditor): the real SDK wraps list() results in { data, error },
  // while the harness mocks return raw arrays - the boot pass must accept
  // BOTH shapes. PASSES against eba07c8 (res?.data ?? [] fallback).
  const { ctx, ptyUpdateCalls } = freshCtx()
  ctx.client.pty.list = async () => ({
    data: [ptyRecord(DEFAULT_PTY_TITLE)],
    error: undefined,
  })
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] ${DEFAULT_PTY_TITLE}`)
})

test("F6b RED: boot retro pass must warn on the non-throw { error } envelope from pty.list (F2 gap)", async () => {
  // F6b (ai-auditor F2 gap): a list() that resolves to { error, data:
  // undefined } instead of throwing is silently swallowed today - res.error
  // is never inspected, so NO warn is emitted and the failure is invisible.
  // This is the F2 proof: RED against eba07c8, must flip green when the
  // implementer inspects res.error.
  const { ctx, toastCalls } = freshCtx()
  ctx.client.pty.list = async () => ({
    error: { message: "boom" },
    data: undefined,
  })
  const warnings = []
  const origWarn = console.warn
  console.warn = (...args) => warnings.push(args.join(" "))
  let hooks
  try {
    hooks = await createNeedsInputObserver(ctx)
    await settleBootPass()
  } finally {
    console.warn = origWarn
  }
  // F2: a warn mentioning the pty list surface must be emitted. RED today:
  // the envelope error is dropped silently -> no warn -> this assertion
  // fails, proving the gap.
  expect(warnings.some((w) => w.includes("pty") && w.includes("list"))).toBe(true)
  // And the plugin must still be alive for subsequent events.
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
})

test("F6c guard: pty.update non-throw { error } envelope warns and never crashes", async () => {
  // F6c (ai-auditor): the rename call may resolve with { error } instead of
  // throwing. The A1b renameDefaultTitle path checks res.error and warns -
  // report actual behavior against eba07c8 honestly (the dispatch expected
  // possible RED here, but renameDefaultTitle already inspects res.error).
  const { ctx } = freshCtx()
  ctx.client.pty.update = async () => ({ error: { message: "boom" } })
  const hooks = await createNeedsInputObserver(ctx)
  const warnings = []
  const origWarn = console.warn
  console.warn = (...args) => warnings.push(args.join(" "))
  try {
    await expect(
      hooks.event(ptyCreatedEvent(DEFAULT_PTY_TITLE))
    ).resolves.toBeUndefined()
  } finally {
    console.warn = origWarn
  }
  // Fail-soft: the warn must mention the pty rename path.
  expect(warnings.some((w) => w.includes("pty"))).toBe(true)
})

// ---------------------------------------------------------------------------
// DIA-189 fix: rename-if-not-suffixed against the real 1.18.18 runtime
// defaults (cod-4 probe, 2026-08-15). The old guard renamed only titles that
// were empty or started with "opencode ", but the runtime defaults sessions
// to "New session - <ISO>" and ptys to "Terminal N" / "Terminal <id4>" - so
// the rename never fired (0 of 1,742 sessions ever suffixed). The approved
// rule appends the suffix to ANY unsuffixed title.
// ---------------------------------------------------------------------------

test("G1 RED: pty title 'Terminal <id4>' (second real runtime default shape) gets suffixed", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  // DIA-260830-3q7e: word-pair FIRST.
  await hooks.event(ptyCreatedEvent("Terminal 3456"))
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`[${PTY_WORD_PAIR}] Terminal 3456`)
})

test("G2 guard: any title already ending in ' [adjective-noun]' is NOT re-renamed", async () => {
  const { hooks, updateCalls } = await makeHarness()
  // DIA-260830-3q7e: guard now prefix ^\[pair\]
  await hooks.event(sessionCreatedEvent("[bold-fox] My Custom Session"))
  expect(updateCalls).toHaveLength(0)
})

// ---------------------------------------------------------------------------
// sessionWordPair determinism and format
// ---------------------------------------------------------------------------

test("sessionWordPair: same input always produces the same output (determinism)", async () => {
  const id = "ses_1234567890abcdef"
  const first = sessionWordPair(id)
  const second = sessionWordPair(id)
  expect(first).toBe(second)
})

test("sessionWordPair: output matches adjective-noun format (lowercase, hyphenated, ASCII-only)", async () => {
  const result = sessionWordPair("ses_1234567890abcdef")
  expect(result).toMatch(/^[a-z]+-[a-z]+$/)
})

test("sessionWordPair: different inputs produce different outputs (collision check)", async () => {
  const a = sessionWordPair("ses_aaaaaaaaaaaaaaaa")
  const b = sessionWordPair("ses_bbbbbbbbbbbbbbbb")
  // Not a strict guarantee (hash collisions possible), but with 100x100 = 10000
  // word-pair space the probability of collision for 2 inputs is ~1/10000.
  expect(a).not.toBe(b)
})
