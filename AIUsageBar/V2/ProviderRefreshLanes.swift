import Foundation

/// Per-provider refresh lane bookkeeping.
///
/// ChatGPT, Claude, and Grok each have at most one logical in-flight refresh.
/// Duplicate triggers join that flight instead of starting another HTTP cycle.
struct ProviderRefreshLaneBook {
    struct Lane: Equatable {
        var epoch: UInt = 0
        var inFlight = false
        var terminal = false
        var claimedSuccess = false
    }

    private var lanes: [UsageProviderID: Lane] = [:]

    mutating func begin(_ provider: UsageProviderID) -> UInt {
        var lane = lanes[provider] ?? Lane()
        lane.epoch += 1
        lane.inFlight = true
        lane.terminal = false
        lane.claimedSuccess = false
        lanes[provider] = lane
        return lane.epoch
    }

    func isCurrent(_ provider: UsageProviderID, epoch: UInt) -> Bool {
        guard let lane = lanes[provider] else {
            return false
        }
        return lane.inFlight && lane.epoch == epoch && !lane.terminal
    }

    func currentEpoch(_ provider: UsageProviderID) -> UInt {
        lanes[provider]?.epoch ?? 0
    }

    /// Atomically chooses the single winner for this lane epoch.
    /// Timeout/failure invalidates the epoch immediately so late work cannot commit.
    mutating func claim(
        _ provider: UsageProviderID,
        epoch: UInt,
        success: Bool
    ) -> Bool {
        guard var lane = lanes[provider],
              lane.epoch == epoch,
              lane.inFlight,
              !lane.terminal else {
            return false
        }
        lane.terminal = true
        lane.claimedSuccess = success
        if !success {
            lane.inFlight = false
            lane.epoch += 1
        }
        lanes[provider] = lane
        return true
    }

    func claimedSuccess(_ provider: UsageProviderID, epoch: UInt) -> Bool {
        guard let lane = lanes[provider], lane.epoch == epoch else {
            return false
        }
        return lane.claimedSuccess
    }

    /// Drops in-flight ownership so a new identity can start its own flight.
    @discardableResult
    mutating func abort(_ provider: UsageProviderID) -> UInt {
        var lane = lanes[provider] ?? Lane()
        let abortedEpoch = lane.epoch
        lane.inFlight = false
        lane.terminal = true
        lane.claimedSuccess = false
        lane.epoch += 1
        lanes[provider] = lane
        return abortedEpoch
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
        L10n.timeout
    }
}

enum ProviderRefreshLaneRace: Sendable {
    case finished(Bool)
    case timedOut
}

enum StaleUsagePresentation {
    static func caption(asOf: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: asOf, relativeTo: now)
        return L10n.lastUpdated(relative)
    }
}
