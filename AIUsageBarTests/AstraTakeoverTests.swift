import Foundation
import Testing
@testable import AIUsageBar

@MainActor
struct AstraTakeoverTests {
    private func model(chatGPT: any ChatGPTUsageFetching = ImmediateChatGPTUsageService(),
                       grok: any GrokUsageFetching = ImmediateGrokUsageService(),
                       cookies: (any GrokRefreshCookieSource)? = nil) -> UsageViewModel {
        UsageViewModel(claudeService: ImmediateClaudeUsageService(), chatGPTService: chatGPT,
                       grokService: grok, grokSessionRestorer: GrokSessionRestorerSpy(),
                       grokCookieSource: cookies ?? EmptyGrokRefreshCookieSource(), credentialStore: KeychainManager(inMemory: true))
    }

    @Test func expiredResponseCannotReachExistingUI() async {
        let source = ControllableChatGPTUsageService()
        source.enqueue(.success(ChatGPTUsage(sessionRemainingPercent: 70, resetText: "old",
            weeklyRemainingPercent: nil, weeklyResetText: nil, sessionResetAt: Date().addingTimeInterval(-1))))
        let vm = model(chatGPT: source)
        vm.setChatGPTSessionToken("synthetic-A")
        await vm.refreshAll()
        #expect(vm.v2Snapshot(for: .chatGPT) == nil)
        #expect(!vm.chatGPT.isLoaded)
    }

    @Test func resetBoundaryKeepsVisibleUsageAndRequestsRefresh() async throws {
        let source = ControllableChatGPTUsageService()
        let reset = Date().addingTimeInterval(60)
        source.enqueue(.success(ChatGPTUsage(sessionRemainingPercent: 70, resetText: "future",
            weeklyRemainingPercent: nil, weeklyResetText: nil, sessionResetAt: reset)))
        let vm = model(chatGPT: source)
        vm.setChatGPTSessionToken("synthetic-A")
        await vm.refreshAll()
        #expect(vm.chatGPT.isLoaded)
        vm.expireInvalidUsage(now: reset.addingTimeInterval(-1))
        #expect(vm.chatGPT.isLoaded)

        let refreshedReset = reset.addingTimeInterval(3_600)
        source.enqueue(.success(ChatGPTUsage(sessionRemainingPercent: 65, resetText: "refreshed",
            weeklyRemainingPercent: nil, weeklyResetText: nil, sessionResetAt: refreshedReset)))
        vm.expireInvalidUsage(now: reset)
        vm.expireInvalidUsage(now: reset)
        while source.cookieHeaders.count < 2 { await Task.yield() }
        while vm.isLoading { await Task.yield() }
        #expect(vm.chatGPT.isLoaded)
        #expect(vm.chatGPT.sessionPercent == 65)
        #expect(vm.v2Snapshot(for: .chatGPT)?.displayedPrimaryMeter?.resetAt == refreshedReset)
        #expect(source.cookieHeaders.count == 2)
    }

    @Test func chatGPTAccountSwitchRejectsSuspendedCompletion() async {
        let service = SuspendedChatGPTSource()
        let vm = model(chatGPT: service)
        vm.setChatGPTSessionToken("synthetic-A")
        let task = Task { await vm.refreshAll() }
        while service.pending == nil { await Task.yield() }
        vm.setChatGPTSessionToken("synthetic-B")
        service.complete()
        await task.value
        #expect(vm.v2Snapshot(for: .chatGPT) == nil)
        #expect(!vm.chatGPT.isLoaded)
    }

    @Test func cookieAccountDriftDoesNotRelabelSuccessfulUsage() async {
        let service = ControllableGrokUsageService()
        let vm = model(grok: service, cookies: ForeignGrokCookies())
        service.enqueue(.success(GrokUsage(
            sessionRemainingPercent: 40,
            resetText: "ok",
            sessionWindowSeconds: 7_200,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            weeklyRelativeResetText: nil
        )))
        vm.setGrokSessionToken("synthetic-A")
        // setGrokCredential enqueues the production refresh.
        for _ in 0..<100 { await Task.yield() }
        while vm.isLoading { await Task.yield() }
        #expect(service.cookieHeaders == ["sso=synthetic-A"])
        #expect(vm.v2Snapshot(for: .grok)?.accountKey == UsageIdentity.accountKey(from: "synthetic-A"))
        #expect(vm.grok.isLoaded)
        #expect(vm.v2GrokRecoveryState() == .healthy)
    }

    @Test func disappearedMetersAreEvicted() throws {
        var cache = UsageAccountCache()
        var snapshot = V1UsageAdapters.chatGPTSnapshot(usage: ChatGPTUsage(sessionRemainingPercent: 80,
            resetText: "", weeklyRemainingPercent: 60, weeklyResetText: nil), token: "synthetic-A")
        let weekly = try #require(snapshot.cacheIdentities.last)
        cache.store(snapshot)
        #expect(cache.snapshot(for: weekly) != nil)
        snapshot.meters.removeLast()
        cache.store(snapshot)
        #expect(cache.snapshot(for: weekly) == nil)
    }

    @Test func secondaryResetDoesNotExpireValidPrimary() {
        let now = Date()
        let snapshot = V1UsageAdapters.chatGPTSnapshot(usage: ChatGPTUsage(sessionRemainingPercent: 80,
            resetText: "", weeklyRemainingPercent: 60, weeklyResetText: nil,
            sessionResetAt: now.addingTimeInterval(100), weeklyResetAt: now), token: "synthetic-A")
        #expect(snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey) == .fresh)
        #expect(snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey,
            meterId: "chatgpt.secondary_window", window: .weekly) == .expired)
    }

    @Test func actualNotificationManagerScopesPrimaryAndReset() {
        let defaults = UserDefaults(suiteName: "AstraNotification-\(UUID().uuidString)")!
        defaults.set(true, forKey: UsageNotificationSettings.isEnabledKey)
        let manager = UsageNotificationManager(defaults: defaults)
        let reset = Date().addingTimeInterval(100)
        func sample(_ remaining: Int, _ resetAt: Date, _ token: String = "A") {
            let usage = GrokUsage(sessionRemainingPercent: 1, resetText: "", sessionWindowSeconds: 0,
                weeklyRemainingPercent: remaining, weeklyResetText: nil, weeklyRelativeResetText: nil,
                weeklyResetAt: resetAt)
            let snapshot = V1UsageAdapters.grokSnapshot(usage: usage, sso: token)
            manager.evaluate(claude: UsageInfo(), chatGPT: UsageInfo(),
                grok: UsageInfo(sessionPercent: 1, weeklyPercent: remaining, weeklyAvailable: true, isLoaded: true),
                snapshots: [.grok: snapshot])
        }
        sample(50, reset)
        #expect(!manager.hasNotified(.grok))
        sample(20, reset)
        #expect(manager.hasNotified(.grok))
        #expect(manager.lastNotifiedMeterID(for: .grok) == "grok.weekly")
        sample(10, reset.addingTimeInterval(60))
        #expect(manager.hasNotified(.grok))
        sample(10, reset, "B")
        #expect(!manager.hasNotified(.grok))
        defaults.removeObject(forKey: UsageNotificationSettings.isEnabledKey)
    }

    @Test func parserResetsSurviveAdaptersAndUnknownStaysUnknown() throws {
        let timestamp = Date().addingTimeInterval(600).timeIntervalSince1970
        let gpt = try ChatGPTService.parseUsage(["rate_limit": ["primary_window": ["used_percent": 25, "reset_at": timestamp]]])
        let snapshot = V1UsageAdapters.chatGPTSnapshot(usage: gpt, token: "A")
        #expect(snapshot.meters[0].resetAt == Date(timeIntervalSince1970: timestamp))
        let claude = try ClaudeService.parseUsage(["five_hour": ["utilization": 25, "resets_at": timestamp], "seven_day": ["utilization": 10]])
        #expect(claude.sessionResetAt == Date(timeIntervalSince1970: timestamp))
        #expect(claude.weeklyResetAt == nil)
        #expect(ServiceSupport.resetDate("nan") == nil)
        #expect(ServiceSupport.resetDate(true) == nil)
        #expect(UsageIdentity.accountKey(from: "  ") == nil)
        #expect(UsageIdentity.fingerprint("A").count == 64)
    }

    @Test func requestCredentialBindingSupportsChunksAndRejectsMismatch() async {
        #expect(UsageIdentity.chatGPTCredential(in: "__Secure-next-auth.session-token.1=B; __Secure-next-auth.session-token.0=A") == "AB")
        #expect(UsageIdentity.chatGPTCredential(in: "next-auth.session-token.1=B") == nil)
        let service = ControllableChatGPTUsageService()
        let source = ChatGPTProductionUsageSource(service: service,
            cookieHeader: "next-auth.session-token=B", accountCredential: "A")
        do { _ = try await source.fetchSnapshot(); Issue.record("Mismatched credential accepted") }
        catch { #expect(service.cookieHeaders.isEmpty) }
    }

    @Test func failedRecoveryRearmsOnlyAfterCredentialChange() async {
        let service = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let vm = UsageViewModel(claudeService: ImmediateClaudeUsageService(), chatGPTService: ImmediateChatGPTUsageService(),
            grokService: service, grokSessionRestorer: restorer, grokCookieSource: EmptyGrokRefreshCookieSource(),
            credentialStore: KeychainManager(inMemory: true))
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        vm.setGrokSessionToken("A")
        await service.waitUntilFetchStartedCount(2)
        while vm.isLoading { await Task.yield() }
        #expect(restorer.restoreIfNeededCount == 0)
        #expect(restorer.restoreAfterCount == 1)
        #expect(vm.v2GrokRecoveryState() == .requiresUserAction)
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        await vm.refreshAll()
        #expect(restorer.restoreAfterCount == 1)
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        service.enqueue(.success(GrokUsage(sessionRemainingPercent: 40, resetText: "", sessionWindowSeconds: 0,
            weeklyRemainingPercent: nil, weeklyResetText: nil, weeklyRelativeResetText: nil)))
        vm.setGrokSessionToken("B")
        await service.waitUntilFetchStartedCount(5)
        while vm.isLoading { await Task.yield() }
        #expect(restorer.restoreAfterCount == 2)
        #expect(restorer.restoreIfNeededCount == 0)
        #expect(vm.v2GrokRecoveryState() == .healthy)
    }

    @Test func transientFailureAfterRestoreUsesBackoffNotLogin() async {
        let service = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let vm = UsageViewModel(claudeService: ImmediateClaudeUsageService(), chatGPTService: ImmediateChatGPTUsageService(),
            grokService: service, grokSessionRestorer: restorer, grokCookieSource: EmptyGrokRefreshCookieSource(),
            credentialStore: KeychainManager(inMemory: true))
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        service.enqueue(.failure(URLError(.timedOut)))
        vm.setGrokSessionToken("A")
        await service.waitUntilFetchStartedCount(2)
        while vm.isLoading { await Task.yield() }
        #expect(restorer.restoreAfterCount == 1)
        #expect(vm.v2GrokRetriesUsed() == 1)
        #expect(vm.v2GrokRecoveryState() == .backoff)
        #expect(vm.v2GrokRecoveryState() != .requiresUserAction)
    }

    @Test func claudeAccountSwitchRejectsSuspendedCompletion() async {
        let service = SuspendedClaudeSource()
        let vm = UsageViewModel(claudeService: service, chatGPTService: ImmediateChatGPTUsageService(),
            grokService: ImmediateGrokUsageService(), grokSessionRestorer: GrokSessionRestorerSpy(),
            grokCookieSource: EmptyGrokRefreshCookieSource(), credentialStore: KeychainManager(inMemory: true))
        vm.setClaudeSessionKey("A")
        let task = Task { await vm.refreshAll() }
        while service.pending == nil { await Task.yield() }
        vm.setClaudeSessionKey("B")
        service.complete()
        await task.value
        #expect(vm.v2Snapshot(for: .claude) == nil)
        #expect(!vm.claude.isLoaded)
    }

    @Test func logoutDuringRestorePreventsRetryAndStaleRecovery() async {
        let service = ControllableGrokUsageService()
        let restorer = SuspendedRestorer()
        let vm = UsageViewModel(claudeService: ImmediateClaudeUsageService(), chatGPTService: ImmediateChatGPTUsageService(),
            grokService: service, grokSessionRestorer: restorer, grokCookieSource: EmptyGrokRefreshCookieSource(),
            credentialStore: KeychainManager(inMemory: true))
        service.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        vm.setGrokSessionToken("A")
        while restorer.pending == nil { await Task.yield() }
        vm.setGrokSessionToken("")
        restorer.complete()
        while vm.isLoading { await Task.yield() }
        #expect(service.cookieHeaders.count == 1)
        #expect(vm.v2Snapshot(for: .grok) == nil)
        #expect(!vm.grok.isLoaded)
    }

    @Test func customWindowDurationParticipatesInIdentity() {
        func snapshot(_ seconds: Int) -> UsageSnapshot {
            V1UsageAdapters.grokSnapshot(usage: GrokUsage(sessionRemainingPercent: 40, resetText: "",
                sessionWindowSeconds: seconds, weeklyRemainingPercent: nil, weeklyResetText: nil,
                weeklyRelativeResetText: nil), sso: "A")
        }
        #expect(snapshot(7200).cacheIdentities != snapshot(14400).cacheIdentities)
    }

    @Test func grokCannotRedirectCredentialsToHTTP() {
        let request = URLRequest(url: URL(string: "http://grok.com/rest/rate-limits")!)
        #expect(GrokRedirectPolicy.requestAfterRedirect(request) == nil)
    }

    @Test func credentialsCannotFollowCrossOriginOrDowngrade() {
        let origin = URL(string: "https://claude.ai/api/organizations")!
        #expect(QuotaRedirectDelegate.permits(original: origin, destination: URL(string: "https://claude.ai/api/usage")))
        #expect(!QuotaRedirectDelegate.permits(original: origin, destination: URL(string: "https://other.example/api/usage")))
        #expect(!QuotaRedirectDelegate.permits(original: origin, destination: URL(string: "http://claude.ai/api/usage")))
    }
}

@MainActor
private final class SuspendedChatGPTSource: ChatGPTUsageFetching {
    var pending: CheckedContinuation<ChatGPTUsage, Never>?
    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        await withCheckedContinuation { pending = $0 }
    }
    func complete() {
        pending?.resume(returning: ChatGPTUsage(sessionRemainingPercent: 1, resetText: "", weeklyRemainingPercent: nil, weeklyResetText: nil))
        pending = nil
    }
}

@MainActor
private final class ForeignGrokCookies: GrokRefreshCookieSource {
    func grokCookies() async -> [HTTPCookie] {
        [HTTPCookie(properties: [.name: "sso", .value: "synthetic-B", .domain: "grok.com", .path: "/", .secure: "TRUE"])!]
    }
}

@MainActor
private final class SuspendedClaudeSource: ClaudeUsageFetching {
    var pending: CheckedContinuation<ClaudeUsage, Never>?
    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        await withCheckedContinuation { pending = $0 }
    }
    func complete() {
        pending?.resume(returning: ClaudeUsage(sessionRemainingPercent: 1, weeklyRemainingPercent: 1, resetText: "", weeklyResetText: ""))
        pending = nil
    }
}

@MainActor
private final class SuspendedRestorer: GrokSessionRestoring {
    var pending: CheckedContinuation<GrokSessionRestoreOutcome, Never>?
    func restoreIfNeeded() async -> GrokSessionRestoreOutcome { .success }
    func restoreAfterRecoverableFailure() async -> GrokSessionRestoreOutcome {
        await withCheckedContinuation { pending = $0 }
    }
    func reset() {}
    func complete() { pending?.resume(returning: .success); pending = nil }
}
