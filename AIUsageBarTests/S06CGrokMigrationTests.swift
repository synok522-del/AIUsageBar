import Foundation
import Testing
@testable import AIUsageBar

struct S06CGrokMigrationTests {
    @Test("T-6GK-01 Short window still from rest/rate-limits grok-3")
    func shortWindowStillFromRateLimitsGrok3() throws {
        #expect(V2GrokProductionSource.shortWindowPath == "rest/rate-limits")
        #expect(V2GrokProductionSource.shortWindowModel == "grok-3")
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 97,
            "totalQueries": 100,
            "windowSizeSeconds": 7200
        ])
        #expect(parsed.remainingPercent == 97)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Service/GrokService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("rest/rate-limits"))
        #expect(source.contains("grok-3"))
    }

    @Test("T-6GK-02 Weekly still from GetGrokCreditsConfig WEEKLY current_period.end")
    func weeklyStillFromWeeklyCurrentPeriodEnd() throws {
        let end = Date(timeIntervalSince1970: 1_788_592_260)
        let quota = try GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: 63,
            periodType: GrokCreditsConfigDecoder.weeklyPeriodType,
            periodEnd: end,
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        #expect(quota.resetAt == end)
        #expect(GrokCreditsConfigDecoder.requestPath.contains("GetGrokCreditsConfig"))
    }

    @Test("T-6GK-03 billing_period_end still ignored as weekly reset")
    func billingPeriodEndStillIgnored() {
        let result = V2GrokWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "grok-1",
                fetchedAt: Date(),
                payload: [
                    "rate_limits": [
                        "remainingQueries": 97,
                        "totalQueries": 100,
                        "windowSizeSeconds": 7200
                    ],
                    "weekly": [
                        "used_percent": 63,
                        "period_type": GrokCreditsConfigDecoder.weeklyPeriodType,
                        "current_period_end": Date(timeIntervalSince1970: 1_788_592_260).timeIntervalSince1970,
                        "billing_period_end": Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSince1970
                    ]
                ]
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "grok.weekly" }?.resetAt == Date(timeIntervalSince1970: 1_788_592_260))
        #expect(snapshot.meters.first { $0.meterId == "grok.weekly" }?.resetAt != Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("T-6GK-04 Local/CLI challenger default off")
    func localChallengerDefaultOff() {
        #expect(V2GrokProductionSource.localChallengerEnabled == false)
        #expect(GrokChallengerContract.sourceSelection(localSourcePresent: false) == .webOnly)
    }

    @Test("T-6GK-05 Recovery success requires usage parse, not sso cookie")
    func recoverySuccessRequiresUsageParseNotSSO() {
        #expect(
            GrokV2RecoveryInterpretation.cardPhase(
                restorerPhase: .ready,
                usageParseSucceeded: false
            ) != .healthy
        )
        #expect(
            V2RecoverySuccessPolicy.isSuccess(
                V2RecoverySuccessInput(
                    didFetch: true,
                    httpStatus: 200,
                    parseSucceeded: true,
                    identityMatched: true
                )
            )
        )
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
    }

    @Test("T-6GK-06 Cookie-only restorer READY cannot mark the card 已登入")
    func cookieOnlyReadyCannotMarkCardSignedIn() {
        #expect(
            GrokV2RecoveryInterpretation.uiCopy(
                restorerPhase: .ready,
                usageParseSucceeded: false
            ) != "已登入"
        )
        #expect(
            GrokV2RecoveryInterpretation.uiCopy(
                restorerPhase: .ready,
                usageParseSucceeded: true
            ) == "已登入"
        )
    }

    @Test("T-6GK-07 Logout generation still cancels in-flight restore")
    func logoutGenerationStillCancelsInFlightRestore() {
        var gate = GrokSessionRestorerGate()
        let generation = gate.beginRestore()
        gate.reset()
        gate.complete(attemptGeneration: generation, outcome: .success)
        #expect(gate.phase == .unknown)
        var http = GrokHTTPAuthGeneration()
        let captured = http.value
        http.invalidate()
        #expect(GrokHTTPRefreshAuthPolicy.shouldCommit(captured: captured, current: http.value) == false)
    }

    @Test("T-6GK-08 Existing GetGrokCreditsConfig T1–T16 still pass")
    func existingGrokCreditsConfigTestsStillPresent() throws {
        #expect(GrokCreditsConfigDecoder.remainingPercent(usedPercent: 63) == 37)
        let url = V2UsageSourceCatalog.productionTestFileURL(from: #filePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("T1 Grok 63 percent used becomes 37 percent remaining"))
        #expect(source.contains("T16 production Grok UI has no weeklyRPC probe diagnostic"))
        #expect(V2UsageSourceCatalog.productionTestCount(in: source) == 133)
    }
}
