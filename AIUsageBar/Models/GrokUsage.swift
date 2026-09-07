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

    init(
        sessionRemainingPercent: Int,
        resetText: String,
        sessionWindowSeconds: Int,
        weeklyRemainingPercent: Int?,
        weeklyResetText: String?,
        weeklyRelativeResetText: String?,
        sessionResetAt: Date? = nil,
        weeklyResetAt: Date? = nil
    ) {
        self.sessionRemainingPercent = sessionRemainingPercent
        self.resetText = resetText
        self.sessionWindowSeconds = sessionWindowSeconds
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetText = weeklyResetText
        self.weeklyRelativeResetText = weeklyRelativeResetText
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
    }
}
