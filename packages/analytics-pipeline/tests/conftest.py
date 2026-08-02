"""
Shared fixtures for the analytics-pipeline test suite.

The src package (`src/`) intentionally has no __init__.py files — it is
imported as a PEP 420 namespace package rooted at the analytics-pipeline
directory (same layout as apps/api-server/app). This conftest inserts that
directory into sys.path so `import src.db.uow` resolves regardless of how
pytest is invoked.
"""

from __future__ import annotations

import sys
from pathlib import Path

ANALYTICS_PIPELINE_DIR = Path(__file__).resolve().parents[1]

if str(ANALYTICS_PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(ANALYTICS_PIPELINE_DIR))
