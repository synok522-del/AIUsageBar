import Foundation
import CryptoKit

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
    var absoluteUsed: Double? = nil
    var absoluteRemaining: Double? = nil
    var absoluteLimit: Double? = nil
    var overage: Double? = nil
    var entitlement: String? = nil
    var windowDurationSeconds: Int? = nil

    func validity(observedAt: Date, now: Date, identityMatches: Bool) -> UsageValidity {
        guard !meterId.isEmpty,
              remainingPercent != nil || usedPercent != nil || absoluteUsed != nil || absoluteRemaining != nil,
              [absoluteUsed, absoluteRemaining, absoluteLimit, overage].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }),
              remainingPercent.map({ (0...100).contains($0) }) ?? true,
              usedPercent.map({ (0...100).contains($0) }) ?? true else { return .invalid }
        return UsageValidityPolicy.validity(asOf: observedAt, now: now, expiresAt: resetAt, identityMatches: identityMatches)
    }
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
                window: $0.window,
                durationSeconds: $0.windowDurationSeconds
            )
        }
    }

    var displayedPrimaryMeter: UsageMeter? {
        meters.first(where: \.isDisplayedPrimary) ?? meters.first
    }

    func validity(
        now: Date,
        expectedAccountKey: String?,
        meterId: String? = nil,
        window: UsageWindow? = nil,
        durationSeconds: Int? = nil
    ) -> UsageValidity {
        let identityMatches: Bool
        if let expectedAccountKey {
            identityMatches = accountKey == expectedAccountKey
        } else {
            identityMatches = accountKeyUnavailable
        }
        guard health == .available, !meters.isEmpty,
              accountKeyUnavailable == (accountKey == nil),
              Set(meters.map { $0.meterId }).count == meters.count else { return .invalid }
        let states = meters.map { $0.validity(observedAt: asOf, now: now, identityMatches: identityMatches) }
        if states.contains(.invalid) { return .invalid }

        if let meterId {
            guard let meterIndex = meters.firstIndex(where: {
                $0.meterId == meterId &&
                (window == nil || $0.window == window) &&
                (durationSeconds == nil || $0.windowDurationSeconds == durationSeconds)
            }) else {
                return .invalid
            }
            return states[meterIndex]
        }

        // A provider card is driven by its displayed primary meter. A
        // secondary quota can cross its own reset boundary independently; it
        // remains expired for meter-specific consumers, but must not blank a
        // still-usable primary card.
        guard let primaryIndex = meters.firstIndex(where: { $0.isDisplayedPrimary })
                ?? meters.indices.first else {
            return .invalid
        }
        switch states[primaryIndex] {
        case .invalid:
            return .invalid
        case .expired:
            return .expired
        case .staleButValid:
            return .staleButValid
        case .fresh:
            return .fresh
        }
    }
}

struct UsageCacheIdentity: Hashable, Sendable {
    var provider: UsageProviderID
    var accountKey: String?
    var meterId: String
    var window: UsageWindow
    var durationSeconds: Int? = nil
}

enum UsageValidityPolicy {
    static let freshnessTTL: TimeInterval = 120

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
        guard age >= -5 else { return .invalid }
        if age <= freshnessTTL {
            return .fresh
        }
        return .staleButValid
    }
}

@MainActor
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
    /// Reconstruct the session token using the same base-name priority as login
    /// cookie assembly. Multiple NextAuth cookie names in one header must not
    /// reject a valid preferred token.
    static func chatGPTCredential(in header: String) -> String? {
        let fields = header.split(separator: ";").compactMap { part -> (String, String)? in
            let pair = part.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            return (String(pair[0]), String(pair[1]))
        }
        for base in ["__Secure-next-auth.session-token", "__Host-next-auth.session-token", "next-auth.session-token"] {
            let exact = fields.filter { $0.0 == base }
            let chunks = fields.compactMap { name, value -> (Int, String)? in
                guard name.hasPrefix(base + "."), let index = Int(name.dropFirst(base.count + 1)) else { return nil }
                return (index, value)
            }.sorted { $0.0 < $1.0 }
            guard exact.count <= 1, exact.isEmpty || chunks.isEmpty else { return nil }
            if let value = exact.first?.1, !value.isEmpty {
                return value
            }
            if !chunks.isEmpty {
                guard chunks.map({ $0.0 }) == Array(0..<chunks.count) else { return nil }
                let value = chunks.map({ $0.1 }).joined()
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }
    static func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func accountKey(from credential: String) -> String? {
        let trimmed = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return fingerprint(trimmed)
    }
}
