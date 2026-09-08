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

enum V2GrokProductionSource {
    static let shortWindowPath = "rest/rate-limits"
    static let shortWindowModel = "grok-3"
    static let localChallengerEnabled = false
}

enum GrokV2RecoveryInterpretation {
    /// Restorer READY is a credential probe latch. Card HEALTHY needs usage parse.
    static func cardPhase(
        restorerPhase: GrokSessionRestorerPhase,
        usageParseSucceeded: Bool,
        identityMatched: Bool = true
    ) -> V2RecoveryPhase {
        _ = restorerPhase
        if usageParseSucceeded && identityMatched {
            return .healthy
        }
        return .recovering
    }

    static func cookieExistsIsCredentialProbeOnly(_ cookieExists: Bool) -> Bool {
        cookieExists
    }

    static func keychainSSOIsCredentialOnly(_ header: String?) -> Bool {
        header != nil
    }

    static func uiCopy(
        restorerPhase: GrokSessionRestorerPhase,
        usageParseSucceeded: Bool
    ) -> String {
        V2UICopyPolicy.copy(
            for: cardPhase(
                restorerPhase: restorerPhase,
                usageParseSucceeded: usageParseSucceeded
            )
        )
    }
}
