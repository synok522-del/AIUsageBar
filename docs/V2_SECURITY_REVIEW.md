# V2 security review (S07)

**Sprint:** S07  
**Track:** Cursor V2  
**Date:** 2026-09-08  
**Scope:** redaction, scopes, no conversation reads. No S08 soak, no publish.

Verdicts below are from **this tree’s source**, not a Mac execution. Linux `xcodebuild` is absent (`BLOCKED_PENDING_REAL_MAC_EVIDENCE` for tests). That does not make a production-needed item UNCLEAR.

If a production-needed item were UNCLEAR, S07 would not be PASS. None are.

---

## Per-provider verdicts

| Provider | Role in this experiment | Verdict | Notes |
|---|---|---|---|
| ChatGPT | Production | **PASS** | Source remains Keychain cookie → session → `backend-api/wham/usage`. No chat/transcript API. No hidden WKWebView restorer. S01C is `NOT_PROVEN`; Codex is not selected. Logs must go through `V2LogRedactor` (bearer, cookies, emails). |
| Claude | Production | **PASS** | Default source is `claude.ai` org usage. Snapshot bridge default **off**. Missing `rate_limits` is `NO_METER_IN_SNAPSHOT`, not logout. No OAuth credential reuse. Parser has no transcript API. |
| Grok | Production | **PASS** | Short window: `rest/rate-limits` `grok-3`. Weekly: `GetGrokCreditsConfig` WEEKLY `current_period.end`. `billing_period_end` is not weekly reset. Restorer READY / `sso` cookie is a **credential probe**, not card `已登入`. Foreign-host redirects strip `Cookie` (`GrokRedirectPolicy`). Tier 6 foreign-cookie reuse is **not enabled**. |
| Cursor | HOLD, not a card | **PASS** (HOLD) | Fixture parser is in-memory only. Not wired to live `state.vscdb` or `~/Library/Application Support/Cursor`. No menu card. |
| Gemini | HOLD, not a card | **PASS** (HOLD) | Apps vs CLI stay distinct families. No card. No silent merge. |
| Codex | Challenger, default off | **PASS** (not production) | Parser has no filesystem API and no `~/.codex/auth.json` path. Live probe was `BLOCKED_PENDING_USER_AUTH`. Not a sixth provider. |
| Copilot | Architecture benchmark only | **PASS** (docs) | Docs-only (`S01H`). No Copilot Swift types, no UI. `/rate_limit` is a yardstick, not a shipped card. |

Production-needed items (ChatGPT, Claude, Grok) are **PASS**. None are UNCLEAR.

---

## Required controls

| Control | Status |
|---|---|
| Bearer tokens stripped from log strings | PASS (`V2LogRedactor` / `CodexLogRedactor`) |
| Session cookies stripped from log strings | PASS |
| Emails stripped from log strings | PASS |
| `V2UsageSource` has no chat/transcript APIs | PASS |
| Codex parser has no `auth.json` path | PASS |
| Cursor parser not wired to live `state.vscdb` | PASS |
| Foreign-cookie reuse (Tier 6) | PASS — disabled |
| Cookie-exists / WKWebView READY ≠ recovery success | PASS (S05/S06C) |
| No Basic Mode / estimated quota / fabricated `resetAt` | PASS |

---

## What this review is not

- Not a 72h Mac soak (S08)
- Not human vs official-page acceptance (S09)
- Not authorization to merge to `main` or publish (S10)
- Not a live Codex login

`main` stays `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`.
