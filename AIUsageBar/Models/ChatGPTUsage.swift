//
//  ChatGPTUsage.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import Foundation

struct ChatGPTUsage {
    let sessionRemainingPercent: Int
    let resetText: String
    let weeklyRemainingPercent: Int?
    let weeklyResetText: String?
    let sessionResetAt: Date?
    let weeklyResetAt: Date?

    init(
        sessionRemainingPercent: Int,
        resetText: String,
        weeklyRemainingPercent: Int?,
        weeklyResetText: String?,
        sessionResetAt: Date? = nil,
        weeklyResetAt: Date? = nil
    ) {
        self.sessionRemainingPercent = sessionRemainingPercent
        self.resetText = resetText
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetText = weeklyResetText
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
    }
}
