import Foundation

enum V1UsageAdapters {
    static func chatGPTSnapshot(
        usage: ChatGPTUsage,
        token: String,
        asOf: Date = Date()
    ) -> UsageSnapshot {
        var meters: [UsageMeter] = [
            UsageMeter(
                meterId: "chatgpt.primary_window",
                window: .rolling5Hour,
                remainingPercent: usage.sessionRemainingPercent,
                usedPercent: max(0, 100 - usage.sessionRemainingPercent),
                resetAt: nil,
                isDisplayedPrimary: true
            )
        ]
        if let weekly = usage.weeklyRemainingPercent {
            meters.append(
                UsageMeter(
                    meterId: "chatgpt.secondary_window",
                    window: .weekly,
                    remainingPercent: weekly,
                    usedPercent: max(0, 100 - weekly),
                    resetAt: nil,
                    isDisplayedPrimary: false
                )
            )
        }
        return UsageSnapshot(
            provider: .chatGPT,
            accountKey: UsageIdentity.fingerprint(token),
            accountKeyUnavailable: token.isEmpty,
            sourceType: .appWebKit,
            asOf: asOf,
            meters: meters,
            health: token.isEmpty ? .unauthorized : .available
        )
    }

    static func claudeSnapshot(
        usage: ClaudeUsage,
        sessionKey: String,
        organizationID: String?,
        asOf: Date = Date()
    ) -> UsageSnapshot {
        let accountKey = organizationID.map(UsageIdentity.fingerprint)
        return UsageSnapshot(
            provider: .claude,
            accountKey: accountKey,
            accountKeyUnavailable: accountKey == nil,
            sourceType: .appWebKit,
            asOf: asOf,
            meters: [
                UsageMeter(
                    meterId: "claude.five_hour",
                    window: .rolling5Hour,
                    remainingPercent: usage.sessionRemainingPercent,
                    usedPercent: max(0, 100 - usage.sessionRemainingPercent),
                    resetAt: nil,
                    isDisplayedPrimary: true
                ),
                UsageMeter(
                    meterId: "claude.seven_day",
                    window: .rolling7Day,
                    remainingPercent: usage.weeklyRemainingPercent,
                    usedPercent: max(0, 100 - usage.weeklyRemainingPercent),
                    resetAt: nil,
                    isDisplayedPrimary: false
                )
            ],
            health: sessionKey.isEmpty ? .unauthorized : .available
        )
    }

    static func grokSnapshot(
        usage: GrokUsage,
        sso: String,
        asOf: Date = Date()
    ) -> UsageSnapshot {
        var meters: [UsageMeter] = [
            UsageMeter(
                meterId: "grok.short",
                window: .rollingCustom,
                remainingPercent: usage.sessionRemainingPercent,
                usedPercent: max(0, 100 - usage.sessionRemainingPercent),
                resetAt: nil,
                isDisplayedPrimary: usage.weeklyRemainingPercent == nil
            )
        ]
        if let weekly = usage.weeklyRemainingPercent {
            meters.append(
                UsageMeter(
                    meterId: "grok.weekly",
                    window: .weekly,
                    remainingPercent: weekly,
                    usedPercent: max(0, 100 - weekly),
                    resetAt: nil,
                    isDisplayedPrimary: true
                )
            )
        }
        return UsageSnapshot(
            provider: .grok,
            accountKey: UsageIdentity.fingerprint(sso),
            accountKeyUnavailable: sso.isEmpty,
            sourceType: .appWebKit,
            asOf: asOf,
            meters: meters,
            health: sso.isEmpty ? .unauthorized : .available
        )
    }
}
