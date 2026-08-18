import Foundation
import OSLog
import UserNotifications

private let usageNotificationLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
    category: "UsageNotifications"
)

enum UsageNotificationSettings {
    static let isEnabledKey = "lowUsageNotificationsEnabled"
    static let defaultEnabled = true
    static let authorizationRequestedKey =
        "lowUsageNotificationAuthorizationRequested"
}

enum UsageNotificationProvider: String, Hashable, Sendable {
    case chatGPT
    case claude

    var displayName: String {
        switch self {
        case .chatGPT:
            "ChatGPT"
        case .claude:
            "Claude"
        }
    }
}

private struct UsageNotificationPayload: Sendable {
    let provider: UsageNotificationProvider
    let remainingPercent: Int
    let resetText: String
}

struct UsageNotificationState {
    static let defaultThreshold = 20

    let threshold: Int

    private var lastValidPercent: [UsageNotificationProvider: Int] = [:]
    private var notifiedProviders: Set<UsageNotificationProvider> = []

    init(threshold: Int = Self.defaultThreshold) {
        self.threshold = threshold
    }

    mutating func shouldNotify(
        for provider: UsageNotificationProvider,
        remainingPercent: Int?,
        isLoaded: Bool,
        hasError: Bool
    ) -> Bool {
        guard isLoaded,
              !hasError,
              let remainingPercent,
              (0...100).contains(remainingPercent) else {
            return false
        }

        let previousPercent = lastValidPercent[provider]
        lastValidPercent[provider] = remainingPercent

        if remainingPercent > threshold {
            notifiedProviders.remove(provider)
            return false
        }

        guard let previousPercent,
              previousPercent > threshold,
              !notifiedProviders.contains(provider) else {
            return false
        }

        notifiedProviders.insert(provider)
        return true
    }

    mutating func shouldNotifyIfEnabled(
        for provider: UsageNotificationProvider,
        remainingPercent: Int?,
        isLoaded: Bool,
        hasError: Bool,
        notificationsEnabled: Bool
    ) -> Bool {
        guard notificationsEnabled else {
            return false
        }

        return shouldNotify(
            for: provider,
            remainingPercent: remainingPercent,
            isLoaded: isLoaded,
            hasError: hasError
        )
    }
}

@MainActor
final class UsageNotificationManager {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var state = UsageNotificationState()
    private var authorizationWasRequested: Bool

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        self.authorizationWasRequested = defaults.bool(
            forKey: UsageNotificationSettings.authorizationRequestedKey
        )
    }

    func evaluate(
        claude: UsageInfo,
        chatGPT: UsageInfo
    ) {
        let notificationsEnabled = notificationsAreEnabled

        let shouldNotifyClaude = state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: claude.sessionPercent,
            isLoaded: claude.isLoaded,
            hasError: claude.errorMessage != nil,
            notificationsEnabled: notificationsEnabled
        )

        let shouldNotifyChatGPT = state.shouldNotifyIfEnabled(
            for: .chatGPT,
            remainingPercent: chatGPT.sessionPercent,
            isLoaded: chatGPT.isLoaded,
            hasError: chatGPT.errorMessage != nil,
            notificationsEnabled: notificationsEnabled
        )

        var payloads: [UsageNotificationPayload] = []

        if shouldNotifyClaude {
            payloads.append(makePayload(for: .claude, info: claude))
        }

        if shouldNotifyChatGPT {
            payloads.append(makePayload(for: .chatGPT, info: chatGPT))
        }

        requestAuthorizationIfNeeded(for: payloads)
    }

    private var notificationsAreEnabled: Bool {
        guard defaults.object(
            forKey: UsageNotificationSettings.isEnabledKey
        ) != nil else {
            return UsageNotificationSettings.defaultEnabled
        }

        return defaults.bool(forKey: UsageNotificationSettings.isEnabledKey)
    }

    private func makePayload(
        for provider: UsageNotificationProvider,
        info: UsageInfo
    ) -> UsageNotificationPayload {
        UsageNotificationPayload(
            provider: provider,
            remainingPercent: info.sessionPercent,
            resetText: info.resetText
        )
    }

    private func makeRequest(
        for payload: UsageNotificationPayload
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()

        content.title = "\(payload.provider.displayName) 剩餘用量偏低"

        var body = "目前剩餘 \(payload.remainingPercent)%"
        if !payload.resetText.isEmpty {
            body += "，\(payload.resetText)"
        }

        content.body = body
        content.sound = .default

        return UNNotificationRequest(
            identifier: "low-usage-\(payload.provider.rawValue)",
            content: content,
            trigger: nil
        )
    }

    private func requestAuthorizationIfNeeded(
        for payloads: [UsageNotificationPayload]
    ) {
        guard !payloads.isEmpty else {
            return
        }

        if authorizationWasRequested {
            center.getNotificationSettings { [weak self] settings in
                guard settings.authorizationStatus == .authorized ||
                        settings.authorizationStatus == .provisional else {
                    return
                }

                Task { @MainActor [weak self] in
                    self?.deliver(payloads)
                }
            }
            return
        }

        authorizationWasRequested = true
        defaults.set(
            true,
            forKey: UsageNotificationSettings.authorizationRequestedKey
        )

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted else {
                return
            }

            Task { @MainActor [weak self] in
                self?.deliver(payloads)
            }
        }
    }

    private func deliver(_ payloads: [UsageNotificationPayload]) {
        for payload in payloads {
            let request = makeRequest(for: payload)
            let provider = payload.provider.rawValue

            center.add(request) { error in
                guard let error else {
                    return
                }

                let errorCode = (error as NSError).code
                usageNotificationLogger.error(
                    "Failed to deliver low usage notification for \(provider, privacy: .public), error code \(errorCode, privacy: .public)"
                )
            }
        }
    }
}
