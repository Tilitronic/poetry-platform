"""
F-7 (DIA-139) regression guard: pytest pythonpath bootstrap in pyproject.toml.

The src package (`src/`) is a PEP 420 namespace package rooted at the
analytics-pipeline directory (same layout as apps/api-server/app). It used
to be importable only because tests/conftest.py inserted that directory into
sys.path. Slice F deleted that conftest and moved the bootstrap to
[tool.pytest.ini_options] pythonpath in pyproject.toml (design.md DD6);
test_smoke.py pins the actual imports.

This test pins the bootstrap contract itself: pyproject.toml must declare
pythonpath (or imports silently break), and src/ must stay a PEP 420
namespace root (no __init__.py anywhere under it) or `pythonpath = ["."]`
stops resolving the src.* imports it exists to enable.
"""

from __future__ import annotations

import tomllib
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
NAMESPACE_ROOT = PROJECT_DIR / "src"


def test_pyproject_declares_pytest_pythonpath():
    """pyproject.toml declares pythonpath and src/ has no __init__.py (F-7, DIA-139)."""
    pyproject_path = PROJECT_DIR / "pyproject.toml"
    assert pyproject_path.is_file(), f"pyproject.toml not found at {pyproject_path}"
    with pyproject_path.open("rb") as fh:
        config = tomllib.load(fh)
    pythonpath = config.get("tool", {}).get("pytest", {}).get("ini_options", {}).get("pythonpath")
    assert pythonpath, "pythonpath missing from [tool.pytest.ini_options]"
    assert not list(NAMESPACE_ROOT.rglob("__init__.py")), (
        f"__init__.py found under {NAMESPACE_ROOT}: src/ must stay a PEP 420 "
        "namespace package for pythonpath to resolve src.* imports"
    )
