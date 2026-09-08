import Foundation

enum CursorLabFilesystemAccess: Equatable {
    case forbidden
}

enum CursorProductionDecision: String, Equatable, Sendable {
    case hold = "HOLD"
}

enum CursorUsageParseError: Error, Equatable {
    case malformedJSON
    case missingRemaining
    case invalidReset
}

struct CursorIncludedModel: Equatable, Sendable {
    var name: String
}

struct CursorUsageFixtureDocument: Equatable, Sendable {
    var remainingPercent: Int
    var resetAt: Date?
    var includedModels: [CursorIncludedModel]
}

/// Lab-only Cursor usage fixture parser. Production stays HOLD. Not a menu card.
enum CursorUsageFixtureParser {
    static let filesystemAccess: CursorLabFilesystemAccess = .forbidden
    static let applicationSupportPathHint = "~/Library/Application Support/Cursor"

    static func parse(json: Data) throws -> CursorUsageFixtureDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json, options: [])
        } catch {
            throw CursorUsageParseError.malformedJSON
        }
        guard let dictionary = object as? [String: Any] else {
            throw CursorUsageParseError.malformedJSON
        }
        return try parse(dictionary: dictionary)
    }

    static func parse(jsonString: String) throws -> CursorUsageFixtureDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw CursorUsageParseError.malformedJSON
        }
        return try parse(json: data)
    }

    private static func parse(dictionary: [String: Any]) throws -> CursorUsageFixtureDocument {
        guard let remaining = intPercent(
            dictionary["remaining_percent"] ?? dictionary["remainingPercent"]
        ) else {
            throw CursorUsageParseError.missingRemaining
        }

        let resetAt = try parseReset(dictionary["resets_at"] ?? dictionary["reset_at"])
        let includedModels = includedModels(from: dictionary["included_models"] ?? dictionary["auto_included_models"])

        return CursorUsageFixtureDocument(
            remainingPercent: remaining,
            resetAt: resetAt,
            includedModels: includedModels
        )
    }

    /// Recorded names only. They are not extra user-visible meters.
    static func userVisibleMeters(from document: CursorUsageFixtureDocument) -> [String] {
        _ = document.includedModels
        return []
    }

    private static func includedModels(from raw: Any?) -> [CursorIncludedModel] {
        guard let raw, !(raw is NSNull) else {
            return []
        }
        if let names = raw as? [String] {
            return names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { CursorIncludedModel(name: $0) }
        }
        if let objects = raw as? [[String: Any]] {
            return objects.compactMap { object in
                let name = (object["name"] as? String)
                    ?? (object["model"] as? String)
                    ?? ""
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : CursorIncludedModel(name: trimmed)
            }
        }
        return []
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
            throw CursorUsageParseError.invalidReset
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CursorUsageParseError.invalidReset
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
        throw CursorUsageParseError.invalidReset
    }
}

enum CursorProductionPolicy {
    static let decision: CursorProductionDecision = .hold

    /// HOLD forbids a Cursor menu card. Always `nil`.
    static func menuCardFactoryOutput() -> String? {
        nil
    }

    static func hasProductionUIMapping(in providers: [UsageProvider]) -> Bool {
        false
    }
}

enum CursorLogRedactor {
    static func redactForLog(_ raw: String) -> String {
        CodexLogRedactor.redactForLog(raw)
    }
}
