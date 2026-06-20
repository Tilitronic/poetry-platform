/**
 * Phonetic Atlas Loader — TypeScript entry point for W2
 * =========================================================
 *
 * Loads the compiled FlatBuffers Phonetic Atlas (.bin) into an
 * ArrayBuffer and provides zero-copy access to phoneme feature vectors.
 *
 * WHY a separate loader module:
 *   - The FlatBuffers binary is a static asset checked into the repo
 *     (see architecture.md §5). This loader encapsulates the binary
 *     load, buffer verification (file identifier), and provides a
 *     convenient lookup API with NFC-normalized index.
 *   - Zero-copy: FeatureVector is a 'struct' (fixed 24 bytes inline).
 *     Reading a single field does NOT parse the entire buffer — the
 *     data is already at the correct offset.
 *
 * IPA NORMALIZATION POLICY:
 *   ALL IPA strings are normalized to NFC (Normalization Form Canonical
 *   Composition) on both index build and lookup. This ensures that
 *   a query for "ä" (U+00E4, precomposed) finds the same entry as
 *   "a\u0308" (U+0061 + U+0308, decomposed). Both the generator
 *   (Python) and this loader (TypeScript) must agree on NFC.
 *
 * USAGE:
 *   import { PhoneticAtlasIndex } from './atlas/load-atlas';
 *   const atlas = PhoneticAtlasIndex.fromBuffer(response.arrayBuffer());
 *   const phoneme = atlas.get('p');
 *   if (phoneme) {
 *     console.log(phoneme.ipa, phoneme.features.voi());
 *   }
 *
 * CONSUMPTION PATTERN (per architecture.md §5):
 *   - W2 (TS)       → this module, loaded once at worker init
 *   - Python        → load_atlas.py (flatc Python bindings + mmap)
 *   - Rust FST (W1) → native FlatBuffers Rust bindings
 */

import * as flatbuffers from 'flatbuffers';
import { PhoneticAtlas } from './generated/phonetic-atlas';
import type { AtlasMetadata } from './generated/atlas-metadata';
import type { PhonemeEntry } from './generated/phoneme-entry';
import type { FeatureVector } from './generated/feature-vector';

/**
 * Error thrown when the atlas data is structurally corrupted.
 * This is a distinct error type so consumers can differentiate
 * "phoneme not found" from "atlas data corrupt".
 */
export class AtlasCorruptionError extends Error {
  constructor(message: string) {
    super(`[PhoneticAtlas] ${message}`);
    this.name = 'AtlasCorruptionError';
  }
}

// ---------------------------------------------------------------------------
// Public types — re-exported for consumer convenience
// ---------------------------------------------------------------------------
export type { AtlasMetadata, PhonemeEntry, FeatureVector };

/**
 * Feature value enum matching the FlatBuffers schema.
 *
 *   0 = Unspecified / not applicable  (panphon "0")
 *   1 = Positively specified          (panphon "+")
 *   2 = Negatively specified          (panphon "-")
 */
export enum FeatureValue {
  Unspecified = 0,
  Positive = 1,
  Negative = 2,
}

/**
 * Decoded phoneme entry with zero-copy feature vector access.
 */
export interface PhonemeInfo {
  /** IPA symbol (e.g., "p", "aɪ"), NFC-normalized */
  readonly ipa: string;
  /** True if this is a base phoneme */
  readonly isBase: boolean;
  /** Phonological feature vector (zero-copy struct access) */
  readonly features: FeatureVector;
}

/**
 * Runtime metadata extracted from the FlatBuffers atlas header.
 */
export interface AtlasInfo {
  readonly sourceName: string;
  readonly sourceVersion: string;
  readonly generatorName: string;
  readonly generatorVersion: string;
  readonly generatedAt: string;
  readonly contentHash: string;
  readonly totalSegments: number;
  readonly totalBases: number;
  readonly featureCount: number;
}

/**
 * Phonetic Atlas — zero-copy access to the phoneme feature vector set.
 *
 * Loaded once at process/worker init. The internal `_atlas` reference
 * holds the FlatBuffers root table; all access methods read directly
 * from the underlying ArrayBuffer without intermediate allocations.
 *
 * IPA LOOKUP NORMALIZATION:
 *   All IPA strings are stored and queried in NFC form. This means:
 *     atlas.get("ä") === atlas.get("a\u0308")  // both find the same entry
 *   The index stores NFC keys; the lookup function normalizes input to NFC.
 */
export class PhoneticAtlasIndex {
  private readonly _atlas: PhoneticAtlas;
  /** IPA-symbol (NFC) → index lookup. Built once at load time. */
  private readonly _index: Map<string, number>;

  private constructor(atlas: PhoneticAtlas) {
    this._atlas = atlas;

    // Build IPA → index map for O(1) lookup. The phoneme table is small
    // (<7000 entries), so Map memory overhead (~48 bytes per entry) is
    // negligible compared to the speed gain on every stress lookup.
    const n = this._atlas.phonemesLength();
    const idx = new Map<string, number>();
    for (let i = 0; i < n; i++) {
      const p = this._atlas.phonemes(i);
      if (!p) continue;

      const rawIpa = p.ipa();
      if (rawIpa === null || rawIpa === undefined) {
        // C5: Null IPA in the binary is data corruption. The schema
        // marks ipa as (required), so this should never happen with a
        // valid atlas. We throw rather than silently skipping — a
        // corrupted atlas should fail loudly, not silently lose entries.
        throw new AtlasCorruptionError(
          `Null IPA at phoneme index ${i}. Atlas binary is corrupt.`,
        );
      }

      // C1: NFC normalization — all IPA symbols stored as NFC.
      // Panphon source data uses NFC for precomposed diacritics.
      // Without normalization, lookups for composed vs decomposed
      // forms of the same symbol produce false negatives.
      const nfcIpa = rawIpa.normalize('NFC');
      if (idx.has(nfcIpa)) {
        // Duplicate IPA after NFC normalization. This can happen if
        // the source data has two different entries that normalize
        // to the same string. Last-write wins — log a warning.
        console.warn(
          `[PhoneticAtlas] Duplicate NFC-normalized IPA: "${nfcIpa}" ` +
          `at index ${i} (overwrites index ${idx.get(nfcIpa)})`,
        );
      }
      idx.set(nfcIpa, i);
    }
    this._index = idx;
  }

  // -----------------------------------------------------------------------
  // Factory
  // -----------------------------------------------------------------------

  /**
   * Create a PhoneticAtlasIndex from an ArrayBuffer containing the
   * compiled FlatBuffers binary.
   *
   * @param buffer - The raw bytes of phonetic_atlas.bin
   * @returns A ready-to-use index
   * @throws AtlasCorruptionError if the buffer lacks the "PHAT" identifier
   */
  static fromBuffer(buffer: ArrayBuffer | Uint8Array): PhoneticAtlasIndex {
    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);

    // C7: Validate the "PHAT" file identifier BEFORE parsing.
    // Without this check, garbage bytes would be parsed as an atlas,
    // producing silently wrong results from random offsets.
    if (!bytes || bytes.length < 8) {
      throw new AtlasCorruptionError(
        'Buffer too small for FlatBuffers file identifier. Expected at least 8 bytes.',
      );
    }
    if (!PhoneticAtlas.bufferHasIdentifier(new flatbuffers.ByteBuffer(bytes))) {
      throw new AtlasCorruptionError(
        'Buffer does not have the "PHAT" file identifier. ' +
        'Expected a valid Phonetic Atlas FlatBuffers binary.',
      );
    }

    const bb = new flatbuffers.ByteBuffer(bytes);
    const atlas = PhoneticAtlas.getRootAsPhoneticAtlas(bb);
    return new PhoneticAtlasIndex(atlas);
  }

  /**
   * Verify the buffer has the correct "PHAT" file identifier.
   *
   * This is a cheap check (just 4 bytes at a known offset).
   */
  static hasValidIdentifier(buffer: ArrayBuffer | Uint8Array): boolean {
    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
    if (bytes.length < 8) return false;
    return PhoneticAtlas.bufferHasIdentifier(new flatbuffers.ByteBuffer(bytes));
  }

  // -----------------------------------------------------------------------
  // Metadata
  // -----------------------------------------------------------------------

  /** Runtime metadata from the atlas header. */
  get metadata(): AtlasInfo | null {
    const m = this._atlas.metadata();
    if (!m) return null;
    return {
      sourceName: m.sourceName() ?? '',
      sourceVersion: m.sourceVersion() ?? '',
      generatorName: m.generatorName() ?? '',
      generatorVersion: m.generatorVersion() ?? '',
      generatedAt: m.generatedAt() ?? '',
      contentHash: m.contentHash() ?? '',
      totalSegments: m.totalSegments(),
      totalBases: m.totalBases(),
      featureCount: m.featuresLength(),
    };
  }

  // -----------------------------------------------------------------------
  // Lookup
  // -----------------------------------------------------------------------

  /**
   * Look up a phoneme by its IPA symbol.
   *
   * The input IPA is normalized to NFC before lookup, so composed and
   * decomposed forms of the same symbol are treated as equivalent.
   *
   * @returns PhonemeInfo with zero-copy feature vector, or null if not found
   */
  get(ipa: string): PhonemeInfo | null {
    // C1: NFC-normalize the query string to match the index keys
    const normalized = ipa.normalize('NFC');
    const i = this._index.get(normalized);
    if (i === undefined) return null;
    return this._entryAt(i);
  }

  /**
   * Get a phoneme by its positional index in the atlas.
   *
   * Useful for iterating all phonemes or for fast random access
   * when the index is already known.
   */
  at(index: number): PhonemeInfo | null {
    if (index < 0 || index >= this._atlas.phonemesLength()) return null;
    return this._entryAt(index);
  }

  /**
   * Iterate all phonemes in the atlas.
   *
   * Yields PhonemeInfo objects with zero-copy feature vector access.
   * The returned objects are valid only during iteration; they share
   * the underlying ArrayBuffer and do not allocate copies.
   *
   * @yields PhonemeInfo for each valid entry.
   * @throws AtlasCorruptionError if any entry has null features.
   */
  *entries(): IterableIterator<PhonemeInfo> {
    const n = this._atlas.phonemesLength();
    for (let i = 0; i < n; i++) {
      // C6: Don't skip corrupted entries — fail loud so the consumer
      // knows the atlas is unreliable rather than silently losing data.
      yield this._entryAtOrThrow(i);
    }
  }

  /** Total number of phoneme entries in the atlas. */
  get size(): number {
    return this._atlas.phonemesLength();
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  /**
   * Safe accessor — returns null for out-of-bounds, but throws on
   * structural corruption (null features).
   *
   * This is the "lenient" version used by get() and at() — null means
   * "phoneme doesn't exist", which is a normal case for user queries.
   * But if the phoneme DOES exist and its data is corrupt, we throw.
   */
  private _entryAt(index: number): PhonemeInfo | null {
    const p = this._atlas.phonemes(index);
    if (!p) return null;

    // C6: Null features = corrupted entry. We throw rather than returning
    // null because null would be indistinguishable from "phoneme not found"
    // to the caller. A corrupted atlas is a hard failure, not a soft miss.
    const fv = p.features();
    if (!fv) {
      throw new AtlasCorruptionError(
        `Null feature vector at phoneme index ${index}. Atlas binary is corrupt.`,
      );
    }

    // C1: NFC-normalize the returned IPA so that all surfaces are NFC
    const rawIpa = p.ipa();
    return {
      ipa: rawIpa ? rawIpa.normalize('NFC') : '',
      isBase: p.isBase(),
      features: fv,
    };
  }

  /**
   * Strict accessor — used by entries() iteration. Throws on ANY
   * null (corrupt entry or corrupt feature vector).
   */
  private _entryAtOrThrow(index: number): PhonemeInfo {
    const p = this._atlas.phonemes(index);
    if (!p) {
      throw new AtlasCorruptionError(
        `Null phoneme entry at index ${index}. Atlas binary is corrupt.`,
      );
    }
    const fv = p.features();
    if (!fv) {
      throw new AtlasCorruptionError(
        `Null feature vector at phoneme index ${index}. Atlas binary is corrupt.`,
      );
    }
    const rawIpa = p.ipa();
    return {
      ipa: rawIpa ? rawIpa.normalize('NFC') : '',
      isBase: p.isBase(),
      features: fv,
    };
  }
}
