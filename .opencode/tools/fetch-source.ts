/**
 * fetch-source - typed fetch tool for the researcher lane (DIA-260827-ft3z,
 * design.md D1-D4, tasks 1.4 / 2.2 / 2.3).
 *
 * WHY this exists: a text allow-list over a shell cannot be made complete
 * (every hole found was a tool with an execution or write mode), so the
 * lane's fetch becomes a typed tool with no caller-selected command string.
 * This commit only ADDS the typed path; `researcher.bash` is removed by the
 * config-migration lane later in the same change, so the lane never goes
 * unusable mid-sequence.
 *
 * Registration: filename stem = tool name (`fetch-source`), same canonical
 * custom-tool shape as get-my-session-id.ts (tool() from @opencode-ai/plugin).
 *
 * Access control (D2), two layers, because custom tools are NOT permission-
 * gated at runtime:
 *   - schema visibility: the global flat "fetch-source": "deny" hides the
 *     tool from every lane's schema; researcher's trailing "allow" wins
 *     (agent rules append after global rules, findLast decides);
 *   - execution: the `context.agent === "researcher"` guard below is the real
 *     runtime control - visibility is only a schema-level gate.
 *
 * Validation order (D3): agent guard, URL, destination - ALL before any
 * network call. A rejected destination is a hard error (throw), never a
 * retry against another path. Publication is atomic: fetch into a temp
 * sibling in the destination directory, rename into place only on success,
 * so a failed fetch leaves no partial artifact for downstream synthesis.
 *
 * Tier chain (D4), argv arrays only - never a shell string:
 *   1. npm registry JSON API for registry.npmjs.org (the response body IS
 *      the archive);
 *   2. trafilatura;
 *   3. curl with the browser user-agent documented in the Phase A capture
 *      chain;
 *   4. crwl, LAST RESORT. Tier 4 is optional: a missing crwl is reported as
 *      an unavailable tier with a failed status - never a throw - so the
 *      surrounding research is not errored out.
 */
import { tool } from "@opencode-ai/plugin"
import { spawnSync } from "node:child_process"
import { randomBytes } from "node:crypto"
import {
  closeSync,
  openSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs"
import { basename, dirname, join } from "node:path"
import { checkFetchUrl, resolveOutputPath } from "../plugins/lib/destination-policy.ts"

/** Browser UA verbatim from the Phase A capture chain (researcher.md tier b). */
const BROWSER_UA =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

// ponytail: single-process 60s cap per tier; killing crwl on timeout can
// orphan a Chromium child - upgrade to a process-group kill if orphans bite.
const TIER_TIMEOUT_MS = 60_000

type TierOutcome = { ok: true; bytes: number } | { ok: false; reason: string }

// `reason` exists only on the failed variant so a non-throwing failure can
// still report which tier stopped the chain (e.g. "tier-4: unavailable").
type FetchSourceResult =
  | { status: "ok"; tier: number; bytes: number; resolved_path: string }
  | { status: "failed"; tier: number; bytes: 0; resolved_path: string; reason: string }

/**
 * Run one spawned tier with stdout redirected straight into the temp
 * sibling: no shell, no maxBuffer ceiling (spawnSync caps piped stdout, a
 * file descriptor does not). ENOENT is surfaced as `unavailable (<cmd> not
 * found)` so a missing optional binary reads differently from a failed
 * fetch - that is how tier 4 degrades.
 */
function runSpawnTier(command: string, args: string[], tempPath: string): TierOutcome {
  let fd: number | undefined
  try {
    fd = openSync(tempPath, "w")
    const res = spawnSync(command, args, {
      stdio: ["ignore", fd, "pipe"],
      timeout: TIER_TIMEOUT_MS,
      encoding: "utf8",
    })
    if (res.error) {
      const code = (res.error as { code?: string }).code
      if (code === "ENOENT") return { ok: false, reason: `unavailable (${command} not found)` }
      return { ok: false, reason: `spawn-failed (${code ?? res.error.message})` }
    }
    if (res.status !== 0) {
      return { ok: false, reason: res.signal ? `killed (${res.signal})` : `exit-${res.status}` }
    }
    const bytes = statSync(tempPath).size
    if (bytes === 0) return { ok: false, reason: "empty-output" }
    return { ok: true, bytes }
  } catch (err) {
    return { ok: false, reason: `io-failed (${err instanceof Error ? err.message : String(err)})` }
  } finally {
    if (fd !== undefined) {
      try {
        closeSync(fd)
      } catch {
        // already closed - nothing to do
      }
    }
  }
}

/** Tier 1: npm registry JSON API - the response body IS the archive. */
async function runRegistryTier(
  url: string,
  tempPath: string,
  abort: AbortSignal
): Promise<TierOutcome> {
  try {
    const res = await fetch(url, { signal: abort })
    if (!res.ok) return { ok: false, reason: `http-${res.status}` }
    const body = Buffer.from(await res.arrayBuffer())
    if (body.length === 0) return { ok: false, reason: "empty-output" }
    writeFileSync(tempPath, body)
    return { ok: true, bytes: body.length }
  } catch (err) {
    return { ok: false, reason: `fetch-failed (${err instanceof Error ? err.message : String(err)})` }
  }
}

export default tool({
  description:
    "Fetch a URL into a knowledge-root file for the researcher lane. Validates the URL and the destination (knowledge/ or .opencode/oh-my-opencode-slim/knowledge/) BEFORE any network call, then tries the npm registry JSON API (registry.npmjs.org URLs only), trafilatura, curl with a browser user-agent, and crwl in that order; publishes atomically via temp sibling + rename so a failed fetch leaves no partial file. Returns JSON {status, tier, bytes, resolved_path[, reason]}. Researcher-only: any other caller is rejected.",
  args: {
    url: tool.schema.string().describe("http(s) URL to fetch"),
    output_path: tool.schema
      .string()
      .describe(
        "destination file path, resolved against the workspace root; must land under knowledge/ or .opencode/oh-my-opencode-slim/knowledge/"
      ),
  },
  async execute({ url, output_path }, context) {
    // Execution-level access control (D2) - see header.
    if (context.agent !== "researcher") {
      throw new Error(`fetch-source: agent-guard: caller "${context.agent}" is not researcher`)
    }
    // Both validators run BEFORE any network call (D3): a rejected
    // destination is a hard error, never a retry against another path.
    const urlCheck = checkFetchUrl(url)
    if (!urlCheck.ok) throw new Error(`fetch-source: url-rejected: ${urlCheck.reason}`)
    const dest = resolveOutputPath(context.directory, output_path)
    if (!dest.ok) {
      throw new Error(`fetch-source: destination-rejected: ${dest.reason} (${output_path})`)
    }
    const resolvedPath = dest.resolvedPath

    // Temp sibling in the destination directory (same filesystem, so the
    // final rename is atomic). Unlinked on failure: no partial artifact.
    const tempPath = join(
      dirname(resolvedPath),
      `.${basename(resolvedPath)}.fetch-source-${randomBytes(6).toString("hex")}.tmp`
    )

    // Tier chain (D4) in order. Tier 1 applies only to registry URLs; every
    // attempt overwrites the temp sibling, so a failed tier leaves nothing
    // behind for the next one to trip over.
    const attempts: Array<[number, () => TierOutcome | Promise<TierOutcome>]> = []
    if (new URL(url).hostname === "registry.npmjs.org") {
      attempts.push([1, () => runRegistryTier(url, tempPath, context.abort)])
    }
    attempts.push([
      2,
      () => runSpawnTier("trafilatura", ["-u", url, "--output-format", "markdown"], tempPath),
    ])
    // --fail: an HTTP error page must fail the tier, not get archived as if
    // it were the artifact.
    attempts.push([
      3,
      () => runSpawnTier("curl", ["-sL", "--fail", "-A", BROWSER_UA, url], tempPath),
    ])
    attempts.push([4, () => runSpawnTier("crwl", ["crawl", url, "-o", "markdown"], tempPath)])

    const failures: string[] = []
    let tier = 0
    let bytes = 0
    let published = false
    for (const [n, run] of attempts) {
      tier = n
      if (context.abort.aborted) {
        failures.push(`tier-${n}: aborted`)
        break
      }
      const outcome = await run()
      if (outcome.ok) {
        renameSync(tempPath, resolvedPath)
        bytes = outcome.bytes
        published = true
        break
      }
      failures.push(`tier-${n}: ${outcome.reason}`)
    }

    if (published) {
      return JSON.stringify({ status: "ok", tier, bytes, resolved_path: resolvedPath })
    }
    try {
      unlinkSync(tempPath)
    } catch {
      // temp was never created (every tier failed before opening it)
    }
    // A missing crwl lands here as `tier-4: unavailable (crwl not found)`:
    // failed status, never a throw (D4) - the surrounding research continues.
    const result: FetchSourceResult = {
      status: "failed",
      tier,
      bytes: 0,
      resolved_path: resolvedPath,
      reason: failures.join("; "),
    }
    return JSON.stringify(result)
  },
})
