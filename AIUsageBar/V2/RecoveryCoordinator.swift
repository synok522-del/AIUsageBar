import Foundation

enum RecoveryState: String, Equatable, Sendable {
    case healthy
    case recovering
    case backoff
    case requiresUserAction
}

struct RecoveryScope: Hashable, Sendable {
    var provider: UsageProviderID
    var accountKey: String
}

struct RecoveryPolicy {
    var restoreAttemptsPerFailure = 1
    var retryFetchesAfterRestore = 1
    var cooldown: TimeInterval = 15
    var circuitWindow: TimeInterval = 10 * 60
    var circuitFailureLimit = 3
}

struct RecoveryCoordinator {
    private(set) var state: RecoveryState = .healthy
    private(set) var generation: UInt = 0
    private var activeScope: RecoveryScope?
    private var failureTimes: [Date] = []
    var policy = RecoveryPolicy()
    private var backoffUntil: Date?
    private(set) var restoresUsed = 0
    private(set) var retriesUsed = 0

    mutating func invalidate() {
        generation += 1
        activeScope = nil
        state = .healthy
        backoffUntil = nil
        failureTimes = []
        restoresUsed = 0
        retriesUsed = 0
    }

    mutating func beginRecovery(scope: RecoveryScope, now: Date = Date()) -> Bool {
        if state == .requiresUserAction {
            return false
        }
        if let backoffUntil, now < backoffUntil {
            state = .backoff
            return false
        }
        if let activeScope, activeScope != scope {
            return false
        }
        if activeScope == scope, state == .recovering {
            return false
        }
        activeScope = scope
        state = .recovering
        restoresUsed = 0
        retriesUsed = 0
        return true
    }

    mutating func consumeRestoreAttempt() -> Bool {
        guard state == .recovering else {
            return false
        }
        guard restoresUsed < policy.restoreAttemptsPerFailure else {
            return false
        }
        restoresUsed += 1
        return true
    }

    mutating func consumeRetryFetch() -> Bool {
        guard state == .recovering else {
            return false
        }
        guard retriesUsed < policy.retryFetchesAfterRestore else {
            return false
        }
        retriesUsed += 1
        return true
    }

    mutating func markSuccess() {
        state = .healthy
        activeScope = nil
        failureTimes = []
        backoffUntil = nil
        restoresUsed = 0
        retriesUsed = 0
    }

    mutating func markRequiresUserAction() {
        state = .requiresUserAction
        activeScope = nil
        backoffUntil = nil
    }

    mutating func markFailure(now: Date = Date()) {
        failureTimes.append(now)
        failureTimes = failureTimes.filter { now.timeIntervalSince($0) <= policy.circuitWindow }
        if failureTimes.count >= policy.circuitFailureLimit {
            state = .requiresUserAction
            activeScope = nil
            return
        }
        state = .backoff
        backoffUntil = now.addingTimeInterval(policy.cooldown)
        activeScope = nil
    }

    func shouldCommit(captured: UInt) -> Bool {
        captured == generation
    }
}

enum RecoverySuccessPolicy {
    /// Cookie/WK state may enable a retry but never proves recovery.
    static func isSuccess(
        fetchSucceeded: Bool,
        parsedValid: Bool,
        expectedAccountKey: String?,
        snapshotAccountKey: String?,
        accountKeyUnavailable: Bool,
        cookiePresent: Bool = false,
        webKitReady: Bool = false
    ) -> Bool {
        _ = cookiePresent
        _ = webKitReady
        guard fetchSucceeded, parsedValid else {
            return false
        }

        if let expectedAccountKey {
            return snapshotAccountKey == expectedAccountKey
        }

        return accountKeyUnavailable && snapshotAccountKey == nil
    }
}
