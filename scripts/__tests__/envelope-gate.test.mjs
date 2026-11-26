#!/usr/bin/env node
/**
 * DIA-261023-d6b9: Envelope-duplication gate tests.
 *
 * Tests the pure envelope-duplication counting rule (evaluateEnvelopeDuplication)
 * from the production seam .opencode/plugins/lib/envelope-gate.ts (shared with
 * delegation-observer.ts) - no local copies of the regex or the counting logic.
 *
 * Counting contract pinned here:
 *   - LINE-ANCHORED fence openers only (three backticks at column 0
 *     immediately followed by IMMUTABLE_GIT_ENVELOPE); count >= 1 violates.
 *   - Indentation semantics: a fence opener with leading whitespace does NOT
 *     count - the guard requires column 0 (an indented fence is quoted/
 *     nested markdown in prose, not a payload copy of the injected block).
 *   - The bare token mid-line (or without the fence) never counts, so prose
 *     that quotes IMMUTABLE_GIT_ENVELOPE cannot trip the guard.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * Plain node ESM, zero npm deps, node:test + node:assert (routing-order-gate
 * suite style).
 *
 * Run: node scripts/__tests__/envelope-gate.test.mjs
 * Wired into `make test-config` (DIA-261023-d6b9).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { evaluateEnvelopeDuplication } from '../../.opencode/plugins/lib/envelope-gate.ts';

const FENCE = '```IMMUTABLE_GIT_ENVELOPE';

test('envelope-gate: clean authored text has zero openers (no violation)', () => {
  const text = [
    'Review the delta at the fixed point.',
    'FIXED_POINT: 0a4caf7a',
    'Check the standards axis too.',
  ].join('\n');
  assert.deepEqual(evaluateEnvelopeDuplication(text), {
    violation: false,
    count: 0,
  });
  assert.deepEqual(evaluateEnvelopeDuplication(''), {
    violation: false,
    count: 0,
  });
});

test('envelope-gate: one column-0 fence opener violates (count 1)', () => {
  const text = ['Review. FIXED_POINT: 0a4caf7a', FENCE, 'worktree: /workspace', '```'].join('\n');
  assert.deepEqual(evaluateEnvelopeDuplication(text), {
    violation: true,
    count: 1,
  });
});

test('envelope-gate: two fence openers count 2 (both in one dispatch)', () => {
  const text = [FENCE, 'fake block', '```', '', FENCE, 'second fake', '```'].join('\n');
  assert.deepEqual(evaluateEnvelopeDuplication(text), {
    violation: true,
    count: 2,
  });
});

test('envelope-gate: bare token quoted mid-line in prose does NOT violate', () => {
  // Learnings records / cards / this file's own diff quote the token freely.
  const text = [
    'The hook writes ```IMMUTABLE_GIT_ENVELOPE into the child prompt itself.',
    'Prose may also name IMMUTABLE_GIT_ENVELOPE without any fence at all.',
    '```',
    'A bare column-0 closing fence carries no token and is not an opener.',
  ].join('\n');
  assert.deepEqual(evaluateEnvelopeDuplication(text), {
    violation: false,
    count: 0,
  });
});

test('envelope-gate: indented opener does NOT count (column-0 semantics)', () => {
  // Chosen semantics: the opener must start at column 0. Leading whitespace
  // marks quoted/nested markdown in prose, not a hand-copied payload block.
  const text = [
    'As recorded in the envelope record:',
    '  ' + FENCE,
    '  worktree: /workspace',
    '  ```',
  ].join('\n');
  assert.deepEqual(evaluateEnvelopeDuplication(text), {
    violation: false,
    count: 0,
  });
});
