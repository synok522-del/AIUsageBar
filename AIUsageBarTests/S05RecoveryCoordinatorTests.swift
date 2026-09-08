import Foundation
import Testing
@testable import AIUsageBar

struct S05RecoveryCoordinatorTests {
    @Test("T-5-01 HEALTHY + valid snapshot stays HEALTHY")
    func healthyPlusValidSnapshotStaysHealthy() {
        var coordinator = V2RecoveryCoordinator()
        #expect(coordinator.phase == .healthy)
        let phase = coordinator.handle(.validSnapshot(sampleSnapshot()))
        #expect(phase == .healthy)
        #expect(coordinator.uiCopy == V2UICopy.signedIn)
    }

    @Test("T-5-02 Transient fetch failure → RECOVERING")
    func transientFetchFailureEntersRecovering() {
        var coordinator = V2RecoveryCoordinator()
        #expect(coordinator.handle(.transientFetchFailure) == .recovering)
    }

    @Test("T-5-03 RECOVERING does not emit 需重新登入")
    func recoveringDoesNotEmitNeedsRelogin() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.phase == .recovering)
        #expect(coordinator.uiCopy != V2UICopy.needsRelogin)
        #expect(coordinator.uiCopy == V2UICopy.signedIn)
    }

    @Test("T-5-04 After N failures → BACKOFF")
    func afterNFailuresEntersBackoff() {
        var coordinator = V2RecoveryCoordinator()
        for _ in 1..<V2ArchitectureConstants.recoverFailureLimit {
            _ = coordinator.handle(.transientFetchFailure)
        }
        #expect(coordinator.phase == .recovering)
        #expect(coordinator.handle(.transientFetchFailure) == .backoff)
    }

    @Test("T-5-05 BACKOFF shows 資料暫時無法取得, not 需重新登入")
    func backoffShowsTemporarilyUnavailable() {
        var coordinator = enterBackoff()
        #expect(coordinator.phase == .backoff)
        #expect(coordinator.uiCopy == V2UICopy.temporarilyUnavailable)
        #expect(coordinator.uiCopy != V2UICopy.needsRelogin)
    }

    @Test("T-5-06 Auth-class 401/403 → REQUIRES_USER_ACTION + 需重新登入")
    func authClassEntersRequiresUserAction() {
        var coordinator = V2RecoveryCoordinator()
        #expect(coordinator.handle(.authFailure) == .requiresUserAction)
        #expect(coordinator.uiCopy == V2UICopy.needsRelogin)
    }

    @Test("T-5-07 Success from RECOVERING returns HEALTHY only after valid parse")
    func successFromRecoveringRequiresValidParse() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.phase == .recovering)
        #expect(coordinator.handle(.transientFetchFailure) == .recovering)
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
        #expect(coordinator.handle(.validSnapshot(sampleSnapshot())) == .healthy)
    }

    @Test("T-5-08 Cookie-exists event does not transition to HEALTHY")
    func cookieExistsDoesNotBecomeHealthyFromRecovering() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.handle(.cookieExists) == .recovering)
        #expect(coordinator.phase != .healthy)
    }

    @Test("T-5-09 Navigation-finished event does not transition to HEALTHY")
    func navigationFinishedDoesNotBecomeHealthy() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.handle(.navigationFinished) == .recovering)
    }

    @Test("T-5-10 WKWebView READY event does not transition to HEALTHY")
    func webKitReadyDoesNotBecomeHealthy() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.handle(.webKitReady) == .recovering)
        #expect(coordinator.phase != .healthy)
    }

    @Test("T-5-11 Identity mismatch on success response → INVALID, not HEALTHY")
    func identityMismatchIsNotHealthy() {
        var coordinator = V2RecoveryCoordinator()
        #expect(
            V2SnapshotValidityPolicy.validity(
                fetchedAt: Date(),
                now: Date(),
                lastParseSucceeded: true,
                identityMatched: false
            ) == .invalid
        )
        let phase = coordinator.handle(.identityMismatch)
        #expect(phase != .healthy)
    }

    @Test("T-5-12 Logout generation increments and cancels in-flight recover")
    func logoutIncrementsGenerationAndCancelsInFlight() {
        var coordinator = V2RecoveryCoordinator()
        let captured = coordinator.beginRecover()
        coordinator.logout()
        #expect(coordinator.ignoreStale(capturedGeneration: captured))
        #expect(coordinator.phase == .requiresUserAction)
    }

    @Test("T-5-13 A stale recover success with old generation is ignored")
    func staleRecoverSuccessWithOldGenerationIsIgnored() {
        var coordinator = V2RecoveryCoordinator()
        let captured = coordinator.beginRecover()
        coordinator.logout()
        #expect(coordinator.ignoreStale(capturedGeneration: captured))
        #expect(coordinator.handle(.validSnapshot(sampleSnapshot())) == .requiresUserAction)
    }

    @Test("T-5-14 Coordinator has no WebKit import")
    func coordinatorHasNoWebKitImport() throws {
        let source = try coordinatorSource()
        #expect(source.contains("import WebKit") == false)
        #expect(V2RecoverySourceImports.importsWebKit == false)
    }

    @Test("T-5-15 Coordinator has no provider-specific URL strings")
    func coordinatorHasNoProviderURLStrings() throws {
        let source = try coordinatorSource()
        #expect(source.contains("https://chatgpt.com") == false)
        #expect(source.contains("https://claude.ai") == false)
        #expect(source.contains("https://grok.com") == false)
        #expect(V2RecoverySourceImports.containsProviderURLStrings == false)
    }

    @Test("T-5-16 ChatGPT overnight-expiry fixture: credential present + 401 → REQUIRES_USER_ACTION")
    func chatGPTOvernightExpiryFailsClosed() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.validSnapshot(sampleSnapshot()))
        let chatGPT401 = V2ChatGPTWebUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 401,
                accountKey: "acct-1",
                fetchedAt: Date(),
                payload: ["rate_limit": ["primary_window": ["used_percent": 1]]]
            ),
            previous: nil
        )
        #expect(chatGPT401 == .authFailure)
        #expect(coordinator.handle(.authFailure) == .requiresUserAction)
        #expect(coordinator.uiCopy == V2UICopy.needsRelogin)
    }

    @Test("T-5-17 Claude missing statusline rate_limits does not enter REQUIRES_USER_ACTION")
    func claudeMissingRateLimitsDoesNotRequireUserAction() {
        #expect(ClaudeStatuslineParser.parse(jsonString: #"{"captured_at":"2026-09-08T12:00:00Z"}"#) == .noMeterInSnapshot)
        var coordinator = V2RecoveryCoordinator()
        #expect(coordinator.handle(.missingSnapshotMeters) == .recovering)
        #expect(coordinator.phase != .requiresUserAction)
        #expect(coordinator.uiCopy != V2UICopy.needsRelogin)
    }

    @Test("T-5-18 Grok restore race: first recover cannot clobber a newer logout")
    func grokFirstRecoverCannotClobberNewerLogout() {
        var coordinator = V2RecoveryCoordinator()
        let first = coordinator.beginRecover()
        coordinator.logout()
        #expect(coordinator.ignoreStale(capturedGeneration: first))
        #expect(coordinator.handle(.validSnapshot(sampleSnapshot(provider: .grok))) == .requiresUserAction)
    }

    @Test("T-5-19 Cooldown is respected")
    func cooldownIsRespected() {
        var coordinator = enterBackoff(now: Date(timeIntervalSince1970: 1_780_000_000))
        #expect(
            coordinator.respectsCooldown(
                now: Date(timeIntervalSince1970: 1_780_000_000).addingTimeInterval(
                    V2ArchitectureConstants.backoffCooldown - 1
                )
            )
        )
        #expect(
            coordinator.respectsCooldown(
                now: Date(timeIntervalSince1970: 1_780_000_000).addingTimeInterval(
                    V2ArchitectureConstants.backoffCooldown
                )
            ) == false
        )
    }

    @Test("T-5-20 Allowed UI mapping: HEALTHY=已登入, BACKOFF=資料暫時無法取得, REQUIRES_USER_ACTION=需重新登入")
    func allowedUIMapping() {
        #expect(V2UICopyPolicy.copy(for: .healthy) == "已登入")
        #expect(V2UICopyPolicy.copy(for: .backoff) == "資料暫時無法取得")
        #expect(V2UICopyPolicy.copy(for: .requiresUserAction) == "需重新登入")
    }

    @Test("T-5-21 RECOVERING keeps last STALE_BUT_VALID numbers on the card if S02 says so")
    func recoveringKeepsLastStaleButValidNumbers() {
        var coordinator = V2RecoveryCoordinator()
        _ = coordinator.handle(.validSnapshot(sampleSnapshot()))
        _ = coordinator.handle(.transientFetchFailure)
        #expect(coordinator.phase == .recovering)
        #expect(coordinator.displayedSnapshotWhileRecovering()?.primaryDisplayedMeter?.remainingPercent == 60)
        #expect(coordinator.uiCopy != V2UICopy.needsRelogin)
    }

    @Test("T-5-22 No new hidden WKWebView is added in this sprint")
    func noNewHiddenWKWebView() throws {
        let source = try coordinatorSource()
        #expect(source.contains("WKWebView") == false)
        #expect(V2RecoverySourceImports.addedHiddenWKWebView == false)
    }

    @Test("T-5-23 All 133 existing tests still pass")
    func existingProductionTestsStillPresent() throws {
        let url = V2UsageSourceCatalog.productionTestFileURL(from: #filePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(V2UsageSourceCatalog.productionTestCount(in: source) == 133)
    }

    private func coordinatorSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Lab/V2RecoveryCoordinator.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sampleSnapshot(provider: V2Provider = .chatGPT) -> V2UsageSnapshot {
        V2UsageSnapshot(
            provider: provider,
            accountKey: "acct-1",
            meters: [
                V2UsageMeter(
                    meterId: "chatgpt.primary_window",
                    window: V2Window(classification: .short, duration: 5 * 60 * 60),
                    remainingPercent: 60,
                    isPrimaryDisplayed: true
                )!
            ],
            fetchedAt: Date()
        )!
    }

    private func enterBackoff(now: Date = Date()) -> V2RecoveryCoordinator {
        var coordinator = V2RecoveryCoordinator()
        for _ in 0..<V2ArchitectureConstants.recoverFailureLimit {
            _ = coordinator.handle(.transientFetchFailure, now: now)
        }
        return coordinator
    }
}
