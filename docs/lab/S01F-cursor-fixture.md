# S01F — Cursor local usage fixture (research only)

**Sprint:** S01F (Cursor V2 lab)  
**Production decision:** **HOLD**  
**New tests:** T-1F-01 … T-1F-08  
**UI:** no Cursor menu card

## Goal

Parse a **redacted in-memory** Cursor usage fixture. This is research / lab only. Production stays HOLD. There is no `UsageProvider.cursor` and no menu-card factory output.

## Redacted fixture shape

```json
{
  "remaining_percent": 42,
  "resets_at": "2026-09-08T18:00:00Z",
  "included_models": ["composer", "tab"]
}
```

| Field | Rule |
|---|---|
| `remaining_percent` | Required. Missing → parse failure (T-1F-03). Never invent remaining. |
| `resets_at` / `reset_at` | Optional ISO-8601. Present → `Date`. Invalid / non-ISO → parse failure. Missing → `nil`. Never fabricate. |
| `included_models` / `auto_included_models` | Recorded as names. **Not** extra user-visible meters (T-1F-05). |

Parser accepts `Data` / `String` only. `filesystemAccess = forbidden`. Unit tests do **not** open `~/Library/Application Support/Cursor` or live `state.vscdb`.

## Production

`CursorProductionPolicy.decision = HOLD`. `menuCardFactoryOutput()` is always `nil`. ChatGPT / Claude / Grok cards are unchanged.
