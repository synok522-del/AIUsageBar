# 17F-010C Grok In-Process Session Self-Recovery

**Date:** 2026-09-02  
**GitHub Push to main:** NO  
**Merge:** NO

## Base

`13b010360ed2fee6e7226d0df823236757bdcf8b` (`review/17f-010b-grok-cold-start-session`)

## Branch

`review/17f-010c-grok-session-self-recovery`

## Ending SHA

`4422b81094b4af0ebaafd6a9c2a50f95350881c6`

## Files

- `AIUsageBar/Service/GrokSessionRecovery.swift` (new)
- `AIUsageBar/Service/GrokWebKitSessionRestorer.swift`
- `AIUsageBar/Service/GrokService.swift`
- `AIUsageBar/Service/ServiceSupport.swift`
- `AIUsageBar/ViewModels/UsageViewModel.swift`
- `AIUsageBarTests/AIUsageBarTests.swift`
- `Grok-17F-Handoff/17F-010C-report.md`

## Behavior

Restorer phases: unknown → restoring → ready. READY only if navigation finishes and WebKit grok.com cookies include `sso`. Timeout/failure/cancel leave unknown. Logout bumps generation so a stale completion cannot latch READY. WAF or HTTP 401 after a fetch invalidates READY, restores once, retries fetch once. Redirects leaving grok.com have Cookie stripped. ChatGPT/Claude still use `URLSession.shared`. No weekly/credits.
