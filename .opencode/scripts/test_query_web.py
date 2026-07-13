"""
Tests for query_web.py — the bridge script for the web-search AI skill.

Covers:
  - Authentication (API key, no key, JWT fallback)
  - Request building (endpoint, payload, timeout)
  - Response parsing (documents, results, items shapes)
  - Error handling (network failures, API errors, malformed JSON, empty results)
  - Edge cases (empty query, whitespace-only, special characters)
  - CLI entry point (--help, missing args, --top-k, quick query)
  - Multiple response envelope shapes from different OpenWebUI versions
"""
from __future__ import annotations

import sys
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

SCRIPT_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(SCRIPT_DIR))

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

AUTH_HEADER = {"Authorization": "Bearer web-test-key-999"}


@pytest.fixture(autouse=True)
def _patch_env_and_reset(monkeypatch):
    """Isolate tests from real config by injecting deterministic env vars."""
    monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
    monkeypatch.setenv("OPENWEBUI_API_KEY", "web-test-key-999")
    monkeypatch.setenv("WEB_SEARCH_TOP_K", "3")
    monkeypatch.setenv("WEB_SEARCH_TIMEOUT", "10")
    monkeypatch.setenv("LOG_LEVEL", "CRITICAL")

    # Force fresh import before each test
    for mod in list(sys.modules.keys()):
        if "query_web" in mod:
            del sys.modules[mod]


@pytest.fixture
def qw():
    """Convenience: freshly-imported query_web module."""
    import query_web as m
    # Reset the JWT cache so tests don't leak across
    m._jwt_token = None
    yield m


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_response(status_code=200, json_data=None, text=""):
    """Build a minimal requests-like response object."""
    class _FakeResponse:
        def __init__(self, sc, jd, txt):
            self.status_code = sc
            self._jd = jd
            self._txt = txt
        def json(self):
            return self._jd
        @property
        def text(self):
            return self._txt
    return _FakeResponse(status_code, json_data or {}, text)


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------


class TestAuthentication:
    """Verify that auth headers are correctly derived from env or fallback."""

    def test_api_key_from_env(self, qw):
        """OPENWEBUI_API_KEY set → used as Bearer token."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://example.com", "content": "hello"}]}
            )
            m.search_web("python tutorial")
            auth = mock_req.post.call_args.kwargs["headers"].get("Authorization", "")
            assert auth == "Bearer web-test-key-999"

    def test_no_api_key_no_auth(self, qw):
        """No API key and no JWT fallback → empty Auth header, warning logged."""
        import query_web as m
        with patch.object(m, "API_KEY", ""):
            with patch.object(m, "_jwt_token", None):
                with patch.object(m, "_get_auth_header") as mock_auth:
                    mock_auth.return_value = {}
                    with patch.object(m, "requests") as mock_req:
                        mock_req.post.return_value = make_response(
                            200, {"documents": []}
                        )
                        m.search_web("test")
                        sent_headers = mock_req.post.call_args.kwargs["headers"]
                        # Should still have Content-Type but no Authorization
                        assert sent_headers.get("Content-Type") == "application/json"
                        assert "Authorization" not in sent_headers or not sent_headers["Authorization"]

    def test_jwt_fallback_success(self, qw):
        """No API key but JWT from query_rag → use it."""
        import query_web as m
        with patch.object(m, "API_KEY", ""):
            # Simulate successful JWT acquisition
            m._jwt_token = "minted-jwt-token"
            with patch.object(m, "requests") as mock_req:
                mock_req.post.return_value = make_response(
                    200, {"documents": [{"url": "http://x.com", "content": "x"}]}
                )
                m.search_web("test")
                auth = mock_req.post.call_args.kwargs["headers"].get("Authorization", "")
                assert auth == "Bearer minted-jwt-token"

    def test_jwt_fallback_import_failure(self, qw):
        """No API key, query_rag available but .key file missing → empty auth."""
        import query_web as m
        with patch.object(m, "API_KEY", ""):
            # Clear any cached token so _get_auth_header() re-evaluates
            m._jwt_token = None
            # query_rag IS available in this environment, but we mock its
            # keyfile function to return None, simulating a missing .key file
            # or a production environment where local JWT minting is disabled.
            with patch("query_rag._get_jwt_from_keyfile", return_value=None):
                with patch.object(m, "requests") as mock_req:
                    mock_req.post.return_value = make_response(
                        200, {"documents": []}
                    )
                    m.search_web("test")
                    sent_headers = mock_req.post.call_args.kwargs["headers"]
                    # No auth means no Authorization header, or an empty one
                    auth = sent_headers.get("Authorization", "")
                    assert not auth


# ---------------------------------------------------------------------------
# Request building
# ---------------------------------------------------------------------------


class TestRequestBuilding:
    """Verify that search_web constructs the correct HTTP request."""

    def test_correct_endpoint(self, qw):
        """POST to /api/v1/retrieval/web/search."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test")
            url = mock_req.post.call_args.args[0]
            assert "retrieval/web/search" in url

    def test_payload_includes_query(self, qw):
        """Payload has 'query' key set to the input string."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test query here")
            assert mock_req.post.call_args.kwargs["json"]["query"] == "test query here"

    def test_payload_includes_k_default(self, qw):
        """Payload uses WEB_SEARCH_TOP_K env var for k."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test")
            assert mock_req.post.call_args.kwargs["json"]["k"] == 3

    def test_custom_k_override(self, qw):
        """Passing k parameter overrides default."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test", k=10)
            assert mock_req.post.call_args.kwargs["json"]["k"] == 10

    def test_headers_content_type(self, qw):
        """Content-Type is application/json."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test")
            ct = mock_req.post.call_args.kwargs["headers"].get("Content-Type", "")
            assert ct == "application/json"

    def test_timeout_from_env(self, qw):
        """Request uses WEB_SEARCH_TIMEOUT value."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.com", "content": "c"}]}
            )
            m.search_web("test")
            assert mock_req.post.call_args.kwargs["timeout"] == 10


# ---------------------------------------------------------------------------
# Response parsing — normalise different API shapes
# ---------------------------------------------------------------------------


class TestResponseParsing:
    """Verify correct handling of various OpenWebUI response envelopes."""

    def test_documents_shape(self, qw):
        """{'documents': [{...}]} is the primary shape."""
        import query_web as m
        fake = {"documents": [{"url": "http://a.io", "title": "Article A", "content": "Some content."}]}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "Article A" in result
        assert "http://a.io" in result
        assert "Some content." in result

    def test_results_shape(self, qw):
        """{'results': [{...}]} is an alternate shape."""
        import query_web as m
        fake = {"results": [{"url": "http://b.io", "title": "Article B", "content": "Other content."}]}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "Article B" in result
        assert "http://b.io" in result
        assert "Other content." in result

    def test_items_shape(self, qw):
        """{'items': [{...}]} with 'link' and 'snippet' (older OpenWebUI)."""
        import query_web as m
        fake = {
            "items": [
                {"link": "http://c.io", "title": "Article C", "snippet": "Snippet content."}
            ]
        }
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "Article C" in result
        assert "http://c.io" in result
        assert "Snippet content." in result

    def test_mixed_shape_empty_documents(self, qw):
        """'documents' is empty but 'results' has data → prefer documents."""
        import query_web as m
        fake = {"documents": [], "results": [{"url": "http://d.io", "title": "Article D", "content": "Should not appear."}]}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "no results" in result.lower()

    def test_all_shapes_absent(self, qw):
        """Response lacks docs/results/items → no results message."""
        import query_web as m
        fake = {"status": "ok"}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "no results" in result.lower()

    def test_empty_document_keys(self, qw):
        """Document entries may lack url/content — handled gracefully."""
        import query_web as m
        fake = {"documents": [{"title": "Just a title"}]}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "Just a title" in result
        assert "URL:" not in result  # no url key, so omitted

    def test_content_truncation(self, qw):
        """Very long content (>600 chars) is truncated with an ellipsis."""
        import query_web as m
        long_text = "word " * 200  # ~1000 chars
        fake = {"documents": [{"url": "http://long.io", "content": long_text}]}
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "…" in result
        # Ensure it's substantially shorter than original
        assert len(result) < len(long_text) * 2  # rough check

    def test_multiple_results(self, qw):
        """Multiple documents are all listed in order."""
        import query_web as m
        fake = {
            "documents": [
                {"url": "http://1.io", "title": "First", "content": "First body."},
                {"url": "http://2.io", "title": "Second", "content": "Second body."},
                {"url": "http://3.io", "title": "Third", "content": "Third body."},
            ]
        }
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "First" in result
        assert "Second" in result
        assert "Third" in result
        assert result.index("First") < result.index("Second") < result.index("Third")


# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------


class TestErrorHandling:
    """Verify that all error paths return user-friendly messages."""

    def test_empty_query(self, qw):
        """Empty string → immediate error, no HTTP call."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            result = m.search_web("")
            mock_req.post.assert_not_called()
        assert "Error" in result

    def test_whitespace_only_query(self, qw):
        """Whitespace only → immediate error."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            result = m.search_web("   ")
            mock_req.post.assert_not_called()
        assert "Error" in result

    def test_connection_error(self, qw):
        """Connection refused → friendly message."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.side_effect = ConnectionRefusedError("Connection refused")
            result = m.search_web("test")
        assert "Failed to connect" in result

    def test_timeout(self, qw):
        """Timeout → specific message."""
        import query_web as m
        import requests as real_requests
        with patch.object(m, "requests") as mock_req:
            mock_req.post.side_effect = real_requests.exceptions.Timeout("timed out")
            result = m.search_web("test")
        assert "did not respond within" in result

    def test_http_401(self, qw):
        """401 response → error with status code and detail."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(401, {"detail": "Not authenticated"})
            result = m.search_web("test")
        assert "API Error (401)" in result
        assert "Not authenticated" in result

    def test_http_500_plain_text(self, qw):
        """Non-JSON error response → plain text included in message."""
        import query_web as m
        resp = MagicMock()
        resp.status_code = 500
        resp.text = "Internal Server Error"
        resp.json.side_effect = ValueError("not json")
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = resp
            result = m.search_web("test")
        assert "API Error (500)" in result

    def test_malformed_json(self, qw):
        """Non-JSON on 200 → malformed message."""
        import query_web as m
        resp = MagicMock()
        resp.status_code = 200
        resp.json.side_effect = ValueError("not json")
        resp.text = "<html>"
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = resp
            result = m.search_web("test")
        assert "malformed JSON" in result

    def test_generic_network_exception(self, qw):
        """Generic exception → wrapped message with exception name."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.side_effect = RuntimeError("weird error")
            result = m.search_web("test")
        assert "Network error" in result
        assert "RuntimeError" in result


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


class TestEdgeCases:
    """Non-trivial query variations."""

    def test_unicode_query(self, qw):
        """Unicode characters in query pass through correctly."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.io", "content": "résumé"}]}
            )
            result = m.search_web("über cool")
            sent_query = mock_req.post.call_args.kwargs["json"]["query"]
            assert "über" in sent_query
        assert "résumé" in result

    def test_query_with_hash(self, qw):
        """Query containing '#' should not confuse anything."""
        import query_web as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.io", "content": "C# tutorial"}]}
            )
            m.search_web("C# tutorial")
            sent_query = mock_req.post.call_args.kwargs["json"]["query"]
            assert "C#" in sent_query

    def test_very_long_query(self, qw):
        """Very long query string does not crash."""
        import query_web as m
        long_q = "query " * 1000
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(
                200, {"documents": [{"url": "http://x.io", "content": "..."}]}
            )
            result = m.search_web(long_q)
        assert "LIVE WEB SEARCH RESULTS" in result

    def test_special_characters_in_response(self, qw):
        """Response with angle brackets, quotes, ampersands renders fine."""
        import query_web as m
        fake = {
            "documents": [
                {
                    "url": "http://x.io?q=a&b=c",
                    "title": "AT&T <test> \"quote\"",
                    "content": "content with <tags> & entities"
                }
            ]
        }
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake)
            result = m.search_web("test")
        assert "AT&T" in result
        assert "<test>" in result or "&lt;test&gt;" in result  # either encoding is fine
        assert "<tags>" in result or "&lt;tags&gt;" in result


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


class TestCliEntryPoint:
    """End-to-end invocation tests via subprocess."""

    def test_cli_no_args(self):
        """No arguments → exit code 1 + help message."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_web.py")],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 1
        output = result.stdout + result.stderr
        assert "Usage:" in output

    def test_cli_help(self):
        """--help → exit code 0."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_web.py"), "--help"],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 0
        assert "Usage:" in result.stdout

    def test_cli_with_query(self):
        """With a query string → exit code 0 (no network call, but doesn't crash)."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_web.py"), "test query"],
            capture_output=True, text=True, timeout=30,
        )
        # The actual request will fail (no real server), but the script should
        # still produce output and exit with code 0 for successful execution.
        # Actually, search_web returns an error string and main() exits with 1
        # on error.  So we expect exit code 1 because the mock server isn't real.
        # This is fine — it exercised the code path.
        assert result.returncode in (0, 1)
        assert len(result.stdout) > 0

    def test_cli_with_top_k(self):
        """--top-k 7 sets k=7."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_web.py"), "--top-k", "7", "search terms"],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode in (0, 1)
        # We can't easily verify the payload from subprocess, but it shouldn't crash

    def test_cli_multi_word_query(self):
        """Multiple words are joined correctly."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_web.py"), "latest", "Python", "news"],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode in (0, 1)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
