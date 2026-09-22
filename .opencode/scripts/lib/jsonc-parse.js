// Shared JSONC handling for OpenCode config validators (make test-config).
//
// JSONC = JSON with // and /* */ comments plus trailing commas. Node's
// JSON.parse rejects all three, so we strip them with a small char-level
// tokenizer that respects string literals - naive regex stripping would
// corrupt URLs such as https://... inside the config.
//
// Usage:
//   node jsonc-parse.js <file>             exit 0 iff <file> parses as JSON(C)
//   node jsonc-parse.js --lockstep <file>  compare agent.coder vs
//                                          agent.coder-escalated permission
//                                          maps; exit 1 + diff on drift
'use strict';
const fs = require('fs');

function stripComments(src) {
  let out = '';
  let inString = null;     // quote char (' or ") when inside a string literal
  let inLineComment = false;
  let inBlockComment = false;

  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    const n = src[i + 1];

    if (inLineComment) {
      if (c === '\n') { inLineComment = false; out += c; }
      continue;
    }
    if (inBlockComment) {
      if (c === '*' && n === '/') { inBlockComment = false; i++; }
      continue;
    }
    if (inString) {
      if (c === '\\') { out += c + (n || ''); i++; continue; }
      out += c;
      if (c === inString) inString = null;
      continue;
    }
    if (c === '"' || c === "'") { inString = c; out += c; continue; }
    if (c === '/' && n === '/') { inLineComment = true; i++; continue; }
    if (c === '/' && n === '*') { inBlockComment = true; i++; continue; }
    // trailing comma: drop ',' when the next non-whitespace char is } or ]
    if (c === ',') {
      let j = i + 1;
      while (j < src.length && /\s/.test(src[j])) j++;
      if (src[j] === '}' || src[j] === ']') continue;
      out += c;
      continue;
    }
    out += c;
  }
  return out;
}

function parseJsonc(file) {
  return JSON.parse(stripComments(fs.readFileSync(file, 'utf8')));
}

const args = process.argv.slice(2);

if (args[0] === '--lockstep') {
  // DIA-260825-nts7 fix-all batch F2: coder-escalated is documented as an
  // EXACT clone of the base coder permission map plus task-related keys, but
  // nothing enforced that - the maps already drifted once (reviewer finding).
  // One comparison function, deep-equal on every permission key except
  // task-related ones (the escalated lane denies delegation by design).
  const cfg = parseJsonc(args[1]);
  const agents = cfg.agent || {};
  const pick = (perm) => {
    const TASK_KEYS = new Set(['task']); // escalated lane adds task:"deny" by design
    const out = {};
    for (const k of Object.keys(perm || {}).sort()) {
      if (!TASK_KEYS.has(k)) out[k] = perm[k];
    }
    return out;
  };
  const a = pick((agents.coder || {}).permission);
  const b = pick((agents['coder-escalated'] || {}).permission);
  const problems = [];
  for (const k of Object.keys(a)) {
    if (!(k in b)) problems.push(`key only in coder: ${k}=${JSON.stringify(a[k])}`);
    else if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) {
      problems.push(`value differs for ${k}: coder=${JSON.stringify(a[k])} coder-escalated=${JSON.stringify(b[k])}`);
    }
  }
  for (const k of Object.keys(b)) {
    if (!(k in a)) problems.push(`key only in coder-escalated: ${k}=${JSON.stringify(b[k])}`);
  }
  if (problems.length > 0) {
    console.error('FAIL  coder / coder-escalated permission lockstep broken (.opencode/opencode.jsonc):');
    for (const p of problems) console.error(`  - ${p}`);
    console.error('fix: keep coder-escalated permissions an exact clone of coder minus task-related keys');
    process.exit(1);
  }
  console.log(`ok: coder/coder-escalated permission lockstep (${Object.keys(a).length} keys compared, task-related ignored)`);
  process.exit(0);
}

try {
  parseJsonc(args[0]);
  process.exit(0);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
