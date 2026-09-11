import Foundation

/// Per-provider refresh lane bookkeeping.
///
/// ChatGPT, Claude, and Grok each have at most one logical in-flight refresh.
/// Duplicate triggers join that flight instead of starting another HTTP cycle.
struct ProviderRefreshLaneBook {
    struct Lane: Equatable {
        var epoch: UInt = 0
        var inFlight = false
    }

    private var lanes: [UsageProviderID: Lane] = [:]

    mutating func begin(_ provider: UsageProviderID) -> UInt {
        var lane = lanes[provider] ?? Lane()
        lane.epoch += 1
        lane.inFlight = true
        lanes[provider] = lane
        return lane.epoch
    }

    func isCurrent(_ provider: UsageProviderID, epoch: UInt) -> Bool {
        guard let lane = lanes[provider] else {
            return false
        }
        return lane.inFlight && lane.epoch == epoch
    }

    mutating func finish(_ provider: UsageProviderID, epoch: UInt) {
        guard var lane = lanes[provider], lane.epoch == epoch else {
            return
        }
        lane.inFlight = false
        // Bump so a cancelled inner task cannot commit after the lane is free.
        lane.epoch += 1
        lanes[provider] = lane
    }

    func isInFlight(_ provider: UsageProviderID) -> Bool {
        lanes[provider]?.inFlight ?? false
    }

    var anyInFlight: Bool {
        lanes.values.contains(where: \.inFlight)
    }
}

struct ProviderRefreshDeadlines: Equatable, Sendable {
    var chatGPT: TimeInterval
    var claude: TimeInterval
    var grok: TimeInterval
    var cookieStore: TimeInterval

    static let production = ProviderRefreshDeadlines(
        chatGPT: 60,
        claude: 60,
        // Grok restore is budgeted at 20s plus two 15s HTTP attempts and
        // bounded cookie waits, so 60s is too tight for a single logical flight.
        grok: 90,
        cookieStore: 8
    )

    func timeout(for provider: UsageProviderID) -> TimeInterval {
        switch provider {
        case .chatGPT:
            return chatGPT
        case .claude:
            return claude
        case .grok:
            return grok
        default:
            return chatGPT
        }
    }
}

enum ProviderRefreshTimeoutError: Error, Equatable, LocalizedError {
    case timedOut

    var errorDescription: String? {
        "更新逾時，請稍後再試"
    }
}

enum ProviderRefreshLaneRace: Sendable {
    case finished(Bool)
    case timedOut
}

enum StaleUsagePresentation {
    static func caption(asOf: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: asOf, relativeTo: now)
        return "上次更新 \(relative)"
    }
}
