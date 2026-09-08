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
    case grok

    var displayName: String {
        switch self {
        case .chatGPT:
            "ChatGPT"
        case .claude:
            "Claude"
        case .grok:
            "Grok"
        }
    }
}

private struct UsageNotificationPayload: Sendable {
    let provider: UsageNotificationProvider
    let remainingPercent: Int
    let resetText: String
    let generation: UInt
    let createdAt: Date
    let resetAt: Date?
}

enum UsageNotificationWindowPolicy {
    static func isGenuineNewWindow(
        previousResetAt: Date?,
        currentResetAt: Date?,
        now: Date
    ) -> Bool {
        // A new future reset after the prior boundary is reliable evidence of
        // a new logical window. Future-to-future changes are treated as
        // harmless provider recomputation so resetAt jitter cannot re-arm a
        // notification that already fired.
        guard let previousResetAt, let currentResetAt else {
            return false
        }
        return previousResetAt <= now && currentResetAt > now
    }
}

struct UsageNotificationState {
    static let defaultThreshold = 20

    let threshold: Int

    private var lastValidPercent: [UsageNotificationProvider: Int] = [:]
    private var notifiedProviders: Set<UsageNotificationProvider> = []

    init(threshold: Int = Self.defaultThreshold) {
        self.threshold = threshold
    }

    mutating func resetTracking(for provider: UsageNotificationProvider) {
        lastValidPercent.removeValue(forKey: provider)
        notifiedProviders.remove(provider)
    }

    func lastRecordedPercent(for provider: UsageNotificationProvider) -> Int? {
        lastValidPercent[provider]
    }

    func hasNotified(_ provider: UsageNotificationProvider) -> Bool {
        notifiedProviders.contains(provider)
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
    private struct ScopeIdentity: Equatable {
        let account: String?
        let meter: String
        let window: UsageWindow
        let durationSeconds: Int?
    }
    private struct Scope {
        let identity: ScopeIdentity
        var resetAt: Date?
    }
    private var scopes: [UsageNotificationProvider: Scope] = [:]
    private var generations: [UsageNotificationProvider: UInt] = [:]
    private var lastMeters: [UsageNotificationProvider: String] = [:]

    func lastNotifiedMeterID(for provider: UsageProviderID) -> String? {
        guard let provider = UsageNotificationProvider(rawValue: provider.rawValue) else { return nil }
        return lastMeters[provider]
    }

    private func prepare(_ provider: UsageNotificationProvider, snapshot: UsageSnapshot?, now: Date) -> Bool {
        guard let snapshot, let meter = snapshot.displayedPrimaryMeter,
              snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey) == .fresh else { return false }
        let identity = ScopeIdentity(
            account: snapshot.accountKey,
            meter: meter.meterId,
            window: meter.window,
            durationSeconds: meter.windowDurationSeconds
        )
        let resetCrossed = scopes[provider].map {
            UsageNotificationWindowPolicy.isGenuineNewWindow(
                previousResetAt: $0.resetAt,
                currentResetAt: meter.resetAt,
                now: now
            )
        } ?? false
        if scopes[provider]?.identity != identity || resetCrossed {
            resetTracking(for: provider)
        }
        scopes[provider] = Scope(identity: identity, resetAt: meter.resetAt)
        return true
    }

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

    func resetTracking(for provider: UsageNotificationProvider) {
        state.resetTracking(for: provider)
        scopes[provider] = nil
        lastMeters[provider] = nil
        generations[provider, default: 0] += 1
    }

    func lastRecordedPercent(for provider: UsageNotificationProvider) -> Int? {
        state.lastRecordedPercent(for: provider)
    }

    func hasNotified(_ provider: UsageNotificationProvider) -> Bool {
        state.hasNotified(provider)
    }

    @discardableResult
    func recordSample(
        for provider: UsageNotificationProvider,
        remainingPercent: Int?,
        isLoaded: Bool,
        hasError: Bool
    ) -> Bool {
        state.shouldNotify(
            for: provider,
            remainingPercent: remainingPercent,
            isLoaded: isLoaded,
            hasError: hasError
        )
    }

    func evaluate(
        claude: UsageInfo,
        chatGPT: UsageInfo,
        grok: UsageInfo,
        snapshots: [UsageProviderID: UsageSnapshot]? = nil
    ) {
        let notificationsEnabled = notificationsAreEnabled
        let now = Date()
        let claudeValid = snapshots.map { prepare(.claude, snapshot: $0[.claude], now: now) } ?? true
        let chatGPTValid = snapshots.map { prepare(.chatGPT, snapshot: $0[.chatGPT], now: now) } ?? true
        let grokValid = snapshots.map { prepare(.grok, snapshot: $0[.grok], now: now) } ?? true

        let shouldNotifyClaude = state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: claude.sessionPercent,
            isLoaded: claude.isLoaded && claudeValid,
            hasError: claude.errorMessage != nil,
            notificationsEnabled: notificationsEnabled
        )

        let shouldNotifyChatGPT = state.shouldNotifyIfEnabled(
            for: .chatGPT,
            remainingPercent: chatGPT.sessionPercent,
            isLoaded: chatGPT.isLoaded && chatGPTValid,
            hasError: chatGPT.errorMessage != nil,
            notificationsEnabled: notificationsEnabled
        )

        let shouldNotifyGrok = state.shouldNotifyIfEnabled(
            for: .grok,
            remainingPercent: grok.primaryRemainingPercent,
            isLoaded: grok.isLoaded && grokValid,
            hasError: grok.errorMessage != nil,
            notificationsEnabled: notificationsEnabled
        )

        var payloads: [UsageNotificationPayload] = []

        if shouldNotifyClaude {
            payloads.append(makePayload(for: .claude, info: claude))
        }

        if shouldNotifyChatGPT {
            payloads.append(makePayload(for: .chatGPT, info: chatGPT))
        }

        if shouldNotifyGrok {
            payloads.append(makePayload(for: .grok, info: grok))
        }

        for payload in payloads { lastMeters[payload.provider] = scopes[payload.provider]?.identity.meter }
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
        switch provider {
        case .grok:
            return UsageNotificationPayload(
                provider: provider,
                remainingPercent: info.primaryRemainingPercent,
                resetText: info.primaryResetText,
                generation: generations[provider, default: 0],
                createdAt: Date(),
                resetAt: scopes[provider]?.resetAt
            )
        case .chatGPT, .claude:
            return UsageNotificationPayload(
                provider: provider,
                remainingPercent: info.sessionPercent,
                resetText: info.resetText,
                generation: generations[provider, default: 0],
                createdAt: Date(),
                resetAt: scopes[provider]?.resetAt
            )
        }
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
        guard !KeychainManager.isTestProcess, !payloads.isEmpty else {
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
            guard Date().timeIntervalSince(payload.createdAt) <= UsageValidityPolicy.freshnessTTL,
                  payload.generation == generations[payload.provider, default: 0],
                  payload.resetAt.map({ Date() < $0 }) ?? true,
                  scopes[payload.provider]?.resetAt.map({ Date() < $0 }) ?? true else { continue }
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
