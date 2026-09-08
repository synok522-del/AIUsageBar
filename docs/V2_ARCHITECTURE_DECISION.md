# V2 architecture decision (S02)

**Sprint:** S02  
**Track:** Cursor V2  
**Status:** types + constants frozen. **No provider migration.**  
**ChatGPT source:** still `backend-api/wham/usage` (S01C = `NOT_PROVEN`)  
**Codex:** not a sixth provider  
**Cursor / Gemini / Copilot cards:** none

This document freezes the V2 types. Later sprints may not change these constants without a new S02 revision.

---

## Production still uses V1

| Surface | After S02 |
|---|---|
| `ChatGPTService` / `ClaudeService` / `GrokService` | Unchanged |
| Menu cards | ChatGPT, Claude, Grok only |
| `UsageViewModel` | Unchanged |
| Lab types | `AIUsageBar/Lab/V2Architecture.swift` only |

---

## Snapshot

`V2UsageSnapshot` requires:

- `provider`
- `accountKey` (non-empty)
- `meters[]`

A snapshot cannot be constructed without an account key. Adapters in S03 must not return a snapshot without `accountKey`.

## Meter

Each `V2UsageMeter` requires `meterId` (non-empty) + `window`. Remaining percent and `resetAt` are optional. Missing remaining is not invented. Missing `resetAt` stays `nil` — never fabricated.

**Primary displayed meter** is `isPrimaryDisplayed: Bool`. It is **not** “the first array item.”

## Window classifier (`V2WindowClassifier`)

| Duration | Class |
|---|---|
| `duration ≤ 6h` (`shortWindowMaxDuration`) | `short` |
| ~24h (`dailyWindowDuration` ± `windowDurationTolerance`) | `daily` |
| ~7d (`weeklyWindowDuration`) | `weekly` |
| ~30d (`monthlyWindowDuration`) | `monthly` |
| missing / unknown / other | `unspecified` (**not** silently weekly) |

Grok weekly reset remains `GetGrokCreditsConfig` `current_period.end` when type is WEEKLY. `billing_period_end` is not a window class and is not a reset.

## Validity

| State | Rule |
|---|---|
| `FRESH` | last parse succeeded, identity matched, `now - fetchedAt ≤ freshnessWindow` (15 minutes) |
| `STALE_BUT_VALID` | last parse succeeded, identity matched, stale but `now - fetchedAt ≤ validityTTL` (6 hours) |
| `EXPIRED` | past `validityTTL` |
| `INVALID` | parse failed **or** identity mismatch |

**Cookie-exists, navigation-finished, and WKWebView READY cannot produce `FRESH`.** Those events are credential probes, not usage success.

## Recovery success

Success requires **all** of:

1. A usage fetch was performed
2. HTTP 2xx
3. Valid parse
4. Matching identity (`provider + accountKey`)

Cookie-exists / READY is not success.

## Notifications

Identity key = `provider + accountKey + meterId + window`.

User-visible 20% alerts fire **only** for the primary displayed meter. Non-primary / weekly-secondary meters do not create extra alerts.

## UI copy (only allowed user-visible recovery strings)

| String | Use |
|---|---|
| `已登入` | HEALTHY (and RECOVERING may keep last STALE_BUT_VALID numbers) |
| `需重新登入` | REQUIRES_USER_ACTION |
| `資料暫時無法取得` | BACKOFF |

No Basic Mode. No estimated quota copy.

## Named constants (`V2ArchitectureConstants`)

| Name | Value |
|---|---|
| `freshnessWindow` | 15 minutes |
| `validityTTL` | 6 hours |
| `recoverFailureLimit` | 3 |
| `backoffCooldown` | 30 seconds |
| `notificationThresholdPercent` | 20 |
| `shortWindowMaxDuration` | 6 hours |
| `dailyWindowDuration` | 24 hours |
| `weeklyWindowDuration` | 7 days |
| `monthlyWindowDuration` | 30 days |
| `windowDurationTolerance` | 3 hours |

Tests must read these names. Do not scatter magic numbers.

## Gemini / Codex / Cursor

- Gemini Apps and CLI are distinct `V2Provider` values (`geminiApps`, `geminiCLI`). Never merge.
- Codex is a challenger (`codex`), not selected for UI while S01C is `NOT_PROVEN`.
- Cursor is HOLD. Copilot is architecture benchmark only (`docs/lab/S01H-copilot-benchmark.md`).

## Tests

T-2-01 … T-2-15 in `AIUsageBarTests/S02ArchitectureDecisionTests.swift`. Linux execution: `BLOCKED_PENDING_REAL_MAC_EVIDENCE`.
