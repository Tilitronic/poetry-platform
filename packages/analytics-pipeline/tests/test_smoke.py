"""
Smoke tests for the analytics-pipeline src modules.

The three src modules are currently scaffolds: they declare their contract in
their docstrings but ship no implementation yet (mirroring how
apps/api-server/app/core/auth.py landed).

Why this assertion: it pins the import path so a regression (broken import
path, syntax error) fails loudly. An import test is meaningful here precisely
because the modules are importable only via the PEP 420 namespace-package
layout set up in conftest.py — a wrong sys.path setup fails it.
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
