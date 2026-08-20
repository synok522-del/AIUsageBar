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

enum UsageRefreshStatePolicy {
    static func state(afterFailure current: UsageInfo, error: Error) -> UsageInfo? {
        guard !isCancellation(error) else {
            return nil
        }

        let message = error.localizedDescription.isEmpty
            ? "更新失敗"
            : error.localizedDescription

        guard current.isLoaded else {
            return UsageInfo(errorMessage: message)
        }

        var preserved = current
        preserved.errorMessage = message
        return preserved
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError ||
        (error as? URLError)?.code == .cancelled
    }
}
