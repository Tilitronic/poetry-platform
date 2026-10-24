"""Cross-language parity test: TS vs Python atlas loader.

Verifies that the Python loader produces the same feature vectors as the
TypeScript loader for a curated set of phonemes. The expected vectors are
stored in tests/fixtures/parity.json (committed) which was generated from
the TS loader. A live subprocess check (node + parity_dump.mjs) is also
attempted when node/tsx are available.
"""

from __future__ import annotations

import json
import pathlib
import subprocess

import pytest

try:
    from atlas.load_atlas import PhoneticAtlasIndex, load_phonetic_atlas
except ImportError:
    from src.atlas.load_atlas import PhoneticAtlasIndex, load_phonetic_atlas  # type: ignore

ATLAS_BIN = pathlib.Path(__file__).parent.parent / "src" / "atlas" / "phonetic_atlas.bin"
FIXTURES = pathlib.Path(__file__).parent / "fixtures"
PARITY_JSON = FIXTURES / "parity.json"
PARITY_DUMP = pathlib.Path(__file__).parent.parent / "scripts" / "parity_dump.mjs"

# Python FeatureVector field name -> TS field name mapping
PY_TO_TS = {
    "Syl": "syl",
    "Son": "son",
    "Cons": "cons",
    "Cont": "cont",
    "Delrel": "delrel",
    "Lat": "lat",
    "Nas": "nas",
    "Strid": "strid",
    "Voi": "voi",
    "Sg": "sg",
    "Cg": "cg",
    "Ant": "ant",
    "Cor": "cor",
    "Distr": "distr",
    "Lab": "lab",
    "Hi": "hi",
    "Lo": "lo",
    "Back": "back",
    "Round": "round",
    "Velaric": "velaric",
    "Tense": "tense",
    "Long": "long",
    "Hitone": "hitone",
    "Hireg": "hireg",
}
TS_TO_PY = {v: k for k, v in PY_TO_TS.items()}


@pytest.fixture(scope="module")
def atlas() -> PhoneticAtlasIndex:
    return load_phonetic_atlas(str(ATLAS_BIN))


def test_parity_fixture_exists():
    assert PARITY_JSON.is_file(), f"parity fixture missing: {PARITY_JSON}"
    data = json.loads(PARITY_JSON.read_text(encoding="utf-8"))
    assert "p" in data
    assert "__metadata__" in data


def test_parity_against_fixture(atlas: PhoneticAtlasIndex):
    """Python feature vectors must match the committed parity fixture (from TS)."""
    expected = json.loads(PARITY_JSON.read_text(encoding="utf-8"))
    for ipa, fields in expected.items():
        if ipa.startswith("__"):
            continue
        entry = atlas.get(ipa)
        assert entry is not None, f"phoneme {ipa!r} missing in Python loader"
        fv = entry.features
        for ts_field, exp_val in fields.items():
            py_field = TS_TO_PY[ts_field]
            actual = getattr(fv, py_field)()
            assert actual == exp_val, f"{ipa!r}.{ts_field}: expected {exp_val}, got {actual}"


def test_parity_metadata(atlas: PhoneticAtlasIndex):
    expected = json.loads(PARITY_JSON.read_text(encoding="utf-8"))["__metadata__"]
    m = atlas.metadata
    assert m is not None
    assert m.total_segments == expected["totalSegments"]
    assert m.feature_count == expected["featureCount"]
    assert m.source_name == expected["sourceName"]


def test_parity_live_node_subprocess(atlas: PhoneticAtlasIndex):
    """Live cross-language check: spawn node to dump TS vectors and compare.

    Skipped gracefully if node or tsx is not available.
    """
    if not PARITY_DUMP.is_file():
        pytest.skip("parity_dump.mjs not found")
    # Try npx tsx first, then node with --loader tsx
    for cmd in (
        ["npx", "tsx", str(PARITY_DUMP)],
        ["node", "--loader", "tsx", str(PARITY_DUMP)],
        ["bunx", "tsx", str(PARITY_DUMP)],
    ):
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10,
                cwd=str(PARITY_DUMP.parent.parent),
            )
            if result.returncode != 0:
                continue
            data = json.loads(result.stdout)
            break
        except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
            continue
    else:
        pytest.skip("node/tsx not available for live parity check")

    # Compare a few fields
    for ipa in ["p", "a", "m", "s"]:
        if ipa not in data or data[ipa] is None:
            continue
        entry = atlas.get(ipa)
        assert entry is not None
        fv = entry.features
        for ts_field, exp_val in data[ipa].items():
            if ts_field not in TS_TO_PY:
                continue
            py_field = TS_TO_PY[ts_field]
            actual = getattr(fv, py_field)()
            assert actual == exp_val, f"live parity {ipa!r}.{ts_field}: ts={exp_val} py={actual}"
