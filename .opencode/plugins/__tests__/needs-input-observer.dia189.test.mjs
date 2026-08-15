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
 */
import { mock, test, expect } from "bun:test"
import { mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

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
}))

// Import AFTER mock.module registration (dynamic import defeats ESM hoisting).
const { default: createNeedsInputObserver } = await import(
  "../needs-input-observer.ts"
)

const DEFAULT_TITLE = "opencode poetry-platform"
const SESSION_ID = "ses_1234567890abcdef"
const SHORT_ID = "abcdef" // SESSION_ID.slice(-6) - verified on bun 1.3.14: "ses_1234567890abcdef".slice(-6) === "abcdef"
// DIA-189b: pty identity. NOTE the dispatch's "[3456]" was slice(-4) - the
// true slice(-6) of "pty_abcdef123456" is "123456" (bun-verified above).
const PTY_ID = "pty_abcdef123456"
const PTY_SHORT = "123456" // PTY_ID.slice(-6) - bun-verified

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

test("A1a RED: default title on session.created triggers session.update with derived unique title", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  // A1: derived = baseTitle + " [" + id.slice(-6) + "]"
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].path).toEqual({ id: SESSION_ID })
  expect(updateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${SHORT_ID}]`)
})

test("A1b guard: custom non-default title is NOT renamed (no session.update)", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent("My special session"))
  // Guard: only default-label / empty titles are renamed. PASSES today
  // (trivially - no update call exists at all); must still pass after A1.
  expect(updateCalls).toHaveLength(0)
})

test("A1c RED: missing/empty title on session.created triggers session.update with default-label base + short-id", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent(""))
  // A1: empty title -> baseTitle = the default label ("opencode <...>") so the
  // derived title starts with "opencode " and ends with the short-id suffix.
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].body.title.startsWith("opencode ")).toBe(true)
  expect(updateCalls[0].body.title.endsWith(` [${SHORT_ID}]`)).toBe(true)
})

test("A1d guard: title already ending in [xxxxxx] is NOT renamed again (no double-rename)", async () => {
  const { hooks, updateCalls } = await makeHarness()
  await hooks.event(
    sessionCreatedEvent(`${DEFAULT_TITLE} [${SHORT_ID}]`, SESSION_ID)
  )
  // Guard from the A1 design: skip if the short-id suffix is already present.
  // PASSES today (trivially); must still pass after A1.
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

test("A2 RED: notify() title carries the short-id suffix in the TUI toast title", async () => {
  const { hooks, toastCalls } = await makeHarness()
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
  // A2: body.title must contain " [abcdef]" so the toast matches the renamed
  // terminal label. RED today: title is just the default label, no suffix.
  expect(toastCalls[0].body.title).toContain(`[${SHORT_ID}]`)
})

test("A2 RED: notify() title carries the short-id suffix in the desktop toast title", async () => {
  const { hooks } = await makeHarness()
  spawnCalls.length = 0
  await hooks.event(sessionCreatedEvent(DEFAULT_TITLE))
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  // A2: the desktop toast title (first CreateTextNode text) must carry the
  // same suffixed title. Assert on the full expected title string so the
  // match is pinned to the title node, not the body node.
  expect(desktopScript()).toContain(`${DEFAULT_TITLE} [${SHORT_ID}]`)
})

test("A2 guard: title already ending in the short-id suffix is NOT double-appended", async () => {
  // F4 coverage: seed sessionMeta/entry with a title that ALREADY carries
  // the " [<short-id>]" suffix (e.g. the A1-renamed label), then trigger a
  // question.asked - notify() must keep the suffix exactly once, never
  // producing " [abcdef] [abcdef]".
  const { hooks, toastCalls } = await makeHarness()
  await hooks.event(
    sessionCreatedEvent(`${DEFAULT_TITLE} [${SHORT_ID}]`, SESSION_ID)
  )
  await hooks.event(
    questionAskedEvent("Need your input", SESSION_ID)
  )
  expect(toastCalls).toHaveLength(1)
  // Exact match proves exactly-once (a double-append would fail this).
  expect(toastCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${SHORT_ID}]`)
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

test("P1a RED: pty.created with default title triggers pty.update with derived unique title", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyCreatedEvent(DEFAULT_TITLE))
  // A1b: derived = baseTitle + " [" + id.slice(-6) + "]" - same rule as the
  // session rename, applied to the PTY object. RED today: no pty handling.
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${PTY_SHORT}]`)
})

test("P1b guard: pty.created with custom non-default title is NOT renamed", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyCreatedEvent("My custom pty"))
  // Guard: only default-label / empty pty titles are renamed. PASSES today
  // (trivially - no pty handling exists at all); must keep passing after A1b.
  expect(ptyUpdateCalls).toHaveLength(0)
})

test("P1c guard: pty.created with already-suffixed title is NOT renamed again", async () => {
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(
    ptyCreatedEvent(`${DEFAULT_TITLE} [${PTY_SHORT}]`, PTY_ID)
  )
  // Guard: skip when the title already ends with " [xxxxxx]" (no double
  // rename). PASSES today (trivially); must keep passing after A1b.
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
      hooks.event(ptyCreatedEvent(DEFAULT_TITLE))
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

test("P2a RED: boot retro pass renames pre-existing default-title ptys from pty.list", async () => {
  const { ctx, ptyUpdateCalls } = freshCtx()
  ctx.client.pty.list = async () => [ptyRecord(DEFAULT_TITLE)]
  // Plugin instance creation IS the test subject here: the constructor fires
  // bootRetroPass, so the call must stay even though `hooks` is not needed.
  await createNeedsInputObserver(ctx)
  // Boot retro pass runs after seedFromDisk() at startup, asynchronously.
  await settleBootPass()
  // A2b: the pty existed before the plugin loaded - the retro pass must
  // apply the same default-title rename. RED today: no boot pass at all.
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${PTY_SHORT}]`)
})

test("P2b guard: boot retro pass skips custom and already-suffixed ptys", async () => {
  const { ctx, ptyUpdateCalls } = freshCtx()
  ctx.client.pty.list = async () => [
    ptyRecord("My custom pty", "pty_custom000001"),
    ptyRecord(`${DEFAULT_TITLE} [${PTY_SHORT}]`, PTY_ID),
  ]
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  // Guard: neither a custom title nor an already-suffixed title may be
  // renamed. PASSES today (trivially); must keep passing after A2b.
  expect(ptyUpdateCalls).toHaveLength(0)
})

test("P2c RED: boot retro pass renames pre-existing default-title sessions from session.list", async () => {
  const { ctx, updateCalls } = freshCtx()
  ctx.client.session.list = async () => [sessionRecord(DEFAULT_TITLE)]
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  // A2b: the session retro pass uses session.update with the same
  // derived-title rule (baseTitle + " [id.slice(-6)]"). RED today: no boot
  // pass -> 0 calls -> FAIL.
  expect(updateCalls).toHaveLength(1)
  expect(updateCalls[0].path).toEqual({ id: SESSION_ID })
  expect(updateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${SHORT_ID}]`)
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

test("F5 lock: pty.updated with default title triggers pty.update with derived unique title", async () => {
  // F5 (ai-auditor): the A1b rename must fire on pty.updated too - the title
  // can change after creation and the terminal strip must stay unique. This
  // is a regression-lock test: PASSES against eba07c8 (the event switch
  // handles pty.updated via the shared renameDefaultTitle).
  const { hooks, ptyUpdateCalls } = await makeHarness()
  await hooks.event(ptyUpdatedEvent(DEFAULT_TITLE))
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${PTY_SHORT}]`)
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
    data: [ptyRecord(DEFAULT_TITLE)],
    error: undefined,
  })
  await createNeedsInputObserver(ctx)
  await settleBootPass()
  expect(ptyUpdateCalls).toHaveLength(1)
  expect(ptyUpdateCalls[0].path).toEqual({ id: PTY_ID })
  expect(ptyUpdateCalls[0].body.title).toBe(`${DEFAULT_TITLE} [${PTY_SHORT}]`)
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
      hooks.event(ptyCreatedEvent(DEFAULT_TITLE))
    ).resolves.toBeUndefined()
  } finally {
    console.warn = origWarn
  }
  // Fail-soft: the warn must mention the pty rename path.
  expect(warnings.some((w) => w.includes("pty"))).toBe(true)
})
