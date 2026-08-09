"""
First tests for app.core.auth.

app/core/auth.py is currently a scaffold: it declares the module's contract in
its docstring ("JWT Auth — Google OAuth") but ships no implementation yet.

Why these assertions: they pin the documented surface so a regression (broken
import path, deleted purpose, syntax error) fails loudly, and they mark the
seam where real JWT/OAuth logic — and its tests — will land. An import test is
meaningful here precisely because the module is importable only via the PEP 420
namespace-package layout set up in conftest.py; a wrong sys.path setup fails it.
"""

from __future__ import annotations

import importlib

import app.core.auth as auth


def test_module_is_importable_from_package_path():
    """The auth module imports cleanly as app.core.auth (namespace package)."""
    mod = importlib.import_module("app.core.auth")
    assert mod is auth


def test_docstring_declares_jwt_and_oauth_contract():
    """The module docstring must keep stating the JWT + Google OAuth contract."""
    doc = (auth.__doc__ or "").lower()
    assert "jwt" in doc
    assert "oauth" in doc
