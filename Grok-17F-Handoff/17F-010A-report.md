# 17F-010A WebKit Cookie Store Crash Fix

**Date:** 2026-09-02  
**GitHub Push to main:** NO  
**Merge to main:** NO  
**Release:** NO

## Stage

17F-010A

## Goal

Stop the deterministic launch crash from first-touching `WKWebsiteDataStore.default()` off the main thread during startup `refreshAll()`, while keeping the 17F-010 / 009B full grok.com WebKit cookie context for Grok usage fetch.

## Base SHA

`9ad91e16092a6fa0683605d6850a44f39224e8a8`  
(`review/17f-010-grok-session-context-fix`)

## Branch

`review/17f-010a-webkit-cookie-crash-fix`

## Ending SHA

`PENDING_COMMIT`

## Files Changed

- `AIUsageBar/Service/WebSessionManager.swift`
- `AIUsageBar/ViewModels/UsageViewModel.swift`
- `AIUsageBarTests/AIUsageBarTests.swift`
- `Grok-17F-Handoff/17F-010A-report.md`

## Root Cause

`WebSessionManager.cookies(for:)` was a **nonisolated** `async` method. Calling it from `@MainActor refreshGrok()` hops onto the cooperative executor for the callee body. The continuation setup then ran:

`WKWebsiteDataStore.default()`

on a **non-main** thread, which enters `WebKit::runInitializationCode` / `WebsiteDataStore::defaultDataStore()` and traps.

This runs at launch because `MenuBarStatusView.task` / `UsagePanelView.task` call `refreshAll()` immediately. If Keychain already has a Grok token, `refreshGrok()` does not return early and hits the cookie store before any `WKWebView` has been created.

## Why 009B live probe did not show this

009B used the same nonisolated `cookies(for:)` helper. Human proof was after WKWebView login in a running app, so WebKit had already been initialized on the main thread. 17F-010 Mac retest launched the Debug binary with an existing Grok Keychain session and no prior WebView — first WebKit init was `default()` off-main.

## Implementation Summary

- Mark `WebSessionManager` `@MainActor`.
- Call `WKWebsiteDataStore.default()` on that actor, then `getAllCookies`.
- Run `refreshGrok()` on the current MainActor `refreshAll()` task (not `async let`) so the first-touch is the SwiftUI `.task` executor. ChatGPT/Claude remain `async let` so a Grok cookie wait does not delay starting those fetches.

Architecture unchanged: WebKit grok.com cookies → in-memory Cookie header → `POST /rest/rate-limits`, Keychain fallback if no `sso`.

## Tests Written

- `@MainActor` access of `WebSessionManager.shared` (does **not** call `cookies(for:)`, which would initialize WebKit in the test host)

Existing `GrokSessionContext` synthetic-cookie tests unchanged.

## Tests Actually Run

Automated Mac Tests: **NOT RUN** (Linux; no `xcodebuild`)

## Debug Build Actually Run

Debug Build: **NOT RUN**

## Release Build Actually Run

Release Build: **NOT RUN**

## Self-Review

Diff vs `9ad91e1` is MainActor isolation, `refreshAll` scheduling of Grok, one test, this report. No weekly, no probe strings, no ChatGPT/Claude behavior change, `main` untouched.

## Human Verification Still Required

Isolated Debug launch, process path, Grok short-window refresh, `xcodebuild test`, Release build.
