import Foundation
import Testing
@testable import AIUsageBar

struct ReliabilityHardeningUnitTests {
    @Test("Duplicate lane begins are rejected until finish")
    func laneBookSingleFlightAndLateEpoch() {
        var book = ProviderRefreshLaneBook()
        let first = book.begin(.chatGPT)
        #expect(book.isInFlight(.chatGPT))
        #expect(book.isCurrent(.chatGPT, epoch: first))
        #expect(book.anyInFlight)
        book.finish(.chatGPT, epoch: first)
        #expect(book.isInFlight(.chatGPT) == false)
        #expect(book.isCurrent(.chatGPT, epoch: first) == false)
        let second = book.begin(.claude)
        #expect(book.isInFlight(.chatGPT) == false)
        #expect(book.isInFlight(.claude))
        book.finish(.claude, epoch: second)
        #expect(book.anyInFlight == false)
    }

    @Test("Backoff delay uses Retry-After as a floor and honors values above the cap")
    func backoffDelayFloorAndServerHonor() {
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 0, retryAfter: nil) == 60)
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 0, retryAfter: 0) == 60)
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 0, retryAfter: 120) == 120)
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 0, retryAfter: 1_200) == 1_200)
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 1, retryAfter: nil) == 120)
        #expect(HTTPRateLimitBackoffPolicy.delay(step: 8, retryAfter: nil) == 15 * 60)
    }

    @Test("Retry-After parser accepts delta seconds and HTTP-date")
    func retryAfterParserAcceptsDeltaAndHTTPDate() {
        #expect(RetryAfterParser.timeInterval(from: "120") == 120)
        #expect(RetryAfterParser.timeInterval(from: "0") == 0)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let header = "Wed, 15 Nov 2023 00:13:20 GMT"
        let parsed = RetryAfterParser.timeInterval(from: header, now: now)
        #expect(parsed == 7_200)
    }

    @Test("Last-good schema mismatch and account mismatch fail closed")
    func lastGoodSchemaAndAccountMismatchFailClosed() throws {
        let defaults = UserDefaults(suiteName: "aiusgbar.lastgood.\(UUID().uuidString)")!
        let store = LastGoodUsageStore(defaults: defaults)
        let asOf = Date(timeIntervalSince1970: 1_000)
        let snapshot = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 55,
                resetText: "do-not-persist-this",
                weeklyRemainingPercent: 80,
                weeklyResetText: "also-relative",
                sessionResetAt: asOf.addingTimeInterval(3_600)
            ),
            token: "token-A",
            asOf: asOf
        )
        let accountKey = try #require(UsageIdentity.accountKey(from: "token-A"))
        store.save(snapshot)
        let loaded = try #require(store.load(provider: .chatGPT, accountKey: accountKey))
        #expect(loaded.asOf == asOf)
        #expect(loaded.meters.allSatisfy { $0.resetText == nil && $0.weeklyRelativeResetText == nil })
        #expect(store.load(provider: .chatGPT, accountKey: "other") == nil)

        var mismatched = try #require(LastGoodUsageStore.record(from: snapshot))
        mismatched.schemaVersion = 99
        let data = try JSONEncoder().encode(mismatched)
        defaults.set(data, forKey: LastGoodUsageStore.storageKey(provider: "chatGPT", accountKey: accountKey))
        #expect(store.load(provider: .chatGPT, accountKey: accountKey) == nil)
    }

    @Test("Persisted last-good recomputes relative reset text")
    func persistedLastGoodRecomputesRelativeReset() throws {
        let asOf = Date(timeIntervalSince1970: 1_000)
        let resetAt = asOf.addingTimeInterval(3_600)
        let snapshot = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 40,
                resetText: "resets in 5 minutes",
                weeklyRemainingPercent: nil,
                weeklyResetText: nil,
                sessionResetAt: resetAt
            ),
            token: "token-A",
            asOf: asOf
        )
        let now = resetAt.addingTimeInterval(-1_800)
        let info = try #require(UsageInfoFromSnapshot.make(snapshot, stale: true, now: now))
        #expect(info.isStale)
        #expect(info.observedAt == asOf)
        #expect(info.resetText != "resets in 5 minutes")
        #expect(info.resetText.contains("重置於"))
        #expect(info.staleCaption?.contains("上次更新") == true)
    }

    @Test("Weekly 429 HTML never becomes a Grok quota payload")
    func grokWeekly429HTMLDoesNotPublishQuota() {
        let html = Data("<html>429</html>".utf8)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 429,
            contentType: "text/html",
            body: html
        )
        #expect(quota == nil)
    }

    @Test("429 is not a Grok recoverable session failure")
    func grok429IsNotRecoverableSessionFailure() {
        let error = AIUsageServiceError.rateLimited("Grok", retryAfter: 120)
        #expect(GrokSessionRecoveryPolicy.isRecoverableSessionFailure(error) == false)
        #expect(GrokSessionRecoveryPolicy.isAuthenticationFailure(error) == false)
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: error
            ) == false
        )
    }
}

@MainActor
struct ReliabilityHardeningIntegrationTests {
    @Test("Timer wake and manual duplicate triggers coalesce to one HTTP per provider")
    func duplicateTriggersCoalesceToOneHTTP() async {
        let chatGPT = HangingChatGPTUsageService()
        let claude = HangingClaudeUsageService()
        let grok = ControllableGrokUsageService()
        let model = makeModel(chatGPT: chatGPT, claude: claude, grok: grok)
        grok.enqueue(.success(sampleGrok(session: 40, weekly: nil)))
        signInAll(model)
        chatGPT.complete(sampleChatGPT(session: 40))
        claude.complete(sampleClaude())
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        let chatGPTAfterLogin = chatGPT.fetchCount
        let claudeAfterLogin = claude.fetchCount
        let grokAfterLogin = grok.cookieHeaders.count

        let first = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(chatGPTAfterLogin + 1)
        await claude.waitUntilStarted(claudeAfterLogin + 1)
        await grok.waitUntilFetchStartedCount(grokAfterLogin + 1)
        model.handleWake()
        let second = Task { await model.refreshAll() }
        chatGPT.complete(sampleChatGPT(session: 41))
        claude.complete(sampleClaude(session: 41))
        grok.completeNext(sampleGrok(session: 41, weekly: nil))
        await first.value
        await second.value
        await waitUntilRefreshIdle(model)

        #expect(chatGPT.fetchCount == chatGPTAfterLogin + 1)
        #expect(claude.fetchCount == claudeAfterLogin + 1)
        #expect(grok.cookieHeaders.count == grokAfterLogin + 1)
    }

    @Test("Hung ChatGPT lane does not prevent Claude and Grok from completing")
    func hungChatGPTDoesNotBlockOtherLanes() async {
        let chatGPT = HangingChatGPTUsageService()
        let claude = CountingClaudeUsageService()
        let grok = CountingGrokUsageService()
        let model = makeModel(chatGPT: chatGPT, claude: claude, grok: grok)
        signInAll(model)
        await chatGPT.waitUntilStarted(1)
        await yieldUntil {
            claude.fetchCount >= 1 && grok.fetchCount >= 1 && model.claude.isLoaded && model.grok.isLoaded
        }
        #expect(model.claude.sessionPercent == 100)
        #expect(model.grok.sessionPercent == 100)
        #expect(model.chatGPT.isLoaded == false)
        #expect(model.isProviderInFlight(.chatGPT))
        #expect(model.isProviderInFlight(.claude) == false)
        #expect(model.isLoading)

        chatGPT.complete(sampleChatGPT(session: 33))
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 33)
        #expect(model.isLoading == false)
    }

    @Test("Deadline releases the lane and does not fabricate usage")
    func deadlineReleasesLaneWithoutFabricatingUsage() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 0.05,
                claude: 2,
                grok: 2,
                cookieStore: 0.05
            )
        )
        model.setChatGPTSessionToken("token-A")
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(model.isLoading == false)
        #expect(model.isProviderInFlight(.chatGPT) == false)
        #expect(model.chatGPT.isLoaded == false)
        #expect(model.chatGPT.sessionPercent == 0)
        #expect(model.chatGPT.errorMessage?.contains("逾時") == true)
        chatGPT.complete(sampleChatGPT(session: 99))
        await yieldBriefly()
        #expect(model.chatGPT.sessionPercent == 0)
        #expect(model.v2Snapshot(for: .chatGPT) == nil)
    }

    @Test("Deadline with last-good preserves previous usage")
    func deadlinePreservesLastGood() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 0.05,
                claude: 2,
                grok: 2,
                cookieStore: 0.05
            )
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.complete(sampleChatGPT(session: 71, resetAt: Date().addingTimeInterval(3_600)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 71)

        let hung = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(2)
        await hung.value
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.isLoaded)
        #expect(model.chatGPT.sessionPercent == 71)
        #expect(model.chatGPT.errorMessage?.contains("逾時") == true)
        #expect(model.isLoading == false)
    }

    @Test("Logout during flight rejects the late ChatGPT result")
    func logoutDuringFlightRejectsLateResult() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService()
        )
        model.setChatGPTSessionToken("token-A")
        let inFlight = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(1)
        model.setChatGPTSessionToken("token-B")
        chatGPT.complete(sampleChatGPT(session: 12))
        await inFlight.value
        await waitUntilRefreshIdle(model)
        #expect(model.v2Snapshot(for: .chatGPT) == nil)
        #expect(model.chatGPT.isLoaded == false)
    }

    @Test("Grok recovery stays one restore and one retry inside a single lane")
    func grokRecoveryRemainsOneRestoreOneRetry() async {
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
        let duplicate = Task { await model.refreshAll() }
        await grok.waitUntilFetchStartedCount(2)
        await waitUntilRefreshIdle(model)
        await duplicate.value
        #expect(restorer.restoreAfterCount == 1)
        #expect(grok.cookieHeaders.count == 2)
        #expect(model.v2GrokRecoveryState() == .healthy)
        #expect(model.grok.weeklyPercent == 25)
    }

    @Test("Wake while idle requests one refresh and coalesces when in-flight")
    func wakeIdleAndInFlightCoalesce() async {
        let grok = ControllableGrokUsageService()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok
        )
        grok.enqueue(.success(sampleGrok(session: 40, weekly: nil)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        let afterLogin = grok.cookieHeaders.count

        grok.enqueue(.success(sampleGrok(session: 41, weekly: nil)))
        model.handleWake()
        await grok.waitUntilFetchStartedCount(afterLogin + 1)
        await waitUntilRefreshIdle(model)
        #expect(grok.cookieHeaders.count == afterLogin + 1)

        let inFlight = Task { await model.refreshAll() }
        await grok.waitUntilFetchStartedCount(afterLogin + 2)
        model.handleWake()
        grok.completeNext(sampleGrok(session: 42, weekly: nil))
        await inFlight.value
        await waitUntilRefreshIdle(model)
        #expect(grok.cookieHeaders.count == afterLogin + 2)
    }

    @Test("Wake does not clear Grok requiresUserAction")
    func wakeDoesNotClearGrokRequiresUserAction() async {
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
        #expect(model.v2GrokRecoveryState() == .requiresUserAction)
        let restores = restorer.restoreAfterCount
        grok.enqueue(.failure(AIUsageServiceError.httpStatus("Grok", 401)))
        model.handleWake()
        await grok.waitUntilFetchStartedCount(3)
        await waitUntilRefreshIdle(model)
        #expect(model.v2GrokRecoveryState() == .requiresUserAction)
        #expect(restorer.restoreAfterCount == restores)
    }

    @Test("429 Retry-After 120 skips later triggers until the floor elapses")
    func retryAfter120IsHonoredAsFloor() async throws {
        let chatGPT = CountingChatGPTUsageService()
        let defaults = isolatedDefaults()
        let backoff = HTTPRateLimitBackoffStore(defaults: defaults)
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            defaults: defaults,
            backoffStore: backoff
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 120))
        )
        await model.refreshAll()
        let accountKey = UsageIdentity.accountKey(from: "token-A")!
        let until = try #require(model.backoffUntil(provider: .chatGPT, accountKey: accountKey))
        #expect(until != nil)
        #expect(until!.timeIntervalSinceNow >= 119)
        #expect(chatGPT.fetchCount == 1)
        #expect(model.chatGPT.errorMessage?.contains("登入已失效") != true)
        #expect(model.chatGPT.errorMessage?.contains("過於頻繁") == true)

        chatGPT.enqueue(.success(sampleChatGPT(session: 90)))
        await model.refreshAll()
        model.handleWake()
        model.expireInvalidUsage()
        await waitUntilRefreshIdle(model)
        #expect(chatGPT.fetchCount == 1)
    }

    @Test("Retry-After 0 still applies the minimum backoff")
    func retryAfterZeroStillAppliesMinimumBackoff() async {
        let chatGPT = CountingChatGPTUsageService()
        let defaults = isolatedDefaults()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            defaults: defaults
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 0))
        )
        await model.refreshAll()
        let accountKey = UsageIdentity.accountKey(from: "token-A")!
        let until = model.backoffUntil(provider: .chatGPT, accountKey: accountKey)
        #expect(until != nil)
        #expect((until?.timeIntervalSinceNow ?? 0) >= 59)
        chatGPT.enqueue(.success(sampleChatGPT(session: 90)))
        await model.refreshAll()
        #expect(chatGPT.fetchCount == 1)
    }

    @Test("Backoff survives relaunch and is not inherited by another account")
    func backoffSurvivesRelaunchAndIsAccountScoped() async {
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let backoff = HTTPRateLimitBackoffStore(defaults: defaults)
        let chatGPT1 = CountingChatGPTUsageService()
        let model1 = makeModel(
            chatGPT: chatGPT1,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood,
            backoffStore: backoff
        )
        model1.setChatGPTSessionToken("token-A")
        chatGPT1.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 120))
        )
        await model1.refreshAll()
        #expect(chatGPT1.fetchCount == 1)

        let chatGPT2 = CountingChatGPTUsageService()
        let model2 = makeModel(
            chatGPT: chatGPT2,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood,
            backoffStore: backoff
        )
        await model2.refreshAll()
        #expect(chatGPT2.fetchCount == 0)

        model2.setChatGPTSessionToken("token-B")
        chatGPT2.enqueue(.success(sampleChatGPT(session: 66, resetAt: Date().addingTimeInterval(3_600))))
        await model2.refreshAll()
        await waitUntilRefreshIdle(model2)
        #expect(chatGPT2.fetchCount == 1)
        #expect(model2.chatGPT.sessionPercent == 66)
    }

    @Test("429 HTML does not increase Grok restorer count")
    func grok429DoesNotTriggerRestore() async {
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer
        )
        grok.enqueue(
            .failure(AIUsageServiceError.rateLimited("Grok", retryAfter: 60))
        )
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        #expect(restorer.restoreAfterCount == 0)
        #expect(model.v2GrokRecoveryState() != .requiresUserAction)
        #expect(model.grok.errorMessage?.contains("登入已失效") != true)
        #expect(grok.cookieHeaders.count == 1)
    }

    @Test("Fresh success clears persisted backoff")
    func freshSuccessClearsBackoff() async {
        let chatGPT = CountingChatGPTUsageService()
        let defaults = isolatedDefaults()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            defaults: defaults
        )
        model.setChatGPTSessionToken("token-A")
        let accountKey = UsageIdentity.accountKey(from: "token-A")!
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 60))
        )
        await model.refreshAll()
        #expect(model.backoffUntil(provider: .chatGPT, accountKey: accountKey) != nil)

        expireBackoff(defaults: defaults, provider: .chatGPT, accountKey: accountKey)
        chatGPT.enqueue(.success(sampleChatGPT(session: 81, resetAt: Date().addingTimeInterval(3_600))))
        await model.refreshAll()
        #expect(model.chatGPT.sessionPercent == 81)
        #expect(model.backoffUntil(provider: .chatGPT, accountKey: accountKey) == nil)
        #expect(chatGPT.fetchCount == 2)
    }

    @Test("Persisted last-good restores as stale on cold launch")
    func persistThenColdLaunchRestoresStale() async throws {
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let chatGPT1 = CountingChatGPTUsageService()
        let resetAt = Date().addingTimeInterval(3_600)
        let model1 = makeModel(
            chatGPT: chatGPT1,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        model1.setChatGPTSessionToken("token-A")
        chatGPT1.enqueue(
            .success(sampleChatGPT(session: 48, resetAt: resetAt))
        )
        await model1.refreshAll()
        #expect(model1.chatGPT.sessionPercent == 48)
        #expect(model1.chatGPT.isStale == false)
        let originalAsOf = model1.v2Snapshot(for: .chatGPT)?.asOf

        let notifications = UsageNotificationManager(
            defaults: UserDefaults(suiteName: "aiusgbar.note.\(UUID().uuidString)")!
        )
        let chatGPT2 = CountingChatGPTUsageService()
        let model2 = makeModel(
            chatGPT: chatGPT2,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            notifications: notifications,
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        #expect(model2.chatGPT.isLoaded)
        #expect(model2.chatGPT.isStale)
        #expect(model2.chatGPT.sessionPercent == 48)
        #expect(model2.chatGPT.observedAt == originalAsOf)
        #expect(model2.v2Snapshot(for: .chatGPT)?.asOf == originalAsOf)
        #expect(model2.lastUpdated == nil)
        #expect(model2.chatGPT.resetText != "resets in 5 minutes")
        #expect(notifications.lastRecordedPercent(for: .chatGPT) == nil)
        #expect(notifications.hasNotified(.chatGPT) == false)
        #expect(chatGPT2.fetchCount == 0)

        chatGPT2.enqueue(
            .success(sampleChatGPT(session: 90, resetAt: Date().addingTimeInterval(3_600)))
        )
        await model2.refreshAll()
        await waitUntilRefreshIdle(model2)
        #expect(model2.chatGPT.sessionPercent == 90)
        #expect(model2.chatGPT.isStale == false)
        #expect(model2.lastUpdated != nil)
        #expect(model2.v2RestoredFromPersistence(.chatGPT) == false)
    }

    @Test("Logout then login B never shows persisted A")
    func logoutLoginBNeverShowsAccountA() async {
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let chatGPT = CountingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .success(sampleChatGPT(session: 11, resetAt: Date().addingTimeInterval(3_600)))
        )
        await model.refreshAll()
        model.setChatGPTSessionToken("")
        #expect(model.chatGPT.isLoaded == false)
        model.setChatGPTSessionToken("token-B")
        #expect(model.chatGPT.isLoaded == false)
        #expect(model.chatGPT.sessionPercent == 0)
        chatGPT.enqueue(
            .success(sampleChatGPT(session: 77, resetAt: Date().addingTimeInterval(3_600)))
        )
        await model.refreshAll()
        #expect(model.chatGPT.sessionPercent == 77)
        #expect(model.v2Snapshot(for: .chatGPT)?.accountKey == UsageIdentity.accountKey(from: "token-B"))
    }

    @Test("Cold launch without credentials does not restore last-good")
    func coldLaunchWithoutCredentialsDoesNotRestore() {
        let defaults = isolatedDefaults()
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let snapshot = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 40,
                resetText: "x",
                weeklyRemainingPercent: nil,
                weeklyResetText: nil,
                sessionResetAt: Date().addingTimeInterval(3_600)
            ),
            token: "token-A",
            asOf: Date().addingTimeInterval(-200)
        )
        lastGood.save(snapshot)
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            defaults: defaults,
            lastGoodStore: lastGood
        )
        #expect(model.chatGPT.isLoaded == false)
        #expect(model.v2Snapshot(for: .chatGPT) == nil)
    }

    @Test("Claude last-good is persisted but not restored without org pinning")
    func claudeLastGoodIsNotRestoredWithoutOrgPin() async throws {
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let claude1 = CountingClaudeUsageService()
        let model1 = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: claude1,
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        model1.setClaudeSessionKey("claude-session")
        claude1.enqueue(
            .success(
                ClaudeUsage(
                    sessionRemainingPercent: 22,
                    weeklyRemainingPercent: 33,
                    resetText: "a",
                    weeklyResetText: "b",
                    sessionResetAt: Date().addingTimeInterval(3_600),
                    weeklyResetAt: Date().addingTimeInterval(86_400)
                )
            )
        )
        await model1.refreshAll()
        let accountKey = try #require(UsageIdentity.accountKey(from: "claude-session"))
        #expect(lastGood.load(provider: .claude, accountKey: accountKey) != nil)

        let model2 = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        #expect(model2.claudeSessionKey == "claude-session")
        #expect(model2.claude.isLoaded == false)
        #expect(model2.v2Snapshot(for: .claude) == nil)
    }

    @Test("Hung Grok cookie store wait does not pin the Grok lane")
    func hungCookieStoreDoesNotPinGrokLane() async {
        let grok = CountingGrokUsageService()
        let cookies = HangingGrokCookieSource()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            cookies: cookies,
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 2,
                claude: 2,
                grok: 2,
                cookieStore: 0.05
            )
        )
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await yieldUntil { grok.fetchCount == 1 || model.grok.isLoaded || !model.isLoading }
        await waitUntilRefreshIdle(model)
        #expect(model.isLoading == false)
        #expect(grok.fetchCount == 1)
        #expect(model.grok.isLoaded)
    }

    private func makeModel(
        chatGPT: any ChatGPTUsageFetching,
        claude: any ClaudeUsageFetching,
        grok: GrokUsageFetching,
        restorer: GrokSessionRestorerSpy = GrokSessionRestorerSpy(),
        cookies: (any GrokRefreshCookieSource)? = nil,
        notifications: UsageNotificationManager? = nil,
        keychain: KeychainManager? = nil,
        defaults: UserDefaults? = nil,
        lastGoodStore: LastGoodUsageStoring? = nil,
        backoffStore: HTTPRateLimitBackoffStoring? = nil,
        deadlines: ProviderRefreshDeadlines = .production
    ) -> UsageViewModel {
        let defaults = defaults ?? isolatedDefaults()
        return UsageViewModel(
            claudeService: claude,
            chatGPTService: chatGPT,
            grokService: grok,
            grokSessionRestorer: restorer,
            grokCookieSource: cookies ?? EmptyGrokRefreshCookieSource(),
            usageNotificationManager: notifications,
            credentialStore: keychain ?? KeychainManager(inMemory: true),
            persistenceDefaults: defaults,
            lastGoodStore: lastGoodStore ?? LastGoodUsageStore(defaults: defaults),
            backoffStore: backoffStore ?? HTTPRateLimitBackoffStore(defaults: defaults),
            refreshDeadlines: deadlines,
            observesWorkspaceWake: false
        )
    }

    private func expireBackoff(
        defaults: UserDefaults,
        provider: UsageProviderID,
        accountKey: String
    ) {
        let key = HTTPRateLimitBackoffStore.storageKey
        guard let data = defaults.data(forKey: key),
              var records = try? JSONDecoder().decode(
                [String: HTTPRateLimitBackoffRecord].self,
                from: data
              ) else {
            return
        }
        let recordKey = "\(provider.rawValue).\(accountKey)"
        if var record = records[recordKey] {
            record.backoffUntil = .distantPast
            records[recordKey] = record
        }
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: key)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "aiusgbar.rel.\(UUID().uuidString)")!
    }

    private func signInAll(_ model: UsageViewModel) {
        model.setChatGPTSessionToken("chatgpt-token")
        model.setClaudeSessionKey("claude-session")
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "grok-token", cookieHeader: "sso=grok-token")
        )
    }

    private func sampleChatGPT(
        session: Int,
        resetAt: Date = Date().addingTimeInterval(3_600)
    ) -> ChatGPTUsage {
        ChatGPTUsage(
            sessionRemainingPercent: session,
            resetText: "resets in 5 minutes",
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            sessionResetAt: resetAt
        )
    }

    private func sampleClaude(session: Int = 100) -> ClaudeUsage {
        ClaudeUsage(
            sessionRemainingPercent: session,
            weeklyRemainingPercent: 100,
            resetText: "ok",
            weeklyResetText: "ok",
            sessionResetAt: Date().addingTimeInterval(3_600)
        )
    }
        GrokUsage(
            sessionRemainingPercent: session,
            resetText: "s",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: weekly,
            weeklyResetText: weekly == nil ? nil : "w",
            weeklyRelativeResetText: weekly == nil ? nil : "r",
            sessionResetAt: Date().addingTimeInterval(3_600)
        )
    }

    private func waitUntilRefreshIdle(_ model: UsageViewModel) async {
        for _ in 0..<4_000 {
            if !model.isLoading {
                return
            }
            await Task.yield()
        }
    }

    private func yieldUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<4_000 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }

    private func yieldBriefly() async {
        for _ in 0..<50 {
            await Task.yield()
        }
    }
}

@MainActor
final class HangingChatGPTUsageService: ChatGPTUsageFetching {
    private(set) var fetchCount = 0
    private var pending: [CheckedContinuation<ChatGPTUsage, Error>] = []
    private var queued: [ChatGPTUsage] = []
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted(_ count: Int) async {
        while fetchCount < count {
            await withCheckedContinuation { continuation in
                if fetchCount >= count {
                    continuation.resume()
                } else {
                    startedWaiters.append(continuation)
                }
            }
        }
    }

    func complete(_ usage: ChatGPTUsage) {
        queued.append(usage)
        flush()
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        fetchCount += 1
        let waiters = startedWaiters
        startedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if !queued.isEmpty {
            return queued.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            flush()
        }
    }

    private func flush() {
        while !queued.isEmpty, !pending.isEmpty {
            pending.removeFirst().resume(returning: queued.removeFirst())
        }
    }
}

@MainActor
final class HangingClaudeUsageService: ClaudeUsageFetching {
    private(set) var fetchCount = 0
    private var pending: [CheckedContinuation<ClaudeUsage, Error>] = []
    private var queued: [ClaudeUsage] = []
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted(_ count: Int) async {
        while fetchCount < count {
            await withCheckedContinuation { continuation in
                if fetchCount >= count {
                    continuation.resume()
                } else {
                    startedWaiters.append(continuation)
                }
            }
        }
    }

    func complete(_ usage: ClaudeUsage) {
        queued.append(usage)
        flush()
    }

    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        fetchCount += 1
        let waiters = startedWaiters
        startedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if !queued.isEmpty {
            return queued.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            flush()
        }
    }

    private func flush() {
        while !queued.isEmpty, !pending.isEmpty {
            pending.removeFirst().resume(returning: queued.removeFirst())
        }
    }
}

@MainActor
final class CountingChatGPTUsageService: ChatGPTUsageFetching {
    private var queued: [Result<ChatGPTUsage, Error>] = []
    private(set) var fetchCount = 0

    func enqueue(_ result: Result<ChatGPTUsage, Error>) {
        queued.append(result)
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        fetchCount += 1
        return try queued.removeFirst().get()
    }
}

@MainActor
final class CountingClaudeUsageService: ClaudeUsageFetching {
    private var queued: [Result<ClaudeUsage, Error>] = []
    private(set) var fetchCount = 0

    func enqueue(_ result: Result<ClaudeUsage, Error>) {
        queued.append(result)
    }

    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        fetchCount += 1
        if queued.isEmpty {
            return ClaudeUsage(
                sessionRemainingPercent: 100,
                weeklyRemainingPercent: 100,
                resetText: "ok",
                weeklyResetText: "ok",
                sessionResetAt: Date().addingTimeInterval(3_600)
            )
        }
        return try queued.removeFirst().get()
    }
}

@MainActor
final class CountingGrokUsageService: GrokUsageFetching {
    private(set) var fetchCount = 0

    func fetchUsage(
        rateLimitsCookieHeader: String,
        weeklyCookieHeader: String
    ) async throws -> GrokUsage {
        fetchCount += 1
        return GrokUsage(
            sessionRemainingPercent: 100,
            resetText: "ok",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            weeklyRelativeResetText: nil,
            sessionResetAt: Date().addingTimeInterval(3_600)
        )
    }
}

@MainActor
final class HangingGrokCookieSource: GrokRefreshCookieSource {
    func grokCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { _ in }
    }
}
