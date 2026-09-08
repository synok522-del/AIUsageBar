import Foundation

enum GeminiLabFilesystemAccess: Equatable {
    case forbidden
}

enum GeminiMeterFamily: String, Equatable, Sendable {
    case apps = "gemini-apps"
    case cli = "gemini-cli"
}

enum GeminiProductionDecision: String, Equatable, Sendable {
    case hold = "HOLD"
}

enum GeminiUsageParseError: Error, Equatable {
    case malformedJSON
    case missingFamily
    case missingRemaining
    case fabricatedReset
    case invalidReset
}

struct GeminiUsageFixtureDocument: Equatable, Sendable {
    var family: GeminiMeterFamily
    var remainingPercent: Int
    var resetAt: Date?
    var accountKey: String
}

enum GeminiIdentityMergeRefusal: Equatable {
    case refusedDistinctFamilies
}

/// Lab-only Gemini Apps vs CLI split. Families stay distinct. No menu card.
enum GeminiUsageFixtureParser {
    static let filesystemAccess: GeminiLabFilesystemAccess = .forbidden

    static func parse(json: Data) throws -> GeminiUsageFixtureDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json, options: [])
        } catch {
            throw GeminiUsageParseError.malformedJSON
        }
        guard let dictionary = object as? [String: Any] else {
            throw GeminiUsageParseError.malformedJSON
        }
        return try parse(dictionary: dictionary)
    }

    static func parse(jsonString: String) throws -> GeminiUsageFixtureDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw GeminiUsageParseError.malformedJSON
        }
        return try parse(json: data)
    }

    private static func parse(dictionary: [String: Any]) throws -> GeminiUsageFixtureDocument {
        guard let family = family(from: dictionary) else {
            throw GeminiUsageParseError.missingFamily
        }
        guard let remaining = intPercent(
            dictionary["remaining_percent"] ?? dictionary["remainingPercent"]
        ) else {
            throw GeminiUsageParseError.missingRemaining
        }
        if dictionary["fabricated_reset"] as? Bool == true {
            throw GeminiUsageParseError.fabricatedReset
        }
        if dictionary["reset_source"] as? String == "fabricated" {
            throw GeminiUsageParseError.fabricatedReset
        }

        let resetAt = try parseReset(dictionary["resets_at"] ?? dictionary["reset_at"])
        let accountKey = (dictionary["account_key"] as? String)
            ?? (dictionary["accountKey"] as? String)
            ?? ""

        return GeminiUsageFixtureDocument(
            family: family,
            remainingPercent: remaining,
            resetAt: resetAt,
            accountKey: accountKey
        )
    }

    static func family(from dictionary: [String: Any]) -> GeminiMeterFamily? {
        let raw = (dictionary["family"] as? String)
            ?? (dictionary["meter_family"] as? String)
            ?? ""
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case GeminiMeterFamily.apps.rawValue, "apps":
            return .apps
        case GeminiMeterFamily.cli.rawValue, "cli", "code_assist", "code-assist":
            return .cli
        default:
            return nil
        }
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

    private static func parseReset(_ raw: Any?) throws -> Date? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        guard let string = raw as? String else {
            throw GeminiUsageParseError.invalidReset
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeminiUsageParseError.invalidReset
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: trimmed) {
            return date
        }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: trimmed) {
            return date
        }
        throw GeminiUsageParseError.invalidReset
    }
}

enum GeminiIdentityHelper {
    /// Apps and CLI accountKeys are never merged, even when remaining looks similar.
    static func mergeAccountKeys(
        apps: String,
        cli: String
    ) -> GeminiIdentityMergeRefusal {
        _ = apps
        _ = cli
        return .refusedDistinctFamilies
    }

    static func metersRemainDistinct(
        apps: GeminiUsageFixtureDocument,
        cli: GeminiUsageFixtureDocument
    ) -> Bool {
        apps.family == .apps && cli.family == .cli
    }
}

enum GeminiSourcePresence {
    static func missingAppsMarksCLIUnauthenticated(_ cliPresent: Bool) -> Bool {
        _ = cliPresent
        return false
    }

    static func missingCLIMarksAppsUnauthenticated(_ appsPresent: Bool) -> Bool {
        _ = appsPresent
        return false
    }
}

enum GeminiProductionPolicy {
    static let decision: GeminiProductionDecision = .hold

    static func menuCardFactoryOutput() -> String? {
        nil
    }
}
