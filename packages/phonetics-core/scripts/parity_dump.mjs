#!/usr/bin/env node
/**
 * Parity dump — loads the atlas via the TS loader and prints feature vectors as JSON.
 * Used by the Python parity test (test_parity.py) to compare TS vs Python.
 *
 * Usage: node scripts/parity_dump.mjs
 * Output: {"p": {"syl":2,"cons":1,...}, "a": {...}, ...}
 */
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PhoneticAtlasIndex } from '../src/atlas/load-atlas.ts';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ATLAS_PATH = resolve(__dirname, '../src/atlas/phonetic_atlas.bin');
const bytes = readFileSync(ATLAS_PATH);
const atlas = PhoneticAtlasIndex.fromBuffer(bytes);

const FIELDS = [
  'syl',
  'son',
  'cons',
  'cont',
  'delrel',
  'lat',
  'nas',
  'strid',
  'voi',
  'sg',
  'cg',
  'ant',
  'cor',
  'distr',
  'lab',
  'hi',
  'lo',
  'back',
  'round',
  'velaric',
  'tense',
  'long',
  'hitone',
  'hireg',
];
const PHONEMES = ['p', 'a', 'm', 's', '\u0261', 't', 'k', 'i', 'u', 'n'];

const out = {};
for (const sym of PHONEMES) {
  const entry = atlas.get(sym);
  if (!entry) {
    out[sym] = null;
    continue;
  }
  const fv = entry.features;
  const vec = {};
  for (const f of FIELDS) vec[f] = fv[f]();
  out[sym] = vec;
}
// Also include metadata for parity
out['__metadata__'] = {
  totalSegments: atlas.size,
  sourceName: atlas.metadata.sourceName,
  featureCount: atlas.metadata.featureCount,
};
console.log(JSON.stringify(out));
