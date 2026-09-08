import Foundation
import Testing
@testable import AIUsageBar

struct S01BCodexRateLimitsParserTests {
    @Test("T-1B-01 Fixture with primary + secondary windows → two candidate meters")
    func primaryAndSecondaryWindowsParseTwoMeters() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.primaryAndSecondary)
        #expect(document.meters.count == 2)
        #expect(document.primaryMeter?.meterId == CodexRateLimitsParser.primaryMeterID)
        #expect(document.secondaryMeter?.meterId == CodexRateLimitsParser.secondaryMeterID)
    }

    @Test("T-1B-02 Missing primary_window → no crash; that meter absent")
    func missingPrimaryWindowOmitsThatMeter() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.secondaryOnly)
        #expect(document.primaryMeter == nil)
        #expect(document.secondaryMeter != nil)
        #expect(document.meters.count == 1)
    }

    @Test("T-1B-03 Missing secondary_window → no crash; that meter absent")
    func missingSecondaryWindowOmitsThatMeter() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.primaryOnly)
        #expect(document.secondaryMeter == nil)
        #expect(document.primaryMeter != nil)
        #expect(document.meters.count == 1)
    }

    @Test("T-1B-04 used_percent → remaining = 100 − used (ChatGPT V1 rule)")
    func usedPercentMapsToV1Remaining() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.primaryAndSecondary)
        #expect(document.primaryMeter?.usedPercent == 40)
        #expect(document.primaryMeter?.remainingPercent == 60)
        #expect(document.secondaryMeter?.usedPercent == 10)
        #expect(document.secondaryMeter?.remainingPercent == 90)
    }

    @Test("T-1B-05 resets_at / documented reset field parses to Date when valid")
    func validISOResetParsesToDate() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.primaryAndSecondary)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        #expect(document.primaryMeter?.resetAt != nil)
        #expect(document.secondaryMeter?.resetAt != nil)
        #expect(document.primaryMeter?.resetAt == iso.date(from: "2026-09-08T12:00:00Z"))
        #expect(document.secondaryMeter?.resetAt == iso.date(from: "2026-09-15T12:00:00Z"))
    }

    @Test("T-1B-06 Invalid / non-ISO reset → parse failure, not a fabricated date")
    func invalidResetFailsClosed() {
        #expect(throws: CodexRateLimitsParseError.invalidReset) {
            _ = try CodexRateLimitsParser.parse(jsonString: Fixtures.invalidReset)
        }
        #expect(throws: CodexRateLimitsParseError.invalidReset) {
            _ = try CodexRateLimitsParser.parse(jsonString: Fixtures.numericReset)
        }
    }

    @Test("T-1B-07 Empty JSON object → parse failure, not empty success")
    func emptyObjectIsParseFailure() {
        #expect(throws: CodexRateLimitsParseError.emptyDocument) {
            _ = try CodexRateLimitsParser.parse(jsonString: "{}")
        }
    }

    @Test("T-1B-08 Malformed JSON → parse failure")
    func malformedJSONIsParseFailure() {
        #expect(throws: CodexRateLimitsParseError.malformedJSON) {
            _ = try CodexRateLimitsParser.parse(jsonString: "{")
        }
        #expect(throws: CodexRateLimitsParseError.malformedJSON) {
            _ = try CodexRateLimitsParser.parse(jsonString: "not-json")
        }
    }

    @Test("T-1B-09 Extra unknown fields are ignored")
    func extraUnknownFieldsAreIgnored() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.unknownFields)
        #expect(document.meters.count == 1)
        #expect(document.primaryMeter?.remainingPercent == 75)
    }

    @Test("T-1B-10 Limitless / null limit does not invent a remaining percent")
    func limitlessDoesNotInventRemaining() throws {
        let document = try CodexRateLimitsParser.parse(jsonString: Fixtures.limitlessWithoutUsed)
        #expect(document.primaryMeter != nil)
        #expect(document.primaryMeter?.limitIsLimitless == true)
        #expect(document.primaryMeter?.remainingPercent == nil)
        #expect(document.primaryMeter?.usedPercent == nil)
    }

    @Test("T-1B-11 Redaction helper strips tokens / emails before any log string")
    func redactionHelperStripsSecrets() {
        let raw = """
        user=lab@example.com token=sk-live-REDACTEDFIXTUREONLY \
        Authorization=Bearer eyJhbGciOi-not-a-real-jwt session-token=abc.def
        """
        let redacted = CodexLogRedactor.redactForLog(raw)
        #expect(redacted.contains("lab@example.com") == false)
        #expect(redacted.contains("sk-live-REDACTEDFIXTUREONLY") == false)
        #expect(redacted.contains("eyJhbGciOi-not-a-real-jwt") == false)
        #expect(redacted.contains("abc.def") == false)
        #expect(redacted.contains("[redacted-email]"))
        #expect(redacted.contains("[redacted-token]"))
    }

    @Test("T-1B-12 Parser does not read ~/.codex/ (no file-path API)")
    func parserHasNoFilesystemAPI() throws {
        #expect(CodexRateLimitsParser.filesystemAccess == .forbidden)
        let inMemory = try CodexRateLimitsParser.parse(jsonString: Fixtures.primaryOnly)
        #expect(inMemory.primaryMeter != nil)
    }

    private enum Fixtures {
        static let primaryAndSecondary = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 40,
              "resets_at": "2026-09-08T12:00:00Z",
              "limit": 100
            },
            "secondary_window": {
              "used_percent": 10,
              "reset_at": "2026-09-15T12:00:00Z",
              "limit": 100
            }
          }
        }
        """

        static let primaryOnly = """
        {
          "rateLimits": {
            "primary_window": {
              "used_percent": 55,
              "resets_at": "2026-09-08T12:00:00Z"
            }
          }
        }
        """

        static let secondaryOnly = """
        {
          "rate_limit": {
            "secondary_window": {
              "used_percent": 12
            }
          }
        }
        """

        static let invalidReset = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 1,
              "resets_at": "tomorrow-ish"
            }
          }
        }
        """

        static let numericReset = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 1,
              "reset_at": 1700000000
            }
          }
        }
        """

        static let unknownFields = """
        {
          "account": { "plan": "lab-fixture" },
          "rate_limit": {
            "primary_window": {
              "used_percent": 25,
              "mystery_counter": 9
            },
            "tertiary_window": { "used_percent": 1 }
          },
          "debug_blob": { "ok": true }
        }
        """

        static let limitlessWithoutUsed = """
        {
          "rate_limit": {
            "primary_window": {
              "limit": "limitless",
              "used_percent": null
            }
          }
        }
        """
    }
}
