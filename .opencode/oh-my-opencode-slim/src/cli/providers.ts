import { DEFAULT_AGENT_MCPS } from '../config/agent-mcps';
import { CUSTOM_SKILLS } from './custom-skills';
import type { InstallConfig } from './types';

const SCHEMA_URL =
  'https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json';

export const GENERATED_PRESETS = ['openai', 'opencode-go'] as const;

// Model mappings by provider/preset.
export const MODEL_MAPPINGS = {
  openai: {
    boss: { model: 'openai/gpt-5.5', variant: 'medium' },
    architector: { model: 'openai/gpt-5.5', variant: 'high' },
    reviewer: { model: 'openai/gpt-5.5', variant: 'high' },
    researcher: { model: 'openai/gpt-5.4-mini', variant: 'low' },
    'code-navigator': { model: 'openai/gpt-5.4-mini', variant: 'low' },
    designer: { model: 'openai/gpt-5.4-mini', variant: 'medium' },
    coder: { model: 'openai/gpt-5.5', variant: 'low' },
  },
  kimi: {
    boss: { model: 'kimi-for-coding/k2p5' },
    architector: { model: 'kimi-for-coding/k2p5', variant: 'high' },
    reviewer: { model: 'kimi-for-coding/k2p5', variant: 'high' },
    researcher: { model: 'kimi-for-coding/k2p5', variant: 'low' },
    'code-navigator': { model: 'kimi-for-coding/k2p5', variant: 'low' },
    designer: { model: 'kimi-for-coding/k2p5', variant: 'medium' },
    coder: { model: 'kimi-for-coding/k2p5', variant: 'low' },
  },
  copilot: {
    boss: { model: 'github-copilot/claude-opus-4.6' },
    architector: { model: 'github-copilot/claude-opus-4.6', variant: 'high' },
    reviewer: { model: 'github-copilot/claude-opus-4.6', variant: 'high' },
    researcher: { model: 'github-copilot/grok-code-fast-1', variant: 'low' },
    'code-navigator': {
      model: 'github-copilot/grok-code-fast-1',
      variant: 'low',
    },
    designer: {
      model: 'github-copilot/gemini-3.1-pro-preview',
      variant: 'medium',
    },
    coder: { model: 'github-copilot/claude-sonnet-4.6', variant: 'low' },
  },
  'zai-plan': {
    boss: { model: 'zai-coding-plan/glm-5' },
    architector: { model: 'zai-coding-plan/glm-5', variant: 'high' },
    reviewer: { model: 'zai-coding-plan/glm-5', variant: 'high' },
    researcher: { model: 'zai-coding-plan/glm-5', variant: 'low' },
    'code-navigator': { model: 'zai-coding-plan/glm-5', variant: 'low' },
    designer: { model: 'zai-coding-plan/glm-5', variant: 'medium' },
    coder: { model: 'zai-coding-plan/glm-5', variant: 'low' },
  },
  'opencode-go': {
    boss: { model: 'opencode-go/glm-5.2' },
    architector: { model: 'opencode-go/qwen3.7-max', variant: 'max' },
    reviewer: { model: 'opencode-go/deepseek-v4-flash', variant: 'high' },
    researcher: { model: 'opencode-go/deepseek-v4-flash' },
    'code-navigator': { model: 'opencode-go/deepseek-v4-flash' },
    designer: { model: 'opencode-go/kimi-k2.7-code', variant: 'medium' },
    coder: { model: 'opencode-go/deepseek-v4-flash', variant: 'high' },
    observer: { model: 'opencode-go/kimi-k2.6' },
  },
} as const;

export type PresetName = keyof typeof MODEL_MAPPINGS;
export type GeneratedPresetName = (typeof GENERATED_PRESETS)[number];

export function isPresetName(value: string): value is PresetName {
  return Object.hasOwn(MODEL_MAPPINGS, value);
}

export function getPresetNames(): PresetName[] {
  return Object.keys(MODEL_MAPPINGS) as PresetName[];
}

export function isGeneratedPresetName(
  value: string,
): value is GeneratedPresetName {
  return GENERATED_PRESETS.includes(value as GeneratedPresetName);
}

export function getGeneratedPresetNames(): GeneratedPresetName[] {
  return [...GENERATED_PRESETS];
}

export function generateLiteConfig(
  installConfig: InstallConfig,
): Record<string, unknown> {
  const preset = installConfig.preset ?? 'openai';
  if (!isGeneratedPresetName(preset)) {
    throw new Error(
      `Unsupported preset "${preset}". Available generated presets: ${getGeneratedPresetNames().join(', ')}`,
    );
  }

  const config: Record<string, unknown> = {
    $schema: SCHEMA_URL,
    preset,
    presets: {},
  };

  if (preset === 'opencode-go') {
    config.disabled_agents = [];
  }

  const createAgentConfig = (
    agentName: string,
    modelInfo: { model: string; variant?: string },
  ) => {
    const isBoss = agentName === 'boss';

    const skills = isBoss
      ? ['*']
      : [
          ...CUSTOM_SKILLS.filter(
            (s) =>
              s.allowedAgents.includes('*') ||
              s.allowedAgents.includes(agentName),
          ).map((s) => s.name),
        ];

    return {
      model: modelInfo.model,
      variant: modelInfo.variant,
      skills,
      mcps:
        DEFAULT_AGENT_MCPS[agentName as keyof typeof DEFAULT_AGENT_MCPS] ?? [],
    };
  };

  const buildPreset = (mappingName: PresetName) => {
    const mapping = MODEL_MAPPINGS[mappingName];
    return Object.fromEntries(
      Object.entries(mapping).map(([agentName, modelInfo]) => [
        agentName,
        createAgentConfig(agentName, modelInfo),
      ]),
    );
  };

  const presets = config.presets as Record<string, unknown>;
  for (const presetName of GENERATED_PRESETS) {
    presets[presetName] = buildPreset(presetName);
  }

  if (installConfig.hasTmux) {
    config.tmux = {
      enabled: true,
      layout: 'main-vertical',
      main_pane_size: 60,
    };
  }

  if (installConfig.companion === 'yes') {
    config.companion = {
      enabled: true,
      position: 'bottom-right',
      size: 'medium',
      gifPack: 'default',
      loopStyle: 'classic',
      speed: 1,
      debug: false,
    };
  }

  return config;
}
