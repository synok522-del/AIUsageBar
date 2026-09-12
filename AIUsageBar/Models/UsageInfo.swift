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
    var isStale: Bool = false
    var observedAt: Date?

    var primaryRemainingPercent: Int {
        weeklyAvailable ? weeklyPercent : sessionPercent
    }

    var primaryResetText: String {
        if weeklyAvailable {
            return ServiceSupport.combinedResetText(
                session: resetText,
                weekly: weeklyResetText
            )
        }
        return resetText
    }

    var staleCaption: String? {
        guard isStale, let observedAt else {
            return nil
        }
        return StaleUsagePresentation.caption(asOf: observedAt)
    }
}

struct GrokCardPresentation: Equatable {
    var showsSessionRow: Bool
    var showsWeeklyRow: Bool
    var sessionPercent: Int?
    var weeklyPercent: Int?

    var displayedRowCount: Int {
        (showsSessionRow ? 1 : 0) + (showsWeeklyRow ? 1 : 0)
    }

    static func from(_ info: UsageInfo) -> GrokCardPresentation {
        // Keep the displayed Grok quota identical to `primaryRemainingPercent`
        // even when a later refresh failed and preserved stale loaded values.
        guard info.isLoaded else {
            return GrokCardPresentation(
                showsSessionRow: true,
                showsWeeklyRow: false,
                sessionPercent: nil,
                weeklyPercent: nil
            )
        }

        if info.weeklyAvailable {
            return GrokCardPresentation(
                showsSessionRow: false,
                showsWeeklyRow: true,
                sessionPercent: nil,
                weeklyPercent: info.weeklyPercent
            )
        }

        return GrokCardPresentation(
            showsSessionRow: true,
            showsWeeklyRow: false,
            sessionPercent: info.sessionPercent,
            weeklyPercent: nil
        )
    }
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
            return L10n.appName
        case 1:
            return L10n.remainingUsageOne(names[0])
        case 2:
            return L10n.remainingUsageTwo(names[0], names[1])
        default:
            return L10n.remainingUsageThree(names[0], names[1], names[2])
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
        message.hasPrefix("\(provider):") ||
        message == L10n.loginSucceeded(provider)
    }

    static func state(afterFailure current: UsageInfo, error: Error, now: Date = Date()) -> UsageInfo? {
        guard !isCancellation(error) else {
            return nil
        }

        let message = error.localizedDescription.isEmpty
            ? L10n.updateFailed
            : error.localizedDescription

        guard current.isLoaded else {
            return UsageInfo(errorMessage: message)
        }

        var preserved = current
        preserved.errorMessage = message
        if let observedAt = current.observedAt,
           now.timeIntervalSince(observedAt) >= UsageValidityPolicy.freshnessTTL {
            preserved.isStale = true
        }
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
