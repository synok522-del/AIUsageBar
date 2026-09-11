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
                resetAt: usage.sessionResetAt,
                isDisplayedPrimary: true,
                resetText: usage.resetText
            )
        ]
        if let weekly = usage.weeklyRemainingPercent {
            meters.append(
                UsageMeter(
                    meterId: "chatgpt.secondary_window",
                    window: .weekly,
                    remainingPercent: weekly,
                    usedPercent: max(0, 100 - weekly),
                    resetAt: usage.weeklyResetAt,
                    isDisplayedPrimary: false,
                    resetText: usage.weeklyResetText
                )
            )
        }
        let accountKey = UsageIdentity.accountKey(from: token)
        return UsageSnapshot(
            provider: .chatGPT,
            accountKey: accountKey,
            accountKeyUnavailable: accountKey == nil,
            sourceType: .appWebKit,
            asOf: asOf,
            meters: meters,
            health: .available
        )
    }

    static func claudeSnapshot(
        usage: ClaudeUsage,
        sessionKey: String,
        organizationID: String?,
        asOf: Date = Date()
    ) -> UsageSnapshot {
        let accountKey = UsageIdentity.accountKey(from: sessionKey)
            ?? organizationID.flatMap(UsageIdentity.accountKey(from:))
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
                    resetAt: usage.sessionResetAt,
                    isDisplayedPrimary: true,
                    resetText: usage.resetText
                ),
                UsageMeter(
                    meterId: "claude.seven_day",
                    window: .rolling7Day,
                    remainingPercent: usage.weeklyRemainingPercent,
                    usedPercent: max(0, 100 - usage.weeklyRemainingPercent),
                    resetAt: usage.weeklyResetAt,
                    isDisplayedPrimary: false,
                    resetText: usage.weeklyResetText
                )
            ],
            health: .available
        )
    }

    static func droppingElapsedGrokWeekly(_ usage: GrokUsage, now: Date = Date()) -> GrokUsage {
        guard let weeklyResetAt = usage.weeklyResetAt, weeklyResetAt <= now else {
            return usage
        }
        return GrokUsage(
            sessionRemainingPercent: usage.sessionRemainingPercent,
            resetText: usage.resetText,
            sessionWindowSeconds: usage.sessionWindowSeconds,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil,
            weeklyRelativeResetText: nil,
            sessionResetAt: usage.sessionResetAt,
            weeklyResetAt: nil,
            weeklyRateLimited: usage.weeklyRateLimited,
            weeklyRateLimitRetryAfter: usage.weeklyRateLimitRetryAfter
        )
    }

    static func grokSnapshot(
        usage: GrokUsage,
        sso: String,
        asOf: Date = Date()
    ) -> UsageSnapshot {
        let usage = droppingElapsedGrokWeekly(usage, now: asOf)
        var meters: [UsageMeter] = [
            UsageMeter(
                meterId: "grok.short",
                window: .rollingCustom,
                remainingPercent: usage.sessionRemainingPercent,
                usedPercent: max(0, 100 - usage.sessionRemainingPercent),
                resetAt: usage.sessionResetAt,
                isDisplayedPrimary: usage.weeklyRemainingPercent == nil,
                resetText: usage.resetText,
                windowDurationSeconds: usage.sessionWindowSeconds > 0 ? usage.sessionWindowSeconds : nil
            )
        ]
        if let weekly = usage.weeklyRemainingPercent {
            meters.append(
                UsageMeter(
                    meterId: "grok.weekly",
                    window: .weekly,
                    remainingPercent: weekly,
                    usedPercent: max(0, 100 - weekly),
                    resetAt: usage.weeklyResetAt,
                    isDisplayedPrimary: true,
                    resetText: usage.weeklyResetText,
                    weeklyRelativeResetText: usage.weeklyRelativeResetText
                )
            )
        }
        let accountKey = UsageIdentity.accountKey(from: sso)
        return UsageSnapshot(
            provider: .grok,
            accountKey: accountKey,
            accountKeyUnavailable: accountKey == nil,
            sourceType: .appWebKit,
            asOf: asOf,
            meters: meters,
            health: .available
        )
    }
}
