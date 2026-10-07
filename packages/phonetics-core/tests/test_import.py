"""Import smoke test for phonetics-core Python loader."""

from __future__ import annotations


def test_import_load_atlas():
    """Package is importable as atlas.load_atlas."""
    try:
        from atlas.load_atlas import AtlasCorruptionError, PhoneticAtlasIndex, load_phonetic_atlas
    except ImportError:
        from src.atlas.load_atlas import (  # type: ignore
            AtlasCorruptionError,
            PhoneticAtlasIndex,
            load_phonetic_atlas,
        )

    assert AtlasCorruptionError is not None
    assert PhoneticAtlasIndex is not None
    assert load_phonetic_atlas is not None


def test_import_flatbuffers_bindings():
    """Generated FlatBuffers bindings are importable."""
    # These are top-level modules from flatc --python output.
    import AtlasMetadata  # type: ignore
    import FeatureVector  # type: ignore

    assert AtlasMetadata is not None
    assert FeatureVector is not None
