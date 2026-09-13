import AppKit
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
        #expect(info.resetText.contains(L10n.resetPrefix))
        #expect(info.staleCaption?.hasPrefix(L10n.lastUpdatedPrefix) == true)
    }

    @Test("Timeout claim invalidates the epoch so late success cannot win")
    func timeoutClaimBeatsLateSuccess() {
        var book = ProviderRefreshLaneBook()
        let epoch = book.begin(.chatGPT)
        let timeoutClaimed = book.claim(.chatGPT, epoch: epoch, success: false)
        #expect(timeoutClaimed)
        #expect(book.isCurrent(.chatGPT, epoch: epoch) == false)
        #expect(book.isInFlight(.chatGPT) == false)
        let lateSuccessClaimed = book.claim(.chatGPT, epoch: epoch, success: true)
        #expect(lateSuccessClaimed == false)
    }

    @Test("Success claim prevents a timeout from overwriting the winner")
    func successClaimBeatsTimeout() {
        var book = ProviderRefreshLaneBook()
        let epoch = book.begin(.chatGPT)
        let successClaimed = book.claim(.chatGPT, epoch: epoch, success: true)
        #expect(successClaimed)
        let timeoutClaimed = book.claim(.chatGPT, epoch: epoch, success: false)
        #expect(timeoutClaimed == false)
        #expect(book.claimedSuccess(.chatGPT, epoch: epoch))
        #expect(book.isInFlight(.chatGPT))
    }

    @Test("Abort releases lane ownership for a new identity flight")
    func abortReleasesLaneForNewIdentity() {
        var book = ProviderRefreshLaneBook()
        let first = book.begin(.chatGPT)
        let abortedEpoch = book.abort(.chatGPT)
        #expect(abortedEpoch == first)
        #expect(book.isInFlight(.chatGPT) == false)
        let second = book.begin(.chatGPT)
        #expect(second != first)
        #expect(book.isCurrent(.chatGPT, epoch: second))
    }

    @Test("Grok recovery abort leaves coordinator able to start a new recovery")
    func grokRecoveryAbortDoesNotTripCircuit() {
        var coordinator = RecoveryCoordinator()
        let scope = RecoveryScope(provider: .grok, accountKey: "acct-a")
        let began = coordinator.beginRecovery(scope: scope)
        #expect(began)
        let restored = coordinator.consumeRestoreAttempt()
        #expect(restored)
        coordinator.abortInFlightRecovery()
        #expect(coordinator.state == .healthy)
        #expect(coordinator.hasActiveScope == false)
        let beganAgain = coordinator.beginRecovery(scope: scope)
        #expect(beganAgain)
        #expect(coordinator.state == .recovering)
        #expect(coordinator.hasActiveScope)
    }

    @Test("Preserved last-good becomes stale after freshness TTL")
    func preservedLastGoodBecomesStaleAfterTTL() throws {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let loaded = UsageInfo(
            sessionPercent: 41,
            isLoaded: true,
            isStale: false,
            observedAt: observedAt
        )
        let freshFailure = try #require(
            UsageRefreshStatePolicy.state(
                afterFailure: loaded,
                error: URLError(.timedOut),
                now: observedAt.addingTimeInterval(30)
            )
        )
        #expect(freshFailure.isStale == false)
        #expect(freshFailure.observedAt == observedAt)
        #expect(freshFailure.sessionPercent == 41)

        let staleFailure = try #require(
            UsageRefreshStatePolicy.state(
                afterFailure: loaded,
                error: URLError(.timedOut),
                now: observedAt.addingTimeInterval(UsageValidityPolicy.freshnessTTL + 1)
            )
        )
        #expect(staleFailure.isStale)
        #expect(staleFailure.observedAt == observedAt)
        #expect(staleFailure.sessionPercent == 41)
        #expect(staleFailure.staleCaption?.hasPrefix(L10n.lastUpdatedPrefix) == true)
    }

    @Test("Expired secondary meter is omitted on restore while primary stays")
    func expiredSecondaryIsOmittedOnRestore() throws {
        let asOf = Date(timeIntervalSince1970: 5_000)
        let snapshot = V1UsageAdapters.grokSnapshot(
            usage: GrokUsage(
                sessionRemainingPercent: 44,
                resetText: "s",
                sessionWindowSeconds: 7200,
                weeklyRemainingPercent: 22,
                weeklyResetText: "w",
                weeklyRelativeResetText: "r",
                sessionResetAt: asOf.addingTimeInterval(3_600),
                weeklyResetAt: asOf.addingTimeInterval(86_400)
            ),
            sso: "token-A",
            asOf: asOf
        )
        let now = asOf.addingTimeInterval(90_000)
        let info = try #require(UsageInfoFromSnapshot.make(snapshot, stale: true, now: now))
        #expect(info.sessionPercent == 44)
        #expect(info.weeklyAvailable == false)
        #expect(info.isLoaded)
        #expect(GrokCardPresentation.from(info).showsWeeklyRow == false)
        #expect(GrokCardPresentation.from(info).weeklyPercent == nil)
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
        await Task.yield()
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
        #expect(model.chatGPT.errorMessage?.contains(L10n.timeout) == true)
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
        #expect(model.chatGPT.errorMessage?.contains(L10n.timeout) == true)
        #expect(model.isLoading == false)
    }

    @Test("Account switch A to B starts a new ChatGPT fetch and rejects A")
    func accountSwitchStartsFreshFetchForB() async {
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
        await chatGPT.waitUntilStarted(2)
        chatGPT.complete(sampleChatGPT(session: 77, resetAt: Date().addingTimeInterval(3_600)))
        await inFlight.value
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 77)
        #expect(model.v2Snapshot(for: .chatGPT)?.accountKey == UsageIdentity.accountKey(from: "token-B"))
        #expect(chatGPT.fetchCount == 2)
    }

    @Test("Hung A does not block B after account switch")
    func hungAccountADoesNotBlockAccountB() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 2,
                claude: 2,
                grok: 2,
                cookieStore: 0.05
            )
        )
        model.setChatGPTSessionToken("token-A")
        let hung = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(1)
        model.setChatGPTSessionToken("token-B")
        await chatGPT.waitUntilStarted(2)
        chatGPT.complete(sampleChatGPT(session: 63, resetAt: Date().addingTimeInterval(3_600)))
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 63)
        #expect(model.v2Snapshot(for: .chatGPT)?.accountKey == UsageIdentity.accountKey(from: "token-B"))
        hung.cancel()
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
        #expect(until.timeIntervalSinceNow >= 119)
        #expect(chatGPT.fetchCount == 1)
        #expect(model.chatGPT.errorMessage?.contains(L10n.sessionExpiredMarker) != true)
        #expect(model.chatGPT.errorMessage?.contains(L10n.rateLimited("ChatGPT")) == true)

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
        #expect(model.grok.errorMessage?.contains(L10n.sessionExpiredMarker) != true)
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

    @Test("Never-released ChatGPT fetch returns at the provider deadline")
    func neverReleasedServiceReturnsAtDeadline() async {
        let chatGPT = NeverReleasedChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 0.12,
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
        #expect(model.chatGPT.errorMessage?.contains(L10n.timeout) == true)
        #expect(model.chatGPT.isLoaded == false)
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(model.chatGPT.sessionPercent == 0)
        #expect(model.v2Snapshot(for: .chatGPT) == nil)
    }

    @Test("Success near the deadline is not overwritten by timeout")
    func successNearDeadlineIsNotOverwritten() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 0.4,
                claude: 2,
                grok: 2,
                cookieStore: 0.05
            )
        )
        model.setChatGPTSessionToken("token-A")
        let refresh = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(1)
        chatGPT.complete(sampleChatGPT(session: 52, resetAt: Date().addingTimeInterval(3_600)))
        await refresh.value
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 52)
        #expect(model.chatGPT.errorMessage == nil)
        #expect(model.isLoading == false)
        try? await Task.sleep(nanoseconds: 450_000_000)
        #expect(model.chatGPT.sessionPercent == 52)
        #expect(model.chatGPT.errorMessage == nil)
    }

    @Test("Rapid A-B-A switching only commits the current identity")
    func rapidAccountSwitchingOnlyCommitsCurrentIdentity() async {
        let chatGPT = HangingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService()
        )
        model.setChatGPTSessionToken("token-A")
        let first = Task { await model.refreshAll() }
        await chatGPT.waitUntilStarted(1)
        model.setChatGPTSessionToken("token-B")
        await chatGPT.waitUntilStarted(2)
        model.setChatGPTSessionToken("token-A")
        await chatGPT.waitUntilStarted(3)
        chatGPT.complete(sampleChatGPT(session: 19, resetAt: Date().addingTimeInterval(3_600)))
        await first.value
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 19)
        #expect(model.v2Snapshot(for: .chatGPT)?.accountKey == UsageIdentity.accountKey(from: "token-A"))
    }

    @Test("Grok timeout during recovery unwinds the coordinator")
    func grokTimeoutDuringRecoveryUnwindsCoordinator() async {
        let grok = ControllableGrokUsageService()
        let restorer = OnceHangingGrokRestorer()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer,
            deadlines: ProviderRefreshDeadlines(
                chatGPT: 2,
                claude: 2,
                grok: 0.15,
                cookieStore: 0.05
            )
        )
        grok.enqueue(.failure(AIUsageServiceError.wafBlocked("Grok")))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        #expect(model.v2GrokRecoveryState() != .recovering)
        #expect(model.v2GrokRecoveryHasActiveScope() == false)
        #expect(model.isLoading == false)
        #expect(model.grok.isLoaded == false)

        grok.enqueue(.failure(AIUsageServiceError.wafBlocked("Grok")))
        grok.enqueue(.success(sampleGrok(session: 61, weekly: 20)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(restorer.restoreAfterCount == 2)
        #expect(model.v2GrokRecoveryState() == .healthy)
        #expect(model.grok.sessionPercent == 61)
        #expect(model.grok.weeklyPercent == 20)
    }

    @Test("Failed refresh marks last-good stale after the freshness TTL")
    func failedRefreshMarksLastGoodStaleAfterTTL() async throws {
        let clock = TestClock()
        let chatGPT = CountingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            now: { clock.date }
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .success(sampleChatGPT(session: 41, resetAt: Date().addingTimeInterval(3_600)))
        )
        await model.refreshAll()
        let observedAt = try #require(model.chatGPT.observedAt)
        #expect(model.chatGPT.isStale == false)
        clock.advance(UsageValidityPolicy.freshnessTTL + 1)
        chatGPT.enqueue(.failure(URLError(.notConnectedToInternet)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(model.chatGPT.sessionPercent == 41)
        #expect(model.chatGPT.isStale)
        #expect(model.chatGPT.observedAt == observedAt)
        #expect(model.chatGPT.staleCaption?.hasPrefix(L10n.lastUpdatedPrefix) == true)
    }

    @Test("Expired weekly meter is omitted on ChatGPT cold restore")
    func expiredWeeklyOmittedOnChatGPTColdRestore() async throws {
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let lastGood = LastGoodUsageStore(defaults: defaults)
        let asOf = Date().addingTimeInterval(-30)
        let snapshot = V1UsageAdapters.chatGPTSnapshot(
            usage: ChatGPTUsage(
                sessionRemainingPercent: 58,
                resetText: "s",
                weeklyRemainingPercent: 12,
                weeklyResetText: "w",
                sessionResetAt: Date().addingTimeInterval(3_600),
                weeklyResetAt: Date().addingTimeInterval(-15)
            ),
            token: "token-A",
            asOf: asOf
        )
        lastGood.save(snapshot)
        keychain.save("token-A", forKey: "chatGPTSessionToken")
        keychain.save("__Secure-next-auth.session-token=token-A", forKey: "chatGPTCookieHeader")
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            keychain: keychain,
            defaults: defaults,
            lastGoodStore: lastGood
        )
        #expect(model.chatGPT.isLoaded)
        #expect(model.chatGPT.sessionPercent == 58)
        #expect(model.chatGPT.weeklyAvailable == false)
    }

    @Test("Wake observer coalesces notifications and stops after invalidate")
    func wakeObserverCoalescesAndStopsAfterInvalidate() async {
        let center = NotificationCenter()
        let grok = ControllableGrokUsageService()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            observesWorkspaceWake: true,
            wakeNotificationCenter: center,
            wakeCoalesce: 0.02
        )
        grok.enqueue(.success(sampleGrok(session: 40, weekly: nil)))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        let afterLogin = grok.cookieHeaders.count
        grok.enqueue(.success(sampleGrok(session: 41, weekly: nil)))
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)
        await waitUntilRefreshIdle(model)
        #expect(model.wakeTriggeredRefreshCount == 1)
        #expect(grok.cookieHeaders.count == afterLogin + 1)
        model.invalidateWakeObserver()
        grok.enqueue(.success(sampleGrok(session: 42, weekly: nil)))
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)
        await waitUntilRefreshIdle(model)
        #expect(model.wakeTriggeredRefreshCount == 1)
        #expect(grok.cookieHeaders.count == afterLogin + 1)
    }

    @Test("Reset boundary during backoff can still refresh after backoff expires")
    func resetBoundaryDuringBackoffCanRefreshLater() async {
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
            .success(sampleChatGPT(session: 40, resetAt: Date().addingTimeInterval(3_600)))
        )
        await model.refreshAll()
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 120))
        )
        await model.refreshAll()
        #expect(chatGPT.fetchCount == 2)
        model.expireInvalidUsage(now: Date().addingTimeInterval(10_000))
        await waitUntilRefreshIdle(model)
        #expect(chatGPT.fetchCount == 2)
        expireBackoff(defaults: defaults, provider: .chatGPT, accountKey: accountKey)
        chatGPT.enqueue(
            .success(sampleChatGPT(session: 18, resetAt: Date().addingTimeInterval(3_600)))
        )
        model.expireInvalidUsage(now: Date().addingTimeInterval(10_000))
        await waitUntilRefreshIdle(model)
        #expect(chatGPT.fetchCount == 3)
        #expect(model.chatGPT.sessionPercent == 18)
    }

    @Test("Same-account relogin during backoff does not hit HTTP")
    func sameAccountReloginDuringBackoffSurfacesStatus() async {
        let chatGPT = CountingChatGPTUsageService()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService()
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 120))
        )
        await model.refreshAll()
        #expect(chatGPT.fetchCount == 1)
        model.setChatGPTSessionToken("token-A")
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(chatGPT.fetchCount == 1)
        #expect(model.statusMessage.contains(L10n.rateLimitedPrefix("ChatGPT")))
        #expect(model.chatGPT.errorMessage?.contains(L10n.rateLimited("ChatGPT")) == true)
    }

    @Test("Rate-limited status clears after the same provider succeeds")
    func rateLimitedStatusClearsAfterSuccessfulProviderRefresh() async {
        let chatGPT = CountingChatGPTUsageService()
        let defaults = isolatedDefaults()
        var currentNow = Date()
        let model = makeModel(
            chatGPT: chatGPT,
            claude: ImmediateClaudeUsageService(),
            grok: ImmediateGrokUsageService(),
            defaults: defaults,
            now: { currentNow }
        )
        model.setChatGPTSessionToken("token-A")
        chatGPT.enqueue(
            .failure(AIUsageServiceError.rateLimited("ChatGPT", retryAfter: 1))
        )

        await model.refreshAll()
        await model.refreshAll()
        #expect(chatGPT.fetchCount == 1)
        #expect(model.statusMessage == L10n.rateLimitedRetry("ChatGPT", 60))

        currentNow = currentNow.addingTimeInterval(61)
        chatGPT.enqueue(
            .success(sampleChatGPT(session: 18, resetAt: currentNow.addingTimeInterval(3_600)))
        )
        await model.refreshAll()
        await waitUntilRefreshIdle(model)

        #expect(chatGPT.fetchCount == 2)
        #expect(model.chatGPT.isLoaded)
        #expect(model.statusMessage.isEmpty)
    }

    @Test("Weekly rate-limited Grok usage records backoff without recovery")
    func grokWeeklyRateLimitedUsageRecordsBackoff() async throws {
        let grok = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let defaults = isolatedDefaults()
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer,
            defaults: defaults
        )
        grok.enqueue(
            .success(
                GrokUsage(
                    sessionRemainingPercent: 80,
                    resetText: "s",
                    sessionWindowSeconds: 7200,
                    weeklyRemainingPercent: nil,
                    weeklyResetText: nil,
                    weeklyRelativeResetText: nil,
                    sessionResetAt: Date().addingTimeInterval(3_600),
                    weeklyRateLimited: true,
                    weeklyRateLimitRetryAfter: 120
                )
            )
        )
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await grok.waitUntilFetchStartedCount(1)
        await waitUntilRefreshIdle(model)
        let accountKey = try #require(UsageIdentity.accountKey(from: "token-A"))
        #expect(model.grok.isLoaded)
        #expect(model.grok.weeklyAvailable == false)
        #expect(restorer.restoreAfterCount == 0)
        #expect(model.v2GrokRecoveryState() != .requiresUserAction)
        let until = try #require(model.backoffUntil(provider: .grok, accountKey: accountKey))
        #expect(until.timeIntervalSinceNow >= 119)
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(grok.cookieHeaders.count == 1)
        expireBackoff(defaults: defaults, provider: .grok, accountKey: accountKey)
        grok.enqueue(.success(sampleGrok(session: 82, weekly: 30)))
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(grok.cookieHeaders.count == 2)
        #expect(model.grok.weeklyPercent == 30)
        #expect(model.backoffUntil(provider: .grok, accountKey: accountKey) == nil)
    }

    @Test("Primary 200 plus weekly 429 records Grok backoff on the production HTTP path")
    func grokWeekly429ProductionPathRecordsBackoff() async throws {
        GrokHTTPStubURLProtocol.reset()
        GrokHTTPStubURLProtocol.weeklyStatus = 429
        GrokHTTPStubURLProtocol.weeklyHeaders = [
            "Retry-After": "120",
            "Content-Type": "text/html"
        ]
        GrokHTTPStubURLProtocol.weeklyBody = Data("<html>429</html>".utf8)
        let session = GrokHTTPStubURLProtocol.makeSession()
        let grok = GrokService(session: session)
        let restorer = GrokSessionRestorerSpy()
        let defaults = isolatedDefaults()
        let keychain = KeychainManager(inMemory: true)
        let model = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: grok,
            restorer: restorer,
            keychain: keychain,
            defaults: defaults
        )
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        await waitUntilRefreshIdle(model)
        let accountKey = try #require(UsageIdentity.accountKey(from: "token-A"))
        #expect(model.grok.isLoaded)
        #expect(model.grok.weeklyAvailable == false)
        #expect(model.grok.errorMessage?.contains(L10n.sessionExpiredMarker) != true)
        #expect(restorer.restoreAfterCount == 0)
        let until = try #require(model.backoffUntil(provider: .grok, accountKey: accountKey))
        #expect(until.timeIntervalSinceNow >= 119)
        let requestsAfterFirst = GrokHTTPStubURLProtocol.requestCount()
        #expect(requestsAfterFirst >= 2)
        await model.refreshAll()
        await waitUntilRefreshIdle(model)
        #expect(GrokHTTPStubURLProtocol.requestCount() == requestsAfterFirst)

        let model2 = makeModel(
            chatGPT: ImmediateChatGPTUsageService(),
            claude: ImmediateClaudeUsageService(),
            grok: GrokService(session: session),
            restorer: GrokSessionRestorerSpy(),
            keychain: keychain,
            defaults: defaults
        )
        await model2.refreshAll()
        await waitUntilRefreshIdle(model2)
        #expect(GrokHTTPStubURLProtocol.requestCount() == requestsAfterFirst)
        #expect(model2.backoffUntil(provider: .grok, accountKey: accountKey) != nil)

        expireBackoff(defaults: defaults, provider: .grok, accountKey: accountKey)
        GrokHTTPStubURLProtocol.weeklyStatus = 404
        GrokHTTPStubURLProtocol.weeklyHeaders = ["Content-Type": "application/json"]
        GrokHTTPStubURLProtocol.weeklyBody = Data()
        await model2.refreshAll()
        await waitUntilRefreshIdle(model2)
        #expect(model2.backoffUntil(provider: .grok, accountKey: accountKey) == nil)
        #expect(model2.grok.isLoaded)
        #expect(restorer.restoreAfterCount == 0)
    }

    private func makeModel(
        chatGPT: any ChatGPTUsageFetching,
        claude: any ClaudeUsageFetching,
        grok: GrokUsageFetching,
        restorer: (any GrokSessionRestoring)? = nil,
        cookies: (any GrokRefreshCookieSource)? = nil,
        notifications: UsageNotificationManager? = nil,
        keychain: KeychainManager? = nil,
        defaults: UserDefaults? = nil,
        lastGoodStore: LastGoodUsageStoring? = nil,
        backoffStore: HTTPRateLimitBackoffStoring? = nil,
        deadlines: ProviderRefreshDeadlines = .production,
        observesWorkspaceWake: Bool = false,
        wakeNotificationCenter: NotificationCenter? = nil,
        wakeCoalesce: TimeInterval = 0,
        now: @escaping () -> Date = Date.init
    ) -> UsageViewModel {
        let defaults = defaults ?? isolatedDefaults()
        return UsageViewModel(
            claudeService: claude,
            chatGPTService: chatGPT,
            grokService: grok,
            grokSessionRestorer: restorer ?? GrokSessionRestorerSpy(),
            grokCookieSource: cookies ?? EmptyGrokRefreshCookieSource(),
            usageNotificationManager: notifications,
            credentialStore: keychain ?? KeychainManager(inMemory: true),
            persistenceDefaults: defaults,
            lastGoodStore: lastGoodStore ?? LastGoodUsageStore(defaults: defaults),
            backoffStore: backoffStore ?? HTTPRateLimitBackoffStore(defaults: defaults),
            refreshDeadlines: deadlines,
            observesWorkspaceWake: observesWorkspaceWake,
            wakeNotificationCenter: wakeNotificationCenter,
            wakeCoalesce: wakeCoalesce,
            now: now
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

    private func sampleGrok(session: Int, weekly: Int?) -> GrokUsage {
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
        await waitUntil({ !model.isLoading }, message: "refresh idle")
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: Duration = .seconds(3),
        message: String = "condition"
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for \(message)")
    }

    private func yieldUntil(_ condition: @escaping () -> Bool) async {
        await waitUntil(condition, message: "yieldUntil condition")
    }

    private func yieldBriefly() async {
        try? await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor
final class HangingChatGPTUsageService: ChatGPTUsageFetching {
    private struct Pending {
        let id: UUID
        let continuation: CheckedContinuation<ChatGPTUsage, Error>
    }

    private final class Store: @unchecked Sendable {
        let lock = NSLock()
        var pending: [Pending] = []
        var queued: [ChatGPTUsage] = []
    }

    private let store = Store()
    private(set) var fetchCount = 0
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
        store.lock.lock()
        store.queued.append(usage)
        store.lock.unlock()
        flush()
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        fetchCount += 1
        let waiters = startedWaiters
        startedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        store.lock.lock()
        if !store.queued.isEmpty {
            let usage = store.queued.removeFirst()
            store.lock.unlock()
            return usage
        }
        store.lock.unlock()
        let id = UUID()
        let store = self.store
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                store.lock.lock()
                store.pending.append(Pending(id: id, continuation: continuation))
                store.lock.unlock()
                self.flush()
            }
        } onCancel: {
            store.lock.lock()
            if let idx = store.pending.firstIndex(where: { $0.id == id }) {
                let item = store.pending.remove(at: idx)
                store.lock.unlock()
                item.continuation.resume(throwing: CancellationError())
            } else {
                store.lock.unlock()
            }
        }
    }

    private func flush() {
        store.lock.lock()
        while !store.queued.isEmpty, !store.pending.isEmpty {
            let item = store.pending.removeFirst()
            let usage = store.queued.removeFirst()
            store.lock.unlock()
            item.continuation.resume(returning: usage)
            store.lock.lock()
        }
        store.lock.unlock()
    }
}

@MainActor
final class HangingClaudeUsageService: ClaudeUsageFetching {
    private struct Pending {
        let id: UUID
        let continuation: CheckedContinuation<ClaudeUsage, Error>
    }

    private(set) var fetchCount = 0
    private var pending: [Pending] = []
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
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.append(Pending(id: id, continuation: continuation))
                flush()
            }
        } onCancel: {
            Task { @MainActor in
                if let idx = self.pending.firstIndex(where: { $0.id == id }) {
                    let item = self.pending.remove(at: idx)
                    item.continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func flush() {
        while !queued.isEmpty, !pending.isEmpty {
            pending.removeFirst().continuation.resume(returning: queued.removeFirst())
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
    private var pending: CheckedContinuation<[HTTPCookie], Never>?

    func grokCookies() async -> [HTTPCookie] {
        await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: [])
                } else {
                    pending = continuation
                }
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                guard let self, let pending = self.pending else { return }
                self.pending = nil
                pending.resume(returning: [])
            }
        })
    }
}

@MainActor
final class NeverReleasedChatGPTUsageService: ChatGPTUsageFetching {
    private(set) var fetchCount = 0
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var held: [CheckedContinuation<ChatGPTUsage, Error>] = []

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

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        fetchCount += 1
        let waiters = startedWaiters
        startedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return try await withCheckedThrowingContinuation { continuation in
            held.append(continuation)
        }
    }
}

@MainActor
final class OnceHangingGrokRestorer: GrokSessionRestoring {
    private(set) var restoreAfterCount = 0
    private var shouldHang = true
    private var pending: CheckedContinuation<GrokSessionRestoreOutcome, Never>?

    func restoreIfNeeded() async -> GrokSessionRestoreOutcome {
        .success
    }

    func restoreAfterRecoverableFailure() async -> GrokSessionRestoreOutcome {
        restoreAfterCount += 1
        if shouldHang {
            shouldHang = false
            return await withTaskCancellationHandler(operation: {
                await withCheckedContinuation { continuation in
                    if Task.isCancelled {
                        continuation.resume(returning: .cancelled)
                    } else {
                        pending = continuation
                    }
                }
            }, onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, let pending = self.pending else { return }
                    self.pending = nil
                    pending.resume(returning: .cancelled)
                }
            })
        }
        return .success
    }

    func reset() {}
}

final class TestClock: @unchecked Sendable {
    var date = Date()

    func advance(_ interval: TimeInterval) {
        date = date.addingTimeInterval(interval)
    }
}

final class GrokHTTPStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var requestPaths: [String] = []
    static var weeklyStatus = 429
    static var weeklyHeaders: [String: String] = [
        "Retry-After": "120",
        "Content-Type": "text/html"
    ]
    static var weeklyBody = Data("<html>429</html>".utf8)

    static func reset() {
        lock.lock()
        requestPaths = []
        weeklyStatus = 429
        weeklyHeaders = [
            "Retry-After": "120",
            "Content-Type": "text/html"
        ]
        weeklyBody = Data("<html>429</html>".utf8)
        lock.unlock()
    }

    static func requestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestPaths.count
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GrokHTTPStubURLProtocol.self]
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(
            configuration: configuration,
            delegate: GrokURLSessionRedirectDelegate.shared,
            delegateQueue: nil
        )
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let url = request.url?.absoluteString ?? ""
        Self.lock.lock()
        Self.requestPaths.append(url)
        let isRateLimits = url.contains("rate-limits")
        let status: Int
        let headers: [String: String]
        let body: Data
        if isRateLimits {
            status = 200
            headers = ["Content-Type": "application/json"]
            let resetAt = Date().addingTimeInterval(3_600).timeIntervalSince1970
            body = Data("""
            {"remainingQueries":80,"totalQueries":100,"windowSizeSeconds":7200,"resetAt":\(resetAt)}
            """.utf8)
        } else {
            status = Self.weeklyStatus
            headers = Self.weeklyHeaders
            body = Self.weeklyBody
        }
        Self.lock.unlock()

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
