# 17F-011 Grok Free Account Weekly Credits Probe

**Date:** 2026-09-02  
**GitHub Push to main:** NO  
**Merge:** NO  
**Production UI:** unchanged except a removable status-line probe label

## Stage

17F-011 (DISCOVERY ONLY)

## Base SHA

`13b010360ed2fee6e7226d0df823236757bdcf8b`

## Branch

`probe/17f-011-grok-free-weekly`

## Ending SHA

`21f3b64e6077f0a3d016ea321a9c64e934c1410f`

## Files

- `AIUsageBar/Service/GrokFreeCreditsProbe.swift` (new, removable)
- `AIUsageBar/ViewModels/UsageViewModel.swift` (status line only after Grok fetch)
- `AIUsageBarTests/AIUsageBarTests.swift`
- `Grok-17F-Handoff/17F-011-report.md`

## Behavior

After 17F-010B session restore and cookie header construction, GET `https://grok.com/rest/grok/credits` with the same in-memory Cookie header. Extract config fields only. Classify against **no active SuperGrok**. Do not set `weeklyRemainingPercent`. Do not add a Weekly row.

## Live endpoint

NOT RUN in this environment (no user Grok session).

## Human procedure

```bash
git fetch origin
git checkout probe/17f-011-grok-free-weekly
xcodebuild -project AIUsageBar.xcodeproj -scheme AIUsageBar -configuration Debug \
  -derivedDataPath /tmp/AIUsageBar-17F011 build
open /tmp/AIUsageBar-17F011/Build/Products/Debug/AIUsageBar.app
```

Do not re-login if restoration works. Refresh once. Copy the status line starting with `credits:`.
