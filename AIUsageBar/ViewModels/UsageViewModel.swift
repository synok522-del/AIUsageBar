//
//  UsageViewModel.swift
//  AIUsageBar
//

import Combine
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {

    private enum StorageKey {
        static let claudeSessionKey = "claudeSessionKey"
        static let chatGPTSessionToken = "chatGPTSessionToken"

        // 舊版 key
        static let oldChatGPTSessionToken = "chatgptSessionToken"
    }


    @Published var claude = UsageInfo()
    @Published var chatGPT = UsageInfo()
    @Published var statusMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?


    @Published private(set) var claudeSessionKey: String = ""

    @Published private(set) var chatGPTSessionToken: String = ""


    private let claudeService: ClaudeService
    private let chatGPTService: ChatGPTService
    private let usageNotificationManager = UsageNotificationManager()


    private var refreshTimer: Timer?


    init(
        claudeService: ClaudeService = ClaudeService(),
        chatGPTService: ChatGPTService = ChatGPTService()
    ) {

        self.claudeService = claudeService
        self.chatGPTService = chatGPTService

        migrateToKeychain()

        self.claudeSessionKey =
            KeychainManager.shared.read(
                StorageKey.claudeSessionKey
            ) ?? ""

        self.chatGPTSessionToken =
            KeychainManager.shared.read(
                StorageKey.chatGPTSessionToken
            ) ?? ""

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

        chatGPTSessionToken = value

        if value.isEmpty {

            KeychainManager.shared.delete(
                StorageKey.chatGPTSessionToken
            )

        } else {

            KeychainManager.shared.save(
                value,
                forKey: StorageKey.chatGPTSessionToken
            )
        }
    }



    // MARK: - Refresh

    func refreshAll() async {

        guard !isLoading else {
            return
        }


        isLoading = true


        async let claudeRefresh: Void =
            refreshClaude()


        async let chatGPTRefresh: Void =
            refreshChatGPT()


        _ = await (
            claudeRefresh,
            chatGPTRefresh
        )

        usageNotificationManager.evaluate(
            claude: claude,
            chatGPT: chatGPT
        )


        lastUpdated = Date()

        isLoading = false
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

    private func refreshClaude() async {

        let key =
        claudeSessionKey
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !key.isEmpty else {

            claude = UsageInfo(
                errorMessage: "尚未登入"
            )

            return
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

                resetText:
                    usage.resetText,

                isLoaded: true,

                errorMessage: nil
            )


        } catch {

            claude = UsageInfo(
                errorMessage:
                    error.localizedDescription
            )
        }
    }



    // MARK: - ChatGPT

    private func refreshChatGPT() async {

        let token =
        chatGPTSessionToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !token.isEmpty else {

            chatGPT = UsageInfo(
                errorMessage: "尚未登入"
            )

            return
        }


        do {

            let usage =
            try await chatGPTService.fetchUsage(
                sessionToken: token
            )


            chatGPT = UsageInfo(
                sessionPercent:
                    usage.sessionRemainingPercent,

                weeklyPercent: 0,

                resetText:
                    usage.resetText,

                isLoaded: true,

                errorMessage: nil
            )


        } catch {

            chatGPT = UsageInfo(
                errorMessage:
                    error.localizedDescription
            )
        }
    }
}
