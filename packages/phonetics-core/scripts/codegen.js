#!/usr/bin/env node
/**
 * Phonetic Atlas Codegen — Multi-language FlatBuffers code generation
 * ====================================================================
 *
 * Runs flatc for all target languages defined in architecture.md §5:
 *   - TypeScript  → dist/ts/   (W2 worker, author-studio)
 *   - Python      → dist/python/ (analytics-pipeline)
 *   - Rust        → dist/rust/  (W1 FST index, via WASM)
 *   - C++         → dist/cpp/   (future ultra-low-latency modules)
 *
 * Also copies the last-generated .bin to dist/ for consumption.
 *
 * USAGE:
 *   node scripts/codegen.js
 *
 * PREREQUISITES:
 *   flatc must be on PATH (or set FLATC=/path/to/flatc)
 *
 * See architecture.md §5 "Phonetic Atlas — the cross-language data asset"
 */

import { execSync } from 'node:child_process';
import { existsSync, copyFileSync, mkdirSync, statSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG = resolve(__dirname, '..');
const SCHEMA = resolve(PKG, 'src/atlas/phonetic_atlas.fbs');
const DIST = resolve(PKG, 'dist');
const BIN_SRC = resolve(PKG, 'src/atlas/phonetic_atlas.bin');

// flatc binary location: either from env FLATC, or on PATH
const FLATC = process.env.FLATC || 'flatc';

// Language targets and their output directories
// Supported flags: --ts, --python, --rust, --cpp, --c, --java, --go, --csharp, --kotlin, --swift, --php, --dart, --lobster
const LANGUAGES = [
  { name: 'TypeScript',  out: 'ts',     args: ['--ts', '--gen-object-api'] },
  { name: 'Python',      out: 'python', args: ['--python'] },
  { name: 'Rust',        out: 'rust',   args: ['--rust'] },
  { name: 'C++',         out: 'cpp',    args: ['--cpp', '--cpp-ptr-type', 'unique_ptr'] },
  // C: flatc v25 does not have a dedicated --c flag. If C bindings are needed,
  // use the C++ generated header with extern "C" wrappers.
];

function main() {
  console.log('=== Phonetic Atlas — Multi-language Codegen ===\n');

  // Ensure schema exists
  if (!existsSync(SCHEMA)) {
    console.error(`ERROR: Schema not found: ${SCHEMA}`);
    process.exit(1);
  }

  // Check flatc availability
  try {
    const version = execSync(`"${FLATC}" --version`, { encoding: 'utf-8' }).trim();
    console.log(`  flatc: ${version}\n`);
  } catch {
    console.error(`ERROR: flatc not found at "${FLATC}". Install from:\n`);
    console.error('  https://github.com/google/flatbuffers/releases');
    console.error('  Or set FLATC env var: $env:FLATC="path\\to\\flatc.exe"\n');
    process.exit(1);
  }

  // Create dist/ directories and run flatc for each language
  for (const lang of LANGUAGES) {
    const outDir = resolve(DIST, lang.out);
    mkdirSync(outDir, { recursive: true });

    console.log(`  [${lang.name}] generating → ${outDir}`);

    const cmd = [
      `"${FLATC}"`,
      ...lang.args,
      `-o "${outDir}"`,
      `"${SCHEMA}"`,
    ].join(' ');

    try {
      const out = execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
      if (out.trim()) console.log(`    ${out.trim()}`);
      console.log(`    ✓ ${lang.name} bindings generated`);
    } catch (e) {
      const stderr = e.stderr?.trim() || e.message;
      console.error(`    ✗ FAILED: ${stderr}`);
      // Non-fatal — some languages may have missing toolchain pieces
      // (e.g., Rust flatc generator requires rust_common.fbs)
    }
  }

  // Copy .bin to dist/ for easy consumption
  if (existsSync(BIN_SRC)) {
    const binDest = resolve(DIST, 'phonetic_atlas.bin');
    copyFileSync(BIN_SRC, binDest);
    const sizeKb = (existsSync(BIN_SRC) ? statSync(BIN_SRC).size : 0) / 1024;
    console.log(`\n  Binary: copied → ${binDest} (${sizeKb.toFixed(1)} KB)`);
  } else {
    console.log(`\n  WARNING: Binary not found at ${BIN_SRC}.`);
    console.log('  Run `pnpm generate:phonetic-atlas` first to generate it.');
  }

  console.log('\n=== Codegen complete ===');
}

main();
