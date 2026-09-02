# 17F-010 Production Session Context Fix

**Date:** 2026-09-02  
**GitHub Push to main:** NO  
**Merge to main:** NO  
**Release:** NO

## Stage

17F-010

## Goal

Production-fix Grok short-window usage fetch so refresh uses the current applicable grok.com WebKit cookie context, matching live-proven 17F-009B behavior, without probe diagnostics or weekly SuperGrok work.

## Base SHA

`a5aff3e5488df641cc5f048764034b28723644d5`  
(`review/17f-007-grok-review-fixes`)

## Branch

`review/17f-010-grok-session-context-fix`

## Ending SHA

`11e756d848c67db7c85bb3ceb6d73d7f4fd34bdf`

## Files Changed

- `AIUsageBar/Service/WebSessionManager.swift`
- `AIUsageBar/ViewModels/UsageViewModel.swift`
- `AIUsageBarTests/AIUsageBarTests.swift`
- `Grok-17F-Handoff/17F-010-report.md`

## Derived Acceptance Standard P1–P10

| ID | Standard |
|----|----------|
| P1 | At Grok refresh, obtain current applicable grok.com WebKit cookies for the rate-limits request. |
| P2 | No probe labels, cookie-name lists, cookie counts, diagnostic source names, or diagnostic classifications in production UI/logs. |
| P3 | Real cookie values only in the in-memory Cookie header. Never logged, printed, shown, committed, or persisted as a full jar. |
| P4 | WKWebView login and Keychain authenticated-state (`sso` / optional `sso-rw`) remain. |
| P5 | Keep `POST https://grok.com/rest/rate-limits` with `{"modelName":"grok-3"}`. No weekly. |
| P6 | Keep remainingQueries/totalQueries, windowSizeSeconds, real resetAt only, weekly nil, auth visibility, 20% notifications. |
| P7 | ChatGPT / Claude behavior unchanged. |
| P8 | Grok logout stays Grok-scoped. |
| P9 | Unit coverage with synthetic cookies only. |
| P10 | Human live Grok refresh must succeed without WAF (Mac). |

## Implementation Summary

`GrokSessionContext` selects cookies that:

- match grok.com (including subdomains)
- exclude x.ai, x.com, and other providers
- honor path, Secure, and expiration
- require a non-empty `sso` before using the WebKit header

`UsageViewModel.refreshGrok()` reads `WKWebsiteDataStore.default().httpCookieStore` via `WebSessionManager.cookies(for: .grok)`, builds an in-memory Cookie header, and falls back to the existing Keychain `sso` / `sso-rw` header when WebKit has no usable `sso`.

Keychain still stores only the login credential snapshot. The full dynamic jar is not persisted.

Success/error status strings are unchanged from 17F-007 (no probe text).

## Tests Written

- Applicable grok.com cookies included; ChatGPT / x.ai / x.com / expired / non-matching path excluded
- Path `/rest` applies to `/rest/rate-limits`
- Synthetic values appear in the request header only
- Cookie-name helper returns names, not values
- Fallback when WebKit cookies lack `sso`
- Prefer WebKit header when `sso` is present

Existing Grok parse, provider-visibility, and ChatGPT/Claude tests were not weakened.

## Tests Actually Run

Automated Mac Tests: **NOT RUN** (Linux environment; no `xcodebuild`)

## Debug Build Actually Run

Debug Build: **NOT RUN**

## Release Build Actually Run

Release Build: **NOT RUN**

## Self-Review

Diff vs 17F-007 is the session-context helper, `refreshGrok` header selection, unit tests, and this report.

No 009C weekly code (`/rest/grok/credits`, `creditUsagePercent`).  
No probe UI/status strings (`probe:`, `webkit-full`, `cookies=`).  
No secrets. No ChatGPT/Claude edits. `origin/main` not modified.

## Acceptance Review

| Criterion | Result | Evidence |
|-----------|--------|----------|
| P1 | PASS (source) | `refreshGrok` + `GrokSessionContext` + `WebSessionManager.cookies(for:)` |
| P2 | PASS (source) | No diagnostic labels/logs added |
| P3 | PASS (source) | Values only in Cookie header; Keychain model unchanged |
| P4 | PASS (source) | Login/Keychain paths untouched |
| P5 | PASS (source) | `GrokService` request unchanged |
| P6 | PASS (source) | Parser and `weeklyRemainingPercent: nil` unchanged |
| P7 | PASS (source) | ChatGPT/Claude files not in diff |
| P8 | PASS (source) | Logout / `clearCookies` unchanged |
| P9 | PASS (source) | New synthetic unit tests; not executed on Mac |
| P10 | NOT VERIFIED | Human live fetch required |

## Known Limitations

- If WebKit has no current `sso`, refresh falls back to the Keychain partial header (the 17F-007 failure mode).
- `WebSessionManager.cookies(for:)` is not unit-tested against a live data store.
- Mac tests/builds were not run in this environment.

## Human Verification Still Required

- Real Grok short-window refresh (must not show WAF HTML error)
- Login / logout
- Restart persistence of authenticated state
- Live quota vs Grok UI
- 20% notification
- Cross-provider isolation

## Resume Point

Checkout `review/17f-010-grok-session-context-fix` on a Mac at the ending SHA. Run `xcodebuild test`, Debug, and Release. Then perform P10 live Grok refresh.
