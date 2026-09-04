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

    @Test("Welcome stays hidden when only Grok is logged in")
    func welcomeStaysHiddenWhenOnlyGrokIsLoggedIn() {
        #expect(WelcomePresentationPolicy(
            isClaudeLoggedIn: false,
            isChatGPTLoggedIn: false,
            isGrokLoggedIn: true,
            isSuppressedForCurrentSession: false
        ).shouldShow == false)
    }

    @Test("Provider visibility shows only authenticated Grok")
    func providerVisibilityShowsOnlyAuthenticatedGrok() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: false,
            isGrokAuthenticated: true
        )

        #expect(policy.visibleProviders == [.grok])
        #expect(policy.isVisible(.grok))
        #expect(policy.isVisible(.chatGPT) == false)
        #expect(policy.isVisible(.claude) == false)
        #expect(policy.shouldShowSetupState == false)
    }

    @Test("Provider visibility order is ChatGPT then Claude then Grok")
    func providerVisibilityOrderIsChatGPTClaudeGrok() {
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: true,
                isClaudeAuthenticated: true,
                isGrokAuthenticated: true
            ).visibleProviders == [.chatGPT, .claude, .grok]
        )
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: true,
                isClaudeAuthenticated: false,
                isGrokAuthenticated: true
            ).visibleProviders == [.chatGPT, .grok]
        )
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: false,
                isClaudeAuthenticated: true,
                isGrokAuthenticated: true
            ).visibleProviders == [.claude, .grok]
        )
    }

    @Test("Unauthenticated Grok is hidden")
    func unauthenticatedGrokIsHidden() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: false
        )

        #expect(policy.isVisible(.grok) == false)
        #expect(policy.visibleProviders == [.chatGPT, .claude])
    }

    @Test("Zero remaining Grok does not hide authenticated Grok")
    func zeroRemainingGrokDoesNotHideAuthenticatedGrok() {
        let policy = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: false,
            isClaudeAuthenticated: false,
            isGrokAuthenticated: true
        )
        let grok = UsageInfo(sessionPercent: 0, weeklyPercent: 0, isLoaded: true)

        #expect(grok.sessionPercent == 0)
        #expect(policy.isVisible(.grok))
        #expect(policy.visibleProviders == [.grok])
    }

    @Test("Fetch failure does not hide authenticated Grok")
    func fetchFailureDoesNotHideAuthenticatedGrok() {
        let policy = ProviderVisibilityPolicy(
            chatGPTSessionToken: "",
            claudeSessionKey: "",
            grokSessionToken: "configured"
        )
        let failed = UsageRefreshStatePolicy.state(
            afterFailure: UsageInfo(sessionPercent: 40, isLoaded: true),
            error: URLError(.timedOut)
        )

        #expect(failed?.isLoaded == true)
        #expect(failed?.sessionPercent == 40)
        #expect(failed?.errorMessage != nil)
        #expect(policy.isVisible(.grok))
    }

    @Test("Logging out Grok does not hide ChatGPT or Claude")
    func loggingOutGrokDoesNotHideChatGPTOrClaude() {
        let before = ProviderVisibilityPolicy(
            chatGPTSessionToken: "chatgpt",
            claudeSessionKey: "claude",
            grokSessionToken: "grok"
        )
        let after = ProviderVisibilityPolicy(
            chatGPTSessionToken: "chatgpt",
            claudeSessionKey: "claude",
            grokSessionToken: ""
        )

        #expect(before.visibleProviders == [.chatGPT, .claude, .grok])
        #expect(after.visibleProviders == [.chatGPT, .claude])
        #expect(after.isVisible(.grok) == false)
        #expect(after.isVisible(.chatGPT))
        #expect(after.isVisible(.claude))
    }

    @Test("Grok window label uses seconds not a hardcoded five hours")
    func grokWindowLabelUsesSecondsNotHardcodedFiveHours() {
        #expect(GrokService.sessionRowLabel(windowSeconds: 7200) == "2 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 18000) == "5 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 3600) == "1 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 1800) == "30 分鐘")
        #expect(GrokService.sessionRowLabel(windowSeconds: 90) == "1 分鐘 30 秒")
        #expect(GrokService.sessionRowLabel(windowSeconds: 45) == "45 秒")
        #expect(GrokService.sessionRowLabel(windowSeconds: 3599) == "59 分鐘 59 秒")
        #expect(GrokService.sessionRowLabel(windowSeconds: 5400) == "1 小時 30 分鐘")
        #expect(GrokService.sessionRowLabel(windowSeconds: 0) == "短窗")
        #expect(GrokService.sessionRowLabel(windowSeconds: 7200) != "5 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 1800) != "1 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 3599) != "1 小時")
    }

    @Test("Menu bar layout is 24 by 10 with 4px bars for one or two providers")
    func menuBarLayoutUsesTwoBarMetricsForOneOrTwoProviders() {
        #expect(MenuBarStatusLayout.imageSize(providerCount: 0) == (24, 10))
        #expect(MenuBarStatusLayout.imageSize(providerCount: 1) == (24, 10))
        #expect(MenuBarStatusLayout.imageSize(providerCount: 2) == (24, 10))
        #expect(MenuBarStatusLayout.barHeight(providerCount: 0) == 4)
        #expect(MenuBarStatusLayout.barHeight(providerCount: 1) == 4)
        #expect(MenuBarStatusLayout.barHeight(providerCount: 2) == 4)
        #expect(
            MenuBarStatusLayout.barY(
                index: 0,
                providerCount: 1,
                imageHeight: 10,
                barHeight: 4
            ) == 3
        )
    }

    @Test("Menu bar layout is 24 by 16 with 3px bars for three providers")
    func menuBarLayoutUsesThreeBarMetricsForThreeProviders() {
        #expect(MenuBarStatusLayout.imageSize(providerCount: 3) == (24, 16))
        #expect(MenuBarStatusLayout.barHeight(providerCount: 3) == 3)
        #expect(
            MenuBarStatusLayout.barY(
                index: 0,
                providerCount: 3,
                imageHeight: 16,
                barHeight: 3
            ) == 13
        )
        #expect(
            MenuBarStatusLayout.barY(
                index: 2,
                providerCount: 3,
                imageHeight: 16,
                barHeight: 3
            ) == 0
        )
    }

    @Test("Menu bar help text covers Grok-only and every pair plus all three")
    func menuBarHelpTextCoversGrokCombinations() {
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: false,
                isClaudeAuthenticated: false,
                isGrokAuthenticated: true
            ).menuBarHelpText == "Grok 剩餘用量"
        )
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: true,
                isClaudeAuthenticated: false,
                isGrokAuthenticated: true
            ).menuBarHelpText == "ChatGPT 與 Grok 剩餘用量"
        )
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: false,
                isClaudeAuthenticated: true,
                isGrokAuthenticated: true
            ).menuBarHelpText == "Claude 與 Grok 剩餘用量"
        )
        #expect(
            ProviderVisibilityPolicy(
                isChatGPTAuthenticated: true,
                isClaudeAuthenticated: true,
                isGrokAuthenticated: true
            ).menuBarHelpText == "ChatGPT、Claude 與 Grok 剩餘用量"
        )
    }

    @Test("Grok low usage notification triggers once at 20 percent")
    func grokLowUsageNotificationTriggersOnceAtTwentyPercent() {
        var state = UsageNotificationState()

        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 10,
            isLoaded: true,
            hasError: false
        ) == false)
    }

    @Test("Grok notification recovery above 20 percent re-arms")
    func grokNotificationRecoveryRearms() {
        var state = UsageNotificationState()

        _ = state.shouldNotify(
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        )
        _ = state.shouldNotify(
            for: .grok,
            remainingPercent: 15,
            isLoaded: true,
            hasError: false
        )
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 50,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
    }

    @Test("Grok notification is independent of Claude and ChatGPT")
    func grokNotificationIsIndependentOfOtherProviders() {
        var state = UsageNotificationState()

        _ = state.shouldNotify(
            for: .claude,
            remainingPercent: 40,
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
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        ) == false)
        #expect(state.shouldNotify(
            for: .grok,
            remainingPercent: 20,
            isLoaded: true,
            hasError: false
        ) == true)
        #expect(state.shouldNotify(
            for: .claude,
            remainingPercent: 10,
            isLoaded: true,
            hasError: false
        ) == false)
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
        #expect(WebSessionProvider.grok.matches("accounts.grok.com"))
        #expect(WebSessionProvider.grok.matches("accounts.x.ai") == false)
        #expect(WebSessionProvider.grok.matches("x.ai") == false)
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

    @Test("Grok credential requires grok.com and ignores x.ai and x.com")
    func grokCredentialPrefersGrokDotCom() throws {
        let grokSSO = try #require(cookie(name: "sso", value: "dummy-grok-sso", domain: "grok.com"))
        let xaiSSO = try #require(cookie(name: "sso", value: "dummy-xai-sso", domain: "x.ai"))
        let xcomSSO = try #require(cookie(name: "sso", value: "dummy-xcom-sso", domain: "x.com"))

        let preferred = try #require(GrokService.credential(from: [xaiSSO, grokSSO, xcomSSO]))
        #expect(preferred.value == "dummy-grok-sso")

        #expect(GrokService.credential(from: [xaiSSO, xcomSSO]) == nil)
        #expect(GrokService.credential(from: [xaiSSO]) == nil)
        #expect(GrokService.credential(from: [xcomSSO]) == nil)
    }

    @Test("Grok rate-limits live shape 140/140/7200 is 100 percent")
    func grokRateLimitsLiveShapeParsesToFullRemaining() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 140,
            "totalQueries": 140,
            "windowSizeSeconds": 7200,
            "lowEffortRateLimits": NSNull(),
            "highEffortRateLimits": NSNull()
        ])

        #expect(parsed.remainingPercent == 100)
        #expect(parsed.windowSeconds == 7200)
        #expect(parsed.resetText.isEmpty)
        #expect(GrokService.sessionRowLabel(windowSeconds: parsed.windowSeconds) == "2 小時")
        #expect(GrokService.sessionRowLabel(windowSeconds: 0) == "短窗")
    }

    @Test("Grok remaining percent uses totalQueries even when totalTokens is present")
    func grokRateLimitsUsesTotalQueriesNotTotalTokens() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 25,
            "totalTokens": 100,
            "totalQueries": 50,
            "windowSizeSeconds": 3600
        ])

        #expect(parsed.remainingPercent == 50)
        #expect(parsed.windowSeconds == 3600)
        #expect(parsed.resetText.isEmpty)
    }

    @Test("Grok remaining percent uses totalQueries when totalTokens is absent")
    func grokRateLimitsUsesTotalQueriesWhenTokensAbsent() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 70,
            "totalQueries": 140,
            "windowSizeSeconds": 7200
        ])

        #expect(parsed.remainingPercent == 50)
        #expect(parsed.resetText.isEmpty)
    }

    @Test("Grok remaining percent ignores zero or missing totalTokens when totalQueries is valid")
    func grokRateLimitsIgnoresZeroOrMissingTotalTokens() throws {
        let zeroTokens = try GrokService.parseRateLimits([
            "remainingQueries": 140,
            "totalTokens": 0,
            "totalQueries": 140,
            "windowSizeSeconds": 7200
        ])
        #expect(zeroTokens.remainingPercent == 100)

        let missingTokens = try GrokService.parseRateLimits([
            "remainingQueries": 70,
            "totalQueries": 140,
            "windowSizeSeconds": 7200
        ])
        #expect(missingTokens.remainingPercent == 50)
    }

    @Test("Grok remaining percent never divides remainingQueries by totalTokens")
    func grokRateLimitsRejectsTokenOnlyDenominator() {
        #expect(throws: AIUsageServiceError.self) {
            _ = try GrokService.parseRateLimits([
                "remainingQueries": 25,
                "totalTokens": 100,
                "windowSizeSeconds": 3600
            ])
        }
    }

    @Test("Grok does not fabricate a reset timestamp from windowSizeSeconds")
    func grokRateLimitsDoesNotFabricateResetFromWindow() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 140,
            "totalQueries": 140,
            "windowSizeSeconds": 7200
        ])

        #expect(parsed.windowSeconds == 7200)
        #expect(parsed.resetText.isEmpty)
        #expect(!parsed.resetText.hasPrefix("重置於 "))
    }

    @Test("Grok uses a genuine reset timestamp when one is present")
    func grokRateLimitsUsesGenuineResetTimestamp() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 70,
            "totalQueries": 140,
            "windowSizeSeconds": 7200,
            "resetAt": 1_700_000_000
        ])

        #expect(parsed.windowSeconds == 7200)
        #expect(parsed.resetText.hasPrefix("重置於 "))
        #expect(!parsed.resetText.isEmpty)
    }

    @Test("Grok missing or zero denominator does not invent a percent")
    func grokRateLimitsRejectsMissingOrZeroDenominator() {
        #expect(throws: AIUsageServiceError.self) {
            _ = try GrokService.parseRateLimits([
                "remainingQueries": 140
            ])
        }
        #expect(throws: AIUsageServiceError.self) {
            _ = try GrokService.parseRateLimits([
                "remainingQueries": 140,
                "totalQueries": 0,
                "windowSizeSeconds": 7200
            ])
        }
        #expect(throws: AIUsageServiceError.self) {
            _ = try GrokService.parseRateLimits([
                "remainingQueries": 140,
                "totalTokens": 100
            ])
        }
        #expect(throws: AIUsageServiceError.self) {
            _ = try GrokService.parseRateLimits([:])
        }
    }

    @Test("Grok zero remaining percent is a valid parsed payload")
    func grokZeroRemainingPercentIsValid() throws {
        let parsed = try GrokService.parseRateLimits([
            "remainingQueries": 0,
            "totalQueries": 140,
            "windowSizeSeconds": 7200
        ])

        #expect(parsed.remainingPercent == 0)
        #expect(parsed.windowSeconds == 7200)
    }

    @Test("HTML or Cloudflare bodies become a WAF error")
    func htmlBodiesBecomeWAFError() {
        let html = Data("<!DOCTYPE html><html><body>Just a moment</body></html>".utf8)

        do {
            try ServiceSupport.validateHTTPResponse(
                statusCode: 200,
                contentType: "text/html; charset=utf-8",
                data: html,
                serviceName: "Grok"
            )
            Issue.record("expected WAF error for 200 HTML")
        } catch let error as AIUsageServiceError {
            #expect(error.localizedDescription == "Grok 被網站防護擋下，請稍後再試")
        } catch {
            Issue.record("unexpected error type for 200 HTML")
        }

        do {
            try ServiceSupport.validateHTTPResponse(
                statusCode: 403,
                contentType: "text/html",
                data: html,
                serviceName: "Grok"
            )
            Issue.record("expected WAF error for 403 HTML")
        } catch let error as AIUsageServiceError {
            #expect(error.localizedDescription == "Grok 被網站防護擋下，請稍後再試")
        } catch {
            Issue.record("unexpected error type for 403 HTML")
        }

        do {
            _ = try ServiceSupport.jsonObject(from: html, serviceName: "Grok")
            Issue.record("expected WAF error for HTML jsonObject")
        } catch let error as AIUsageServiceError {
            #expect(error.localizedDescription == "Grok 被網站防護擋下，請稍後再試")
        } catch {
            Issue.record("unexpected error type for HTML jsonObject")
        }
    }

    @Test("HTTP 401 remains an auth error even when the body is HTML")
    func http401RemainsAuthError() {
        let html = Data("<html><body>login</body></html>".utf8)

        do {
            try ServiceSupport.validateHTTPResponse(
                statusCode: 401,
                contentType: "text/html",
                data: html,
                serviceName: "Grok"
            )
            Issue.record("expected 401 auth error")
        } catch let error as AIUsageServiceError {
            #expect(error.localizedDescription == "Grok 登入已失效，請重新登入")
        } catch {
            Issue.record("unexpected error type for 401")
        }
    }

    @Test("JSON 403 stays a permission error rather than WAF")
    func json403StaysPermissionError() {
        let json = Data("{\"error\":true}".utf8)

        do {
            try ServiceSupport.validateHTTPResponse(
                statusCode: 403,
                contentType: "application/json",
                data: json,
                serviceName: "Grok"
            )
            Issue.record("expected 403 permission error")
        } catch let error as AIUsageServiceError {
            #expect(error.localizedDescription == "Grok 沒有權限，請重新登入")
        } catch {
            Issue.record("unexpected error type for JSON 403")
        }
    }

    @Test("Grok session context includes applicable grok.com cookies and excludes others")
    func grokSessionContextIncludesApplicableCookiesOnly() throws {
        let url = GrokSessionContext.rateLimitsURL
        let sso = try #require(cookie(name: "sso", value: "dummy-sso", domain: "grok.com"))
        let ssoRw = try #require(cookie(name: "sso-rw", value: "dummy-sso-rw", domain: "grok.com"))
        let clearance = try #require(cookie(name: "cf_clearance", value: "dummy-cf", domain: "grok.com"))
        let bot = try #require(cookie(name: "__cf_bm", value: "dummy-bm", domain: ".grok.com"))
        let chatgpt = try #require(cookie(
            name: "session-token",
            value: "dummy-chatgpt",
            domain: "chatgpt.com"
        ))
        let xai = try #require(cookie(name: "sso", value: "dummy-xai", domain: "x.ai"))
        let xcom = try #require(cookie(name: "sso", value: "dummy-xcom", domain: "x.com"))
        let expired = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/",
            .name: "expired",
            .value: "dummy-expired",
            .expires: Date().addingTimeInterval(-60)
        ]))
        let otherPath = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/account",
            .name: "account",
            .value: "dummy-account"
        ]))
        let restPath = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/rest",
            .name: "rest-scope",
            .value: "dummy-rest"
        ]))

        let header = try #require(
            GrokSessionContext.cookieHeader(
                from: [
                    sso, ssoRw, clearance, bot, chatgpt, xai, xcom, expired,
                    otherPath, restPath
                ],
                to: url
            )
        )
        let headerNames = GrokSessionContext.cookieNames(fromHeader: header)

        #expect(headerNames.contains("sso"))
        #expect(headerNames.contains("sso-rw"))
        #expect(headerNames.contains("cf_clearance"))
        #expect(headerNames.contains("__cf_bm"))
        #expect(headerNames.contains("rest-scope"))
        #expect(!headerNames.contains("session-token"))
        #expect(!headerNames.contains("expired"))
        #expect(!headerNames.contains("account"))

        #expect(header.contains("sso=dummy-sso"))
        #expect(header.contains("sso-rw=dummy-sso-rw"))
        #expect(header.contains("cf_clearance=dummy-cf"))
        #expect(header.contains("__cf_bm=dummy-bm"))
        #expect(header.contains("rest-scope=dummy-rest"))
        #expect(!header.contains("dummy-chatgpt"))
        #expect(!header.contains("dummy-xai"))
        #expect(!header.contains("dummy-xcom"))
        #expect(!header.contains("dummy-expired"))
        #expect(!header.contains("dummy-account"))
    }

    @Test("Grok session context falls back when WebKit cookies lack sso")
    func grokSessionContextFallsBackWithoutWebKitSSO() throws {
        let clearance = try #require(cookie(
            name: "cf_clearance",
            value: "dummy-cf",
            domain: "grok.com"
        ))
        let header = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: [clearance],
            fallbackHeader: "sso=dummy-sso; sso-rw=dummy-sso-rw"
        )

        #expect(header == "sso=dummy-sso; sso-rw=dummy-sso-rw")
        #expect(GrokSessionContext.cookieHeader(from: [clearance], to: GrokSessionContext.rateLimitsURL) == nil)
    }

    @Test("Grok session context prefers current WebKit cookies when sso exists")
    func grokSessionContextPrefersWebKitWhenSSOExists() throws {
        let sso = try #require(cookie(name: "sso", value: "dummy-sso", domain: "grok.com"))
        let clearance = try #require(cookie(
            name: "cf_clearance",
            value: "dummy-cf",
            domain: "grok.com"
        ))
        let header = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: [sso, clearance],
            fallbackHeader: "sso=dummy-fallback"
        )

        #expect(header.contains("sso=dummy-sso"))
        #expect(header.contains("cf_clearance=dummy-cf"))
        #expect(!header.contains("dummy-fallback"))
    }

    @Test("Grok session context cookie-name helper does not include values")
    func grokSessionContextCookieNamesExcludeValues() {
        let names = GrokSessionContext.cookieNames(
            fromHeader: "sso=dummy-sso; cf_clearance=dummy-cf"
        )

        #expect(names == ["cf_clearance", "sso"])
        #expect(!names.contains(where: { $0.contains("dummy") }))
        #expect(!names.contains(where: { $0.contains("=") }))
    }

    @Test("Session-only grok.com cookies remain applicable to rate-limits")
    func sessionOnlyGrokCookiesRemainApplicable() throws {
        let url = GrokSessionContext.rateLimitsURL
        let sso = try #require(cookie(name: "sso", value: "dummy-sso", domain: "grok.com"))
        let clearance = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/",
            .name: "cf_clearance",
            .value: "dummy-cf",
            .secure: "TRUE"
        ]))

        #expect(clearance.isSessionOnly)

        let descriptors = GrokSessionContext.descriptors(
            from: [sso, clearance],
            to: url
        )
        let names = descriptors.map(\.name)
        #expect(names == ["cf_clearance", "sso"])
        #expect(descriptors.contains { $0.name == "cf_clearance" && $0.isSessionOnly })
        #expect(!descriptors.contains { $0.name == "cf_clearance" && $0.hasExpiration })

        let header = try #require(
            GrokSessionContext.cookieHeader(from: [sso, clearance], to: url)
        )
        #expect(header.contains("cf_clearance=dummy-cf"))
        #expect(header.contains("sso=dummy-sso"))
        #expect(!descriptors.map(\.name).joined().contains("dummy"))
    }

    @Test("Grok cold-start restorer loads grok.com without credential automation")
    func grokColdStartRestorerLoadsGrokHome() {
        #expect(GrokWebKitSessionRestorer.restoreURL.absoluteString == "https://grok.com/")
        #expect(GrokWebKitSessionRestorer.restoreURL.host == "grok.com")
        #expect(GrokWebKitSessionRestorer.restoreURL.path == "/" ||
                GrokWebKitSessionRestorer.restoreURL.path.isEmpty)
        #expect(WebLoginProvider.grok.loginURL == GrokWebKitSessionRestorer.restoreURL)
    }

    @Test("Successful restoration with usable sso becomes READY")
    func grokRestorerSuccessBecomesReady() {
        var gate = GrokSessionRestorerGate()
        let generation = gate.beginRestore()
        gate.complete(attemptGeneration: generation, outcome: .success)
        #expect(gate.phase == .ready)
    }

    @Test("Failed restoration does not become READY")
    func grokRestorerFailureDoesNotBecomeReady() {
        var gate = GrokSessionRestorerGate()
        let generation = gate.beginRestore()
        gate.complete(attemptGeneration: generation, outcome: .failure)
        #expect(gate.phase == .unknown)
    }

    @Test("Timed out restoration does not become READY")
    func grokRestorerTimeoutDoesNotBecomeReady() {
        var gate = GrokSessionRestorerGate()
        let generation = gate.beginRestore()
        gate.complete(attemptGeneration: generation, outcome: .timeout)
        #expect(gate.phase == .unknown)
    }

    @Test("Reset invalidates in-flight restoration completion")
    func grokRestorerResetInvalidatesInFlightCompletion() {
        var gate = GrokSessionRestorerGate()
        let generation = gate.beginRestore()
        gate.reset()
        gate.complete(attemptGeneration: generation, outcome: .success)
        #expect(gate.phase == .unknown)
        #expect(gate.generation != generation)
    }

    @Test("Recoverable Grok WAF permits exactly one restoration retry")
    func grokRecoverableWAFPermitsExactlyOneRetry() {
        let error = AIUsageServiceError.wafBlocked("Grok")
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: error
            )
        )
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: true,
                error: error
            ) == false
        )
        #expect(error.localizedDescription == "Grok 被網站防護擋下，請稍後再試")
    }

    @Test("HTTP 401 is a recoverable Grok session failure")
    func grokHTTP401IsRecoverableSessionFailure() {
        #expect(
            GrokSessionRecoveryPolicy.isRecoverableSessionFailure(
                AIUsageServiceError.httpStatus("Grok", 401)
            )
        )
    }

    @Test("Parser and network errors do not trigger Grok restoration")
    func grokParserAndNetworkErrorsDoNotTriggerRestoration() {
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: AIUsageServiceError.invalidPayload("Grok")
            ) == false
        )
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: URLError(.notConnectedToInternet)
            ) == false
        )
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: AIUsageServiceError.httpStatus("Grok", 500)
            ) == false
        )
    }

    @Test("Grok Cookie header is stripped on redirect outside grok.com")
    func grokCookieHeaderIsStrippedOutsideGrokHost() {
        var foreign = URLRequest(url: URL(string: "https://example.com/steal")!)
        foreign.setValue("sso=dummy-sso", forHTTPHeaderField: "Cookie")
        let rewritten = GrokRedirectPolicy.requestAfterRedirect(foreign)
        #expect(rewritten?.url?.host == "example.com")
        #expect(rewritten?.value(forHTTPHeaderField: "Cookie") == nil)

        var grok = URLRequest(url: URL(string: "https://accounts.grok.com/continue")!)
        grok.setValue("sso=dummy-sso", forHTTPHeaderField: "Cookie")
        let kept = GrokRedirectPolicy.requestAfterRedirect(grok)
        #expect(kept?.value(forHTTPHeaderField: "Cookie") == "sso=dummy-sso")

        var xai = URLRequest(url: URL(string: "https://x.ai/auth")!)
        xai.setValue("sso=dummy-sso", forHTTPHeaderField: "Cookie")
        #expect(GrokRedirectPolicy.requestAfterRedirect(xai)?.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test("Web session manager is isolated to the main actor")
    @MainActor
    func webSessionManagerIsIsolatedToTheMainActor() {
        // Do not call cookies(for:) here: that would initialize WebKit.
        // Isolation is the production crash fix; cookie filtering is covered
        // by GrokSessionContext tests with synthetic values.
        _ = WebSessionManager.shared
    }

    @Test("T1 Grok 63 percent used becomes 37 percent remaining")
    func grokWeeklyUsed63BecomesRemaining37() throws {
        #expect(GrokCreditsConfigDecoder.remainingPercent(usedPercent: 63) == 37)
        let quota = try GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: 63,
            periodType: 2,
            periodEnd: Date(timeIntervalSince1970: 1_788_592_260),
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        #expect(quota.usedPercent == 63)
        #expect(quota.remainingPercent == 37)
    }

    @Test("T2 Grok weekly used clamps to 0...100")
    func grokWeeklyUsedClampsToClosedRange() throws {
        #expect(GrokCreditsConfigDecoder.remainingPercent(usedRaw: -8) == 100)
        #expect(GrokCreditsConfigDecoder.remainingPercent(usedRaw: 150) == 0)
        let high = try GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: 150,
            periodType: 2,
            periodEnd: Date(timeIntervalSince1970: 1_788_592_260),
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        #expect(high.usedPercent == 100)
        #expect(high.remainingPercent == 0)
        let low = try GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: -4,
            periodType: 2,
            periodEnd: Date(timeIntervalSince1970: 1_788_592_260),
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        #expect(low.usedPercent == 0)
        #expect(low.remainingPercent == 100)
    }

    @Test("T3 WEEKLY period with valid end is accepted")
    func grokWeeklyRequiresWeeklyPeriodAndEnd() throws {
        let end = Date(timeIntervalSince1970: 1_788_592_260)
        let quota = try GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: 63,
            periodType: GrokCreditsConfigDecoder.weeklyPeriodType,
            periodEnd: end,
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        #expect(quota.resetAt == end)
    }

    @Test("T4 non-WEEKLY period is rejected")
    func grokNonWeeklyPeriodIsRejected() {
        #expect(throws: Error.self) {
            _ = try GrokCreditsConfigDecoder.validatedWeekly(
                usedRaw: 63,
                periodType: 1,
                periodEnd: Date(timeIntervalSince1970: 1_788_592_260)
            )
        }
    }

    @Test("T5 missing current period is rejected")
    func grokMissingPeriodIsRejected() {
        #expect(throws: Error.self) {
            _ = try GrokCreditsConfigDecoder.validatedWeekly(
                usedRaw: 63,
                periodType: nil,
                periodEnd: Date(timeIntervalSince1970: 1_788_592_260)
            )
        }
    }

    @Test("T6 missing or invalid end is rejected")
    func grokMissingEndIsRejected() {
        #expect(throws: Error.self) {
            _ = try GrokCreditsConfigDecoder.validatedWeekly(
                usedRaw: 63,
                periodType: 2,
                periodEnd: nil
            )
        }
    }

    @Test("T7 protobuf decode failure does not yield Weekly")
    func grokProtobufDecodeFailureYieldsNoWeekly() {
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: Data([0x00, 0x00, 0x00, 0x00, 0x03, 0xFF, 0xFF, 0xFF])
        )
        #expect(quota == nil)
    }

    @Test("T8 Weekly HTTP failure leaves short-window usable")
    func grokWeeklyHTTPFailureLeavesShortWindowUsable() throws {
        #expect(
            GrokCreditsConfigDecoder.weeklyQuota(
                httpStatus: 404,
                contentType: "application/json",
                body: Data(#"{"error":"not found"}"#.utf8)
            ) == nil
        )
        let session = try GrokService.parseRateLimits([
            "remainingQueries": 97,
            "totalQueries": 100,
            "windowSizeSeconds": 86400
        ])
        let usage = GrokUsage(
            sessionRemainingPercent: session.remainingPercent,
            resetText: session.resetText,
            sessionWindowSeconds: session.windowSeconds,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            weeklyRelativeResetText: nil
        )
        #expect(usage.sessionRemainingPercent == 97)
        #expect(usage.sessionWindowSeconds == 86400)
        #expect(usage.weeklyRemainingPercent == nil)

        let info = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: 0,
            weeklyAvailable: false,
            resetText: usage.resetText,
            sessionWindowSeconds: usage.sessionWindowSeconds,
            isLoaded: true
        )
        let presentation = GrokCardPresentation.from(info)
        #expect(presentation.showsSessionRow)
        #expect(!presentation.showsWeeklyRow)
        #expect(presentation.displayedRowCount == 1)
    }

    @Test("T9 valid Weekly shows exactly one Weekly row")
    func grokValidWeeklyShowsOneWeeklyRow() {
        let info = UsageInfo(
            sessionPercent: 99,
            weeklyPercent: 37,
            weeklyAvailable: true,
            resetText: "重置於 2 天後",
            weeklyResetText: "9 月 5 日 下午 3:11",
            sessionWindowSeconds: 7200,
            isLoaded: true
        )
        let presentation = GrokCardPresentation.from(info)
        #expect(presentation.showsWeeklyRow)
        #expect(!presentation.showsSessionRow)
        #expect(presentation.displayedRowCount == 1)
        #expect(presentation.weeklyPercent == 37)
        #expect(presentation.sessionPercent == nil)
    }

    @Test("T10 no Weekly shows exactly one short-window row")
    func grokWithoutWeeklyShowsOneShortWindowRow() {
        let info = UsageInfo(
            sessionPercent: 97,
            weeklyPercent: 0,
            weeklyAvailable: false,
            sessionWindowSeconds: 86400,
            isLoaded: true
        )
        let presentation = GrokCardPresentation.from(info)
        #expect(presentation.showsSessionRow)
        #expect(!presentation.showsWeeklyRow)
        #expect(presentation.displayedRowCount == 1)
        #expect(presentation.sessionPercent == 97)
    }

    @Test("T11 valid Weekly does not display the short-window bar")
    func grokValidWeeklyHidesShortWindowBar() {
        let info = UsageInfo(
            sessionPercent: 100,
            weeklyPercent: 37,
            weeklyAvailable: true,
            sessionWindowSeconds: 7200,
            isLoaded: true
        )
        let presentation = GrokCardPresentation.from(info)
        #expect(presentation.showsSessionRow == false)
        #expect(presentation.sessionPercent == nil)
        #expect(info.sessionPercent == 100)
    }

    @Test("T12 notification uses Weekly remaining when Weekly is primary")
    func grokNotificationUsesWeeklyWhenPrimary() {
        let info = UsageInfo(
            sessionPercent: 99,
            weeklyPercent: 18,
            weeklyAvailable: true,
            resetText: "重置於 2 天後",
            weeklyResetText: "9 月 5 日 下午 3:11",
            isLoaded: true
        )
        #expect(info.primaryRemainingPercent == 18)
        var state = UsageNotificationState()
        _ = state.shouldNotify(
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        )
        let notifiedOnWeeklyPrimary = state.shouldNotify(
            for: .grok,
            remainingPercent: info.primaryRemainingPercent,
            isLoaded: true,
            hasError: false
        )
        #expect(notifiedOnWeeklyPrimary)
        #expect(info.primaryResetText.contains("重置於 2 天後"))
        #expect(info.primaryResetText.contains("9 月 5 日 下午 3:11"))
    }

    @Test("T13 notification uses short-window remaining when Weekly is absent")
    func grokNotificationUsesShortWindowWhenFallback() {
        let info = UsageInfo(
            sessionPercent: 18,
            weeklyPercent: 0,
            weeklyAvailable: false,
            resetText: "重置於 20 小時後",
            isLoaded: true
        )
        #expect(info.primaryRemainingPercent == 18)
        #expect(info.primaryResetText == "重置於 20 小時後")
        var state = UsageNotificationState()
        _ = state.shouldNotify(
            for: .grok,
            remainingPercent: 40,
            isLoaded: true,
            hasError: false
        )
        let notifiedOnShortWindowFallback = state.shouldNotify(
            for: .grok,
            remainingPercent: info.primaryRemainingPercent,
            isLoaded: true,
            hasError: false
        )
        #expect(notifiedOnShortWindowFallback)
    }

    @Test("T16 production Grok UI has no weeklyRPC probe diagnostic")
    func grokProductionHasNoWeeklyRPCProbeDiagnostic() {
        let info = UsageInfo(
            sessionPercent: 99,
            weeklyPercent: 37,
            weeklyAvailable: true,
            resetText: "重置於 2 天後",
            weeklyResetText: "9 月 5 日 下午 3:11",
            isLoaded: true
        )
        #expect(!info.primaryResetText.contains("weeklyRPC"))
        #expect(!info.primaryResetText.contains("probe:"))
        #expect(!info.primaryResetText.contains("credits:"))
    }

    @Test("Live-shaped gRPC-Web Weekly payload decodes used remaining and reset")
    func grokLiveShapedGrpcWebPayloadDecodesWeekly() throws {
        let end = protoTimestamp(seconds: 1_788_592_260)
        let period = protoVarint(1, 2) + protoBytes(3, end)
        let config = protoFloat(1, 63) + protoBytes(8, period)
        let message = protoBytes(1, config)
        let body = grpcWebFrame(message) + grpcWebTrailer("grpc-status: 0\r\n")
        let quota = try #require(
            GrokCreditsConfigDecoder.weeklyQuota(
                httpStatus: 200,
                contentType: "application/grpc-web+proto",
                body: body,
                now: Date(timeIntervalSince1970: 1_788_000_000)
            )
        )
        #expect(quota.usedPercent == 63)
        #expect(quota.remainingPercent == 37)
        #expect(quota.resetAt.timeIntervalSince1970 == 1_788_592_260)
    }

    @Test("Malformed trailing nested protobuf rejects Weekly without crashing")
    func grokMalformedTrailingNestedProtobufRejectsWeekly() {
        let end = protoTimestamp(seconds: 1_788_592_260)
        let validPeriod = protoVarint(1, 2) + protoBytes(3, end)
        let malformedTrailing = Data([0x1F])
        let config = protoFloat(1, 63) + protoBytes(8, validPeriod) + malformedTrailing
        let body = grpcWebFrame(protoBytes(1, config)) + grpcWebTrailer("grpc-status: 0\r\n")
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: body
        )
        #expect(quota == nil)
    }

    @Test("Oversized protobuf length varint rejects Weekly without crashing")
    func grokOversizedProtobufLengthVarintRejectsWeekly() {
        var oversized = Data([0x12])
        oversized.append(contentsOf: Array(repeating: 0xFF, count: 10))
        let body = grpcWebFrame(oversized)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: body
        )
        #expect(quota == nil)
    }

    @Test("Truncated length-delimited protobuf rejects Weekly without crashing")
    func grokTruncatedLengthDelimitedProtobufRejectsWeekly() {
        let truncated = Data([0x0A, 0x20, 0x01])
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(truncated)
        )
        #expect(quota == nil)
    }

    @Test("Malformed Timestamp nested in Period rejects Weekly")
    func grokMalformedTimestampRejectsWeekly() {
        let truncatedTimestamp = Data([0x0A, 0x08, 0x01])
        let period = protoVarint(1, 2) + protoBytes(3, truncatedTimestamp)
        let config = protoFloat(1, 63) + protoBytes(8, period)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(protoBytes(1, config))
        )
        #expect(quota == nil)
    }

    @Test("Malformed Period nested field rejects Weekly")
    func grokMalformedPeriodRejectsWeekly() {
        let truncatedPeriod = protoVarint(1, 2) + Data([0x1A, 0x08, 0x01])
        let config = protoFloat(1, 63) + protoBytes(8, truncatedPeriod)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(protoBytes(1, config))
        )
        #expect(quota == nil)
    }

    @Test("Failed refresh after valid Weekly keeps panel menu and notification primary aligned")
    func grokStaleWeeklyRefreshFailureKeepsPrimaryQuotaConsistent() throws {
        let loaded = UsageInfo(
            sessionPercent: 99,
            weeklyPercent: 37,
            weeklyAvailable: true,
            resetText: "重置於 2 天後",
            weeklyResetText: "9 月 5 日 下午 3:11",
            sessionWindowSeconds: 7200,
            isLoaded: true
        )
        let failed = UsageRefreshStatePolicy.state(
            afterFailure: loaded,
            error: AIUsageServiceError.httpStatus("Grok", 500)
        )
        let info = try #require(failed)
        let presentation = GrokCardPresentation.from(info)
        let menuBarPrimary = info.primaryRemainingPercent
        let notificationPrimary = info.primaryRemainingPercent

        #expect(info.weeklyAvailable)
        #expect(info.errorMessage != nil)
        #expect(presentation.showsWeeklyRow)
        #expect(!presentation.showsSessionRow)
        #expect(presentation.displayedRowCount == 1)
        #expect(presentation.weeklyPercent == 37)
        #expect(presentation.sessionPercent == nil)
        #expect(menuBarPrimary == 37)
        #expect(notificationPrimary == 37)
        #expect(presentation.weeklyPercent == menuBarPrimary)
    }

    @Test("Logout generation rejects in-flight Grok HTTP completion")
    func grokLogoutGenerationRejectsOldHTTPCompletion() {
        var generation = GrokHTTPAuthGeneration()
        let captured = generation.value
        generation.invalidate()
        #expect(
            GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: captured,
                current: generation.value
            ) == false
        )
    }

    @Test("Logout before WAF recovery blocks old-auth retry")
    func grokLogoutBeforeRecoveryBlocksOldAuthRetry() {
        var generation = GrokHTTPAuthGeneration()
        let captured = generation.value
        generation.invalidate()
        #expect(
            GrokHTTPRefreshAuthPolicy.shouldAttemptRecovery(
                captured: captured,
                current: generation.value,
                didAlreadyRetry: false,
                error: AIUsageServiceError.wafBlocked("Grok")
            ) == false
        )
        #expect(
            GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: false,
                error: AIUsageServiceError.wafBlocked("Grok")
            )
        )
    }

    @Test("Old Grok HTTP generation cannot overwrite a newer login generation")
    func grokOldHTTPGenerationCannotOverwriteNewLogin() {
        var generation = GrokHTTPAuthGeneration()
        let old = generation.value
        generation.invalidate()
        let newLogin = generation.value
        #expect(old != newLogin)
        #expect(
            GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: old,
                current: newLogin
            ) == false
        )
        #expect(
            GrokHTTPRefreshAuthPolicy.shouldCommit(
                captured: newLogin,
                current: generation.value
            )
        )
    }

    @Test("Host-only accounts.grok.com cookies are not sent to grok.com")
    func grokHostOnlyAccountsCookieIsNotSentToGrokCom() throws {
        let hostOnly = try #require(HTTPCookie(properties: [
            .domain: "accounts.grok.com",
            .path: "/",
            .name: "sso",
            .value: "dummy-accounts-sso"
        ]))
        let domainCookie = try #require(HTTPCookie(properties: [
            .domain: ".grok.com",
            .path: "/",
            .name: "sso",
            .value: "dummy-domain-sso"
        ]))
        let rateLimits = GrokSessionContext.rateLimitsURL
        #expect(
            GrokSessionContext.cookieHeader(from: [hostOnly], to: rateLimits) == nil
        )
        let domainHeader = try #require(
            GrokSessionContext.cookieHeader(from: [domainCookie], to: rateLimits)
        )
        #expect(domainHeader.contains("sso=dummy-domain-sso"))
        #expect(!domainHeader.contains("dummy-accounts-sso"))
    }

    @Test("Rate-limits path cookies are not reused for Weekly request URL")
    func grokRestScopedCookieIsNotSentToWeeklyURL() throws {
        let sso = try #require(cookie(name: "sso", value: "dummy-sso", domain: "grok.com"))
        let rest = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/rest",
            .name: "rest-scope",
            .value: "dummy-rest"
        ]))
        let weeklyPath = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig",
            .name: "weekly-scope",
            .value: "dummy-weekly"
        ]))

        let rateLimitsHeader = try #require(
            GrokSessionContext.cookieHeader(
                from: [sso, rest, weeklyPath],
                to: GrokSessionContext.rateLimitsURL
            )
        )
        let weeklyHeader = try #require(
            GrokSessionContext.cookieHeader(
                from: [sso, rest, weeklyPath],
                to: GrokSessionContext.weeklyCreditsURL
            )
        )

        #expect(rateLimitsHeader.contains("rest-scope=dummy-rest"))
        #expect(!rateLimitsHeader.contains("dummy-weekly"))
        #expect(weeklyHeader.contains("weekly-scope=dummy-weekly"))
        #expect(!weeklyHeader.contains("dummy-rest"))
    }

    @Test("Secure Grok cookies are omitted from non-HTTPS request URLs")
    func grokSecureCookieOmittedFromHTTPURL() throws {
        let sso = try #require(HTTPCookie(properties: [
            .domain: "grok.com",
            .path: "/",
            .name: "sso",
            .value: "dummy-sso",
            .secure: "TRUE"
        ]))
        let httpURL = URL(string: "http://grok.com/rest/rate-limits")!
        #expect(GrokSessionContext.cookieHeader(from: [sso], to: httpURL) == nil)
        let httpsHeader = try #require(
            GrokSessionContext.cookieHeader(from: [sso], to: GrokSessionContext.rateLimitsURL)
        )
        #expect(httpsHeader.contains("sso=dummy-sso"))
    }

    @Test("Malformed 10th-byte protobuf varint rejects Weekly")
    func grokMalformedTenthByteVarintRejectsWeekly() {
        let malformed = Data([0x82, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x02])
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(malformed)
        )
        #expect(quota == nil)
    }

    @Test("Timestamp nanos above 999_999_999 reject Weekly")
    func grokTimestampNanosOverflowRejectsWeekly() {
        let timestamp = protoVarint(1, Int(Date().addingTimeInterval(86_400).timeIntervalSince1970))
            + protoVarint(2, 1_000_000_000)
        let period = protoVarint(1, 2) + protoBytes(3, timestamp)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(protoBytes(1, protoFloat(1, 63) + protoBytes(8, period)))
        )
        #expect(quota == nil)
    }

    @Test("Negative-equivalent Timestamp nanos reject Weekly")
    func grokNegativeEquivalentNanosRejectWeekly() {
        let timestamp = protoVarint(
            1,
            Int(Date().addingTimeInterval(86_400).timeIntervalSince1970)
        ) + protoUnsignedVarint(2, 4_294_967_295)
        let period = protoVarint(1, 2) + protoBytes(3, timestamp)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(protoBytes(1, protoFloat(1, 63) + protoBytes(8, period)))
        )
        #expect(quota == nil)
    }

    @Test("Absurd Weekly reset Timestamp is rejected")
    func grokAbsurdResetTimestampRejectsWeekly() {
        let timestamp = protoVarint(1, 1)
        let period = protoVarint(1, 2) + protoBytes(3, timestamp)
        let quota = GrokCreditsConfigDecoder.weeklyQuota(
            httpStatus: 200,
            contentType: "application/grpc-web+proto",
            body: grpcWebFrame(protoBytes(1, protoFloat(1, 63) + protoBytes(8, period))),
            now: Date()
        )
        #expect(quota == nil)
    }

    @Test("Live-shaped Weekly timestamp near now still succeeds")
    func grokLiveShapedTimestampNearNowStillSucceeds() throws {
        let reset = Date().addingTimeInterval(2 * 24 * 60 * 60)
        let end = protoTimestamp(seconds: Int(reset.timeIntervalSince1970))
        let period = protoVarint(1, 2) + protoBytes(3, end)
        let quota = try #require(
            GrokCreditsConfigDecoder.weeklyQuota(
                httpStatus: 200,
                contentType: "application/grpc-web+proto",
                body: grpcWebFrame(
                    protoBytes(1, protoFloat(1, 63) + protoBytes(8, period))
                ) + grpcWebTrailer("grpc-status: 0\r\n")
            )
        )
        #expect(quota.usedPercent == 63)
        #expect(quota.remainingPercent == 37)
    }

    @Test("Grok account replacement clears stale usage and re-arms refresh")
    @MainActor
    func grokAccountReplacementClearsStaleUsageAndRearmsRefresh() async throws {
        let service = ControllableGrokUsageService()
        let restorer = GrokSessionRestorerSpy()
        let model = UsageViewModel(
            grokService: service,
            grokSessionRestorer: restorer
        )

        let usageA = GrokUsage(
            sessionRemainingPercent: 11,
            resetText: "A",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: 37,
            weeklyResetText: "A-weekly",
            weeklyRelativeResetText: "A-rel"
        )
        let usageB = GrokUsage(
            sessionRemainingPercent: 88,
            resetText: "B",
            sessionWindowSeconds: 7200,
            weeklyRemainingPercent: 12,
            weeklyResetText: "B-weekly",
            weeklyRelativeResetText: "B-rel"
        )

        service.enqueue(.success(usageA))
        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-A", cookieHeader: "sso=token-A")
        )
        try await waitUntil { model.grok.isLoaded && model.grok.weeklyPercent == 37 }
        #expect(model.grok.sessionPercent == 11)

        let inFlight = Task { await model.refreshAll() }
        try await waitUntil { !service.pending.isEmpty }
        #expect(model.isLoading)

        model.setGrokCredential(
            WebCredential(cookieName: "sso", value: "token-B", cookieHeader: "sso=token-B")
        )
        #expect(model.grok.isLoaded == false)
        #expect(model.grok.weeklyPercent == 0)
        #expect(model.grok.weeklyAvailable == false)
        #expect(restorer.resetCount >= 1)

        service.enqueue(.success(usageB))
        service.enqueue(.success(usageB))
        service.completeNext(usageA)
        await inFlight.value

        try await waitUntil {
            !model.isLoading && model.grok.isLoaded && model.grok.weeklyPercent == 12
        }
        #expect(model.grok.sessionPercent == 88)
        #expect(model.grok.weeklyPercent != 37)
        #expect(service.cookieHeaders.contains(where: { $0.contains("token-B") }))
    }

    private func protoVarint(_ field: Int, _ value: Int) -> Data {
        var data = Data()
        appendVarint(&data, UInt64(field << 3))
        appendVarint(&data, UInt64(value))
        return data
    }

    private func protoFloat(_ field: Int, _ value: Float) -> Data {
        var data = Data()
        appendVarint(&data, UInt64((field << 3) | 5))
        var bits = value.bitPattern.littleEndian
        Swift.withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        return data
    }

    private func protoBytes(_ field: Int, _ payload: Data) -> Data {
        var data = Data()
        appendVarint(&data, UInt64((field << 3) | 2))
        appendVarint(&data, UInt64(payload.count))
        data.append(payload)
        return data
    }

    private func protoTimestamp(seconds: Int) -> Data {
        protoVarint(1, seconds)
    }

    private func grpcWebFrame(_ payload: Data, flag: UInt8 = 0) -> Data {
        var header = Data([flag, 0, 0, 0, 0])
        let length = UInt32(payload.count).bigEndian
        Swift.withUnsafeBytes(of: length) { bytes in
            header.replaceSubrange(1..<5, with: bytes)
        }
        return header + payload
    }

    private func grpcWebTrailer(_ text: String) -> Data {
        grpcWebFrame(Data(text.utf8), flag: 0x80)
    }

    private func appendVarint(_ data: inout Data, _ value: UInt64) {
        var value = value
        while value > 0x7F {
            data.append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        }
        data.append(UInt8(value))
    }

    private func protoUnsignedVarint(_ field: Int, _ value: UInt64) -> Data {
        var data = Data()
        appendVarint(&data, UInt64(field << 3))
        appendVarint(&data, value)
        return data
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<4_000 {
            if await MainActor.run(body: condition) {
                return
            }
            await Task.yield()
        }
        Issue.record("timed out waiting for Grok refresh lifecycle")
        throw CancellationError()
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

@MainActor
final class GrokSessionRestorerSpy: GrokSessionRestoring {
    private(set) var resetCount = 0

    func restoreIfNeeded() async -> GrokSessionRestoreOutcome {
        .success
    }

    func restoreAfterRecoverableFailure() async -> GrokSessionRestoreOutcome {
        .success
    }

    func reset() {
        resetCount += 1
    }
}

final class ControllableGrokUsageService: GrokUsageFetching, @unchecked Sendable {
    struct Pending {
        let cookieHeader: String
        let continuation: CheckedContinuation<GrokUsage, Error>
    }

    private var queued: [Result<GrokUsage, Error>] = []
    private(set) var pending: [Pending] = []
    private(set) var cookieHeaders: [String] = []

    func enqueue(_ result: Result<GrokUsage, Error>) {
        queued.append(result)
    }

    func fetchUsage(
        rateLimitsCookieHeader: String,
        weeklyCookieHeader: String
    ) async throws -> GrokUsage {
        cookieHeaders.append(rateLimitsCookieHeader)
        if !queued.isEmpty {
            return try queued.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(
                Pending(cookieHeader: rateLimitsCookieHeader, continuation: continuation)
            )
        }
    }

    func completeNext(_ usage: GrokUsage) {
        let item = pending.removeFirst()
        item.continuation.resume(returning: usage)
    }
}
