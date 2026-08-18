//
//  UsageInfo.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import Foundation

struct UsageInfo {
    var sessionPercent: Int = 0
    var weeklyPercent: Int = 0
    var resetText: String = ""
    var isLoaded: Bool = false
    var errorMessage: String?
}
