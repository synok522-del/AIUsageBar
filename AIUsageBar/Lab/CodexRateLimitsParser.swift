import Foundation

/// Lab-only Codex / ChatGPT rate-limit challenger. Not a production source.
enum CodexParserFilesystemAccess: Equatable {
    case forbidden
}

enum CodexRateLimitsParseError: Error, Equatable {
    case malformedJSON
    case emptyDocument
    case missingRateLimitObject
    case invalidReset
}

struct CodexCandidateMeter: Equatable, Sendable {
    var meterId: String
    var usedPercent: Int?
    var remainingPercent: Int?
    var resetAt: Date?
    var limitIsLimitless: Bool
}

struct CodexRateLimitsDocument: Equatable, Sendable {
    var meters: [CodexCandidateMeter]

    var primaryMeter: CodexCandidateMeter? {
        meters.first { $0.meterId == CodexRateLimitsParser.primaryMeterID }
    }

    var secondaryMeter: CodexCandidateMeter? {
        meters.first { $0.meterId == CodexRateLimitsParser.secondaryMeterID }
    }
}

/// In-memory JSON parser for redacted Codex `rateLimits` fixtures.
/// There is no `parse(path:)`, no `FileManager` use, and no `~/.codex/` access.
enum CodexRateLimitsParser {
    static let primaryMeterID = "codex.primary_window"
    static let secondaryMeterID = "codex.secondary_window"
    static let filesystemAccess: CodexParserFilesystemAccess = .forbidden

    static func parse(json: Data) throws -> CodexRateLimitsDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json, options: [])
        } catch {
            throw CodexRateLimitsParseError.malformedJSON
        }

        guard let dictionary = object as? [String: Any] else {
            throw CodexRateLimitsParseError.malformedJSON
        }

        if dictionary.isEmpty {
            throw CodexRateLimitsParseError.emptyDocument
        }

        guard let rateLimit = rateLimitObject(from: dictionary) else {
            throw CodexRateLimitsParseError.missingRateLimitObject
        }

        var meters: [CodexCandidateMeter] = []
        if let primary = try windowMeter(
            rateLimit["primary_window"],
            meterId: primaryMeterID
        ) {
            meters.append(primary)
        }
        if let secondary = try windowMeter(
            rateLimit["secondary_window"],
            meterId: secondaryMeterID
        ) {
            meters.append(secondary)
        }

        return CodexRateLimitsDocument(meters: meters)
    }

    static func parse(jsonString: String) throws -> CodexRateLimitsDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw CodexRateLimitsParseError.malformedJSON
        }
        return try parse(json: data)
    }

    private static func rateLimitObject(from dictionary: [String: Any]) -> [String: Any]? {
        if let rateLimit = dictionary["rate_limit"] as? [String: Any] {
            return rateLimit
        }
        if let rateLimits = dictionary["rateLimits"] as? [String: Any] {
            return rateLimits
        }
        return nil
    }

    private static func windowMeter(_ raw: Any?, meterId: String) throws -> CodexCandidateMeter? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        guard let window = raw as? [String: Any] else {
            throw CodexRateLimitsParseError.malformedJSON
        }

        let usedPercent = optionalPercent(window["used_percent"])
        let remainingPercent = usedPercent.map { max(0, 100 - $0) }
        let limitIsLimitless = isLimitless(window["limit"])
        let resetAt = try parseReset(window["resets_at"] ?? window["reset_at"])

        return CodexCandidateMeter(
            meterId: meterId,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetAt: resetAt,
            limitIsLimitless: limitIsLimitless
        )
    }

    private static func optionalPercent(_ raw: Any?) -> Int? {
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

        let rounded = Int(number.rounded())
        return min(100, max(0, rounded))
    }

    private static func isLimitless(_ raw: Any?) -> Bool {
        if raw == nil || raw is NSNull {
            return true
        }
        if let string = raw as? String {
            let folded = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return folded == "limitless" || folded == "unlimited"
        }
        return false
    }

    private static func parseReset(_ raw: Any?) throws -> Date? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        guard let string = raw as? String else {
            throw CodexRateLimitsParseError.invalidReset
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CodexRateLimitsParseError.invalidReset
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

        throw CodexRateLimitsParseError.invalidReset
    }
}

enum CodexLogRedactor {
    static func redactForLog(_ raw: String) -> String {
        var redacted = raw
        redacted = replace(
            in: redacted,
            pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
            template: "[redacted-email]",
            options: [.caseInsensitive]
        )
        redacted = replace(
            in: redacted,
            pattern: #"(?i)bearer\s+[A-Za-z0-9._\-+=/]+"#,
            template: "Bearer [redacted-token]"
        )
        redacted = replace(
            in: redacted,
            pattern: #"sk-[A-Za-z0-9_-]+"#,
            template: "[redacted-token]"
        )
        redacted = replace(
            in: redacted,
            pattern: #"(?i)(session[-_]?token\s*[:=]\s*)\S+"#,
            template: "$1[redacted-token]"
        )
        return redacted
    }

    private static func replace(
        in source: String,
        pattern: String,
        template: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return source
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.stringByReplacingMatches(
            in: source,
            options: [],
            range: range,
            withTemplate: template
        )
    }
}
