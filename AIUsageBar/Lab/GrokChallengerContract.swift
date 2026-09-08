import Foundation

enum GrokLabFilesystemAccess: Equatable {
    case forbidden
}
    case superGrok = "super_grok"
    case free = "free"
    case unknown = "unknown"
}

enum GrokChallengerOutcome: Equatable {
    case accepted(GrokChallengerDocument)
    case rejected
    case missingLocalSource
    case parseFailure
}

enum GrokLabSourceSelection: String, Equatable, Sendable {
    case webOnly
    case webPlusChallenger
}

struct GrokChallengerDocument: Equatable, Sendable {
    var entitlement: GrokLabEntitlement
    var shortRemainingPercent: Int
    var weeklyRemainingPercent: Int?
    var weeklyExplicitlyAbsent: Bool
    var weeklyResetAt: Date?
    var weeklyResetFromBillingPeriodEnd: Bool
}

/// Lab contract for a local/CLI Grok challenger vs SuperGrok web meters.
/// Does not replace `GrokService` or `GetGrokCreditsConfig`.
enum GrokChallengerContract {
    static let filesystemAccess: GrokLabFilesystemAccess = .forbidden
    static let webCreditsRequestPath = GrokCreditsConfigDecoder.requestPath

    static func parse(json: Data) -> GrokChallengerOutcome {
        if json.isEmpty {
            return .parseFailure
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json, options: [])
        } catch {
            return .parseFailure
        }
        guard let dictionary = object as? [String: Any] else {
            return .parseFailure
        }
        return parse(dictionary: dictionary)
    }

    static func parse(jsonString: String) -> GrokChallengerOutcome {
        guard let data = jsonString.data(using: .utf8) else {
            return .parseFailure
        }
        return parse(json: data)
    }

    static func evaluate(
        fixture: GrokChallengerOutcome,
        webEntitlement: GrokLabEntitlement
    ) -> GrokChallengerOutcome {
        switch fixture {
        case .accepted(let document):
            if document.weeklyResetFromBillingPeriodEnd {
                return .rejected
            }
            if !entitlementMatches(web: webEntitlement, challenger: document.entitlement) {
                return .rejected
            }
            return .accepted(document)
        case .rejected, .missingLocalSource, .parseFailure:
            return fixture
        }
    }

    static func entitlementMatches(
        web: GrokLabEntitlement,
        challenger: GrokLabEntitlement
    ) -> Bool {
        web == challenger
    }

    static func sourceSelection(localSourcePresent: Bool) -> GrokLabSourceSelection {
        localSourcePresent ? .webPlusChallenger : .webOnly
    }

    static func treatsMissingLocalAsLogout(_ outcome: GrokChallengerOutcome) -> Bool {
        if case .missingLocalSource = outcome {
            return false
        }
        return false
    }

    static func webCreditsPathEnabled(after outcome: GrokChallengerOutcome) -> Bool {
        _ = outcome
        return true
    }

    private static func parse(dictionary: [String: Any]) -> GrokChallengerOutcome {
        if dictionary["local_source_present"] as? Bool == false {
            return .missingLocalSource
        }

        guard let short = dictionary["short_window"] as? [String: Any],
              let shortRemaining = intPercent(short["remaining_percent"]) else {
            return .rejected
        }

        let weeklyExplicitlyAbsent = dictionary["weekly_absent"] as? Bool == true
        let weeklyObject = dictionary["weekly"] as? [String: Any]
        let weeklyRemaining = weeklyObject.flatMap { intPercent($0["remaining_percent"]) }

        if weeklyObject == nil && !weeklyExplicitlyAbsent {
            return .rejected
        }
        if weeklyObject != nil && weeklyRemaining == nil && !weeklyExplicitlyAbsent {
            return .rejected
        }

        let billingPeriodEnd = weeklyObject?["billing_period_end"]
        let resetSource = (weeklyObject?["reset_source"] as? String)?.lowercased()
        let usedBillingPeriodEnd =
            resetSource == "billing_period_end"
            || (weeklyObject?["reset_at"] == nil && billingPeriodEnd != nil && !(billingPeriodEnd is NSNull))

        let weeklyResetAt: Date?
        if usedBillingPeriodEnd {
            weeklyResetAt = nil
        } else {
            weeklyResetAt = isoDate(weeklyObject?["reset_at"] ?? weeklyObject?["current_period_end"])
        }

        let entitlement = GrokLabEntitlement(
            rawValue: (dictionary["entitlement"] as? String) ?? ""
        ) ?? .unknown

        let document = GrokChallengerDocument(
            entitlement: entitlement,
            shortRemainingPercent: shortRemaining,
            weeklyRemainingPercent: weeklyExplicitlyAbsent ? nil : weeklyRemaining,
            weeklyExplicitlyAbsent: weeklyExplicitlyAbsent,
            weeklyResetAt: weeklyResetAt,
            weeklyResetFromBillingPeriodEnd: usedBillingPeriodEnd
        )
        return .accepted(document)
    }

    private static func intPercent(_ raw: Any?) -> Int? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        let number: Double?
        if let value = raw as? NSNumber {
            number = value.doubleValue
        } else if let value = raw as? String {
            number = Double(value)
        } else {
            return nil
        }
        guard let number, number.isFinite else {
            return nil
        }
        return min(100, max(0, Int(number.rounded())))
    }

    private static func isoDate(_ raw: Any?) -> Date? {
        guard let string = raw as? String else {
            return nil
        }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: string) {
            return date
        }
        let fraction = ISO8601DateFormatter()
        fraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fraction.date(from: string)
    }
}
