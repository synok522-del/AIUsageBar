# Sprint 17F-015 — Grok Weekly Production Integration

**Date:** 2026-09-03  
**Merge to main:** NO  
**PR targeting main:** NO

## Git Boundary

| Item | Value |
|---|---|
| Base SHA | `68c505edc44457e8796562b33b04e0fe2edca777` (`review/17f-010c-grok-session-self-recovery`) |
| Implementation Branch | `review/17f-015-grok-weekly-production` |
| Ending SHA | (this commit) |
| Working Tree | production Weekly integration only |
| origin/main | `b1fcda95150592dbb28d7790a3126c0d06ff72de` |

17F-013/014 are evidence only. This branch is not based on probe commits.

## Production Architecture

| Short-window source | `POST https://grok.com/rest/rate-limits` (`remainingQueries` / `totalQueries` / `windowSizeSeconds`) |
| Weekly source | `POST https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig` (gRPC-Web protobuf, empty frame) |
| Primary quota selection | Valid WEEKLY entitlement → Weekly row only; otherwise dynamic short-window row only |

Weekly fetch uses the same 010C grok.com Cookie header and Grok-only redirect policy. Weekly errors are swallowed after a successful short-window parse.

## Weekly Parser

| Used | `config.credit_usage_percent`, rounded and clamped 0…100 |
| Remaining | `100 − used` |
| Period validation | `current_period.type == WEEKLY` (2) required |
| Reset validation | `current_period.end` required; `billing_period_end` ignored |

HTTP 200 alone is not enough.

## UI Behavior

### SuperGrok

One row: `每週` + remaining % + combined reset from `current_period.end` (`重置於 …｜M 月 d 日 a h:mm`). No 2-hour row.

### Free Grok

No valid WEEKLY → one dynamic short-window row (`sessionRowLabel` from `windowSizeSeconds`).

## Notification Behavior

Grok notifies on `primaryRemainingPercent` (Weekly remaining if primary, else short-window). ChatGPT/Claude still use session remaining. One Grok notification stream.

## Session Recovery Preservation

Unchanged: MainActor WebKit, restorer READY/`sso`, generation, WAF/401 retry, logout race, Grok-only Cookie strip. Weekly uses the same recovered session.

## Security Review

No cookie/sso/Authorization/protobuf logging. No new Keychain items.

## Probe Artifact Removal

No `weeklyRPC:` / probe status line in production UI or Grok sources.

## Tests

Linux has no Xcode. Automated tests are **NOT RUN** here.

| ID | Intent | This environment |
|---|---|---|
| T1 | 63% used → 37% remaining | written, NOT RUN |
| T2 | used clamp 0…100 | written, NOT RUN |
| T3 | WEEKLY + end accepted | written, NOT RUN |
| T4 | non-WEEKLY rejected | written, NOT RUN |
| T5 | missing period rejected | written, NOT RUN |
| T6 | missing end rejected | written, NOT RUN |
| T7 | protobuf failure → no Weekly | written, NOT RUN |
| T8 | Weekly HTTP fail + short-window usable | written, NOT RUN |
| T9 | one Weekly row | written, NOT RUN |
| T10 | one short-window row | written, NOT RUN |
| T11 | Weekly hides 2-hour bar | written, NOT RUN |
| T12 | notification uses Weekly | written, NOT RUN |
| T13 | notification uses short-window | written, NOT RUN |
| T14 | F1–F7 retained | retained, NOT RUN |
| T15 | 010C recovery tests retained | retained, NOT RUN |
| T16 | no probe diagnostic | written, NOT RUN |

Mac Debug/Release/xcodebuild: **NOT RUN** / **NOT VERIFIED**.

## Human Mac Verification Required

H1–H10 on SuperGrok Lite. Free fallback is unit-level only.

## Known Limitations

- Product breakdown is not shown (by design).
- Free-account live retest needs a Free session.
- This agent did not execute Mac builds.

## Acceptance Results

P1–P13 implemented in source. P14 Mac tests/builds **NOT VERIFIED**.

## Final Verdict

`READY_FOR_MAC_RETEST`
