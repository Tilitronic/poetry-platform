---
source: https://www.npmjs.com/package/@adrianlzt/opencode-show-tools
capture-note: |
  Direct server-side fetch encountered Cloudflare's JavaScript challenge ("Just a moment...")
  which prevents retrieving the fully rendered npm package page without executing JS.
  The raw HTML saved to /tmp/npm-show-tools.html (5752 bytes) contains the challenge page
  and no package README or straightforward metadata extractable by trafilatura.

extracted-from-html:
- html_title: "Just a moment..."
- cloudflare_challenge_present: true
- saved_html_bytes: 5752

extraction-conclusion: |
  This page is JS-rendered / protected by Cloudflare. Full package README and metadata
  require a browser-capable fetch (headless browser) or an npm registry API call.
  Saved the above diagnostics and a minimal note to preserve the source capture as required.

---

# npm package: @adrianlzt/opencode-show-tools

URL: https://www.npmjs.com/package/@adrianlzt/opencode-show-tools

Capture outcome: Cloudflare JS-challenge page saved. See saved_html_bytes above. No README or
package metadata was extractable from the server-side HTML snapshot. Do not fabricate content.
