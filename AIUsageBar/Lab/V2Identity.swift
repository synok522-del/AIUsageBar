import Foundation

enum V2IdentityFilesystemAccess: Equatable {
    case forbidden
}

struct V2IdentityKey: Equatable, Sendable, Hashable {
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

    static func from(snapshot: V2UsageSnapshot, meter: V2UsageMeter) -> V2IdentityKey? {
        V2IdentityKey(
            provider: snapshot.provider,
            accountKey: snapshot.accountKey,
            meterId: meter.meterId,
            window: meter.window.classification
        )
    }
}

/// Pure identity helper. No Keychain, WebKit, FileManager, or network.
enum V2IdentityHelper {
    static let filesystemAccess: V2IdentityFilesystemAccess = .forbidden

    static func cacheSlot(for key: V2IdentityKey) -> String {
        "\(key.provider.rawValue)|\(key.accountKey)|\(key.meterId)|\(key.window.rawValue)"
    }

    static func canMergeChatGPTAndCodex(
        verdict: ChatGPTCodexEquivalenceVerdict
    ) -> Bool {
        verdict == .provenEquivalent
    }
}

struct V2MeterCache {
    private var slots: [String: V2UsageMeter] = [:]

    mutating func store(key: V2IdentityKey, meter: V2UsageMeter) {
        slots[V2IdentityHelper.cacheSlot(for: key)] = meter
    }

    func meter(for key: V2IdentityKey) -> V2UsageMeter? {
        slots[V2IdentityHelper.cacheSlot(for: key)]
    }

    func sharesSlot(_ left: V2IdentityKey, _ right: V2IdentityKey) -> Bool {
        V2IdentityHelper.cacheSlot(for: left) == V2IdentityHelper.cacheSlot(for: right)
    }
}

struct V2PrimaryAlertLatch {
    var threshold: Int = V2ArchitectureConstants.notificationThresholdPercent
    private var lastValidPercent: [V2IdentityKey: Int] = [:]
    private var notified: Set<V2IdentityKey> = []

    mutating func reset(accountKey: String? = nil) {
        if let accountKey {
            lastValidPercent = lastValidPercent.filter { $0.key.accountKey != accountKey }
            notified = notified.filter { $0.accountKey != accountKey }
            return
        }
        lastValidPercent = [:]
        notified = []
    }

    /// User-visible 20% alert: primary displayed meter only, once until recover above threshold.
    mutating func shouldNotify(
        snapshot: V2UsageSnapshot,
        meter: V2UsageMeter
    ) -> Bool {
        guard let remaining = meter.remainingPercent else {
            return false
        }
        guard let key = V2IdentityKey.from(snapshot: snapshot, meter: meter) else {
            return false
        }
        guard meter.isPrimaryDisplayed else {
            lastValidPercent[key] = remaining
            return false
        }

        let previous = lastValidPercent[key]
        lastValidPercent[key] = remaining

        if remaining > threshold {
            notified.remove(key)
            return false
        }

        guard let previous, previous > threshold, !notified.contains(key) else {
            return false
        }
        notified.insert(key)
        return true
    }
}

enum V2DisplayedPercentMapping {
    struct Percents: Equatable {
        var sessionPercent: Int?
        var weeklyPercent: Int?
        var primaryRemainingPercent: Int?
        var weeklyAvailable: Bool
    }

    /// Explicit per-provider mapping. Does not guess primary from array order.
    static func percents(from snapshot: V2UsageSnapshot) -> Percents {
        switch snapshot.provider {
        case .chatGPT:
            let session = snapshot.meters.first { $0.meterId == "chatgpt.primary_window" }?.remainingPercent
            let weekly = snapshot.meters.first { $0.meterId == "chatgpt.secondary_window" }?.remainingPercent
            return Percents(
                sessionPercent: session,
                weeklyPercent: weekly,
                primaryRemainingPercent: snapshot.primaryDisplayedMeter?.remainingPercent ?? session,
                weeklyAvailable: weekly != nil
            )
        case .claude:
            let session = snapshot.meters.first { $0.meterId == "claude.five_hour" }?.remainingPercent
            let weekly = snapshot.meters.first { $0.meterId == "claude.seven_day" }?.remainingPercent
            return Percents(
                sessionPercent: session,
                weeklyPercent: weekly,
                primaryRemainingPercent: snapshot.primaryDisplayedMeter?.remainingPercent ?? session,
                weeklyAvailable: weekly != nil
            )
        case .grok:
            let session = snapshot.meters.first { $0.meterId == "grok.short" }?.remainingPercent
            let weekly = snapshot.meters.first { $0.meterId == "grok.weekly" }?.remainingPercent
            let weeklyAvailable = weekly != nil
            return Percents(
                sessionPercent: session,
                weeklyPercent: weekly,
                primaryRemainingPercent: weeklyAvailable ? weekly : session,
                weeklyAvailable: weeklyAvailable
            )
        default:
            return Percents(
                sessionPercent: snapshot.primaryDisplayedMeter?.remainingPercent,
                weeklyPercent: nil,
                primaryRemainingPercent: snapshot.primaryDisplayedMeter?.remainingPercent,
                weeklyAvailable: false
            )
        }
    }
}
