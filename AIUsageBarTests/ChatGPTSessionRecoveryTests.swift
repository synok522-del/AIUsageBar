import Foundation
import Testing
@testable import AIUsageBar

struct ChatGPTSessionRecoveryTests {
    @Test("401 and missing access token are recoverable ChatGPT session failures")
    func chatGPTRecoverableFailuresAreBounded() {
        let unauthorized = AIUsageServiceError.httpStatus("ChatGPT", 401)
        #expect(ChatGPTSessionRecoveryPolicy.isRecoverableSessionFailure(unauthorized))
        #expect(
            ChatGPTSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: unauthorized
            )
        )
        #expect(
            ChatGPTSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: true,
                error: unauthorized
            ) == false
        )
        #expect(
            ChatGPTSessionRecoveryPolicy.isRecoverableSessionFailure(
                AIUsageServiceError.missingValue("無法取得 ChatGPT Access Token")
            )
        )
        #expect(
            ChatGPTSessionRecoveryPolicy.isRecoverableSessionFailure(
                AIUsageServiceError.invalidPayload("ChatGPT")
            ) == false
        )
        #expect(
            ChatGPTSessionRecoveryPolicy.presentationErrorAfterExhaustedRecovery(unauthorized)
                .localizedDescription == "ChatGPT 登入已失效，請重新登入"
        )
    }

    @Test("ChatGPT WebKit cookies assemble next-auth header and ignore other hosts")
    func chatGPTCookieHeaderUsesChatGPTHostOnly() throws {
        let session = try #require(
            HTTPCookie(properties: [
                .domain: "chatgpt.com",
                .path: "/",
                .name: "__Secure-next-auth.session-token",
                .value: "live-session"
            ])
        )
        let other = try #require(
            HTTPCookie(properties: [
                .domain: "grok.com",
                .path: "/",
                .name: "__Secure-next-auth.session-token",
                .value: "grok-session"
            ])
        )
        let header = try #require(
            ChatGPTSessionContext.cookieHeader(from: [session, other])
        )
        #expect(header.contains("live-session"))
        #expect(!header.contains("grok-session"))
        #expect(
            ChatGPTSessionContext.cookieHeaderForRequest(
                webKitCookies: [],
                fallbackHeader: "__Secure-next-auth.session-token=fallback"
            ) == "__Secure-next-auth.session-token=fallback"
        )
    }

    @Test("17F-018 healthy ChatGPT refresh does not restore")
    @MainActor
    func chatGPTHealthyRefreshDoesNotRestore() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        service.enqueue(.success(chatGPTUsage(session: 55, weekly: 80)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        #expect(restorer.restoreAfterCount == 0)
        #expect(service.cookieHeaders.count == 1)
        #expect(service.cookieHeaders[0].contains("session-A"))
        #expect(model.chatGPT.isLoaded)
        #expect(model.chatGPT.sessionPercent == 55)
        #expect(model.chatGPT.weeklyPercent == 80)
        #expect(model.chatGPT.weeklyAvailable)
        #expect(!model.chatGPTSessionRequiresRelogin)

        service.enqueue(.success(chatGPTUsage(session: 55, weekly: 80)))
        await model.refreshAll()
        await waitUntilChatGPTRefreshIdle(model)
        #expect(restorer.restoreAfterCount == 0)
        #expect(service.cookieHeaders.count == 2)
    }

    @Test("17F-018 expired session restores once with fresh cookies")
    @MainActor
    func chatGPTExpiredSessionRestoresOnceWithFreshCookies() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        cookies.applyUsableSession(token: "stale-session")
        restorer.onRestoreAfter = {
            cookies.applyUsableSession(token: "fresh-session")
        }
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        service.enqueue(.success(chatGPTUsage(session: 40, weekly: 70)))
        loginChatGPT(model, cookies: cookies, token: "stale-session")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        #expect(restorer.restoreAfterCount == 1)
        #expect(service.cookieHeaders.count == 2)
        #expect(service.cookieHeaders[0].contains("stale-session"))
        #expect(service.cookieHeaders[1].contains("fresh-session"))
        #expect(!service.cookieHeaders[1].contains("stale-session"))
        #expect(model.chatGPT.isLoaded)
        #expect(model.chatGPT.sessionPercent == 40)
        #expect(!model.chatGPTSessionRequiresRelogin)
    }

    @Test("17F-018 restore success with retry still unauthorized does not loop")
    @MainActor
    func chatGPTRestoreSuccessStillUnauthorizedDoesNotLoop() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        #expect(restorer.restoreAfterCount == 1)
        #expect(service.cookieHeaders.count == 2)
        #expect(model.chatGPT.errorMessage == "ChatGPT 登入已失效，請重新登入")
        #expect(model.chatGPTSessionRequiresRelogin)
        #expect(model.chatGPTSessionToken == "session-A")
        #expect(model.statusMessage.contains("登入已失效"))
    }

    @Test("17F-018 restore failure skips retry and requires re-login")
    @MainActor
    func chatGPTRestoreFailureSkipsRetry() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        restorer.restoreAfterOutcome = .failure
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        #expect(restorer.restoreAfterCount == 1)
        #expect(service.cookieHeaders.count == 1)
        #expect(model.chatGPTSessionRequiresRelogin)
        #expect(model.chatGPT.errorMessage == "ChatGPT 登入已失效，請重新登入")
    }

    @Test("17F-018 logout during recovery does not commit stale usage")
    @MainActor
    func chatGPTLogoutDuringRecoveryDoesNotCommit() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        restorer.shouldHoldRestoreAfter = true
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        service.enqueue(.success(chatGPTUsage(session: 55, weekly: 80)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        let inFlight = Task { await model.refreshAll() }
        await service.waitUntilFetchStartedCount(2)
        while restorer.restoreAfterCount == 0 {
            await Task.yield()
        }

        cookies.clear()
        model.setChatGPTSessionToken("")
        restorer.releaseRestoreAfter()
        await inFlight.value
        await waitUntilChatGPTRefreshIdle(model)

        #expect(model.chatGPTSessionToken.isEmpty)
        #expect(model.chatGPT.sessionPercent == 55)
        #expect(model.chatGPT.isLoaded)
        #expect(service.cookieHeaders.count == 2)
    }

    @Test("17F-018 account replacement during recovery does not commit old usage")
    @MainActor
    func chatGPTAccountReplacementDuringRecoveryDoesNotCommitOldUsage() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        restorer.shouldHoldRestoreAfter = true
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        while restorer.restoreAfterCount == 0 {
            await Task.yield()
        }

        service.enqueue(.success(chatGPTUsage(session: 88, weekly: 12)))
        loginChatGPT(model, cookies: cookies, token: "session-B")
        restorer.releaseRestoreAfter()
        await waitUntilChatGPTRefreshIdle(model)

        #expect(model.chatGPT.sessionPercent == 88)
        #expect(model.chatGPT.weeklyPercent == 12)
        #expect(service.fetchCount(containing: "session-A") == 1)
        #expect(service.fetchCount(containing: "session-B") == 1)
        #expect(!model.chatGPTSessionRequiresRelogin)
    }

    @Test("17F-018 identical ChatGPT credential does not invalidate in-flight refresh")
    @MainActor
    func chatGPTIdenticalCredentialDoesNotInvalidateInFlightRefresh() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        let credential = WebCredential(
            cookieName: "__Secure-next-auth.session-token",
            value: "session-A",
            cookieHeader: "__Secure-next-auth.session-token=session-A"
        )
        service.enqueue(.success(chatGPTUsage(session: 55, weekly: 80)))
        cookies.applyUsableSession(token: "session-A")
        model.setChatGPTCredential(credential)
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        let inFlight = Task { await model.refreshAll() }
        await service.waitUntilFetchStartedCount(2)
        let generation = model.chatGPTHTTPAuthGenerationValue
        let resets = restorer.resetCount
        let fetches = service.cookieHeaders.count

        model.setChatGPTCredential(credential)
        #expect(model.chatGPTHTTPAuthGenerationValue == generation)
        #expect(restorer.resetCount == resets)
        #expect(service.cookieHeaders.count == fetches)
        #expect(service.pending.count == 1)

        service.completeNext(chatGPTUsage(session: 55, weekly: 80))
        await inFlight.value
        #expect(model.chatGPT.weeklyPercent == 80)
        #expect(service.pending.isEmpty)
    }

    @Test("17F-018 last-known ChatGPT usage is preserved after exhausted recovery")
    @MainActor
    func chatGPTLastKnownUsagePreservedAfterExhaustedRecovery() async throws {
        let service = ControllableChatGPTUsageService()
        let restorer = ChatGPTSessionRestorerSpy()
        let cookies = MutableChatGPTRefreshCookieSource()
        let model = chatGPTLifecycleModel(
            service: service,
            restorer: restorer,
            cookies: cookies
        )
        service.enqueue(.success(chatGPTUsage(session: 55, weekly: 80)))
        loginChatGPT(model, cookies: cookies, token: "session-A")
        await service.waitUntilFetchStartedCount(1)
        await waitUntilChatGPTRefreshIdle(model)

        restorer.restoreAfterOutcome = .failure
        service.enqueue(.failure(AIUsageServiceError.httpStatus("ChatGPT", 401)))
        await model.refreshAll()
        await waitUntilChatGPTRefreshIdle(model)

        #expect(model.chatGPT.isLoaded)
        #expect(model.chatGPT.sessionPercent == 55)
        #expect(model.chatGPT.weeklyPercent == 80)
        #expect(model.chatGPT.weeklyAvailable)
        #expect(model.chatGPT.errorMessage == "ChatGPT 登入已失效，請重新登入")
        #expect(model.chatGPTSessionRequiresRelogin)
        #expect(model.chatGPTSessionToken == "session-A")
        #expect(service.cookieHeaders.count == 2)
        #expect(restorer.restoreAfterCount == 1)
    }

    @MainActor
    private func chatGPTLifecycleModel(
        service: ControllableChatGPTUsageService,
        restorer: ChatGPTSessionRestorerSpy,
        cookies: MutableChatGPTRefreshCookieSource
    ) -> UsageViewModel {
        let grokService = ControllableGrokUsageService()
        let grokRestorer = GrokSessionRestorerSpy()
        let model = UsageViewModel(
            chatGPTService: service,
            chatGPTSessionRestorer: restorer,
            chatGPTCookieSource: cookies,
            grokService: grokService,
            grokSessionRestorer: grokRestorer,
            grokCookieSource: EmptyGrokRefreshCookieSource()
        )
        if !model.chatGPTSessionToken.isEmpty {
            cookies.clear()
            model.setChatGPTSessionToken("")
        }
        if !model.grokSessionToken.isEmpty {
            model.setGrokSessionToken("")
        }
        return model
    }

    @MainActor
    private func loginChatGPT(
        _ model: UsageViewModel,
        cookies: MutableChatGPTRefreshCookieSource,
        token: String
    ) {
        cookies.applyUsableSession(token: token)
        model.setChatGPTCredential(
            WebCredential(
                cookieName: "__Secure-next-auth.session-token",
                value: token,
                cookieHeader: "__Secure-next-auth.session-token=\(token)"
            )
        )
    }

    private func chatGPTUsage(session: Int, weekly: Int?) -> ChatGPTUsage {
        ChatGPTUsage(
            sessionRemainingPercent: session,
            resetText: "5 小時後重置",
            weeklyRemainingPercent: weekly,
            weeklyResetText: weekly == nil ? nil : "每週重置"
        )
    }

    @MainActor
    private func waitUntilChatGPTRefreshIdle(_ model: UsageViewModel) async {
        for _ in 0..<200 where !model.isLoading {
            await Task.yield()
        }
        while model.isLoading {
            await Task.yield()
        }
    }
}

@MainActor
final class MutableChatGPTRefreshCookieSource: ChatGPTRefreshCookieSource {
    var cookies: [HTTPCookie] = []

    func chatGPTCookies() async -> [HTTPCookie] {
        cookies
    }

    func applyUsableSession(token: String) {
        cookies = [
            HTTPCookie(properties: [
                .domain: "chatgpt.com",
                .path: "/",
                .name: "__Secure-next-auth.session-token",
                .value: token
            ])
        ].compactMap { $0 }
    }

    func clear() {
        cookies = []
    }
}

@MainActor
final class ChatGPTSessionRestorerSpy: ChatGPTSessionRestoring {
    private(set) var resetCount = 0
    private(set) var restoreAfterCount = 0
    var restoreAfterOutcome: ChatGPTSessionRestoreOutcome = .success
    var shouldHoldRestoreAfter = false
    var onRestoreAfter: (() -> Void)?
    private var restoreAfterHold: CheckedContinuation<Void, Never>?

    func restoreAfterRecoverableFailure() async -> ChatGPTSessionRestoreOutcome {
        restoreAfterCount += 1
        if shouldHoldRestoreAfter {
            await withCheckedContinuation { continuation in
                restoreAfterHold = continuation
            }
        }
        onRestoreAfter?()
        return restoreAfterOutcome
    }

    func releaseRestoreAfter() {
        restoreAfterHold?.resume()
        restoreAfterHold = nil
    }

    func reset() {
        resetCount += 1
    }
}

final class ControllableChatGPTUsageService: ChatGPTUsageFetching, @unchecked Sendable {
    struct Pending {
        let cookieHeader: String
        let continuation: CheckedContinuation<ChatGPTUsage, Error>
    }

    private let lock = NSLock()
    private var queued: [Result<ChatGPTUsage, Error>] = []
    private var startedCount = 0
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var pending: [Pending] = []
    private(set) var cookieHeaders: [String] = []

    func enqueue(_ result: Result<ChatGPTUsage, Error>) {
        queued.append(result)
    }

    func waitUntilFetchStartedCount(_ count: Int) async {
        while true {
            if noteIfStarted(count) {
                return
            }
            await withCheckedContinuation { continuation in
                lock.lock()
                if startedCount >= count {
                    lock.unlock()
                    continuation.resume()
                } else {
                    startedWaiters.append(continuation)
                    lock.unlock()
                }
            }
        }
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        cookieHeaders.append(cookieHeader)
        noteFetchStarted()
        if !queued.isEmpty {
            return try queued.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(
                Pending(cookieHeader: cookieHeader, continuation: continuation)
            )
        }
    }

    func completeNext(_ usage: ChatGPTUsage) {
        let item = pending.removeFirst()
        item.continuation.resume(returning: usage)
    }

    func fetchCount(containing token: String) -> Int {
        cookieHeaders.filter { $0.contains(token) }.count
    }

    private func noteIfStarted(_ count: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return startedCount >= count
    }

    private func noteFetchStarted() {
        lock.lock()
        startedCount += 1
        let waiters = startedWaiters
        startedWaiters.removeAll()
        lock.unlock()
        waiters.forEach { $0.resume() }
    }
}
