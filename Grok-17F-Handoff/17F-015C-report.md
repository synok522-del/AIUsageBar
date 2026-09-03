# Sprint 17F-015C — UI launch-performance test stabilization

**Base:** `f45c4adca05705a789a4da25c5de06ff468c4c96`
**Branch:** `review/17f-015c-ui-test-stabilization`
**Production source:** NO
**Merge to main:** NO

## Classification

Xcode template / XCTest infrastructure. Not a Grok Weekly or session-recovery regression.

## Failure

`AIUsageBarUITests.testLaunchPerformance` — `XCTApplicationLaunchMetric` got 1 sample on iteration 0 and 0 on iteration 2.

## Why

The app is `LSUIElement` + `MenuBarExtra`. `XCTApplicationLaunchMetric` expects window/first-frame launch signposts. Agent apps often omit those on later `measure` relaunches.

## Change

Replace the metric loop with two real launches that assert the process is running (foreground or background), then terminate. Launch smoke stays; flaky duration metric does not.
