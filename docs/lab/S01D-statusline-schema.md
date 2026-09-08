# S01D — Claude Code statusline snapshot (lab)

**Sprint:** S01D (Cursor V2 lab)  
**Status:** Opt-in, reversible challenger. **Not** a replacement for `claude.ai` web usage (`ClaudeService`). Not wired to `UsageViewModel` or menu cards.

## Bridge default

`ClaudeStatuslineBridgeConfig.isEnabled` defaults to **false**. Selector is **web-only**. Enable then disable restores web-only (T-1D-08). No OAuth credential reuse.

## Assumed redacted JSON shape

Live Claude Code statusline JSON was not captured here. This is a **redacted fixture schema** for the lab parser.

```json
{
  "captured_at": "2026-09-08T11:50:00Z",
  "rate_limits": {
    "five_hour": {
      "utilization": 0.37,
      "resets_at": "2026-09-08T12:00:00Z"
    },
    "seven_day": {
      "utilization": 0.10,
      "resets_at": "2026-09-15T12:00:00Z"
    }
  }
}
```

| Field | Rule |
|---|---|
| `rate_limits` | Required for meters. **Missing → `NO_METER_IN_SNAPSHOT`, never `AUTH_FAILED` / logout.** Empty object / empty `Data` is the same outcome, not auth failure. |
| `five_hour` / `seven_day` | Optional windows. Present windows become `claude.five_hour` / `claude.seven_day`. |
| `utilization` | If value is in `0...1` inclusive, treat as a **fraction** (0.37 → used 37 → remaining 63). If `> 1`, treat as already a percent. `1.0` → remaining 0. Do **not** use `ServiceSupport.requiredPercent` (it would round 0.37 to 0). Remaining = `max(0, 100 - usedPercent)`. |
| `resets_at` / `reset_at` | Optional ISO-8601. Invalid / non-ISO → **parse failure**. Missing → `resetAt == nil`. Never fabricate a `Date`. |
| `captured_at` / `as_of` | Optional ISO-8601 snapshot time for lab freshness. Invalid → parse failure. |

Malformed JSON → `parseFailure`, **not** auth failure. Parser accepts in-memory `Data` / `String` only. **No filesystem, transcript, or `~/.claude` API.**

## Freshness (lab constant; S02 not shipped)

S02 validity constants are **not frozen**. This sprint defines:

| Constant | Value | Meaning |
|---|---|---|
| `ClaudeStatuslineFreshness.freshnessTTL` | **15 minutes** | Age ≤ 15m → `FRESH` |
| `ClaudeStatuslineFreshness.expiredTTL` | **6 hours** | Age > 15m and ≤ 6h → `STALE_BUT_VALID`; age > 6h → `EXPIRED` |

An old snapshot is still **parsed**. It is **not** silent `FRESH` success.

Missing `captured_at` is treated as `STALE_BUT_VALID` (not invented fresh).

## What this is not

- Not `ClaudeService.parseUsage` / org HTTP  
- Not conversation transcript reading  
- Not a production source until a later sprint explicitly selects it
