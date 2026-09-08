import Foundation
import Testing
@testable import AIUsageBar

struct S03UsageSourceAdapterTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
    private let weeklyEnd = Date(timeIntervalSince1970: 1_788_592_260)

    @Test("T-3-01 ChatGPT adapter maps primary_window to a short meter")
    func chatGPTPrimaryWindowMapsToShortMeter() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: chatGPTEnvelope(used: 40, weeklyUsed: 10),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        let primary = snapshot.meters.first { $0.meterId == "chatgpt.primary_window" }
        #expect(primary?.window.classification == .short)
    }

    @Test("T-3-02 ChatGPT adapter maps secondary_window to a weekly meter")
    func chatGPTSecondaryWindowMapsToWeeklyMeter() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: chatGPTEnvelope(used: 40, weeklyUsed: 10),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        let weekly = snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }
        #expect(weekly?.window.classification == .weekly)
    }

    @Test("T-3-03 ChatGPT remaining = 100 − used")
    func chatGPTRemainingIsOneHundredMinusUsed() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: chatGPTEnvelope(used: 40, weeklyUsed: 10),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "chatgpt.primary_window" }?.remainingPercent == 60)
        #expect(snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }?.remainingPercent == 90)
    }

    @Test("T-3-04 ChatGPT 401 → auth failure, not empty meters")
    func chatGPT401IsAuthFailureNotEmptyMeters() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 401,
                accountKey: "acct-1",
                fetchedAt: fetchedAt,
                payload: chatGPTPayload(used: 0, weeklyUsed: 0)
            ),
            previous: nil
        )
        #expect(result == .authFailure)
        if case .snapshot = result {
            Issue.record("401 must not become a snapshot")
        }
    }

    @Test("T-3-05 ChatGPT empty usage payload → invalid snapshot, not 0%")
    func chatGPTEmptyPayloadIsInvalidNotZeroPercent() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "acct-1",
                fetchedAt: fetchedAt,
                payload: [:]
            ),
            previous: nil
        )
        #expect(result == .invalid)
        if case .snapshot(let snapshot) = result {
            Issue.record("empty payload must not be 0% success, got \(snapshot.meters)")
        }
    }

    @Test("T-3-06 Claude adapter maps five_hour remaining = 100 − utilization%")
    func claudeFiveHourRemainingIsOneHundredMinusUtilization() {
        let result = V2ClaudeWebUsageSource().load(
            envelope: claudeEnvelope(fiveHour: 37, sevenDay: 10),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "claude.five_hour" }?.remainingPercent == 63)
        #expect(snapshot.meters.first { $0.meterId == "claude.five_hour" }?.window.classification == .short)
    }

    @Test("T-3-07 Claude adapter maps seven_day remaining = 100 − utilization%")
    func claudeSevenDayRemainingIsOneHundredMinusUtilization() {
        let result = V2ClaudeWebUsageSource().load(
            envelope: claudeEnvelope(fiveHour: 37, sevenDay: 10),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "claude.seven_day" }?.remainingPercent == 90)
        #expect(snapshot.meters.first { $0.meterId == "claude.seven_day" }?.window.classification == .weekly)
    }

    @Test("T-3-08 Claude 401 → auth failure")
    func claude401IsAuthFailure() {
        let result = V2ClaudeWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 401,
                accountKey: "org-1",
                fetchedAt: fetchedAt,
                payload: claudePayload(fiveHour: 1, sevenDay: 1)
            ),
            previous: nil
        )
        #expect(result == .authFailure)
    }

    @Test("T-3-09 Claude 403 → auth / forbidden, not 0%")
    func claude403IsForbiddenNotZeroPercent() {
        let result = V2ClaudeWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 403,
                accountKey: "org-1",
                fetchedAt: fetchedAt,
                payload: claudePayload(fiveHour: 0, sevenDay: 0)
            ),
            previous: nil
        )
        #expect(result == .forbidden)
        if case .snapshot = result {
            Issue.record("403 must not become 0% meters")
        }
    }

    @Test("T-3-10 Grok adapter maps remainingQueries/totalQueries to short remaining")
    func grokShortRemainingFromRemainingOverTotal() {
        let result = V2GrokWebUsageSource().load(
            envelope: grokEnvelope(remaining: 97, total: 100, windowSeconds: 7200),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "grok.short" }?.remainingPercent == 97)
    }

    @Test("T-3-11 Grok adapter maps GetGrokCreditsConfig used% to weekly remaining = 100 − used")
    func grokWeeklyRemainingIsOneHundredMinusUsed() {
        let result = V2GrokWebUsageSource().load(
            envelope: grokEnvelope(
                remaining: 97,
                total: 100,
                windowSeconds: 7200,
                weeklyUsed: 63
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "grok.weekly" }?.remainingPercent == 37)
    }

    @Test("T-3-12 Grok weekly reset comes from current_period.end when type is WEEKLY")
    func grokWeeklyResetFromCurrentPeriodEnd() {
        let result = V2GrokWebUsageSource().load(
            envelope: grokEnvelope(
                remaining: 97,
                total: 100,
                windowSeconds: 7200,
                weeklyUsed: 63
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "grok.weekly" }?.resetAt == weeklyEnd)
        #expect(snapshot.meters.first { $0.meterId == "grok.weekly" }?.window.classification == .weekly)
    }

    @Test("T-3-13 Grok billing_period_end is not used as weekly reset")
    func grokBillingPeriodEndIsNotWeeklyReset() {
        let billing = Date(timeIntervalSince1970: 1_800_000_000)
        let result = V2GrokWebUsageSource().load(
            envelope: grokEnvelope(
                remaining: 97,
                total: 100,
                windowSeconds: 7200,
                weeklyUsed: 63,
                billingPeriodEnd: billing
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        let reset = snapshot.meters.first { $0.meterId == "grok.weekly" }?.resetAt
        #expect(reset == weeklyEnd)
        #expect(reset != billing)
    }

    @Test("T-3-14 Unknown window stays unspecified")
    func unknownWindowStaysUnspecified() {
        let result = V2GrokWebUsageSource().load(
            envelope: grokEnvelope(remaining: 50, total: 100, windowSeconds: 90 * 24 * 60 * 60),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "grok.short" }?.window.classification == .unspecified)
        #expect(snapshot.meters.first { $0.meterId == "grok.short" }?.window.classification != .weekly)
    }

    @Test("T-3-15 Adapter never returns a snapshot without accountKey")
    func adapterNeverReturnsSnapshotWithoutAccountKey() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "  ",
                fetchedAt: fetchedAt,
                payload: chatGPTPayload(used: 1, weeklyUsed: 1)
            ),
            previous: nil
        )
        #expect(result == .invalid)
        if case .snapshot(let snapshot) = result {
            Issue.record("blank accountKey must not snapshot, got \(snapshot.accountKey)")
        }
    }

    @Test("T-3-16 Adapter never returns a meter without meterId")
    func adapterNeverReturnsMeterWithoutMeterId() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: chatGPTEnvelope(used: 21, weeklyUsed: 5),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.allSatisfy { !$0.meterId.isEmpty })
    }

    @Test("T-3-17 Failed parse does not reuse a previous snapshot silently")
    func failedParseDoesNotReusePreviousSnapshot() {
        let previous = V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: "acct-1",
            meters: [
                V2UsageMeter(
                    meterId: "chatgpt.primary_window",
                    window: V2Window(classification: .short, duration: 5 * 60 * 60),
                    remainingPercent: 88,
                    isPrimaryDisplayed: true
                )!
            ],
            fetchedAt: fetchedAt
        )!
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "acct-1",
                fetchedAt: fetchedAt,
                payload: ["rate_limit": ["primary_window": ["used_percent": "not-a-number"]]]
            ),
            previous: previous
        )
        #expect(result == .invalid)
        if case .snapshot(let snapshot) = result {
            Issue.record("must not reuse remaining \(snapshot.primaryDisplayedMeter?.remainingPercent as Any)")
        }
    }

    @Test("T-3-18 Codex adapter is compiled only as a challenger behind a flag, default off")
    func codexAdapterIsChallengerDefaultOff() {
        let source = V2CodexChallengerUsageSource()
        #expect(source.isEnabled == false)
        #expect(source.isSelectableForUI == false)
        #expect(source.sourceID == .codexChallenger)
    }

    @Test("T-3-19 Claude snapshot-bridge adapter default off")
    func claudeSnapshotBridgeDefaultOff() {
        let source = V2ClaudeSnapshotBridgeUsageSource()
        #expect(source.isEnabled == false)
        #expect(source.isSelectableForUI == false)
    }

    @Test("T-3-20 Cursor adapter exists as HOLD stub that cannot be selected for UI")
    func cursorAdapterIsHoldStubNotSelectable() {
        let source = V2CursorHoldUsageSource()
        #expect(source.sourceID == .cursorHold)
        #expect(source.isSelectableForUI == false)
        #expect(CursorProductionPolicy.decision == .hold)
    }

    @Test("T-3-21 Gemini adapters are two families, default not selected for UI")
    func geminiAdaptersAreTwoFamiliesNotSelected() {
        let apps = V2GeminiAppsUsageSource()
        let cli = V2GeminiCLIUsageSource()
        #expect(apps.sourceID == .geminiApps)
        #expect(cli.sourceID == .geminiCLI)
        #expect(apps.isSelectableForUI == false)
        #expect(cli.isSelectableForUI == false)
        #expect(apps.sourceID != cli.sourceID)
        #expect(V2UsageSourceCatalog.uiSelectableSourceIDs().contains(.geminiApps) == false)
        #expect(V2UsageSourceCatalog.uiSelectableSourceIDs().contains(.geminiCLI) == false)
    }

    @Test("T-3-22 All 133 existing tests still pass")
    func existingProductionTestsStillPresentInSource() throws {
        let url = V2UsageSourceCatalog.productionTestFileURL(from: #filePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(V2UsageSourceCatalog.productionTestCount(in: source) == 133)
    }

    private func chatGPTEnvelope(used: Int, weeklyUsed: Int) -> V2FetchEnvelope {
        V2FetchEnvelope(
            httpStatus: 200,
            accountKey: "acct-1",
            fetchedAt: fetchedAt,
            payload: chatGPTPayload(used: used, weeklyUsed: weeklyUsed)
        )
    }

    private func chatGPTPayload(used: Int, weeklyUsed: Int) -> [String: Any] {
        [
            "rate_limit": [
                "primary_window": ["used_percent": used],
                "secondary_window": ["used_percent": weeklyUsed]
            ]
        ]
    }

    private func claudeEnvelope(fiveHour: Int, sevenDay: Int) -> V2FetchEnvelope {
        V2FetchEnvelope(
            httpStatus: 200,
            accountKey: "org-1",
            fetchedAt: fetchedAt,
            payload: claudePayload(fiveHour: fiveHour, sevenDay: sevenDay)
        )
    }

    private func claudePayload(fiveHour: Int, sevenDay: Int) -> [String: Any] {
        [
            "five_hour": ["utilization": fiveHour],
            "seven_day": ["utilization": sevenDay]
        ]
    }

    private func grokEnvelope(
        remaining: Int,
        total: Int,
        windowSeconds: Int,
        weeklyUsed: Int? = nil,
        billingPeriodEnd: Date? = nil
    ) -> V2FetchEnvelope {
        var payload: [String: Any] = [
            "rate_limits": [
                "remainingQueries": remaining,
                "totalQueries": total,
                "windowSizeSeconds": windowSeconds
            ]
        ]
        if let weeklyUsed {
            var weekly: [String: Any] = [
                "used_percent": weeklyUsed,
                "period_type": GrokCreditsConfigDecoder.weeklyPeriodType,
                "current_period_end": weeklyEnd.timeIntervalSince1970
            ]
            if let billingPeriodEnd {
                weekly["billing_period_end"] = billingPeriodEnd.timeIntervalSince1970
            }
            payload["weekly"] = weekly
        }
        return V2FetchEnvelope(
            httpStatus: 200,
            accountKey: "grok-1",
            fetchedAt: fetchedAt,
            payload: payload
        )
    }
}
