# GEMINI_SOURCE_POC.md

**Stage:** 1G

## Apps vs CLI (must stay separate)

| Surface | Meter | Auth |
|---|---|---|
| Gemini Apps (web) | Consumer subscription; not proven equivalent to CLI | Google account in browser |
| Gemini CLI / Code Assist | Requests/day by **edition** (docs: Standard 1500, Enterprise 2000; consumer Google-login CLI deprecated toward Antigravity as of 2026-06-18) | Code Assist license, API key, or Vertex — **not** assumed = Apps |

Google documentation states Google AI Pro/Ultra **web** plans do not automatically equal CLI quotas.

## Account-specific remaining % API

No official Gemini Apps “remaining percent + resetAt” API suitable for AIUsageBar was verified. Public docs describe **plan limits**, not a live personal remaining snapshot for the consumer app.

Gemini CLI quota docs are **request caps by auth method**, not a portable Apps meter.

## Classification

`HOLD` for Gemini Apps.  
`HOLD` for Gemini CLI/Code Assist as a **separate** future provider (would need official remaining snapshot, not public-rule-only estimates).

**Do not** show Gemini UI. Constraint B/C/D: no public-rule-only or fabricated remaining.
