"""
Smoke tests for the analytics-pipeline src modules.

The three src modules are currently scaffolds: they declare their contract in
their docstrings but ship no implementation yet (mirroring how
apps/api-server/app/core/auth.py landed).

Why these assertions: they pin the documented surface so a regression (broken
import path, deleted purpose, syntax error) fails loudly. An import test is
meaningful here precisely because the modules are importable only via the
PEP 420 namespace-package layout set up in conftest.py — a wrong sys.path
setup fails it.
"""

from __future__ import annotations

import importlib

import src.core.numpy_calc as numpy_calc
import src.daemon.cron as cron
import src.db.uow as uow


def test_modules_import_from_namespace_package_path():
    """Each src module imports cleanly as its namespace-package path."""
    assert importlib.import_module("src.db.uow") is uow
    assert importlib.import_module("src.core.numpy_calc") is numpy_calc
    assert importlib.import_module("src.daemon.cron") is cron


def test_uow_docstring_declares_single_commit_contract():
    """uow.py must keep stating the single-commit + OCC contract."""
    doc = (uow.__doc__ or "").lower()
    assert "unit of work" in doc
    assert "metrics.upsert" in doc
    assert "mark_as_processed" in doc
    assert "occ" in doc


def test_numpy_calc_docstring_declares_analytics_core_contract():
    """numpy_calc.py must keep stating the NumPy/ProcessPoolExecutor contract."""
    doc = (numpy_calc.__doc__ or "").lower()
    assert "numpy" in doc
    assert "processpoolexecutor" in doc


def test_cron_docstring_declares_daemon_contract():
    """cron.py must keep stating the WHERE contract_hash != processed_hash contract."""
    doc = (cron.__doc__ or "").lower()
    assert "cron" in doc
    assert "contract_hash" in doc
    assert "processed_hash" in doc
