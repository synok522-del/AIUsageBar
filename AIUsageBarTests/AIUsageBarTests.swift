//
//  AIUsageBarTests.swift
//  AIUsageBarTests
//
//  Created by Kenny Hung on 2026/8/16.
//

import Foundation
import Testing
@testable import AIUsageBar

struct AIUsageBarTests {

    @Test("ServiceSupport.percent clamps and rounds values")
    func percentCoversBoundaryNumericAndInvalidValues() {
        #expect(ServiceSupport.percent(0) == 0)
        #expect(ServiceSupport.percent(100) == 100)
        #expect(ServiceSupport.percent(-25) == 0)
        #expect(ServiceSupport.percent(125) == 100)
        #expect(ServiceSupport.percent("42.4") == 42)
        #expect(ServiceSupport.percent("42.6") == 43)
        #expect(ServiceSupport.percent("not-a-number") == 0)
        #expect(ServiceSupport.percent(nil) == 0)
    }

    @Test("ServiceSupport.resetText parses timestamps and ISO8601 dates")
    func resetTextParsesSupportedDateFormats() {
        let unix = ServiceSupport.resetText(1_700_000_000)
        let milliseconds = ServiceSupport.resetText("1700000000000")
        let fractionalISO8601 = ServiceSupport.resetText("2026-08-18T12:34:56.789Z")

        #expect(unix.hasPrefix("重置於 "))
        #expect(milliseconds.hasPrefix("重置於 "))
        #expect(fractionalISO8601.hasPrefix("重置於 "))
        #expect(ServiceSupport.resetText("invalid-date").isEmpty)
        #expect(ServiceSupport.resetText(nil).isEmpty)
        #expect(ServiceSupport.resetText(["unsupported": true]).isEmpty)
    }

    @Test("CookieTokenAssembler prefers exact cookies and joins numbered chunks")
    func cookieTokenAssemblerHandlesExactAndChunkedCookies() throws {
        let exact = try #require(cookie(name: "session-token", value: "exact"))
        let chunkOne = try #require(cookie(name: "chunked.1", value: "-two"))
        let chunkZero = try #require(cookie(name: "chunked.0", value: "one"))
        let otherDomain = try #require(cookie(name: "chunked.2", value: "ignored", domain: "example.com"))

        let exactValue = CookieTokenAssembler.value(
            from: [chunkOne, chunkZero, exact],
            baseNames: ["session-token"],
            domainMatcher: { $0 == "chatgpt.com" }
        )
        let chunkedValue = CookieTokenAssembler.value(
            from: [chunkOne, chunkZero, otherDomain],
            baseNames: ["chunked"],
            domainMatcher: { $0 == "chatgpt.com" }
        )
        let missingValue = CookieTokenAssembler.value(
            from: [otherDomain],
            baseNames: ["missing"],
            domainMatcher: { _ in true }
        )

        #expect(exactValue == "exact")
        #expect(chunkedValue == "one-two")
        #expect(missingValue == nil)
    }

    @Test("Claude usage parsing returns remaining percentages")
    func claudeUsageParsingHandlesBoundariesAndDateFields() {
        let usage: [String: [String: Any]] = [
            "five_hour": [
                "utilization": "0",
                "resets_at": "2026-08-18T12:34:56.789Z"
            ],
            "seven_day": [
                "utilization": 100,
                "resets_at": 1_700_000_000
            ]
        ]

        let parsed = ClaudeService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 100)
        #expect(parsed.weeklyRemainingPercent == 0)
        #expect(parsed.resetText.hasPrefix("重置於 "))
    }

    @Test("Claude usage parsing handles missing payload values")
    func claudeUsageParsingHandlesMissingValues() {
        let parsed = ClaudeService.parseUsage([:])

        #expect(parsed.sessionRemainingPercent == 100)
        #expect(parsed.weeklyRemainingPercent == 100)
        #expect(parsed.resetText.isEmpty)
    }

    @Test("ChatGPT usage parsing returns remaining percentages")
    func chatGPTUsageParsingHandlesBoundariesAndDateFields() {
        let usage: [String: Any] = [
            "rate_limit": [
                "primary_window": [
                    "used_percent": "100",
                    "reset_at": "1700000000000"
                ]
            ]
        ]

        let parsed = ChatGPTService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 0)
        #expect(parsed.resetText.hasPrefix("重置於 "))
    }

    @Test("ChatGPT usage parsing handles missing payload values")
    func chatGPTUsageParsingHandlesMissingValues() {
        let parsed = ChatGPTService.parseUsage([:])

        #expect(parsed.sessionRemainingPercent == 100)
        #expect(parsed.resetText == "無限制資料")
    }

    @Test("Low usage notification triggers at the threshold")
    func lowUsageNotificationTriggersAtTwentyPercent() {
        var state = UsageNotificationState()

        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("Low usage notification triggers below the threshold")
    func lowUsageNotificationTriggersBelowTwentyPercent() {
        var state = UsageNotificationState()

        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 19,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("Disabled notifications do not consume a threshold crossing")
    func lowUsageNotificationPreservesCrossingWhileDisabled() {
        var state = UsageNotificationState()

        #expect(state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false,
            notificationsEnabled: true
        ) == false)
        #expect(state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: 15,
            isLoaded: true,
            hasError: false,
            notificationsEnabled: false
        ) == false)
        #expect(state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: 15,
            isLoaded: true,
            hasError: false,
            notificationsEnabled: true
        ) == true)
        #expect(state.shouldNotifyIfEnabled(
            for: .claude,
            remainingPercent: 15,
            isLoaded: true,
            hasError: false,
            notificationsEnabled: true
        ) == false)
    }

    @Test("Low usage notification does not repeat while usage stays low")
    func lowUsageNotificationDoesNotRepeatWhileLow() {
        var state = UsageNotificationState()

        _ = state.shouldNotify(
            for: .claude,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        )
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 15,
            isLoaded: true,
            hasError: false
        ) == false)
    }

    @Test("Recovery above the threshold resets notification state")
    func lowUsageNotificationResetsAfterRecovery() {
        var state = UsageNotificationState()

        _ = state.shouldNotify(
            for: .claude,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        )
        _ = state.shouldNotify(
            for: .claude,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        )
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 10,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 100,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("Unloaded and error states do not trigger notifications")
    func lowUsageNotificationIgnoresUnavailableUsage() {
        var state = UsageNotificationState()

        _ = state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 30,
            isLoaded: true,
            hasError: false
        )
        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 10,
            isLoaded: false,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .chatGPT,
            remainingPercent: 10,
            isLoaded: true,
            hasError: true
        ) == false)
    }

    private func cookie(
        name: String,
        value: String,
        domain: String = "chatgpt.com"
    ) -> HTTPCookie? {
        HTTPCookie(properties: [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: value
        ])
    }

}
