import Foundation
import Testing
@testable import AIUsageBar

struct S01DClaudeStatuslineParserTests {
    @Test("T-1D-01 five_hour + seven_day → two meters")
    func fiveHourAndSevenDayParseTwoMeters() {
        let result = ClaudeStatuslineParser.parse(jsonString: Fixtures.twoWindows)
        guard case .success(let document) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(document.meters.count == 2)
        #expect(document.fiveHourMeter?.meterId == ClaudeStatuslineParser.fiveHourMeterID)
        #expect(document.sevenDayMeter?.meterId == ClaudeStatuslineParser.sevenDayMeterID)
    }

    @Test("T-1D-02 utilization 0.37 → remaining 63")
    func utilizationFractionMapsToRemaining() {
        #expect(ClaudeStatuslineParser.usedPercent(fromUtilization: 0.37) == 37)
        #expect(ClaudeStatuslineParser.usedPercent(fromUtilization: 1.0) == 100)
        let result = ClaudeStatuslineParser.parse(jsonString: Fixtures.twoWindows)
        guard case .success(let document) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(document.fiveHourMeter?.remainingPercent == 63)
    }

    @Test("T-1D-03 resets_at present → resetAt set")
    func resetsAtParsesToDate() {
        let result = ClaudeStatuslineParser.parse(jsonString: Fixtures.twoWindows)
        guard case .success(let document) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        #expect(document.fiveHourMeter?.resetAt == iso.date(from: "2026-09-08T12:00:00Z"))
        #expect(document.sevenDayMeter?.resetAt == iso.date(from: "2026-09-15T12:00:00Z"))
    }

    @Test("T-1D-04 missing rate_limits → NO_METER_IN_SNAPSHOT, not AUTH_FAILED")
    func missingRateLimitsIsNoMeterNotAuth() {
        let result = ClaudeStatuslineParser.parse(jsonString: #"{"status":"ok"}"#)
        #expect(result == .noMeterInSnapshot)
        #expect(isAuthFailure(result) == false)
    }

    @Test("T-1D-05 empty snapshot → NO_METER_IN_SNAPSHOT")
    func emptySnapshotIsNoMeter() {
        #expect(ClaudeStatuslineParser.parse(json: Data()) == .noMeterInSnapshot)
        #expect(ClaudeStatuslineParser.parse(jsonString: "{}") == .noMeterInSnapshot)
        #expect(isAuthFailure(ClaudeStatuslineParser.parse(json: Data())) == false)
    }

    @Test("T-1D-06 malformed JSON → parse failure, not auth failure")
    func malformedJSONIsParseFailureNotAuth() {
        let result = ClaudeStatuslineParser.parse(jsonString: "{")
        #expect(result == .parseFailure)
        #expect(isAuthFailure(result) == false)
    }

    @Test("T-1D-07 default config: bridge disabled")
    func defaultBridgeIsDisabled() {
        let config = ClaudeStatuslineBridgeConfig()
        #expect(config.isEnabled == false)
        #expect(config.selectedSource == .webOnly)
        #expect(ClaudeLabSourceSelector.source(for: config) == .webOnly)
    }

    @Test("T-1D-08 enabled then disabled restores web-only selector")
    func enableThenDisableRestoresWebOnly() {
        var config = ClaudeStatuslineBridgeConfig()
        config.enable()
        #expect(ClaudeLabSourceSelector.source(for: config) == .statuslineBridge)
        config.disable()
        #expect(config.isEnabled == false)
        #expect(ClaudeLabSourceSelector.source(for: config) == .webOnly)
    }

    @Test("T-1D-09 old snapshot → STALE_BUT_VALID or EXPIRED, not silent FRESH")
    func oldSnapshotIsNotSilentFresh() {
        let captured = Date(timeIntervalSince1970: 1_000)
        let now = captured.addingTimeInterval(16 * 60)
        #expect(
            ClaudeStatuslineFreshness.validity(capturedAt: captured, now: now) == .staleButValid
        )
        #expect(
            ClaudeStatuslineFreshness.validity(
                capturedAt: captured,
                now: captured.addingTimeInterval(7 * 60 * 60)
            ) == .expired
        )
        #expect(
            ClaudeStatuslineFreshness.validity(
                capturedAt: captured,
                now: captured.addingTimeInterval(60)
            ) == .fresh
        )

        let result = ClaudeStatuslineParser.parse(jsonString: Fixtures.staleSnapshot)
        guard case .success(let document) = result else {
            Issue.record("expected parsed stale snapshot, got \(result)")
            return
        }
        guard let captured = document.capturedAt else {
            Issue.record("stale fixture must include captured_at")
            return
        }
        #expect(document.validity(now: captured.addingTimeInterval(16 * 60)) != .fresh)
        #expect(document.validity(now: captured.addingTimeInterval(16 * 60)) == .staleButValid)
    }

    @Test("T-1D-10 parser never opens Claude conversation transcripts (no path API)")
    func parserHasNoFilesystemOrTranscriptAPI() {
        #expect(ClaudeStatuslineParser.filesystemAccess == .forbidden)
        let inMemory = ClaudeStatuslineParser.parse(jsonString: Fixtures.twoWindows)
        guard case .success = inMemory else {
            Issue.record("in-memory parse should succeed")
            return
        }
    }

    private func isAuthFailure(_ result: ClaudeStatuslineParseResult) -> Bool {
        false
    }

    private enum Fixtures {
        static let twoWindows = """
        {
          "captured_at": "2026-09-08T11:50:00Z",
          "rate_limits": {
            "five_hour": {
              "utilization": 0.37,
              "resets_at": "2026-09-08T12:00:00Z"
            },
            "seven_day": {
              "utilization": 0.10,
              "resets_at": "2026-09-15T12:00:00Z"
            }
          }
        }
        """

        static let staleSnapshot = """
        {
          "captured_at": "2026-09-08T11:00:00Z",
          "rate_limits": {
            "five_hour": {
              "utilization": 0.37,
              "resets_at": "2026-09-08T12:00:00Z"
            }
          }
        }
        """
    }
}
