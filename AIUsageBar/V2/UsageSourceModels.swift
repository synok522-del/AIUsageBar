import Foundation

enum UsageProviderID: String, Hashable, Sendable {
    case chatGPT
    case claude
    case grok
    case cursor
    case gemini
    case copilot
    case codex
}

enum UsageSourceType: String, Hashable, Sendable {
    case officialLocalRPC
    case officialAPI
    case officialLocalQuotaState
    case authorizedBrowserObservation
    case appWebKit
    case researchOnly
}

enum UsageWindow: String, Hashable, Sendable {
    case rolling5Hour
    case rolling7Day
    case rollingCustom
    case weekly
    case monthly
    case billingCycle
    case unknown
}

enum UsageValidity: String, Hashable, Sendable {
    case fresh
    case staleButValid
    case expired
    case invalid
}

enum UsageSourceHealth: String, Hashable, Sendable {
    case available
    case unavailable
    case unauthorized
}

struct UsageMeter: Equatable, Sendable {
    var meterId: String
    var window: UsageWindow
    var remainingPercent: Int?
    var usedPercent: Int?
    var resetAt: Date?
    var isDisplayedPrimary: Bool
    var resetText: String? = nil
    var weeklyRelativeResetText: String? = nil
}

struct UsageSnapshot: Equatable, Sendable {
    var provider: UsageProviderID
    var accountKey: String?
    var accountKeyUnavailable: Bool
    var sourceType: UsageSourceType
    var asOf: Date
    var meters: [UsageMeter]
    var health: UsageSourceHealth

    var cacheIdentities: [UsageCacheIdentity] {
        meters.map {
            UsageCacheIdentity(
                provider: provider,
                accountKey: accountKey,
                meterId: $0.meterId,
                window: $0.window
            )
        }
    }

    var displayedPrimaryMeter: UsageMeter? {
        meters.first(where: \.isDisplayedPrimary) ?? meters.first
    }

    func validity(now: Date, expectedAccountKey: String?) -> UsageValidity {
        let identityMatches: Bool
        if let expectedAccountKey {
            identityMatches = accountKey == expectedAccountKey
        } else {
            identityMatches = accountKeyUnavailable
        }
        return UsageValidityPolicy.validity(
            asOf: asOf,
            now: now,
            expiresAt: displayedPrimaryMeter?.resetAt,
            identityMatches: identityMatches
        )
    }
}

struct UsageCacheIdentity: Hashable, Sendable {
    var provider: UsageProviderID
    var accountKey: String?
    var meterId: String
    var window: UsageWindow
}

enum UsageValidityPolicy {
    static let freshnessTTL: TimeInterval = 120
    static let expiredTTL: TimeInterval = 6 * 60 * 60

    static func validity(
        asOf: Date,
        now: Date,
        expiresAt: Date?,
        identityMatches: Bool
    ) -> UsageValidity {
        guard identityMatches else {
            return .invalid
        }

        if let expiresAt, now >= expiresAt {
            return .expired
        }

        let age = now.timeIntervalSince(asOf)
        if age <= freshnessTTL {
            return .fresh
        }
        if age > expiredTTL {
            return .expired
        }
        return .staleButValid
    }
}

protocol UsageSource {
    var provider: UsageProviderID { get }
    var sourceType: UsageSourceType { get }
    func fetchSnapshot() async throws -> UsageSnapshot
}

enum UsageSourceError: Error, Equatable {
    case unavailable
    case unauthorized
    case malformed
    case missingMeter
}

enum UsageIdentity {
    static func fingerprint(_ value: String) -> String {
        var hash: UInt64 = 5381
        for byte in value.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    static func accountKey(from credential: String) -> String? {
        let trimmed = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return fingerprint(trimmed)
    }
}
