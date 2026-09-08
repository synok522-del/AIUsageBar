import Foundation
import Testing
@testable import AIUsageBar

struct S06BClaudeMigrationTests {
    @Test("T-6CL-01 Default source remains claude.ai web usage")
    func defaultSourceRemainsClaudeWeb() {
        #expect(V2ClaudeProductionSource.webHost == "claude.ai")
        #expect(V2ClaudeWebUsageSource().isSelectableForUI)
        #expect(V2ClaudeProductionSource.selectedSource(bridge: ClaudeStatuslineBridgeConfig()) == .webOnly)
    }

    @Test("T-6CL-02 Snapshot bridge default off")
    func snapshotBridgeDefaultOff() {
        #expect(ClaudeStatuslineBridgeConfig().isEnabled == false)
        #expect(V2ClaudeSnapshotBridgeUsageSource().isEnabled == false)
    }

    @Test("T-6CL-03 When bridge on and rate_limits present, meters match web remaining rule")
    func bridgeOnWithRateLimitsMatchesWebRemainingRule() {
        var config = ClaudeStatuslineBridgeConfig()
        config.enable()
        var bridge = V2ClaudeSnapshotBridgeUsageSource()
        bridge.isEnabled = true
        let result = bridge.load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "org-1",
                fetchedAt: Date(),
                payload: [
                    "rate_limits": [
                        "five_hour": ["utilization": 0.37],
                        "seven_day": ["utilization": 0.10]
                    ]
                ]
            ),
            previous: nil
        )
        guard case .snapshot(let snapshot) = result else {
            Issue.record("expected snapshot, got \(result)")
            return
        }
        #expect(snapshot.meters.first { $0.meterId == "claude.five_hour" }?.remainingPercent == 63)
        #expect(snapshot.meters.first { $0.meterId == "claude.seven_day" }?.remainingPercent == 90)
        #expect(V2ClaudeProductionSource.selectedSource(bridge: config) == .statuslineBridge)
    }

    @Test("T-6CL-04 When bridge on and rate_limits missing → keep last valid or show temporary failure, not logout")
    func missingRateLimitsIsNotLogout() {
        var bridge = V2ClaudeSnapshotBridgeUsageSource()
        bridge.isEnabled = true
        var coordinator = V2RecoveryCoordinator()
        let last = V2UsageSnapshot(
            provider: .claude,
            accountKey: "org-1",
            meters: [
                V2UsageMeter(
                    meterId: "claude.five_hour",
                    window: V2Window(classification: .short, duration: 5 * 60 * 60),
                    remainingPercent: 63,
                    isPrimaryDisplayed: true
                )!
            ],
            fetchedAt: Date()
        )!
        _ = coordinator.handle(.validSnapshot(last))
        let parsed = ClaudeStatuslineParser.parse(jsonString: #"{"captured_at":"2026-09-08T12:00:00Z"}"#)
        #expect(parsed == .noMeterInSnapshot)
        let result = bridge.load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "org-1",
                fetchedAt: Date(),
                payload: ["captured_at": "2026-09-08T12:00:00Z"]
            ),
            previous: last
        )
        #expect(result == .invalid)
        #expect(coordinator.handle(.missingSnapshotMeters) != .requiresUserAction)
        #expect(coordinator.uiCopy != "需重新登入")
    }

    @Test("T-6CL-05 Bridge off restores web-only")
    func bridgeOffRestoresWebOnly() {
        var config = ClaudeStatuslineBridgeConfig()
        config.enable()
        config.disable()
        #expect(config.selectedSource == .webOnly)
        #expect(V2ClaudeProductionSource.selectedSource(bridge: config) == .webOnly)
    }

    @Test("T-6CL-06 No Claude OAuth credential reuse is enabled")
    func noClaudeOAuthCredentialReuse() {
        #expect(V2ClaudeProductionSource.oauthCredentialReuseEnabled == false)
    }

    @Test("T-6CL-07 401/403 still 需重新登入")
    func status401And403StillNeedRelogin() {
        var coordinator = V2RecoveryCoordinator()
        #expect(V2ClaudeWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 401,
                accountKey: "org-1",
                fetchedAt: Date(),
                payload: [:]
            ),
            previous: nil
        ) == .authFailure)
        #expect(V2ClaudeWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 403,
                accountKey: "org-1",
                fetchedAt: Date(),
                payload: [:]
            ),
            previous: nil
        ) == .forbidden)
        #expect(coordinator.handle(.authFailure) == .requiresUserAction)
        #expect(coordinator.uiCopy == "需重新登入")
    }

    @Test("T-6CL-08 Existing Claude tests still pass")
    func existingClaudeParseStillPasses() throws {
        let parsed = try ClaudeService.parseUsage([
            "five_hour": ["utilization": 0],
            "seven_day": ["utilization": 100]
        ])
        #expect(parsed.sessionRemainingPercent == 100)
        #expect(parsed.weeklyRemainingPercent == 0)
    }
}
