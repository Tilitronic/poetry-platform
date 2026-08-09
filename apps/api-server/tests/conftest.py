"""
Shared fixtures for the api-server test suite.

The app package (`app/`) intentionally has no __init__.py files — it is
imported as a PEP 420 namespace package rooted at the api-server directory.
This conftest inserts that directory into sys.path so `import app.core.auth`
resolves regardless of how pytest is invoked.
"""

from __future__ import annotations

import sys
from pathlib import Path

API_SERVER_DIR = Path(__file__).resolve().parents[1]

if str(API_SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(API_SERVER_DIR))
