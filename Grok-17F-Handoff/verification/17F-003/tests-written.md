# 17F-003 tests written

Updated in 17F-007 to match the corrected remaining-percent and reset contracts.

- Grok rate-limits live shape 140/140/7200 is 100 percent, with empty reset text
- Grok remaining percent uses totalQueries even when totalTokens is present
- Grok remaining percent uses totalQueries when totalTokens is absent
- Grok remaining percent ignores zero or missing totalTokens when totalQueries is valid
- Grok remaining percent never divides remainingQueries by totalTokens
- Grok does not fabricate a reset timestamp from windowSizeSeconds
- Grok uses a genuine reset timestamp when one is present
- Grok missing or zero totalQueries does not invent a percent
- Grok zero remaining percent is a valid parsed payload
- Window labels represent sub-hour durations instead of rounding to 1 hour
- HTML or Cloudflare bodies become a WAF error
- HTTP 401 remains an auth error even when the body is HTML
- JSON 403 stays a permission error rather than WAF

Dummy values only. No live cookies/tokens.

Execution: NOT RUN (Linux, no xcodebuild).
