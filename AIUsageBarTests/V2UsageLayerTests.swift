import Foundation
import Testing
@testable import AIUsageBar

struct V2UsageLayerTests {
    @Test("Freshness TTL distinguishes FRESH STALE_BUT_VALID EXPIRED INVALID")
    func usageValidityStates() {
        let asOf = Date(timeIntervalSince1970: 1_000)
        #expect(
            UsageValidityPolicy.validity(
                asOf: asOf,
                now: asOf.addingTimeInterval(30),
                expiresAt: nil,
                identityMatches: true
            ) == .fresh
        )
        #expect(
            UsageValidityPolicy.validity(
                asOf: asOf,
                now: asOf.addingTimeInterval(200),
                expiresAt: nil,
                identityMatches: true
            ) == .staleButValid
        )
        #expect(
            UsageValidityPolicy.validity(
                asOf: asOf,
                now: asOf.addingTimeInterval(7 * 60 * 60),
                expiresAt: nil,
                identityMatches: true
            ) == .staleButValid
        )
        #expect(
            UsageValidityPolicy.validity(
                asOf: asOf,
                now: asOf.addingTimeInterval(10),
                expiresAt: asOf.addingTimeInterval(5),
                identityMatches: true
            ) == .expired
        )
        #expect(
            UsageValidityPolicy.validity(
                asOf: asOf,
                now: asOf.addingTimeInterval(10),
                expiresAt: nil,
                identityMatches: false
            ) == .invalid
        )
    }

    @Test("Missing meter is omitted and snapshot can remain healthy")
    func missingMeterIsOmitted() {
        let snapshot = UsageSnapshot(
            provider: .chatGPT,
            accountKey: "a",
            accountKeyUnavailable: false,
            sourceType: .appWebKit,
            asOf: Date(),
            meters: [
                UsageMeter(
                    meterId: "chatgpt.primary_window",
                    window: .rolling5Hour,
                    remainingPercent: 40,
                    usedPercent: 60,
                    resetAt: nil,
                    isDisplayedPrimary: true
                )
            ],
            health: .available
        )
        #expect(snapshot.meters.contains(where: { $0.meterId == "chatgpt.secondary_window" }) == false)
        #expect(snapshot.health == .available)
    }

    @Test("Unknown meter window stays unknown without fabricating resetAt")
    func unknownMeterDoesNotFabricateReset() {
        let meter = UsageMeter(
            meterId: "experimental",
            window: .unknown,
            remainingPercent: 10,
            usedPercent: 90,
            resetAt: nil,
            isDisplayedPrimary: false
        )
        #expect(meter.resetAt == nil)
        #expect(meter.window == .unknown)
    }

    @Test("Account switch invalidates cache and notification history")
    func accountSwitchInvalidatesCacheAndNotifications() {
        var cache = UsageAccountCache()
        var notes = UsageNotificationIdentityState()
        let usage = ChatGPTUsage(
            sessionRemainingPercent: 40,
            resetText: "r",
            weeklyRemainingPercent: 80,
            weeklyResetText: "w"
        )
        let old = V1UsageAdapters.chatGPTSnapshot(usage: usage, token: "token-A")
        let new = V1UsageAdapters.chatGPTSnapshot(usage: usage, token: "token-B")
        cache.store(old)
        let oldID = UsageCacheIdentity(
            provider: .chatGPT,
            accountKey: old.accountKey,
            meterId: "chatgpt.primary_window",
            window: .rolling5Hour
        )
        let decision1 = (notes.shouldNotify(
            identity: oldID,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(decision1)
        let decision2 = (notes.shouldNotify(
            identity: oldID,
            remainingPercent: 18,
            isLoaded: true,
            hasError: false
        ))
        #expect(decision2)
        cache.invalidateAccount(provider: .chatGPT, accountKey: old.accountKey!)
        notes.resetAccount(provider: .chatGPT, accountKey: old.accountKey!)
        #expect(cache.snapshot(for: oldID) == nil)
        let newID = UsageCacheIdentity(
            provider: .chatGPT,
            accountKey: new.accountKey,
            meterId: "chatgpt.primary_window",
            window: .rolling5Hour
        )
        let decision3 = (notes.shouldNotify(
            identity: newID,
            remainingPercent: 18,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(decision3)
    }

    @Test("accountKey unavailable does not reuse another account cache")
    func unavailableAccountKeyDoesNotReuseCache() {
        var cache = UsageAccountCache()
        let snapshot = UsageSnapshot(
            provider: .claude,
            accountKey: nil,
            accountKeyUnavailable: true,
            sourceType: .appWebKit,
            asOf: Date(),
            meters: [],
            health: .available
        )
        cache.store(snapshot)
        let identity = UsageCacheIdentity(
            provider: .claude,
            accountKey: nil,
            meterId: "claude.five_hour",
            window: .rolling5Hour
        )
        #expect(cache.snapshot(for: identity) == nil)
    }

    @Test("Notification uses displayed primary identity only once per window")
    func notificationPrimaryThresholdOnce() {
        var notes = UsageNotificationIdentityState()
        let id = UsageCacheIdentity(
            provider: .grok,
            accountKey: "acct",
            meterId: "grok.short",
            window: .rollingCustom
        )
        let decision4 = (notes.shouldNotify(identity: id, remainingPercent: 40, isLoaded: true, hasError: false) == false)
        #expect(decision4)
        let decision5 = (notes.shouldNotify(identity: id, remainingPercent: 19, isLoaded: true, hasError: false))
        #expect(decision5)
        let decision6 = (notes.shouldNotify(identity: id, remainingPercent: 10, isLoaded: true, hasError: false) == false)
        #expect(decision6)
        let decision7 = (notes.shouldNotify(identity: id, remainingPercent: 19, isLoaded: false, hasError: false) == false)
        #expect(decision7)
        let decision8 = (notes.shouldNotify(identity: id, remainingPercent: 19, isLoaded: true, hasError: true) == false)
        #expect(decision8)
    }

    @Test("Notification reset jitter is not a new window, but a post-reset future is")
    func notificationResetJitterAndBoundaryPolicy() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(
            UsageNotificationWindowPolicy.isGenuineNewWindow(
                previousResetAt: now.addingTimeInterval(60),
                currentResetAt: now.addingTimeInterval(120),
                now: now
            ) == false
        )
        #expect(
            UsageNotificationWindowPolicy.isGenuineNewWindow(
                previousResetAt: now.addingTimeInterval(-1),
                currentResetAt: now.addingTimeInterval(60),
                now: now
            )
        )
        #expect(
            UsageNotificationWindowPolicy.isGenuineNewWindow(
                previousResetAt: nil,
                currentResetAt: now.addingTimeInterval(60),
                now: now
            ) == false
        )
    }

    @Test("Recovery allows one active restore and latches REQUIRES_USER_ACTION")
    func recoveryDedupeAndLatch() {
        var coordinator = RecoveryCoordinator()
        let scope = RecoveryScope(provider: .chatGPT, accountKey: "a")
        let decision9 = (coordinator.beginRecovery(scope: scope))
        #expect(decision9)
        let decision10 = (coordinator.beginRecovery(scope: scope) == false)
        #expect(decision10)
        #expect(coordinator.state == .recovering)
        let captured = coordinator.generation
        coordinator.invalidate()
        #expect(coordinator.shouldCommit(captured: captured) == false)

        coordinator = RecoveryCoordinator()
        let now = Date()
        _ = coordinator.beginRecovery(scope: scope, now: now)
        coordinator.markFailure(now: now)
        #expect(coordinator.state == .backoff)
        let decision11 = (coordinator.beginRecovery(scope: scope, now: now) == false)
        #expect(decision11)
        coordinator.markFailure(now: now.addingTimeInterval(1))
        coordinator.markFailure(now: now.addingTimeInterval(2))
        #expect(coordinator.state == .requiresUserAction)
        let decision12 = (coordinator.beginRecovery(scope: scope, now: now.addingTimeInterval(30)) == false)
        #expect(decision12)
    }

    @Test("Recovery success requires fetch parse and identity not WebKit READY")
    func recoverySuccessIsFreshFetchNotCookieLatch() {
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: true,
                parsedValid: true,
                expectedAccountKey: "acct",
                snapshotAccountKey: "acct",
                accountKeyUnavailable: false,
                cookiePresent: false,
                webKitReady: false
            )
        )
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: false,
                parsedValid: true,
                expectedAccountKey: "acct",
                snapshotAccountKey: "acct",
                accountKeyUnavailable: false,
                cookiePresent: true,
                webKitReady: true
            ) == false
        )
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: true,
                parsedValid: true,
                expectedAccountKey: "acct",
                snapshotAccountKey: "other",
                accountKeyUnavailable: false
            ) == false
        )
    }

    @Test("Identity-unavailable recovery can succeed without fingerprinting empty credentials")
    func identityUnavailableRecoveryCanSucceed() {
        #expect(UsageIdentity.accountKey(from: "") == nil)
        #expect(UsageIdentity.accountKey(from: "   ") == nil)
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: true,
                parsedValid: true,
                expectedAccountKey: nil,
                snapshotAccountKey: nil,
                accountKeyUnavailable: true,
                cookiePresent: false,
                webKitReady: false
            )
        )
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: true,
                parsedValid: true,
                expectedAccountKey: nil,
                snapshotAccountKey: nil,
                accountKeyUnavailable: false
            ) == false
        )
        #expect(
            RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: false,
                parsedValid: false,
                expectedAccountKey: nil,
                snapshotAccountKey: nil,
                accountKeyUnavailable: true,
                cookiePresent: true,
                webKitReady: true
            ) == false
        )
    }

    @Test("resetAt crossing expires only the primary meter")
    func resetAtCrossingExpiresOnlyPrimaryMeter() {
        let resetAt = Date(timeIntervalSince1970: 5_000)
        let snapshot = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 40,
                resetText: "soon",
                weeklyRemainingPercent: nil,
                weeklyResetText: nil,
                sessionResetAt: resetAt
            ),
            token: "tok",
            asOf: Date(timeIntervalSince1970: 4_900)
        )
        #expect(snapshot.displayedPrimaryMeter?.resetAt == resetAt)
        #expect(
            snapshot.validity(
                now: Date(timeIntervalSince1970: 4_999),
                expectedAccountKey: snapshot.accountKey
            ) == .fresh
        )
        #expect(
            snapshot.validity(
                now: resetAt,
                expectedAccountKey: snapshot.accountKey
            ) == .expired
        )

        let secondaryExpired = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 40,
                resetText: "soon",
                weeklyRemainingPercent: 80,
                weeklyResetText: "old",
                sessionResetAt: resetAt.addingTimeInterval(600),
                weeklyResetAt: resetAt
            ),
            token: "tok",
            asOf: Date(timeIntervalSince1970: 4_900)
        )
        #expect(
            secondaryExpired.validity(
                now: resetAt,
                expectedAccountKey: secondaryExpired.accountKey
            ) == .fresh
        )
        #expect(
            secondaryExpired.validity(
                now: resetAt,
                expectedAccountKey: secondaryExpired.accountKey,
                meterId: "chatgpt.secondary_window",
                window: .weekly
            ) == .expired
        )

        let missing = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 40,
                resetText: "unknown",
                weeklyRemainingPercent: nil,
                weeklyResetText: nil,
                sessionResetAt: nil
            ),
            token: "tok",
            asOf: Date(timeIntervalSince1970: 4_900)
        )
        #expect(missing.displayedPrimaryMeter?.resetAt == nil)
        #expect(
            missing.validity(
                now: Date(timeIntervalSince1970: 4_950),
                expectedAccountKey: missing.accountKey
            ) == .fresh
        )
    }

    @Test("Recovery coordinator enforces one restore and one retry per cycle")
    func recoveryCoordinatorEnforcesRestoreAndRetryBounds() {
        var coordinator = RecoveryCoordinator()
        let scope = RecoveryScope(provider: .grok, accountKey: "a")
        let decision13 = (coordinator.beginRecovery(scope: scope))
        #expect(decision13)
        let decision14 = (coordinator.consumeRestoreAttempt())
        #expect(decision14)
        let decision15 = (coordinator.consumeRestoreAttempt() == false)
        #expect(decision15)
        let decision16 = (coordinator.consumeRetryFetch())
        #expect(decision16)
        let decision17 = (coordinator.consumeRetryFetch() == false)
        #expect(decision17)
        coordinator.markRequiresUserAction()
        let decision18 = (coordinator.beginRecovery(scope: scope) == false)
        #expect(decision18)
        let decision19 = (coordinator.consumeRestoreAttempt() == false)
        #expect(decision19)
    }

    @Test("Stale in-flight completion cannot commit after logout generation bump")
    func staleCompletionRejectedAfterLogout() {
        var coordinator = RecoveryCoordinator()
        let captured = coordinator.generation
        coordinator.invalidate()
        #expect(coordinator.shouldCommit(captured: captured) == false)
    }

    @Test("ChatGPT Claude Grok adapters preserve primary quota mapping")
    func v1AdaptersPreservePrimaryMeters() {
        let chat = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 55,
                resetText: "5h",
                weeklyRemainingPercent: 80,
                weeklyResetText: "w"
            ),
            token: "tok"
        )
        #expect(chat.meters.first { $0.isDisplayedPrimary }?.remainingPercent == 55)
        #expect(chat.meters.contains(where: { $0.window == .weekly && $0.remainingPercent == 80 }))
        #expect(chat.displayedPrimaryMeter?.resetAt == nil)

        let reset = Date(timeIntervalSince1970: 1_700_000_000)
        let chatReset = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 55,
                resetText: "5h",
                weeklyRemainingPercent: 80,
                weeklyResetText: "w",
                sessionResetAt: reset,
                weeklyResetAt: reset.addingTimeInterval(3600)
            ),
            token: "tok"
        )
        #expect(chatReset.meters.first { $0.meterId == "chatgpt.primary_window" }?.resetAt == reset)
        #expect(
            chatReset.meters.first { $0.meterId == "chatgpt.secondary_window" }?.resetAt
                == reset.addingTimeInterval(3600)
        )

        let claude = V1UsageAdapters.claudeSnapshot(
            usage: ClaudeUsage(
                sessionRemainingPercent: 10,
                weeklyRemainingPercent: 20,
                resetText: "a",
                weeklyResetText: "b"
            ),
            sessionKey: "sk",
            organizationID: "org-1"
        )
        #expect(claude.meters.first { $0.meterId == "claude.five_hour" }?.window == .rolling5Hour)

        let claudeReset = Date(timeIntervalSince1970: 1_800_000_000)
        let claudeWithReset = V1UsageAdapters.claudeSnapshot(
            usage: ClaudeUsage(
                sessionRemainingPercent: 10,
                weeklyRemainingPercent: 20,
                resetText: "a",
                weeklyResetText: "b",
                sessionResetAt: claudeReset,
                weeklyResetAt: claudeReset.addingTimeInterval(86400)
            ),
            sessionKey: "sk",
            organizationID: "org-1"
        )
        #expect(claudeWithReset.meters.first { $0.meterId == "claude.five_hour" }?.resetAt == claudeReset)
        #expect(
            claudeWithReset.meters.first { $0.meterId == "claude.seven_day" }?.resetAt
                == claudeReset.addingTimeInterval(86400)
        )

        let grokWeekly = V1UsageAdapters.grokSnapshot(
            usage: GrokUsage(
                sessionRemainingPercent: 40,
                resetText: "s",
                sessionWindowSeconds: 7200,
                weeklyRemainingPercent: 12,
                weeklyResetText: "w",
                weeklyRelativeResetText: "r"
            ),
            sso: "sso"
        )
        #expect(grokWeekly.meters.first { $0.isDisplayedPrimary }?.meterId == "grok.weekly")

        let grokSessionReset = Date(timeIntervalSince1970: 1_760_000_000)
        let grokWeeklyReset = Date(timeIntervalSince1970: 1_760_086_400)
        let grokWithReset = V1UsageAdapters.grokSnapshot(
            usage: GrokUsage(
                sessionRemainingPercent: 40,
                resetText: "s",
                sessionWindowSeconds: 7200,
                weeklyRemainingPercent: 12,
                weeklyResetText: "w",
                weeklyRelativeResetText: "r",
                sessionResetAt: grokSessionReset,
                weeklyResetAt: grokWeeklyReset
            ),
            sso: "sso"
        )
        #expect(grokWithReset.meters.first { $0.meterId == "grok.short" }?.resetAt == grokSessionReset)
        #expect(grokWithReset.meters.first { $0.meterId == "grok.weekly" }?.resetAt == grokWeeklyReset)

        let grokFree = V1UsageAdapters.grokSnapshot(
            usage: GrokUsage(
                sessionRemainingPercent: 40,
                resetText: "s",
                sessionWindowSeconds: 7200,
                weeklyRemainingPercent: nil,
                weeklyResetText: nil,
                weeklyRelativeResetText: nil
            ),
            sso: "sso"
        )
        #expect(grokFree.meters.first { $0.isDisplayedPrimary }?.meterId == "grok.short")
        #expect(grokFree.meters.count == 1)
    }

    @Test("Same-meter equivalence helper stays strict")
    func sameMeterEquivalence() {
        #expect(UsageEquivalence.sameMeter(
            remainingA: 40,
            remainingB: 41,
            resetA: Date(timeIntervalSince1970: 100),
            resetB: Date(timeIntervalSince1970: 200)
        ))
        #expect(UsageEquivalence.sameMeter(
            remainingA: 40,
            remainingB: 50,
            resetA: Date(timeIntervalSince1970: 100),
            resetB: Date(timeIntervalSince1970: 100)
        ) == false)
    }

    @Test("Fingerprints redact raw tokens from identity keys")
    func fingerprintDoesNotContainRawToken() {
        let token = "sk-live-secret-value"
        let key = UsageIdentity.fingerprint(token)
        #expect(key.contains(token) == false)
        #expect(UsageIdentity.fingerprint(token) == key)
        #expect(UsageIdentity.fingerprint("other") != key)
    }
}

enum UsageEquivalence {
    static func sameMeter(
        remainingA: Int,
        remainingB: Int,
        resetA: Date,
        resetB: Date
    ) -> Bool {
        abs(remainingA - remainingB) <= 2 &&
            abs(resetA.timeIntervalSince(resetB)) <= 5 * 60
    }
}
