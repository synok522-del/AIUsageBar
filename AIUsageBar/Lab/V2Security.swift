import Foundation

enum V2ForeignCookieReuse {
    /// Tier 6 foreign-cookie reuse is not enabled.
    static let enabled = false
}

enum V2LogRedactor {
    static func redactForLog(_ raw: String) -> String {
        var redacted = CodexLogRedactor.redactForLog(raw)
        redacted = replace(
            in: redacted,
            pattern: #"(?i)(Cookie:\s*)([^\r\n]+)"#,
            template: "$1[redacted-cookie]"
        )
        redacted = replace(
            in: redacted,
            pattern: #"(?i)(sso=)[^\s;]+"#,
            template: "$1[redacted-cookie]"
        )
        redacted = replace(
            in: redacted,
            pattern: #"(?i)(__Secure-next-auth\.session-token=)[^\s;]+"#,
            template: "$1[redacted-cookie]"
        )
        redacted = replace(
            in: redacted,
            pattern: #"(?i)(sessionKey=)[^\s;]+"#,
            template: "$1[redacted-cookie]"
        )
        return redacted
    }

    private static func replace(
        in source: String,
        pattern: String,
        template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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

enum V2SecuritySurface {
    static func usageSourceSourceURL(from testFilePath: String) -> URL {
        URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Lab/V2UsageSources.swift")
    }

    static func codexParserSourceURL(from testFilePath: String) -> URL {
        URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Lab/CodexRateLimitsParser.swift")
    }

    static func cursorParserSourceURL(from testFilePath: String) -> URL {
        URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar/Lab/CursorUsageFixtureParser.swift")
    }
}
