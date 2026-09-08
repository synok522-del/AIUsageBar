# S01G — Gemini Apps vs CLI / Code Assist split

**Sprint:** S01G (Cursor V2 lab)  
**Production decision:** **HOLD** (no Gemini menu card)  
**New tests:** T-1G-01 … T-1G-08

## Goal

Treat Gemini **Apps** and **CLI / Code Assist** as **separate meters** unless a later sprint proves they are identical. Similar remaining percent is not a merge.

## Families

| Fixture | Meter family |
|---|---|
| Apps | `gemini-apps` |
| CLI / Code Assist | `gemini-cli` |

Identity helper **always refuses** to merge Apps + CLI `accountKey`s (T-1G-04). Missing one family does **not** mark the other unauthenticated (T-1G-05, T-1G-06).

## Fabricated resetAt

`reset_source: fabricated` or `fabricated_reset: true` → parse failure. Missing reset stays `nil`. Invalid ISO-8601 → parse failure. Never invent a date.

## Production

`GeminiProductionPolicy.decision = HOLD`. No Gemini card factory. ChatGPT / Claude / Grok cards unchanged.
