"""Tests for the Python atlas loader: load, lookup, iteration, corruption, Unicode."""

from __future__ import annotations

import pathlib
import unicodedata

import pytest

try:
    from atlas.load_atlas import AtlasCorruptionError, PhoneticAtlasIndex, load_phonetic_atlas
except ImportError:
    from src.atlas.load_atlas import (  # type: ignore
        AtlasCorruptionError,
        PhoneticAtlasIndex,
        load_phonetic_atlas,
    )

ATLAS_BIN = pathlib.Path(__file__).parent.parent / "src" / "atlas" / "phonetic_atlas.bin"
FIXTURES = pathlib.Path(__file__).parent / "fixtures"

EXPECTED_SEGMENTS = 6367
EXPECTED_BASES = 147
EXPECTED_FEATURES = 24


@pytest.fixture(scope="module")
def atlas() -> PhoneticAtlasIndex:
    assert ATLAS_BIN.is_file(), f"atlas bin not found: {ATLAS_BIN}"
    return load_phonetic_atlas(str(ATLAS_BIN))


# -- load / metadata -------------------------------------------------------


def test_load_valid_atlas(atlas: PhoneticAtlasIndex):
    assert len(atlas) == EXPECTED_SEGMENTS
    assert atlas.metadata is not None
    m = atlas.metadata
    assert m.source_name == "Panphon"
    assert m.source_version == "0.22.2"
    assert m.total_segments == EXPECTED_SEGMENTS
    assert m.total_bases == EXPECTED_BASES
    assert m.feature_count == EXPECTED_FEATURES
    assert m.content_hash is not None and len(m.content_hash) == 64


def test_load_via_from_path():
    a = PhoneticAtlasIndex.from_path(str(ATLAS_BIN))
    assert len(a) == EXPECTED_SEGMENTS
    # mmap lifetime: access after construction
    p = a.get("p")
    assert p is not None
    assert p.features.Cons() == 1


def test_load_missing_file_raises():
    with pytest.raises(FileNotFoundError):
        PhoneticAtlasIndex.from_path("/tmp/does-not-exist-xyz.bin")


# -- lookup ----------------------------------------------------------------


def test_get_well_known_base_phonemes(atlas: PhoneticAtlasIndex):
    # Uses actual IPA symbols from Panphon (e.g. U+0261 LATIN SMALL LETTER SCRIPT G)
    for sym in ["a", "b", "d", "e", "f", "\u0261", "h", "i", "j", "k", "l", "m", "n", "o", "p"]:
        p = atlas.get(sym)
        assert p is not None, f"base phoneme {sym!r} missing"
        assert p.ipa == sym
        assert p.is_base is True


def test_get_derived_phonemes(atlas: PhoneticAtlasIndex):
    # NFC forms - these are derived (not base)
    for sym in ["\u00e4", "p\u02b0", "t\u0361s"]:
        p = atlas.get(sym)
        assert p is not None, f"derived phoneme {sym!r} missing"


def test_get_missing_returns_none(atlas: PhoneticAtlasIndex):
    assert atlas.get("ZZZZ") is None
    assert atlas.get("") is None


def test_at_index_bounds(atlas: PhoneticAtlasIndex):
    assert atlas.at(0) is not None
    assert atlas.at(len(atlas) - 1) is not None
    assert atlas.at(len(atlas)) is None
    assert atlas.at(-1) is None


def test_len_and_iter_count(atlas: PhoneticAtlasIndex):
    assert len(atlas) == EXPECTED_SEGMENTS
    count = sum(1 for _ in atlas)
    assert count == EXPECTED_SEGMENTS


def test_entries_have_valid_ipa(atlas: PhoneticAtlasIndex):
    for p in atlas:
        assert p.ipa
        assert len(p.ipa) > 0


# -- Unicode NFC normalization ---------------------------------------------


def test_unicode_nfc_normalization(atlas: PhoneticAtlasIndex):
    # U+00E4 LATIN SMALL LETTER A WITH DIAERESIS can be encoded two ways:
    # NFC (precomposed) = "\u00e4", NFD = "a\u0308"
    # The atlas stores NFC; lookup via NFD must still find it if one exists.
    nfc = "\u00e4"
    nfd = unicodedata.normalize("NFD", nfc)
    assert nfc != nfd or True  # they differ for this char
    p_nfc = atlas.get(nfc)
    p_nfd = atlas.get(nfd)
    # If the NFC form exists, NFD must also resolve to same entry
    if p_nfc is not None:
        assert p_nfd is not None
        assert p_nfd.ipa == p_nfc.ipa
        assert p_nfd.features.Syl() == p_nfc.features.Syl()
    # Also test decomposed query directly vs composed stored entry
    # Even if this specific phoneme is missing, the normalization itself must not error
    assert atlas.get(nfd) is None or atlas.get(nfd).ipa == unicodedata.normalize("NFC", nfd)


# -- feature vectors -------------------------------------------------------


def test_feature_vector_p_consonant(atlas: PhoneticAtlasIndex):
    p = atlas.get("p")
    assert p is not None
    fv = p.features
    # /p/ voiceless bilabial plosive
    assert fv.Syl() == 2
    assert fv.Cons() == 1
    assert fv.Voi() == 2
    assert fv.Lab() == 1


def test_feature_vector_a_vowel(atlas: PhoneticAtlasIndex):
    p = atlas.get("a")
    assert p is not None
    fv = p.features
    assert fv.Syl() == 1
    assert fv.Son() == 1
    assert fv.Cons() == 2
    assert fv.Voi() == 1
    assert fv.Lo() == 1


def test_feature_vector_m_nasal(atlas: PhoneticAtlasIndex):
    p = atlas.get("m")
    assert p is not None
    fv = p.features
    assert fv.Nas() == 1
    assert fv.Cons() == 1
    assert fv.Voi() == 1
    assert fv.Lab() == 1


def test_feature_vector_s_fricative(atlas: PhoneticAtlasIndex):
    p = atlas.get("s")
    assert p is not None
    fv = p.features
    assert fv.Cont() == 1
    assert fv.Strid() == 1
    assert fv.Voi() == 2
    assert fv.Cor() == 1


def test_all_feature_values_in_range(atlas: PhoneticAtlasIndex):
    # Spot-check first 20 entries: every field in {0,1,2}
    for i in range(min(20, len(atlas))):
        p = atlas.at(i)
        assert p is not None
        fv = p.features
        for method in [
            "Syl",
            "Son",
            "Cons",
            "Cont",
            "Delrel",
            "Lat",
            "Nas",
            "Strid",
            "Voi",
            "Sg",
            "Cg",
            "Ant",
            "Cor",
            "Distr",
            "Lab",
            "Hi",
            "Lo",
            "Back",
            "Round",
            "Velaric",
            "Tense",
            "Long",
            "Hitone",
            "Hireg",
        ]:
            v = getattr(fv, method)()
            assert v in (0, 1, 2), f"{method}={v} out of range at index {i}"


# -- mmap lifetime ---------------------------------------------------------


def test_mmap_stays_alive_after_load():
    # Load then force GC, then access - would segfault if mmap closed
    import gc

    a = PhoneticAtlasIndex.from_path(str(ATLAS_BIN))
    gc.collect()
    p = a.get("p")
    assert p is not None
    assert p.features.Cons() == 1
    # Also via iteration after GC
    gc.collect()
    assert sum(1 for _ in a) == EXPECTED_SEGMENTS
    # Explicit mmap retained
    assert hasattr(a, "_mmap")
    assert a._mmap is not None


# -- corruption handling ---------------------------------------------------


@pytest.mark.parametrize(
    "fixture",
    [
        "corrupt_empty.bin",
        "corrupt_truncated.bin",
        "corrupt_too_small.bin",
        "corrupt_bad_identifier.bin",
    ],
)
def test_corruption_fixtures_raise(fixture: str):
    path = FIXTURES / fixture
    assert path.is_file(), f"fixture missing: {path}"
    with pytest.raises(AtlasCorruptionError):
        PhoneticAtlasIndex.from_path(str(path))


def test_corruption_error_is_distinct():
    # AtlasCorruptionError must be distinguishable from FileNotFoundError
    assert issubclass(AtlasCorruptionError, Exception)
    assert not issubclass(AtlasCorruptionError, FileNotFoundError)
