import Foundation
import Testing
@testable import AIUsageBar

struct S06DCursorHoldTests {
    @Test("T-6CU-01 No Cursor card is instantiated in menu UI")
    func noCursorCardInstantiated() {
        #expect(CursorProductionPolicy.decision == .hold)
        #expect(CursorProductionPolicy.menuCardFactoryOutput() == nil)
        let visible = ProviderVisibilityPolicy(
            isChatGPTAuthenticated: true,
            isClaudeAuthenticated: true,
            isGrokAuthenticated: true
        ).visibleProviders
        #expect(visible.contains(.chatGPT))
        #expect(visible.contains(.claude))
        #expect(visible.contains(.grok))
        #expect(visible.map(\.displayName).contains("Cursor") == false)
        #expect(V2CursorHoldUsageSource().isSelectableForUI == false)
    }

    @Test("T-6CU-02 Selecting a Cursor source in tests cannot emit Provider UI state")
    func selectingCursorSourceCannotEmitProviderUIState() {
        let result = V2CursorHoldUsageSource().load(
            envelope: V2FetchEnvelope(
                httpStatus: 200,
                accountKey: "cursor-lab",
                fetchedAt: Date(),
                payload: ["remaining_percent": 40]
            ),
            previous: nil
        )
        #expect(result == .invalid)
        #expect(V2UsageSourceCatalog.uiSelectableSourceIDs().contains(.cursorHold) == false)
        #expect(CursorProductionPolicy.hasProductionUIMapping(in: [.chatGPT, .claude, .grok]) == false)
    }
}
