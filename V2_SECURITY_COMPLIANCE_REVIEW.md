# V2_SECURITY_COMPLIANCE_REVIEW.md

**Stage:** 7  
**SHA at review:** experiment branch tip after source/identity/recovery layers (see git log).  
**Base product SHA:** `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`

## Findings

| Area | Result | Notes |
|---|---|---|
| Keychain | OK | ChatGPT/Claude/Grok credentials local |
| Foreign CLI credentials | OK (V2 policy) | Not read; fingerprints only in V2 identity |
| Local files/RPC | CONDITIONAL | Codex/statusline not wired to production |
| OAuth | N/A | No OAuth client in app |
| WKWebView | CONDITIONAL | Default data store; provider login pages |
| Redirects | OK for Grok | Cookie stripped off grok.com |
| HTTPS | OK | chatgpt.com, claude.ai, grok.com |
| Account switch | CONDITIONAL | V2 identity layer tested; V1 ChatGPT/Claude still token-presence UI |
| Recovery | CONDITIONAL | V2 coordinator tested; V1 Grok restorer still WebKit-based; success policy forbids cookie-only success |
| Logs | OK | WebLogin hashes cookie names/domains; no raw values in V2 fingerprints |
| Crash reports | NOT_VERIFIED | No Crashlytics in source |
| Repo secrets | OK | No provider tokens in tree |
| ToS / unofficial endpoints | CONDITIONAL | wham/usage, claude usage, grok rest — `UNCLEAR`/`LIKELY_ALLOWED` consumer-session; HOLD new RE endpoints |
| App Sandbox | Off | Empty entitlements |
| Hardened Runtime / notarization | NOT_VERIFIED on Linux |

CRITICAL/HIGH for **release**: none newly introduced by V2 layers. Unofficial session APIs remain a **product-level** condition, not a silent PASS.

## Gate

`PASS_WITH_CONDITIONS`

Conditions: no Cursor/Gemini/Copilot production sources; no CLI credential scrape; Mac signing/notarization still required before any release (Stage 10).
