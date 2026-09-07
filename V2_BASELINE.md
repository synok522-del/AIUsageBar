# V2_BASELINE.md

**Stage:** 0 — Freeze Production Baseline  
**Status:** `BASELINE_FROZEN`  
**Experiment branch:** `cursor/v2-experiment-bbad`  
**Frozen base SHA:** `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`  
**Commit subject:** `release: bump build to 4 for beta 3`  
**Date:** 2026-09-07  
**Environment:** Linux Cursor Cloud agent (no Xcode). Mac tests/builds: **NOT RUN**.

This file is the Stage 0 deliverable for the frozen AIUsageBar V2.1 experiment. It does **not** change production behavior. It does **not** add ChatGPT/Grok browser recovery.

---

## 1. Reproducible starting boundary

| Field | Value |
|---|---|
| SHA | `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a` |
| Marketing version | `1.0.0` (`MARKETING_VERSION`) |
| Build | `4` (`CURRENT_PROJECT_VERSION` for the app target) |
| Bundle ID | `synok522.AIUsageBar` |
| Deployment | macOS 13.0 |
| `LSUIElement` | menu bar app, no Dock icon |
| App Sandbox | **disabled** (`AIUsageBar.entitlements` is empty) |
| Hardened Runtime / Developer ID / notarization | **NOT_VERIFIED** in this Linux environment |
| Working tree at freeze | clean at checkout of frozen SHA |
| Merge / publish | forbidden for this experiment |

README still says build number `1` in prose; **project file is the authority: Build 4**.

---

## 2. Current provider source behavior (from source)

### ChatGPT

- **Auth owner:** WKWebView login (`https://chatgpt.com/auth/login`) captures `__Secure-next-auth.session-token` / `__Host-` / `next-auth.session-token` (possibly chunked).
- **Durable:** Keychain `chatGPTSessionToken` + `chatGPTCookieHeader`.
- **Usage source:** Cookie → `GET https://chatgpt.com/api/auth/session` → Bearer `accessToken` → `GET https://chatgpt.com/backend-api/wham/usage`.
- **Meters:** `rate_limit.primary_window` (UI 5-hour) and optional `secondary_window` (Weekly). Remaining = `100 - used_percent`.
- **Recovery on this SHA:** **none**. Refresh always uses the Keychain cookie snapshot. 401 → `ChatGPT 登入已失效，請重新登入`. Last-known usage preserved if already loaded.
- **Identity:** token presence only. No accountKey. Logout does not invalidate an in-flight ChatGPT generation (unlike Grok).

### Claude

- **Auth owner:** WKWebView login; cookie `sessionKey` on claude.ai / anthropic.com.
- **Durable:** Keychain `claudeSessionKey`.
- **Usage source:** `GET https://claude.ai/api/organizations` then `GET …/api/organizations/{id}/usage` with `Cookie: sessionKey=…`.
- **Meters:** `five_hour.utilization`, `seven_day.utilization` (used %); remaining = `100 - used`. Reset from `resets_at`.
- **Recovery on this SHA:** **none**.
- **Identity:** first organization id/uuid; no explicit account-switch generation.

### Grok

- **Auth owner:** WKWebView login on `https://grok.com/`; `sso` (+ `sso-rw`) cookies.
- **Durable:** Keychain `grokSessionToken` + `grokCookieHeader`.
- **Usage source:**
  - Short window: live WebKit grok.com cookies (fallback Keychain) → `POST https://grok.com/rest/rate-limits` `{"modelName":"grok-3"}`.
  - Weekly (paid): `POST …/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig` gRPC-Web. Remaining = `100 - round(clamp(used))`. Reset = `current_period.end` only.
- **UI:** exactly one Grok row — `每週` if valid Weekly, else dynamic short-window.
- **Recovery on this SHA (010C, merged):** WAF/401 → at most one `restoreAfterRecoverableFailure` (hidden `https://grok.com/` WKWebView) → one retry. READY latch after usable `sso`. Logout/account replace increments `GrokHTTPAuthGeneration` so stale in-flight results cannot commit. Redirects strip Cookie off grok.com hosts.
- **Overnight WAF with READY + stale jar:** classified below; **Stage 0 does not implement a new restorer**.

### Cursor / Gemini / Copilot / Codex

- **Not present** as providers in this SHA. No UI, no services.

---

## 3. Current UI / notifications (must preserve)

- `MenuBarExtra` + per-provider remaining bars; ChatGPT/Claude/Grok cards; Settings login/logout; 20% remaining notification once per provider until reset/account change.
- Notification identity today: `UsageNotificationProvider` only (not `accountKey+meterId+window`). Account switch for **Grok** resets Grok tracking; ChatGPT/Claude logout does not use Grok-style generation.
- Visibility: provider appears iff its stored credential is non-empty.

---

## 4. Current tests / builds

- Unit tests live in `AIUsageBarTests` (Swift Testing). Count at freeze: **133 `@Test` methods** in `AIUsageBarTests.swift`.
- Coverage includes ChatGPT/Claude parse, Grok cookies/Weekly protobuf, Grok lifecycle doubles, notifications, visibility.
- **This environment cannot run `xcodebuild`.** Stage 0 does not invent Mac PASS.
- No Debug/Release build evidence from this agent.

---

## 5. V1 recovery classification (Stage 0 required)

| Provider | Classification | Evidence |
|---|---|---|
| ChatGPT browser/session recovery | `DEFERRED_TO_V2` | No restore/retry. Human overnight 401 required logout→login. Not a Stage 0 production patch. |
| Claude browser/session recovery | `DEFERRED_TO_V2` | Cookie fetch only; no restorer. |
| Grok in-process WAF/401 restore | `RESOLVED` | 010C restorer + generation + one retry exist at this SHA. |
| Grok overnight READY/stale-WAF without logout | `DEFERRED_TO_V2` | Human evidence after Build 4; Stage 0 must **not** build a new ChatGPT/Grok browser recovery architecture. |
| ChatGPT/Grok 17F-017/018 branches | **out of this experiment base** | Experiment starts at `d6a4bd7`, not those review branches. |

No `PRODUCTION_REGRESSION_MUST_FIX` is opened in Stage 0: Build 4 is the frozen shipping baseline; V2.1 recovery coordinator is Stage 5.

---

## 6. Architecture facts V2 must not forget

1. Provider currently **owns auth in WKWebView** and **owns usage via unofficial HTTPS** (except Grok weekly gRPC-Web).
2. AUTHENTICATION, USAGE SOURCE, ACCOUNT IDENTITY, METER IDENTITY, RECOVERY, UI are **collapsed** in `UsageViewModel` + `UsageInfo`.
3. Windows are UI-labeled (5-hour / 每週) not semantic `UsageWindow` types.
4. Freshness is not modeled (`isLoaded` + optional `errorMessage` only).
5. Recovery success today (Grok) = restore outcome + retry HTTP, not a source-agnostic coordinator.

---

## 7. Stage 0 gate

- Objective: exact reproducible V2 starting boundary — **met**.
- Starting SHA: `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`
- Files changed: this document only (after commit).
- Tests run: none (Linux).
- Builds run: none.
- Gate: **`PASS` / `BASELINE_FROZEN`**
- Continue automatically to Stage 1.
