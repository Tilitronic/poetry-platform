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
//                                           every pair member must be present
//                                           with a non-empty permission map
//                                           first (no vacuous green);
//                                           exit 1 + diff on drift
//   node jsonc-parse.js --doc-drift <file>  bash-RESTRICTED agents (resolved
//                                           semantically, not by key order)
//                                           must not claim a flat allow in any
//                                           of their doc surfaces, and an agent
//                                           whose edit is deny-scoped must not
//                                           carry an unrestricted bash map;
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

// --- semantic permission helpers (DIA-260827-ft3z G2) ------------------------
// OpenCode resolves a permission map with findLast over the merged rule list
// (global rules first, agent rules appended), so the decision for a command is
// "the LAST matching rule wins" - key order inside a JSON object is what
// carries that. A predicate that only inspects Object.keys()[0] therefore
// mis-reads any map whose catch-all is not the first key, and skips maps that
// are effectively flat-allow. These helpers resolve a probe command instead of
// inspecting key position. Matcher semantics (anchored whole-value, `*` = any
// run of characters) mirror packages/opencode/src/util/wildcard.ts as recorded
// in .opencode/learnings/external-patterns/2026-11-01-opencode-permission-resolver-findlast-and-deny-first-maps.md.
function wildcardMatch(pattern, value) {
  let source = '';
  for (const ch of pattern) {
    source += ch === '*' ? '[\\s\\S]*' : ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp('^' + source + '$').test(value);
}

// Last matching rule wins (findLast). undefined when nothing matches.
function resolveRule(map, probe) {
  let last;
  for (const key of Object.keys(map)) {
    if (wildcardMatch(key, probe)) last = map[key];
  }
  return last;
}

// Two probes no legitimate allow pattern targets. Two rather than one so a map
// that allows a probe-shaped command is caught from the other direction too.
const RESTRICTION_PROBES = ['__dia_probe_denied__', 'zzz_nonexistent_cmd --flag'];

// Deny-by-default probe: EVERY restriction probe resolves to deny. A flat
// "deny" passes, a flat "allow" does not, and a map whose last match for a
// probe is allow does not. This alone is NOT enough to call a map restricted -
// see the dangerous-allow probe below.
function isDenyByDefault(bash) {
  if (typeof bash === 'string') return bash === 'deny';
  if (bash === null || typeof bash !== 'object' || Array.isArray(bash)) return false;
  return RESTRICTION_PROBES.every((probe) => resolveRule(bash, probe) === 'deny');
}

// Dangerous-allow probe: shapes that execute arbitrary code. The restriction
// probes alone under-classify - {"*":"deny","python3 *":"allow"} resolves BOTH
// probes to deny (no probe starts with python3) yet lets the lane run
// `python3 -c 'open(...,"w")'`, which is the write-scope hole this campaign
// exists to close (DIA-260827-ft3z C1). A map resolving ANY of these to allow
// is unrestricted no matter what the probes say.
const DANGEROUS_EXECUTION_SHAPES = [
  "python3 -c 'x'",
  "python -c 'x'",
  "bash -c 'x'",
  "sh -c 'x'",
  "node -e '0'",
  "perl -e '0'",
  "ruby -e '0'",
];

// First dangerous shape the map resolves to allow, else null. The real analyzer
// map allows only `python3 .opencode/scripts/query_rag.py *`, which is anchored
// to a fixed script path and matches none of these shapes, so the gate stays
// green on the current config.
function allowedDangerousShape(bash) {
  if (bash === null || typeof bash !== 'object' || Array.isArray(bash)) return null;
  return DANGEROUS_EXECUTION_SHAPES.find((shape) => resolveRule(bash, shape) === 'allow') || null;
}

// bash is restricted iff it is deny-by-default AND no dangerous execution
// shape resolves to allow.
function isBashRestricted(bash) {
  return isDenyByDefault(bash) && allowedDangerousShape(bash) === null;
}

// Edit-side probes are PATH-shaped (a bare name plus a nested path), unlike the
// command-shaped bash probes: a path-only deny map ({"**/*":"deny"}) matches
// neither command probe, so the old command probe skipped exactly the
// deny-scoped edit maps this invariant exists to catch (DIA-260827-ft3z M1).
// Deny-scoped = at least one path probe resolves deny AND neither resolves
// allow - the first keeps path-only catch-alls in, the second keeps any map
// that grants an arbitrary path out.
const EDIT_PATH_PROBES = ['dia_edit_probe', 'nested/dir/dia_edit_probe'];

function isDenyScoped(edit) {
  if (typeof edit === 'string') return edit === 'deny';
  if (edit === null || typeof edit !== 'object' || Array.isArray(edit)) return false;
  const resolved = EDIT_PATH_PROBES.map((probe) => resolveRule(edit, probe));
  return resolved.includes('deny') && !resolved.includes('allow');
}

// Effective permission value: an UNDECLARED agent key has no agent rule at all,
// so it resolves through the global block (agent rules are appended AFTER
// global rules) - "no bash key" inherits the global bash map, "no edit key"
// inherits the global edit baseline.
function effectivePermission(agentPermission, globalPermission, key) {
  const declared = agentPermission ? agentPermission[key] : undefined;
  return declared !== undefined ? declared : (globalPermission || {})[key];
}

// Each top-level permission key expands to leaf rules: a string is one rule, an
// object contributes its own entries (recursed), an array its items. The
// lockstep success line reports both numbers so a ten-rule bash map cannot hide
// behind a "3 keys compared" count.
function countLeafRules(value) {
  if (value === null || typeof value !== 'object') return 1;
  if (Array.isArray(value)) return value.reduce((n, v) => n + countLeafRules(v), 0);
  return Object.values(value).reduce((n, v) => n + countLeafRules(v), 0);
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
    const pairProblems = [];
    let a = null;
    let b = null;
    // G1: a missing or empty member used to pick an empty object for BOTH
    // sides, so the comparison below saw nothing and still printed a green
    // line - a green gate with zero coverage is worse than no gate. Every
    // member must be present with a non-empty, post-exemption permission map
    // before anything is compared, and each failure names the pair member.
    const members = [
      { role: pair.base, agent: agents[pair.base], picked: 'a' },
      { role: pair.esc, agent: agents[pair.esc], picked: 'b' },
    ];
    for (const member of members) {
      const perm = member.agent && member.agent.permission;
      if (!member.agent || typeof member.agent !== 'object') {
        pairProblems.push(
          `pair ${pair.base}/${pair.esc}: missing member "${member.role}" (agent not configured)`
        );
      } else if (!perm || typeof perm !== 'object' || Array.isArray(perm)) {
        pairProblems.push(
          `pair ${pair.base}/${pair.esc}: member "${member.role}" has no permission object`
        );
      } else if (Object.keys(perm).length === 0) {
        pairProblems.push(
          `pair ${pair.base}/${pair.esc}: member "${member.role}" has an empty permission object`
        );
      } else {
        const picked = pick(perm, pair.exempt);
        if (Object.keys(picked).length === 0) {
          pairProblems.push(
            `pair ${pair.base}/${pair.esc}: member "${member.role}" has no comparable permission keys left after exemptions`
          );
        } else if (countLeafRules(picked) === 0) {
          // M4: {"bash":{}} has a key but carries no rule, so the comparison
          // below would green on "1 keys, 0 rules" - zero rule coverage.
          pairProblems.push(
            `pair ${pair.base}/${pair.esc}: member "${member.role}" has 0 leaf rules (an empty permission key such as "bash": {} carries no rule)`
          );
        } else if (member.picked === 'a') {
          a = picked;
        } else {
          b = picked;
        }
      }
    }
    if (pairProblems.length === 0) {
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
    }
    if (pairProblems.length > 0) {
      failures.push(`FAIL  ${pair.base} / ${pair.esc} permission lockstep broken (${args[1]}):`);
      for (const p of pairProblems) failures.push(`  - ${p}`);
      failures.push(`fix: ${pair.fix}`);
    } else {
      // Honest depth: top-level keys AND the leaf rules beneath them, plus the
      // agent names actually compared - "3 keys" hides a twenty-rule bash map.
      const keys = Object.keys(a).length;
      const rules = Object.values(a).reduce((n, v) => n + countLeafRules(v), 0);
      const note = pair.exempt.size > 0 ? ', task-related ignored' : '';
      successes.push(
        `ok: ${pair.base}/${pair.esc} permission lockstep (${keys} key${keys === 1 ? '' : 's'}, ${rules} rule${rules === 1 ? '' : 's'}${note}: ${pair.base}, ${pair.esc})`
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
  // DIA-260827-ft3z check B (widened by G2/G3 of the same ticket): an agent
  // whose bash is deny-scoped must not claim a flat allow in its docs. The
  // drift class appeared twice in one session (agent prose + preset prompt kept
  // "bash: allow" / "Mermaid CLI" after the config hardened the maps) and no
  // gate compared the surfaces. Two things are asserted here:
  //   1. scope + matching (G3) - an agent is IN SCOPE when its EFFECTIVE bash
  //      permission is deny-scoped, resolved semantically (see the helpers
  //      above) so a flat "deny" counts too, and every doc surface is scanned
  //      for every occurrence of every forbidden phrase;
  //   2. the edit/bash invariant (G2) - an agent whose edit is deny-scoped may
  //      not run on an unrestricted bash map.
  // This is a tripwire, not a full prose-vs-token parity check.
  const cfg = parseJsonc(args[1]);
  const dir = path.dirname(args[1]);
  // Tripwire phrase list with a KNOWN PARAPHRASE CEILING: it catches the
  // spellings that actually appeared in review, nothing more. "shell is open",
  // "no command restrictions" and the like walk straight past it - closing that
  // ceiling needs semantic prose-vs-config comparison, which is deliberately
  // out of scope for a config gate. Extend the list when a new spelling of the
  // same claim is seen.
  const FORBIDDEN = [
    'bash: allow',
    'bash: fully allowed',
    'Mermaid CLI',
    'bash (allow)',
    'bash is allowed',
    'mmdc',
  ];
  // Same-line negation markers (M2b): a line that negates the claim before the
  // phrase ("we do not run mmdc") is NOT a claim. Checked against the line text
  // preceding the hit, so "mmdc is not available" still fires (the negation
  // comes after the phrase and does not retract it).
  const NEGATION_MARKERS = ['not ', 'never', "don't", 'do not'];
  const findForbidden = (line) => {
    const lower = line.toLowerCase();
    const hits = [];
    for (const phrase of FORBIDDEN) {
      const needle = phrase.toLowerCase();
      // Loop instead of a single indexOf: a line that claims the flat allow
      // twice must report BOTH occurrences, or the second claim survives the
      // fix that removed the first.
      for (let idx = lower.indexOf(needle); idx >= 0; idx = lower.indexOf(needle, idx + needle.length)) {
        // M2a: `bash: allow` must not fire on `bash: allow-list` /
        // `bash: allowlisted` - require a word boundary after a phrase that
        // ends in the bare word "allow" (next char not -, not word char).
        if (needle.endsWith('allow')) {
          const after = lower[idx + needle.length];
          if (after !== undefined && /[-\w]/.test(after)) continue;
        }
        // M2b: the same line negates the phrase before it.
        if (NEGATION_MARKERS.some((m) => lower.slice(0, idx).includes(m))) continue;
        hits.push(line.slice(idx, idx + phrase.length));
      }
    }
    return hits;
  };
  const problems = [];
  // M2c: prompt fields are scanned LINE BY LINE (they used to be one blob, so
  // a hit could not be attributed to its line), and a hit on a line that names
  // a DIFFERENT configured agent - without naming the subject - describes that
  // other lane's grant and must not be attributed to the restricted subject
  // (a routing table is not a claim by every lane it appears next to).
  const agentNames = Object.keys(cfg.agent || {});
  const namesAgent = (line, name) => {
    const hay = line.toLowerCase();
    const needle = name.toLowerCase();
    let at = hay.indexOf(needle);
    while (at >= 0) {
      const before = hay[at - 1];
      const after = hay[at + needle.length];
      // Word boundary on both sides, '-' included so `analyzer` does not count
      // as a mention inside `analyzer-escalated`.
      const open = before === undefined || !/[-\w]/.test(before);
      const close = after === undefined || !/[-\w]/.test(after);
      if (open && close) return true;
      at = hay.indexOf(needle, at + 1);
    }
    return false;
  };
  const attributedToOtherAgent = (line, subject) =>
    agentNames.some((n) => n !== subject && namesAgent(line, n)) && !namesAgent(line, subject);
  // Line-scanned surfaces. Every hit is resolved against its own line so the
  // negation rule (M2b) and, for prompt fields, the attribution rule (M2c)
  // apply; files report their line number, prompt fields their field path.
  const scanLines = (subject, label, text, attribute = false) => {
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      if (attribute && attributedToOtherAgent(lines[i], subject)) continue;
      for (const hit of findForbidden(lines[i])) {
        problems.push(`${subject}: ${label}:${i + 1}: forbidden phrase "${hit}"`);
      }
    }
  };
  const inScope = [];
  // MINOR: parse the slim config ONCE before the per-agent loop instead of
  // re-reading and re-parsing the same file for every in-scope agent.
  const slimFile = path.join(dir, 'oh-my-opencode-slim.jsonc');
  const slim = fs.existsSync(slimFile) ? parseJsonc(slimFile) : null;
  for (const name of Object.keys(cfg.agent || {})) {
    const agent = cfg.agent[name] || {};
    const perm = agent.permission || {};
    // G3.1/G2: scope is the SEMANTIC predicate, so the flat-"deny" agents
    // (MORE restrictive than a deny-first object) are checked too - their docs
    // must not claim an allow either.
    if (!isBashRestricted(effectivePermission(perm, cfg.permission, 'bash'))) continue;
    inScope.push(name);

    const mdFile = path.join(dir, 'agents', name + '.md');
    if (fs.existsSync(mdFile)) scanLines(name, mdFile, fs.readFileSync(mdFile, 'utf8'));

    if (slim) {
      const sites = [];
      const agentsBlock = slim.agents || {};
      const agentEntry = agentsBlock[name];
      if (agentEntry && typeof agentEntry.orchestratorPrompt === 'string') {
        sites.push({ loc: `agents.${name}.orchestratorPrompt`, text: agentEntry.orchestratorPrompt });
      }
      // G3.2: `.prompt` is the other injected prompt field - same drift class,
      // previously unscanned.
      if (agentEntry && typeof agentEntry.prompt === 'string') {
        sites.push({ loc: `agents.${name}.prompt`, text: agentEntry.prompt });
      }
      const presets = slim.presets || {};
      for (const pname of Object.keys(presets)) {
        const entry = presets[pname] && presets[pname][name];
        if (!entry) continue;
        if (typeof entry.orchestratorPrompt === 'string') {
          sites.push({ loc: `presets.${pname}.${name}.orchestratorPrompt`, text: entry.orchestratorPrompt });
        }
        if (typeof entry.prompt === 'string') {
          sites.push({ loc: `presets.${pname}.${name}.prompt`, text: entry.prompt });
        }
      }
      for (const site of sites) scanLines(name, `${slimFile} ${site.loc}`, site.text, true);
    }

    // G3.3: the live prompt-override files are injected at runtime and were
    // never scanned at all. Only files that exist are read - the override layer
    // is a fixed contract enforced by scripts/check-omo-version-sync.sh.
    const promptDir = path.join(dir, 'oh-my-opencode-slim');
    for (const suffix of ['.md', '_append.md']) {
      const promptFile = path.join(promptDir, name + suffix);
      if (fs.existsSync(promptFile)) scanLines(name, promptFile, fs.readFileSync(promptFile, 'utf8'));
    }
  }

  // G3.6 positive invariant, scoped to the analyzer pair only: their documents
  // are the ones the deny-first contract is written into, and asserting it on
  // every in-scope agent would only add noise. The markdown is a REQUIRED
  // surface (M3): a missing file used to `continue` silently, so deleting the
  // document removed the requirement. Negative phrase scans above stay
  // skip-on-absent (no file, no claim); this positive check does not.
  for (const name of ['analyzer', 'analyzer-escalated']) {
    const mdFile = path.join(dir, 'agents', name + '.md');
    if (!fs.existsSync(mdFile)) {
      problems.push(
        `${name}: required agent document missing: ${mdFile} (the agent markdown must state the deny-first bash contract)`
      );
      continue;
    }
    if (!fs.readFileSync(mdFile, 'utf8').includes('deny-first')) {
      problems.push(
        `${name}: ${mdFile}: missing required "deny-first" marker (the agent document must state the deny-first bash contract)`
      );
    }
  }

  // G2 invariant: an agent whose EDIT is deny-scoped must not run on an
  // unrestricted bash map - that is the campaign's actual failure mode, an
  // edit-scoped lane whose shell can still write anywhere. The exemption set
  // below is the known tracked debt; it stays EXPLICIT (one named agent, one
  // ticket) so the debt is visible in review and a NEW agent appearing in this
  // state fails loudly.
  const EXEMPT_EDIT_BASH = new Set([
    // memory-manager: edit is deny-first, the bash key is ABSENT so it
    // inherits the global `"*": "allow"` baseline (verified with
    // `opencode debug agent memory-manager`).
    'memory-manager',
  ]);
  // Same tracked debt, deliberately NOT exempt: designer. Its config comment in
  // .opencode/opencode.jsonc ("designer bash gap is a DEFERRED drift routed to
  // the follow-up ticket" - the block that sat at line 621 when this gate was
  // written) cites DIA-261006-ldfs. designer's edit key is undeclared too, so
  // edit inherits the global allow and the invariant does not reach it today;
  // leaving it covered means the gate fires the day its edit becomes
  // deny-scoped without a deny-scoped bash.
  const invariantFailures = [];
  for (const name of Object.keys(cfg.agent || {})) {
    if (EXEMPT_EDIT_BASH.has(name)) continue;
    const perm = (cfg.agent[name] || {}).permission || {};
    const edit = effectivePermission(perm, cfg.permission, 'edit');
    const bash = effectivePermission(perm, cfg.permission, 'bash');
    if (isDenyScoped(edit) && !isBashRestricted(bash)) {
      // C1: when the map is deny-by-default but still allows a dangerous
      // execution shape, name the shape - "bash is not" alone hides WHICH
      // grant reopens the write-scope hole.
      const shape = isDenyByDefault(bash) ? allowedDangerousShape(bash) : null;
      const why = shape
        ? `bash is deny-by-default but allows the dangerous execution shape "${shape}"`
        : 'bash resolves to allow for an arbitrary command';
      invariantFailures.push(`${name}: edit is deny-scoped but bash is not (${why})`);
    }
  }

  if (problems.length > 0) {
    console.error(`FAIL  deny-first doc contract drift (${args[1]}):`);
    for (const p of problems) console.error(`  - ${p}`);
    console.error('fix: remove the flat-allow claim from the deny-first agent docs (config is ground truth)');
  }
  if (invariantFailures.length > 0) {
    console.error(`FAIL  deny-scoped edit with unrestricted bash (${args[1]}):`);
    for (const p of invariantFailures) console.error(`  - ${p}`);
    console.error(
      'fix: give the agent a deny-scoped bash map (flat "deny" or a deny-first object), or add it to the exemption set next to its tracking ticket'
    );
  }
  if (problems.length > 0 || invariantFailures.length > 0) process.exit(1);
  console.log(
    `ok: deny-first doc contract (${inScope.length} in-scope agents: ${inScope.join(', ')}, no flat-allow claims)`
  );
  process.exit(0);
}

try {
  parseJsonc(args[0]);
  process.exit(0);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
