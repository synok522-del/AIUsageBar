# 17F-003 tests written

- Grok rate-limits live shape 140/140/7200 is 100 percent
- Grok remaining percent prefers totalTokens over totalQueries
- Grok remaining percent uses totalQueries when totalTokens is absent
- Grok missing or zero denominator does not invent a percent
- Grok zero remaining percent is a valid parsed payload
- HTML or Cloudflare bodies become a WAF error
- HTTP 401 remains an auth error even when the body is HTML
- JSON 403 stays a permission error rather than WAF

Dummy values only. No live cookies/tokens.

Execution: NOT RUN (Linux, no xcodebuild).
