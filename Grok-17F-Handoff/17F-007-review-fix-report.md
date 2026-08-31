# 17F-007 Review Fix Round

**Date:** 2026-08-31 (Asia/Taipei)
**GitHub Push to main:** NO
**Merge to main:** NO
**Release:** NO

## Task objective
Fix only the independent Grok Build review findings F1–F7 on `review/17f-006-grok-integration`. Do not redesign the Grok integration. Do not expand scope.

## Starting branch
review/17f-006-grok-integration

## Starting SHA
545a1d0bdbb79f4b06d3456ea4f96fd5136a550e

## Ending SHA
see git rev-parse HEAD on this branch (filled after commit)

## Files changed
- AIUsageBar/Service/GrokService.swift
- AIUsageBar/Service/WebSessionManager.swift
- AIUsageBarTests/AIUsageBarTests.swift
- Grok-17F-Handoff/17F-002-report.md
- Grok-17F-Handoff/17F-003-report.md
- Grok-17F-Handoff/17F-004-report.md
- Grok-17F-Handoff/17F-005-report.md
- Grok-17F-Handoff/17F-006-report.md
- Grok-17F-Handoff/17F-final-report.md
- Grok-17F-Handoff/verification/17F-002/tests-written.md
- Grok-17F-Handoff/verification/17F-003/tests-written.md
- Grok-17F-Handoff/17F-007-review-fix-report.md
- Grok-17F-Handoff/verification/17F-007/

## Findings

### F1 HIGH — remaining percent units
FIXED.

`parseRateLimits` now uses `remainingQueries / totalQueries` only.
- `totalTokens` does not override a valid `totalQueries`.
- Zero or missing `totalTokens` does not invalidate a valid `totalQueries` response.
- Token-only payloads (no valid `totalQueries`) throw `invalidPayload`.
- Query count is never divided by token count.

### F2 MEDIUM — windowSizeSeconds is not a reset timestamp
FIXED.

`windowSizeSeconds` is kept for the window label.
Reset text comes only from a genuine `resetAt` / `reset_at`.
If none is present, `resetText` is empty. The parser no longer uses `now + windowSizeSeconds`.

### F3 MEDIUM — consumer auth is grok.com
FIXED.

`WebSessionProvider.grok.matches` is grok.com only (including subdomains).
x.ai-only `sso` is not a consumer Grok credential.
Grok logout therefore does not clear x.ai cookies or website data.
x.com remains excluded.

### F4 MEDIUM — Task report Ending SHA
FIXED.

Corrected from git objects, not invented values:

| Report | Previous recorded SHA | Actual branch tip |
|--------|------------------------|-------------------|
| 17F-002 | 71f71b070bb9bc35115f40cafcaa816aa04fc82f | 82839e6437da4107dfed3c26fec0de3e1d1b46f0 |
| 17F-003 | 93cf381b64e49fddf58d50f6ccc63cb9deb9eebb | f7f500aa7e60d1d7f178b48c9e7959a904a3375b |
| 17F-004 | 96151655cbc8fea3a9be98275ae8f492706ed298 | ee423c556a2442270d5619d3027f9fd3d9021581 |
| 17F-005 | "see git rev-parse HEAD" | f6bf996b8eb618bce52df67787302ec7d07801ff |
| 17F-006 | "see git rev-parse HEAD" | 545a1d0bdbb79f4b06d3456ea4f96fd5136a550e |

### F5 MEDIUM — human-only items
FIXED.

The final report now marks these NOT VERIFIED until actually tested:
- real macOS Grok login
- real logout
- live quota comparison
- session persistence
- Fast vs grok-3
- real three-bar appearance
- real 20% notification
- logout isolation against live ChatGPT/Claude sessions

They are not marked PASS.

### F6 LOW — sub-hour window labels
FIXED.

`sessionRowLabel` no longer rounds every positive duration up to at least 1 hour.
Examples: 7200 → `2 小時`; 1800 → `30 分鐘`; 90 → `1 分鐘 30 秒`; 45 → `45 秒`; 3599 → `59 分鐘 59 秒`; 0 → `短窗`.

### F7 LOW — unused sessionToken fetch path
FIXED.

Removed `GrokService.fetchUsage(sessionToken:)`, which built `sso=` only and dropped `sso-rw`.
The live path is `fetchUsage(cookieHeader:)`, which keeps the stored header including `sso-rw` when present.

## Tests performed
Added or updated Swift Testing cases for F1, F2, F3, F6:
- remainingQueries / totalQueries even when totalTokens is present
- ignored zero/missing totalTokens when totalQueries is valid
- token-only denominator throws
- no fabricated reset from windowSizeSeconds
- genuine resetAt is used
- grok.com required; x.ai and x.com ignored
- sub-hour window labels are not "1 小時"

## Exact test results
Automated macOS tests: NOT RUN
Debug build: NOT RUN
Release build: NOT RUN

Linux box cannot run `xcodebuild`. These are not marked PASS.

## Self-review
PASS (source). Diff limited to F1–F7. No secrets or live cookie values. Dummy cookie strings only (`dummy-sso-value`, `dummy-xai-sso`, `dummy-xcom-sso`). origin/main remains `b1fcda95150592dbb28d7790a3126c0d06ff72de`.

## Problems encountered
None beyond the documented Linux / no-Mac test gap.

## Remaining risks
Human-only items in F5 remain NOT VERIFIED.

## GitHub branch name
review/17f-007-grok-review-fixes

## Exact GitHub branch URL
https://github.com/synok522-del/AIUsageBar/tree/review/17f-007-grok-review-fixes

## Final Status
READY_FOR_REVIEW_RECHECK
