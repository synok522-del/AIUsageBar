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


    private let claudeService: ClaudeService
    private let chatGPTService: ChatGPTService
    private let grokService: GrokUsageFetching
    private let grokSessionRestorer: GrokSessionRestoring
    private let grokCookieSource: GrokRefreshCookieSource
    private let usageNotificationManager: UsageNotificationManager


    private var refreshTimer: Timer?


    init(
        claudeService: ClaudeService = ClaudeService(),
        chatGPTService: ChatGPTService = ChatGPTService(),
        grokService: GrokUsageFetching = GrokService(),
        grokSessionRestorer: GrokSessionRestoring? = nil,
        grokCookieSource: GrokRefreshCookieSource? = nil,
        usageNotificationManager: UsageNotificationManager? = nil
    ) {

        self.claudeService = claudeService
        self.chatGPTService = chatGPTService
        self.grokService = grokService
        self.grokSessionRestorer =
            grokSessionRestorer ?? GrokWebKitSessionRestorer.shared
        self.grokCookieSource =
            grokCookieSource ?? WebSessionManager.shared
        self.usageNotificationManager =
            usageNotificationManager ?? UsageNotificationManager()

        migrateToKeychain()

        self.claudeSessionKey =
            KeychainManager.shared.read(
                StorageKey.claudeSessionKey
            ) ?? ""

        let savedChatGPTToken =
            KeychainManager.shared.read(
                StorageKey.chatGPTSessionToken
            ) ?? ""

        self.chatGPTSessionToken = savedChatGPTToken
        self.chatGPTCookieHeader =
            KeychainManager.shared.read(
                StorageKey.chatGPTCookieHeader
            ) ?? {
                guard !savedChatGPTToken.isEmpty else {
                    return ""
                }

                return "__Secure-next-auth.session-token=\(savedChatGPTToken)"
            }()

        let savedGrokToken =
            KeychainManager.shared.read(
                StorageKey.grokSessionToken
            ) ?? ""

        self.grokSessionToken = savedGrokToken
        self.grokCookieHeader =
            KeychainManager.shared.read(
                StorageKey.grokCookieHeader
            ) ?? {
                guard !savedGrokToken.isEmpty else {
                    return ""
                }

                return "sso=\(savedGrokToken)"
            }()

        startAutoRefresh()
    }


    deinit {
        refreshTimer?.invalidate()
    }



    // MARK: - Keychain Migration

    private func migrateToKeychain() {

        let defaults = UserDefaults.standard


        // Claude

        if KeychainManager.shared.read(
            StorageKey.claudeSessionKey
        ) == nil {

            if let oldValue = defaults.string(
                forKey: StorageKey.claudeSessionKey
            ) {

                KeychainManager.shared.save(
                    oldValue,
                    forKey: StorageKey.claudeSessionKey
                )

                defaults.removeObject(
                    forKey: StorageKey.claudeSessionKey
                )
            }
        }


        // ChatGPT 新 key

        if KeychainManager.shared.read(
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

                KeychainManager.shared.save(
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

        claudeSessionKey = value

        if value.isEmpty {

            KeychainManager.shared.delete(
                StorageKey.claudeSessionKey
            )

        } else {

            KeychainManager.shared.save(
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

        chatGPTSessionToken = credential.value
        chatGPTCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {

            KeychainManager.shared.delete(
                StorageKey.chatGPTSessionToken
            )
            KeychainManager.shared.delete(
                StorageKey.chatGPTCookieHeader
            )

        } else {

            KeychainManager.shared.save(
                credential.value,
                forKey: StorageKey.chatGPTSessionToken
            )
            KeychainManager.shared.save(
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

        grokSessionToken = credential.value
        grokCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {
            grok = UsageInfo()

            KeychainManager.shared.delete(
                StorageKey.grokSessionToken
            )
            KeychainManager.shared.delete(
                StorageKey.grokCookieHeader
            )
            grokSessionRestorer.reset()
            usageNotificationManager.resetTracking(for: .grok)
        } else {
            KeychainManager.shared.save(
                credential.value,
                forKey: StorageKey.grokSessionToken
            )
            KeychainManager.shared.save(
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
            grok: grok
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


        do {

            let usage =
            try await claudeService.fetchUsage(
                sessionKey: key
            )


            claude = UsageInfo(
                sessionPercent:
                    usage.sessionRemainingPercent,

                weeklyPercent:
                    usage.weeklyRemainingPercent,

                weeklyAvailable: true,

                resetText:
                    usage.resetText,

                weeklyResetText:
                    usage.weeklyResetText,

                isLoaded: true,

                errorMessage: nil
            )

            clearStatusMessage(for: "Claude")
            return true


        } catch {
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


        do {

            let usage =
            try await chatGPTService.fetchUsage(
                cookieHeader: chatGPTCookieHeader.isEmpty
                    ? "__Secure-next-auth.session-token=\(token)"
                    : chatGPTCookieHeader
            )


            chatGPT = UsageInfo(
                sessionPercent:
                    usage.sessionRemainingPercent,

                weeklyPercent:
                    usage.weeklyRemainingPercent ?? 0,

                weeklyAvailable:
                    usage.weeklyRemainingPercent != nil,

                resetText:
                    usage.resetText,

                weeklyResetText:
                    usage.weeklyResetText ?? "",

                isLoaded: true,

                errorMessage: nil
            )

            clearStatusMessage(for: "ChatGPT")
            return true


        } catch {
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
        await grokSessionRestorer.restoreIfNeeded()
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

        do {

            let usage =
            try await grokService.fetchUsage(
                rateLimitsCookieHeader: rateLimitsCookieHeader,
                weeklyCookieHeader: weeklyCookieHeader
            )

            guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value
            ) else {
                return false
            }

            grok = UsageInfo(
                sessionPercent:
                    usage.sessionRemainingPercent,

                weeklyPercent:
                    usage.weeklyRemainingPercent ?? 0,

                weeklyAvailable:
                    usage.weeklyRemainingPercent != nil,

                resetText:
                    usage.weeklyRemainingPercent != nil
                    ? (usage.weeklyRelativeResetText ?? "")
                    : usage.resetText,

                weeklyResetText:
                    usage.weeklyResetText ?? "",

                sessionWindowSeconds:
                    usage.sessionWindowSeconds,

                isLoaded: true,

                errorMessage: nil
            )

            clearStatusMessage(for: "Grok")
            return true


        } catch {
            guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value
            ) else {
                return false
            }

            if GrokHTTPRefreshAuthPolicy.shouldAttemptRecovery(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value,
                didAlreadyRetry: !allowRecovery,
                error: error
            ) {
                _ = await grokSessionRestorer.restoreAfterRecoverableFailure()
                guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                    captured: authGeneration,
                    current: grokHTTPAuthGeneration.value
                ) else {
                    return false
                }
                return await fetchGrokUsage(
                    fallbackHeader: fallbackHeader,
                    allowRecovery: false,
                    authGeneration: authGeneration
                )
            }

            if let nextState = UsageRefreshStatePolicy.state(
                afterFailure: grok,
                error: error
            ) {
                guard GrokHTTPRefreshAuthPolicy.shouldCommit(
                    captured: authGeneration,
                    current: grokHTTPAuthGeneration.value
                ) else {
                    return false
                }
                grok = nextState
                let message = nextState.errorMessage ?? "更新失敗"
                statusMessage = "Grok：\(message)"
            }

            return false
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
