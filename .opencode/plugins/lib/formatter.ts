/**
 * formatter seam — SRP extraction (Slice 6, DIA-260902-eqgg).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts
 * Move VERBATIM — no behavior change. Constants, isFormatterIgnoredPath,
 * extractPatchPaths, and runEditTimeFormatter logic are copied verbatim
 * from the monolith's DIA-105 formatter section.
 *
 * DI contract: lib is pure/DI'd — spawnSync and FS probes are injected.
 * Caller (shell) and tests inject fakes; lib never imports child_process.
 */

import { existsSync as realExistsSync, statSync as realStatSync } from "node:fs"
import { extname, isAbsolute, relative, resolve } from "node:path"

// ── D2 constants — verbatim values ──────────────────────────────────────────

export const FORMATTER_MAX_BYTES = 1024 * 1024 // 1 MiB — bigger = generated/binary
export const FORMATTER_TIMEOUT_MS = 30_000 // prettier on one file is <1s; 30s is generous
export const FORMATTER_EXTENSIONS = new Set([
  ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue",
  ".css", ".scss", ".html", ".md", ".json", ".jsonc", ".yaml", ".yml",
])
export const FORMATTER_IGNORE_PREFIXES = [
  ".opencode/session/",
  "knowledge/",
  "docs/dev-infra-audit/tickets/",
  "openspec/changes/archive/",
]

// ── helpers ─────────────────────────────────────────────────────────────────

function errMsg(err: unknown): string {
  if (typeof err === "string") return err
  if (err !== null && typeof err === "object" && "message" in err && typeof (err as { message: unknown }).message === "string") {
    return (err as { message: string }).message
  }
  const data = (err as { data?: unknown }).data
  if (data !== null && typeof data === "object" && data !== null && "message" in data && typeof (data as { message: unknown }).message === "string") {
    return (data as { message: string }).message
  }
  try {
    return String(err)
  } catch {
    return "[unserializable error]"
  }
}

// ── isFormatterIgnoredPath — verbatim ───────────────────────────────────────

/**
 * True when `filePath` (absolute or relative) is under a no-format prefix.
 * Resolves against `workspaceRoot` (caller passes workspace directory).
 * Verbatim from delegation-observer.ts.
 */
export function isFormatterIgnoredPath(
  filePath: string,
  workspaceRoot: string
): boolean {
  const absolute = isAbsolute(filePath)
    ? filePath
    : resolve(workspaceRoot, filePath)
  const rel = relative(workspaceRoot, absolute)
  return FORMATTER_IGNORE_PREFIXES.some(
    (prefix) => rel === prefix.slice(0, -1) || rel.startsWith(prefix)
  )
}

// ── extractPatchPaths — verbatim ────────────────────────────────────────────

/**
 * Extract EVERY touched path from an apply_patch payload.
 * Verbatim from delegation-observer.ts (7 markers, deduped via !includes).
 */
export function extractPatchPaths(patchText: string): string[] {
  const paths: string[] = []
  for (const line of patchText.split(/\r?\n/)) {
    const indexMatch = /^Index:\s*(\S+)/i.exec(line)
    const diffMatch = /^diff\s+--git\s+a\/\S+\s+b\/(\S+)/.exec(line)
    const plusPlusMatch = /^\+\+\+\s+b\/(\S+)/.exec(line)
    const addFileMatch = /^\*\*\*\s+Add File:\s*(.+)/.exec(line)
    const updateFileMatch = /^\*\*\*\s+Update File:\s*(.+)/.exec(line)
    const deleteFileMatch = /^\*\*\*\s+Delete File:\s*(.+)/.exec(line)
    const moveToMatch = /^\*\*\*\s+Move to:\s*(.+)/.exec(line)
    const matchedPath =
      indexMatch?.[1] ??
      diffMatch?.[1] ??
      plusPlusMatch?.[1] ??
      addFileMatch?.[1]?.trim() ??
      updateFileMatch?.[1]?.trim() ??
      deleteFileMatch?.[1]?.trim() ??
      moveToMatch?.[1]?.trim()
    if (matchedPath && !paths.includes(matchedPath)) paths.push(matchedPath)
  }
  return paths
}

// ── runEditTimeFormatter — verbatim logic, DI'd ─────────────────────────────

export interface FormatterDeps {
  spawnSync: (cmd: string, args: string[], opts: unknown) => { status: number | null; signal?: string | null; error?: Error; stderr?: string; stdout?: string }
  existsSync?: (p: string) => boolean
  statSync?: (p: string) => { size: number }
  workspaceRoot: string
  cwd?: string
}

export interface FormatterInput {
  tool: string
  sessionID: string
  args?: unknown
}

export interface FormatterResult {
  formatted: string[]
  skipped: string[]
  warnNote?: string
  results: Array<{ file: string; ok: boolean; warnNote?: string }>
}

/**
 * DI'd edit-time formatter. Mirrors delegation-observer.ts runEditTimeFormatter
 * steps 1-6 verbatim, but instead of writing registry rows it returns a
 * structured result. Never throws — fail-soft contract: spawn throw / non-zero
 * exit / result.error all produce warnNote per file and collective warnNote.
 */
export function runEditTimeFormatter(
  input: FormatterInput,
  deps: FormatterDeps
): FormatterResult {
  const formatted: string[] = []
  const skipped: string[] = []
  const results: Array<{ file: string; ok: boolean; warnNote?: string }> = []
  const warnNotes: string[] = []

  // Never throw — outer guard for any unexpected error
  try {
    const workspaceRoot = deps.cwd ?? deps.workspaceRoot
    if (!workspaceRoot) {
      return { formatted, skipped, results }
    }

    const existsSyncFn = deps.existsSync ?? realExistsSync
    const statSyncFn = deps.statSync ?? realStatSync
    const spawnSyncFn = deps.spawnSync

    const args = (input.args ?? {}) as Record<string, unknown>

    // Step 1 — resolve touched paths
    let touchedPaths: string[] = []
    if (input.tool === "edit" || input.tool === "write") {
      if (typeof args.filePath === "string" && args.filePath) {
        touchedPaths = [args.filePath]
      }
    } else if (input.tool === "apply_patch") {
      touchedPaths = extractPatchPaths(
        typeof args.patchText === "string" ? args.patchText : ""
      )
    }
    if (touchedPaths.length === 0) return { formatted, skipped, results }

    for (const rawPath of touchedPaths) {
      const absPath = isAbsolute(rawPath)
        ? rawPath
        : resolve(workspaceRoot, rawPath)
      const relPath = relative(workspaceRoot, absPath)

      // Step 2 — ignore set (silent)
      if (isFormatterIgnoredPath(absPath, workspaceRoot)) {
        skipped.push(relPath)
        continue
      }

      // Step 3 — extension allow-list (silent)
      if (!FORMATTER_EXTENSIONS.has(extname(absPath).toLowerCase())) {
        skipped.push(relPath)
        continue
      }

      // Step 4 — perf guard: missing or too large
      try {
        if (!existsSyncFn(absPath)) {
          skipped.push(relPath)
          continue
        }
        if (statSyncFn(absPath).size > FORMATTER_MAX_BYTES) {
          skipped.push(relPath)
          continue
        }
      } catch {
        skipped.push(relPath)
        continue
      }

      // Step 5-6 — deterministic formatter invocation
      let result: { status: number | null; signal?: string | null; error?: Error; stderr?: string; stdout?: string }
      try {
        result = spawnSyncFn(
          "npx",
          ["--no-install", "prettier", "--write", absPath],
          {
            cwd: workspaceRoot,
            encoding: "utf-8",
            timeout: FORMATTER_TIMEOUT_MS,
          }
        )
      } catch (err) {
        const note = `prettier spawn failed: ${errMsg(err)}`
        warnNotes.push(note)
        results.push({ file: relPath, ok: false, warnNote: note })
        continue
      }

      if ((result as { error?: unknown }).error || result.status !== 0) {
        const why = (result as { error?: unknown }).error
          ? (errMsg((result as { error: unknown }).error) ?? "spawn error")
          : `prettier exit ${result.status}${result.signal ? ` (${result.signal})` : ""}`
        warnNotes.push(why)
        results.push({ file: relPath, ok: false, warnNote: why })
        continue
      }

      formatted.push(relPath)
      results.push({ file: relPath, ok: true })
    }
  } catch (err) {
    // Absolute never-throw guarantee — surface as collective warnNote
    const note = errMsg(err) ?? "formatter unexpected error"
    warnNotes.push(note)
  }

  const out: FormatterResult = { formatted, skipped, results }
  if (warnNotes.length > 0) out.warnNote = warnNotes.join("; ")
  return out
}

// ── DI factory ──────────────────────────────────────────────────────────────

/**
 * Factory DI seam — captures deps so callers can use single-arg runEditTimeFormatter.
 * Exposes constants and pure helpers alongside the bound formatter.
 */
export function createFormatter(deps: FormatterDeps) {
  const workspaceRoot = deps.cwd ?? deps.workspaceRoot
  return {
    FORMATTER_MAX_BYTES,
    FORMATTER_TIMEOUT_MS,
    FORMATTER_EXTENSIONS,
    FORMATTER_IGNORE_PREFIXES,
    isFormatterIgnoredPath: (filePath: string, wsRoot?: string) =>
      isFormatterIgnoredPath(filePath, wsRoot ?? workspaceRoot),
    extractPatchPaths,
    runEditTimeFormatter: (input: FormatterInput) =>
      runEditTimeFormatter(input, deps),
  }
}

// Default export for factory probe flexibility
