# Sprint 17F-014 — SuperGrok Weekly gRPC Live Probe

**Date:** 2026-09-02  
**Mode:** LIVE VERIFICATION PROBE (code ready; Mac session not run here)  
**GitHub Push to main:** NO  
**Merge:** NO  
**Production Weekly UI:** NOT implemented (`weeklyRemainingPercent` remains `nil`)

## Git Boundary

| Item | Value |
|---|---|
| Base Branch | `review/17f-010c-grok-session-self-recovery` |
| Base SHA | `68c505edc44457e8796562b33b04e0fe2edca777` |
| Discovery evidence | `probe/17f-013-supergrok-weekly-rpc-discovery` (not the git base) |
| Probe Branch | `probe/17f-014-supergrok-weekly-grpc-live` |
| origin/main | `b1fcda95150592dbb28d7790a3126c0d06ff72de` |

## Request

| | |
|---|---|
| Route | `POST https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig` |
| Protocol | gRPC-Web + protobuf (`Content-Type: application/grpc-web+proto`, `X-Grpc-Web: 1`) |
| Request framing | empty `GetGrokCreditsConfigRequest` in a 5-byte envelope `00 00 00 00 00` |
| Auth | 17F-010C in-memory grok.com Cookie header; `httpShouldHandleCookies = false`; same Grok-only redirect Cookie strip |

## Files

- `AIUsageBar/Service/GrokWeeklyRPCProbe.swift` (new, removable)
- `AIUsageBar/Service/GrokService.swift` (probe after `/rest/rate-limits`; Weekly UI fields stay nil)
- `AIUsageBar/Models/GrokUsage.swift` (`weeklyRPCDiagnostic` only)
- `AIUsageBar/ViewModels/UsageViewModel.swift` (status line after Refresh)
- `AIUsageBarTests/AIUsageBarTests.swift`

## Diagnostic

After Refresh, status text:

```text
weeklyRPC: http=200 grpc=OK used=53 remaining=47 period=WEEKLY start=... end=2026-09-05T07:11:00Z chat=36 appBuilder=16 imagine=1
```

Failure example (no payload):

```text
weeklyRPC: http=403 contentType=text/html frames=n/a grpc=n/a decode=HTML_OR_WAF
```

`remaining` is `100 − round(credit_usage_percent)`. `billingEnd` is logged separately if present and is not used as Weekly reset.

## Live Result

This cloud environment has no Kenny WebKit session. The RPC was **not** executed against grok.com.

| HTTP | not run |
| gRPC status | not run |
| Decode status | unit-tested on a synthetic 53/47/WEEKLY/Chat/App Builder/Imagine frame |

## Kenny Mac

Quit every `AIUsageBar` process first (`synok522.AIUsageBar`).

```bash
cd "/Users/kennyhung/Desktop/06_個人檔案/PROJECT/AIUsageBar/AIUsageBar"
git fetch origin
git checkout probe/17f-014-supergrok-weekly-grpc-live
xcodebuild -project AIUsageBar.xcodeproj -scheme AIUsageBar -configuration Debug \
  -derivedDataPath /tmp/AIUsageBar-17F-014 build
open /tmp/AIUsageBar-17F-014/Build/Products/Debug/AIUsageBar.app
```

Refresh Grok. Copy the `weeklyRPC:` status line only. Do not screenshot cookies.

## Official UI Reconciliation

Not live-reconciled in this environment. Target:

| Used | 53% |
| Remaining | 47% |
| Reset | 2026-09-05 15:11 +08 |
| Chat / App Builder / Imagine | 36 / 16 / 1 |

## Short-Window Isolation

`/rest/rate-limits` still drives session remaining / 2-hour window. Weekly RPC failure does not fail that fetch.

## Security Review

No cookie/sso/authorization/raw protobuf logging. No new Keychain writes. Redirect Cookie strip unchanged.

## Classification

`PROBE_BLOCKED`

(Mac live session required.)

## Final Verdict

`NEEDS_MORE_EVIDENCE`
