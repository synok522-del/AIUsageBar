# AIUsageBar V2.1 — Cursor track baseline (S00)

**Sprint:** S00  
**Track:** Cursor V2  
**Date:** 2026-09-08  
**Status:** docs-only freeze. Production behavior is unchanged.

This document makes the Cursor V2 experiment reproducible. It does not implement V2 usage adapters, new providers, UI, a recovery coordinator, Codex, Basic Mode, or a UI redesign. ChatGPT / Claude / Grok card language stays as shipped.

---

## Frozen production identity

| Field | Value |
|---|---|
| Frozen SHA | `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a` |
| Frozen commit | `release: bump build to 4 for beta 3` |
| Marketing version (app target) | `1.0.0` |
| Build (`CURRENT_PROJECT_VERSION`, app target) | `4` |
| Current UI providers | ChatGPT, Claude, Grok |
| Cursor / Gemini cards | **Forbidden until Stage 6 PASS** |
| Copilot | Architecture benchmark only. Not a product card. |
| Merge to `main` | **This branch and the Cursor experiment branch must never merge to `main` during the experiment.** |

---

## Cursor integration branch

| Check | Result |
|---|---|
| `origin/cursor/v2-experiment-48a2` exists | Yes |
| Tip SHA | `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a` |
| Commits on experiment that are not in frozen SHA | None (tip **is** the frozen SHA) |
| ChatGPT/Astra / `cursor/ai-usage-tracking-architecture-research-48a2` as parent | Not used |
| Merged to `main` as extra experiment work | **No.** `origin/main` is the same SHA. There are no Cursor-track experiment commits beyond the freeze, so nothing extra has been merged to `main`. |

S00 start SHA is therefore exactly the frozen production SHA. That is correct.

---

## UI and product freeze (source)

Menu cards in `AIUsageBar/Views/UsagePanelView.swift` are ChatGPT, Claude, and Grok only. Setup copy is `登入 ChatGPT、Claude 或 Grok`. No Cursor, Gemini, or Copilot card exists in this tree.

---

## Production tests (S00-R1 … S00-R133)

`AIUsageBarTests/AIUsageBarTests.swift` contains **133** `@Test` cases at this SHA.

| Item | Result |
|---|---|
| Tests changed in S00 | 0 |
| Tests added in S00 | 0 |
| Execution on this Linux/cloud environment | **BLOCKED_PENDING_REAL_MAC_EVIDENCE** (`xcodebuild` is not available; do not fake PASS) |
| Failures observed here | None (suite was not executed) |
| `PRODUCTION_REGRESSION_MUST_FIX` from this environment | None reported. A real Mac must still run the 133 tests before S00 review can treat S00-R1…R133 as PASS. |

---

## V1 ChatGPT / Grok recovery classification

Classifications below are from this SHA’s source. Cookie-exists, navigation-finished, and WKWebView READY are **not** recovery success for V2. S00 does not rebuild recovery.

| ID | V1 path | Classification | Evidence / rule |
|---|---|---|---|
| S00-C1 | ChatGPT Keychain cookie → `/api/auth/session` → Bearer → `/backend-api/wham/usage` | **RESOLVED** | Keep as the production ChatGPT source. `UsageViewModel` stores Keychain cookie/header; `ChatGPTService.fetchUsage(cookieHeader:)` loads session then `wham/usage`. Not a new recovery framework. |
| S00-C2 | ChatGPT 401 → `登入已失效，請重新登入` | **RESOLVED** | Keep. `AIUsageServiceError.httpStatus(_, 401)` maps to that copy in `ServiceSupport`. ChatGPT has **no** hidden `WKWebView` restorer in current code. |
| S00-C3 | Grok `GrokWebKitSessionRestorer` READY = navigation finished AND `sso` cookie exists | **DEFERRED_TO_V2** | Do not expand this framework in S00. READY is latched after navigation completes with a usable grok.com `sso` cookie (`GrokWebKitSessionRestorer`). Cookie-exists / navigation-finished / WKWebView READY is **not** recovery success. Rewrite success in later sprints (S06C). |
| S00-C4 | Grok restore in-flight / generation race | **RESOLVED** | Keep as production race fix. `GrokHTTPAuthGeneration` + `GrokHTTPRefreshAuthPolicy.shouldCommit` drop stale HTTP/restore completions. Success *definition* is rewritten later in S06C; the race gate stays. |
| S00-C5 | Grok logout generation invalidation | **RESOLVED** | Keep. `setGrokCredential` identity change calls `grokHTTPAuthGeneration.invalidate()`, clears usage, `grokSessionRestorer.reset()`, and notification tracking. |
| S00-C6 | Grok redirect Cookie-header strip | **RESOLVED** | Keep. `GrokRedirectPolicy.requestAfterRedirect` strips `Cookie` when the redirect host is not a Grok product host. |
| S00-C7 | Grok Keychain `sso` fallback | **RESOLVED** | Keep as **credential store**, not as recovery-success proof. Empty WebKit cookie list falls back to Keychain/header via `GrokSessionContext.cookieHeaderForRequest`. Presence of that header does not prove recovery. |
| S00-C8 | Notification keyed only by provider | **DEFERRED_TO_V2** | `UsageNotificationState` keys `lastValidPercent` / `notifiedProviders` by `UsageNotificationProvider` only. Identity lands in S04. User-visible alerts stay displayed-primary-meter-only, 20% crossing once. |

No ChatGPT/Grok V1 path on this SHA is classified `PRODUCTION_REGRESSION_MUST_FIX` from source review. That label is reserved for a failing existing test or a proven production break; neither was observed here (tests not executed on Mac).

---

## What S00 must not do (confirmed)

- No usage adapters  
- No new providers  
- No UI / card language change  
- No recovery coordinator  
- No Codex  
- No Basic Mode  
- No publish / notarize  
- No merge to `main`  
- No merge of this sprint into `cursor/v2-experiment-48a2` (independent review does that later)

---

## Lineage for review

| Item | SHA / name |
|---|---|
| Frozen production / experiment tip / S00 start | `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a` |
| S00 branch | `cursor/v2-s00-baseline-48a2` |
| PR base (required) | `cursor/v2-experiment-48a2` |
| PR base must not be | `main` |
