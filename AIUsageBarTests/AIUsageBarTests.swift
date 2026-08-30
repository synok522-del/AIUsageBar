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

    @Test("Welcome shows when both providers are logged out")
    func welcomeShowsWhenBothProvidersAreLoggedOut() {
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: false,
            isChatGPTLoggedIn: false,
            isSuppressedForCurrentSession: false
        ).shouldShow)
    }

    @Test("Welcome stays hidden when ChatGPT is logged in")
    func welcomeStaysHiddenWhenChatGPTIsLoggedIn() {
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: false,
            isChatGPTLoggedIn: true,
            isSuppressedForCurrentSession: false
        ).shouldShow == false)
    }

    @Test("Welcome stays hidden when Claude or both providers are logged in")
    func welcomeStaysHiddenWhenClaudeOrBothProvidersAreLoggedIn() {
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: true,
            isChatGPTLoggedIn: false,
            isSuppressedForCurrentSession: false
        ).shouldShow == false)
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: true,
            isChatGPTLoggedIn: true,
            isSuppressedForCurrentSession: false
        ).shouldShow == false)
    }

    @Test("Later suppresses Welcome only for the current session")
    func welcomeSuppressionIsSessionOnly() {
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: false,
            isChatGPTLoggedIn: false,
            isSuppressedForCurrentSession: true
        ).shouldShow == false)
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: false,
            isChatGPTLoggedIn: false,
            isSuppressedForCurrentSession: false
        ).shouldShow)
    }

    @Test("Provider visibility shows only authenticated ChatGPT")
    func providerVisibilityShowsOnlyAuthenticatedChatGPT() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )

        #expect(policy.visibleProviders == [.chatGPT])
        #expect(policy.isVisible(.chatGPT))
        #expect(policy.isVisible(.claude) == false)
        #expect(policy.shouldShowSetupState == false)
    }

    @Test("Provider visibility shows only authenticated Claude")
    func providerVisibilityShowsOnlyAuthenticatedClaude() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: true
        )

        #expect(policy.visibleProviders == [.claude])
        #expect(policy.isVisible(.chatGPT) == false)
        #expect(policy.isVisible(.claude))
        #expect(policy.shouldShowSetupState == false)
    }

    @Test("Provider visibility preserves ChatGPT then Claude order")
    func providerVisibilityPreservesProviderOrder() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true
        )

        #expect(policy.visibleProviders == [.chatGPT, .claude])
        #expect(policy.shouldShowSetupState == false)
    }

    @Test("Provider visibility shows setup state when both are unauthenticated")
    func providerVisibilityShowsSetupStateWhenBothUnauthenticated() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: false
        )

        #expect(policy.visibleProviders.isEmpty)
        #expect(policy.shouldShowSetupState)
    }

    @Test("Authenticated ChatGPT remains visible when usage is not loaded")
    func authenticatedChatGPTRemainsVisibleWhenUsageIsNotLoaded() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )
        let usage = UsageInfo(isLoaded: false, errorMessage: "更新失敗")

        #expect(usage.isLoaded == false)
        #expect(policy.isVisible(.chatGPT))
    }

    @Test("Authenticated Claude remains visible when usage is not loaded")
    func authenticatedClaudeRemainsVisibleWhenUsageIsNotLoaded() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: true
        )
        let usage = UsageInfo(isLoaded: false, errorMessage: "更新失敗")

        #expect(usage.isLoaded == false)
        #expect(policy.isVisible(.claude))
    }

    @Test("Authenticated provider remains visible with stale usage data")
    func authenticatedProviderRemainsVisibleWithStaleUsageData() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )
        let usage = UsageInfo(
            sessionPercent: 42,
            isLoaded: true,
            errorMessage: "暫時無法更新"
        )

        #expect(usage.isLoaded)
        #expect(usage.errorMessage != nil)
        #expect(policy.isVisible(.chatGPT))
    }

    @Test("Logging out ChatGPT hides only its provider")
    func loggingOutChatGPTHidesOnlyItsProvider() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: true
        )

        #expect(policy.isVisible(.chatGPT) == false)
        #expect(policy.isVisible(.claude))
        #expect(policy.visibleProviders == [.claude])
    }

    @Test("Logging out Claude hides only its provider")
    func loggingOutClaudeHidesOnlyItsProvider() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )

        #expect(policy.isVisible(.claude) == false)
        #expect(policy.isVisible(.chatGPT))
        #expect(policy.visibleProviders == [.chatGPT])
    }

    @Test("Logging out the last provider shows setup state")
    func loggingOutLastProviderShowsSetupState() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: false
        )

        #expect(policy.visibleProviders.isEmpty)
        #expect(policy.shouldShowSetupState)
    }

    @Test("Zero remaining quota does not hide an authenticated provider")
    func zeroRemainingQuotaDoesNotHideAuthenticatedProvider() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true
        )
        let chatGPTUsage = UsageInfo(sessionPercent: 0, weeklyPercent: 0, isLoaded: true)
        let claudeUsage = UsageInfo(sessionPercent: 0, weeklyPercent: 0, isLoaded: true)

        #expect(chatGPTUsage.sessionPercent == 0)
        #expect(claudeUsage.sessionPercent == 0)
        #expect(policy.visibleProviders == [.chatGPT, .claude])
    }

    @Test("Shared visibility policy maps existing session credentials")
    func sharedVisibilityPolicyMapsExistingSessionCredentials() {
        #expect(
            ProviderVisibilityPolicy(
                chatGPTSessionToken: "configured",
                claudeSessionKey: ""
            ).visibleProviders == [.chatGPT]
        )
        #expect(
            ProviderVisibilityPolicy(
                chatGPTSessionToken: "",
                claudeSessionKey: "configured"
            ).visibleProviders == [.claude]
        )
        #expect(
            ProviderVisibilityPolicy(
                chatGPTSessionToken: "configured",
                claudeSessionKey: "configured"
            ).visibleProviders == [.chatGPT, .claude]
        )
    }

    @Test("Shared visibility policy has no indicators for empty credentials")
    func sharedVisibilityPolicyHasNoIndicatorsForEmptyCredentials() {
        let policy = ProviderVisibilityPolicy(
            chatGPTSessionToken: "",
            claudeSessionKey: ""
        )

        #expect(policy.visibleProviders.isEmpty)
        #expect(policy.shouldShowSetupState)
    }

    @Test("Shared visibility policy ignores usage state")
    func sharedVisibilityPolicyIgnoresUsageState() {
        let policy = ProviderVisibilityPolicy(
            chatGPTSessionToken: "configured",
            claudeSessionKey: "configured"
        )
        let failedChatGPT = UsageInfo(
            sessionPercent: 0,
            isLoaded: false,
            errorMessage: "更新失敗"
        )
        let failedClaude = UsageInfo(
            sessionPercent: 0,
            isLoaded: false,
            errorMessage: "更新失敗"
        )

        #expect(failedChatGPT.isLoaded == false)
        #expect(failedClaude.isLoaded == false)
        #expect(policy.visibleProviders == [.chatGPT, .claude])
    }

    @Test("Shared visibility policy keeps zero-quota providers visible")
    func sharedVisibilityPolicyKeepsZeroQuotaProvidersVisible() {
        let policy = ProviderVisibilityPolicy(
            chatGPTSessionToken: "configured",
            claudeSessionKey: "configured"
        )
        let chatGPT = UsageInfo(sessionPercent: 0, isLoaded: true)
        let claude = UsageInfo(sessionPercent: 0, isLoaded: true)

        #expect(chatGPT.sessionPercent == 0)
        #expect(claude.sessionPercent == 0)
        #expect(policy.visibleProviders == [.chatGPT, .claude])
    }

    @Test("Shared visibility policy reflects last-provider logout")
    func sharedVisibilityPolicyReflectsLastProviderLogout() {
        let policy = ProviderVisibilityPolicy(
            chatGPTSessionToken: "",
            claudeSessionKey: ""
        )

        #expect(policy.visibleProviders.isEmpty)
        #expect(policy.shouldShowSetupState)
    }

    @Test("Menu bar help text identifies ChatGPT only")
    func menuBarHelpTextIdentifiesChatGPTOnly() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )

        #expect(policy.menuBarHelpText == "ChatGPT 剩餘用量")
    }

    @Test("Menu bar help text identifies Claude only")
    func menuBarHelpTextIdentifiesClaudeOnly() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: true
        )

        #expect(policy.menuBarHelpText == "Claude 剩餘用量")
    }

    @Test("Menu bar help text identifies both providers")
    func menuBarHelpTextIdentifiesBothProviders() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true
        )

        #expect(policy.menuBarHelpText == "ChatGPT 與 Claude 剩餘用量")
    }

    @Test("Menu bar help text identifies an unconfigured app")
    func menuBarHelpTextIdentifiesUnconfiguredApp() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: false
        )

        #expect(policy.menuBarHelpText == "AIUsageBar")
    }

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

        let exactCredential = CookieTokenAssembler.credential(
            from: [chunkOne, chunkZero, exact],
            baseNames: ["session-token"],
            domainMatcher: { $0 == "chatgpt.com" }
        )
        let chunkedCredential = CookieTokenAssembler.credential(
            from: [chunkOne, chunkZero, otherDomain],
            baseNames: ["chunked"],
            domainMatcher: { $0 == "chatgpt.com" }
        )
        let missingValue = CookieTokenAssembler.value(
            from: [otherDomain],
            baseNames: ["missing"],
            domainMatcher: { _ in true }
        )

        #expect(exactCredential?.cookieName == "session-token")
        #expect(exactCredential?.value == "exact")
        #expect(exactCredential?.cookieHeader == "session-token=exact")
        #expect(chunkedCredential?.cookieName == "chunked")
        #expect(chunkedCredential?.value == "one-two")
        #expect(chunkedCredential?.cookieHeader == "chunked.0=one; chunked.1=-two")
        #expect(missingValue == nil)
    }

    @Test("ChatGPT credential preserves the cookie name used by WebKit")
    func chatGPTCredentialPreservesCookieName() throws {
        let hostCookie = try #require(cookie(
            name: "__Host-next-auth.session-token",
            value: "host-token"
        ))

        let credential = try #require(
            WebLoginProvider.chatGPT.credential(from: [hostCookie])
        )

        #expect(credential.cookieName == "__Host-next-auth.session-token")
        #expect(credential.value == "host-token")
        #expect(credential.cookieHeader == "__Host-next-auth.session-token=host-token")
    }

    @Test("Provider cookie matching accepts only exact domains and subdomains")
    func providerCookieMatchingIsStrict() {
        #expect(WebSessionProvider.chatGPT.matches("chatgpt.com"))
        #expect(WebSessionProvider.chatGPT.matches("auth.chatgpt.com"))
        #expect(WebSessionProvider.chatGPT.matches(".openai.com"))
        #expect(WebSessionProvider.chatGPT.matches("notchatgpt.com") == false)
        #expect(WebSessionProvider.chatGPT.matches("chatgpt.com.evil") == false)
        #expect(WebSessionProvider.claude.matches("anthropic.com.evil") == false)
        #expect(WebSessionProvider.grok.matches("grok.com"))
        #expect(WebSessionProvider.grok.matches("accounts.x.ai"))
        #expect(WebSessionProvider.grok.matches("x.ai"))
        #expect(WebSessionProvider.grok.matches("x.com") == false)
        #expect(WebSessionProvider.grok.matches("notgrok.com") == false)
        #expect(WebSessionProvider.matchesGrokProductHost("grok.com"))
        #expect(WebSessionProvider.matchesGrokProductHost("x.ai") == false)
        #expect(WebSessionProvider.matchesGrokProductHost("x.com") == false)
    }

    @Test("Refresh timestamp updates only after a provider succeeds")
    func refreshTimestampRequiresSuccessfulProviderRefresh() {
        #expect(
            UsageRefreshStatePolicy.shouldUpdateLastUpdated(
                claudeSucceeded: false,
                chatGPTSucceeded: false
            ) == false
        )
        #expect(
            UsageRefreshStatePolicy.shouldUpdateLastUpdated(
                claudeSucceeded: true,
                chatGPTSucceeded: false
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldUpdateLastUpdated(
                claudeSucceeded: false,
                chatGPTSucceeded: true
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldUpdateLastUpdated(
                claudeSucceeded: false,
                chatGPTSucceeded: false,
                grokSucceeded: true
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldUpdateLastUpdated(
                claudeSucceeded: false,
                chatGPTSucceeded: false,
                grokSucceeded: false
            ) == false
        )
    }

    @Test("Successful refresh clears only its provider status message")
    func successfulRefreshClearsProviderStatusMessage() {
        #expect(
            UsageRefreshStatePolicy.shouldClearStatusMessage(
                "Claude：登入已失效",
                for: "Claude"
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldClearStatusMessage(
                "Claude 登入成功",
                for: "Claude"
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldClearStatusMessage(
                "ChatGPT：登入已失效",
                for: "Claude"
            ) == false
        )
    }

    @Test("Claude usage parsing returns remaining percentages")
    func claudeUsageParsingHandlesBoundariesAndDateFields() throws {
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

        let parsed = try ClaudeService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 100)
        #expect(parsed.weeklyRemainingPercent == 0)
        #expect(parsed.resetText.hasPrefix("重置於 "))
        #expect(!parsed.weeklyResetText.hasPrefix("重置於 "))
    }

    @Test("Claude reset fields remain separate when session reset is missing")
    func claudeUsageParsingDoesNotFallbackToWeeklyReset() throws {
        let usage: [String: [String: Any]] = [
            "five_hour": [
                "utilization": 10
            ],
            "seven_day": [
                "utilization": 20,
                "resets_at": 1_700_000_000
            ]
        ]

        let parsed = try ClaudeService.parseUsage(usage)
        let combined = ServiceSupport.combinedResetText(
            session: parsed.resetText,
            weekly: parsed.weeklyResetText
        )

        #expect(parsed.sessionRemainingPercent == 90)
        #expect(parsed.weeklyRemainingPercent == 80)
        #expect(parsed.resetText.isEmpty)
        #expect(!parsed.weeklyResetText.isEmpty)
        #expect(combined == "重置於 \(parsed.weeklyResetText)")
        #expect(!combined.contains("｜"))
    }

    @Test("Claude usage parsing handles missing payload values")
    func claudeUsageParsingRejectsMissingValues() {
        #expect(throws: AIUsageServiceError.self) {
            _ = try ClaudeService.parseUsage([:])
        }
    }

    @Test("Claude usage parsing rejects malformed required numbers")
    func claudeUsageParsingRejectsMalformedRequiredNumbers() {
        let usage: [String: [String: Any]] = [
            "five_hour": ["utilization": "not-a-number"],
            "seven_day": ["utilization": 0]
        ]

        #expect(throws: AIUsageServiceError.self) {
            _ = try ClaudeService.parseUsage(usage)
        }
    }

    @Test("ChatGPT usage parsing returns remaining percentages")
    func chatGPTUsageParsingHandlesBoundariesAndDateFields() throws {
        let usage: [String: Any] = [
            "rate_limit": [
                "primary_window": [
                    "used_percent": "100",
                    "reset_at": "1700000000000"
                ]
            ]
        ]

        let parsed = try ChatGPTService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 0)
        #expect(parsed.resetText.hasPrefix("重置於 "))
    }

    @Test("ChatGPT usage parsing handles missing payload values")
    func chatGPTUsageParsingRejectsMissingValues() {
        #expect(throws: AIUsageServiceError.self) {
            _ = try ChatGPTService.parseUsage([:])
        }
    }

    @Test("ChatGPT usage parsing rejects malformed required numbers")
    func chatGPTUsageParsingRejectsMalformedRequiredNumbers() {
        let usage: [String: Any] = [
            "rate_limit": [
                "primary_window": [
                    "used_percent": "not-a-number"
                ]
            ]
        ]

        #expect(throws: AIUsageServiceError.self) {
            _ = try ChatGPTService.parseUsage(usage)
        }
    }

    @Test("ChatGPT usage parsing preserves a valid zero percent used value")
    func chatGPTUsageParsingHandlesZeroUsedPercent() throws {
        let usage: [String: Any] = [
            "rate_limit": [
                "primary_window": [
                    "used_percent": 0
                ]
            ]
        ]

        let parsed = try ChatGPTService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 100)
    }

    @Test("ChatGPT usage parsing reads primary and weekly windows")
    func chatGPTUsageParsingHandlesDualWindows() throws {
        let usage: [String: Any] = [
            "rate_limit": [
                "primary_window": [
                    "used_percent": "21",
                    "reset_at": 1_700_000_000
                ],
                "secondary_window": [
                    "used_percent": "3",
                    "reset_at": "1788317863",
                    "limit_window_seconds": 604_800,
                    "reset_after_seconds": 588_630
                ]
            ]
        ]

        let parsed = try ChatGPTService.parseUsage(usage)

        #expect(parsed.sessionRemainingPercent == 79)
        #expect(parsed.weeklyRemainingPercent == 97)
        #expect(parsed.weeklyResetText != nil)
        #expect(!(parsed.weeklyResetText ?? "").isEmpty)
    }

    @Test("ChatGPT weekly zero percent remains available")
    func chatGPTWeeklyZeroPercentRemainsAvailable() throws {
        let zeroUsed: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": [
                    "used_percent": 0,
                    "reset_at": "not-a-date"
                ]
            ]
        ]
        let fullyUsed: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": [
                    "used_percent": 100,
                    "reset_at": "not-a-date"
                ]
            ]
        ]

        let zeroParsed = try ChatGPTService.parseUsage(zeroUsed)
        let fullyUsedParsed = try ChatGPTService.parseUsage(fullyUsed)

        #expect(zeroParsed.weeklyRemainingPercent == 100)
        #expect(zeroParsed.weeklyResetText == nil)
        #expect(fullyUsedParsed.weeklyRemainingPercent == 0)
        #expect(fullyUsedParsed.weeklyResetText == nil)
    }

    @Test("ChatGPT weekly percentage clamps numeric strings and out-of-range values")
    func chatGPTWeeklyPercentageClampsValues() throws {
        let belowRange: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": ["used_percent": "-25"]
            ]
        ]
        let aboveRange: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": ["used_percent": "125"]
            ]
        ]

        #expect(try ChatGPTService.parseUsage(belowRange).weeklyRemainingPercent == 100)
        #expect(try ChatGPTService.parseUsage(aboveRange).weeklyRemainingPercent == 0)
    }

    @Test("ChatGPT weekly data is optional without breaking primary usage")
    func chatGPTWeeklyDataIsOptional() throws {
        let missingWindow: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21]
            ]
        ]
        let missingValue: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": [:]
            ]
        ]
        let malformedValue: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 21],
                "secondary_window": ["used_percent": "invalid"]
            ]
        ]

        for usage in [missingWindow, missingValue, malformedValue] {
            let parsed = try ChatGPTService.parseUsage(usage)
            #expect(parsed.sessionRemainingPercent == 79)
            #expect(parsed.weeklyRemainingPercent == nil)
            #expect(parsed.weeklyResetText == nil)
        }
    }

    @Test("ChatGPT weekly reset supports seconds, milliseconds, and fractional ISO8601")
    func chatGPTWeeklyResetParsesSupportedDateFormats() throws {
        let values: [Any] = [
            1_700_000_000,
            "1700000000000",
            "2023-11-14T22:13:20.123Z"
        ]

        for value in values {
            let usage: [String: Any] = [
                "rate_limit": [
                    "primary_window": ["used_percent": 21],
                    "secondary_window": [
                        "used_percent": 3,
                        "reset_at": value
                    ]
                ]
            ]

            let parsed = try ChatGPTService.parseUsage(usage)
            #expect(parsed.weeklyRemainingPercent == 97)
            #expect(parsed.weeklyResetText != nil)
            #expect(!(parsed.weeklyResetText ?? "").isEmpty)
        }

        let fixedLocale = Locale(identifier: "zh_TW")
        let fixedTimeZone = TimeZone(secondsFromGMT: 0)!
        let expected = ServiceSupport.absoluteResetText(
            1_700_000_000,
            locale: fixedLocale,
            timeZone: fixedTimeZone
        )

        #expect(ServiceSupport.absoluteResetText(
            "1700000000000",
            locale: fixedLocale,
            timeZone: fixedTimeZone
        ) == expected)
        #expect(ServiceSupport.absoluteResetText(
            "2023-11-14T22:13:20.123Z",
            locale: fixedLocale,
            timeZone: fixedTimeZone
        ) == expected)
    }

    @Test("Reset display composition avoids a dangling separator")
    func resetDisplayCompositionAvoidsDanglingSeparator() {
        #expect(ServiceSupport.combinedResetText(
            session: "重置於 32 分鐘後",
            weekly: "9 月 2 日 上午 10:57"
        ) == "重置於 32 分鐘後｜9 月 2 日 上午 10:57")
        #expect(ServiceSupport.combinedResetText(
            session: "重置於 32 分鐘後",
            weekly: ""
        ) == "重置於 32 分鐘後")
        #expect(ServiceSupport.combinedResetText(
            session: "",
            weekly: "9 月 2 日 上午 10:57"
        ) == "重置於 9 月 2 日 上午 10:57")
        #expect(ServiceSupport.combinedResetText(session: "", weekly: "").isEmpty)
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

    @Test("Refresh failure preserves last-known-good usage")
    func refreshFailurePreservesLoadedUsage() throws {
        let current = UsageInfo(
            sessionPercent: 72,
            weeklyPercent: 41,
            resetText: "重置於 2 小時後",
            isLoaded: true
        )

        let next = try #require(
            UsageRefreshStatePolicy.state(
                afterFailure: current,
                error: URLError(.timedOut)
            )
        )

        #expect(next.sessionPercent == current.sessionPercent)
        #expect(next.weeklyPercent == current.weeklyPercent)
        #expect(next.resetText == current.resetText)
        #expect(next.isLoaded)
        #expect(next.errorMessage != nil)
    }

    @Test("Refresh cancellation leaves usage state unchanged")
    func refreshCancellationLeavesUsageUnchanged() {
        let current = UsageInfo(
            sessionPercent: 72,
            weeklyPercent: 41,
            resetText: "重置於 2 小時後",
            isLoaded: true
        )

        #expect(
            UsageRefreshStatePolicy.state(
                afterFailure: current,
                error: CancellationError()
            ) == nil
        )
        #expect(
            UsageRefreshStatePolicy.state(
                afterFailure: current,
                error: URLError(.cancelled)
            ) == nil
        )
    }

    @Test("Grok login URL and display name are product-scoped")
    func grokLoginProviderUsesGrokDotCom() {
        #expect(WebLoginProvider.grok.displayName == "Grok")
        #expect(WebLoginProvider.grok.loginURL.host == "grok.com")
        #expect(WebLoginProvider.grok.loginURL.path == "/" || WebLoginProvider.grok.loginURL.path.isEmpty)
    }

    @Test("Grok credential extracts dummy sso and optional sso-rw")
    func grokCredentialExtractsSsoAndOptionalSsoRw() throws {
        let sso = try #require(cookie(name: "sso", value: "dummy-sso-value", domain: "grok.com"))
        let ssoRw = try #require(cookie(name: "sso-rw", value: "dummy-sso-rw-value", domain: "grok.com"))
        let unrelated = try #require(cookie(name: "sso", value: "dummy-x-sso", domain: "x.com"))

        let withBoth = try #require(WebLoginProvider.grok.credential(from: [sso, ssoRw, unrelated]))
        #expect(withBoth.cookieName == "sso")
        #expect(withBoth.value == "dummy-sso-value")
        #expect(withBoth.cookieHeader == "sso=dummy-sso-value; sso-rw=dummy-sso-rw-value")

        let ssoOnly = try #require(WebLoginProvider.grok.credential(from: [sso]))
        #expect(ssoOnly.value == "dummy-sso-value")
        #expect(ssoOnly.cookieHeader == "sso=dummy-sso-value")

        let emptySSO = try #require(cookie(name: "sso", value: "", domain: "grok.com"))
        #expect(WebLoginProvider.grok.credential(from: [emptySSO]) == nil)
        #expect(WebLoginProvider.grok.credential(from: [unrelated]) == nil)
        #expect(WebLoginProvider.grok.credential(from: [ssoRw]) == nil)
    }

    @Test("Grok credential prefers grok.com over x.ai and ignores x.com")
    func grokCredentialPrefersGrokDotCom() throws {
        let grokSSO = try #require(cookie(name: "sso", value: "dummy-grok-sso", domain: "grok.com"))
        let xaiSSO = try #require(cookie(name: "sso", value: "dummy-xai-sso", domain: "x.ai"))
        let xcomSSO = try #require(cookie(name: "sso", value: "dummy-xcom-sso", domain: "x.com"))

        let preferred = try #require(GrokService.credential(from: [xaiSSO, grokSSO, xcomSSO]))
        #expect(preferred.value == "dummy-grok-sso")

        let xaiOnly = try #require(GrokService.credential(from: [xaiSSO, xcomSSO]))
        #expect(xaiOnly.value == "dummy-xai-sso")
        #expect(GrokService.credential(from: [xcomSSO]) == nil)
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
