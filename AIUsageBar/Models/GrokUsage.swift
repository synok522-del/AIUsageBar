//
//  GrokUsage.swift
//  AIUsageBar
//

import Foundation

struct GrokUsage {
    let sessionRemainingPercent: Int
    let resetText: String
    let sessionWindowSeconds: Int
    let weeklyRemainingPercent: Int?
    let weeklyResetText: String?
    let weeklyRelativeResetText: String?
    let sessionResetAt: Date?
    let weeklyResetAt: Date?
    let weeklyRateLimited: Bool
    let weeklyRateLimitRetryAfter: TimeInterval?

    init(
        sessionRemainingPercent: Int,
        resetText: String,
        sessionWindowSeconds: Int,
        weeklyRemainingPercent: Int?,
        weeklyResetText: String?,
        weeklyRelativeResetText: String?,
        sessionResetAt: Date? = nil,
        weeklyResetAt: Date? = nil,
        weeklyRateLimited: Bool = false,
        weeklyRateLimitRetryAfter: TimeInterval? = nil
    ) {
        self.sessionRemainingPercent = sessionRemainingPercent
        self.resetText = resetText
        self.sessionWindowSeconds = sessionWindowSeconds
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetText = weeklyResetText
        self.weeklyRelativeResetText = weeklyRelativeResetText
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
        self.weeklyRateLimited = weeklyRateLimited
        self.weeklyRateLimitRetryAfter = weeklyRateLimitRetryAfter
    }
}
