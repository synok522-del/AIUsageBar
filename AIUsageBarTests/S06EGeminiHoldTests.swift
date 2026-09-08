import Foundation
import Testing
@testable import AIUsageBar

struct S06EGeminiHoldTests {
    @Test("T-6GE-01 No Gemini card unless both source PASS and a later spec authorizes UI")
    func noGeminiCardWithoutAuthorization() {
        #expect(GeminiProductionPolicy.decision == .hold)
        #expect(GeminiProductionPolicy.menuCardFactoryOutput() == nil)
        #expect(V2GeminiAppsUsageSource().isSelectableForUI == false)
        #expect(V2GeminiCLIUsageSource().isSelectableForUI == false)
        let visible = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: true
        ).visibleProviders
        #expect(visible.map(\.displayName).contains("Gemini") == false)
    }

    @Test("T-6GE-02 Apps and CLI remain distinct identities")
    func appsAndCLIRemainDistinctIdentities() {
        let apps = V2IdentityKey(
            provider: .geminiApps,
            accountKey: "user-1",
            meterId: "gemini.apps",
            window: .daily
        )!
        let cli = V2IdentityKey(
            provider: .geminiCLI,
            accountKey: "user-1",
            meterId: "gemini.cli",
            window: .daily
        )!
        #expect(V2MeterCache().sharesSlot(apps, cli) == false)
        #expect(apps.provider != cli.provider)
    }

    @Test("T-6GE-03 A merged Apps+CLI snapshot is rejected")
    func mergedAppsCLISnapshotIsRejected() {
        #expect(
            GeminiIdentityHelper.mergeAccountKeys(apps: "user-1", cli: "user-1")
                == .refusedDistinctFamilies
        )
        let apps = try? GeminiUsageFixtureParser.parse(jsonString: """
        {"family":"gemini-apps","remaining_percent":40,"account_key":"user-1"}
        """)
        let cli = try? GeminiUsageFixtureParser.parse(jsonString: """
        {"family":"gemini-cli","remaining_percent":40,"account_key":"user-1"}
        """)
        #expect(apps?.family == .apps)
        #expect(cli?.family == .cli)
        #expect(apps?.family != cli?.family)
    }
}
