import Foundation
import Testing
@testable import AIUsageBar

struct S04IdentityKeyTests {
    @Test("T-4-01 Two ChatGPT accounts do not share a cache slot")
    func twoChatGPTAccountsDoNotShareCacheSlot() {
        var cache = V2MeterCache()
        let a = chatGPTKey(account: "acct-a", meter: "chatgpt.primary_window", window: .short)
        let b = chatGPTKey(account: "acct-b", meter: "chatgpt.primary_window", window: .short)
        cache.store(key: a, meter: meter(id: a.meterId, window: .short, remaining: 40, primary: true))
        cache.store(key: b, meter: meter(id: b.meterId, window: .short, remaining: 10, primary: true))
        #expect(cache.sharesSlot(a, b) == false)
        #expect(cache.meter(for: a)?.remainingPercent == 40)
        #expect(cache.meter(for: b)?.remainingPercent == 10)
    }

    @Test("T-4-02 ChatGPT 5h and weekly meters do not share a cache slot")
    func chatGPTShortAndWeeklyDoNotShareSlot() {
        let short = chatGPTKey(account: "acct-1", meter: "chatgpt.primary_window", window: .short)
        let weekly = chatGPTKey(account: "acct-1", meter: "chatgpt.secondary_window", window: .weekly)
        #expect(V2MeterCache().sharesSlot(short, weekly) == false)
    }

    @Test("T-4-03 Claude 5h and 7d meters do not share a cache slot")
    func claudeShortAndWeeklyDoNotShareSlot() {
        let five = V2IdentityKey(provider: .claude, accountKey: "org-1", meterId: "claude.five_hour", window: .short)!
        let seven = V2IdentityKey(provider: .claude, accountKey: "org-1", meterId: "claude.seven_day", window: .weekly)!
        #expect(V2MeterCache().sharesSlot(five, seven) == false)
    }

    @Test("T-4-04 Grok short and weekly meters do not share a cache slot")
    func grokShortAndWeeklyDoNotShareSlot() {
        let short = V2IdentityKey(provider: .grok, accountKey: "grok-1", meterId: "grok.short", window: .short)!
        let weekly = V2IdentityKey(provider: .grok, accountKey: "grok-1", meterId: "grok.weekly", window: .weekly)!
        #expect(V2MeterCache().sharesSlot(short, weekly) == false)
    }

    @Test("T-4-05 Notification still fires only for the primary displayed meter")
    func notificationFiresOnlyForPrimaryMeter() {
        var latch = V2PrimaryAlertLatch()
        let snapshot = chatGPTSnapshot(account: "acct-1", short: 40, weekly: 10, primaryIsShort: true)
        let weekly = snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }!
        let short = snapshot.meters.first { $0.meterId == "chatgpt.primary_window" }!
        #expect(latch.shouldNotify(snapshot: snapshot, meter: weekly) == false)
        _ = latch.shouldNotify(snapshot: snapshot, meter: short)
        let dropped = meter(id: short.meterId, window: .short, remaining: 15, primary: true)
        #expect(latch.shouldNotify(snapshot: snapshot, meter: dropped))
    }

    @Test("T-4-06 Weekly remaining crossing 20% does not fire a new user-visible alert")
    func weeklyCrossingDoesNotFireVisibleAlert() {
        var latch = V2PrimaryAlertLatch()
        let snapshot = chatGPTSnapshot(account: "acct-1", short: 80, weekly: 40, primaryIsShort: true)
        let weeklyHigh = snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }!
        #expect(latch.shouldNotify(snapshot: snapshot, meter: weeklyHigh) == false)
        let weeklyLow = meter(id: "chatgpt.secondary_window", window: .weekly, remaining: 10, primary: false)
        #expect(latch.shouldNotify(snapshot: snapshot, meter: weeklyLow) == false)
    }

    @Test("T-4-07 Same provider, different accountKey, primary 20% crossing fires separately")
    func differentAccountsFireSeparately() {
        var latch = V2PrimaryAlertLatch()
        let first = chatGPTSnapshot(account: "acct-a", short: 40, weekly: 90, primaryIsShort: true)
        let second = chatGPTSnapshot(account: "acct-b", short: 40, weekly: 90, primaryIsShort: true)
        let firstPrimary = snapshotPrimary(first)
        let secondPrimary = snapshotPrimary(second)
        #expect(latch.shouldNotify(snapshot: first, meter: firstPrimary) == false)
        #expect(latch.shouldNotify(snapshot: second, meter: secondPrimary) == false)
        #expect(
            latch.shouldNotify(
                snapshot: first,
                meter: meter(id: "chatgpt.primary_window", window: .short, remaining: 15, primary: true)
            )
        )
        #expect(
            latch.shouldNotify(
                snapshot: second,
                meter: meter(id: "chatgpt.primary_window", window: .short, remaining: 15, primary: true)
            )
        )
    }

    @Test("T-4-08 Same account, same meter, second 20% event does not repeat")
    func secondTwentyPercentEventDoesNotRepeat() {
        var latch = V2PrimaryAlertLatch()
        let snapshot = chatGPTSnapshot(account: "acct-1", short: 40, weekly: 90, primaryIsShort: true)
        let primary = snapshotPrimary(snapshot)
        #expect(latch.shouldNotify(snapshot: snapshot, meter: primary) == false)
        #expect(
            latch.shouldNotify(
                snapshot: snapshot,
                meter: meter(id: primary.meterId, window: .short, remaining: 15, primary: true)
            )
        )
        #expect(
            latch.shouldNotify(
                snapshot: snapshot,
                meter: meter(id: primary.meterId, window: .short, remaining: 10, primary: true)
            ) == false
        )
    }

    @Test("T-4-09 After recover above 20% then drop again, alert may fire again")
    func recoverThenDropMayFireAgain() {
        var latch = V2PrimaryAlertLatch()
        let snapshot = chatGPTSnapshot(account: "acct-1", short: 40, weekly: 90, primaryIsShort: true)
        let primary = snapshotPrimary(snapshot)
        _ = latch.shouldNotify(snapshot: snapshot, meter: primary)
        _ = latch.shouldNotify(
            snapshot: snapshot,
            meter: meter(id: primary.meterId, window: .short, remaining: 15, primary: true)
        )
        #expect(
            latch.shouldNotify(
                snapshot: snapshot,
                meter: meter(id: primary.meterId, window: .short, remaining: 50, primary: true)
            ) == false
        )
        #expect(
            latch.shouldNotify(
                snapshot: snapshot,
                meter: meter(id: primary.meterId, window: .short, remaining: 20, primary: true)
            )
        )
    }

    @Test("T-4-10 Logout + login as a different account does not inherit the previous alert latch")
    func logoutLoginDifferentAccountDoesNotInheritLatch() {
        var latch = V2PrimaryAlertLatch()
        let old = chatGPTSnapshot(account: "acct-old", short: 40, weekly: 90, primaryIsShort: true)
        let oldPrimary = snapshotPrimary(old)
        _ = latch.shouldNotify(snapshot: old, meter: oldPrimary)
        _ = latch.shouldNotify(
            snapshot: old,
            meter: meter(id: oldPrimary.meterId, window: .short, remaining: 15, primary: true)
        )
        latch.reset(accountKey: "acct-old")
        let next = chatGPTSnapshot(account: "acct-new", short: 40, weekly: 90, primaryIsShort: true)
        let nextPrimary = snapshotPrimary(next)
        #expect(latch.shouldNotify(snapshot: next, meter: nextPrimary) == false)
        #expect(
            latch.shouldNotify(
                snapshot: next,
                meter: meter(id: nextPrimary.meterId, window: .short, remaining: 15, primary: true)
            )
        )
    }

    @Test("T-4-11 Gemini Apps vs CLI identities never share a slot")
    func geminiAppsAndCLINeverShareSlot() {
        let apps = V2IdentityKey(
            provider: .geminiApps,
            accountKey: "same-user",
            meterId: "gemini.apps",
            window: .daily
        )!
        let cli = V2IdentityKey(
            provider: .geminiCLI,
            accountKey: "same-user",
            meterId: "gemini.cli",
            window: .daily
        )!
        #expect(V2MeterCache().sharesSlot(apps, cli) == false)
        #expect(GeminiIdentityHelper.mergeAccountKeys(apps: "same-user", cli: "same-user") == .refusedDistinctFamilies)
    }

    @Test("T-4-12 Codex identity is not merged with ChatGPT unless S01C is PROVEN_EQUIVALENT")
    func codexNotMergedUnlessProvenEquivalent() {
        #expect(V2IdentityHelper.canMergeChatGPTAndCodex(verdict: .notProven) == false)
        #expect(V2IdentityHelper.canMergeChatGPTAndCodex(verdict: .provenDifferent) == false)
        #expect(V2IdentityHelper.canMergeChatGPTAndCodex(verdict: .provenEquivalent))
        let chatGPT = chatGPTKey(account: "acct-1", meter: "chatgpt.primary_window", window: .short)
        let codex = V2IdentityKey(
            provider: .codex,
            accountKey: "acct-1",
            meterId: CodexRateLimitsParser.primaryMeterID,
            window: .short
        )!
        #expect(V2MeterCache().sharesSlot(chatGPT, codex) == false)
    }

    @Test("T-4-13 Missing accountKey cannot latch a notification")
    func missingAccountKeyCannotLatchNotification() {
        #expect(V2IdentityKey(provider: .chatGPT, accountKey: "", meterId: "chatgpt.primary_window", window: .short) == nil)
        var latch = V2PrimaryAlertLatch()
        let snapshot = V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: "acct-1",
            meters: [meter(id: "chatgpt.primary_window", window: .short, remaining: 15, primary: true)],
            fetchedAt: Date()
        )!
        let orphan = meter(id: "chatgpt.primary_window", window: .short, remaining: 15, primary: true)
        #expect(V2NotificationIdentity(provider: .chatGPT, accountKey: "  ", meterId: "x", window: .short) == nil)
        _ = latch.shouldNotify(snapshot: snapshot, meter: orphan)
        #expect(V2IdentityKey(provider: .chatGPT, accountKey: " ", meterId: "chatgpt.primary_window", window: .short) == nil)
    }

    @Test("T-4-14 sessionPercent vs primaryRemainingPercent mapping is explicit per provider")
    func sessionVersusPrimaryMappingIsExplicit() {
        let chatGPT = chatGPTSnapshot(account: "acct-1", short: 60, weekly: 12, primaryIsShort: true)
        let chatPercents = V2DisplayedPercentMapping.percents(from: chatGPT)
        #expect(chatPercents.sessionPercent == 60)
        #expect(chatPercents.primaryRemainingPercent == 60)

        let grok = V2UsageSnapshot(
            provider: .grok,
            accountKey: "grok-1",
            meters: [
                meter(id: "grok.short", window: .short, remaining: 99, primary: false),
                meter(id: "grok.weekly", window: .weekly, remaining: 18, primary: true)
            ],
            fetchedAt: Date()
        )!
        let grokPercents = V2DisplayedPercentMapping.percents(from: grok)
        #expect(grokPercents.sessionPercent == 99)
        #expect(grokPercents.weeklyPercent == 18)
        #expect(grokPercents.weeklyAvailable)
        #expect(grokPercents.primaryRemainingPercent == 18)
        #expect(grokPercents.primaryRemainingPercent != grokPercents.sessionPercent)
    }

    @Test("T-4-15 Identity helper is pure (no Keychain / WebKit)")
    func identityHelperIsPure() {
        #expect(V2IdentityHelper.filesystemAccess == .forbidden)
        let key = chatGPTKey(account: "acct-1", meter: "chatgpt.primary_window", window: .short)
        #expect(V2IdentityHelper.cacheSlot(for: key).contains("acct-1"))
    }

    @Test("T-4-16 Existing ChatGPT 20% notification test still passes")
    func existingChatGPTTwentyPercentStillPasses() {
        var state = UsageNotificationState()
        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 19,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("T-4-17 Existing Claude 20% notification test still passes")
    func existingClaudeTwentyPercentStillPasses() {
        var state = UsageNotificationState()
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("T-4-18 Existing Grok 20% notification test still passes")
    func existingGrokTwentyPercentStillPasses() {
        var state = UsageNotificationState()
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 10,
            isLoaded: true,
            hasError: false
        ) == false)
    }

    private func chatGPTKey(account: String, meter: String, window: V2WindowClass) -> V2IdentityKey {
        V2IdentityKey(provider: .chatGPT, accountKey: account, meterId: meter, window: window)!
    }

    private func meter(
        id: String,
        window: V2WindowClass,
        remaining: Int,
        primary: Bool
    ) -> V2UsageMeter {
        V2UsageMeter(
            meterId: id,
            window: V2Window(classification: window, duration: nil),
            remainingPercent: remaining,
            isPrimaryDisplayed: primary
        )!
    }

    private func chatGPTSnapshot(
        account: String,
        short: Int,
        weekly: Int,
        primaryIsShort: Bool
    ) -> V2UsageSnapshot {
        V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: account,
            meters: [
                meter(id: "chatgpt.primary_window", window: .short, remaining: short, primary: primaryIsShort),
                meter(id: "chatgpt.secondary_window", window: .weekly, remaining: weekly, primary: !primaryIsShort)
            ],
            fetchedAt: Date()
        )!
    }

    private func snapshotPrimary(_ snapshot: V2UsageSnapshot) -> V2UsageMeter {
        snapshot.primaryDisplayedMeter!
    }
}
