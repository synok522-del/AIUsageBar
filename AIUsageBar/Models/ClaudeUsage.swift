//
//  ClaudeUsage.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import Foundation

struct ClaudeUsage {
    let sessionRemainingPercent: Int
    let weeklyRemainingPercent: Int
    let resetText: String
    let weeklyResetText: String
    let sessionResetAt: Date?
    let weeklyResetAt: Date?

    init(
        sessionRemainingPercent: Int,
        weeklyRemainingPercent: Int,
        resetText: String,
        weeklyResetText: String,
        sessionResetAt: Date? = nil,
        weeklyResetAt: Date? = nil
    ) {
        self.sessionRemainingPercent = sessionRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.resetText = resetText
        self.weeklyResetText = weeklyResetText
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
    }
}
