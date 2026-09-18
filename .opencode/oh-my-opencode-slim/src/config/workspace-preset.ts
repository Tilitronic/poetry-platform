import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { Preset } from './schema';

// Project-local store (DIA-260918-yug6 M1): one file per project at
// <projectRoot>/.opencode/state/workspace-preset.json so the host save path
// and the container activate path read the same bytes. The project root is
// the nearest ancestor (or self) containing `.opencode` or `.git`.
export const WORKSPACE_PRESET_STORE_VERSION = 2;
const STORE_REL_PATH = path.join(
  '.opencode',
  'state',
  'workspace-preset.json',
);

interface WorkspacePresetStore {
  version: 2;
  preset: string | null;
}

// Legacy global store (pre-M1): keyed by canonical host path, invisible to
// the container. Read-only now: resolve() only warns when it still holds a
// value, never returns it. Kept so long-time users get a migration hint.
const LEGACY_STORE_FILE = 'workspace-presets.json';
const LEGACY_STORE_VERSION = 1;

interface LegacyWorkspacePresetStore {
  version: 1;
  workspaces: Record<string, string>;
}

export type WorkspacePresetSource =
  | 'override'
  | 'bridge'
  | 'stored'
  | 'declared'
  | 'none';

export interface WorkspacePresetResolution {
  name: string | null;
  source: WorkspacePresetSource;
  workspace: string;
}

/**
 * Find the project root for a directory by walking up to the nearest
 * ancestor containing `.opencode` or `.git`. Falls back to the resolved
 * start directory when no marker exists (e.g. bare temp fixtures).
 */
export function findProjectRoot(startDirectory: string): string {
  let start: string;
  try {
    start = fs.realpathSync(startDirectory);
  } catch {
    start = path.resolve(startDirectory);
  }
  let current = start;
  let previous = '';
  while (current !== previous) {
    try {
      if (
        fs.existsSync(path.join(current, '.opencode')) ||
        fs.existsSync(path.join(current, '.git'))
      ) {
        return current;
      }
    } catch {
      // Unreadable level: keep walking up.
    }
    previous = current;
    current = path.dirname(current);
  }
  return start;
}

function projectStorePath(directory: string): string {
  return path.join(findProjectRoot(directory), STORE_REL_PATH);
}

function legacyStorePath(): string {
  const configHome =
    process.env.OPENCODE_CONFIG_DIR?.trim() ||
    path.join(
      process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), '.config'),
      'opencode',
    );
  return path.join(configHome, LEGACY_STORE_FILE);
}

function parseProjectStore(raw: string, storeFile: string): WorkspacePresetStore {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error(
      `workspace preset store ${storeFile} has an invalid shape`,
      { cause: error },
    );
  }
  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    (parsed as { version?: unknown }).version !==
      WORKSPACE_PRESET_STORE_VERSION ||
    !(
      (parsed as { preset?: unknown }).preset === null ||
      typeof (parsed as { preset?: unknown }).preset === 'string'
    )
  ) {
    throw new Error(
      `workspace preset store ${storeFile} has an invalid shape`,
    );
  }
  return parsed as WorkspacePresetStore;
}

function parseLegacyStore(raw: string): LegacyWorkspacePresetStore {
  const parsed = JSON.parse(raw) as Partial<LegacyWorkspacePresetStore>;
  if (
    parsed.version !== LEGACY_STORE_VERSION ||
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

  return { version: LEGACY_STORE_VERSION, workspaces: parsed.workspaces };
}

function safeCanonicalWorkspace(directory: string): string {
  try {
    return fs.realpathSync(directory);
  } catch {
    return path.resolve(directory);
  }
}

export function getWorkspacePresetStorePath(directory: string): string {
  return projectStorePath(directory);
}

export function getLegacyWorkspacePresetStorePath(): string {
  return legacyStorePath();
}

export function readWorkspacePreset(directory: string): string | null {
  const storeFile = projectStorePath(directory);
  try {
    return parseProjectStore(fs.readFileSync(storeFile, 'utf8'), storeFile)
      .preset;
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

// Warn-only legacy probe: a stale global entry must never resolve, only hint
// at re-saving into the project-local store. Never throws.
function warnOnLegacySelection(directory: string): void {
  let raw: string;
  try {
    raw = fs.readFileSync(legacyStorePath(), 'utf8');
  } catch {
    return;
  }
  try {
    const store = parseLegacyStore(raw);
    const selection =
      store.workspaces[safeCanonicalWorkspace(directory)] ?? null;
    if (selection) {
      console.warn(
        `[oh-my-opencode-slim] Ignoring legacy global preset store ` +
          `${legacyStorePath()}: re-save with /preset or make preset to ` +
          `migrate "${selection}" to the project-local store.`,
      );
    }
  } catch {
    // Corrupt legacy data is trivia, not signal: stay silent.
  }
}

// No lock file: tmp write + atomic rename + readback verify is the whole
// protocol (F5). Rename is atomic on POSIX, so concurrent savers cannot
// interleave bytes; the last rename wins and the readback proves it.
function atomicWriteStore(storeFile: string, preset: string | null): void {
  fs.mkdirSync(path.dirname(storeFile), { recursive: true });
  const store: WorkspacePresetStore = {
    version: WORKSPACE_PRESET_STORE_VERSION,
    preset,
  };
  const temporaryPath = `${storeFile}.${process.pid}.${Date.now()}.tmp`;
  try {
    fs.writeFileSync(temporaryPath, `${JSON.stringify(store, null, 2)}\n`);
    fs.renameSync(temporaryPath, storeFile);
    const verified = parseProjectStore(
      fs.readFileSync(storeFile, 'utf8'),
      storeFile,
    );
    if (verified.preset !== preset) {
      throw new Error(
        `workspace preset store verification failed (${storeFile})`,
      );
    }
  } finally {
    fs.rmSync(temporaryPath, { force: true });
  }
}

export function saveWorkspacePreset(
  directory: string,
  presetName: string,
): string {
  const workspace = findProjectRoot(directory);
  const storeFile = path.join(workspace, STORE_REL_PATH);
  try {
    parseProjectStore(fs.readFileSync(storeFile, 'utf8'), storeFile);
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

  atomicWriteStore(storeFile, presetName);
  return workspace;
}

// Clear path for `make preset NAME=none`: drops the stored selection so
// launches fall through to the declared default or no preset.
export function clearWorkspacePreset(directory: string): string {
  const workspace = findProjectRoot(directory);
  atomicWriteStore(path.join(workspace, STORE_REL_PATH), null);
  return workspace;
}

// Single resolver (DIA-260918-yug6 M1+M2+M3, F4 single owner: doctor and the
// CLI defer to this function for the verdict). Five tiers, first hit wins:
// 1. PRESET env (explicit CLI override, fail-closed on unknown).
// 2. OPENCODE_WORKSPACE_PRESET bridge (deprecated, read-only: honored but
//    never written; reported as source `bridge`, fail-closed on unknown).
// 3. Project-local store (fail-closed on corrupt/unmatched).
// 4. Config `preset` field as declaredDefault (fail-closed on unknown).
// 5. none. Every throw names source + value + root + store path + available.
export function resolveWorkspacePreset(
  directory: string,
  presets: Record<string, Preset> | undefined,
  override = process.env.PRESET,
  declaredDefault?: string,
): WorkspacePresetResolution {
  const workspace = findProjectRoot(directory);
  const storeFile = path.join(workspace, STORE_REL_PATH);
  const available = presets ?? {};
  const availableLabel = Object.keys(available).join(', ') || 'none';
  const fail = (sourceLabel: string, value: string): Error =>
    new Error(
      `Preset "${value}" (source: ${sourceLabel}) not found for workspace ` +
        `${workspace}. Store: ${storeFile}. ` +
        `Available presets: ${availableLabel}`,
    );

  const explicit = override?.trim() ? (override as string).trim() : undefined;
  if (explicit !== undefined) {
    if (!Object.hasOwn(available, explicit)) {
      throw fail('PRESET override', explicit);
    }
    return { name: explicit, source: 'override', workspace };
  }

  // Deprecated host-launcher bridge: kept for the transition (the Makefile
  // still forwards it) but never written back. The distinct `bridge` source
  // is the deprecation telemetry (F6). Unknown values throw loudly.
  const bridged = process.env.OPENCODE_WORKSPACE_PRESET?.trim();
  if (bridged) {
    if (!Object.hasOwn(available, bridged)) {
      throw fail('OPENCODE_WORKSPACE_PRESET bridge (deprecated)', bridged);
    }
    return { name: bridged, source: 'bridge', workspace };
  }

  let stored: string | null;
  try {
    stored = readWorkspacePreset(directory);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Stored preset store ${storeFile} is invalid for workspace ` +
        `${workspace}: ${detail}. ` +
        `Available presets: ${availableLabel}`,
      { cause: error },
    );
  }
  if (stored !== null && stored !== '') {
    if (!Object.hasOwn(available, stored)) {
      throw fail('project store', stored);
    }
    return { name: stored, source: 'stored', workspace };
  }
  warnOnLegacySelection(directory);

  const declared = declaredDefault?.trim();
  if (declared) {
    if (!Object.hasOwn(available, declared)) {
      throw fail('config preset', declared);
    }
    return { name: declared, source: 'declared', workspace };
  }

  return { name: null, source: 'none', workspace };
}
