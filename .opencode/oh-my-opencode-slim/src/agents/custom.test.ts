import { describe, expect, spyOn, test } from 'bun:test';
import { DEFAULT_MODELS, type PluginConfig } from '../config';
import { createAgents, getAgentConfigs } from './index';

describe('custom-agent creation', () => {
  test('infers custom agents from unknown keys', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': { model: 'openai/gpt-5.4-mini' },
        reviewer: {
          model: 'openai/gpt-5.5',
          prompt: 'You are the custom reviewer agent.',
        },
      },
    };

    const agents = createAgents(config);
    const names = agents.map((agent) => agent.name);

    expect(names).toContain('reviewer');

    const customAgent = agents.find((agent) => agent.name === 'reviewer');
    expect(customAgent).toBeDefined();
    expect(customAgent?.config.model).toBe('openai/gpt-5.5');
    expect(customAgent?.config.prompt).toBe(
      'You are the custom reviewer agent.',
    );
  });

  test('supports prompt and orchestratorPrompt for custom agents', () => {
    const config: PluginConfig = {
      agents: {
        'test-auditor': {
          model: 'openai/gpt-5.4-mini',
          prompt: 'You are a custom subagent for auditing.',
          orchestratorPrompt:
            '@test-auditor\n- Role: Compliance audit specialist',
        },
      },
    };

    const agents = createAgents(config);
    const customAgent = agents.find((agent) => agent.name === 'test-auditor');

    expect(customAgent).toBeDefined();
    expect(customAgent?.config.prompt).toBe(
      'You are a custom subagent for auditing.',
    );

    const boss = agents.find((agent) => agent.name === 'boss');
    expect(boss?.config.prompt).toContain(
      '@test-auditor\n- Role: Compliance audit specialist',
    );
  });

  test('skips custom agents without a model', () => {
    const warnSpy = spyOn(console, 'warn').mockImplementation(() => {});

    try {
      const config: PluginConfig = {
        agents: {
          janitor: {
            prompt: 'You are Janitor.',
            orchestratorPrompt: '@janitor\n- Role: Cleanup specialist',
          },
        },
      };

      const agentDefs = createAgents(config);
      expect(
        agentDefs.find((agent) => agent.name === 'janitor'),
      ).toBeUndefined();
      expect(warnSpy).toHaveBeenCalledWith(
        "[oh-my-opencode] Custom agent 'janitor' skipped: 'model' is required",
      );
    } finally {
      warnSpy.mockRestore();
    }
  });

  test('does not create or inject disabled custom agents', () => {
    const config: PluginConfig = {
      disabled_agents: ['test-auditor', 'designer'],
      agents: {
        'test-auditor': {
          model: 'openai/gpt-5.4-mini',
          prompt: 'You are a disabled custom agent.',
        },
      },
    };

    const agentDefs = createAgents(config);
    const names = agentDefs.map((agent) => agent.name);
    expect(names).not.toContain('test-auditor');

    const sdkConfigs = getAgentConfigs(config);
    expect(sdkConfigs['test-auditor']).toBeUndefined();
  });

  test('rejects unsafe custom agent names', () => {
    const config: PluginConfig = {
      agents: {
        'unsafe/name': {
          model: 'openai/gpt-5.4-mini',
        },
      },
    };

    expect(() => createAgents(config)).toThrow();
  });

  test('accepts arbitrary orchestratorPrompt text for custom agents', () => {
    const config: PluginConfig = {
      agents: {
        janitor: {
          model: 'openai/gpt-5.4-mini',
          orchestratorPrompt: '@cleanup\n- Role: Cleanup specialist',
        },
      },
    };

    const agents = createAgents(config);
    const boss = agents.find((agent) => agent.name === 'boss');
    expect(boss?.config.prompt).toContain(
      '@cleanup\n- Role: Cleanup specialist',
    );
  });

  test('creates wrapper agents from acpAgents config', () => {
    const config: PluginConfig = {
      acpAgents: {
        'claude-research': {
          command: 'claude-code-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
          description: 'Claude Code research via ACP',
          wrapperModel: 'openai/gpt-5.4-mini',
        },
      },
    };

    const agents = createAgents(config);
    const wrapper = agents.find((agent) => agent.name === 'claude-research');
    const boss = agents.find((agent) => agent.name === 'boss');

    expect(wrapper).toBeDefined();
    expect(wrapper?.description).toBe('Claude Code research via ACP');
    expect(wrapper?.config.model).toBe('openai/gpt-5.4-mini');
    expect(wrapper?.config.prompt).toContain('acp_run');
    expect(boss?.config.prompt).toContain('@claude-research');
  });

  test('falls back to active preset primary model for ACP wrappers', () => {
    const config: PluginConfig = {
      preset: 'opencode-go',
      presets: {
        'opencode-go': {
          orchestrator: { model: 'opencode-go/glm-5.2' },
        },
      },
      agents: {
        orchestrator: { model: 'opencode-go/glm-5.2' },
      },
      acpAgents: {
        bridge: {
          command: 'bridge-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
        },
      },
    };

    const agents = createAgents(config);
    const wrapper = agents.find((agent) => agent.name === 'bridge');

    expect(wrapper?.config.model).toBe('opencode-go/glm-5.2');
  });

  test('falls back to oracle model for ACP wrappers', () => {
    const defaults = {
      coder: DEFAULT_MODELS.coder,
      researcher: DEFAULT_MODELS.researcher,
      orchestrator: DEFAULT_MODELS.boss,
    };
    DEFAULT_MODELS.coder = undefined;
    DEFAULT_MODELS.researcher = undefined;
    DEFAULT_MODELS.boss = undefined;

    try {
      const config: PluginConfig = {
        acpAgents: {
          bridge: {
            command: 'bridge-acp',
            args: [],
            env: {},
            timeoutMs: 0,
            permissionMode: 'ask',
          },
        },
      };

      const agents = createAgents(config);
      const wrapper = agents.find((agent) => agent.name === 'bridge');

      expect(wrapper?.config.model).toBe(DEFAULT_MODELS.architector);
    } finally {
      DEFAULT_MODELS.coder = defaults.fixer;
      DEFAULT_MODELS.researcher = defaults.librarian;
      DEFAULT_MODELS.boss = defaults.orchestrator;
    }
  });

  test('rejects acpAgents that conflict with custom agents', () => {
    const config: PluginConfig = {
      agents: {
        bridge: { model: 'openai/gpt-5.4-mini' },
      },
      acpAgents: {
        bridge: {
          command: 'bridge-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
        },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "ACP agent 'bridge' conflicts with a custom agent of the same name",
    );
  });

  test('rejects acpAgents that conflict with built-in agents', () => {
    const config: PluginConfig = {
      acpAgents: {
        coder: {
          command: 'fixer-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
        },
      },
    };

    expect(() => createAgents(config)).toThrow(
      "ACP agent 'coder' conflicts with a built-in agent name or alias",
    );
  });

  test('appends ACP routing prompts separately without heading, and preserves rewriting', () => {
    const config: PluginConfig = {
      agents: {
        'code-navigator': {
          model: 'openai/gpt-5.4-mini',
          displayName: 'fancy-explorer',
        },
        janitor: {
          model: 'openai/gpt-5.5',
          orchestratorPrompt:
            'Please use @janitor to clean up after @code-navigator has completed.',
        },
      },
      acpAgents: {
        'claude-research': {
          command: 'claude-code-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
          orchestratorPrompt:
            'Please delegate research tasks to @claude-research or @code-navigator.',
        },
      },
    };

    const agents = createAgents(config);
    const boss = agents.find((agent) => agent.name === 'boss');
    const prompt = boss?.config.prompt ?? '';

    // Verify Project-specific routing guidance exists and has the custom agent override prompt rewritten
    expect(prompt).toContain('# Project-specific routing guidance');
    expect(prompt).toContain(
      'Please use @janitor to clean up after @fancy-explorer has completed.',
    );

    // Verify ACP routing prompt is appended but NOT under the Project-specific routing guidance section
    // (i.e. it comes after or is separate, let's verify exact substring sequence or that the ACP test isn't inside the heading section)
    const pieces = prompt.split('# Project-specific routing guidance');
    expect(pieces.length).toBe(2);

    const headingContent = pieces[1];
    // The headingContent should contain the custom prompt but not contain the ACP prompt if ACP prompt is appended after/before.
    // Wait, in our implementation, order of appending is:
    // 1) overridden/custom prompts under # Project-specific routing guidance.
    // 2) ACP routing prompts (without the header).
    // So headingContent (everything after the header) will contain the custom prompt, and then at the very end (or separated), the ACP prompt.
    // But the ACP prompt is not under that header's specific block if it's appended separately.
    // Wait, is there a way to verify they are separated? Yes, we can verify that the custom prompt block and ACP prompt block are two separate parts,
    // and that ACP prompt is appended at the very end of the string, outside of the heading's contiguous text block or that if only ACP is present, the heading doesn't show up.
    expect(headingContent).toContain(
      'Please use @janitor to clean up after @fancy-explorer has completed.',
    );
    expect(headingContent).toContain(
      'Please delegate research tasks to @claude-research or @fancy-explorer.',
    );

    // Let's also check a scenario where only ACP routing prompt is present. There should be NO heading at all!
    const configOnlyAcp: PluginConfig = {
      agents: {
        'code-navigator': {
          model: 'openai/gpt-5.4-mini',
          displayName: 'fancy-explorer',
        },
      },
      acpAgents: {
        'claude-research': {
          command: 'claude-code-acp',
          args: [],
          env: {},
          timeoutMs: 0,
          permissionMode: 'ask',
          orchestratorPrompt:
            'Please delegate research tasks to @claude-research or @code-navigator.',
        },
      },
    };

    const agentsOnlyAcp = createAgents(configOnlyAcp);
    const bossOnlyAcp = agentsOnlyAcp.find((agent) => agent.name === 'boss');
    const promptOnlyAcp = bossOnlyAcp?.config.prompt ?? '';

    expect(promptOnlyAcp).not.toContain('# Project-specific routing guidance');
    expect(promptOnlyAcp).toContain(
      'Please delegate research tasks to @claude-research or @fancy-explorer.',
    );
  });
});
