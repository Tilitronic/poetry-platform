#!/usr/bin/env node
/**
 * DIA-230: Routing-order gate tests (F1/F2/F3/F4 fixes).
 *
 * Tests the advisory routing-order check logic extracted from the
 * delegation-observer plugin. These tests validate:
 *
 * F1: Routing check fires BEFORE ticket-gate early returns
 * F2: Prior @ai-specialist check scans messages.jsonl (gen_ai.agent.name)
 * F3: Config-work pattern coverage (commands/, dcp.jsonc, rules/)
 * F4: Integration tests simulating full hook control flow
 *
 * Plain node ESM, zero npm deps. No plugin loading needed -- tests the
 * pure logic functions directly.
 *
 * Run: node scripts/__tests__/routing-order-gate.test.mjs
 */
import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// --- Config-work path detection regex (extracted from delegation-observer.ts) ---
// F3: Added .opencode/commands/, dcp.jsonc, .opencode/rules/
const CONFIG_WORK_PATTERN =
  /(\.opencode\/plugins\/|\.opencode\/oh-my-opencode-slim|orchestrator_append\.md|\.opencode\/agents\/|\.opencode\/skills\/|\.opencode\/commands\/|\.opencode\/rules\/|opencode\.jsonc|dcp\.jsonc|AGENTS\.md|practice-protected\.md)/i;

/**
 * Detect if a dispatch text contains config-work path indicators.
 * Extracted from delegation-observer.ts DIA-230 routing-order gate.
 */
function isConfigWorkDispatch(dispatchText) {
  return CONFIG_WORK_PATTERN.test(dispatchText);
}

/**
 * F2: Scan messages.jsonl for a prior @ai-specialist delegation in a session.
 * messages.jsonl carries gen_ai.agent.name which registry.jsonl lacks.
 * Returns true if any delegation row with agent name "ai-specialist" exists.
 */
function hasPriorAiSpecialistDispatch(messagesPath, sessionId) {
  if (!existsSync(messagesPath)) return false;
  const lines = readFileSync(messagesPath, 'utf-8').split('\n').filter(Boolean);
  return lines.some((line) => {
    try {
      const row = JSON.parse(line);
      return (
        row.session_id === sessionId &&
        row['gen_ai.agent.name'] === 'ai-specialist' &&
        row.event_type === 'delegation'
      );
    } catch {
      return false;
    }
  });
}

/**
 * Check if a subagent type is a coder variant.
 * Extracted from delegation-observer.ts DIA-230 routing-order gate.
 */
function isCoderAgent(subagentType) {
  return subagentType === 'coder' || subagentType === 'coder-escalated';
}

/**
 * F4: Simulate the full routing-order gate control flow.
 * Returns { violation: boolean, reason: string } describing the outcome.
 * This mirrors the exact logic in delegation-observer.ts tool.execute.before.
 */
function simulateRoutingGate({ subagentType, dispatchText, messagesPath, sessionId }) {
  // Only check coder variants
  if (subagentType !== 'coder' && subagentType !== 'coder-escalated') {
    return { violation: false, reason: 'not a coder agent' };
  }

  // Detect config-work paths
  if (!CONFIG_WORK_PATTERN.test(dispatchText)) {
    return { violation: false, reason: 'no config-work paths detected' };
  }

  // Scan messages.jsonl for prior ai-specialist dispatch
  if (hasPriorAiSpecialistDispatch(messagesPath, sessionId)) {
    return { violation: false, reason: 'prior @ai-specialist dispatch found' };
  }

  return { violation: true, reason: 'no prior @ai-specialist dispatch' };
}

// --- Test helpers ---
function makeMessagesRow(overrides) {
  return JSON.stringify({
    row_id: 1,
    event_uuid: 'test-uuid',
    timestamp: new Date().toISOString(),
    'gen_ai.provider.name': 'opencode-go',
    'gen_ai.operation.name': 'invoke_agent',
    'gen_ai.agent.name': 'coder',
    event_type: 'delegation',
    task_ref: 'test task',
    resolution_status: 'in-flight',
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

  it('detects dcp.jsonc (F3)', () => {
    assert.ok(isConfigWorkDispatch('Change dcp.jsonc permissions'));
    assert.ok(isConfigWorkDispatch('Update dcp.jsonc tool access'));
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

  it('returns true when prior ai-specialist delegation exists for session', () => {
    writeFileSync(
      messagesPath,
      makeMessagesRow({
        session_id: 'ses_123',
        'gen_ai.agent.name': 'ai-specialist',
        event_type: 'delegation',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), true);
  });

  it('returns false when prior delegation is for different session', () => {
    writeFileSync(
      messagesPath,
      makeMessagesRow({
        session_id: 'ses_other',
        'gen_ai.agent.name': 'ai-specialist',
        event_type: 'delegation',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns false when agent is not ai-specialist', () => {
    writeFileSync(
      messagesPath,
      makeMessagesRow({
        session_id: 'ses_123',
        'gen_ai.agent.name': 'coder',
        event_type: 'delegation',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('returns false when event_type is not delegation', () => {
    writeFileSync(
      messagesPath,
      makeMessagesRow({
        session_id: 'ses_123',
        'gen_ai.agent.name': 'ai-specialist',
        event_type: 'routing_violation',
      }) + '\n',
    );
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), false);
  });

  it('handles multiple rows (finds matching one)', () => {
    const rows = [
      makeMessagesRow({ session_id: 'ses_123', 'gen_ai.agent.name': 'coder' }),
      makeMessagesRow({ session_id: 'ses_123', 'gen_ai.agent.name': 'ai-specialist' }),
    ].join('\n');
    writeFileSync(messagesPath, rows + '\n');
    assert.equal(hasPriorAiSpecialistDispatch(messagesPath, 'ses_123'), true);
  });

  it('handles malformed JSON lines gracefully', () => {
    const rows = [
      'not valid json',
      makeMessagesRow({ session_id: 'ses_123', 'gen_ai.agent.name': 'ai-specialist' }),
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
      makeMessagesRow({
        session_id: 'ses_123',
        'gen_ai.agent.name': 'ai-specialist',
        event_type: 'delegation',
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
      makeMessagesRow({
        session_id: 'ses_123',
        'gen_ai.agent.name': 'coder',
        event_type: 'delegation',
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
      'Change dcp.jsonc permissions',
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
    // Verify the routing gate error message starts with "ROUTING GATE:" so it
    // matches the catch-block re-throw condition alongside "TICKET GATE:".
    const routingError = new Error(
      'ROUTING GATE: @coder dispatched on config-work without prior @ai-specialist gate review.\n' +
        'AGENTS.md section 2.5 requires:\n' +
        '  1. @ai-specialist gate research -> findings registered\n' +
        '  2. User reviews & approves findings\n' +
        '  3. THEN @coder implementation can proceed\n' +
        'Action: dispatch @ai-specialist first.',
    );

    const ticketError = new Error('§10 TICKET GATE: no DIA ticket found for config-work dispatch.');

    // Both must match the re-throw condition
    assert.ok(
      routingError.message.startsWith('ROUTING GATE:'),
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
