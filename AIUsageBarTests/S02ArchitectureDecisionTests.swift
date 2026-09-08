import Foundation
import Testing
@testable import AIUsageBar

struct S02ArchitectureDecisionTests {
    @Test("T-2-01 UsageSnapshot requires provider + accountKey + meters[]")
    func snapshotRequiresProviderAccountKeyAndMeters() {
        let meter = tryMeter()
        let snapshot = V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: "acct-1",
            meters: [meter],
            fetchedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
        #expect(snapshot != nil)
        #expect(snapshot?.provider == .chatGPT)
        #expect(snapshot?.accountKey == "acct-1")
        #expect(snapshot?.meters.count == 1)

        #expect(
            V2UsageSnapshot(
                provider: .chatGPT,
                accountKey: "  ",
                meters: [meter],
                fetchedAt: Date()
            ) == nil
        )
    }

    @Test("T-2-02 Each meter requires meterId + window")
    func meterRequiresMeterIdAndWindow() {
        let window = V2Window(classification: .short, duration: 5 * 60 * 60)
        #expect(
            V2UsageMeter(meterId: "chatgpt.primary_window", window: window) != nil
        )
        #expect(
            V2UsageMeter(meterId: "", window: window) == nil
        )
        let meter = V2UsageMeter(
            meterId: "chatgpt.primary_window",
            window: V2Window(classification: .short, duration: 5 * 60 * 60)
        )
        #expect(meter?.meterId == "chatgpt.primary_window")
        #expect(meter?.window.classification == .short)
    }

    @Test("T-2-03 Window classifier: ≤6h short; ~24h daily; ~7d weekly; ~30d monthly; unknown unspecified")
    func windowClassifierUsesNamedDurationBands() {
        #expect(V2WindowClassifier.classify(duration: 5 * 60 * 60) == .short)
        #expect(V2WindowClassifier.classify(duration: V2ArchitectureConstants.shortWindowMaxDuration) == .short)
        #expect(V2WindowClassifier.classify(duration: V2ArchitectureConstants.dailyWindowDuration) == .daily)
        #expect(V2WindowClassifier.classify(duration: V2ArchitectureConstants.weeklyWindowDuration) == .weekly)
        #expect(V2WindowClassifier.classify(duration: V2ArchitectureConstants.monthlyWindowDuration) == .monthly)
        #expect(V2WindowClassifier.classify(duration: nil) == .unspecified)
        #expect(V2WindowClassifier.classify(duration: 90 * 24 * 60 * 60) == .unspecified)
        #expect(V2WindowClassifier.classify(duration: 90 * 24 * 60 * 60) != .weekly)
    }

    @Test("T-2-04 Primary displayed meter is an explicit flag, not first array item")
    func primaryMeterIsExplicitFlag() {
        let short = V2UsageMeter(
            meterId: "chatgpt.primary_window",
            window: V2Window(classification: .short, duration: 5 * 60 * 60),
            remainingPercent: 40,
            isPrimaryDisplayed: false
        )!
        let weekly = V2UsageMeter(
            meterId: "chatgpt.secondary_window",
            window: V2Window(classification: .weekly, duration: 7 * 24 * 60 * 60),
            remainingPercent: 12,
            isPrimaryDisplayed: true
        )!
        let snapshot = V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: "acct-1",
            meters: [short, weekly],
            fetchedAt: Date()
        )!
        #expect(snapshot.meters.first?.meterId == "chatgpt.primary_window")
        #expect(snapshot.primaryDisplayedMeter?.meterId == "chatgpt.secondary_window")
        #expect(snapshot.primaryDisplayedMeter?.isPrimaryDisplayed == true)
    }

    @Test("T-2-05 FRESH if fetchedAt within freshness window")
    func freshIfWithinFreshnessWindow() {
        let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let now = fetchedAt.addingTimeInterval(V2ArchitectureConstants.freshnessWindow - 1)
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: fetchedAt,
                now: now,
                lastParseSucceeded: true,
                identityMatched: true
            ) == .fresh
        )
    }

    @Test("T-2-06 STALE_BUT_VALID if stale but not expired and last parse succeeded")
    func staleButValidWhenStaleAndParseSucceeded() {
        let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let now = fetchedAt.addingTimeInterval(V2ArchitectureConstants.freshnessWindow + 1)
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: fetchedAt,
                now: now,
                lastParseSucceeded: true,
                identityMatched: true
            ) == .staleButValid
        )
    }

    @Test("T-2-07 EXPIRED if past validity TTL")
    func expiredIfPastValidityTTL() {
        let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let now = fetchedAt.addingTimeInterval(V2ArchitectureConstants.validityTTL + 1)
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: fetchedAt,
                now: now,
                lastParseSucceeded: true,
                identityMatched: true
            ) == .expired
        )
    }

    @Test("T-2-08 INVALID if parse failed or identity mismatch")
    func invalidIfParseFailedOrIdentityMismatch() {
        let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: fetchedAt,
                now: fetchedAt,
                lastParseSucceeded: false,
                identityMatched: true
            ) == .invalid
        )
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: fetchedAt,
                now: fetchedAt,
                lastParseSucceeded: true,
                identityMatched: false
            ) == .invalid
        )
    }

    @Test("T-2-09 Cookie-exists alone cannot produce FRESH")
    func cookieExistsAloneCannotProduceFresh() {
        #expect(
            V2SnapshotValidityPolicy.validity(fromProbe: .cookieExists, now: Date()) != .fresh
        )
        #expect(
            V2SnapshotValidityPolicy.validity(fromProbe: .cookieExists, now: Date()) == .invalid
        )
    }

    @Test("T-2-10 Navigation-finished alone cannot produce FRESH")
    func navigationFinishedAloneCannotProduceFresh() {
        #expect(
            V2SnapshotValidityPolicy.validity(fromProbe: .navigationFinished, now: Date()) != .fresh
        )
        #expect(
            V2SnapshotValidityPolicy.validity(fromProbe: .webKitReady, now: Date()) != .fresh
        )
    }

    @Test("T-2-11 Recovery success requires fetch + 2xx + valid parse + matching identity")
    func recoverySuccessRequiresFetchStatusParseAndIdentity() {
        let success = V2RecoverySuccessInput(
            didFetch: true,
            httpStatus: 200,
            parseSucceeded: true,
            identityMatched: true
        )
        #expect(V2RecoverySuccessPolicy.isSuccess(success))
        #expect(
            V2RecoverySuccessPolicy.isSuccess(
                V2RecoverySuccessInput(
                    didFetch: false,
                    httpStatus: 200,
                    parseSucceeded: true,
                    identityMatched: true
                )
            ) == false
        )
        #expect(
            V2RecoverySuccessPolicy.isSuccess(
                V2RecoverySuccessInput(
                    didFetch: true,
                    httpStatus: 401,
                    parseSucceeded: true,
                    identityMatched: true
                )
            ) == false
        )
        #expect(
            V2RecoverySuccessPolicy.isSuccess(
                V2RecoverySuccessInput(
                    didFetch: true,
                    httpStatus: 200,
                    parseSucceeded: false,
                    identityMatched: true
                )
            ) == false
        )
        #expect(
            V2RecoverySuccessPolicy.isSuccess(
                V2RecoverySuccessInput(
                    didFetch: true,
                    httpStatus: 200,
                    parseSucceeded: true,
                    identityMatched: false
                )
            ) == false
        )
    }

    @Test("T-2-12 Notification identity key = provider + accountKey + meterId + window")
    func notificationIdentityKeyIsComposite() {
        let meter = tryMeter()
        let snapshot = V2UsageSnapshot(
            provider: .claude,
            accountKey: "org-1",
            meters: [meter],
            fetchedAt: Date()
        )!
        let identity = V2NotificationIdentity.from(snapshot: snapshot, meter: meter)
        #expect(identity?.provider == .claude)
        #expect(identity?.accountKey == "org-1")
        #expect(identity?.meterId == meter.meterId)
        #expect(identity?.window == .short)
        #expect(V2NotificationIdentity(provider: .claude, accountKey: "", meterId: "x", window: .short) == nil)
    }

    @Test("T-2-13 Non-primary meters do not create user-visible 20% alerts")
    func nonPrimaryMetersDoNotCreateVisibleAlerts() {
        let secondary = V2UsageMeter(
            meterId: "chatgpt.secondary_window",
            window: V2Window(classification: .weekly, duration: V2ArchitectureConstants.weeklyWindowDuration),
            remainingPercent: 10,
            isPrimaryDisplayed: false
        )!
        let primary = V2UsageMeter(
            meterId: "chatgpt.primary_window",
            window: V2Window(classification: .short, duration: 5 * 60 * 60),
            remainingPercent: 10,
            isPrimaryDisplayed: true
        )!
        #expect(
            V2NotificationPolicy.shouldEmitUserVisibleAlert(meter: secondary, remainingPercent: 10) == false
        )
        #expect(
            V2NotificationPolicy.shouldEmitUserVisibleAlert(meter: primary, remainingPercent: 10)
        )
        #expect(V2ArchitectureConstants.notificationThresholdPercent == 20)
    }

    @Test("T-2-14 Allowed UI strings are only 已登入 / 需重新登入 / 資料暫時無法取得")
    func allowedUIStringsAreFrozen() {
        #expect(V2UICopy.signedIn == "已登入")
        #expect(V2UICopy.needsRelogin == "需重新登入")
        #expect(V2UICopy.temporarilyUnavailable == "資料暫時無法取得")
        #expect(V2UICopy.allowedUserVisibleStrings.count == 3)
        #expect(V2UICopyPolicy.isAllowed("已登入"))
        #expect(V2UICopyPolicy.isAllowed("需重新登入"))
        #expect(V2UICopyPolicy.isAllowed("資料暫時無法取得"))
        #expect(V2UICopyPolicy.isAllowed("READY") == false)
        #expect(V2UICopyPolicy.isAllowed("Basic Mode") == false)
    }

    @Test("T-2-15 Cooldown / backoff constants are readable named values, not magic numbers")
    func cooldownBackoffConstantsAreNamed() {
        #expect(V2ArchitectureConstants.backoffCooldown == 30)
        #expect(V2ArchitectureConstants.recoverFailureLimit == 3)
        #expect(V2ArchitectureConstants.freshnessWindow == 15 * 60)
        #expect(V2ArchitectureConstants.validityTTL == 6 * 60 * 60)
        #expect(V2ArchitectureConstants.backoffCooldown == V2ArchitectureConstants.backoffCooldown)
    }

    private func tryMeter() -> V2UsageMeter {
        V2UsageMeter(
            meterId: "chatgpt.primary_window",
            window: V2Window(classification: .short, duration: 5 * 60 * 60),
            remainingPercent: 60,
            isPrimaryDisplayed: true
        )!
    }
}
