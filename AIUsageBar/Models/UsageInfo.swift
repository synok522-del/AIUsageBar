//
//  UsageInfo.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import CoreGraphics
import Foundation

struct UsageInfo {
    var sessionPercent: Int = 0
    var weeklyPercent: Int = 0
    var weeklyAvailable: Bool = false
    var resetText: String = ""
    var weeklyResetText: String = ""
    var sessionWindowSeconds: Int = 0
    var isLoaded: Bool = false
    var errorMessage: String?
}

enum UsageProvider: Hashable {
    case chatGPT
    case claude
    case grok
}

struct ProviderVisibilityPolicy {
    let isChatGPTAuthenticated: Bool
    let isClaudeAuthenticated: Bool
    let isGrokAuthenticated: Bool

    init(
        isChatGPTAuthenticated: Bool,
        isClaudeAuthenticated: Bool,
        isGrokAuthenticated: Bool = false
    ) {
        self.isChatGPTAuthenticated = isChatGPTAuthenticated
        self.isClaudeAuthenticated = isClaudeAuthenticated
        self.isGrokAuthenticated = isGrokAuthenticated
    }

    init(
        chatGPTSessionToken: String,
        claudeSessionKey: String,
        grokSessionToken: String = ""
    ) {
        self.init(
            isChatGPTAuthenticated: !chatGPTSessionToken.isEmpty,
            isClaudeAuthenticated: !claudeSessionKey.isEmpty,
            isGrokAuthenticated: !grokSessionToken.isEmpty
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

        if isGrokAuthenticated {
            providers.append(.grok)
        }

        return providers
    }

    var shouldShowSetupState: Bool {
        visibleProviders.isEmpty
    }

    var menuBarHelpText: String {
        let names = visibleProviders.map(\.displayName)

        switch names.count {
        case 0:
            return "AIUsageBar"
        case 1:
            return "\(names[0]) 剩餘用量"
        case 2:
            return "\(names[0]) 與 \(names[1]) 剩餘用量"
        default:
            let leading = names.dropLast().joined(separator: "、")
            return "\(leading) 與 \(names.last!) 剩餘用量"
        }
    }

    func isVisible(_ provider: UsageProvider) -> Bool {
        visibleProviders.contains(provider)
    }
}

extension UsageProvider {
    var displayName: String {
        switch self {
        case .chatGPT:
            return "ChatGPT"
        case .claude:
            return "Claude"
        case .grok:
            return "Grok"
        }
    }
}

enum UsageRefreshStatePolicy {
    static func shouldUpdateLastUpdated(
        claudeSucceeded: Bool,
        chatGPTSucceeded: Bool,
        grokSucceeded: Bool = false
    ) -> Bool {
        claudeSucceeded || chatGPTSucceeded || grokSucceeded
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

enum MenuBarStatusLayout {
    static func imageSize(providerCount: Int) -> (width: CGFloat, height: CGFloat) {
        if providerCount >= 3 {
            return (24, 16)
        }

        return (24, 10)
    }

    static func barHeight(providerCount: Int) -> CGFloat {
        providerCount >= 3 ? 3 : 4
    }

    static func barY(
        index: Int,
        providerCount: Int,
        imageHeight: CGFloat,
        barHeight: CGFloat
    ) -> CGFloat {
        guard providerCount > 1 else {
            return (imageHeight - barHeight) / 2
        }

        let usable = imageHeight - barHeight
        let step = usable / CGFloat(providerCount - 1)
        return imageHeight - barHeight - CGFloat(index) * step
    }
}
