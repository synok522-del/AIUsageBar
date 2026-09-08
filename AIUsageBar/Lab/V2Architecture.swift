import Foundation

/// Frozen V2 architecture types. Production ChatGPT / Claude / Grok services
/// still run V1 paths. These types are not a provider migration.

enum V2Provider: String, Equatable, Sendable, Hashable {
    case chatGPT
    case claude
    case grok
    case cursor
    case geminiApps
    case geminiCLI
    case copilot
    case codex
}

enum V2WindowClass: String, Equatable, Sendable, Hashable {
    case short
    case daily
    case weekly
    case monthly
    case unspecified
}

struct V2Window: Equatable, Sendable, Hashable {
    var classification: V2WindowClass
    var duration: TimeInterval?
}

struct V2UsageMeter: Equatable, Sendable {
    var meterId: String
    var window: V2Window
    var remainingPercent: Int?
    var resetAt: Date?
    var isPrimaryDisplayed: Bool

    init?(
        meterId: String,
        window: V2Window,
        remainingPercent: Int? = nil,
        resetAt: Date? = nil,
        isPrimaryDisplayed: Bool = false
    ) {
        let trimmed = meterId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        self.meterId = trimmed
        self.window = window
        self.remainingPercent = remainingPercent
        self.resetAt = resetAt
        self.isPrimaryDisplayed = isPrimaryDisplayed
    }
}

struct V2UsageSnapshot: Equatable, Sendable {
    var provider: V2Provider
    var accountKey: String
    var meters: [V2UsageMeter]
    var fetchedAt: Date

    init?(
        provider: V2Provider,
        accountKey: String,
        meters: [V2UsageMeter],
        fetchedAt: Date
    ) {
        let trimmed = accountKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        self.provider = provider
        self.accountKey = trimmed
        self.meters = meters
        self.fetchedAt = fetchedAt
    }

    var primaryDisplayedMeter: V2UsageMeter? {
        meters.first(where: \.isPrimaryDisplayed)
    }
}

enum V2SnapshotValidity: String, Equatable, Sendable {
    case fresh = "FRESH"
    case staleButValid = "STALE_BUT_VALID"
    case expired = "EXPIRED"
    case invalid = "INVALID"
}

enum V2RecoveryPhase: String, Equatable, Sendable {
    case healthy = "HEALTHY"
    case recovering = "RECOVERING"
    case backoff = "BACKOFF"
    case requiresUserAction = "REQUIRES_USER_ACTION"
}

enum V2UICopy: Equatable, Sendable {
    static let signedIn = "已登入"
    static let needsRelogin = "需重新登入"
    static let temporarilyUnavailable = "資料暫時無法取得"

    static let allowedUserVisibleStrings: Set<String> = [
        signedIn,
        needsRelogin,
        temporarilyUnavailable
    ]
}

/// Named constants. Tests must read these identifiers, not magic numbers.
enum V2ArchitectureConstants {
    static let freshnessWindow: TimeInterval = 15 * 60
    static let validityTTL: TimeInterval = 6 * 60 * 60
    static let recoverFailureLimit = 3
    static let backoffCooldown: TimeInterval = 30
    static let notificationThresholdPercent = 20

    static let shortWindowMaxDuration: TimeInterval = 6 * 60 * 60
    static let dailyWindowDuration: TimeInterval = 24 * 60 * 60
    static let weeklyWindowDuration: TimeInterval = 7 * 24 * 60 * 60
    static let monthlyWindowDuration: TimeInterval = 30 * 24 * 60 * 60
    static let windowDurationTolerance: TimeInterval = 3 * 60 * 60
}

enum V2WindowClassifier {
    static func classify(duration: TimeInterval?) -> V2WindowClass {
        guard let duration, duration.isFinite, duration > 0 else {
            return .unspecified
        }
        if duration <= V2ArchitectureConstants.shortWindowMaxDuration {
            return .short
        }
        if isNear(duration, V2ArchitectureConstants.dailyWindowDuration) {
            return .daily
        }
        if isNear(duration, V2ArchitectureConstants.weeklyWindowDuration) {
            return .weekly
        }
        if isNear(duration, V2ArchitectureConstants.monthlyWindowDuration) {
            return .monthly
        }
        return .unspecified
    }

    private static func isNear(_ duration: TimeInterval, _ target: TimeInterval) -> Bool {
        abs(duration - target) <= V2ArchitectureConstants.windowDurationTolerance
    }
}

enum V2SnapshotValidityPolicy {
    static func validity(
        fetchedAt: Date,
        now: Date,
        lastParseSucceeded: Bool,
        identityMatched: Bool
    ) -> V2SnapshotValidity {
        if !lastParseSucceeded || !identityMatched {
            return .invalid
        }
        let age = now.timeIntervalSince(fetchedAt)
        if age > V2ArchitectureConstants.validityTTL {
            return .expired
        }
        if age > V2ArchitectureConstants.freshnessWindow {
            return .staleButValid
        }
        return .fresh
    }

    /// Cookie-exists / navigation-finished / WKWebView READY cannot produce FRESH.
    static func validity(
        fromProbe probe: V2CredentialProbeEvent,
        now: Date
    ) -> V2SnapshotValidity {
        _ = now
        switch probe {
        case .cookieExists, .navigationFinished, .webKitReady:
            return .invalid
        }
    }
}

enum V2CredentialProbeEvent: Equatable, Sendable {
    case cookieExists
    case navigationFinished
    case webKitReady
}

struct V2RecoverySuccessInput: Equatable, Sendable {
    var didFetch: Bool
    var httpStatus: Int?
    var parseSucceeded: Bool
    var identityMatched: Bool
}

enum V2RecoverySuccessPolicy {
    static func isSuccess(_ input: V2RecoverySuccessInput) -> Bool {
        guard input.didFetch,
              let status = input.httpStatus,
              (200..<300).contains(status),
              input.parseSucceeded,
              input.identityMatched else {
            return false
        }
        return true
    }
}

struct V2NotificationIdentity: Equatable, Sendable, Hashable {
    var provider: V2Provider
    var accountKey: String
    var meterId: String
    var window: V2WindowClass

    init?(provider: V2Provider, accountKey: String, meterId: String, window: V2WindowClass) {
        let account = accountKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let meter = meterId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !meter.isEmpty else {
            return nil
        }
        self.provider = provider
        self.accountKey = account
        self.meterId = meter
        self.window = window
    }

    static func from(snapshot: V2UsageSnapshot, meter: V2UsageMeter) -> V2NotificationIdentity? {
        V2NotificationIdentity(
            provider: snapshot.provider,
            accountKey: snapshot.accountKey,
            meterId: meter.meterId,
            window: meter.window.classification
        )
    }
}

enum V2NotificationPolicy {
    static func shouldEmitUserVisibleAlert(
        meter: V2UsageMeter,
        remainingPercent: Int,
        threshold: Int = V2ArchitectureConstants.notificationThresholdPercent
    ) -> Bool {
        guard meter.isPrimaryDisplayed else {
            return false
        }
        return remainingPercent <= threshold
    }
}

enum V2UICopyPolicy {
    static func copy(for phase: V2RecoveryPhase) -> String {
        switch phase {
        case .healthy:
            return V2UICopy.signedIn
        case .recovering:
            return V2UICopy.signedIn
        case .backoff:
            return V2UICopy.temporarilyUnavailable
        case .requiresUserAction:
            return V2UICopy.needsRelogin
        }
    }

    static func isAllowed(_ string: String) -> Bool {
        V2UICopy.allowedUserVisibleStrings.contains(string)
    }
}
