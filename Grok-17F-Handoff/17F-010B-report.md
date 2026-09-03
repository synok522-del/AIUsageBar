# 17F-010B Grok Cold-Start Session Restoration

**Date:** 2026-09-02
**GitHub Push to main:** NO
**Merge to main:** NO
**Release:** NO

## Stage

17F-010B

## Goal

After process restart, restore a legitimate grok.com WebKit browsing session so Grok usage fetch can succeed without opening the login window or re-entering credentials.

## Base SHA

`c1e14fb485dd5752bf35c0624595af5362b37145`
(`review/17f-010a-webkit-cookie-crash-fix`)

## Branch

`review/17f-010b-grok-cold-start-session`

## Ending SHA

`2b3b404ca1af780f8ec0fa4c3e684072f896e150`

## Files Changed

- `AIUsageBar/Service/GrokWebKitSessionRestorer.swift` (new)
- `AIUsageBar/Service/WebSessionManager.swift`
- `AIUsageBar/ViewModels/UsageViewModel.swift`
- `AIUsageBarTests/AIUsageBarTests.swift`
- `Grok-17F-Handoff/17F-010B-report.md`

## Root Cause

Cold start reads `WKWebsiteDataStore.default().httpCookieStore` **without** a WKWebView navigation. Keychain still has `sso`, so Settings shows Grok authenticated. Cloudflare/session cookies are typically **session-only** and do not survive process exit. The fetch then uses Keychain `sso`/`sso-rw` (or a persistent-only jar) → WAF HTML.

Opening Grok Login creates a WKWebView on the default store and loads `https://grok.com/`, which re-establishes session cookies using the existing authenticated WebKit data. Refresh then succeeds. Human “重新登入” does not prove credentials must be typed again.

Repeated Refresh without a WebView never repairs this (not a short readiness race).

## Implementation Summary

Before the Grok URLSession fetch, `GrokWebKitSessionRestorer` (MainActor) creates a hidden WKWebView on `WKWebsiteDataStore.default()`, loads `https://grok.com/` (same URL as login, no form fill), waits for navigation finish/fail or 20s timeout, then `cookies(for: .grok)` proceeds. The WebView is kept for the process so session cookies remain. Logout calls `reset()`.

No weekly. No probe UI. No new Keychain jar persistence.

## Tests Written

- Session-only grok.com cookies remain applicable (names/metadata only)
- Restorer URL is `https://grok.com/` and matches login URL
- Existing GrokSessionContext / MainActor tests preserved

`restoreIfNeeded()` is not called from tests (would initialize WebKit).

## Tests / Builds Actually Run

Automated Mac Tests: **NOT RUN**
Debug Build: **NOT RUN**
Release Build: **NOT RUN**
