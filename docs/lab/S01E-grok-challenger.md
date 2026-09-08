# S01E — Grok local/CLI challenger contract (lab)

**Sprint:** S01E (Cursor V2 lab)  
**Baseline:** SuperGrok **web** meters (`GrokService` rate-limits + `GetGrokCreditsConfig`). This sprint does **not** replace web Grok.

## Contract

A local/CLI Grok challenger is accepted only if it can prove the same *shape* as current web meters:

| Requirement | Rule |
|---|---|
| Short window | Fixture **must** expose `short_window.remaining_percent` (T-1E-01). |
| Weekly | Fixture **must** expose `weekly.remaining_percent` **or** set `weekly_absent: true` (T-1E-02). Silently omitting weekly is a reject. |
| Weekly reset | Must **not** be taken from `billing_period_end` / `reset_source: billing_period_end` (T-1E-03). Web weekly reset is `current_period.end` (period type 2), not billing-cycle end. |
| Entitlement | Challenger `entitlement` must match the web SuperGrok/free classification. Mismatch → reject (T-1E-04). |
| Missing local source | Keep **web-only** selection. Not logout / not auth failure (T-1E-05). |
| Parse failure | Does **not** disable `GrokCreditsConfigDecoder.requestPath` (`/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig`) (T-1E-06). |

## Redacted fixture shape

```json
{
  "entitlement": "super_grok",
  "short_window": { "remaining_percent": 40 },
  "weekly": {
    "remaining_percent": 12,
    "reset_at": "2026-09-15T12:00:00Z",
    "reset_source": "current_period_end"
  }
}
```

Parser is in-memory `Data` / `String` only. Not wired to `UsageViewModel` or Grok cards.

## Production

Web Grok remains the selected source. No production swap in S01E.
