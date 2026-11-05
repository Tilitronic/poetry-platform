/**
 * destination-policy - pure output-path containment policy (DIA-260827-ft3z,
 * design.md D3).
 *
 * Single source of truth for where a fetched artifact may be written, shared
 * by the typed fetch-source tool (task 2.2) and by
 * scripts/__tests__/destination-policy.test.mjs (node:test imports this file
 * directly - Node >=23 strips erasable TS by default, so keep this module to
 * erasable syntax only: no enums, namespaces, or parameter properties; the
 * plugin tsconfig also enforces `erasableSyntaxOnly`).
 *
 * Ordering is the point (D3): resolve against the workspace root, create the
 * parent directory, canonicalize the parent, THEN judge containment. A
 * lexical prefix check before canonicalization is defeated by `..` and by
 * symlinks, which is exactly what this module must reject.
 *
 * Two roots only, matched with a path-separator boundary so a sibling named
 * `knowledge-evil/` never passes.
 */

import { mkdirSync, realpathSync } from "node:fs"
import { basename, dirname, join, resolve, sep } from "node:path"

// Allowed write roots, relative to the workspace root.
const OUTPUT_ROOTS = ["knowledge", join(".opencode", "oh-my-opencode-slim", "knowledge")]

export type ResolveOutputResult =
  | { ok: true; resolvedPath: string }
  | { ok: false; reason: string }

export type CheckFetchUrlResult = { ok: true } | { ok: false; reason: string }

/** URL schemes a fetch is allowed to speak (D3). */
const ALLOWED_URL_PROTOCOLS = new Set(["http:", "https:"])

/**
 * Resolve `outputPath` against `workspaceRoot` and accept it only if the
 * canonicalized target stays under one of the two knowledge roots.
 * Rejection reasons are stable, short, machine-readable tokens.
 */
export function resolveOutputPath(
  workspaceRoot: string,
  outputPath: string
): ResolveOutputResult {
  // Canonical workspace root first so later parent realpaths compare equal
  // even when the root itself sits behind a symlink (e.g. /tmp on macOS).
  let canonicalRoot: string
  try {
    canonicalRoot = realpathSync(workspaceRoot)
  } catch {
    return { ok: false, reason: "workspace-root-unresolvable" }
  }

  const target = resolve(canonicalRoot, outputPath)

  // D3 ordering: create the parent, canonicalize the parent, then judge.
  // Post-mkdir realpath closes the common symlink race (design Risks).
  try {
    mkdirSync(dirname(target), { recursive: true })
  } catch {
    return { ok: false, reason: "parent-create-failed" }
  }
  let canonicalParent: string
  try {
    canonicalParent = realpathSync(dirname(target))
  } catch {
    return { ok: false, reason: "parent-resolve-failed" }
  }
  const resolvedPath = join(canonicalParent, basename(target))

  for (const root of OUTPUT_ROOTS) {
    const rootPath = join(canonicalRoot, root)
    let canonicalChildRoot: string
    try {
      canonicalChildRoot = realpathSync(rootPath)
    } catch {
      // Root does not exist yet, so no target can live under it.
      continue
    }
    // Path-separator boundary: `knowledge/` must not match `knowledge-evil/`.
    if (resolvedPath.startsWith(canonicalChildRoot + sep)) {
      return { ok: true, resolvedPath }
    }
  }
  return { ok: false, reason: "outside-allowed-roots" }
}

/**
 * Accept only http/https fetch URLs; `file:`, `data:`, `javascript:` and
 * scheme-less strings are rejected with a stable reason token.
 */
export function checkFetchUrl(url: string): CheckFetchUrlResult {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return { ok: false, reason: "url-unparseable" }
  }
  if (!ALLOWED_URL_PROTOCOLS.has(parsed.protocol)) {
    return { ok: false, reason: "url-scheme-not-allowed" }
  }
  return { ok: true }
}
