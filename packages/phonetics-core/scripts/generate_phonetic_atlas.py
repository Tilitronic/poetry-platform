#!/usr/bin/env python3
"""
Phonetic Atlas Generator — FlatBuffers binary from Panphon IPA data
====================================================================

Generates a single cross-language FlatBuffers binary asset (.bin) from
Panphon's IPA feature vector CSV files.

This is the implementation of §5 in architecture.md: the Phonetic Atlas,
a compiled-once, read-many asset consumed by:
  - W2 (TypeScript, via flatc-generated TS bindings)
  - analytics-pipeline (Python, via flatc-generated Python bindings)
  - Rust FST index (W1, via WASM)

USAGE:
    python generate_phonetic_atlas.py [--output PATH]

OUTPUT:
    A FlatBuffers binary file with file_identifier "PHAT".
    Default: ../src/atlas/phonetic_atlas.bin

DEPENDENCIES:
    - panphon (pip install panphon)
    - flatbuffers (pip install flatbuffers)
    - pandas (comes with panphon)

RATIONALE:
    - FlatBuffers 'struct' for FeatureVector (24 bytes, inline, zero-copy)
    - Content-addressed via SHA-256 hash embedded in metadata
    - File identifier "PHAT" for quick format identification
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from datetime import datetime, timezone

import pandas as pd

# ---------------------------------------------------------------------------
# Panphon integration — reads CSV data from the installed panphon package
# ---------------------------------------------------------------------------
try:
    import panphon
except ImportError:
    sys.exit("ERROR: panphon is required. Run: pip install panphon")

PANPHON_DATA_DIR = os.path.join(os.path.dirname(panphon.__file__), "data")
IPA_ALL_CSV = os.path.join(PANPHON_DATA_DIR, "ipa_all.csv")
IPA_BASES_CSV = os.path.join(PANPHON_DATA_DIR, "ipa_bases.csv")

# ---------------------------------------------------------------------------
# Feature schema — ordered list matching FeatureVector struct field positions
# ---------------------------------------------------------------------------
FEATURE_DEFS: list[dict[str, str]] = [
    {"key": "syl",     "long_name": "syllabic"},
    {"key": "son",     "long_name": "sonorant"},
    {"key": "cons",    "long_name": "consonantal"},
    {"key": "cont",    "long_name": "continuant"},
    {"key": "delrel",  "long_name": "delayed release"},
    {"key": "lat",     "long_name": "lateral"},
    {"key": "nas",     "long_name": "nasal"},
    {"key": "strid",   "long_name": "strident"},
    {"key": "voi",     "long_name": "voice"},
    {"key": "sg",      "long_name": "spread glottis"},
    {"key": "cg",      "long_name": "constricted glottis"},
    {"key": "ant",     "long_name": "anterior"},
    {"key": "cor",     "long_name": "coronal"},
    {"key": "distr",   "long_name": "distributed"},
    {"key": "lab",     "long_name": "labial"},
    {"key": "hi",      "long_name": "high"},
    {"key": "lo",      "long_name": "low"},
    {"key": "back",    "long_name": "back"},
    {"key": "round",   "long_name": "round"},
    {"key": "velaric", "long_name": "velaric"},
    {"key": "tense",   "long_name": "tense"},
    {"key": "long",    "long_name": "long"},
    {"key": "hitone",  "long_name": "high tone"},
    {"key": "hireg",   "long_name": "high register"},
]

# Value encoding — maps panphon CSV cell values to FeatureValue enum
VALUE_ENCODING: dict[str, str] = {
    "0": "unspecified / not applicable",
    "+": "positively specified (present)",
    "-": "negatively specified (absent)",
}

VALUE_TO_ENUM = {"0": 0, "+": 1, "-": 2}

# Generator version — increment when the schema or generation logic changes
GENERATOR_VERSION = "1.0.0"


def _feature_value(raw: str) -> int:
    """Map a panphon CSV cell ('+', '-', '0') to FeatureValue enum (0, 1, 2)."""
    return VALUE_TO_ENUM.get(raw.strip(), 0)


def parse_ipa_csv(path: str) -> pd.DataFrame:
    """Read one of the IPA CSVs with proper NA handling."""
    df = pd.read_csv(path, encoding="utf-8", dtype=str)
    df.fillna("0", inplace=True)
    return df


def compute_content_hash(all_segments: pd.DataFrame, base_ipa_set: set) -> str:
    """
    Compute a content-addressable SHA-256 hash over the canonical phoneme data.

    C4: Hash includes ALL fields that consumers read: IPA symbol, is_base flag,
    and all 24 feature values. This ensures any data change is detected.

    C1: IPA symbols are NFC-normalized before hashing, matching the lookup
    normalization in both the TS and Python loaders.

    Hash input format per phoneme (one per line, sorted by IPA):
        IPA:is_base:val0,val1,...,val23
    where is_base is 0/1 and feature values are 0, 1, or 2.
    """
    import unicodedata
    feature_cols = [c["key"] for c in FEATURE_DEFS]
    # Sort all segments by IPA for canonical ordering
    sorted_df = all_segments.sort_values("ipa")
    lines: list[str] = []
    for _, row in sorted_df.iterrows():
        ipa_nfc = unicodedata.normalize("NFC", str(row["ipa"]))
        is_base = "1" if row["ipa"] in base_ipa_set else "0"
        vals = ",".join(str(_feature_value(row.get(c, "0"))) for c in feature_cols)
        lines.append(f"{ipa_nfc}:{is_base}:{vals}")
    canonical = "\n".join(lines)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _import_generated_types():
    """Import flatc-generated Python bindings from dist/ or legacy location."""
    _generated_dirs = [
        os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "dist", "python")),
        os.path.normpath(os.path.join(os.path.dirname(__file__), "generated", "python")),
    ]
    for _g in _generated_dirs:
        if os.path.isdir(_g):
            sys.path.insert(0, _g)
            break
    else:
        sys.exit("ERROR: Generated Python bindings not found. Run: node scripts/codegen.js")


def _build_phoneme_entries(
    b: "flatbuffers.Builder",
    base_rows,
    derived_rows,
    base_ipa_set: set,
    feature_cols: list[str],
) -> tuple[list[int], int, int]:
    """
    Build all phoneme entry tables into the FlatBuffers builder.

    Returns (phoneme_offsets, total_segments, total_bases).
    C3: Shared by both passes — single implementation, no duplication.
    C1: IPA strings are NFC-normalized before storage.
    """
    import unicodedata
    from PhonemeEntry import (
        PhonemeEntryAddFeatures, PhonemeEntryAddIpa, PhonemeEntryAddIsBase,
        PhonemeEntryEnd, PhonemeEntryStart,
    )
    from FeatureVector import CreateFeatureVector

    phoneme_offsets: list[int] = []
    for df in (base_rows, derived_rows):
        for _, row in df.iterrows():
            # C1: NFC-normalize the IPA symbol so lookups are consistent
            # with the NFC normalization in load-atlas.ts and load_atlas.py
            raw_ipa = str(row["ipa"])
            nfc_ipa = unicodedata.normalize("NFC", raw_ipa)
            is_base = raw_ipa in base_ipa_set

            ipa_offset = b.CreateString(nfc_ipa)
            feat_vals = [_feature_value(row.get(c, "0")) for c in feature_cols]
            fv_offset = CreateFeatureVector(b, *feat_vals)

            # Struct slot MUST come first (assertStructIsInline constraint)
            PhonemeEntryStart(b)
            PhonemeEntryAddFeatures(b, fv_offset)
            PhonemeEntryAddIpa(b, ipa_offset)
            PhonemeEntryAddIsBase(b, is_base)
            phoneme_offsets.append(PhonemeEntryEnd(b))

    total_segments = len(phoneme_offsets)
    total_bases = len(base_rows)
    return phoneme_offsets, total_segments, total_bases


def _build_phonemes_vector(
    b: "flatbuffers.Builder", phoneme_offsets: list[int]
) -> int:
    """Build a FlatBuffers vector of phoneme entry table offsets."""
    from PhoneticAtlas import PhoneticAtlasStartPhonemesVector
    PhoneticAtlasStartPhonemesVector(b, len(phoneme_offsets))
    for offset in reversed(phoneme_offsets):
        b.PrependUOffsetTRelative(offset)
    return b.EndVector()


def _build_feature_defs_vector(b: "flatbuffers.Builder") -> int:
    """Build the FeatureDef metadata vector from FEATURE_DEFS."""
    from FeatureDef import (
        FeatureDefAddDoc, FeatureDefAddKey, FeatureDefAddLongName,
        FeatureDefEnd, FeatureDefStart,
    )
    from AtlasMetadata import AtlasMetadataStartFeaturesVector

    offsets: list[int] = []
    for fd in FEATURE_DEFS:
        key_off = b.CreateString(fd["key"])
        long_name_off = b.CreateString(fd["long_name"])
        doc_off = b.CreateString(fd.get("doc", ""))
        FeatureDefStart(b)
        FeatureDefAddKey(b, key_off)
        FeatureDefAddLongName(b, long_name_off)
        FeatureDefAddDoc(b, doc_off)
        offsets.append(FeatureDefEnd(b))

    AtlasMetadataStartFeaturesVector(b, len(offsets))
    for offset in reversed(offsets):
        b.PrependUOffsetTRelative(offset)
    return b.EndVector()


def _build_value_encoding_vector(b: "flatbuffers.Builder") -> int:
    """Build the value encoding description vector."""
    from AtlasMetadata import AtlasMetadataStartValueEncodingVector
    enc_offsets = [
        b.CreateString(f"{k} = {v}") for k, v in sorted(VALUE_ENCODING.items())
    ]
    AtlasMetadataStartValueEncodingVector(b, len(enc_offsets))
    for offset in reversed(enc_offsets):
        b.PrependUOffsetTRelative(offset)
    return b.EndVector()


def _build_metadata_table(
    b: "flatbuffers.Builder",
    source_name: str,
    panphon_version: str,
    generated_at: str,
    content_hash: str,
    total_segments: int,
    total_bases: int,
    features_vector: int,
    value_encoding_vector: int,
) -> int:
    """Build the AtlasMetadata table."""
    from AtlasMetadata import (
        AtlasMetadataAddContentHash, AtlasMetadataAddFeatures,
        AtlasMetadataAddGeneratedAt, AtlasMetadataAddGeneratorName,
        AtlasMetadataAddGeneratorVersion, AtlasMetadataAddSourceName,
        AtlasMetadataAddSourceVersion, AtlasMetadataAddTotalBases,
        AtlasMetadataAddTotalSegments, AtlasMetadataAddValueEncoding,
        AtlasMetadataEnd, AtlasMetadataStart,
    )

    source_name_off = b.CreateString(source_name)
    source_ver_off = b.CreateString(panphon_version)
    gen_name_off = b.CreateString("generate_phonetic_atlas.py")
    gen_ver_off = b.CreateString(GENERATOR_VERSION)
    gen_at_off = b.CreateString(generated_at)
    hash_off = b.CreateString(content_hash)

    AtlasMetadataStart(b)
    AtlasMetadataAddSourceName(b, source_name_off)
    AtlasMetadataAddSourceVersion(b, source_ver_off)
    AtlasMetadataAddGeneratorName(b, gen_name_off)
    AtlasMetadataAddGeneratorVersion(b, gen_ver_off)
    AtlasMetadataAddGeneratedAt(b, gen_at_off)
    AtlasMetadataAddContentHash(b, hash_off)
    AtlasMetadataAddTotalSegments(b, total_segments)
    AtlasMetadataAddTotalBases(b, total_bases)
    AtlasMetadataAddFeatures(b, features_vector)
    AtlasMetadataAddValueEncoding(b, value_encoding_vector)
    return AtlasMetadataEnd(b)


def _write_atlas(
    b: "flatbuffers.Builder",
    metadata_offset: int,
    phonemes_vector: int,
    output_path: str,
) -> bytes:
    """Finalize and write the FlatBuffers binary."""
    from PhoneticAtlas import (
        PhoneticAtlasAddMetadata, PhoneticAtlasAddPhonemes,
        PhoneticAtlasEnd, PhoneticAtlasStart,
    )
    PhoneticAtlasStart(b)
    PhoneticAtlasAddMetadata(b, metadata_offset)
    PhoneticAtlasAddPhonemes(b, phonemes_vector)
    root_offset = PhoneticAtlasEnd(b)
    b.Finish(root_offset, file_identifier=b"PHAT")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    buf = b.Output()
    with open(output_path, "wb") as f:
        f.write(bytes(buf))
    return bytes(buf)


def build_phonetic_atlas(output_path: str) -> str:
    """
    Build and write the FlatBuffers PhoneticAtlas binary.

    Returns the content_hash string for the caller to use (e.g., for
    writing a .sha256 sidecar file).

    C3: Single-pass phoneme building via _build_phoneme_entries shared
    function. The hash is computed from canonical data (format-independent),
    so no two-pass rebuild is needed — we build once with the real hash.
    """
    import flatbuffers
    _import_generated_types()
    from PhoneticAtlas import PhoneticAtlasStartPhonemesVector
    from PhonemeEntry import (
        PhonemeEntryAddFeatures, PhonemeEntryAddIpa, PhonemeEntryAddIsBase,
        PhonemeEntryEnd, PhonemeEntryStart,
    )
    from FeatureVector import CreateFeatureVector

    # -------------------------------------------------------------------
    # Read and prepare source data
    # -------------------------------------------------------------------
    bases_df = parse_ipa_csv(IPA_BASES_CSV)
    all_segments_df = parse_ipa_csv(IPA_ALL_CSV)
    base_ipa_set = set(bases_df["ipa"].tolist())

    # Build phoneme list: bases first, then derived. Within each group,
    # sort by IPA symbol for deterministic ordering.
    base_mask = all_segments_df["ipa"].isin(base_ipa_set)
    base_rows = all_segments_df[base_mask].copy()
    derived_rows = all_segments_df[~base_mask].copy()
    base_rows.sort_values("ipa", inplace=True)
    derived_rows.sort_values("ipa", inplace=True)

    # C8: Warn about base phonemes not found in ipa_all.csv
    all_ipa_set = set(all_segments_df["ipa"].tolist())
    missing_bases = base_ipa_set - all_ipa_set
    if missing_bases:
        print(f"  WARNING: {len(missing_bases)} base phonemes not in ipa_all.csv:")
        for sym in sorted(missing_bases):
            print(f"    - {repr(sym)}")

    # -------------------------------------------------------------------
    # Source metadata
    # -------------------------------------------------------------------
    panphon_version = "0.22.2"
    try:
        import importlib.metadata
        panphon_version = importlib.metadata.version("panphon")
    except Exception:
        print(f"  WARNING: Could not determine Panphon version, using {panphon_version}")
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    feature_cols = [c["key"] for c in FEATURE_DEFS]

    # -------------------------------------------------------------------
    # Hash first (from canonical data) — then build once with real hash
    # -------------------------------------------------------------------
    content_hash = compute_content_hash(all_segments_df, base_ipa_set)

    print(f"  Content hash (SHA-256): {content_hash}")
    print(f"  Total segments:         {len(all_segments_df)}")
    print(f"  Total bases:            {len(base_rows)}")

    # -------------------------------------------------------------------
    # Single build pass with extracted shared functions
    # -------------------------------------------------------------------
    b = flatbuffers.Builder(1024)

    # 1. Build phoneme entries (shared implementation, one place)
    phoneme_offsets, total_segments, total_bases = _build_phoneme_entries(
        b, base_rows, derived_rows, base_ipa_set, feature_cols
    )

    # 2. Build vectors (shared implementations)
    phonemes_vector = _build_phonemes_vector(b, phoneme_offsets)
    features_vector = _build_feature_defs_vector(b)
    value_encoding_vector = _build_value_encoding_vector(b)

    # 3. Build metadata with real content hash
    metadata_offset = _build_metadata_table(
        b, "Panphon", panphon_version, generated_at,
        content_hash, total_segments, total_bases,
        features_vector, value_encoding_vector,
    )

    # 4. Finalize and write
    final_buf = _write_atlas(b, metadata_offset, phonemes_vector, output_path)

    file_size_kb = len(final_buf) / 1024
    print(f"  Output size:            {file_size_kb:.1f} KB")
    print(f"  Written to:             {output_path}")

    return content_hash


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Phonetic Atlas FlatBuffers binary from Panphon data"
    )
    script_dir = os.path.dirname(__file__)
    default_output = os.path.normpath(
        os.path.join(script_dir, "..", "src", "atlas", "phonetic_atlas.bin")
    )
    parser.add_argument(
        "--output",
        default=default_output,
        help=f"Output path for the FlatBuffers binary (default: {default_output})",
    )
    parser.add_argument(
        "--dist",
        default=None,
        help="Also copy the binary to a dist/ directory for consumption",
    )
    parser.add_argument(
        "--inspect",
        action="store_true",
        help="After generation, read back and print summary for verification",
    )
    args = parser.parse_args()

    import shutil

    print("=== Phonetic Atlas Generator ===")
    print(f"  Source: {IPA_ALL_CSV}")
    print(f"  Bases:  {IPA_BASES_CSV}")
    print()

    content_hash = build_phonetic_atlas(args.output)

    # Write .sha256 sidecar file (C2: content hash for independent verification)
    sha256_path = args.output + ".sha256"
    with open(sha256_path, "w", encoding="utf-8") as f:
        f.write(f"{content_hash}  {os.path.basename(args.output)}\n")
    print(f"  SHA-256 sidecar:        {sha256_path}")

    # Also copy to dist/ if requested (or auto-detect dist/ path)
    dist_arg = args.dist
    if dist_arg is not None:
        dist_dir = os.path.normpath(
            dist_arg if os.path.isabs(dist_arg)
            else os.path.join(script_dir, "..", dist_arg)
        )
        if os.path.isdir(dist_dir):
            dist_dest = os.path.join(dist_dir, "phonetic_atlas.bin")
        else:
            dist_dest = dist_dir
        os.makedirs(os.path.dirname(dist_dest), exist_ok=True)
        shutil.copy2(args.output, dist_dest)
        print(f"  Also copied to:         {dist_dest}")
        # Also copy .sha256 to dist/
        sha256_dest = dist_dest + ".sha256"
        shutil.copy2(sha256_path, sha256_dest)
        print(f"  SHA-256 sidecar:        {sha256_dest}")
    else:
        auto_dist_dir = os.path.normpath(
            os.path.join(script_dir, "..", "dist")
        )
        if os.path.isdir(auto_dist_dir):
            dist_dest = os.path.join(auto_dist_dir, "phonetic_atlas.bin")
            shutil.copy2(args.output, dist_dest)
            print(f"  Also copied to:         {dist_dest}")
            sha256_dest = dist_dest + ".sha256"
            shutil.copy2(sha256_path, sha256_dest)

    if args.inspect:
        print()
        print("=== Verification: Reading back ===")
        verify_atlas(args.output)


def verify_atlas(path: str) -> None:
    """Read back the FlatBuffer and print a summary for manual verification."""
    import flatbuffers

    sys.path.insert(
        0,
        os.path.normpath(
            os.path.join(os.path.dirname(__file__), "generated", "python")
        ),
    )
    from PhoneticAtlas import PhoneticAtlas
    from FeatureVector import FeatureVector

    with open(path, "rb") as f:
        buf = f.read()

    atlas = PhoneticAtlas.GetRootAsPhoneticAtlas(buf, 0)

    # Verify file identifier
    has_id = PhoneticAtlas.PhoneticAtlasBufferHasIdentifier(buf, 0)
    print(f"  Valid file identifier (PHAT): {has_id}")

    meta = atlas.Metadata()
    if meta:
        # Decode bytes to str for display (FlatBuffers Python returns bytes)
        def _s(b: bytes | None) -> str:
            return b.decode("utf-8") if b else ""

        print(f"  Source: {_s(meta.SourceName())} {_s(meta.SourceVersion())}")
        print(f"  Generator: {_s(meta.GeneratorName())} v{_s(meta.GeneratorVersion())}")
        print(f"  Generated: {_s(meta.GeneratedAt())}")
        print(f"  Content hash: {_s(meta.ContentHash())}")
        print(f"  Total segments: {meta.TotalSegments()}")
        print(f"  Total bases: {meta.TotalBases()}")
        print(f"  Features defined: {meta.FeaturesLength()}")

        # Sample features
        for i in range(min(3, meta.FeaturesLength())):
            fd = meta.Features(i)
            print(f"    [{i}] {_s(fd.Key())} = {_s(fd.LongName())}")

        # Value encoding
        if meta.ValueEncodingLength() > 0:
            print(f"  Value encodings ({meta.ValueEncodingLength()}):")
            for i in range(meta.ValueEncodingLength()):
                print(f"    {_s(meta.ValueEncoding(i))}")

    # Print first and last phoneme as samples
    n = atlas.PhonemesLength()
    print(f"  Total phoneme entries: {n}")
    for idx in [0, 1, n - 2, n - 1]:
        if idx >= n:
            continue
        p = atlas.Phonemes(idx)
        fv = p.Features()
        feat_str = ",".join(
            str(
                getattr(fv, col_name)()
                if hasattr(fv, col_name)
                else 0
            )
            for col_name in ["Syl", "Son", "Cons"]
        )
        ipa_str = p.Ipa().decode("utf-8") if p.Ipa() else "?"
        print(f"  [{idx:4d}] IPA={ipa_str:>8s}  base={p.IsBase()}  features(syl,son,cons)=({feat_str})")

    print()
    print("  Verification complete.")


if __name__ == "__main__":
    main()
