# 17F-006 Notifications / regression / final verification

## Task objective
Complete Grok integration: 20% low-usage notifications without refresh spam, regression coverage for ChatGPT/Claude, reports, and review-branch delivery. Do not merge main. Do not release.

## Starting branch
review/17f-005-grok-menubar

## Starting SHA
f6bf996b8eb618bce52df67787302ec7d07801ff

## Ending SHA
see git rev-parse HEAD on this branch

## Files changed
- AIUsageBarTests/AIUsageBarTests.swift (Grok 20% notify / no-spam / recovery / independence)
- Grok-17F-Handoff/17F-006-report.md
- Grok-17F-Handoff/17F-final-report.md
- Grok-17F-Handoff/verification/17F-006/

UsageNotificationManager already includes `.grok` from earlier compile-safety landing.

## Work completed
- Grok participates in the existing 20% threshold.
- Crossing notifies once; remaining at 10% on refresh does not notify again.
- Recovery above 20% then drop notifies again.
- Grok notify state is independent of Claude/ChatGPT.
- ChatGPT and Claude notification tests kept.
- Final integration report and acceptance checklist written.

## Tests performed
- Grok 20% crossing once
- Recovery re-arm
- Independence from other providers
- Prior ChatGPT/Claude suites remain in AIUsageBarTests.swift

## Exact test results
AUTOMATED TESTS: WRITTEN. Execution NOT RUN on this Linux box.

## Build results
Debug: NOT RUN
Release: NOT RUN

## Problems encountered
- No registered Mac, so `xcodebuild` Debug/Release/test could not run.
- Desktop working tree at `/Users/kennyhung/Desktop/06_個人檔案/PROJECT/AIUsageBar/AIUsageBar` was not inspectable (no connected computer). Work started from origin/main.

## Problems fixed
- Grok notification behavior is locked in tests.

## Remaining risks
- Live WKWebView Grok login, live remaining numbers, Fast vs grok-3, and three-bar compactness are human visual/session checks.
- Automated tests and macOS builds are unverified until a Mac run.

## Human verification still required
- Real Grok login/logout in the app, independent of ChatGPT/Claude.
- Live remaining percent vs grok.com.
- 20% notification on a real drop, no spam on refresh.
- Debug + Release + `xcodebuild test` on macOS.

## GitHub branch name
review/17f-006-grok-integration

## Exact GitHub branch URL
https://github.com/synok522-del/AIUsageBar/tree/review/17f-006-grok-integration
