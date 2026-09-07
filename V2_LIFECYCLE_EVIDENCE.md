# V2_LIFECYCLE_EVIDENCE.md

**Stage:** 8  
**Gate:** `BLOCKED_PENDING_REAL_MAC_EVIDENCE`

## Environment

Linux Cursor Cloud agent. `xcodebuild` absent. Kenny Mac path not mounted.

## Must not fake

Overnight idle, sleep/wake, 72h soak, Debug/Release, focused+full scheme, Developer ID — **NOT RUN**.

## What was executed here

| Item | Result |
|---|---|
| Focused V2 Swift tests | **NOT RUN** (no Xcode) |
| Full scheme | **NOT RUN** |
| Debug / Release | **NOT RUN** |
| 72h soak | **NOT RUN** |
| Overnight / sleep-wake | **NOT RUN** |
| Network interrupt | **NOT RUN** |
| Relaunch / account switch on device | **NOT RUN** |
| Reset crossing live | **NOT RUN** |

Deterministic V2 unit tests were **authored** (`AIUsageBarTests/V2UsageLayerTests.swift`) covering validity, identity, notifications, recovery latch/generation, adapters.

## TRUE BLOCKER

Required real Mac lifecycle evidence cannot be generated in this environment.

After Mac gate, replace this file’s gate with `LIFECYCLE_PASS` only if commands actually succeed.
