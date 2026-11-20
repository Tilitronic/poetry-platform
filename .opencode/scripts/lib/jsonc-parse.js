// Shared JSONC handling for OpenCode config validators (make test-config).
//
// JSONC = JSON with // and /* */ comments plus trailing commas. Node's
// JSON.parse rejects all three, so we strip them with a small char-level
// tokenizer that respects string literals - naive regex stripping would
// corrupt URLs such as https://... inside the config.
//
// Usage:
//   node jsonc-parse.js <file>              exit 0 iff <file> parses as JSON(C)
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

// Dangerous-allow probe: shapes that execute arbitrary code OR write to an
// arbitrary path. The restriction probes alone under-classify -
// {"*":"deny","python3 *":"allow"} resolves BOTH probes to deny (no probe
// starts with python3) yet lets the lane run `python3 -c 'open(...,"w")'`,
// which is the write-scope hole this campaign exists to close (DIA-260827-ft3z
// C1). The same hole opens through any write primitive or shell-out the map
// allows: the researcher map this ticket was opened for kept both probes on
// deny while `curl -o /workspace/anything URL` resolved to allow behind its
// `curl *` grant (R1). A map resolving ANY of these to allow is unrestricted
// no matter what the probes say.
const DANGEROUS_EXECUTION_SHAPES = [
  // interpreter -c/-e forms
  "python3 -c 'x'",
  "python -c 'x'",
  "bash -c 'x'",
  "sh -c 'x'",
  "node -e '0'",
  "perl -e '0'",
  "ruby -e '0'",
  // write primitives: the output / install target is an arbitrary path
  "curl -o x http://x",
  "curl --output x http://x",
  "wget -O x http://x",
  // DIA-260827-ft3z design D7: the four remaining reproduced write modes of
  // the former fetch allow-list. Appended AFTER the curl -o entry on purpose:
  // allowedDangerousShape returns the FIRST shape that resolves to allow, and
  // the r1-curl bats case pins "curl -o x http://x" as the name for a `curl *`
  // map - inserting before it would silently change that assertion's text.
  "curl -O x",
  "wget -P x http://x",
  "trafilatura -o x",
  "crwl -o x",
  "tee x",
  "dd of=x",
  "sed -i x",
  "python3 -m pip install x",
  // shell-outs: the executed operand is arbitrary
  "find . -exec x",
  "xargs x",
  "awk 'BEGIN{system(\"x\")}'",
  "bun -e '0'",
  "deno eval '0'",
  "git -c core.pager=x log",
];

// First dangerous shape the map resolves to allow, else null. On the real tree
// this now returns null for every agent (the former researcher `curl *` allow
// is gone as of DIA-260827-ft3z design D1/D6); it still names any map that
// re-opens a write shape, which is what the invariant below reports.
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
// Asymmetry, tolerated on purpose: a nested-only deny ({"nested/**":"deny"}
// with no bare-name rule) counts as deny-scoped while a bare path stays
// allowed - the pair reads probe outcomes and never asserts both deny, which
// fails closed (the lane still has to carry a restricted bash) where the
// opposite reading would wave a nested-deny map with flat-allow bash through;
// the bare-path allowance itself is the edit matcher's glob semantics, outside
// this tripwire.
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
    // DIA-260827-ft3z design D7: shell-claim spellings that are false for any
    // lane whose bash is now deny-scoped (researcher lost its allow-list when
    // its capture chain moved to the typed fetch-source tool). All six were
    // checked against every scanned surface (agent md, slim prompt fields,
    // prompt-override md) before addition: they fire only on the researcher
    // documents this ticket rewrites, never on unrelated documentation.
    // `bash (allow-list` covers the no-backtick spelling of the claim that
    // `bash allow-list` alone would miss behind a code span.
    'bash allow-list',
    'bash (allow-list',
    'curl *',
    'wget *',
    'trafilatura *',
    'crwl *',
  ];
  // Same-line negation markers (M2b, bounded by R4): a line that negates the
  // claim before the phrase ("we do not run mmdc") is NOT a claim. Bounded on
  // two axes - word-boundary regexes, so `never` does not match "nevertheless"
  // and `not` does not match "cannot" (the `not` there is not word-initial);
  // and clause-scoped, so only the text between the last clause boundary
  // (". ", "; ", ": ") before the hit and the hit itself is examined - a
  // negation in an earlier clause cannot retract a later claim. Checked against
  // the text preceding the hit, so "mmdc is not available" still fires (the
  // negation comes after the phrase and does not retract it).
  const NEGATION_MARKERS = [/\bnot\b/, /\bnever\b/, /don't/, /\bdo not\b/];
  const CLAUSE_BOUNDARIES = ['. ', '; ', ': '];
  const clauseBefore = (text, idx) => {
    const prefix = text.slice(0, idx);
    let start = 0;
    for (const b of CLAUSE_BOUNDARIES) {
      const at = prefix.lastIndexOf(b);
      if (at >= 0 && at + b.length > start) start = at + b.length;
    }
    return prefix.slice(start);
  };
  const findForbidden = (line) => {
    const lower = line.toLowerCase();
    const hits = [];
    for (const phrase of FORBIDDEN) {
      const needle = phrase.toLowerCase();
      // Loop instead of a single indexOf: a line that claims the flat allow
      // twice must report BOTH occurrences, or the second claim survives the
      // fix that removed the first.
      for (let idx = lower.indexOf(needle); idx >= 0; idx = lower.indexOf(needle, idx + needle.length)) {
        // M2a/R3: read the REST of the word after the match. Only the four
        // allow-list spellings (`list`, `listed`, `-list`, `-listed`) name a
        // procedure rather than a claim - `bash: allowed` is a genuine
        // flat-allow claim and must fire, as must any other continuation.
        if (needle.endsWith('allow')) {
          const word = (lower.slice(idx + needle.length).match(/^[-\w]*/) || [''])[0];
          if (word === 'list' || word === 'listed' || word === '-list' || word === '-listed') continue;
        }
        // M2b/R4: the clause before the hit negates the phrase.
        if (NEGATION_MARKERS.some((re) => re.test(clauseBefore(lower, idx)))) continue;
        hits.push({ phrase: line.slice(idx, idx + phrase.length), at: idx });
      }
    }
    return hits;
  };
  const problems = [];
  // M2c/R5: a hit is attributed to the subject UNLESS the clause around it
  // labels a DIFFERENT configured agent - a routing-table line describing
  // another lane's grant is not a claim by the subject (a routing table is not
  // a claim by every lane it appears next to). Attribution is per HIT, never
  // per line: a line that both names another agent and makes its own claim
  // ("Unlike coder, this lane grants bash: allow") must still report the claim,
  // so only the individual hit is suppressed, and only when the label owns it.
  // Two spellings of that label: the text right before the hit ends with
  // `<name>:` (the hit directly follows the label), or the claim's clause
  // opens with `<name>:` (`coder: this lane grants bash: allow`). The subject
  // must not be named anywhere in that clause.
  const agentNames = Object.keys(cfg.agent || {});
  const namesAgent = (line, name) => {
    const hay = line.toLowerCase();
    const needle = name.toLowerCase();
    let at = hay.indexOf(needle);
    while (at >= 0) {
      const before = hay[at - 1];
      const after = hay[at + needle.length];
      // Word boundary on both sides, '-' included so a shorter name does not
      // count as a mention inside a longer hyphenated name starting with it.
      const open = before === undefined || !/[-\w]/.test(before);
      const close = after === undefined || !/[-\w]/.test(after);
      if (open && close) return true;
      at = hay.indexOf(needle, at + 1);
    }
    return false;
  };
  // The claim's clause around a hit at index `at`: split on ". " and "; " only
  // - a ": " does NOT start a new clause, because a label and its claim share
  // one clause (`coder: bash: allow` is a single labelled claim).
  const claimClause = (line, at) => {
    let start = 0;
    for (const b of ['. ', '; ']) {
      const p = line.lastIndexOf(b, at);
      if (p >= 0 && p + b.length > start) start = p + b.length;
    }
    let end = line.length;
    for (const b of ['. ', '; ']) {
      const p = line.indexOf(b, at);
      if (p >= 0 && p < end) end = p;
    }
    return line.slice(start, end);
  };
  const attributedHit = (line, at, subject) => {
    const prefix = line.slice(0, at);
    const clause = claimClause(line, at);
    const labelledByOther = agentNames.some(
      (n) =>
        n !== subject &&
        (prefix.trimEnd().toLowerCase().endsWith(n.toLowerCase() + ':') ||
          clause.toLowerCase().startsWith(n.toLowerCase() + ':'))
    );
    return labelledByOther && !namesAgent(clause, subject);
  };
  // Line-scanned surfaces. Every hit is resolved against its own line so the
  // negation rule (M2b/R4) and, for prompt fields, the per-hit attribution
  // rule (M2c/R5) apply; files report their line number, prompt fields their
  // field path. No line is ever dropped wholesale - only an individual hit that
  // another agent's label owns is suppressed.
  const scanLines = (subject, label, text, attribute = false) => {
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      for (const hit of findForbidden(lines[i])) {
        if (attribute && attributedHit(lines[i], hit.at, subject)) continue;
        problems.push(`${subject}: ${label}:${i + 1}: forbidden phrase "${hit.phrase}"`);
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

  // G3.6 positive invariant, scoped to the analyzer agent only: its document
  // is the one the deny-first contract is written into, and asserting it on
  // every in-scope agent would only add noise. The markdown is a REQUIRED
  // surface (M3): a missing file used to `continue` silently, so deleting the
  // document removed the requirement. Negative phrase scans above stay
  // skip-on-absent (no file, no claim); this positive check does not.
  for (const name of ['analyzer']) {
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
  // below is the known tracked debt; it stays EXPLICIT (one named agent per
  // tracking ticket, each entry naming what it can still run) so the debt is
  // visible in review and a NEW agent appearing in this state fails loudly.
  //
  // EMPTY BY DESIGN since DIA-260827-ft3z design D6: the last two members are
  // gone. researcher went flat "bash": "deny" (its capture chain runs through
  // the typed fetch-source tool) and memory-manager got a deny-first map whose
  // grants are read-only git plus the shelf validator, so both lanes now pass
  // the invariant on their own config. Do not re-add a member to silence a
  // firing invariant - fix the lane's bash map instead. An agent appearing in
  // the deny-scoped-edit / unrestricted-bash state now fails loudly, which is
  // the intended behaviour of an empty set.
  const EXEMPT_EDIT_BASH = new Set([]);
  // Same tracked debt, deliberately NOT exempt: designer. Its config block
  // (designer in .opencode/opencode.jsonc) cites DIA-261006-ldfs for the
  // original task closure and DIA-260827-ft3z design D6 for the bash deny.
  // designer's edit key is undeclared too, so edit inherits the global allow
  // and the invariant does not reach it today; leaving it covered means the
  // gate fires the day its edit becomes deny-scoped without a deny-scoped
  // bash.
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
