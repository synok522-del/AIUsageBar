import Foundation

/// Disk DTO for a verified last-good usage snapshot.
///
/// Never persist cookies, tokens, session keys, auth headers, or relative
/// reset strings. Relative display is recomputed from `resetAt` on restore.
struct PersistedLastGoodRecord: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var provider: String
    var accountKey: String
    var asOf: Date
    var health: String
    var sourceType: String
    var meters: [PersistedLastGoodMeter]
}

struct PersistedLastGoodMeter: Codable, Equatable, Sendable {
    var meterId: String
    var window: String
    var remainingPercent: Int?
    var usedPercent: Int?
    var resetAt: Date?
    var isDisplayedPrimary: Bool
    var absoluteUsed: Double?
    var absoluteRemaining: Double?
    var absoluteLimit: Double?
    var overage: Double?
    var entitlement: String?
    var windowDurationSeconds: Int?
}

protocol LastGoodUsageStoring: AnyObject {
    func save(_ snapshot: UsageSnapshot)
    func load(provider: UsageProviderID, accountKey: String) -> UsageSnapshot?
    func remove(provider: UsageProviderID, accountKey: String)
}

final class LastGoodUsageStore: LastGoodUsageStoring, @unchecked Sendable {
    static let keyPrefix = "aiusgbar.lastGood.v1."

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func save(_ snapshot: UsageSnapshot) {
        guard let record = Self.record(from: snapshot) else {
            return
        }
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        lock.lock()
        defaults.set(data, forKey: Self.storageKey(provider: record.provider, accountKey: record.accountKey))
        lock.unlock()
    }

    func load(provider: UsageProviderID, accountKey: String) -> UsageSnapshot? {
        lock.lock()
        let data = defaults.data(forKey: Self.storageKey(provider: provider.rawValue, accountKey: accountKey))
        lock.unlock()
        guard let data else {
            return nil
        }
        guard let record = try? JSONDecoder().decode(PersistedLastGoodRecord.self, from: data) else {
            return nil
        }
        return Self.snapshot(from: record, expectedProvider: provider, expectedAccountKey: accountKey)
    }

    func remove(provider: UsageProviderID, accountKey: String) {
        lock.lock()
        defaults.removeObject(forKey: Self.storageKey(provider: provider.rawValue, accountKey: accountKey))
        lock.unlock()
    }

    static func storageKey(provider: String, accountKey: String) -> String {
        keyPrefix + provider + "." + accountKey
    }

    static func record(from snapshot: UsageSnapshot) -> PersistedLastGoodRecord? {
        guard snapshot.health == .available,
              !snapshot.accountKeyUnavailable,
              let accountKey = snapshot.accountKey,
              !accountKey.isEmpty else {
            return nil
        }
        return PersistedLastGoodRecord(
            schemaVersion: PersistedLastGoodRecord.currentSchemaVersion,
            provider: snapshot.provider.rawValue,
            accountKey: accountKey,
            asOf: snapshot.asOf,
            health: snapshot.health.rawValue,
            sourceType: snapshot.sourceType.rawValue,
            meters: snapshot.meters.map { meter in
                PersistedLastGoodMeter(
                    meterId: meter.meterId,
                    window: meter.window.rawValue,
                    remainingPercent: meter.remainingPercent,
                    usedPercent: meter.usedPercent,
                    resetAt: meter.resetAt,
                    isDisplayedPrimary: meter.isDisplayedPrimary,
                    absoluteUsed: meter.absoluteUsed,
                    absoluteRemaining: meter.absoluteRemaining,
                    absoluteLimit: meter.absoluteLimit,
                    overage: meter.overage,
                    entitlement: meter.entitlement,
                    windowDurationSeconds: meter.windowDurationSeconds
                )
            }
        )
    }

    static func snapshot(
        from record: PersistedLastGoodRecord,
        expectedProvider: UsageProviderID,
        expectedAccountKey: String
    ) -> UsageSnapshot? {
        // Schema/version mismatch fails closed. Unknown provider or health
        // values also fail closed rather than guessing.
        guard record.schemaVersion == PersistedLastGoodRecord.currentSchemaVersion else {
            return nil
        }
        guard record.provider == expectedProvider.rawValue,
              record.accountKey == expectedAccountKey,
              let provider = UsageProviderID(rawValue: record.provider),
              provider == expectedProvider,
              let health = UsageSourceHealth(rawValue: record.health),
              health == .available,
              let sourceType = UsageSourceType(rawValue: record.sourceType) else {
            return nil
        }

        let meters: [UsageMeter] = record.meters.compactMap { meter in
            guard let window = UsageWindow(rawValue: meter.window), !meter.meterId.isEmpty else {
                return nil
            }
            return UsageMeter(
                meterId: meter.meterId,
                window: window,
                remainingPercent: meter.remainingPercent,
                usedPercent: meter.usedPercent,
                resetAt: meter.resetAt,
                isDisplayedPrimary: meter.isDisplayedPrimary,
                resetText: nil,
                weeklyRelativeResetText: nil,
                absoluteUsed: meter.absoluteUsed,
                absoluteRemaining: meter.absoluteRemaining,
                absoluteLimit: meter.absoluteLimit,
                overage: meter.overage,
                entitlement: meter.entitlement,
                windowDurationSeconds: meter.windowDurationSeconds
            )
        }
        guard meters.count == record.meters.count, !meters.isEmpty else {
            return nil
        }

        return UsageSnapshot(
            provider: provider,
            accountKey: record.accountKey,
            accountKeyUnavailable: false,
            sourceType: sourceType,
            asOf: record.asOf,
            meters: meters,
            health: health
        )
    }
}

enum UsageInfoFromSnapshot {
    static func make(_ snapshot: UsageSnapshot, stale: Bool, now: Date = Date()) -> UsageInfo? {
        guard let primary = snapshot.displayedPrimaryMeter else {
            return nil
        }

        switch snapshot.provider {
        case .chatGPT:
            let weekly = displayedSecondary(
                snapshot.meters.first(where: { $0.meterId == "chatgpt.secondary_window" }),
                observedAt: snapshot.asOf,
                now: now
            )
            return UsageInfo(
                sessionPercent: primary.remainingPercent ?? 0,
                weeklyPercent: weekly?.percent ?? 0,
                weeklyAvailable: weekly != nil,
                resetText: relativeReset(primary.resetAt, now: now),
                weeklyResetText: weekly.flatMap { absoluteReset($0.resetAt) } ?? "",
                isLoaded: true,
                errorMessage: nil,
                isStale: stale,
                observedAt: snapshot.asOf
            )
        case .claude:
            let session = snapshot.meters.first(where: { $0.meterId == "claude.five_hour" })
            let weeklyMeter = snapshot.meters.first(where: { $0.meterId == "claude.seven_day" })
            guard let session, let sessionPercent = session.remainingPercent else {
                return nil
            }
            let weekly = displayedSecondary(weeklyMeter, observedAt: snapshot.asOf, now: now)
            return UsageInfo(
                sessionPercent: sessionPercent,
                weeklyPercent: weekly?.percent ?? 0,
                weeklyAvailable: weekly != nil,
                resetText: relativeReset(session.resetAt, now: now),
                weeklyResetText: weekly.flatMap { absoluteReset($0.resetAt) } ?? "",
                isLoaded: true,
                errorMessage: nil,
                isStale: stale,
                observedAt: snapshot.asOf
            )
        case .grok:
            let short = snapshot.meters.first(where: { $0.meterId == "grok.short" })
            let weekly = displayedSecondary(
                snapshot.meters.first(where: { $0.meterId == "grok.weekly" }),
                observedAt: snapshot.asOf,
                now: now
            )
            let sessionPercent = short?.remainingPercent ?? primary.remainingPercent ?? 0
            return UsageInfo(
                sessionPercent: sessionPercent,
                weeklyPercent: weekly?.percent ?? 0,
                weeklyAvailable: weekly != nil,
                resetText: weekly != nil
                    ? relativeReset(weekly?.resetAt, now: now)
                    : relativeReset(short?.resetAt ?? primary.resetAt, now: now),
                weeklyResetText: weekly.flatMap { absoluteReset($0.resetAt) } ?? "",
                sessionWindowSeconds: short?.windowDurationSeconds ?? 0,
                isLoaded: true,
                errorMessage: nil,
                isStale: stale,
                observedAt: snapshot.asOf
            )
        default:
            return nil
        }
    }

    private struct SecondaryDisplay {
        var percent: Int
        var resetAt: Date?
    }

    private static func displayedSecondary(
        _ meter: UsageMeter?,
        observedAt: Date,
        now: Date
    ) -> SecondaryDisplay? {
        guard let meter, let percent = meter.remainingPercent else {
            return nil
        }
        switch meter.validity(observedAt: observedAt, now: now, identityMatches: true) {
        case .fresh, .staleButValid:
            return SecondaryDisplay(percent: percent, resetAt: meter.resetAt)
        case .expired, .invalid:
            return nil
        }
    }

    private static func relativeReset(_ date: Date?, now: Date) -> String {
        guard let date else {
            return ""
        }
        return ServiceSupport.resetText(
            NSNumber(value: date.timeIntervalSince1970),
            now: now
        )
    }

    private static func absoluteReset(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }
        let text = ServiceSupport.absoluteResetText(NSNumber(value: date.timeIntervalSince1970))
        return text.isEmpty ? nil : text
    }
}
