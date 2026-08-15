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
 *   Verified result today (2026-08-15): 6 pass, 5 fail - the RED tests fail
 *   for the RIGHT reasons (A1a/A1c: no session.update call at all; A2: toast
 *   title lacks [abcdef]; A3: Cyrillic replaced by spaces in the script) and
 *   the guard regressions A1b/A1d/A3b/A3c/A3d PASS.
 *
 *   Post-implementation: 11/11 green (after 60a1671 SHORT_ID fix), then 3
 *   ai-auditor F4 coverage tests added (A1f error-branch fail-soft, A2
 *   no-double-append, A3e C1-range strip) -> 13/13 green.
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

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia189-"))
  const updateCalls = []
  const toastCalls = []
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
  return { ctx, updateCalls, toastCalls }
}

async function makeHarness() {
  const { ctx, updateCalls, toastCalls } = freshCtx()
  const hooks = await createNeedsInputObserver(ctx)
  return { hooks, ctx, updateCalls, toastCalls }
}

function sessionCreatedEvent(title, id = SESSION_ID) {
  return {
    event: {
      type: "session.created",
      properties: { info: { id, title } },
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
