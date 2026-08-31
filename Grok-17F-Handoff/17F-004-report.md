# 17F-004 Provider / settings / panel

## Task objective
Make Grok a normal third provider throughout Code Bar. Order is ChatGPT → Claude → Grok. Settings login/logout is independent. Unauthenticated Grok is hidden. Fetch failure and 0% remaining do not hide authenticated Grok. Window duration comes from `windowSizeSeconds`, not a hardcoded 5 hours. Weekly remains omitted. No xAI/Grok company logos.

## Starting branch
review/17f-003-grok-usage

## Starting SHA
f7f500aa7e60d1d7f178b48c9e7959a904a3375b

## Ending SHA
ee423c556a2442270d5619d3027f9fd3d9021581

SHA correction (17F-007): the previously recorded Ending SHA `96151655cbc8fea3a9be98275ae8f492706ed298` was not the `review/17f-004-grok-provider` tip. The actual branch tip is `ee423c556a2442270d5619d3027f9fd3d9021581`.

## Files changed
- AIUsageBarTests/AIUsageBarTests.swift (Grok visibility / welcome / logout isolation / window label)
- Grok-17F-Handoff/17F-004-report.md
- Grok-17F-Handoff/verification/17F-004/

Settings, panel, welcome, and view-model Grok wiring already landed on 17F-002/003 so those branches compile. This sprint records the provider-policy tests and verification.

## Work completed
- Settings rows: ChatGPT, Claude, Grok, each with independent login/logout.
- Panel shows authenticated Grok; unauthenticated Grok is omitted from `visibleProviders`.
- Provider order: ChatGPT → Claude → Grok.
- 0% remaining keeps Grok visible while the Grok credential is present.
- Fetch failure preserves last loaded Grok usage (`UsageRefreshStatePolicy.state(afterFailure:)`) and does not hide the provider.
- Session row label uses `GrokService.sessionRowLabel(windowSeconds:)` (7200 → `2 小時`; 0 → `短窗`). 7200 is not displayed as `5 小時`.
- Weekly row only if `weeklyAvailable` (v1 remains false).
- Welcome hides when only Grok is logged in. Grok login is optional; all three are not required.
- No Grok/xAI company logos.

## Tests performed
- Welcome hidden for Grok-only login
- Grok-only visibility
- ChatGPT+Grok, Claude+Grok, all three order
- Unauthenticated Grok hidden
- 0% Grok still visible
- Fetch-failure preserved loaded state still visible
- Grok logout does not hide ChatGPT/Claude
- Window label from seconds, not hardcoded 5 hours

Existing ChatGPT/Claude tests kept.

## Exact test results
AUTOMATED TESTS: WRITTEN. Execution NOT RUN on this Linux box. No Mac available for `xcodebuild test`.

## Build results
Debug: NOT RUN
Release: NOT RUN
xcodebuild: NOT RUN (Linux cannot xcodebuild). Not a STOP blocker.

## Problems encountered
- Production Settings/Panel/Welcome files were already on 17F-003 for compile-safety. This branch adds the 17F-004 policy tests and report rather than re-wiring those files.

## Problems fixed
- Visibility combinations required by the sprint (Grok-only and every pair plus all three) are now locked in tests.

## Remaining risks
- Real WKWebView Settings login/logout has not been run on a Mac.
- Panel compactness with three cards is a visual check.

## Human verification still required
- Log in Grok from Settings; confirm ChatGPT and Claude stay logged in.
- Log out Grok; confirm ChatGPT and Claude stay logged in.
- Confirm unauthenticated Grok is absent from the panel.
- Confirm 0% and a failed refresh still show Grok.
- Confirm the session row is `2 小時` (or the live window), not `5 小時`.
- Confirm no weekly row and no company logo.
- Compile + test on macOS.

## GitHub branch name
review/17f-004-grok-provider

## Exact GitHub branch URL
https://github.com/synok522-del/AIUsageBar/tree/review/17f-004-grok-provider
