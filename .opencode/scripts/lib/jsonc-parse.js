// Shared JSONC handling for OpenCode config validators (make test-config).
//
// JSONC = JSON with // and /* */ comments plus trailing commas. Node's
// JSON.parse rejects all three, so we strip them with a small char-level
// tokenizer that respects string literals - naive regex stripping would
// corrupt URLs such as https://... inside the config.
//
// Usage:
//   node jsonc-parse.js <file>              exit 0 iff <file> parses as JSON(C)
//   node jsonc-parse.js --lockstep <file>   compare the coder and analyzer
//                                           base/escalated permission maps;
//                                           exit 1 + diff on drift
//   node jsonc-parse.js --doc-drift <file>  deny-first bash-map agents must not
//                                           claim a flat allow in their docs
//                                           (agents/<name>.md + the agent's
//                                           orchestratorPrompt in
//                                           oh-my-opencode-slim.jsonc);
//                                           exit 1 + diff on drift
'use strict';
const fs = require('fs');
const path = require('path');

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

// Deepest dotted path inside two values that JSON.stringify-differ. Order-
// sensitive (JSON.stringify), mirroring the F2 lockstep comparison semantics;
// a key-order-only divergence reports the container path whose order differs.
function firstDiffPath(a, b, prefix) {
  if (JSON.stringify(a) === JSON.stringify(b)) return null;
  if (a === null || typeof a !== 'object' || b === null || typeof b !== 'object') {
    return prefix;
  }
  const keys = Array.from(new Set(Object.keys(a).concat(Object.keys(b))));
  for (const k of keys) {
    const p = prefix + '.' + k;
    if (!(k in a) || !(k in b) || JSON.stringify(a[k]) !== JSON.stringify(b[k])) {
      return firstDiffPath(a[k], b[k], p) || p;
    }
  }
  return prefix;
}

if (args[0] === '--lockstep') {
  // DIA-260825-nts7 fix-all batch F2: coder-escalated is documented as an
  // EXACT clone of the base coder permission map plus task-related keys, but
  // nothing enforced that - the maps already drifted once (reviewer finding).
  // DIA-260827-ft3z check A extends the same gate to the analyzer pair:
  // analyzer-escalated is documented as an exact clone of base analyzer, and
  // the two maps could diverge with nothing noticing. One comparison, deep-
  // equal on every permission key except the per-pair exemptions:
  //   coder pair      - task-related keys exempt (the escalated lane denies
  //                     delegation by design; base coder carries no task key
  //                     of its own to compare against).
  //   analyzer pair   - NO exemption: both lanes already carry task:"deny"
  //                     (base analyzer denies task), so the keys are equal;
  //                     exempting them would only mask a future divergence.
  const cfg = parseJsonc(args[1]);
  const agents = cfg.agent || {};
  const pick = (perm, exempt) => {
    const out = {};
    for (const k of Object.keys(perm || {}).sort()) {
      if (!exempt.has(k)) out[k] = perm[k];
    }
    return out;
  };
  const PAIRS = [
    {
      base: 'coder',
      esc: 'coder-escalated',
      exempt: new Set(['task']), // escalated lane adds task:"deny" by design
      fix: 'keep coder-escalated permissions an exact clone of coder minus task-related keys',
    },
    {
      base: 'analyzer',
      esc: 'analyzer-escalated',
      exempt: new Set(),
      fix: 'keep analyzer-escalated permissions an exact clone of analyzer',
    },
  ];
  const failures = [];
  const successes = [];
  for (const pair of PAIRS) {
    const a = pick((agents[pair.base] || {}).permission, pair.exempt);
    const b = pick((agents[pair.esc] || {}).permission, pair.exempt);
    const pairProblems = [];
    for (const k of Object.keys(a)) {
      if (!(k in b)) {
        pairProblems.push(`key only in ${pair.base}: ${k}=${JSON.stringify(a[k])}`);
      } else if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) {
        const where = firstDiffPath(a[k], b[k], k) || k;
        pairProblems.push(
          `value differs at ${where}: ${pair.base}=${JSON.stringify(a[k])} ${pair.esc}=${JSON.stringify(b[k])}`
        );
      }
    }
    for (const k of Object.keys(b)) {
      if (!(k in a)) {
        pairProblems.push(`key only in ${pair.esc}: ${k}=${JSON.stringify(b[k])}`);
      }
    }
    if (pairProblems.length > 0) {
      failures.push(`FAIL  ${pair.base} / ${pair.esc} permission lockstep broken (${args[1]}):`);
      for (const p of pairProblems) failures.push(`  - ${p}`);
      failures.push(`fix: ${pair.fix}`);
    } else {
      const note = pair.exempt.size > 0 ? 'task-related ignored' : 'no exemptions';
      successes.push(
        `ok: ${pair.base}/${pair.esc} permission lockstep (${Object.keys(a).length} keys compared, ${note})`
      );
    }
  }
  if (failures.length > 0) {
    for (const line of failures) console.error(line);
    process.exit(1);
  }
  for (const line of successes) console.log(line);
  process.exit(0);
}

if (args[0] === '--doc-drift') {
  // DIA-260827-ft3z check B: a deny-first bash map means the agent docs must
  // not claim a flat allow. The drift class appeared twice in one session
  // (agent prose + preset prompt kept "bash: allow" / "Mermaid CLI" after the
  // config hardened the maps) and no gate compared the surfaces. Scope:
  // agents whose configured bash permission is an OBJECT whose FIRST rule is
  // the catch-all deny. This is a drift invariant, not a full prose-vs-token
  // parity check - only these three forbidden claims are asserted.
  const cfg = parseJsonc(args[1]);
  const dir = path.dirname(args[1]);
  const FORBIDDEN = ['bash: allow', 'bash: fully allowed', 'Mermaid CLI'];
  const findForbidden = (text) => {
    const lower = text.toLowerCase();
    const hits = [];
    for (const phrase of FORBIDDEN) {
      const idx = lower.indexOf(phrase.toLowerCase());
      if (idx >= 0) hits.push(text.slice(idx, idx + phrase.length));
    }
    return hits;
  };
  const problems = [];
  let checked = 0;
  for (const name of Object.keys(cfg.agent || {})) {
    const agent = cfg.agent[name] || {};
    const bash = (agent.permission || {}).bash;
    if (!bash || typeof bash !== 'object' || Array.isArray(bash)) continue;
    const bashKeys = Object.keys(bash);
    if (bashKeys.length === 0 || bashKeys[0] !== '*' || bash['*'] !== 'deny') continue;
    checked += 1;
    const mdFile = path.join(dir, 'agents', name + '.md');
    if (fs.existsSync(mdFile)) {
      const lines = fs.readFileSync(mdFile, 'utf8').split(/\r?\n/);
      for (let i = 0; i < lines.length; i++) {
        for (const hit of findForbidden(lines[i])) {
          problems.push(`${name}: ${mdFile}:${i + 1}: forbidden phrase "${hit}"`);
        }
      }
    }
    const slimFile = path.join(dir, 'oh-my-opencode-slim.jsonc');
    if (fs.existsSync(slimFile)) {
      const slim = parseJsonc(slimFile);
      const sites = [];
      const agentsBlock = slim.agents || {};
      if (agentsBlock[name] && typeof agentsBlock[name].orchestratorPrompt === 'string') {
        sites.push({ loc: `agents.${name}.orchestratorPrompt`, text: agentsBlock[name].orchestratorPrompt });
      }
      const presets = slim.presets || {};
      for (const pname of Object.keys(presets)) {
        const entry = presets[pname] && presets[pname][name];
        if (entry && typeof entry.orchestratorPrompt === 'string') {
          sites.push({ loc: `presets.${pname}.${name}.orchestratorPrompt`, text: entry.orchestratorPrompt });
        }
      }
      for (const site of sites) {
        for (const hit of findForbidden(site.text)) {
          problems.push(`${name}: ${slimFile} ${site.loc}: forbidden phrase "${hit}"`);
        }
      }
    }
  }
  if (problems.length > 0) {
    console.error(`FAIL  deny-first doc contract drift (${args[1]}):`);
    for (const p of problems) console.error(`  - ${p}`);
    console.error('fix: remove the flat-allow claim from the deny-first agent docs (config is ground truth)');
    process.exit(1);
  }
  console.log(`ok: deny-first doc contract (${checked} deny-first agents, no flat-allow claims)`);
  process.exit(0);
}

try {
  parseJsonc(args[0]);
  process.exit(0);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
