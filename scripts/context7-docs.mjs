#!/usr/bin/env node
/**
 * context7-docs.mjs — fetch Context7 library docs for the monorepo's workspace
 * dependencies and store them as markdown under knowledge/context7-docs/.
 *
 * WHY this script exists: the RAG knowledge pipeline needs up-to-date library
 * docs as grounding context, and Context7 serves pre-processed LLM-friendly
 * markdown. This is a developer-triggered tool, NOT a CI gate: the free plan
 * allows 1000 calls/month, so wiring it into test-infra would exhaust quota.
 *
 * Operating modes (checked in this order):
 *   dry-run  — CONTEXT7_API_KEY missing/empty/placeholder. Inventory only,
 *              no API calls, exit 0.
 *   mock     — CONTEXT7_MOCK=1. API calls are served from
 *              scripts/__tests__/fixtures/context7-mock/ (unit tests only).
 *   real     — live Context7 API at https://context7.com/api (api.context7.com
 *              is DEAD — NXDOMAIN, confirmed 2026-08-02).
 *
 * Testability seams (env overrides, used by scripts/__tests__/context7-docs.bats):
 *   CONTEXT7_WORKSPACE_ROOT  workspace root to scan (default: process.cwd())
 *   CONTEXT7_RETRY_DELAY_MS  collapse ALL retry sleeps to this value so bats
 *                            tests never wait the nominal 5s/15s/45s backoff.
 *
 * Dependency-free by design: Node built-ins only (fs/path/url/fetch). No new
 * npm deps, no package.json changes. Semver comparison is a lightweight
 * major.minor.patch parser — prerelease/build-metadata handling is a follow-up
 * if it ever matters (tasks.md out-of-scope note).
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const MOCK_FIXTURE_DIR = path.join(SCRIPT_DIR, '__tests__', 'fixtures', 'context7-mock');

// Confirmed contract (design.md): context7.com/api, NOT the dead api.context7.com.
// API_BASE is the bare origin; endpoint paths carry the full /api/v2/... prefix
// (design.md endpoint table) — a trailing /api here would double it and 404.
const API_BASE = 'https://context7.com';

// The search/context `query` param is REQUIRED by the API (relevance ranking).
// One generic broad query keeps both calls identical and maximizes coverage.
const SEARCH_QUERY = 'introduction and usage overview';

// Retry policy (design.md HTTP status table):
//   202 not-finalized -> 3 retries, 5s/15s/45s exponential backoff
//   5xx              -> 1 retry, 5s
//   429              -> 1 retry, respect Retry-After (default 60s); 2nd 429 aborts
//   401/402          -> fatal, abort immediately
const RETRY_202_DELAYS_S = [5, 15, 45];
const RETRY_5XX_DELAY_S = 5;
const RATE_LIMIT_DEFAULT_S = 60;

// Mock-mode sentinel: this exact key makes the mock client return 401 so the
// fatal-auth path is testable without a real key. "test-key" and any other
// non-placeholder key exercise the normal mock path.
const MOCK_MODE_401_KEY = 'invalid-key';

// ---------------------------------------------------------------------------
// Workspace scanning (pure: workspace layout -> dependency list)
// ---------------------------------------------------------------------------

/**
 * Minimal pnpm-workspace.yaml parser. Only the `packages:` list form is read
 * (the repo's real file and the test fixtures both use it); YAML is deliberately
 * NOT a dependency. Stops at the next top-level key (e.g. onlyBuiltDependencies).
 */
function parseWorkspaceGlobs(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const globs = [];
  let inPackages = false;
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed.startsWith('packages:')) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (trimmed === '' || trimmed.startsWith('#')) continue;
    const m = trimmed.match(/^-\s*(?:"([^"]+)"|'([^']+)'|(\S+))/);
    if (m) {
      globs.push(m[1] ?? m[2] ?? m[3]);
    } else {
      inPackages = false; // next top-level key
    }
  }
  // Silent-failure guard (review fix): an unsupported YAML variant (scalar form,
  // single-line list, alternate `packages:` spelling, ...) yields zero globs.
  // Fail loudly instead of producing an empty inventory with exit 0 — a future
  // YAML variant must be noticed, not silently accepted. The repo's real file
  // and all fixtures use the supported list form, so this never trips on them.
  if (globs.length === 0) {
    throw new Error(
      `parseWorkspaceGlobs: found no package globs in ${filePath} — this parser only supports the 'packages:' list form (e.g. "- apps/*"); the YAML may use an unsupported variant`,
    );
  }
  return globs;
}

/**
 * Expand workspace globs (e.g. "packages/*") into repo-relative directory
 * paths that contain a package.json. Supports `*` (one level) and `**`
 * (recursive); `*` covers the repo's real globs (apps/*, packages/*).
 */
function expandGlobs(rootDir, globs) {
  const dirs = [];
  for (const glob of globs) {
    const parts = glob.split('/').filter(Boolean);
    let current = [rootDir];
    for (const part of parts) {
      const next = [];
      for (const dir of current) {
        let entries;
        try {
          entries = fs.readdirSync(dir, { withFileTypes: true });
        } catch {
          continue; // dir missing — glob matches nothing
        }
        for (const ent of entries) {
          if (!ent.isDirectory()) continue;
          const full = path.join(dir, ent.name);
          if (part === '**') {
            // recursive: include every nested dir
            const walk = (d) => {
              next.push(d);
              let sub;
              try {
                sub = fs.readdirSync(d, { withFileTypes: true });
              } catch {
                return;
              }
              for (const s of sub) if (s.isDirectory()) walk(path.join(d, s.name));
            };
            walk(full);
          } else if (part === '*' || ent.name === part) {
            next.push(full);
          }
        }
      }
      current = next;
    }
    for (const dir of current) {
      if (fs.existsSync(path.join(dir, 'package.json'))) {
        dirs.push(path.relative(rootDir, dir));
      }
    }
  }
  return [...new Set(dirs)].sort();
}

/**
 * Collect every dependency declaration from all four dependency sections of
 * every workspace package.json. Workspace-internal packages (@poetry/*) and
 * node: builtins are excluded — we only want third-party docs.
 */
function collectDependencies(rootDir) {
  const wsFile = path.join(rootDir, 'pnpm-workspace.yaml');
  if (!fs.existsSync(wsFile)) {
    throw new Error(
      `no pnpm-workspace.yaml found at ${wsFile} — run from the repo root (or set CONTEXT7_WORKSPACE_ROOT)`,
    );
  }
  const workspaces = expandGlobs(rootDir, parseWorkspaceGlobs(wsFile));
  const deps = [];
  for (const ws of workspaces) {
    const pkgFile = path.join(rootDir, ws, 'package.json');
    let pkg;
    try {
      pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));
    } catch (e) {
      console.error(`WARN: cannot read ${pkgFile}: ${e.message}`);
      continue;
    }
    for (const type of [
      'dependencies',
      'devDependencies',
      'peerDependencies',
      'optionalDependencies',
    ]) {
      const section = pkg[type];
      if (!section || typeof section !== 'object') continue;
      for (const [name, version] of Object.entries(section)) {
        if (name.startsWith('@poetry/')) continue;
        if (name.startsWith('node:')) continue;
        deps.push({ name, version: String(version), type, workspace: ws });
      }
    }
  }
  return { workspaces, deps };
}

// ---------------------------------------------------------------------------
// Version dedup (pure: dependency list -> unique libraries + skew warnings)
// ---------------------------------------------------------------------------

/** Strip semver range prefixes (^ ~ >= workspace:) to the bare base version. */
function stripRange(version) {
  let s = String(version).trim();
  if (s.startsWith('workspace:')) s = s.slice('workspace:'.length).trim();
  s = s.replace(/^[~^>=<xX*]+/, '').trim();
  const m = s.match(/^v?(\d+)\.(\d+)\.(\d+)/);
  if (m) return `${m[1]}.${m[2]}.${m[3]}`;
  const m2 = s.match(/^v?(\d+)\.(\d+)/);
  if (m2) return `${m2[1]}.${m2[2]}.0`;
  const m3 = s.match(/^v?(\d+)/);
  if (m3) return `${m3[1]}.0.0`;
  return s; // unparseable (e.g. "*", "latest") — kept as-is, sorts lowest
}

/** Lightweight major.minor.patch comparator; unparseable versions sort lowest. */
function compareVersions(a, b) {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  if (pa === null && pb === null) return 0;
  if (pa === null) return -1;
  if (pb === null) return 1;
  if (pa.major !== pb.major) return pa.major - pb.major;
  if (pa.minor !== pb.minor) return pa.minor - pb.minor;
  return pa.patch - pb.patch;
}

function parseVersion(v) {
  const m = stripRange(v).match(/^(\d+)\.(\d+)\.(\d+)/);
  if (!m) return null;
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

/**
 * Group dependencies by name, resolve each to the highest version found, and
 * emit a skew warning when workspaces disagree. `versions` is keyed by
 * workspace path (raw range strings); if one workspace declares the same
 * package twice (e.g. dep + devDep at different ranges), last-declared wins
 * for the warning map — the RESOLVED version still takes the global max.
 */
function deduplicate(deps) {
  const byName = new Map();
  for (const dep of deps) {
    if (!byName.has(dep.name)) byName.set(dep.name, []);
    byName.get(dep.name).push(dep);
  }
  const libraries = [];
  const warnings = [];
  for (const [name, entries] of byName) {
    let resolved = entries[0].version;
    const versions = {};
    for (const e of entries) {
      versions[e.workspace] = e.version;
      if (compareVersions(e.version, resolved) > 0) resolved = e.version;
    }
    const resolvedBase = stripRange(resolved);
    if (new Set(entries.map((e) => e.version)).size > 1) {
      const detail = Object.entries(versions)
        .map(([ws, v]) => `${ws} has ${v}`)
        .join(', ');
      console.error(
        `WARN: version skew for ${name}: ${detail} — resolved to highest: ${resolvedBase}`,
      );
      warnings.push({ package: name, versions, resolved: resolvedBase });
    }
    libraries.push({ packageName: name, resolvedVersion: resolvedBase });
  }
  libraries.sort((a, b) => a.packageName.localeCompare(b.packageName));
  return { libraries, warnings };
}

// ---------------------------------------------------------------------------
// HTTP layer (retry policy + mock routing)
// ---------------------------------------------------------------------------

function sleepMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Testability seam: CONTEXT7_RETRY_DELAY_MS collapses every wait to a fixed
 * value so bats never sleeps the nominal 5s/15s/45s backoff. */
function scaledDelay(seconds) {
  const override = Number(process.env.CONTEXT7_RETRY_DELAY_MS);
  if (Number.isFinite(override) && override >= 0) return override;
  return seconds * 1000;
}

function parseRetryAfter(value) {
  if (!value) return null;
  const s = Number(value);
  // HTTP-date form (rare) is not supported — callers fall back to the default.
  return Number.isFinite(s) && s >= 0 ? s : null;
}

async function realRequest(url, apiKey, acceptType) {
  const headers = { Accept: acceptType === 'txt' ? 'text/plain' : 'application/json' };
  if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
  const res = await fetch(url, { headers });
  const body = await res.text();
  let json = null;
  try {
    json = JSON.parse(body);
  } catch {
    // body not JSON (expected for type=txt) — fine
  }
  return { status: res.status, body, json, retryAfter: res.headers.get('retry-after') };
}

function readMockFixture(name) {
  const p = path.join(MOCK_FIXTURE_DIR, name);
  if (!fs.existsSync(p)) return null;
  return fs.readFileSync(p, 'utf8');
}

/** Mock search response router. Fixture files are named search-<pkg>.json.
 * A missing fixture mimics a 404; a fixture with results[0].state "processing"
 * mimics the API's 202 not-finalized response for the first two attempts
 * (deterministic via the `attempt` argument — no in-process counter needed). */
function mockSearch(pkg, apiKey, attempt) {
  if (apiKey === MOCK_MODE_401_KEY) {
    return { status: 401, body: '{"error":"invalid_api_key","message":"invalid API key"}' };
  }
  const body = readMockFixture(`search-${pkg}.json`);
  if (body === null) {
    return {
      status: 404,
      body: `{"error":"not_found","message":"mock fixture missing: search-${pkg}.json"}`,
    };
  }
  const json = JSON.parse(body);
  // 301 routing: a fixture with a top-level `redirectUrl` key simulates the
  // API's "library moved" response. A null/empty value exercises the
  // 301-without-redirectUrl edge case (searchLibrary marks it skipped).
  if (Object.prototype.hasOwnProperty.call(json, 'redirectUrl')) {
    return { status: 301, body, json };
  }
  if (json.results?.[0]?.state === 'processing' && attempt < 2) {
    return {
      status: 202,
      body: '{"error":"library_not_finalized","message":"library not finalized"}',
    };
  }
  return { status: 200, body, json };
}

/** Mock context-fetch router. Fixture files are context-<slug>.txt where slug
 * is the libraryId with leading "/" removed and "/" -> "-". A fixture whose
 * body is JSON with a top-level `redirectUrl` key simulates a 301 "library
 * moved" response (markdown bodies are served as plain 200). */
function mockFetch(libraryId, apiKey) {
  if (apiKey === MOCK_MODE_401_KEY) {
    return { status: 401, body: '{"error":"invalid_api_key","message":"invalid API key"}' };
  }
  const body = readMockFixture(`context-${slugify(libraryId)}.txt`);
  if (body === null) {
    return {
      status: 404,
      body: `{"error":"not_found","message":"mock fixture missing: context-${slugify(libraryId)}.txt"}`,
    };
  }
  let json = null;
  try {
    json = JSON.parse(body);
  } catch {
    // markdown body — not a redirect response
  }
  if (json && Object.prototype.hasOwnProperty.call(json, 'redirectUrl')) {
    return { status: 301, body, json };
  }
  return { status: 200, body };
}

/**
 * One GET with the retry policy baked in. Shared by search and context calls.
 * Returns a response object; `fatal: true` means the whole run must abort
 * (401/402, or a second 429).
 */
async function apiGet(url, { apiKey, mode, mock, label, acceptType = 'json' }) {
  let attempt = 0;
  let rateLimited = false;
  for (;;) {
    const res = mode === 'mock' ? mock(attempt) : await realRequest(url, apiKey, acceptType);
    if (res.status === 401 || res.status === 402) {
      return { ...res, fatal: true };
    }
    if (res.status === 202 && attempt < RETRY_202_DELAYS_S.length) {
      console.error(
        `WARN: ${label} returned 202 (library not finalized) — retry ${attempt + 1}/${RETRY_202_DELAYS_S.length} in ${RETRY_202_DELAYS_S[attempt]}s`,
      );
      await sleepMs(scaledDelay(RETRY_202_DELAYS_S[attempt]));
      attempt++;
      continue;
    }
    if (res.status >= 500 && attempt < 1) {
      console.error(`WARN: ${label} returned ${res.status} — retrying in ${RETRY_5XX_DELAY_S}s`);
      await sleepMs(scaledDelay(RETRY_5XX_DELAY_S));
      attempt++;
      continue;
    }
    if (res.status === 429) {
      if (rateLimited) return { ...res, fatal: true };
      rateLimited = true;
      const waitS = parseRetryAfter(res.retryAfter) ?? RATE_LIMIT_DEFAULT_S;
      console.error(`WARN: ${label} rate limited (429) — waiting ${waitS}s (Retry-After)`);
      await sleepMs(scaledDelay(waitS));
      continue;
    }
    return res; // 200, 301, 404, or an exhausted 202/5xx — no more retries
  }
}

function describeHttpError(status) {
  switch (status) {
    case 401:
      return 'invalid API key';
    case 402:
      return 'spending limit exceeded';
    case 429:
      return 'rate limit exceeded';
    default:
      return `HTTP ${status}`;
  }
}

// ---------------------------------------------------------------------------
// Per-library pipeline (search -> fetch -> write markdown)
// ---------------------------------------------------------------------------

/** /owner/repo -> owner-repo (leading "/" dropped, "/" replaced with "-"). */
function slugify(libraryId) {
  return String(libraryId).replace(/^\//, '').replace(/\//g, '-');
}

async function searchLibrary(pkg, { apiKey, mode }) {
  const url = `${API_BASE}/api/v2/libs/search?libraryName=${encodeURIComponent(pkg)}&query=${encodeURIComponent(SEARCH_QUERY)}`;
  const label = `search(${pkg})`;
  const res = await apiGet(url, {
    apiKey,
    mode,
    mock: (attempt) => mockSearch(pkg, apiKey, attempt),
    label,
    acceptType: 'json',
  });
  if (res.fatal) return { fatal: res };
  if (res.status === 301) {
    const target = res.json?.redirectUrl;
    if (target) {
      console.error(`WARN: ${label} returned 301 — following redirect to ${target}`);
      return { libraryId: target };
    }
    // 301 without redirectUrl: the library is unresolvable, not broken — mark
    // skipped (unified with fetchDocs: never "failed" for this condition).
    return { skipped: true, statusDetail: `${label} returned 301 without redirectUrl` };
  }
  if (res.status === 404) {
    return {
      skipped: true,
      statusDetail: res.json?.message ?? `no Context7 library found for ${pkg}`,
    };
  }
  if (res.status !== 200) {
    return { failed: true, statusDetail: `${label} returned HTTP ${res.status} after retries` };
  }
  const results = res.json?.results;
  if (!Array.isArray(results) || results.length === 0) {
    return { skipped: true, statusDetail: `no Context7 library found for ${pkg}` };
  }
  if (!results[0].id) {
    return { skipped: true, statusDetail: `search result for ${pkg} is missing an id` };
  }
  return { libraryId: results[0].id };
}

async function fetchDocs(libraryId, { apiKey, mode, depth = 0 }) {
  const url = `${API_BASE}/api/v2/context?libraryId=${encodeURIComponent(libraryId)}&query=${encodeURIComponent(SEARCH_QUERY)}&type=txt`;
  const label = `fetch(${libraryId})`;
  const res = await apiGet(url, {
    apiKey,
    mode,
    mock: () => mockFetch(libraryId, apiKey),
    label,
    acceptType: 'txt',
  });
  if (res.fatal) return { fatal: res };
  if (res.status === 301) {
    const target = res.json?.redirectUrl;
    if (target && depth < 3) {
      console.error(`WARN: ${label} returned 301 — following redirect to ${target}`);
      return fetchDocs(target, { apiKey, mode, depth: depth + 1 });
    }
    if (target) {
      // redirectUrl present but the depth cap (3) is exhausted — a genuine
      // redirect loop, not an unresolvable library: keep this one "failed".
      return {
        failed: true,
        statusDetail: `${label} 301 redirect loop (depth cap 3, last target ${target})`,
      };
    }
    // 301 without redirectUrl: the library is unresolvable, not broken — mark
    // skipped (unified with searchLibrary: never "failed" for this condition).
    return { skipped: true, statusDetail: `${label} returned 301 without redirectUrl` };
  }
  if (res.status !== 200) {
    return { failed: true, statusDetail: `${label} returned HTTP ${res.status} after retries` };
  }
  return { markdown: res.body };
}

function writeMarkdown(outDir, lib, markdown, fetchedAt) {
  const slug = slugify(lib.context7LibraryId);
  const frontmatter = [
    '---',
    `libraryId: ${lib.context7LibraryId}`,
    `packageName: ${lib.packageName}`,
    `resolvedVersion: ${lib.resolvedVersion}`,
    `fetchedAt: ${fetchedAt}`,
    '---',
    '',
  ].join('\n');
  const filePath = path.join(outDir, `${slug}.md`);
  fs.writeFileSync(filePath, frontmatter + markdown + '\n');
  return `${slug}.md`;
}

// ---------------------------------------------------------------------------
// Inventory + report
// ---------------------------------------------------------------------------

function summarize(statuses) {
  const s = { succeeded: 0, skipped: 0, failed: 0 };
  for (const st of Object.values(statuses)) {
    if (st === 'succeeded') s.succeeded++;
    else if (st === 'skipped') s.skipped++;
    else if (st === 'failed') s.failed++;
  }
  return s;
}

function buildInventory({
  mode,
  workspaces,
  totalDependencies,
  libraries,
  warnings,
  statuses,
  details,
  outputFiles,
}) {
  const librariesOut = libraries.map((lib) => {
    const entry = { packageName: lib.packageName, resolvedVersion: lib.resolvedVersion };
    if (mode === 'dry-run') {
      entry.status = 'dry-run';
    } else {
      entry.status = statuses[lib.packageName] ?? 'skipped';
      if (details[lib.packageName]) entry.statusDetail = details[lib.packageName];
      if (outputFiles[lib.packageName]) entry.outputFile = outputFiles[lib.packageName];
    }
    return entry;
  });
  return {
    generatedAt: new Date().toISOString(),
    mode,
    workspacesScanned: workspaces,
    totalDependencies,
    uniqueLibraries: libraries.length,
    versionSkewWarnings: warnings,
    libraries: librariesOut,
    summary: summarize(statuses),
  };
}

function printSummary(inv) {
  console.log(`Context7 docs pipeline — mode: ${inv.mode}`);
  console.log(`workspaces scanned: ${inv.workspacesScanned.length}`);
  console.log(`total dependencies: ${inv.totalDependencies}`);
  console.log(`unique libraries: ${inv.uniqueLibraries}`);
  console.log(`version skew warnings: ${inv.versionSkewWarnings.length}`);
  for (const w of inv.versionSkewWarnings) {
    const parts = Object.entries(w.versions)
      .map(([ws, v]) => `${ws} has ${v}`)
      .join(', ');
    console.log(`  - ${w.package}: ${parts} -> resolved to ${w.resolved}`);
  }
  console.log('libraries:');
  for (const lib of inv.libraries) {
    const extra = lib.outputFile ? ` (${lib.outputFile})` : '';
    const detail = lib.statusDetail ? ` — ${lib.statusDetail}` : '';
    console.log(`  - ${lib.packageName}@${lib.resolvedVersion}: ${lib.status}${extra}${detail}`);
  }
  console.log(
    `summary: ${inv.summary.succeeded} succeeded, ${inv.summary.skipped} skipped, ${inv.summary.failed} failed`,
  );
}

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------

async function main() {
  const rootDir = process.env.CONTEXT7_WORKSPACE_ROOT || process.cwd();
  const outDir = path.join(rootDir, 'knowledge', 'context7-docs');
  fs.mkdirSync(outDir, { recursive: true });

  const apiKey = process.env.CONTEXT7_API_KEY || '';
  const mockMode = process.env.CONTEXT7_MOCK === '1';

  let mode;
  if (!apiKey || apiKey.startsWith('placeholder')) {
    mode = 'dry-run';
    console.error('No Context7 API key — running in dry-run mode (inventory only)');
  } else if (mockMode) {
    mode = 'mock';
    console.error('MOCK MODE — no real API calls');
  } else {
    mode = 'real';
  }

  const { workspaces, deps } = collectDependencies(rootDir);
  const { libraries, warnings } = deduplicate(deps);

  const statuses = {};
  const details = {};
  const outputFiles = {};

  if (mode !== 'dry-run') {
    const fetchedAt = new Date().toISOString();
    let fatal = null;
    for (const lib of libraries) {
      if (fatal) {
        // Run aborted after a fatal auth/quota error — remaining libs unprocessed.
        statuses[lib.packageName] = 'skipped';
        details[lib.packageName] = 'run aborted after fatal API error';
        continue;
      }
      const search = await searchLibrary(lib.packageName, { apiKey, mode });
      if (search.fatal) {
        fatal = search.fatal;
        statuses[lib.packageName] = 'failed';
        details[lib.packageName] = describeHttpError(search.fatal.status);
        continue;
      }
      if (search.skipped) {
        console.error(`WARN: skipping ${lib.packageName} — ${search.statusDetail}`);
        statuses[lib.packageName] = 'skipped';
        details[lib.packageName] = search.statusDetail;
        continue;
      }
      if (search.failed) {
        console.error(`ERROR: ${lib.packageName} — ${search.statusDetail}`);
        statuses[lib.packageName] = 'failed';
        details[lib.packageName] = search.statusDetail;
        continue;
      }
      const fetch = await fetchDocs(search.libraryId, { apiKey, mode });
      if (fetch.fatal) {
        fatal = fetch.fatal;
        statuses[lib.packageName] = 'failed';
        details[lib.packageName] = describeHttpError(fetch.fatal.status);
        continue;
      }
      if (fetch.skipped) {
        console.error(
          `WARN: skipping ${lib.packageName} (${search.libraryId}) — ${fetch.statusDetail}`,
        );
        statuses[lib.packageName] = 'skipped';
        details[lib.packageName] = fetch.statusDetail;
        continue;
      }
      if (fetch.failed) {
        console.error(`ERROR: ${lib.packageName} (${search.libraryId}) — ${fetch.statusDetail}`);
        statuses[lib.packageName] = 'failed';
        details[lib.packageName] = fetch.statusDetail;
        continue;
      }
      const libEntry = { ...lib, context7LibraryId: search.libraryId };
      const outputFile = writeMarkdown(outDir, libEntry, fetch.markdown, fetchedAt);
      console.error(
        `ok: ${lib.packageName}@${lib.resolvedVersion} -> ${search.libraryId} -> ${outputFile}`,
      );
      statuses[lib.packageName] = 'succeeded';
      outputFiles[lib.packageName] = outputFile;
    }
    if (fatal) {
      console.error(
        `FATAL: Context7 API aborted: ${describeHttpError(fatal.status)} (HTTP ${fatal.status})`,
      );
      process.exitCode = 1;
    }
  }

  const inventory = buildInventory({
    mode,
    workspaces,
    totalDependencies: deps.length,
    libraries,
    warnings,
    statuses,
    details,
    outputFiles,
  });
  writeInventory(outDir, inventory);
  printSummary(inventory);
}

function writeInventory(outDir, inventory) {
  fs.writeFileSync(path.join(outDir, '_inventory.json'), `${JSON.stringify(inventory, null, 2)}\n`);
}

main().catch((err) => {
  console.error(`FATAL: ${err.message}`);
  process.exitCode = 1;
});
