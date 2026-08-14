#!/usr/bin/env node
/**
 * DIA-174 slice S2: persistent behavioral test suite for batch-D infra
 * hardening.
 *
 * Consolidates the DIA-172-era plugin/config assertions (which previously
 * lived in throwaway /tmp suites) plus the new DIA-174 targets (S3/S4
 * directive text, Makefile wiring).
 *
 * TRACKED since DIA-176 F2 (previously gitignored per design.md DD2; the
 * session-local-reconstruction rationale did not hold - the suite asserts
 * committed files only, so a fresh clone must be able to run it). Recreate
 * or regenerate the suite when the plugin/config invariants evolve.
 * The Makefile test-config wiring is the S2 GREEN phase (asserted RED in
 * section 3 below).
 *
 * Plain node ESM, zero npm deps. The only external bit is esbuild, invoked
 * as a subprocess to bundle the REAL delegation-observer plugin (which has
 * zero named exports) plus an export footer, mirroring the DIA-172
 * throwaway approach. NODE_PATH points at the OMO node_modules so the
 * @opencode-ai/plugin import resolves from any TEST_ROOT (worktrees have no
 * node_modules).
 *
 * Run: TEST_ROOT=/workspace node scripts/__tests__/batch-d-infra.test.mjs
 *   TEST_ROOT defaults to /workspace; every file assertion resolves against
 *   it, so the same suite runs against the main tree or a worktree.
 *
 * Sections:
 *   1. PLUGIN CLASSIFICATION (batch D, post-DIA-172) - GREEN now
 *   2. CONFIG DRIFT (post-DIA-172)                   - GREEN now
 *   3. STRUCTURAL CHECKS (.sdd ADR invariants, DD5)  - GREEN now
 *   4. NEW DIA-174 TARGETS (S3/S4/Makefile wiring)   - RED until S3/S4 land
 *   5. DIA-139 SLICE C (F-3 single rebuild)          - GREEN since 795750b
 *   6. DIA-139 SLICE B (F-2 turbo default flip)      - GREEN since 6cf2db9
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const TEST_ROOT = process.env.TEST_ROOT || '/workspace';
const ESBUILD_BIN = process.env.ESBUILD_BIN || '/workspace/node_modules/.bin/esbuild';
const OMO_NODE_MODULES = process.env.OMO_NODE_MODULES || '/workspace/.opencode/node_modules';

const readRoot = (rel) => readFileSync(join(TEST_ROOT, rel), 'utf8');

/** Minimal JSONC comment stripper - respects string literals and escapes. */
function stripJsonc(src) {
  let out = '';
  let inStr = false;
  let i = 0;
  while (i < src.length) {
    const ch = src[i];
    const next = src[i + 1];
    if (inStr) {
      out += ch;
      if (ch === '\\') {
        out += next ?? '';
        i += 2;
        continue;
      }
      if (ch === '"') inStr = false;
      i += 1;
      continue;
    }
    if (ch === '"') {
      inStr = true;
      out += ch;
      i += 1;
      continue;
    }
    if (ch === '/' && next === '/') {
      while (i < src.length && src[i] !== '\n') i += 1;
      continue;
    }
    if (ch === '/' && next === '*') {
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i += 1;
      i += 2;
      continue;
    }
    out += ch;
    i += 1;
  }
  return out;
}

const parseJsonc = (rel) => JSON.parse(stripJsonc(readRoot(rel)));

// Shared fixtures (read once so every section asserts the same snapshot).
const opencodeConfig = parseJsonc('.opencode/opencode.jsonc');
const omoConfig = parseJsonc('.opencode/oh-my-opencode-slim.jsonc');
const presetPrompts = Object.values(omoConfig.presets)
  .map((p) => (p.orchestrator ? p.orchestrator.prompt : undefined))
  .filter(Boolean);
const orchAppend = readRoot('.opencode/oh-my-opencode-slim/orchestrator_append.md');
const coderAppend = readRoot('.opencode/oh-my-opencode-slim/coder_append.md');
const agentsMd = readRoot('AGENTS.md');
const makefile = readRoot('Makefile');
const turbo = parseJsonc('turbo.json');

// A1 NEVER clause: presets carry it as one JSON string line; the A1 section
// wraps it across md lines. Whitespace normalization before compare is
// intentional - the lockstep invariant is semantic byte-identity, not layout.
// The clause ends at the ".yaml" filename's trailing sentence period, so the
// regex spans to "yaml." (a naive /[^.]*\./ would stop inside the filename).
const NEVER_CLAUSE = /NEVER batch:[\s\S]*?yaml\./;
const norm = (s) => (s === null ? null : s.replace(/\s+/g, ' ').trim());
const a1NeverClause = (orchAppend.match(NEVER_CLAUSE) || [null])[0];
const presetNeverClauses = presetPrompts.map((p) => (p.match(NEVER_CLAUSE) || [null])[0]);

// Makefile test-config recipe block: from the target line up to the next
// target definition (scoped so a reference to scripts/__tests__ elsewhere in
// the file - e.g. the bats wrapper at line ~112 - cannot false-pass).
function testConfigRecipe() {
  const lines = makefile.split('\n');
  const idx = lines.findIndex((l) => /^test-config:/.test(l));
  if (idx === -1) return '';
  let end = idx + 1;
  while (end < lines.length && !/^[a-zA-Z0-9_.-]+:/.test(lines[end])) end += 1;
  return lines.slice(idx, end).join('\n');
}

// Makefile test-infra recipe block: same scoping as testConfigRecipe, so a
// reference to `docker compose up -d --build` in a comment above the target
// (or in the smoke script, which lives in a different file) cannot false-pass.
function testInfraRecipe() {
  const lines = makefile.split('\n');
  const idx = lines.findIndex((l) => /^test-infra:/.test(l));
  if (idx === -1) return '';
  let end = idx + 1;
  while (end < lines.length && !/^[a-zA-Z0-9_.-]+:/.test(lines[end])) end += 1;
  return lines.slice(idx, end).join('\n');
}

// ============================================================================
// S1 PLUGIN CLASSIFICATION (batch D, post-DIA-172) - GREEN now
// ============================================================================
describe('S1 PLUGIN CLASSIFICATION (batch D, post-DIA-172)', async () => {
  // Bundle the REAL plugin (zero named exports by design) with esbuild and an
  // export footer, exactly like the DIA-172 throwaway suite did.
  const tmpDir = mkdtempSync(join(tmpdir(), 'dia134-suite-'));
  process.on('exit', () => rmSync(tmpDir, { recursive: true, force: true }));
  const bundlePath = join(tmpDir, 'delegation-observer.bundle.mjs');
  execFileSync(
    ESBUILD_BIN,
    [
      join(TEST_ROOT, '.opencode/plugins/delegation-observer.ts'),
      '--bundle',
      '--platform=node',
      '--format=esm',
      `--outfile=${bundlePath}`,
      '--log-level=error',
    ],
    {
      env: { ...process.env, NODE_PATH: OMO_NODE_MODULES },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  appendFileSync(bundlePath, '\nexport { isSafeTaskBatch, READ_ONLY_LANES, WRITER_LANES }\n');
  const { isSafeTaskBatch, READ_ONLY_LANES } = await import(pathToFileURL(bundlePath).href);

  it('READ_ONLY_LANES includes architector (DIA-172 F5)', () => {
    assert.ok(READ_ONLY_LANES.has('architector'), 'architector must be read-only by config');
  });

  // DIA-172 tasks.md 5.1 cases (a)-(i), reconstructed from the spec.
  it('batch A: [architector, researcher] classified SAFE (read-only fan-out)', () => {
    assert.equal(isSafeTaskBatch([{ agent: 'architector' }, { agent: 'researcher' }]), true);
  });

  it('batch A: full read-only fan-out (all 6 lanes) classified SAFE', () => {
    const fanOut = [
      'researcher',
      'ai-specialist',
      'ai-auditor',
      'code-navigator',
      'observer',
      'architector',
    ].map((agent) => ({ agent }));
    assert.equal(isSafeTaskBatch(fanOut), true);
  });

  it('batch B: single writer + read-only reader classified SAFE', () => {
    assert.equal(isSafeTaskBatch([{ agent: 'analyzer' }, { agent: 'researcher' }]), true);
  });

  it('batch C: reviewer + ai-auditor pair classified SAFE (post-fix review)', () => {
    assert.equal(isSafeTaskBatch([{ agent: 'reviewer' }, { agent: 'ai-auditor' }]), true);
  });

  it('batch D: two coders with distinct worktrees classified SAFE', () => {
    assert.equal(
      isSafeTaskBatch([
        { agent: 'coder', worktree: '/workspace/.worktrees/feature-s1' },
        { agent: 'coder', worktree: '/workspace/.worktrees/feature-s2' },
      ]),
      true,
    );
  });

  it('batch D: two coders sharing one worktree classified UNSAFE', () => {
    assert.equal(
      isSafeTaskBatch([
        { agent: 'coder', worktree: '/workspace/.worktrees/feature-s1' },
        { agent: 'coder', worktree: '/workspace/.worktrees/feature-s1' },
      ]),
      false,
    );
  });

  it('batch D: two coders with missing worktrees classified UNSAFE', () => {
    assert.equal(isSafeTaskBatch([{ agent: 'coder' }, { agent: 'coder' }]), false);
  });

  it('batch D: coder + analyzer classified UNSAFE (analyzer is a writer lane)', () => {
    assert.equal(
      isSafeTaskBatch([
        { agent: 'coder', worktree: '/workspace/.worktrees/feature-s1' },
        { agent: 'analyzer' },
      ]),
      false,
    );
  });

  it('F4: singleton coder is not a batch shape - call-site guard prevents A1', () => {
    // A lone delegation satisfies no approved-batch predicate, so
    // isSafeTaskBatch returns false...
    assert.equal(
      isSafeTaskBatch([{ agent: 'coder', worktree: '/workspace/.worktrees/solo' }]),
      false,
    );
    // ...and the call site only runs A1 when the turn holds MORE than one
    // task() call (DIA-172 F4 singleton exemption - silent otherwise).
    // Structural pin on the REAL plugin source so dropping the guard fails.
    const src = readRoot('.opencode/plugins/delegation-observer.ts');
    assert.match(src, /taskCalls\.length > 1/, 'F4 singleton guard must gate the A1 check');
    assert.match(src, /F4 singleton exemption/, 'F4 exemption must be documented');
  });

  it("presets contain zero literal 'two coders' (wording is 'multiple @coder lanes')", () => {
    for (const p of presetPrompts) {
      assert.doesNotMatch(p, /two coders/i, "preset must not use 'two coders'");
    }
  });
});

// ============================================================================
// S2 CONFIG DRIFT (post-DIA-172) - GREEN now
// ============================================================================
describe('S2 CONFIG DRIFT (post-DIA-172)', () => {
  it('code-navigator has bash: deny', () => {
    assert.equal(opencodeConfig.agent['code-navigator'].permission.bash, 'deny');
  });

  it('observer has bash: deny', () => {
    assert.equal(opencodeConfig.agent['observer'].permission.bash, 'deny');
  });

  it('analyzer-escalated edit block grants no .opencode/ path (no memory-shelf.yaml)', () => {
    const edit = opencodeConfig.agent['analyzer-escalated'].permission.edit;
    assert.equal(edit['*'], 'deny');
    assert.equal(edit['knowledge/*'], 'allow');
    const keys = Object.keys(edit);
    assert.ok(
      !keys.some((k) => k.startsWith('.opencode')),
      'analyzer-escalated edit must stay scoped to knowledge/*',
    );
  });

  it('conspecter edit allow is knowledge/* only (agent md + opencode config agree)', () => {
    assert.match(readRoot('.opencode/agents/conspecter.md'), /knowledge\/\*/);
    const edit = opencodeConfig.agent['conspecter'].permission.edit;
    assert.deepEqual(Object.keys(edit).sort(), ['*', 'knowledge/*']);
    assert.equal(edit['*'], 'deny');
    assert.equal(edit['knowledge/*'], 'allow');
  });

  it('A1 NEVER clause byte-identical across A1 section and all presets (whitespace-normalized)', () => {
    assert.ok(a1NeverClause, 'A1 NEVER clause must exist in orchestrator_append.md');
    assert.ok(presetNeverClauses.length >= 1, 'preset prompts must carry a NEVER clause');
    assert.ok(presetNeverClauses.every(Boolean), 'every preset prompt must carry a NEVER clause');
    const normalized = [a1NeverClause, ...presetNeverClauses].map(norm);
    assert.equal(
      new Set(normalized).size,
      1,
      'A1 + preset NEVER clauses must agree after whitespace normalization',
    );
    assert.match(a1NeverClause, /memory-shelf\.yaml/, 'writer-pair ban must be covered');
  });

  it('A6 item 6 (per-worktree review + serialized squash-merge) is present', () => {
    assert.match(orchAppend, /parallel coders -> reviewer/);
    assert.match(orchAppend, /squash-merges to the main branch MUST be serialized/);
  });
});

// ============================================================================
// S2 STRUCTURAL CHECKS (DD5) - .sdd ADR invariants
// ============================================================================
describe('S2 STRUCTURAL CHECKS (.sdd ADR invariants, DD5)', () => {
  // DD5 structural class. First assertion: the DD1 husky-shim ADR. DD1's 'ADR
  // placement' note (design.md line 97) left the ADR unowned in the spec
  // ownership table, so S2 owns appending it to the dev-infra sdd; this
  // assertion stays RED until that ADR exists. Second: the DIA-172
  // opencode-config ADRs must stay intact (tasks.md 2.1 structural checks).
  it('.sdd/dev-infra/architecture.md contains the DD1 ADR (Worktree husky shim materialization)', () => {
    const sdd = readRoot('.sdd/dev-infra/architecture.md');
    assert.match(
      sdd,
      /### ADR \d+: Worktree husky shim materialization/i,
      'DD1 ADR heading must exist in the dev-infra sdd',
    );
    assert.match(sdd, /- \*\*Status:\*\* Accepted/, 'DD1 ADR must carry Status Accepted');
  });

  it('.sdd/opencode-config/architecture.md ADR 1 + ADR 2 intact (headings + Status Accepted)', () => {
    const sdd = readRoot('.sdd/opencode-config/architecture.md');
    // heading level differs across sdd docs (## vs ###) - match any level
    assert.match(sdd, /#{2,} ADR 1:/, 'ADR 1 heading must be intact');
    assert.match(sdd, /#{2,} ADR 2:/, 'ADR 2 heading must be intact');
    const accepted = (sdd.match(/- \*\*Status:\*\* Accepted/g) || []).length;
    assert.ok(accepted >= 2, 'both ADRs must carry Status Accepted (found ' + accepted + ')');
  });
});

// ============================================================================
// S3 NEW DIA-174 TARGETS - RED until S3/S4 land and the Makefile is wired
// ============================================================================
describe('S3 NEW DIA-174 TARGETS (RED now)', () => {
  // (a) Makefile wiring (S2 GREEN phase adds the step; AC 2.2)
  it('Makefile: test-config target exists', () => {
    assert.match(makefile, /^test-config:/m, 'test-config target must exist');
  });

  it('Makefile: test-config recipe references the S2 suite (batch-d-infra.test.mjs or scripts/__tests__)', () => {
    assert.match(
      testConfigRecipe(),
      /batch-d-infra\.test\.mjs|scripts\/__tests__/,
      'test-config must run the S2 suite',
    );
  });

  // (b) coder_append.md S3 branch-ownership model (S3 AC 3.1 required phrases)
  it('coder_append.md: "worktree base"', () => {
    assert.match(coderAppend, /worktree base/);
  });
  it('coder_append.md: "sibling branches own"', () => {
    assert.match(coderAppend, /sibling branches own/);
  });
  it('coder_append.md: "edit ONLY your assigned files"', () => {
    assert.match(coderAppend, /edit ONLY your assigned files/);
  });
  it('coder_append.md: "disjoint file sets"', () => {
    assert.match(coderAppend, /disjoint file sets/);
  });
  it('coder_append.md: payloads name the owned files per slice (S3 5th phrase)', () => {
    assert.match(coderAppend, /name the owned files/);
  });

  // (c) orchestrator_append.md S4 rules (S4 AC 4.1)
  // R1: ticket-ID token in every dispatch/resume prompt
  it('orchestrator_append.md R1: "every dispatch"', () => {
    assert.match(orchAppend, /every dispatch/);
  });
  it('orchestrator_append.md R1: "every resume prompt"', () => {
    assert.match(orchAppend, /every resume prompt/);
  });
  it('orchestrator_append.md R1: "literal ticket ID"', () => {
    assert.match(orchAppend, /literal ticket ID/);
  });
  it('orchestrator_append.md R1: "DIA-063 gate"', () => {
    assert.match(orchAppend, /DIA-063 gate/);
  });
  // R2: architector design persistence before implementation
  it('orchestrator_append.md R2: "persist the design text"', () => {
    assert.match(orchAppend, /persist the design text/);
  });
  it('orchestrator_append.md R2: "DIA ticket"', () => {
    assert.match(orchAppend, /DIA ticket/);
  });
  it('orchestrator_append.md R2: "before implementation"', () => {
    assert.match(orchAppend, /before implementation/);
  });
  // R3: merge-gate container evidence
  it('orchestrator_append.md R3: "docker compose ps"', () => {
    assert.match(orchAppend, /docker compose ps/);
  });
  it('orchestrator_append.md R3: "dev service"', () => {
    assert.match(orchAppend, /dev service/);
  });
  it('orchestrator_append.md R3: "before merge dispatch"', () => {
    assert.match(orchAppend, /before merge dispatch/);
  });
  it('orchestrator_append.md R3: "session log"', () => {
    assert.match(orchAppend, /session log/);
  });

  // (c) AGENTS.md S4 codification (S4 AC 4.2 required phrases)
  it('AGENTS.md S4: "ticket ID"', () => {
    assert.match(agentsMd, /ticket ID/);
  });
  it('AGENTS.md S4: "every dispatch"', () => {
    assert.match(agentsMd, /every dispatch/);
  });
  it('AGENTS.md S4: "every resume prompt"', () => {
    assert.match(agentsMd, /every resume prompt/);
  });
  it('AGENTS.md S4: "persist the design text"', () => {
    assert.match(agentsMd, /persist the design text/);
  });
  it('AGENTS.md S4: "docker compose ps"', () => {
    assert.match(agentsMd, /docker compose ps/);
  });
  it('AGENTS.md S4: "before merge dispatch"', () => {
    assert.match(agentsMd, /before merge dispatch/);
  });
});

// ============================================================================
// S4 DIA-139 SLICE C (F-3) - RED until the single-rebuild fix lands
// ============================================================================
describe('S4 DIA-139 SLICE C (F-3): single docker stack rebuild in make test-infra (RED now)', () => {
  const smokeScript = readRoot('scripts/test-docker-smoke.sh');

  // F-3 (tasks.md 3.2): the test-infra recipe must NOT run its own
  // `docker compose up -d --build` - the smoke test is the sole bring-up.
  // Comment lines are filtered out first so a `# docker compose up ...` note
  // above the target (documenting the fix) cannot false-positive the match.
  it('Makefile: test-infra recipe contains no docker compose up -d --build (smoke test is the sole bring-up)', () => {
    const recipeLines = testInfraRecipe()
      .split('\n')
      .filter((l) => !l.trim().startsWith('#'))
      .join('\n');
    assert.doesNotMatch(
      recipeLines,
      /docker compose up -d --build/,
      'test-infra must not rebuild the stack a second time (F-3)',
    );
  });

  // F-3 (tasks.md 3.2): the recipe must opt the smoke test into leave-up
  // mode so test-python runs against the stack the smoke test brought up.
  it('Makefile: test-infra recipe invokes the smoke test with SMOKE_LEAVE_UP=1', () => {
    assert.match(
      testInfraRecipe(),
      /SMOKE_LEAVE_UP=1/,
      'test-infra must set SMOKE_LEAVE_UP=1 when calling test-docker-smoke.sh (F-3)',
    );
  });

  // F-3 (tasks.md 3.1): the smoke script must support the SMOKE_LEAVE_UP
  // env var (leave the stack running on success). Absent today - RED.
  it('test-docker-smoke.sh: supports SMOKE_LEAVE_UP=1 to leave the stack up on success', () => {
    assert.match(
      smokeScript,
      /SMOKE_LEAVE_UP/,
      'test-docker-smoke.sh must read SMOKE_LEAVE_UP (F-3)',
    );
  });

  // F-3 (tasks.md 3.1): the env var is checked at the teardown step, not at
  // bring-up - the smoke test's validation logic is unchanged. The teardown
  // is the cleanup trap; the guard must live there. Line-anchored match so a
  // comment mentioning "cleanup()" earlier in the script cannot shift the
  // scanned region off the real function.
  it('test-docker-smoke.sh: SMOKE_LEAVE_UP guard lives in the teardown (cleanup trap) step', () => {
    const cleanupMatch = smokeScript.match(/^cleanup\(\)/m);
    assert.ok(cleanupMatch, 'test-docker-smoke.sh must define a cleanup() teardown function');
    const teardownRegion = smokeScript.slice(cleanupMatch.index, cleanupMatch.index + 500);
    assert.match(
      teardownRegion,
      /SMOKE_LEAVE_UP/,
      'SMOKE_LEAVE_UP must be checked in the teardown step',
    );
  });
});

// ============================================================================
// S5 DIA-139 SLICE B (F-2) - turbo base `test` default flip - GREEN since
// 6cf2db9. Moved here in the slice B fix loop (cycle 1): review finding said
// the F-2 assertions must live in THIS persistent suite (wired into make
// test-config per ADR 10), not a standalone file. Reuses parseJsonc above.
// ============================================================================
describe('S5 DIA-139 SLICE B (F-2): turbo base test task default', () => {
  // The four packages DIA-168 verified to run standalone (no build artifacts);
  // their overrides became dead once the base default flipped to dependsOn: [].
  const LEGACY_OVERRIDES = [
    '@poetry/editor-engine#test',
    '@poetry/data-contracts#test',
    '@poetry/phonetics-core#test',
    'author-studio#test',
  ];

  it('base test task must not depend on build (dependsOn: [] or key absent)', () => {
    const deps = turbo.tasks.test.dependsOn;
    assert.ok(
      deps === undefined || (Array.isArray(deps) && deps.length === 0),
      `expected dependsOn: [] or no dependsOn key, got ${JSON.stringify(deps)}`,
    );
  });

  it('per-package #test override block for the four verified packages is removed', () => {
    for (const key of LEGACY_OVERRIDES) {
      assert.equal(
        key in turbo.tasks,
        false,
        `${key} override must be removed (new base default covers it)`,
      );
    }
  });
});
