import Foundation

enum ClaudeLabFilesystemAccess: Equatable {
    case forbidden
}

enum ClaudeStatuslineParseResult: Equatable {
    case success(ClaudeStatuslineDocument)
    case noMeterInSnapshot
    case parseFailure
}

enum ClaudeStatuslineValidity: String, Equatable, Sendable {
    case fresh
    case staleButValid
    case expired
}

enum ClaudeLabSource: String, Equatable, Sendable {
    case webOnly
    case statuslineBridge
}

struct ClaudeStatuslineMeter: Equatable, Sendable {
    var meterId: String
    var remainingPercent: Int
    var resetAt: Date?
}

struct ClaudeStatuslineDocument: Equatable, Sendable {
    var meters: [ClaudeStatuslineMeter]
    var capturedAt: Date?

    var fiveHourMeter: ClaudeStatuslineMeter? {
        meters.first { $0.meterId == ClaudeStatuslineParser.fiveHourMeterID }
    }

    var sevenDayMeter: ClaudeStatuslineMeter? {
        meters.first { $0.meterId == ClaudeStatuslineParser.sevenDayMeterID }
    }

    func validity(now: Date) -> ClaudeStatuslineValidity {
        ClaudeStatuslineFreshness.validity(capturedAt: capturedAt, now: now)
    }
}

/// Lab freshness only. S02 validity constants are not frozen yet.
enum ClaudeStatuslineFreshness {
    static let freshnessTTL: TimeInterval = 15 * 60
    static let expiredTTL: TimeInterval = 6 * 60 * 60

    static func validity(capturedAt: Date?, now: Date) -> ClaudeStatuslineValidity {
        guard let capturedAt else {
            return .staleButValid
        }
        let age = now.timeIntervalSince(capturedAt)
        if age > expiredTTL {
            return .expired
        }
        if age > freshnessTTL {
            return .staleButValid
        }
        return .fresh
    }
}

struct ClaudeStatuslineBridgeConfig: Equatable {
    var isEnabled: Bool = false

    var selectedSource: ClaudeLabSource {
        isEnabled ? .statuslineBridge : .webOnly
    }

    mutating func enable() {
        isEnabled = true
    }

    mutating func disable() {
        isEnabled = false
    }
}

enum ClaudeLabSourceSelector {
    static func source(for config: ClaudeStatuslineBridgeConfig) -> ClaudeLabSource {
        config.selectedSource
    }
}

/// In-memory Claude Code statusline snapshot parser. Lab-only, not a production source.
enum ClaudeStatuslineParser {
    static let fiveHourMeterID = "claude.five_hour"
    static let sevenDayMeterID = "claude.seven_day"
    static let filesystemAccess: ClaudeLabFilesystemAccess = .forbidden

    static func parse(json: Data) -> ClaudeStatuslineParseResult {
        if json.isEmpty {
            return .noMeterInSnapshot
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

        guard let rateLimits = dictionary["rate_limits"] as? [String: Any] else {
            return .noMeterInSnapshot
        }

        do {
            var meters: [ClaudeStatuslineMeter] = []
            if let fiveHour = try windowMeter(rateLimits["five_hour"], meterId: fiveHourMeterID) {
                meters.append(fiveHour)
            }
            if let sevenDay = try windowMeter(rateLimits["seven_day"], meterId: sevenDayMeterID) {
                meters.append(sevenDay)
            }
            if meters.isEmpty {
                return .noMeterInSnapshot
            }
            let capturedAt = try parseOptionalReset(dictionary["captured_at"] ?? dictionary["as_of"])
            return .success(
                ClaudeStatuslineDocument(meters: meters, capturedAt: capturedAt)
            )
        } catch {
            return .parseFailure
        }
    }

    static func parse(jsonString: String) -> ClaudeStatuslineParseResult {
        guard let data = jsonString.data(using: .utf8) else {
            return .parseFailure
        }
        return parse(json: data)
    }

    private static func windowMeter(_ raw: Any?, meterId: String) throws -> ClaudeStatuslineMeter? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        guard let window = raw as? [String: Any] else {
            throw ClaudeStatuslineParseError.malformedWindow
        }
        guard let usedPercent = usedPercent(fromUtilization: window["utilization"]) else {
            throw ClaudeStatuslineParseError.malformedWindow
        }
        let remaining = max(0, 100 - usedPercent)
        let resetAt = try parseOptionalReset(window["resets_at"] ?? window["reset_at"])
        return ClaudeStatuslineMeter(
            meterId: meterId,
            remainingPercent: remaining,
            resetAt: resetAt
        )
    }

    /// 0...1 inclusive is a fraction (0.37 → 37). Values > 1 are already percent.
    static func usedPercent(fromUtilization raw: Any?) -> Int? {
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

        guard let number, number.isFinite, number >= 0 else {
            return nil
        }

        let percent: Double
        if number <= 1 {
            percent = number * 100
        } else {
            percent = number
        }
        return min(100, max(0, Int(percent.rounded())))
    }

    private static func parseOptionalReset(_ raw: Any?) throws -> Date? {
        guard let raw, !(raw is NSNull) else {
            return nil
        }
        guard let string = raw as? String else {
            throw ClaudeStatuslineParseError.invalidReset
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClaudeStatuslineParseError.invalidReset
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

        throw ClaudeStatuslineParseError.invalidReset
    }
}

private enum ClaudeStatuslineParseError: Error {
    case malformedWindow
    case invalidReset
}
