//
//  UsageInfo.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import Foundation

struct UsageInfo {
    var sessionPercent: Int = 0
    var weeklyPercent: Int = 0
    var weeklyAvailable: Bool = false
    var resetText: String = ""
    var weeklyResetText: String = ""
    var isLoaded: Bool = false
    var errorMessage: String?
}

enum UsageProvider: Hashable {
    case chatGPT
    case claude
}

struct ProviderVisibilityPolicy {
    let isChatGPTAuthenticated: Bool
    let isClaudeAuthenticated: Bool

    init(
        isChatGPTAuthenticated: Bool,
        isClaudeAuthenticated: Bool
    ) {
        self.isChatGPTAuthenticated = isChatGPTAuthenticated
        self.isClaudeAuthenticated = isClaudeAuthenticated
    }

    init(
        chatGPTSessionToken: String,
        claudeSessionKey: String
    ) {
        self.init(
            isChatGPTAuthenticated: !chatGPTSessionToken.isEmpty,
            isClaudeAuthenticated: !claudeSessionKey.isEmpty
        )
    }

    var visibleProviders: [UsageProvider] {
        var providers: [UsageProvider] = []

        if isChatGPTAuthenticated {
            providers.append(.chatGPT)
        }

        if isClaudeAuthenticated {
            providers.append(.claude)
        }

        return providers
    }

    var shouldShowSetupState: Bool {
        visibleProviders.isEmpty
    }

    var menuBarHelpText: String {
        switch visibleProviders {
        case [.chatGPT]:
            return "ChatGPT 剩餘用量"
        case [.claude]:
            return "Claude 剩餘用量"
        case [.chatGPT, .claude]:
            return "ChatGPT 與 Claude 剩餘用量"
        default:
            return "AIUsageBar"
        }
    }

    func isVisible(_ provider: UsageProvider) -> Bool {
        visibleProviders.contains(provider)
    }
}

enum UsageRefreshStatePolicy {
    static func shouldUpdateLastUpdated(
        claudeSucceeded: Bool,
        chatGPTSucceeded: Bool
    ) -> Bool {
        claudeSucceeded || chatGPTSucceeded
    }

    static func shouldClearStatusMessage(
        _ message: String,
        for provider: String
    ) -> Bool {
        message.hasPrefix("\(provider)：") ||
        message.hasPrefix("\(provider) 登入")
    }

    static func state(afterFailure current: UsageInfo, error: Error) -> UsageInfo? {
        guard !isCancellation(error) else {
            return nil
        }

        let message = error.localizedDescription.isEmpty
            ? "更新失敗"
            : error.localizedDescription

        guard current.isLoaded else {
            return UsageInfo(errorMessage: message)
        }

        var preserved = current
        preserved.errorMessage = message
        return preserved
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError ||
        (error as? URLError)?.code == .cancelled
    }
}
