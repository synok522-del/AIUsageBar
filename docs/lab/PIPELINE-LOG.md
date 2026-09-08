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
| S01F | 6b4fbd1aa5a4e1a775e34e74bb31afc0ab94187e | HOLD | T-1F-01…08 written. Production HOLD, no Cursor card, no `UsageProvider.cursor`. Parser in-memory only; does not open Application Support or `state.vscdb`. §16 FAIL list empty. Test execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE` (`xcodebuild` absent). Allowed HOLD — continue. |
| S01G | 2e3e46332749f28ab6b62135119e963012f64b30 | HOLD | T-1G-01…08 written. Apps=`gemini-apps`, CLI=`gemini-cli`, never merged. Missing one family ≠ unauth of the other. No Gemini card. Fabricated resetAt rejected. §16 FAIL list empty. Execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE`. Allowed HOLD — continue. |
| S01A | e5ee3b8615bf22ef8fe150a008438919ed1da826 | BLOCKED | `BLOCKED_PENDING_USER_AUTH`. Codex binary absent; login not runnable. `account/rateLimits/read` not captured and not invented. `~/.codex/auth.json` was **not** opened (T-1A-L4 = NO). ChatGPT production untouched. Allowed BLOCKED — continue. |
| S02 | 5a8f7a08561a57fcf7c7a219f33a42424760cbaa | PASS | T-2-01…15 written. Types frozen in `V2Architecture.swift` + `docs/V2_ARCHITECTURE_DECISION.md`. No ChatGPT/Claude/Grok migration. Cookie-exists / navigation-finished cannot produce FRESH. Primary-meter 20% alerts only. Named cooldown/backoff constants. Execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE`. §16 FAIL list empty. |
| S03 | 5e2a76c797f56a3ccb5d3f62dbf130ffc7f89590 | PASS | T-3-01…22 written. Adapters wrap V1 `parseUsage` / `parseRateLimits` / `validatedWeekly`. No UI rewrite. Codex + Claude snapshot-bridge default off. Cursor HOLD stub. Gemini two families not selected for UI. `billing_period_end` ignored as weekly reset. 133 `@Test` still counted in `AIUsageBarTests.swift`. Execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE`. §16 FAIL list empty. |
| S04 | 789c4bb3ba45189a921d83686b90f0798143ae52 | PASS | T-4-01…18 written. Cache slots split by account/meter/window. User-visible 20% alerts remain primary-meter-only. Existing ChatGPT/Claude/Grok 20% notification sequences still pass. Codex not merged (`NOT_PROVEN`). Gemini Apps/CLI never share a slot. Identity helper is pure. Execution `BLOCKED_PENDING_REAL_MAC_EVIDENCE`. §16 FAIL list empty. |
