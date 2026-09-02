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
    /// Removable 17F-014 live-probe line. Not a production Weekly field.
    let weeklyRPCDiagnostic: String?
}
