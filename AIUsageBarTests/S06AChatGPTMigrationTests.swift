import Foundation
import Testing
@testable import AIUsageBar

struct S06AChatGPTMigrationTests {
    @Test("T-6CG-01 Production ChatGPT still uses wham/usage unless S01C is PROVEN_EQUIVALENT")
    func productionChatGPTStaysOnWhamUsage() {
        #expect(ChatGPTCodexEquivalence.verdict(samples: [], liveEvidencePresent: false) == .notProven)
        #expect(V2ChatGPTProductionSource.liveEquivalenceVerdict == .notProven)
        #expect(V2ChatGPTProductionSource.selectedSource() == .chatGPTWeb)
        #expect(V2ChatGPTProductionSource.usagePath == "backend-api/wham/usage")
        #expect(V2ChatGPTProductionSource.selectedSource(verdict: .provenDifferent) == .chatGPTWeb)
        #expect(V2ChatGPTProductionSource.selectedSource(verdict: .notProven) == .chatGPTWeb)
    }

    @Test("T-6CG-02 Codex source remains disabled when verdict is NOT_PROVEN")
    func codexRemainsDisabledWhenNotProven() {
        #expect(V2ChatGPTProductionSource.isCodexEnabled(verdict: .notProven) == false)
        #expect(V2CodexChallengerUsageSource().isEnabled == false)
        #expect(V2CodexChallengerUsageSource().isSelectableForUI == false)
    }

    @Test("T-6CG-03 401 → 需重新登入")
    func status401MapsToNeedsRelogin() {
        var coordinator = V2RecoveryCoordinator()
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 401,
                accountKey: "acct-1",
                fetchedAt: Date(),
                payload: ["rate_limit": ["primary_window": ["used_percent": 1]]]
            ),
            previous: nil
        )
        #expect(result == .authFailure)
        #expect(coordinator.handle(.authFailure) == .requiresUserAction)
        #expect(coordinator.uiCopy == "需重新登入")
    }

    @Test("T-6CG-04 Valid snapshot → 已登入 + short + weekly meters")
    func validSnapshotIsSignedInWithShortAndWeekly() {
        let result = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "acct-1",
                fetchedAt: Date(),
                payload: [
                    "rate_limit": [
                        "primary_window": ["used_percent": 40],
                        "secondary_window": ["used_percent": 10]
                    ]
                ]
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        var coordinator = V2RecoveryCoordinator()
        #expect(coordinator.handle(.validSnapshot(snapshot)) == .healthy)
        #expect(coordinator.uiCopy == "已登入")
        #expect(snapshot.meters.contains { $0.window.classification == .short })
        #expect(snapshot.meters.contains { $0.window.classification == .weekly })
    }

    @Test("T-6CG-05 Overnight expiry fixture still fails closed")
    func overnightExpiryFailsClosed() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.validSnapshot(
            V2UsageSnapshot(
                provider: .chatGPT,
                accountKey: "acct-1",
                meters: [
                    V2UsageMeter(
                        meterId: "chatgpt.primary_window",
                        window: V2Window(classification: .short, duration: 5 * 60 * 60),
                        remainingPercent: 50,
                        isPrimaryDisplayed: true
                    )!
                ],
                fetchedAt: Date()
            )!
        ))
        #expect(coordinator.handle(.authFailure) == .requiresUserAction)
        #expect(coordinator.uiCopy == "需重新登入")
    }

    @Test("T-6CG-06 No ChatGPT hidden WKWebView restorer is introduced")
    func noChatGPTHiddenWKWebViewRestorer() throws {
        #expect(V2ChatGPTProductionSource.introducesHiddenWKWebViewRestorer == false)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Service/ChatGPTService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("WKWebView") == false)
        #expect(source.contains("wham/usage"))
    }

    @Test("T-6CG-07 Notification still uses primary displayed meter only")
    func notificationUsesPrimaryDisplayedMeterOnly() {
        var latch = V2PrimaryAlertLatch()
        let snapshot = V2UsageSnapshot(
            provider: .chatGPT,
            accountKey: "acct-1",
            meters: [
                V2UsageMeter(
                    meterId: "chatgpt.primary_window",
                    window: V2Window(classification: .short, duration: 5 * 60 * 60),
                    remainingPercent: 40,
                    isPrimaryDisplayed: true
                )!,
                V2UsageMeter(
                    meterId: "chatgpt.secondary_window",
                    window: V2Window(classification: .weekly, duration: 7 * 24 * 60 * 60),
                    remainingPercent: 10,
                    isPrimaryDisplayed: false
                )!
            ],
            fetchedAt: Date()
        )!
        let weekly = snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }!
        #expect(latch.shouldNotify(snapshot: snapshot, meter: weekly) == false)
    }

    @Test("T-6CG-08 Existing ChatGPT tests still pass")
    func existingChatGPTParseStillPasses() throws {
        let parsed = try ChatGPTService.parseUsage([
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": ["used_percent": 10]
            ]
        ])
        #expect(parsed.sessionRemainingPercent == 79)
        #expect(parsed.weeklyRemainingPercent == 90)
        let url = V2UsageSourceCatalog.productionTestFileURL(from: #filePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("chatGPTUsageParsingHandlesBoundariesAndDateFields"))
    }
}
