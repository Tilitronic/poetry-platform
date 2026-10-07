import { describe, expect, test } from 'bun:test';
import type { PluginConfig } from '../config';
import { createAgents, getAgentConfigs } from './index';

describe('displayName', () => {
  test('stores displayName on agent when configured', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'analyst' },
      },
    };

    const agents = createAgents(config);
    const explorer = agents.find((a) => a.name === 'code-navigator');
    expect(explorer?.displayName).toBe('analyst');

    const sdkConfigs = getAgentConfigs(config);
    expect(
      (sdkConfigs['code-navigator'] as { displayName?: string }).displayName,
    ).toBe('analyst');
  });

  test('injects configured displayName into orchestrator prompt mentions', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'analyst' },
      },
    };

    const agents = createAgents(config);
    const boss = agents.find((a) => a.name === 'boss');
    const prompt = boss?.config.prompt ?? '';

    expect(prompt).toContain('@analyst');
    expect(prompt).not.toMatch(/@code-navigator\b/);
  });

  test('normalizes @-prefixed displayName in prompt injection', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: '@analyst' },
      },
    };

    const agents = createAgents(config);
    const boss = agents.find((a) => a.name === 'boss');
    const prompt = boss?.config.prompt ?? '';

    expect(prompt).toContain('@analyst');
    expect(prompt).not.toContain('@@analyst');
    expect(prompt).not.toMatch(/@code-navigator\b/);
  });

  test('normalizes whitespace-padded displayName in prompt injection', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: '  analyst  ' },
      },
    };

    const agents = createAgents(config);
    const boss = agents.find((a) => a.name === 'boss');
    const prompt = boss?.config.prompt ?? '';

    expect(prompt).toContain('@analyst');
    expect(prompt).not.toContain('@ analyst ');
    expect(prompt).not.toMatch(/@code-navigator\b/);
  });

  test('throws when duplicate displayName is assigned', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'helper' },
        researcher: { displayName: 'helper' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "Duplicate displayName 'helper' assigned to multiple agents",
    );
  });

  test('throws when normalized duplicate displayName is assigned', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'advisor' },
        researcher: { displayName: ' @advisor ' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "Duplicate displayName 'advisor' assigned to multiple agents",
    );
  });

  test('throws when displayName conflicts with internal agent name', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'architector' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "displayName 'architector' conflicts with an agent name",
    );
  });

  test('throws when normalized displayName conflicts with internal agent name', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: ' @architector ' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "displayName 'architector' conflicts with an agent name",
    );
  });

  test('throws when orchestrator displayName conflicts with internal agent name', () => {
    const config: PluginConfig = {
      agents: {
        orchestrator: { displayName: 'architector' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      /displayName.*conflicts with an agent name/,
    );
  });

  test('throws when displayName is not a safe agent alias', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { displayName: 'senior reviewer' },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "displayName 'senior reviewer' must match /^[a-z][a-z0-9_-]*$/i",
    );
  });

  test('resolves legacy alias for explorer displayName override', () => {
    const config: PluginConfig = {
      agents: {
        explore: { displayName: 'analyst' },
      },
    };

    const agents = createAgents(config);
    const explorer = agents.find((a) => a.name === 'code-navigator');

    expect(explorer?.displayName).toBe('analyst');
  });

  test('uses displayName as host-facing registry key with hidden internal alias', () => {
    const config: PluginConfig = {
      agents: {
        architector: { displayName: 'advisor' },
      },
    };

    const sdkConfigs = getAgentConfigs(config) as Record<
      string,
      { hidden?: boolean; mode?: string }
    >;

    expect(sdkConfigs.advisor).toBeDefined();
    expect(sdkConfigs.advisor.mode).toBe('subagent');
    expect(sdkConfigs.advisor.hidden).toBeUndefined();

    expect(sdkConfigs.architector).toBeDefined();
    expect(sdkConfigs.architector.mode).toBe('subagent');
    expect(sdkConfigs.architector.hidden).toBe(true);
  });

  test('uses orchestrator displayName as host-facing key with hidden internal alias', () => {
    const config: PluginConfig = {
      agents: {
        orchestrator: { displayName: 'engineer' },
      },
    };

    const sdkConfigs = getAgentConfigs(config) as Record<
      string,
      { hidden?: boolean; mode?: string }
    >;

    expect(sdkConfigs.engineer).toBeDefined();
    expect(sdkConfigs.engineer.mode).toBe('primary');
    expect(sdkConfigs.engineer.hidden).toBeUndefined();

    expect(sdkConfigs.boss).toBeDefined();
    expect(sdkConfigs.boss.mode).toBe('primary');
    expect(sdkConfigs.boss.hidden).toBe(true);
  });

  test('keeps internal-only council agents hidden even with displayName configured', () => {
    const config: PluginConfig = {
      disabled_agents: [],
      agents: {
        councillor: { displayName: 'moderator' },
      },
    };

    const sdkConfigs = getAgentConfigs(config);

    expect(sdkConfigs.moderator).toBeUndefined();
    expect(sdkConfigs.councillor?.hidden).toBe(true);
  });
});
