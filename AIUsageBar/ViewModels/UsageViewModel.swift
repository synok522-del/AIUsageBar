//
//  UsageViewModel.swift
//  AIUsageBar
//
//

import Combine
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {

    private enum StorageKey {
        static let claudeSessionKey = "claudeSessionKey"
        static let chatGPTSessionToken = "chatGPTSessionToken"
        static let chatGPTCookieHeader = "chatGPTCookieHeader"
        static let grokSessionToken = "grokSessionToken"
        static let grokCookieHeader = "grokCookieHeader"

        // 舊版 key
        static let oldChatGPTSessionToken = "chatgptSessionToken"
    }


    @Published var claude = UsageInfo()
    @Published var chatGPT = UsageInfo()
    @Published var grok = UsageInfo()
    @Published var statusMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?


    @Published private(set) var claudeSessionKey: String = ""

    @Published private(set) var chatGPTSessionToken: String = ""

    @Published private(set) var grokSessionToken: String = ""

    private var chatGPTCookieHeader = ""
    private var grokCookieHeader = ""
    private var grokHTTPAuthGeneration = GrokHTTPAuthGeneration()
    private var pendingRefreshAll = false


    private let claudeService: any ClaudeUsageFetching
    private let chatGPTService: any ChatGPTUsageFetching
    private let grokService: GrokUsageFetching
    private let grokSessionRestorer: GrokSessionRestoring
    private let grokCookieSource: GrokRefreshCookieSource
    private let usageNotificationManager: UsageNotificationManager
    private var v2 = V2RuntimeState()


    private var refreshTimer: Timer?
    private var validityTimer: Timer?
    private let credentialStore: KeychainManager


    init(
        claudeService: any ClaudeUsageFetching = ClaudeService(),
        chatGPTService: any ChatGPTUsageFetching = ChatGPTService(),
        grokService: GrokUsageFetching = GrokService(),
        grokSessionRestorer: GrokSessionRestoring? = nil,
        grokCookieSource: GrokRefreshCookieSource? = nil,
        usageNotificationManager: UsageNotificationManager? = nil,
        credentialStore: KeychainManager? = nil
    ) {

        self.credentialStore = credentialStore ?? KeychainManager(inMemory: KeychainManager.isTestProcess)
        self.claudeService = claudeService
        self.chatGPTService = chatGPTService
        self.grokService = grokService
        self.grokSessionRestorer =
            grokSessionRestorer ?? GrokWebKitSessionRestorer.shared
        self.grokCookieSource =
            grokCookieSource ?? WebSessionManager.shared
        self.usageNotificationManager =
            usageNotificationManager ?? UsageNotificationManager()

        if !KeychainManager.isTestProcess { migrateToKeychain() }

        self.claudeSessionKey =
            self.credentialStore.read(
                StorageKey.claudeSessionKey
            ) ?? ""

        let savedChatGPTToken =
            self.credentialStore.read(
                StorageKey.chatGPTSessionToken
            ) ?? ""

        self.chatGPTSessionToken = savedChatGPTToken
        self.chatGPTCookieHeader =
            self.credentialStore.read(
                StorageKey.chatGPTCookieHeader
            ) ?? {
                guard !savedChatGPTToken.isEmpty else {
                    return ""
                }

                return "__Secure-next-auth.session-token=\(savedChatGPTToken)"
            }()

        let savedGrokToken =
            self.credentialStore.read(
                StorageKey.grokSessionToken
            ) ?? ""

        self.grokSessionToken = savedGrokToken
        self.grokCookieHeader =
            self.credentialStore.read(
                StorageKey.grokCookieHeader
            ) ?? {
                guard !savedGrokToken.isEmpty else {
                    return ""
                }

                return "sso=\(savedGrokToken)"
            }()

        if !KeychainManager.isTestProcess { startAutoRefresh() }
    }


    deinit {
        refreshTimer?.invalidate()
        validityTimer?.invalidate()
    }



    // MARK: - Keychain Migration

    private func migrateToKeychain() {

        let defaults = UserDefaults.standard


        // Claude

        if self.credentialStore.read(
            StorageKey.claudeSessionKey
        ) == nil {

            if let oldValue = defaults.string(
                forKey: StorageKey.claudeSessionKey
            ) {

                self.credentialStore.save(
                    oldValue,
                    forKey: StorageKey.claudeSessionKey
                )

                defaults.removeObject(
                    forKey: StorageKey.claudeSessionKey
                )
            }
        }


        // ChatGPT 新 key

        if self.credentialStore.read(
            StorageKey.chatGPTSessionToken
        ) == nil {


            let newValue =
            defaults.string(
                forKey: StorageKey.chatGPTSessionToken
            )


            let oldValue =
            defaults.string(
                forKey: StorageKey.oldChatGPTSessionToken
            )


            if let token = newValue ?? oldValue {

                self.credentialStore.save(
                    token,
                    forKey: StorageKey.chatGPTSessionToken
                )


                defaults.removeObject(
                    forKey: StorageKey.chatGPTSessionToken
                )

                defaults.removeObject(
                    forKey: StorageKey.oldChatGPTSessionToken
                )
            }
        }
    }



    // MARK: - Login / Logout

    func setClaudeSessionKey(_ value: String) {
        let identityChanged = claudeSessionKey != value
        if identityChanged {
            claude = UsageInfo()
            usageNotificationManager.resetTracking(for: .claude)
            v2.invalidateProvider(
                .claude,
                accountKey: UsageIdentity.accountKey(from: claudeSessionKey)
            )
        }

        claudeSessionKey = value

        if value.isEmpty {

            self.credentialStore.delete(
                StorageKey.claudeSessionKey
            )

        } else {

            self.credentialStore.save(
                value,
                forKey: StorageKey.claudeSessionKey
            )
        }
    }



    func setChatGPTSessionToken(_ value: String) {

        setChatGPTCredential(
            WebCredential(
                cookieName: "__Secure-next-auth.session-token",
                value: value,
                cookieHeader: "__Secure-next-auth.session-token=\(value)"
            )
        )
    }

    func setChatGPTCredential(_ credential: WebCredential) {
        let identityChanged =
            chatGPTSessionToken != credential.value
            || chatGPTCookieHeader != credential.cookieHeader
        if identityChanged {
            chatGPT = UsageInfo()
            usageNotificationManager.resetTracking(for: .chatGPT)
            v2.invalidateProvider(
                .chatGPT,
                accountKey: UsageIdentity.accountKey(from: chatGPTSessionToken)
            )
        }

        chatGPTSessionToken = credential.value
        chatGPTCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {

            self.credentialStore.delete(
                StorageKey.chatGPTSessionToken
            )
            self.credentialStore.delete(
                StorageKey.chatGPTCookieHeader
            )

        } else {

            self.credentialStore.save(
                credential.value,
                forKey: StorageKey.chatGPTSessionToken
            )
            self.credentialStore.save(
                credential.cookieHeader,
                forKey: StorageKey.chatGPTCookieHeader
            )
        }
    }

    func setGrokSessionToken(_ value: String) {

        setGrokCredential(
            WebCredential(
                cookieName: "sso",
                value: value,
                cookieHeader: "sso=\(value)"
            )
        )
    }

    var grokHTTPAuthGenerationValue: UInt {
        grokHTTPAuthGeneration.value
    }

    func setGrokCredential(_ credential: WebCredential) {
        let previousToken = grokSessionToken
        let previousHeader = grokCookieHeader
        let identityChanged =
            previousToken != credential.value || previousHeader != credential.cookieHeader

        if !identityChanged {
            return
        }

        grokHTTPAuthGeneration.invalidate()
        v2.invalidateProvider(
            .grok,
            accountKey: UsageIdentity.accountKey(from: previousToken)
        )

        grokSessionToken = credential.value
        grokCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {
            grok = UsageInfo()

            self.credentialStore.delete(
                StorageKey.grokSessionToken
            )
            self.credentialStore.delete(
                StorageKey.grokCookieHeader
            )
            grokSessionRestorer.reset()
            usageNotificationManager.resetTracking(for: .grok)
        } else {
            self.credentialStore.save(
                credential.value,
                forKey: StorageKey.grokSessionToken
            )
            self.credentialStore.save(
                credential.cookieHeader,
                forKey: StorageKey.grokCookieHeader
            )

            grok = UsageInfo()
            grokSessionRestorer.reset()
            usageNotificationManager.resetTracking(for: .grok)
            requestRefreshAll()
        }
    }



    // MARK: - Refresh

    func refreshAll() async {
        if isLoading {
            pendingRefreshAll = true
            return
        }

        isLoading = true
        while true {
            pendingRefreshAll = false
            await performRefreshCycle()
            if pendingRefreshAll {
                continue
            }
            isLoading = false
            if pendingRefreshAll {
                isLoading = true
                continue
            }
            break
        }
    }

    private func requestRefreshAll() {
        if isLoading {
            pendingRefreshAll = true
            return
        }
        Task { await refreshAll() }
    }

    private func performRefreshCycle() async {
        expireInvalidUsage()


        async let claudeRefresh: Bool =
            refreshClaude()


        async let chatGPTRefresh: Bool =
            refreshChatGPT()

        // Keep Grok cookie-store access on this MainActor task. `async let`
        // would still hop to MainActor for refreshGrok, but the WebKit
        // default-store first-touch must not start on a child executor.
        let grokSucceeded = await refreshGrok()


        let (claudeSucceeded, chatGPTSucceeded) = await (
            claudeRefresh,
            chatGPTRefresh
        )

        usageNotificationManager.evaluate(
            claude: claude,
            chatGPT: chatGPT,
            grok: grok,
            snapshots: v2.lastSnapshots
        )


        if UsageRefreshStatePolicy.shouldUpdateLastUpdated(
            claudeSucceeded: claudeSucceeded,
            chatGPTSucceeded: chatGPTSucceeded,
            grokSucceeded: grokSucceeded
        ) {
            lastUpdated = Date()
        }
    }



    // MARK: - Auto Refresh

    private func startAutoRefresh() {

        refreshTimer?.invalidate()


        validityTimer?.invalidate()
        validityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.expireInvalidUsage() }
        }
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 600,
            repeats: true
        ) { [weak self] _ in


            guard let self else {
                return
            }


            Task {
                await self.refreshAll()
            }

        }
    }



    // MARK: - Claude

    private func refreshClaude() async -> Bool {

        let key =
        claudeSessionKey
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !key.isEmpty else {

            claude = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }

        let captured = v2.claudeRecovery.generation
        v2.noteFetch(.claude)
        let source = ClaudeProductionUsageSource(
            service: claudeService,
            sessionKey: key
        )

        do {
            let snapshot = try await source.fetchSnapshot()
            guard v2.claudeRecovery.shouldCommit(captured: captured) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            guard v2.commit(snapshot) else { throw AIUsageServiceError.invalidPayload("Claude") }
            applyClaude(usage)
            return true
        } catch {
            guard v2.claudeRecovery.shouldCommit(captured: captured) else {
                return false
            }
            if let nextState = UsageRefreshStatePolicy.state(
                afterFailure: claude,
                error: error
            ) {
                claude = nextState
                let message = nextState.errorMessage ?? "更新失敗"
                statusMessage = "Claude：\(message)"
            }

            return false
        }
    }



    // MARK: - ChatGPT

    private func refreshChatGPT() async -> Bool {

        let token =
        chatGPTSessionToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !token.isEmpty else {

            chatGPT = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }

        let captured = v2.chatGPTRecovery.generation
        v2.noteFetch(.chatGPT)
        let source = ChatGPTProductionUsageSource(
            service: chatGPTService,
            cookieHeader: chatGPTCookieHeader.isEmpty
                ? "__Secure-next-auth.session-token=\(token)"
                : chatGPTCookieHeader,
            accountCredential: token
        )

        do {
            let snapshot = try await source.fetchSnapshot()
            guard v2.chatGPTRecovery.shouldCommit(captured: captured) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            guard v2.commit(snapshot) else { throw AIUsageServiceError.invalidPayload("ChatGPT") }
            applyChatGPT(usage)
            return true
        } catch {
            guard v2.chatGPTRecovery.shouldCommit(captured: captured) else {
                return false
            }
            if let nextState = UsageRefreshStatePolicy.state(
                afterFailure: chatGPT,
                error: error
            ) {
                chatGPT = nextState
                let message = nextState.errorMessage ?? "更新失敗"
                statusMessage = "ChatGPT：\(message)"
            }

            return false
        }
    }



    // MARK: - Grok

    private func refreshGrok() async -> Bool {

        let token =
        grokSessionToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !token.isEmpty else {

            grok = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }


        let fallbackHeader = grokCookieHeader.isEmpty
            ? "sso=\(token)"
            : grokCookieHeader
        let authGeneration = grokHTTPAuthGeneration.value

        return await fetchGrokUsage(
            fallbackHeader: fallbackHeader,
            allowRecovery: true,
            authGeneration: authGeneration
        )
    }

    private func fetchGrokUsage(
        fallbackHeader: String,
        allowRecovery: Bool,
        authGeneration: UInt
    ) async -> Bool {
        let recoveryLatched = v2.grokRecovery.state == .requiresUserAction
        guard GrokHTTPRefreshAuthPolicy.shouldCommit(
            captured: authGeneration,
            current: grokHTTPAuthGeneration.value
        ) else {
            return false
        }

        let webKitCookies = await grokCookieSource.grokCookies()
        guard GrokHTTPRefreshAuthPolicy.shouldCommit(
            captured: authGeneration,
            current: grokHTTPAuthGeneration.value
        ) else {
            return false
        }

        let rateLimitsCookieHeader = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: webKitCookies,
            fallbackHeader: fallbackHeader,
            url: GrokSessionContext.rateLimitsURL
        )
        let weeklyCookieHeader = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: webKitCookies,
            fallbackHeader: fallbackHeader,
            url: GrokSessionContext.weeklyCreditsURL
        )
        let accountCredential = grokSessionToken
        let expectedAccountKey = UsageIdentity.accountKey(from: accountCredential)
        guard GrokService.ssoToken(from: rateLimitsCookieHeader) == accountCredential,
              GrokService.ssoToken(from: weeklyCookieHeader) == accountCredential else {
            v2.grokRecovery.markRequiresUserAction()
            grok = UsageInfo(errorMessage: "Grok 登入已失效，請重新登入")
            return false
        }
        let source = GrokProductionUsageSource(
            service: grokService,
            rateLimitsCookieHeader: rateLimitsCookieHeader,
            weeklyCookieHeader: weeklyCookieHeader,
            accountCredential: accountCredential
        )
        v2.noteFetch(.grok)

        do {
            let snapshot = try await source.fetchSnapshot()
            guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value
            ) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            if v2.grokRecovery.state == .recovering {
                let recovered = GrokV2RecoveryGate.isRecovered(
                    snapshot: snapshot,
                    expectedAccountKey: expectedAccountKey,
                    cookiePresent: true,
                    webKitReady: true
                )
                if !recovered {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(
                        AIUsageServiceError.invalidPayload("Grok recovery identity"),
                        authGeneration: authGeneration
                    )
                    return false
                }
                v2.grokRecovery.markSuccess()
            }

            try Task.checkCancellation()
            guard v2.commit(snapshot) else { throw AIUsageServiceError.invalidPayload("Grok") }
            applyGrok(usage)
            return true
        } catch {
            guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value
            ) else {
                return false
            }

            if recoveryLatched {
                applyGrokFailure(error, authGeneration: authGeneration)
                return false
            }

            if Task.isCancelled { return false }
            if GrokHTTPRefreshAuthPolicy.shouldAttemptRecovery(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value,
                didAlreadyRetry: !allowRecovery,
                error: error
            ) {
                let scope = RecoveryScope(
                    provider: .grok,
                    accountKey: expectedAccountKey ?? ""
                )
                guard v2.grokRecovery.beginRecovery(scope: scope) else {
                    applyGrokFailure(error, authGeneration: authGeneration)
                    return false
                }
                guard v2.grokRecovery.consumeRestoreAttempt() else {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(error, authGeneration: authGeneration)
                    return false
                }

                _ = await grokSessionRestorer.restoreAfterRecoverableFailure()
                guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                    captured: authGeneration,
                    current: grokHTTPAuthGeneration.value
                ) else {
                    return false
                }
                guard v2.grokRecovery.consumeRetryFetch() else {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(error, authGeneration: authGeneration)
                    return false
                }
                return await fetchGrokUsage(
                    fallbackHeader: fallbackHeader,
                    allowRecovery: false,
                    authGeneration: authGeneration
                )
            }

            if v2.grokRecovery.state == .recovering {
                v2.grokRecovery.markRequiresUserAction()
            }

            applyGrokFailure(error, authGeneration: authGeneration)
            return false
        }
    }

    private func applyClaude(_ usage: ClaudeUsage) {
        claude = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent,
            weeklyAvailable: true,
            resetText: usage.resetText,
            weeklyResetText: usage.weeklyResetText,
            isLoaded: true,
            errorMessage: nil
        )
        clearStatusMessage(for: "Claude")
    }

    private func applyChatGPT(_ usage: ChatGPTUsage) {
        chatGPT = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent ?? 0,
            weeklyAvailable: usage.weeklyRemainingPercent != nil,
            resetText: usage.resetText,
            weeklyResetText: usage.weeklyResetText ?? "",
            isLoaded: true,
            errorMessage: nil
        )
        clearStatusMessage(for: "ChatGPT")
    }

    private func applyGrok(_ usage: GrokUsage) {
        grok = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent ?? 0,
            weeklyAvailable: usage.weeklyRemainingPercent != nil,
            resetText: usage.weeklyRemainingPercent != nil
                ? (usage.weeklyRelativeResetText ?? "")
                : usage.resetText,
            weeklyResetText: usage.weeklyResetText ?? "",
            sessionWindowSeconds: usage.sessionWindowSeconds,
            isLoaded: true,
            errorMessage: nil
        )
        clearStatusMessage(for: "Grok")
    }

    private func applyGrokFailure(_ error: Error, authGeneration: UInt) {
        guard GrokHTTPRefreshAuthPolicy.shouldCommit(
            captured: authGeneration,
            current: grokHTTPAuthGeneration.value
        ) else {
            return
        }
        if let nextState = UsageRefreshStatePolicy.state(
            afterFailure: grok,
            error: error
        ) {
            grok = nextState
            let message = nextState.errorMessage ?? "更新失敗"
            statusMessage = "Grok：\(message)"
        }
    }

    func v2Snapshot(for provider: UsageProviderID) -> UsageSnapshot? {
        v2.lastSnapshots[provider]
    }

    func v2PathInvocationCount() -> Int {
        v2.pathInvocations
    }

    func v2FetchInvocationCount(for provider: UsageProviderID) -> Int {
        v2.fetchInvocations[provider] ?? 0
    }

    func v2GrokRecoveryState() -> RecoveryState {
        v2.grokRecovery.state
    }

    func v2GrokRestoresUsed() -> Int {
        v2.grokRecovery.restoresUsed
    }

    func v2GrokRetriesUsed() -> Int {
        v2.grokRecovery.retriesUsed
    }

    func v2LastNotifiedMeterId(for provider: UsageProviderID) -> String? {
        usageNotificationManager.lastNotifiedMeterID(for: provider)
    }

    func v2PrimaryMeterValidity(for provider: UsageProviderID, now: Date) -> UsageValidity? {
        guard let snapshot = v2.lastSnapshots[provider] else {
            return nil
        }
        return snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey)
    }

    func expireInvalidUsage(now: Date = Date()) {
        for (provider, snapshot) in v2.lastSnapshots {
            let validity = snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey)
            guard validity == .expired || validity == .invalid else { continue }
            let info = UsageInfo(errorMessage: "更新失敗")
            switch provider {
            case .chatGPT: if chatGPT.isLoaded { chatGPT = info }
            case .claude: if claude.isLoaded { claude = info }
            case .grok: if grok.isLoaded { grok = info }
            default: break
            }
        }
    }

    private func clearStatusMessage(for provider: String) {
        guard UsageRefreshStatePolicy.shouldClearStatusMessage(
            statusMessage,
            for: provider
        ) else {
            return
        }

        statusMessage = ""
    }
}
