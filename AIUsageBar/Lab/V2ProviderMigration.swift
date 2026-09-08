import Foundation

enum V2ChatGPTProductionSource {
    static let usagePath = "backend-api/wham/usage"
    static let liveEquivalenceVerdict = ChatGPTCodexEquivalenceVerdict.notProven

    static func selectedSource(
        verdict: ChatGPTCodexEquivalenceVerdict = liveEquivalenceVerdict
    ) -> V2UsageSourceID {
        _ = verdict
        return .chatGPTWeb
    }

    static func isCodexEnabled(verdict: ChatGPTCodexEquivalenceVerdict) -> Bool {
        verdict == .provenEquivalent
    }

    static var introducesHiddenWKWebViewRestorer: Bool { false }
}

enum V2ClaudeProductionSource {
    static let webHost = "claude.ai"
    static var oauthCredentialReuseEnabled: Bool { false }

    static func selectedSource(bridge: ClaudeStatuslineBridgeConfig) -> ClaudeLabSource {
        ClaudeLabSourceSelector.source(for: bridge)
    }
}
