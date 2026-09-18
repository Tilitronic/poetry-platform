import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { Preset } from './schema';

const STORE_FILE = 'workspace-presets.json';
const STORE_VERSION = 1;

interface WorkspacePresetStore {
  version: 1;
  workspaces: Record<string, string>;
}

export type WorkspacePresetSource = 'override' | 'stored' | 'none';

export interface WorkspacePresetResolution {
  name: string | null;
  source: WorkspacePresetSource;
  workspace: string;
}

function storePath(): string {
  const configHome =
    process.env.OPENCODE_CONFIG_DIR?.trim() ||
    path.join(
      process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), '.config'),
      'opencode',
    );
  return path.join(configHome, STORE_FILE);
}

function canonicalWorkspace(directory: string): string {
  return fs.realpathSync(directory);
}

function parseStore(raw: string): WorkspacePresetStore {
  const parsed = JSON.parse(raw) as Partial<WorkspacePresetStore>;
  if (
    parsed.version !== STORE_VERSION ||
    !parsed.workspaces ||
    typeof parsed.workspaces !== 'object' ||
    Array.isArray(parsed.workspaces)
  ) {
    throw new Error('workspace preset store has an invalid shape');
  }

  for (const [workspace, preset] of Object.entries(parsed.workspaces)) {
    if (typeof workspace !== 'string' || typeof preset !== 'string') {
      throw new Error('workspace preset store contains an invalid selection');
    }
  }

  return { version: STORE_VERSION, workspaces: parsed.workspaces };
}

export function getWorkspacePresetStorePath(): string {
  return storePath();
}

export function readWorkspacePreset(directory: string): string | null {
  const workspace = canonicalWorkspace(directory);
  try {
    const store = parseStore(fs.readFileSync(storePath(), 'utf8'));
    return store.workspaces[workspace] ?? null;
  } catch (error) {
    if (
      error instanceof Error &&
      'code' in error &&
      (error as { code?: string }).code === 'ENOENT'
    ) {
      return null;
    }
    throw error;
  }
}

function withStoreLock<T>(operation: () => T): T {
  const filePath = storePath();
  const lockPath = `${filePath}.lock`;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const lock = fs.openSync(lockPath, 'wx');
  try {
    return operation();
  } finally {
    fs.closeSync(lock);
    fs.rmSync(lockPath, { force: true });
  }
}

export function saveWorkspacePreset(
  directory: string,
  presetName: string,
): string {
  const workspace = canonicalWorkspace(directory);
  return withStoreLock(() => {
    const filePath = storePath();
    let store: WorkspacePresetStore = {
      version: STORE_VERSION,
      workspaces: {},
    };
    try {
      store = parseStore(fs.readFileSync(filePath, 'utf8'));
    } catch (error) {
      if (
        !(
          error instanceof Error &&
          'code' in error &&
          (error as { code?: string }).code === 'ENOENT'
        )
      ) {
        throw error;
      }
    }

    store.workspaces[workspace] = presetName;
    const temporaryPath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
    try {
      fs.writeFileSync(temporaryPath, `${JSON.stringify(store, null, 2)}\n`);
      fs.renameSync(temporaryPath, filePath);
      const verified = parseStore(fs.readFileSync(filePath, 'utf8'));
      if (verified.workspaces[workspace] !== presetName) {
        throw new Error('workspace preset store verification failed');
      }
    } finally {
      fs.rmSync(temporaryPath, { force: true });
    }
    return workspace;
  });
}

export function resolveWorkspacePreset(
  directory: string,
  presets: Record<string, Preset> | undefined,
  override = process.env.PRESET,
): WorkspacePresetResolution {
  const workspace = canonicalWorkspace(directory);
  const available = presets ?? {};
  const explicit = override;

  if (explicit !== undefined && explicit !== '') {
    if (!Object.hasOwn(available, explicit)) {
      throw new Error(
        `Preset "${explicit}" not found for workspace ${workspace}. Available presets: ${Object.keys(available).join(', ') || 'none'}`,
      );
    }
    return { name: explicit, source: 'override', workspace };
  }

  // The host launcher uses this private bridge because its user config is not
  // mounted into the dev container. It carries a stored value, not a new
  // public selector, and is still validated against the container registry.
  const bridged = process.env.OPENCODE_WORKSPACE_PRESET?.trim();
  if (bridged) {
    if (!Object.hasOwn(available, bridged)) {
      // Fixture workspaces (loader/tui tests) define no presets, so a leaked
      // bridge value has nothing to resolve against: fall back to empty
      // instead of throwing. Real workspaces define presets, so an unknown
      // bridge value there still throws (stale selection surfaces loudly).
      if (Object.keys(available).length === 0) {
        return { name: null, source: 'none', workspace };
      }
      throw new Error(
        `Stored preset "${bridged}" is not found for workspace ${workspace}. Available presets: ${Object.keys(available).join(', ') || 'none'}`,
      );
    }
    return { name: bridged, source: 'stored', workspace };
  }

  let stored: string | null;
  try {
    stored = readWorkspacePreset(directory);
  } catch (error) {
    throw new Error(
      `Stored preset value "invalid store data" is invalid for workspace ${workspace}. Available presets: ${Object.keys(available).join(', ') || 'none'}`,
      { cause: error },
    );
  }
  if (stored !== null) {
    if (!Object.hasOwn(available, stored)) {
      throw new Error(
        `Stored preset "${stored}" is not found for workspace ${workspace}. Available presets: ${Object.keys(available).join(', ') || 'none'}`,
      );
    }
    return { name: stored, source: 'stored', workspace };
  }

  return { name: null, source: 'none', workspace };
}
