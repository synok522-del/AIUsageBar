import Foundation
import Testing
@testable import AIUsageBar

struct LocalizationTests {
    @Test("English and Traditional Chinese expose the settings chrome")
    func settingsChromeHasBothLanguages() {
        #expect(L10n.t(.settings, language: .chineseTraditional) == "設定")
        #expect(L10n.t(.settings, language: .english) == "Settings")
        #expect(L10n.t(.signedIn, language: .english) == "Signed in")
        #expect(L10n.t(.signedOut, language: .english) == "Signed out")
        #expect(L10n.t(.quitApp, language: .english) == "Quit AIUsageBar")
    }

    @Test("System preference follows zh vs other language codes")
    func systemPreferenceFollowsLanguageCode() {
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "zh") == .chineseTraditional)
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "zh-Hant") == .chineseTraditional)
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "zh-TW") == .chineseTraditional)
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "zh-Hans") == .chineseTraditional)
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "en") == .english)
        #expect(AppLanguagePreference.system.resolve(systemLanguageCode: "ja") == .english)
        #expect(AppLanguagePreference.chineseTraditional.resolve() == .chineseTraditional)
        #expect(AppLanguagePreference.english.resolve() == .english)
    }

    @Test("English menu bar help text names one or more providers")
    func englishMenuBarHelpText() {
        let chatGPT = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: false
        )
        #expect(
            chatGPT.menuBarHelpText(language: .english) == "ChatGPT remaining usage"
        )

        let two = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true
        )
        #expect(
            two.menuBarHelpText(language: .english) == "ChatGPT and Claude remaining usage"
        )

        let three = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: true
        )
        #expect(
            three.menuBarHelpText(language: .english)
                == "ChatGPT, Claude, and Grok remaining usage"
        )
    }

    @Test("English service errors keep the provider name")
    func englishServiceErrors() {
        #expect(
            L10n.t(.loginExpired("Grok"), language: .english)
                == "Grok sign-in expired. Please sign in again"
        )
        #expect(
            L10n.t(.wafBlocked("Grok"), language: .english)
                == "Grok was blocked by site protection. Try again later"
        )
    }

    @Test("English Grok window labels stay compact")
    func englishGrokWindowLabels() {
        #expect(GrokService.sessionRowLabel(windowSeconds: 7200, language: .english) == "2h")
        #expect(GrokService.sessionRowLabel(windowSeconds: 0, language: .english) == "Short")
        #expect(
            GrokService.sessionRowLabel(windowSeconds: 90, language: .english) == "1m 30s"
        )
    }

    @Test("English status and notification copy uses ASCII punctuation")
    func englishStatusAndNotificationCopy() {
        #expect(
            L10n.t(.providerStatus("Claude", "Update failed"), language: .english)
                == "Claude: Update failed"
        )
        #expect(
            UsageRefreshStatePolicy.shouldClearStatusMessage(
                "Claude: Update failed",
                for: "Claude"
            )
        )
        #expect(
            UsageRefreshStatePolicy.shouldClearStatusMessage(
                "Claude signed in",
                for: "Claude"
            )
        )
        #expect(
            L10n.t(.lowUsageBodyWithReset(18, "Resets in 2 hours"), language: .english)
                == "18% remaining. Resets in 2 hours"
        )
    }

    @Test("English reset prefix is Resets")
    func englishResetPrefix() {
        let text = ServiceSupport.resetText(1_700_000_000, language: .english)
        #expect(text.hasPrefix("Resets "))
        #expect(
            ServiceSupport.combinedResetText(
                session: "",
                weekly: "Sep 2, 10:57 AM",
                language: .english
            ) == "Resets Sep 2, 10:57 AM"
        )
    }
}
