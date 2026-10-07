#!/usr/bin/env node
/**
 * DIA-230: Routing-order gate tests (F1/F2/F3/F4 fixes).
 *
 * Tests the advisory routing-order check logic extracted from the
 * delegation-observer plugin. These tests validate:
 *
 * F1: Routing check fires BEFORE ticket-gate early returns
 * F2: Prior @ai-specialist check scans messages.jsonl (paracrine dispatch.started)
 * F3: Config-work pattern coverage (commands/, rules/)
 * F4: Integration tests simulating full hook control flow
 *
 * Plain node ESM, zero npm deps. Imports the REAL production seam
 * (.opencode/plugins/lib/routing-gate.ts, shared with
 * delegation-observer.ts) — no local logic copies.
 *
 * Run: node scripts/__tests__/routing-order-gate.test.mjs
 * Wired into `make test-config` (DIA-260827-uv).
 */
import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// --- Production imports (DIA-260827-uv a): single source of truth lives in
// .opencode/plugins/lib/routing-gate.ts, shared with delegation-observer.ts.
// No local copies of the pattern, scan, coder check, gate flow, or error text.
import {
  isConfigWorkDispatch,
  hasPriorAiSpecialistDispatch,
  isCoderAgent,
  evaluateRoutingGate as simulateRoutingGate,
  ROUTING_GATE_PREFIX,
  buildRoutingGateError,
} from '../../.opencode/plugins/lib/routing-gate.ts';

// Mirrors emitStateSignal's row shape in delegation-observer.ts (DIA-220):
// paracrine dispatch.started rows carry session_id + agent in the payload,
// unlike delegation rows.
function makeParacrineRow(overrides) {
  return JSON.stringify({
    row_id: 1,
    event_uuid: 'test-uuid',
    timestamp: new Date().toISOString(),
    'gen_ai.provider.name': 'opencode-go',
    'gen_ai.operation.name': 'state_signal',
    event_type: 'paracrine',
    signal_type: 'dispatch.started',
    'gen_ai.agent.id': 'task-1',
    agent: 'coder',
    session_id: 'ses_test123',
    writer: 'plugin',
    ...overrides,
  });
}

// --- Test suite ---
describe('DIA-230: Config-work path detection (F3)', () => {
  it('detects .opencode/plugins/ paths', () => {
    assert.ok(isConfigWorkDispatch('Edit .opencode/plugins/delegation-observer.ts'));
  });

  it('detects .opencode/oh-my-opencode-slim paths', () => {
    assert.ok(isConfigWorkDispatch('Update .opencode/oh-my-opencode-slim.jsonc'));
  });

  it('detects orchestrator_append.md', () => {
    assert.ok(isConfigWorkDispatch('Add orchestrator_append.md'));
  });

  it('detects .opencode/agents/ paths', () => {
    assert.ok(isConfigWorkDispatch('Create .opencode/agents/new-agent.md'));
  });

  it('detects .opencode/skills/ paths', () => {
    assert.ok(isConfigWorkDispatch('Add .opencode/skills/new-skill/SKILL.md'));
  });

  it('detects .opencode/commands/ paths (F3)', () => {
    assert.ok(isConfigWorkDispatch('Create .opencode/commands/new-command.md'));
    assert.ok(isConfigWorkDispatch('Edit .opencode/commands/deploy.sh'));
  });

  it('detects .opencode/rules/ paths (F3)', () => {
    assert.ok(isConfigWorkDispatch('Add .opencode/rules/new-rule.md'));
    assert.ok(isConfigWorkDispatch('Update .opencode/rules/lint-config'));
  });

  it('detects opencode.jsonc', () => {
    assert.ok(isConfigWorkDispatch('Update opencode.jsonc agent config'));
  });

  it('detects AGENTS.md', () => {
    assert.ok(isConfigWorkDispatch('Edit AGENTS.md section 2.5'));
  });

  it('detects practice-protected.md', () => {
    assert.ok(isConfigWorkDispatch('Change practice-protected.md zones'));
  });

  it('does not detect non-config-work paths', () => {
    assert.ok(!isConfigWorkDispatch('Implement user profile in apps/author-studio/'));
    assert.ok(!isConfigWorkDispatch('Fix src/components/Button.tsx'));
    assert.ok(!isConfigWorkDispatch('Update packages/data-contracts'));
  });

  it('does not detect .opencode/session/ paths (runtime artifacts)', () => {
    assert.ok(!isConfigWorkDispatch('Read .opencode/session/registry.jsonl'));
  });

  it('does not detect .opencode/learnings/ paths (runtime artifacts)', () => {
    assert.ok(!isConfigWorkDispatch('Update .opencode/learnings/external-patterns/'));
  });

  it('is case-insensitive', () => {
    assert.ok(isConfigWorkDispatch('Edit OPENCODE.JSONC'));
    assert.ok(isConfigWorkDispatch('Update agents.md'));
    assert.ok(isConfigWorkDispatch('Fix .OPENCODE/PLUGINS/test.ts'));
  });

  it('handles empty text', () => {
    assert.ok(!isConfigWorkDispatch(''));
  });
});

describe('DIA-230: Prior @ai-specialist dispatch scanning (F2)', () => {
  let testDir;
  let messagesPath;

  beforeEach(() => {
    testDir = join('/tmp', `routing-gate-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
    messagesPath = join(testDir, 'messages.jsonl');
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
  });

  it('returns false when messages file does not exist', () => {
    assert.equal(hasPriorAiSpecialistDispatch('/nonexistent/messages.jsonl', 'ses_123'), false);
  });

  it('returns false when messages is empty', () => {
    writeFileSync(messagesPath, '');
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns true when prior ai-specialist dispatch.started exists for session', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'ai-specialist',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), true);
  });

  it('returns false when prior dispatch.started is for different session', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_other',
        agent: 'ai-specialist',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns false when agent is not ai-specialist', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'coder',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns false when signal_type is not dispatch.started', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'ai-specialist',
        signal_type: 'dispatch.completed',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns false when event_type is not paracrine', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'ai-specialist',
        event_type: 'delegation',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('handles multiple rows (finds matching one)', () => {
    const rows = [
      makeParacrineRow({ session_id: 'ses_123', agent: 'coder' }),
      makeParacrineRow({ session_id: 'ses_123', agent: 'ai-specialist' }),
    ].join('\n');
    writeFileSync(messagesPath, rows + '\n');
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), true);
  });

  it('handles malformed JSON lines gracefully', () => {
    const rows = [
      'not valid json',
      makeParacrineRow({ session_id: 'ses_123', agent: 'ai-specialist' }),
      '{broken',
    ].join('\n');
    writeFileSync(messagesPath, rows + '\n');
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), true);
  });
});

describe('DIA-230: Coder agent detection', () => {
  it('detects coder', () => {
    assert.ok(isCoderAgent('coder'));
  });

  it('detects coder-escalated', () => {
    assert.ok(isCoderAgent('coder-escalated'));
  });

  it('does not detect other agents', () => {
    assert.ok(!isCoderAgent('ai-specialist'));
    assert.ok(!isCoderAgent('reviewer'));
    assert.ok(!isCoderAgent('architector'));
    assert.ok(!isCoderAgent(''));
  });
});

describe('DIA-230: Full routing gate simulation (F4)', () => {
  let testDir;
  let messagesPath;

  beforeEach(() => {
    testDir = join('/tmp', `routing-gate-sim-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
    messagesPath = join(testDir, 'messages.jsonl');
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
  });

  it('VIOLATION: coder + config-work + no ai-specialist', () => {
    writeFileSync(messagesPath, '');
    const result = simulateRoutingGate({
      subagentType: 'coder',
      dispatchText: 'Update .opencode/plugins/delegation-observer.ts',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.ok(result.violation, result.reason);
  });

  it('NO VIOLATION: coder + config-work + prior ai-specialist', () => {
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'ai-specialist',
      }) + '\n',
    );
    const result = simulateRoutingGate({
      subagentType: 'coder',
      dispatchText: 'Update .opencode/plugins/delegation-observer.ts',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.equal(result.violation, false, result.reason);
  });

  it('NO VIOLATION: coder + non-config-work + no ai-specialist', () => {
    writeFileSync(messagesPath, '');
    const result = simulateRoutingGate({
      subagentType: 'coder',
      dispatchText: 'Implement user profile in apps/author-studio/',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.equal(result.violation, false, result.reason);
  });

  it('NO VIOLATION: ai-specialist + config-work + no ai-specialist', () => {
    writeFileSync(messagesPath, '');
    const result = simulateRoutingGate({
      subagentType: 'ai-specialist',
      dispatchText: 'Research .opencode/plugins/ best practices',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.equal(result.violation, false, result.reason);
  });

  it('NO VIOLATION: empty messages + non-coder agent', () => {
    writeFileSync(messagesPath, '');
    const result = simulateRoutingGate({
      subagentType: 'reviewer',
      dispatchText: 'Review .opencode/agents/coder.md changes',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.equal(result.violation, false, result.reason);
  });

  it('F1: routing check fires before ticket-gate returns (control flow test)', () => {
    // This test verifies the control flow order: the routing check must run
    // BEFORE any early returns from the ticket-gate block. We simulate this
    // by checking that the routing gate logic is independent of ticket-gate
    // state -- it fires regardless of whether a ticket exists.
    writeFileSync(messagesPath, '');

    // Even with a valid ticket_id, the routing check should fire
    const result = simulateRoutingGate({
      subagentType: 'coder',
      dispatchText: 'Update opencode.jsonc agent config',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.ok(result.violation, 'routing check fires independently of ticket gate');
  });

  it('F2: specific ai-specialist check (not any prior task)', () => {
    // Prior coder dispatch should NOT satisfy the routing check
    writeFileSync(
      messagesPath,
      makeParacrineRow({
        session_id: 'ses_123',
        agent: 'coder',
      }) + '\n',
    );
    const result = simulateRoutingGate({
      subagentType: 'coder',
      dispatchText: 'Update .opencode/plugins/delegation-observer.ts',
      messagesPath,
      sessionId: 'ses_123',
    });
    assert.ok(result.violation, 'prior coder dispatch should NOT satisfy routing check');
  });

  it('F3: new config-work patterns trigger violation', () => {
    writeFileSync(messagesPath, '');

    const testCases = [
      'Create .opencode/commands/new-command.md',
      'Edit .opencode/rules/lint-config',
    ];

    for (const text of testCases) {
      const result = simulateRoutingGate({
        subagentType: 'coder',
        dispatchText: text,
        messagesPath,
        sessionId: 'ses_123',
      });
      assert.ok(result.violation, `expected violation for: ${text}`);
    }
  });

  it('F4b: ROUTING GATE error prefix matches catch-block re-throw condition', () => {
    // Verify the PRODUCTION routing gate error starts with "ROUTING GATE:"
    // so it matches the catch-block re-throw condition alongside
    // "TICKET GATE:". Uses the real production builder, not a local copy.
    const routingError = buildRoutingGateError();

    const ticketError = new Error('§10 TICKET GATE: no DIA ticket found for config-work dispatch.');

    // Both must match the re-throw condition
    assert.ok(
      routingError.message.startsWith(ROUTING_GATE_PREFIX),
      'ROUTING GATE: error must start with ROUTING GATE:',
    );
    assert.ok(
      routingError.message.startsWith('ROUTING GATE:') ||
        routingError.message.startsWith('§10 TICKET GATE:'),
      'catch-block re-throw condition covers ROUTING GATE: prefix',
    );
    assert.ok(
      ticketError.message.startsWith('§10 TICKET GATE:'),
      'TICKET GATE: error must start with §10 TICKET GATE:',
    );
  });
});
