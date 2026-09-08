import Foundation
import Testing
@testable import AIUsageBar

struct S01FCursorUsageFixtureTests {
    @Test("T-1F-01 Fixture with remaining percent parses")
    func fixtureWithRemainingPercentParses() throws {
        let document = try CursorUsageFixtureParser.parse(jsonString: Fixtures.withRemaining)
        #expect(document.remainingPercent == 42)
    }

    @Test("T-1F-02 ResetAt present parses")
    func resetAtPresentParses() throws {
        let document = try CursorUsageFixtureParser.parse(jsonString: Fixtures.withRemaining)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        #expect(document.resetAt == iso.date(from: "2026-09-08T18:00:00Z"))
    }

    @Test("T-1F-03 Missing remaining → parse failure")
    func missingRemainingIsParseFailure() {
        #expect(throws: CursorUsageParseError.missingRemaining) {
            _ = try CursorUsageFixtureParser.parse(jsonString: Fixtures.missingRemaining)
        }
    }

    @Test("T-1F-04 Policy flag default = HOLD, no menu card factory output")
    func policyDefaultIsHoldWithNoCard() {
        #expect(CursorProductionPolicy.decision == .hold)
        #expect(CursorProductionPolicy.menuCardFactoryOutput() == nil)
    }

    @Test("T-1F-05 Auto-included models are recorded, not extra user-visible meters")
    func includedModelsAreRecordedNotBilledAsMeters() throws {
        let document = try CursorUsageFixtureParser.parse(jsonString: Fixtures.withRemaining)
        #expect(document.includedModels.map(\.name) == ["composer", "tab"])
        #expect(CursorUsageFixtureParser.userVisibleMeters(from: document).isEmpty)
    }

    @Test("T-1F-06 No production Provider.cursor UI mapping exists after this sprint")
    func noProductionCursorUIMapping() {
        let shipped: [UsageProvider] = [.chatGPT, .claude, .grok]
        #expect(CursorProductionPolicy.hasProductionUIMapping(in: shipped) == false)
        #expect(shipped.map(\.displayName) == ["ChatGPT", "Claude", "Grok"])
        #expect(ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: true
        ).visibleProviders == shipped)
    }

    @Test("T-1F-07 Parser does not open ~/Library/Application Support/Cursor in unit tests")
    func parserDoesNotOpenCursorApplicationSupport() throws {
        #expect(CursorUsageFixtureParser.filesystemAccess == .forbidden)
        #expect(CursorUsageFixtureParser.applicationSupportPathHint.contains("Application Support/Cursor"))
        let inMemory = try CursorUsageFixtureParser.parse(jsonString: Fixtures.withRemaining)
        #expect(inMemory.remainingPercent == 42)
    }

    @Test("T-1F-08 Redaction helper strips tokens / emails")
    func redactionHelperStripsSecrets() {
        let raw = """
        user=cursor-lab@example.com token=sk-live-CURSORFIXTUREONLY \
        Authorization=Bearer eyJhbGciOi-not-a-real-jwt
        """
        let redacted = CursorLogRedactor.redactForLog(raw)
        #expect(redacted.contains("cursor-lab@example.com") == false)
        #expect(redacted.contains("sk-live-CURSORFIXTUREONLY") == false)
        #expect(redacted.contains("eyJhbGciOi-not-a-real-jwt") == false)
        #expect(redacted.contains("[redacted-email]"))
        #expect(redacted.contains("[redacted-token]"))
    }

    private enum Fixtures {
        static let withRemaining = """
        {
          "remaining_percent": 42,
          "resets_at": "2026-09-08T18:00:00Z",
          "included_models": ["composer", "tab"],
          "plan": "lab-fixture"
        }
        """

        static let missingRemaining = """
        {
          "resets_at": "2026-09-08T18:00:00Z",
          "included_models": ["composer"]
        }
        """
    }
}
