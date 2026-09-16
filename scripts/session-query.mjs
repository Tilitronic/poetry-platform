#!/usr/bin/env node
/**
 * session-query.mjs — read-only SQL query layer over orchestrator session
 * records (DIA-156, V2 of the DIA-136 read-layer decision).
 *
 * Loads .opencode/session/registry.jsonl (delegation lifecycle rows) and
 * .opencode/session/messages.jsonl (semantic event rows) into an in-memory
 * node:sqlite database (new DatabaseSync(':memory:'), zero new deps — the
 * engine is a Node built-in) and runs ONE filtered/aggregated query,
 * printing only the requested rows as JSONL to stdout.
 *
 * The token-economy win: the orchestrator gets exactly the rows it asked
 * for (a single session's record, a grouped count) instead of a full-file
 * read of ~16k-line JSONL logs.
 *
 * Canonical-source-of-truth contract (binding, DIA-136 developer decision):
 *   - JSONL stays the canonical committed store — this script ONLY READS
 *     the JSONL records (fs.readFileSync, no writes) and never touches the
 *     delegation-observer write path.
 *   - NO binary DB file is ever created: :memory: lives only for the
 *     duration of the query process.
 *   - node:sqlite readOnly:true is deliberately NOT used: SQLite's
 *     read-only mode rejects even in-memory DDL/DML, which the JSONL->table
 *     import requires (verified empirically on Node v24.18.0). The
 *     read-only guarantee comes from :memory: (no file backing, ephemeral)
 *     plus read-only opens of the JSONL inputs — the binding intent
 *     (never write a session record, never commit a binary) is preserved.
 *
 * Malformed-line policy (documented): a line that fails JSON.parse is
 * SKIPPED with a warning to stderr and counted; the query proceeds over the
 * valid rows (warn-and-skip, mirroring jsonl-cross-check.sh's precedent).
 * Blank lines are ignored silently. A missing input file is an INFRA error
 * (exit 2) — same convention as the other dev-infra validators.
 *
 * Usage:
 *   node scripts/session-query.mjs [options]
 *
 * Options:
 *   --registry <path>   registry.jsonl path (default: .opencode/session/registry.jsonl)
 *   --messages <path>   messages.jsonl path (default: .opencode/session/messages.jsonl)
 *   --session <id>      recall: print every registry row with session_id=<id>
 *                       plus every messages row with gen_ai.agent.id=<id>
 *                       (messages.jsonl has no session_id field; the agent.id
 *                       is the task/session correlation key — verified
 *                       overlap ~1181/2217 on the live records).
 *   --count-by <field>  aggregate: print { "<field>": value, "count": N }
 *                       per distinct non-NULL value of <field> in --table
 *                       (e.g. status, event_type, resolution_status, lane_id).
 *                       NULL groups (rows missing the field) are omitted.
 *   --table <t>         table for --count-by: registry | messages
 *                       (required with --count-by).
 *   --where <k=v>       equality filter, repeatable. Applied as
 *                       json_extract(data, '$.k') = v on every queried table.
 *   --limit <n>         max rows printed (default 100; 0 = unlimited).
 *                       --count-by caps the number of groups.
 *   --json              print a single JSON array instead of JSONL.
 *   --help              show this help and exit.
 *
 * Exit codes: 0 ok (empty result is ok), 2 usage error or missing input file.
 *
 * Examples:
 *   node scripts/session-query.mjs --session ses_abc123
 *   node scripts/session-query.mjs --count-by status --table registry
 *   node scripts/session-query.mjs --count-by event_type --table messages \
 *     --where resolution_status=in-flight
 */

import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const DEFAULT_REGISTRY = '.opencode/session/registry.jsonl';
const DEFAULT_MESSAGES = '.opencode/session/messages.jsonl';
const DEFAULT_ARCHIVE_DIR = '.opencode/session/registry-archive';
const VALID_TABLES = new Set(['registry', 'messages']);
// Recall matches messages rows via the task/session correlation key
// (gen_ai.agent.id) because the messages log has no session_id column.
const MESSAGES_SESSION_KEY = 'gen_ai.agent.id';

function usage() {
  return `Usage: node scripts/session-query.mjs [options]

Read-only SQL query layer over the orchestrator's session records
(.opencode/session/registry.jsonl + messages.jsonl). Loads both files into
an in-memory node:sqlite database (:memory:, zero deps) and runs ONE
filtered/aggregated query, printing only the requested rows as JSONL to
stdout. The JSONL files stay the canonical committed source of truth -
nothing is ever written back and no binary DB file is created.

Options:
  --registry <path>   registry.jsonl path (default: .opencode/session/registry.jsonl)
  --messages <path>   messages.jsonl path (default: .opencode/session/messages.jsonl)
  --archive-dir <path> verified registry archive directory (default: .opencode/session/registry-archive)
  --active-only       query only the active registry (skip archive validation)
  --session <id>      recall: print every registry row with session_id=<id>
                      plus every messages row with gen_ai.agent.id=<id>
  --count-by <field>  aggregate: print { "<field>": value, "count": N } per
                      distinct non-NULL value of <field> in --table
  --table <t>         table for --count-by: registry | messages (required)
  --where <k=v>       equality filter, repeatable (json_extract(data,'$.k')=v)
  --limit <n>         max rows printed (default 100; 0 = unlimited)
  --json              print a single JSON array instead of JSONL
  --help              show this help and exit

One query mode is required: --session <id> OR --count-by <field> (not both).
Exit codes: 0 ok (empty result is ok), 2 usage error or missing input file.

Examples:
  node scripts/session-query.mjs --session ses_abc123
  node scripts/session-query.mjs --count-by status --table registry
  node scripts/session-query.mjs --count-by event_type --table messages --where resolution_status=in-flight`;
}

class UsageError extends Error {}

// ---------------------------------------------------------------------------
// Minimal arg parsing (explicitly NOT a CLI framework — DIA-086 scope guard).
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const opts = {
    registry: DEFAULT_REGISTRY,
    messages: DEFAULT_MESSAGES,
    archiveDir: DEFAULT_ARCHIVE_DIR,
    archiveDirExplicit: false,
    activeOnly: false,
    session: null,
    countBy: null,
    table: null,
    wheres: [],
    limit: 100,
    json: false,
    help: false,
  };
  const needValue = (name, i) => {
    const v = argv[i + 1];
    if (v === undefined) throw new UsageError(`--${name} requires a value`);
    return v;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--registry':
        opts.registry = needValue('registry', i);
        i++;
        break;
      case '--messages':
        opts.messages = needValue('messages', i);
        i++;
        break;
      case '--archive-dir':
        opts.archiveDir = needValue('archive-dir', i);
        opts.archiveDirExplicit = true;
        i++;
        break;
      case '--active-only':
        opts.activeOnly = true;
        break;
      case '--session':
        opts.session = needValue('session', i);
        i++;
        break;
      case '--count-by':
        opts.countBy = needValue('count-by', i);
        i++;
        break;
      case '--table':
        opts.table = needValue('table', i);
        i++;
        break;
      case '--where': {
        const w = needValue('where', i);
        i++;
        const eq = w.indexOf('=');
        if (eq < 1) throw new UsageError(`--where expects <field>=<value>, got: ${w}`);
        opts.wheres.push([w.slice(0, eq), w.slice(eq + 1)]);
        break;
      }
      case '--limit': {
        const v = needValue('limit', i);
        i++;
        if (!/^\d+$/.test(v))
          throw new UsageError(`--limit expects a non-negative integer, got: ${v}`);
        opts.limit = Number(v);
        break;
      }
      case '--json':
        opts.json = true;
        break;
      case '--help':
      case '-h':
        opts.help = true;
        break;
      default:
        throw new UsageError(`unknown option: ${a}`);
    }
  }
  if (opts.help) return opts; // help short-circuits all validation
  if (opts.session && opts.countBy) {
    throw new UsageError(
      '--session and --count-by are mutually exclusive (one query per invocation)',
    );
  }
  if (!opts.session && !opts.countBy) {
    throw new UsageError('one query mode required: --session <id> or --count-by <field>');
  }
  if (opts.countBy && !opts.table) {
    throw new UsageError('--count-by requires --table registry|messages');
  }
  if (opts.table && !VALID_TABLES.has(opts.table)) {
    throw new UsageError(`--table must be one of: ${[...VALID_TABLES].join(', ')}`);
  }
  // A custom registry belongs to its own session directory.  Keep the
  // canonical default unchanged, but never accidentally read the repository
  // archive when a caller points at a disposable registry fixture.
  if (!opts.archiveDirExplicit && opts.registry !== DEFAULT_REGISTRY) {
    opts.archiveDir = join(dirname(opts.registry), 'registry-archive');
  }
  return opts;
}

// ---------------------------------------------------------------------------
// JSONL -> in-memory table import. Raw lines are stored verbatim (id + data)
// so output rows are byte-faithful to the committed records. Malformed lines
// are skipped with a warning (documented policy, see header).
// ---------------------------------------------------------------------------
function canonicalJson(value) {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, item]) => [key, canonicalJson(item)]),
    );
  }
  return value;
}

function isCompactProjection(row) {
  return (
    row &&
    typeof row === 'object' &&
    typeof row._offset === 'number' &&
    Number.isFinite(row._offset) &&
    typeof row.lifecycle_generation === 'number' &&
    Number.isFinite(row.lifecycle_generation)
  );
}

function importJsonl(db, table, filePath, { seenSeq, allowProjectionOverlap = false } = {}) {
  db.exec(
    `CREATE TABLE IF NOT EXISTS ${table} (id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT NOT NULL)`,
  );
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch (err) {
    throw new Error(`input file not found: ${filePath} (${err.code})`);
  }
  const insert = db.prepare(`INSERT INTO ${table} (data) VALUES (?)`);
  let imported = 0;
  let skipped = 0;
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue; // blank lines are noise, not malformed rows
    let parsed;
    try {
      parsed = JSON.parse(line); // validate; the raw line is what we store
    } catch {
      skipped++;
      console.error(`warn: ${filePath} line ${i + 1} is malformed JSON - skipped`);
      continue;
    }
    if (seenSeq && typeof parsed.seq === 'number' && Number.isFinite(parsed.seq)) {
      const key = String(parsed.seq);
      const canonical = JSON.stringify(canonicalJson(parsed));
      const existing = seenSeq.get(key);
      if (existing !== undefined && existing.canonical === canonical) continue;
      if (existing !== undefined) {
        if (allowProjectionOverlap && table === 'registry') {
          const projection = isCompactProjection(parsed);
          if (existing.projection && !projection) {
            db.prepare('DELETE FROM registry WHERE id = ?').run(existing.id);
            const inserted = insert.run(line);
            seenSeq.set(key, { canonical, projection: false, id: inserted.lastInsertRowid });
            imported++;
            continue;
          }
          if (!existing.projection && projection) continue;
        }
        throw new Error(`conflicting registry archive payload for seq ${key}`);
      }
      const inserted = insert.run(line);
      seenSeq.set(key, {
        canonical,
        projection: table === 'registry' && isCompactProjection(parsed),
        id: inserted.lastInsertRowid,
      });
      imported++;
      continue;
    }
    insert.run(line);
    imported++;
  }
  return { imported, skipped };
}

// Registry archives are immutable only when their adjacent manifest verifies
// the exact bytes. Unverified files are never queried (fail closed).
function verifiedRegistryArchives(archiveDir, { required = false } = {}) {
  if (!archiveDir) return [];
  if (!fs.existsSync(archiveDir)) {
    if (required) throw new Error(`archive directory unavailable: ${archiveDir} (ENOENT)`);
    return [];
  }
  let names;
  try {
    names = fs.readdirSync(archiveDir, { withFileTypes: true });
  } catch (err) {
    throw new Error(`archive directory unavailable: ${archiveDir} (${err.code ?? err.message})`);
  }
  const files = names
    .filter((entry) => entry.isFile() && entry.name.endsWith('.jsonl'))
    .map((entry) => entry.name)
    .sort();
  return files.map((name) => {
    const filePath = `${archiveDir}/${name}`;
    const manifestPath = `${filePath}.manifest.json`;
    let manifest;
    try {
      manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    } catch (err) {
      throw new Error(`archive ${name} lacks a verified manifest (${err.code ?? err.message})`);
    }
    const bytes = fs.readFileSync(filePath);
    const checksum = createHash('sha256').update(bytes).digest('hex');
    if (
      manifest.archive !== name ||
      manifest.sha256 !== checksum ||
      manifest.byte_count !== bytes.byteLength
    ) {
      throw new Error(`archive ${name} failed verified manifest check`);
    }
    return filePath;
  });
}

// Build a repeatable-equality filter fragment over the JSON payload.
// The returned `clause` is ` AND ...` (joinable after another predicate) or
// empty; `where` is the standalone ` WHERE ...` form. Both share one params
// array. json_extract binds the field name as a parameter so values can
// never inject SQL.
function buildWhere(wheres) {
  if (wheres.length === 0) return { clause: '', where: '', params: [] };
  const clauses = [];
  const params = [];
  for (const [field, value] of wheres) {
    clauses.push(`${jsonPath(field)} = ?`);
    params.push(value);
  }
  const joined = clauses.join(' AND ');
  return { clause: ` AND ${joined}`, where: ` WHERE ${joined}`, params };
}

// jsonPath(field): a SQLite JSON1 path expression for a FLAT top-level key.
// Keys that contain a literal dot (e.g. the messages-log semconv key
// "gen_ai.agent.id") MUST be quoted — unquoted, SQLite's JSON path treats
// dots as nesting separators and silently resolves to NULL (verified on
// Node v24.18.0). The path is built from a constant prefix + the field name
// checked against a safe charset, so user input cannot inject SQL.
function jsonPath(field) {
  if (!/^[A-Za-z0-9_.-]+$/.test(field)) {
    throw new Error(`unsafe field name: ${field} (allowed: [A-Za-z0-9_.-])`);
  }
  return field.includes('.')
    ? `json_extract(data, '$."${field}"')`
    : `json_extract(data, '$.${field}')`;
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    if (err instanceof UsageError) {
      console.error(`error: ${err.message}`);
      console.error(usage());
      process.exit(2);
    }
    throw err;
  }

  if (opts.help) {
    console.log(usage());
    process.exit(0);
  }

  const db = new DatabaseSync(':memory:'); // ephemeral: dies with this process
  const w = buildWhere(opts.wheres);
  const registrySeenSeq = new Map();
  const registryStats = importJsonl(db, 'registry', opts.registry, {
    seenSeq: registrySeenSeq,
    allowProjectionOverlap: !opts.activeOnly,
  });
  const archiveFiles = opts.activeOnly
    ? []
    : verifiedRegistryArchives(opts.archiveDir, { required: opts.archiveDirExplicit });
  const archiveStats = archiveFiles.reduce(
    (total, filePath) => {
      const stats = importJsonl(db, 'registry', filePath, {
        seenSeq: registrySeenSeq,
        allowProjectionOverlap: true,
      });
      return { imported: total.imported + stats.imported, skipped: total.skipped + stats.skipped };
    },
    { imported: 0, skipped: 0 },
  );
  const messagesStats = importJsonl(db, 'messages', opts.messages);
  console.error(
    `note: imported registry=${registryStats.imported + archiveStats.imported} messages=${messagesStats.imported}` +
      ` malformed-skipped=${registryStats.skipped + archiveStats.skipped + messagesStats.skipped}`,
  );

  let rows = [];
  if (opts.session) {
    // Recall: registry rows keyed by session_id, messages rows keyed by the
    // task/session correlation key (gen_ai.agent.id).
    const registryRows = db
      .prepare(`SELECT data FROM registry WHERE json_extract(data, '$.session_id') = ?${w.clause}`)
      .all(opts.session, ...w.params)
      .map((r) => JSON.parse(r.data));
    const messagesRows = db
      .prepare(`SELECT data FROM messages WHERE ${jsonPath(MESSAGES_SESSION_KEY)} = ?${w.clause}`)
      .all(opts.session, ...w.params)
      .map((r) => JSON.parse(r.data));
    rows = [...registryRows, ...messagesRows];
  } else {
    // Aggregation: one group per distinct non-NULL field value.
    const groupRows = db
      .prepare(
        `SELECT ${jsonPath(opts.countBy)} AS v, COUNT(*) AS c ` +
          `FROM ${opts.table}${w.where} GROUP BY v HAVING v IS NOT NULL ORDER BY c DESC, v`,
      )
      .all(...w.params);
    rows = groupRows.map((r) => ({ [opts.countBy]: r.v, count: Number(r.c) }));
  }

  if (opts.limit > 0 && rows.length > opts.limit) {
    rows = rows.slice(0, opts.limit);
  }

  if (opts.json) {
    console.log(JSON.stringify(rows));
  } else {
    for (const row of rows) console.log(JSON.stringify(row));
  }
  db.close();
}

try {
  main();
} catch (err) {
  console.error(`error: ${err.message}`);
  process.exit(2);
}
