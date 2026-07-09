import { describe, expect, test } from 'bun:test';
import type { PluginConfig } from '../config';
import { normalizeAgentName, resolveRuntimeAgentName } from './agent-variant';

describe('normalizeAgentName', () => {
  test('returns name unchanged if no @ prefix', () => {
    expect(normalizeAgentName('architector')).toBe('architector');
  });

  test('strips @ prefix from agent name', () => {
    expect(normalizeAgentName('@oracle')).toBe('oracle');
  });

  test('trims whitespace', () => {
    expect(normalizeAgentName('  oracle  ')).toBe('oracle');
  });

  test('handles @ prefix with whitespace', () => {
    expect(normalizeAgentName('  @explore  ')).toBe('explore');
  });

  test('handles empty string', () => {
    expect(normalizeAgentName('')).toBe('');
  });
});

describe('resolveRuntimeAgentName', () => {
  test('keeps internal agent names unchanged', () => {
    const config = {
      agents: {
        architector: { displayName: 'advisor' },
      },
    } as PluginConfig;

    expect(resolveRuntimeAgentName(config, 'architector')).toBe('architector');
  });

  test('resolves displayName to internal name', () => {
    const config = {
      agents: {
        architector: { displayName: 'advisor' },
      },
    } as PluginConfig;

    expect(resolveRuntimeAgentName(config, 'advisor')).toBe('architector');
  });

  test('resolves displayName with @ prefix and whitespace', () => {
    const config = {
      agents: {
        architector: { displayName: 'advisor' },
      },
    } as PluginConfig;

    expect(resolveRuntimeAgentName(config, '  @advisor  ')).toBe('architector');
  });

  test('resolves displayName configured via legacy alias key', () => {
    const config = {
      agents: {
        'code-navigator': { displayName: 'custom-searcher' },
      },
    } as PluginConfig;

    expect(resolveRuntimeAgentName(config, 'custom-searcher')).toBe(
      'code-navigator',
    );
  });

  test('returns normalized name when no displayName match exists', () => {
    const config = {
      agents: {
        architector: { displayName: 'advisor' },
      },
    } as PluginConfig;

    expect(resolveRuntimeAgentName(config, '  @unknown  ')).toBe('unknown');
  });
});
