"""
Phonetic Atlas Loader — Python entry point for analytics-pipeline
==================================================================

Loads the compiled FlatBuffers Phonetic Atlas (.bin) via memory-mapped
file (mmap) and provides typed access to phoneme feature vectors with
zero-copy reads.

WHY mmap:
  - The atlas is a static, read-heavy asset (~305 KB, 6367 entries).
  - mmap maps the file into the process virtual address space — the OS
    pages in data on demand, and no Python allocation occurs for the
    raw buffer.
  - FeatureVector is a struct (inline, fixed 24 bytes) — reading a
    single field reads directly from mapped memory.

WHY a separate module (#2 in the guide):
  - flatc-generated Python bindings provide GetRootAs / low-level
    access. This module wraps them in a convenient PhoneticAtlasIndex
    with dict-based IPA→entry lookup.
  - The analytics pipeline (analytics-pipeline/src/core/numpy_calc.py)
    imports this to transform feature vectors into C-contiguous NumPy
    arrays.

USAGE:
    from atlas.load_atlas import load_phonetic_atlas
    atlas = load_phonetic_atlas("path/to/phonetic_atlas.bin")
    phoneme = atlas.get("p")
    if phoneme:
        print(phoneme.features.Cons())  # 1 = [+consonantal]

See architecture.md §5 "Phonetic Atlas — the cross-language data asset"
"""

from __future__ import annotations

import mmap
import os
import unicodedata
from typing import Optional


class AtlasCorruptionError(Exception):
    """Raised when the atlas binary is structurally corrupted."""
    pass

# ---------------------------------------------------------------------------
# FlatBuffers Python bindings (flatc-generated from phonetic_atlas.fbs)
#
# These are imported from the dist/python/ directory of the phonetics-core
# package. The import path works when:
#   - Running from within the monorepo (workspace path resolves it)
#   - The package is installed via pip -e or the dist-info is present
# ---------------------------------------------------------------------------
try:
    from PhoneticAtlas import PhoneticAtlas  # type: ignore[import-not-found]
    from PhonemeEntry import PhonemeEntry  # type: ignore[import-not-found]
    from FeatureVector import FeatureVector  # type: ignore[import-not-found]
    from AtlasMetadata import AtlasMetadata  # type: ignore[import-not-found]
except ImportError:
    # Fallback: try to find generated bindings relative to this file
    _PKG_DIR = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "..", "dist", "python")
    )
    if os.path.isdir(_PKG_DIR):
        import sys
        sys.path.insert(0, _PKG_DIR)
        from PhoneticAtlas import PhoneticAtlas  # type: ignore[import-not-found]
        from PhonemeEntry import PhonemeEntry  # type: ignore[import-not-found]
        from FeatureVector import FeatureVector  # type: ignore[import-not-found]
        from AtlasMetadata import AtlasMetadata  # type: ignore[import-not-found]
    else:
        raise ImportError(
            "FlatBuffers generated Python bindings not found. "
            "Run: pnpm --filter @poetry/phonetics-core codegen"
        )


class PhonemeInfo:
    """Decoded phoneme entry with zero-copy feature vector access."""

    __slots__ = ("ipa", "is_base", "features")

    def __init__(
        self,
        ipa: str,
        is_base: bool,
        features: FeatureVector,
    ) -> None:
        self.ipa = ipa
        self.is_base = is_base
        self.features = features  # Zero-copy struct — reads from mmap'd memory


class AtlasMetadataInfo:
    """Metadata extracted from the FlatBuffers atlas header."""

    __slots__ = (
        "source_name", "source_version",
        "generator_name", "generator_version",
        "generated_at", "content_hash",
        "total_segments", "total_bases",
        "feature_count",
    )

    def __init__(self, meta: AtlasMetadata) -> None:
        def _s(b: Optional[bytes]) -> str:
            return b.decode("utf-8") if b else ""
        self.source_name = _s(meta.SourceName())
        self.source_version = _s(meta.SourceVersion())
        self.generator_name = _s(meta.GeneratorName())
        self.generator_version = _s(meta.GeneratorVersion())
        self.generated_at = _s(meta.GeneratedAt())
        self.content_hash = _s(meta.ContentHash())
        self.total_segments = meta.TotalSegments()
        self.total_bases = meta.TotalBases()
        self.feature_count = meta.FeaturesLength()


class PhoneticAtlasIndex:
    """
    Phonetic Atlas — zero-copy access to the phoneme feature vector set.

    Loaded once at process start. The internal `_atlas` reference holds
    the FlatBuffers root table; all access methods read directly from
    the memory-mapped buffer without intermediate allocations.
    """

    def __init__(self, atlas: PhoneticAtlas) -> None:
        self._atlas = atlas
        # Build IPA → index dict for O(1) lookup
        # C1: All IPA symbols are NFC-normalized. This ensures composed
        # and decomposed forms of the same symbol map to the same entry.
        n = self._atlas.PhonemesLength()
        self._index: dict[str, int] = {}
        for i in range(n):
            p = self._atlas.Phonemes(i)
            if not p:
                continue
            ipa_bytes = p.Ipa()
            if ipa_bytes is None:
                # C5: Null IPA = data corruption. Schema marks ipa as
                # (required), so this should never happen in valid data.
                raise AtlasCorruptionError(
                    f"Null IPA at phoneme index {i}. Atlas binary is corrupt."
                )
            ipa = unicodedata.normalize("NFC", ipa_bytes.decode("utf-8"))
            if ipa in self._index:
                import warnings
                warnings.warn(
                    f"Duplicate NFC-normalized IPA: '{ipa}' at index {i} "
                    f"(overwrites index {self._index[ipa]})"
                )
            self._index[ipa] = i

    # -------------------------------------------------------------------
    # Factory
    # -------------------------------------------------------------------

    @classmethod
    def from_path(cls, path: str) -> "PhoneticAtlasIndex":
        """
        Load the atlas from a binary file using memory-mapped I/O.

        The file is mapped into the process address space (mmap) — the
        OS handles paging, and no Python buffer allocation occurs for
        the raw data. The mmap stays valid for the lifetime of this
        object.

        Raises:
            AtlasCorruptionError: if the file lacks the "PHAT" identifier
                or is too small to be a valid FlatBuffer.
        """
        with open(path, "rb") as f:
            mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

        # C7: Validate "PHAT" file identifier before parsing
        if len(mm) < 8:
            mm.close()
            raise AtlasCorruptionError(
                f"File too small for FlatBuffers: {path} ({len(mm)} bytes)."
            )
        if not PhoneticAtlas.PhoneticAtlasBufferHasIdentifier(mm, 0):
            mm.close()
            raise AtlasCorruptionError(
                f"File does not have the 'PHAT' identifier: {path}"
            )

        atlas = PhoneticAtlas.GetRootAsPhoneticAtlas(mm, 0)
        return cls(atlas)

    # -------------------------------------------------------------------
    # Metadata
    # -------------------------------------------------------------------

    @property
    def metadata(self) -> Optional[AtlasMetadataInfo]:
        m = self._atlas.Metadata()
        return AtlasMetadataInfo(m) if m else None

    # -------------------------------------------------------------------
    # Lookup
    # -------------------------------------------------------------------

    def get(self, ipa: str) -> Optional[PhonemeInfo]:
        """Look up a phoneme by its IPA symbol. Returns None if not found.

        The input IPA is NFC-normalized, so composed and decomposed forms
        of the same symbol (e.g., "ä" vs "a\\u0308") are equivalent.
        """
        # C1: NFC-normalize the query to match index keys
        normalized = unicodedata.normalize("NFC", ipa)
        i = self._index.get(normalized)
        if i is None:
            return None
        return self._entry_at(i)

    def at(self, index: int) -> Optional[PhonemeInfo]:
        """Get a phoneme by its positional index in the atlas."""
        if index < 0 or index >= self._atlas.PhonemesLength():
            return None
        return self._entry_at(index)

    def __len__(self) -> int:
        return self._atlas.PhonemesLength()

    def __iter__(self):
        n = self._atlas.PhonemesLength()
        for i in range(n):
            # C6: Don't skip corrupted entries — fail loud.
            # The strict accessor throws on null phoneme or null features.
            yield self._entry_at_strict(i)

    # -------------------------------------------------------------------
    # Internal
    # -------------------------------------------------------------------

    def _entry_at(self, index: int) -> Optional[PhonemeInfo]:
        """Lenient accessor — returns None for out-of-bounds, but throws
        on structural corruption (null features, null IPA).
        This is used by get() and at() — null means "phoneme doesn't
        exist", which is normal. But if data is corrupt, we throw."""
        p = self._atlas.Phonemes(index)
        if p is None:
            return None
        # C6: Null features = corruption. Throw distinctly so the caller
        # can differentiate "phoneme not found" from "atlas corrupt".
        fv = p.Features()
        if fv is None:
            raise AtlasCorruptionError(
                f"Null feature vector at phoneme index {index}. "
                f"Atlas binary is corrupt."
            )
        ipa_bytes = p.Ipa()
        if ipa_bytes is None:
            raise AtlasCorruptionError(
                f"Null IPA at phoneme index {index}. Atlas binary is corrupt."
            )
        # C1: NFC-normalize the IPA before returning
        ipa = unicodedata.normalize("NFC", ipa_bytes.decode("utf-8"))
        return PhonemeInfo(
            ipa=ipa,
            is_base=p.IsBase(),
            features=fv,
        )

    def _entry_at_strict(self, index: int) -> PhonemeInfo:
        """Strict accessor — used by iteration. Throws on ANY null:
        corrupt entry or corrupt feature vector."""
        p = self._atlas.Phonemes(index)
        if p is None:
            raise AtlasCorruptionError(
                f"Null phoneme entry at index {index}. Atlas binary is corrupt."
            )
        fv = p.Features()
        if fv is None:
            raise AtlasCorruptionError(
                f"Null feature vector at phoneme index {index}. "
                f"Atlas binary is corrupt."
            )
        ipa_bytes = p.Ipa()
        if ipa_bytes is None:
            raise AtlasCorruptionError(
                f"Null IPA at phoneme index {index}. Atlas binary is corrupt."
            )
        ipa = unicodedata.normalize("NFC", ipa_bytes.decode("utf-8"))
        return PhonemeInfo(
            ipa=ipa,
            is_base=p.IsBase(),
            features=fv,
        )


# ---------------------------------------------------------------------------
# Convenience factory
# ---------------------------------------------------------------------------

def load_phonetic_atlas(path: Optional[str] = None) -> PhoneticAtlasIndex:
    """
    Load the Phonetic Atlas from disk.

    Args:
        path: Path to phonetic_atlas.bin. If None, auto-resolves relative
              to this package's dist/ directory.

    Returns:
        A ready-to-use PhoneticAtlasIndex.
    """
    if path is None:
        path = os.path.normpath(
            os.path.join(
                os.path.dirname(__file__),
                "..", "..", "dist", "phonetic_atlas.bin"
            )
        )
    return PhoneticAtlasIndex.from_path(path)
