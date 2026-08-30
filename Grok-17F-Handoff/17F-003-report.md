# 17F-003 Usage fetch / parse

## Task objective
Confirm Grok usage fetch is a single authenticated POST `{modelName:"grok-3"}` against `https://grok.com/rest/rate-limits`. Parse remaining percent from `remainingQueries / (totalTokens ?? totalQueries)` without inventing a percent. Weekly stays optional nil. HTML / non-JSON / Cloudflare is a WAF error, not a missing endpoint.

## Starting branch
review/17f-002-grok-login

## Starting SHA
82839e6437da4107dfed3c26fec0de3e1d1b46f0

## Ending SHA
93cf381b64e49fddf58d50f6ccc63cb9deb9eebb

## Files changed
- AIUsageBarTests/AIUsageBarTests.swift (parser + WAF/auth tests)
- Grok-17F-Handoff/17F-003-report.md
- Grok-17F-Handoff/verification/17F-003/

Implementation files (`GrokService.swift`, `ServiceSupport.swift`) already landed in 17F-002 so this branch compiles: single grok-3 POST, remainingQueries/(totalTokens??totalQueries), windowSizeSeconds, weekly nil, WAF for HTML. This sprint records verification tests for that behavior.

## Work completed
- Confirmed `GrokService.fetchUsage` POSTs only `{"modelName":"grok-3"}`. No `requestKind`. No grok-4 / fast / grok-4.5 brute force.
- `parseRateLimits`:
  - Requires `remainingQueries`.
  - Denominator = `totalTokens ?? totalQueries`. Missing or 0 throws `invalidPayload`. Never invents a percent.
  - Live shape `{remainingQueries:140,totalQueries:140,windowSizeSeconds:7200}` → 100%, window 7200.
  - `windowSizeSeconds` is parsed from the payload (not hardcoded 7200 or 5 hours).
- Weekly remains nil (`weeklyAvailable=false` for v1). No cli-chat-proxy billing, no ConnectRPC getGrokCreditsConfig.
- `ServiceSupport.validateHTTPResponse`:
  - 401 → `Grok 登入已失效，請重新登入`
  - 200/403 HTML or HTML-looking body → `Grok 被網站防護擋下，請稍後再試`
  - JSON 403 still uses the permission message
- `GrokService.sessionRowLabel(windowSeconds:)` converts seconds to hours (7200 → `2 小時`; 0 → `短窗`).

## Tests performed
- Live shape 140/140/7200 → 100%, window 7200
- `totalTokens` preferred over `totalQueries` when both present
- Fallback to `totalQueries` when `totalTokens` is absent
- Missing denominator throws
- `totalQueries=0` throws
- `totalTokens=0` even with a positive `totalQueries` throws (do not invent)
- Zero remaining with a valid total → 0% (valid payload)
- HTML body 200/403 → WAF Traditional Chinese message
- HTML jsonObject → WAF
- 401 HTML → auth re-login message (not WAF)
- JSON 403 → permission error (not WAF)

Existing ChatGPT/Claude and 17F-002 credential tests kept.

## Exact test results
AUTOMATED TESTS: WRITTEN. Execution NOT RUN on this Linux box. No Mac available for `xcodebuild test`.

## Build results
Debug: NOT RUN
Release: NOT RUN
xcodebuild: NOT RUN (Linux cannot xcodebuild). Not a STOP blocker.

## Problems encountered
- No remaining production-file delta versus 002 because GrokService/ServiceSupport were applied in full for compile-safety.

## Problems fixed
- Parser tests now lock the live 140/140/7200 shape, totalTokens preference, zero/missing denominator, and WAF vs 401 vs JSON 403.

## Remaining risks
- Live remainingTokens/totalTokens may appear later; current formula already prefers `totalTokens` when present.
- WAF detection peeks at HTML prefixes / content-type; an atypical Cloudflare text page without HTML markers may still surface as `invalidPayload`.
- Parser unit tests have not been executed on macOS.

## Human verification still required
- With a logged-in Grok session, confirm the panel percent matches grok.com remaining queries (140/140 → 100%).
- Confirm the session row label follows the live `windowSizeSeconds` (7200 → `2 小時`), not a hardcoded 5 hours.
- Confirm no weekly row is shown.
- If Cloudflare HTML is returned, confirm the WAF Traditional Chinese message appears and no cookie value is shown.
- Compile + test on macOS.

## GitHub branch name
review/17f-003-grok-usage

## Exact GitHub branch URL
https://github.com/synok522-del/AIUsageBar/tree/review/17f-003-grok-usage
