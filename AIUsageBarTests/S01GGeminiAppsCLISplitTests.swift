import Foundation
import Testing
@testable import AIUsageBar

struct S01GGeminiAppsCLISplitTests {
    @Test("T-1G-01 Apps fixture parses as meter family gemini-apps")
    func appsFixtureParsesAsAppsFamily() throws {
        let document = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.apps)
        #expect(document.family == .apps)
        #expect(document.family.rawValue == "gemini-apps")
        #expect(document.remainingPercent == 55)
    }

    @Test("T-1G-02 CLI / Code Assist fixture parses as meter family gemini-cli")
    func cliFixtureParsesAsCLIFamily() throws {
        let document = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.cli)
        #expect(document.family == .cli)
        #expect(document.family.rawValue == "gemini-cli")
        #expect(document.remainingPercent == 54)
    }

    @Test("T-1G-03 Two families with similar remaining are still two meters")
    func similarRemainingStaysTwoMeters() throws {
        let apps = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.apps)
        let cli = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.cli)
        #expect(abs(apps.remainingPercent - cli.remainingPercent) <= 1)
        #expect(GeminiIdentityHelper.metersRemainDistinct(apps: apps, cli: cli))
        #expect(apps.family != cli.family)
    }

    @Test("T-1G-04 Identity helper refuses to merge Apps + CLI accountKeys")
    func identityHelperRefusesToMergeFamilies() {
        #expect(
            GeminiIdentityHelper.mergeAccountKeys(apps: "user-a", cli: "user-a")
                == .refusedDistinctFamilies
        )
        #expect(
            GeminiIdentityHelper.mergeAccountKeys(apps: "user-a", cli: "user-b")
                == .refusedDistinctFamilies
        )
    }

    @Test("T-1G-05 Missing Apps source does not mark CLI unauthenticated")
    func missingAppsDoesNotUnauthenticateCLI() {
        #expect(GeminiSourcePresence.missingAppsMarksCLIUnauthenticated(true) == false)
    }

    @Test("T-1G-06 Missing CLI source does not mark Apps unauthenticated")
    func missingCLIDoesNotUnauthenticateApps() {
        #expect(GeminiSourcePresence.missingCLIMarksAppsUnauthenticated(true) == false)
    }

    @Test("T-1G-07 No Gemini menu card factory after this sprint")
    func noGeminiMenuCardFactory() {
        #expect(GeminiProductionPolicy.decision == .hold)
        #expect(GeminiProductionPolicy.menuCardFactoryOutput() == nil)
        let visible = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: true
        ).visibleProviders
        #expect(visible == [.chatGPT, .claude, .grok])
        #expect(visible.map(\.displayName).contains("Gemini") == false)
    }

    @Test("T-1G-08 Fabricated resetAt is rejected")
    func fabricatedResetAtIsRejected() {
        #expect(throws: GeminiUsageParseError.fabricatedReset) {
            _ = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.fabricatedReset)
        }
        #expect(throws: GeminiUsageParseError.fabricatedReset) {
            _ = try GeminiUsageFixtureParser.parse(jsonString: Fixtures.fabricatedResetFlag)
        }
    }

    private enum Fixtures {
        static let apps = """
        {
          "family": "gemini-apps",
          "remaining_percent": 55,
          "account_key": "apps-lab-account",
          "resets_at": "2026-09-09T00:00:00Z"
        }
        """

        static let cli = """
        {
          "family": "cli",
          "remaining_percent": 54,
          "account_key": "cli-lab-account",
          "resets_at": "2026-09-09T00:00:00Z"
        }
        """

        static let fabricatedReset = """
        {
          "family": "gemini-apps",
          "remaining_percent": 40,
          "reset_source": "fabricated",
          "resets_at": "2026-09-09T00:00:00Z"
        }
        """

        static let fabricatedResetFlag = """
        {
          "family": "gemini-cli",
          "remaining_percent": 40,
          "fabricated_reset": true
        }
        """
    }
}
