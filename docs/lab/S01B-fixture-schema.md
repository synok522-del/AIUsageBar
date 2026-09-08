# S01B — Assumed Codex `account/rateLimits/read` fixture schema

**Sprint:** S01B (Cursor V2 lab)  
**Status:** Assumed schema for **redacted fixtures only**. Live Codex JSON was not available in this environment. This is not a production ChatGPT source.

The lab parser (`CodexRateLimitsParser`) accepts **in-memory** `Data` / `String` only. It has **no filesystem API**, does not read `~/.codex/`, and does not read `auth.json`.

ChatGPT V1 production parse (`ChatGPTService.parseUsage`) is unchanged: `rate_limit.primary_window` / `secondary_window`, `used_percent`, remaining = `max(0, 100 - used)`, reset field `reset_at`. This lab parser is a **challenger** type and is **not** selected in `UsageViewModel`.

---

## Documented JSON shape (redacted)

Top-level object **must** contain a rate-limit object under one of:

- `rate_limit` (ChatGPT-shaped key)
- `rateLimits` (Codex RPC-style alias)

Empty `{}` is a parse failure (T-1B-07), not a successful empty meter list.

```json
{
  "rate_limit": {
    "primary_window": {
      "used_percent": 40,
      "resets_at": "2026-09-08T12:00:00Z",
      "limit": 100
    },
    "secondary_window": {
      "used_percent": 10,
      "reset_at": "2026-09-15T12:00:00Z",
      "limit": 100
    }
  },
  "unknown_future_field": true
}
```

| Field | Rule |
|---|---|
| `primary_window` | Optional. If absent, that candidate meter is omitted (no crash). |
| `secondary_window` | Optional. If absent, that candidate meter is omitted (no crash). |
| `used_percent` | Number or numeric string. Remaining = `max(0, 100 - used)` (ChatGPT V1 rule). If missing/null, remaining is **not** invented. |
| `limit` | If `null`, omitted, or the string `limitless` / `unlimited`, do **not** invent a remaining percent from limit. Remaining still comes only from `used_percent` when that field is present. |
| `resets_at` or `reset_at` | Optional. If present, value **must** be ISO-8601 datetime (`InternetDateTime`, optional fractional seconds). Invalid / non-ISO values **fail the parse**. Unix timestamps, relative strings, and `Date()` fallbacks are **not** accepted. Missing reset → `resetAt == nil`. |
| Other keys | Ignored. |

---

## What this schema is not

- Not live `account/rateLimits/read` capture  
- Not a secret store  
- Not wired to menu cards or `ChatGPTService`  
- Fixtures in tests must stay **redacted** (no real tokens, emails, or cookies)
