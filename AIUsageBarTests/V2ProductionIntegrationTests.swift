import Foundation
import Testing
@testable import AIUsageBar

struct V2ProductionIntegrationTests {
    @Test("Production refresh invokes V2 and commits ChatGPT Claude Grok snapshots")
    @MainActor
    func productionRefreshInvokesV2PathAndCommitsSnapshots() async {
        let chatGPT = ControllableChatGPTUsageService()
        let claude = ControllableClaudeUsageService()
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: claude,
            grok: grok,
            restorer: restorer
        )

        chatGPT.enqueue(.success(sampleChatGPT(session: 55, weekly: 80)))
        claude.enqueue(.success(sampleClaude(session: 10, weekly: 20)))
        grok.enqueue(.success(sampleGrok(session: 40, weekly: 12)))

        model.setChatGPTCredential(
            WebCredential(
                cookieName: "__Secure-next-auth.session-token",
                value: "chatgpt-token",
                cookieHeader: "__Secure-next-auth.session-token=chatgpt-token"
            )
        )
        model.setClaudeSessionKey("claude-session")
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "grok-token", cookieHeader: "sso=grok-token")
        )

        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)

        #expect(model.v2FetchInvocationCount(for: .chatGPT) >= 1)
        #expect(model.v2FetchInvocationCount(for: .claude) >= 1)
        #expect(model.v2FetchInvocationCount(for: .grok) >= 1)
        #expect(model.v2PathInvocationCount() >= 3)

        let chatSnap = model.v2Snapshot(for: .chatGPT)
        let claudeSnap = model.v2Snapshot(for: .claude)
        let grokSnap = model.v2Snapshot(for: .grok)
        #expect(chatSnap != nil)
        #expect(claudeSnap != nil)
        #expect(grokSnap != nil)
        #expect(chatSnap?.displayedPrimaryMeter?.remainingPercent == 55)
        #expect(claudeSnap?.displayedPrimaryMeter?.remainingPercent == 10)
        #expect(grokSnap?.displayedPrimaryMeter?.meterId == "grok.weekly")
        #expect(model.chatGPT.sessionPercent == 55)
        #expect(model.chatGPT.weeklyPercent == 80)
        #expect(model.claude.sessionPercent == 10)
        #expect(model.claude.weeklyPercent == 20)
        #expect(model.grok.sessionPercent == 40)
        #expect(model.grok.weeklyPercent == 12)
        #expect(chatGPT.cookieHeaders.count == 1)
        #expect(claude.sessionKeys.count == 1)
        #expect(grok.cookieHeaders.count == 1)
        #expect(restorer.restoreAfterCount == 0)
    }

    @Test("Stale generation result cannot commit after account switch")
    @MainActor
    func staleGenerationCannotCommitAfterAccountSwitch() async {
        let chatGPT = ControllableChatGPTUsageService()
        let claude = ControllableClaudeUsageService()
        let grok = ControllableGrokUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: claude,
            grok: grok,
            restorer: GrokSessionRestorerSpy()
        )
        chatGPT.enqueue(.success(sampleChatGPT(session: 1, weekly: 1)))
        claude.enqueue(.success(sampleClaude(session: 1, weekly: 1)))
        grok.enqueue(.success(sampleGrok(session: 11, weekly: 37)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        #expect(model.v2Snapshot(for: .grok)?.accountKey == UsageIdentity.accountKey(from: "token-A"))

        let inFlight = Task { await model.refreshAll() }
        await grok.waitUntilFetchStartedCount(2)
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-B", cookieHeader: "sso=token-B")
        )
        grok.enqueue(.success(sampleGrok(session: 88, weekly: 12)))
        grok.completeNext(sampleGrok(session: 11, weekly: 37))
        await inFlight.value
        await grok.waitUntilFetchStartedCount(3)
        await waitUntilRefreshIdle(model)

        #expect(model.grok.weeklyPercent == 12)
        #expect(model.v2Snapshot(for: .grok)?.accountKey == UsageIdentity.accountKey(from: "token-B"))
        #expect(model.v2Snapshot(for: .grok)?.displayedPrimaryMeter?.remainingPercent == 12)
    }

    @Test("Recovery cannot succeed from cookie or WK readiness alone")
    @MainActor
    func recoveryCannotSucceedFromCookieOrWebKitAlone() async {
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer
        )
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(2)
        await waitUntilRefreshIdle(model)

        #expect(model.grok.isLoaded == false)
        #expect(model.v2Snapshot(for: .grok) == nil)
        #expect(model.v2GrokRecoveryState() == .requiresUserAction)
        #expect(restorer.restoreAfterCount == 1)
        #expect(
            GrokV2RecoveryGate.isRecovered(
                snapshot: nil,
                expectedAccountKey: UsageIdentity.accountKey(from: "token-A"),
                cookiePresent: true,
                webKitReady: true
            ) == false
        )
    }

    @Test("Recovery succeeds after valid post-recovery usage fetch")
    @MainActor
    func recoverySucceedsAfterValidPostRecoveryFetch() async {
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer
        )
        grok.enqueue(.failure(AIUsageServiceError.wafBlocked("Grok")))
        grok.enqueue(.success(sampleGrok(session: 70, weekly: 25)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(2)
        await waitUntilRefreshIdle(model)

        #expect(model.grok.isLoaded)
        #expect(model.grok.weeklyPercent == 25)
        #expect(model.v2Snapshot(for: .grok)?.displayedPrimaryMeter?.remainingPercent == 25)
        #expect(model.v2GrokRecoveryState() == .healthy)
        #expect(restorer.restoreAfterCount == 1)
        #expect(grok.cookieHeaders.count == 2)
    }

    @Test("One restore and one retry bound is enforced on the production recovery path")
    @MainActor
    func oneRestoreAndOneRetryBoundIsEnforced() async {
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer
        )
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(2)
        await waitUntilRefreshIdle(model)
        #expect(restorer.restoreAfterCount == 1)
        #expect(model.v2GrokRecoveryState() == .requiresUserAction)

        let restoreIfNeededAfterLatch = restorer.restoreIfNeededCount
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)

        #expect(restorer.restoreAfterCount == 1)
        #expect(restorer.restoreIfNeededCount == restoreIfNeededAfterLatch)
        #expect(model.v2GrokRecoveryState() == .requiresUserAction)
        #expect(model.grok.isLoaded == false)
    }

    @Test("resetAt crossing changes V2 validity on the production snapshot")
    @MainActor
    func resetAtCrossingChangesProductionValidity() async {
        let chatGPT = ControllableChatGPTUsageService()
        let resetAt = Date().addingTimeInterval(30)
        chatGPT.enqueue(
            .success(
                ChatGPTUsage(
                    sessionRemainingPercent: 40,
                    resetText: "soon",
                    weeklyRemainingPercent: nil,
                    weeklyResetText: nil,
                    sessionResetAt: resetAt
                )
            )
        )
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            restorer: GrokSessionRestorerSpy()
        )
        model.setChatGPTCredential(
            WebCredential(
                cookieName: "__Secure-next-auth.session-token",
                value: "chatgpt-token",
                cookieHeader: "__Secure-next-auth.session-token=chatgpt-token"
            )
        )
        await model.refreshAll()
        await waitUntilRefreshIdle(model)

        let snapshot = model.v2Snapshot(for: .chatGPT)
        #expect(snapshot?.displayedPrimaryMeter?.resetAt == resetAt)
        #expect(
            model.v2PrimaryMeterValidity(
                for: .chatGPT,
                now: resetAt.addingTimeInterval(-1)
            ) != .expired
        )
        #expect(model.v2PrimaryMeterValidity(for: .chatGPT, now: resetAt) == .expired)
        #expect(chatGPT.cookieHeaders.count == 1)
    }

    @Test("Identity-unavailable recovery can succeed safely without cache reuse")
    @MainActor
    func identityUnavailableRecoverySucceedsWithoutCacheReuse() async throws {
        let grok = ControllableGrokUsageService()
        grok.enqueue(.success(sampleGrok(session: 40, weekly: 12)))
        let source = GrokProductionUsageSource(
            service: grok,
            rateLimitsCookieHeader: "",
            weeklyCookieHeader: "",
            accountCredential: ""
        )
        let snapshot = try await source.fetchSnapshot()
        #expect(snapshot.accountKey == nil)
        #expect(snapshot.accountKeyUnavailable)
        #expect(UsageIdentity.accountKey(from: "") == nil)
        #expect(
            GrokV2RecoveryGate.isRecovered(
                snapshot: snapshot,
                expectedAccountKey: nil,
                cookiePresent: true,
                webKitReady: true
            )
        )
        #expect(
            GrokV2RecoveryGate.isRecovered(
                snapshot: nil,
                expectedAccountKey: nil,
                cookiePresent: true,
                webKitReady: true
            ) == false
        )

        var cache = UsageAccountCache()
        cache.store(snapshot)
        let other = UsageCacheIdentity(
            provider: .grok,
            accountKey: UsageIdentity.accountKey(from: "someone-else"),
            meterId: "grok.weekly",
            window: .weekly
        )
        #expect(cache.snapshot(for: other) == nil)
        #expect(
            cache.snapshot(
                for: UsageCacheIdentity(
                    provider: .grok,
                    accountKey: nil,
                    meterId: "grok.weekly",
                    window: .weekly
                )
            ) == nil
        )
    }

    @Test("Notification identity stays on the displayed primary meter")
    @MainActor
    func notificationStaysOnDisplayedPrimaryMeter() async {
        let grok = ControllableGrokUsageService()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: GrokSessionRestorerSpy()
        )
        grok.enqueue(.success(sampleGrok(session: 11, weekly: 40)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        #expect(model.v2LastNotifiedMeterId(for: .grok) == nil)

        grok.enqueue(.success(sampleGrok(session: 5, weekly: 18)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(model.v2LastNotifiedMeterId(for: .grok) == "grok.weekly")
        #expect(model.v2Snapshot(for: .grok)?.displayedPrimaryMeter?.meterId == "grok.weekly")
        #expect(model.grok.primaryRemainingPercent == 18)
    }

    @MainActor
    private func makeModel(
        chatGPT: any ChatGPTUsageFetching,
        claude: any ClaudeUsageFetching,
        grok: GrokUsageFetching,
        restorer: GrokSessionRestorerSpy
    ) -> UsageViewModel {
        UsageViewModel(
            claudeService: claude,
            chatGPTService: chatGPT,
            grokService: grok,
            grokSessionRestorer: restorer,
            grokCookieSource: EmptyGrokRefreshCookieSource()
        )
    }

    @MainActor
    private func waitUntilRefreshIdle(_ model: UsageViewModel) async {
        while model.isLoading {
            await Task.yield()
        }
    }

    private func sampleChatGPT(session: Int, weekly: Int?) -> ChatGPTUsage {
        ChatGPTUsage(
            sessionRemainingPercent: session,
            resetText: "5h",
            weeklyRemainingPercent: weekly,
            weeklyResetText: weekly == nil ? nil : "w"
        )
    }

    private func sampleClaude(session: Int, weekly: Int) -> ClaudeUsage {
        ClaudeUsage(
            sessionRemainingPercent: session,
            weeklyRemainingPercent: weekly,
            resetText: "a",
            weeklyResetText: "b"
        )
    }

    private func sampleGrok(session: Int, weekly: Int?) -> GrokUsage {
        GrokUsage(
            sessionRemainingPercent: session,
            resetText: "s",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: weekly,
            weeklyResetText: weekly == nil ? nil : "w",
            weeklyRelativeResetText: weekly == nil ? nil : "r"
        )
    }
}

final class ImmediateGrokUsageService: GrokUsageFetching, @unchecked Sendable {
    func fetchUsage(
        rateLimitsCookieHeader: String,
        weeklyCookieHeader: String
    ) async throws -> GrokUsage {
        GrokUsage(
            sessionRemainingPercent: 100,
            resetText: "ok",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            weeklyRelativeResetText: nil
        )
    }
}

final class ImmediateChatGPTUsageService: ChatGPTUsageFetching, @unchecked Sendable {
    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        ChatGPTUsage(
            sessionRemainingPercent: 100,
            resetText: "ok",
            weeklyRemainingPercent: nil,
            weeklyResetText: nil
        )
    }
}

final class ImmediateClaudeUsageService: ClaudeUsageFetching, @unchecked Sendable {
    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        ClaudeUsage(
            sessionRemainingPercent: 100,
            weeklyRemainingPercent: 100,
            resetText: "ok",
            weeklyResetText: "ok"
        )
    }
}

final class ControllableChatGPTUsageService: ChatGPTUsageFetching, @unchecked Sendable {
    private var queued: [Result<ChatGPTUsage, Error>] = []
    private(set) var cookieHeaders: [String] = []

    func enqueue(_ result: Result<ChatGPTUsage, Error>) {
        queued.append(result)
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        cookieHeaders.append(cookieHeader)
        return try queued.removeFirst().get()
    }
}

final class ControllableClaudeUsageService: ClaudeUsageFetching, @unchecked Sendable {
    private var queued: [Result<ClaudeUsage, Error>] = []
    private(set) var sessionKeys: [String] = []

    func enqueue(_ result: Result<ClaudeUsage, Error>) {
        queued.append(result)
    }

    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        sessionKeys.append(sessionKey)
        return try queued.removeFirst().get()
    }
}
