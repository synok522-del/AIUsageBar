# AIUsageBar V2.1 — Astra Engineering Takeover Review Packet

Status: READY_FOR_INDEPENDENT_REVIEW. This is not release approval.

## Boundaries and reproduction

- Repository: https://github.com/synok522-del/AIUsageBar
- Frozen production: `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a` (1.0.0, build 4).
- Cursor C0: `db8ffb44707e97dae23835471f761e6c25776598`.
- Cursor C1 / exact Astra start: `e7617fc2375b699b46ae61e9070074316cc9a0a8`.
- Astra implementation: `b8b8b5c9b3ba8d5e09621acd0ad8fc82c2ef935d`.
- Branch: `astra/v2-engineering-takeover`, local only.
- The subsequent review-packet commit changes documentation only. The final report and sibling `astra-v21-evidence/manifest.txt` identify the exact final HEAD, including this packet. Verify source equality against the implementation commit before attributing its test evidence to a later documentation commit.

The initial clone was clean on main at the frozen production SHA. Both ancestry checks succeeded: production → C0 → C1. C1 was inspected with `git show` and `git diff` before checkout or production edits. C1 is a repairable structural base; no rollback was necessary. Cursor branch and commits remain unchanged.

```sh
git rev-parse HEAD
git status --short --branch
git merge-base --is-ancestor d6a4bd7 e7617fc
git merge-base --is-ancestor e7617fc HEAD
git log --reverse --oneline e7617fc..HEAD
git diff e7617fc..HEAD
git diff d6a4bd7..HEAD
git diff --exit-code e7617fc HEAD -- AIUsageBar/Views AIUsageBar/App AIUsageBar/Login AIUsageBar/Coordinator AIUsageBar/Assets.xcassets AIUsageBar/Models/UsageInfo.swift
git diff --exit-code d6a4bd7 HEAD -- AIUsageBar/Views AIUsageBar/App AIUsageBar/Login AIUsageBar/Coordinator AIUsageBar/Assets.xcassets AIUsageBar/Models/UsageInfo.swift
```

## Takeover audit: disproof of Cursor claims

| Claim | Independent finding at C1 | Astra action |
|---|---|---|
| Real production UsageSource path | Confirmed: all three refresh methods invoke conformers and create snapshots. Generation checks protect completions. | Retained; made snapshot validity a commit gate before V1 UI mapping. |
| V2 validity governs correctness | Rejected: `v2PrimaryMeterValidity` was a query; production committed regardless. Only primary reset was evaluated. | Validate every included meter; reject malformed/expired results; invalidate loaded V1 data at reset without another fetch. |
| Recovery succeeds only after fresh usage | Partly confirmed: retry response was required; parse proof was only nonempty meters and request credential was restamped as identity. | Gate requires a fresh, valid snapshot and matching scope; enforce actual request-cookie binding. |
| One restore + one retry | Partly rejected: recursive `fetchGrokUsage` called `restoreIfNeeded` before initial and retry fetch, outside the V2 restore counter. | Removed prefetch restore. Only the counted recoverable-failure path restores, once; retry failure latches. |
| Identity unavailable is supported | Helper policy confirmed; successful adapters with empty credentials incorrectly labeled health unauthorized. Anonymous cache reuse correctly refused. | Successful parsed observation gets available health; nil account stays nil and cannot be cached. |
| Real reset timestamps threaded | Confirmed in provider parsers, models, adapters. | Retained; now consumed in production validity and cache lookup. Reject nonfinite/boolean/invalid timestamp inputs. |
| Production integration tests | Authored and partly meaningful, not Mac executed. Six mutating calls inside Swift Testing expectations failed compilation under this Xcode. Tests touched the real Keychain through ViewModel. | Evaluated mutating results before expectations; isolated test stores and host behavior; executed on Mac. |
| Cache/identity robustness | Disappeared meter entries persisted; noncryptographic DJB2 credential fingerprint. | Replace account's cached meter set atomically; SHA-256 fingerprint; reject expired lookup; custom window duration participates in identity. |
| Primary notification integration | V2 kept a second diagnostic notification state while the real manager remained provider-only. | Removed runtime duplicate; existing notification manager scopes history and pending delivery to account, meter, window, duration and real reset. |

Additional repairs: clear ChatGPT/Claude display and notification tracking on credential changes; prevent Grok WK cookies for B being labeled as A; guard stale WebKit callbacks and cancelled timeout tasks; prevent concurrent restorer continuation replacement; keep provider fetch entry points on MainActor; prevent cross-origin/downgrade redirects for ChatGPT/Claude; reject Grok HTTPS downgrade and strip Authorization with Cookie on foreign redirects; prevent numeric overflow converting Grok window size.

### Cursor code retained / modified / removed

Retained: all three endpoints and parsers, provider models, snapshot/meter types, source conformers, coordinator states, generation architecture, UI mapping, existing notification content and delivery, all original tests and historical Stage documents.

Modified: production orchestration, validity and identity policies, cache replacement/read rules, source credential binding, recovery proof, notification scope, test isolation and assertions. ServiceSupport transport and numeric boundary hardening are Astra additions.

Removed: uncounted Grok prefetch restore; V2 runtime's duplicate notification sampler; age-only six-hour expiration; DJB2 fingerprint implementation. No source file or Cursor commit was deleted. Historical Stage documents remain historical evidence and do not override this packet.

## Final architecture and invariants

`UsageViewModel` → provider production `UsageSource` → existing service/parser → provider model + real reset timestamps → `UsageSnapshot` → captured-generation check + cancellation check + validity gate → existing `UsageInfo` → unchanged views.

There is one existing logical usage fetch per provider refresh. ChatGPT's existing session+usage requests, Claude's organization+usage requests, and Grok's short+optional weekly requests are retained. Recovery adds at most one Grok logical fetch. No challenger provider runs in parallel.

Snapshots support provider/account/meter/window, percentages, optional absolute used/remaining/limit, overage and entitlement, real reset, observation time (`asOf`), health, and derived validity. Unknown optional values remain nil. Grok custom window duration is included in cache and notification identity. Existing ChatGPT 5h/weekly and Claude 5h/7d taxonomy is retained; no Codex/CLI entitlement is inferred from these names.

Account scope is a SHA-256 fingerprint of AIUsageBar's own session credential, not a verified durable provider user ID. It is intentionally conservative across token rotation. It must not be represented as independently proven account equivalence. ChatGPT actual header must reassemble to the captured credential; Grok short and weekly headers must both match captured sso. Claude uses its captured sessionKey. Transport no longer inherits shared URLSession cookies. Generation changes invalidate old completions and relevant cache/recovery/notification state. No foreign app/CLI credentials are read.

When identity is genuinely unavailable, successful usage remains possible; nil identity never produces a reusable cache entry. Production login still requires a credential, which is distinct from availability of a durable provider account ID.

Freshness: ≤120 seconds is fresh, older is stale-but-valid while identity and reset allow it. Age alone is not quota expiry. Any real meter reset at `now >= resetAt` expires the snapshot. Snapshot invalidity includes malformed meters, inconsistent identity availability, bad health, duplicate meter IDs and implausibly future observation time. The existing card interface cannot represent per-field expiry; conservatively invalidate the whole loaded card if any included meter expires, using its existing error state. This changes correctness behavior, not presentation code. A one-second local timer evaluates expiry without making network requests. Actual sleep/wake timing still needs observation.

Grok recovery: HTTP 401/WAF → begin scoped cycle → consume one restore → await WebKit → generation check → consume one retry → fresh usage/parse/identity/validity → healthy or latched requires-user-action. Cookie/WK readiness alone is never success. A failed retry latches even if restore reported success. Polling while latched can make an ordinary usage request but cannot restore or unlatch. A meaningful credential/session generation change re-arms. Account drift is rejected rather than silently adopting another WK account.

Notifications: the existing 20% crossing rule, content, sound, and one provider request identifier remain. Only displayed primary participates (Grok weekly if available, otherwise short; ChatGPT/Claude session). Account, meter, window, duration and reset changes seed a new history, never infer a crossing between different identities. Pending payloads carry generation and expire after the freshness interval. No extra user-visible notification system or secondary-meter alerts.

## Provider matrix

Technical retention and compliance are separate decisions. None of the source classifications below is provider permission or a release approval.

| Provider | Source and account scope | Meters/window/reset | Equivalence | Security / compliance | Decision |
|---|---|---|---|---|---|
| ChatGPT | Existing WK cookie → auth/session → wham/usage; request-bound session hash | Primary 5h taxonomy, optional weekly; response reset_at only | Codex equivalence NOT VERIFIED | App-owned credentials, isolated HTTPS; LIKELY_DISALLOWED absent an applicable authorization for automated extraction | FALLBACK |
| Claude | Existing sessionKey → organization → usage; session hash | five_hour/seven_day; resets_at only | Statusline challenger NOT VERIFIED | No Claude Code OAuth reuse; LIKELY_DISALLOWED absent explicit permission | FALLBACK |
| Grok | Existing rate-limits + GetGrokCreditsConfig; both request sso values bound to captured hash | Short custom duration; optional weekly; resetAt and current_period.end; never billing_period_end | No challenger equivalence established | App-owned WK; HTTPS downgrade blocked; LIKELY_DISALLOWED absent authorization for automated access | FALLBACK (retained source; regression tests pass, live/provider compliance gate incomplete) |
| Cursor | No production source; no account read | Unknown | NOT VERIFIED | Private DB/RPC/credential reuse UNCLEAR | HOLD, hidden |
| Gemini Apps | No production source; no account read | Unknown | Apps ≠ CLI/Code Assist until proven | Proposed migration UNCLEAR | HOLD, hidden |
| Codex | Official local RPC proposal only; not invoked here | Independent meters/window/reset unverified in this takeover | NOT equivalent to ChatGPT without account/entitlement/window/reset/delta evidence | Documented-interface approach is conditional LIKELY_ALLOWED; exact integration not reviewed | HOLD, hidden |
| Copilot reference | No production implementation or credential access | Multi-meter reference only | No product equivalence claim | Private endpoint proposal UNCLEAR | REJECT as V2.1 product provider; reference retained |

Grok's earlier “official-enough” PASS rationale is rejected as compliance evidence. Keeping the authorized existing source does not promote a new private integration or certify release legality.

### Current compliance evidence

Reviewed 2026-09-08. Classifications are conservative engineering inferences, not legal determinations. Resolve applicable provider authorization before release. No migration is authorized from technical feasibility alone.

- [OpenAI Terms of Use](https://openai.com/policies/row-terms-of-use/) restrict automated/programmatic extraction and bypass of protective measures.
- [Anthropic Consumer Terms](https://www.anthropic.com/legal/consumer-terms) restrict automated non-human access except through API keys or explicit permission. The retrieved page served a Korean localization; no assertion about a new regional exception is made.
- [xAI Acceptable Use Policy](https://x.ai/legal/acceptable-use-policy) restricts unauthorized automated access and bypass of protective measures.

No live challenge bypass, CAPTCHA solving, OAuth extraction, CLI configuration edit, statusline bridge installation, paid action or provider migration was performed.

## UI freeze

UI_FILES_CHANGED: NO, against both C1 and frozen production for Views, App, Login, Coordinator, assets, and UsageInfo presentation helpers. Visual behavior intentionally redesigned: NO. Provider ordering, labels, dimensions, styles, settings and notification presentation are retained. Only incorrect/stale data state is cleared using existing rendering.

Source equality is not a screenshot comparison. Visual cards/order, live account values and acceptance are NOT VERIFIED. The GUI tool first encountered a locked Mac; after unlocking, candidate selection repeatedly timed out. Bundle selection was ambiguous across installed copies. Exact-path process inspection confirmed the Astra Release binary launched; a one-second sample showed its AppKit event loop, not an observed deadlock. The candidate process was then stopped by its verified PID; the installed production app was left running. Do not treat this as a completed visual Mac Gate.

## Verification evidence

Environment: macOS 26.5.2 (25F84), arm64; Xcode 26.6 (17F113). App deployment target remains macOS 13.0. Version/build unchanged at 1.0.0/4.

- AUTHORED: 15 additional Astra tests in `AstraTakeoverTests.swift` covering production expiry, reset boundary, ChatGPT/Claude suspended account switches, wrong Grok cookie identity, cache replacement, secondary expiry, actual notification manager, parser reset threading, chunked credential binding, recovery latch/re-arm, logout during restore, custom window identity and redirect protections.
- EXECUTED / PASSED: 171 tests in 4 suites at implementation SHA b8b8b5c, including existing provider regressions, Cursor V2 layer and integration tests, and Astra tests. Latest code-run xcresult: `../astra-v21-evidence/code-candidate.xcresult`.
- EXECUTED / PASSED: Debug build as part of test; Release build with CODE_SIGNING_ALLOWED=NO. Release binary contains b8b8b5c Git metadata; only linker ad-hoc signing, no Developer ID identity/notarization.
- Earlier FAILED: Cursor mutating #expect compilation; repaired. Astra actor-isolated default initializer attempt failed compilation; repaired with method-level actor isolation. Earlier test execution BLOCKED by sandbox testmanagerd; retried through the approved native test runner and passed. No unresolved test failure in the successful candidate run.
- Build warnings: Xcode test libraries have macOS 14 minimum while project tests target macOS 13; no claim of macOS 13 runtime validation. Optional AppIntents extraction reports no dependency. Actor warning on immutable restorer constants repaired.
- AUTHORED only / NOT EXECUTED: real-account acceptance and lifecycle plan below. UI-test bundle compilation does not equal live card verification.

Reproduce from a clean exact checkout (use absolute paths outside the repository for logs/DerivedData):

```sh
xcodebuild -project AIUsageBar.xcodeproj -scheme AIUsageBar -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/astra-v21-build -only-testing:AIUsageBarTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project AIUsageBar.xcodeproj -scheme AIUsageBar -configuration Release -derivedDataPath /tmp/astra-v21-release CODE_SIGNING_ALLOWED=NO build
```

Test ViewModels use isolated in-memory credentials. The test-host path suppresses Keychain migration, automatic timers and notification authorization/delivery; pure notification decisions are still exercised. This isolation intentionally does not claim a real Keychain, auto-timer, notification-center or WebKit recovery test.

## Security/privacy review

No secret values logged or copied into this packet. Existing diagnostic logs use errors/status, hashed names/domains/URLs and cookie lengths; no raw Cookie/Authorization headers were added. Session fingerprints and quota cache remain process-local. No prompt/chat content stored. Keychain service and account names remain compatible. Test fixtures cannot overwrite real credentials. WebKit uses AIUsageBar's own default data store; disconnect behavior remains provider-scoped and no other official CLI/app session was edited. ChatGPT/Claude transport uses ephemeral sessions without shared cookies/cache, and strict same-origin HTTPS redirects. Grok retains its isolated session and strips credentials on foreign redirects.

Remaining security/compliance evidence: real Keychain ACL/signing behavior on the distribution build; real WebKit account transitions; supported provider authorization; provider schema stability. Session hashes are not independently verified durable account IDs. Cookie rotation may deliberately require login instead of unsafe account adoption. No secret scan can certify arbitrary preexisting git history; source changes and known credential/logging paths were reviewed.

## Remaining gates and exact observation plan

Next gate: INDEPENDENT_REVIEW. A separate reviewer must audit the frozen diff, reproduce the test result, and explicitly accept or reject correctness/security/compliance findings. This takeover's self-review is not that review.

After independent review, complete the real Mac gate on the exact accepted SHA:

1. Verify clean checkout and embedded SHA, build Debug/Release, rerun unit/integration/provider regressions.
2. Run only that candidate for the comparison session; retain the installed app for rollback, avoid two concurrent pollers.
3. Compare unchanged UI against frozen production: ChatGPT, Claude, Grok, ordering, settings, menu-bar and notification presentation; no Cursor/Gemini/Codex/Copilot cards.
4. Observe authorized account-specific values and actual reset labels. Manual refresh and at least two automatic 600-second cycles. Record timestamps, meter/window identity, percentages and reset only; redact account details.
5. With human login/MFA as needed: logout/login, A→B switch with an in-flight request; cookie/WK-ready plus failing usage must remain unhealed. Do not manufacture WAF or bypass CAPTCHA.
6. Real 20% crossing, same-meter duplicate suppression, meter/reset replacement, and actual OS delivery. Synthetic tests are already passed but do not replace this observation.
7. Relaunch, network loss/recovery, authentication expiry, sleep/wake and long idle. No secret logs or stale cross-account display.
8. Run a real 72-hour soak from recorded T0 to T0+72h, logging checks at T0, +1h, +6h, +12h, +24h, +48h and +72h, plus sleep/wake transitions. Record failures and restarts. A restart changes the continuity evidence and must be disclosed.
9. Separately observe genuine weekly/monthly reset boundaries where the provider exposes them; record before, at/after and fresh post-reset readings. Unknown reset stays unknown. No month/week boundary PASS inferred from 72 hours.
10. Human acceptance must explicitly cover usage/reset display for all three, manual/automatic refresh, login/logout, account switch, 20% notification, sleep/wake and visual comparison. No UI redesign during acceptance.

NOT OBTAINED: independent review verdict; real account/delta equivalence; complete visual comparison; live manual/automatic refresh; actual recovery/WAF/login/account-switch evidence; OS notification delivery; sleep/wake; 72h soak; weekly/monthly boundary observation; human acceptance; Developer ID/notarization; provider-specific approval. These are remaining gates, not ordinary compiler bugs.

No merge, push, tag, notarization, release, upload or publish was performed. Working tree must remain clean after the packet commit. READY_FOR_INDEPENDENT_REVIEW does not authorize any later gate or release.
