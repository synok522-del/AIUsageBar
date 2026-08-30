# 17F-005 Menu bar 1 / 2 / 3 providers

## Task objective
Support Grok as the third Menu Bar usage provider. 0 providers keep the disconnected state. 1/2/3 authenticated providers draw 1/2/3 bars in ChatGPT → Claude → Grok order. Grok 0% stays visible. Three bars stay compact.

## Starting branch
review/17f-004-grok-provider

## Starting SHA
ee423c556a2442270d5619d3027f9fd3d9021581

## Ending SHA
see git rev-parse HEAD on this branch

## Files changed
- AIUsageBarTests/AIUsageBarTests.swift (MenuBarStatusLayout + Grok combination help text)
- Grok-17F-Handoff/17F-005-report.md
- Grok-17F-Handoff/verification/17F-005/

MenuBarStatusView and MenuBarStatusLayout already landed earlier so 002–004 compile. This sprint locks layout metrics and combination help text.

## Work completed
- 0 providers: existing disconnected / `AIUsageBar` help text.
- 1 provider: one centered bar, image 24×10, bar height 4.
- 2 providers: two bars, image 24×10, bar height 4.
- 3 providers: three bars, image 24×16, bar height 3.
- Combinations: ChatGPT only, Claude only, Grok only, ChatGPT+Claude, ChatGPT+Grok, Claude+Grok, all three.
- Order: ChatGPT → Claude → Grok.
- 0% Grok remains visible (credential-based visibility). Loaded 0% still uses the existing min 2px fill.
- No company logos.

## Tests performed
- Layout metrics for 0/1/2 vs 3 providers
- Grok-only and pair/all-three help text

Existing one-bar and two-bar ChatGPT/Claude help-text tests kept.

## Exact test results
AUTOMATED TESTS: WRITTEN. Execution NOT RUN on this Linux box.

## Build results
Debug: NOT RUN
Release: NOT RUN

## Problems encountered
- Production menu-bar drawing already on earlier branches for exhaustive-switch compile-safety.

## Problems fixed
- 1/2/3 layout numbers and Grok combination help text are now tested.

## Remaining risks
- Compactness of three 3px bars in a real macOS menu bar is visual-only.
- 0% min-2px fill matches ChatGPT/Claude; a truly empty 0% bar was not requested as a behavior change.

## Human verification still required
- Visual check of 0/1/2/3 bars in the live menu bar, including Grok-only and all three.
- Confirm 0% and 100% Grok bars render.
- Compile + test on macOS.

## GitHub branch name
review/17f-005-grok-menubar

## Exact GitHub branch URL
https://github.com/synok522-del/AIUsageBar/tree/review/17f-005-grok-menubar
