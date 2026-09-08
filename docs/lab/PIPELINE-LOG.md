# Cursor V2 pipeline log

**Branch:** `cursor/v2-pipeline-48a2`  
**Base:** `origin/cursor/v2-experiment-48a2` `ebdd2034818ccf29aa2c59c682e10a2ab8d25ad0`  
**Frozen production / `main`:** `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`  
**Orchestrator:** PIPELINE conversation (not Build / Review / Plan)

Per-sprint review is recorded here before the next sprint starts. Linux `xcodebuild` absence is `BLOCKED_PENDING_REAL_MAC_EVIDENCE`, not a faked PASS.

| sprint | commit SHA | verdict | notes |
|---|---|---|---|
| BOOTSTRAP | 54f561269daccc01d1f83f5b6bb89cf9cd5e2d00 | PASS | Imported `docs/V2.1-SPRINT-PLAN.md` and `docs/V2.1-PIPELINE-ORCHESTRATOR-PROMPT.md` from `origin/cursor/v2-sprint-plan-48a2` only. Start SHA confirmed `ebdd203`. `main` still `d6a4bd7`. No Swift / production change. |
| S01H | fa787536a05b93fdc31ff385db62ae8a91aa6e98 | PASS | Cherry-pick of `018130d` applied cleanly (plus this log). Docs only (`docs/lab/S01H-copilot-benchmark.md`). No Copilot Swift types, no UI card. §16 FAIL list empty. Tests: 0 (as specified). |
| S01F | c0ffce9d3717507e04e0ea983aff9d993f75a141 | HOLD | T-1F-01…08 written. Production HOLD, no Cursor card, no `UsageProvider.cursor`. Parser in-memory only; does not open Application Support or `state.vscdb`. §16 FAIL list empty. Test execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE` (`xcodebuild` absent). Allowed HOLD — continue. |
