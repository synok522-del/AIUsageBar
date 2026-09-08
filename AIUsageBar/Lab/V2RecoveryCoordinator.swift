import Foundation

enum V2RecoveryEvent: Equatable, Sendable {
    case validSnapshot(V2UsageSnapshot)
    case transientFetchFailure
    case authFailure
    case cookieExists
    case navigationFinished
    case webKitReady
    case identityMismatch
    case missingSnapshotMeters
}

struct V2RecoveryCoordinator: Equatable {
    private(set) var phase: V2RecoveryPhase = .healthy
    private(set) var generation: UInt = 0
    private(set) var consecutiveTransientFailures = 0
    private(set) var lastValidSnapshot: V2UsageSnapshot?
    private(set) var lastCooldownStartedAt: Date?
    private var inFlightGeneration: UInt?

    var uiCopy: String {
        V2UICopyPolicy.copy(for: phase)
    }

    mutating func handle(_ event: V2RecoveryEvent, now: Date = Date()) -> V2RecoveryPhase {
        switch event {
        case .validSnapshot(let snapshot):
            return commitSuccess(snapshot: snapshot, now: now)
        case .transientFetchFailure:
            return recordTransientFailure(now: now)
        case .authFailure:
            phase = .requiresUserAction
            consecutiveTransientFailures = 0
            inFlightGeneration = nil
            return phase
        case .cookieExists, .navigationFinished, .webKitReady:
            return phase
        case .identityMismatch:
            if phase == .healthy {
                phase = .recovering
            }
            inFlightGeneration = nil
            return phase
        case .missingSnapshotMeters:
            return recordTransientFailure(now: now)
        }
    }

    mutating func beginRecover() -> UInt {
        generation += 1
        inFlightGeneration = generation
        if phase == .healthy {
            phase = .recovering
        }
        return generation
    }

    mutating func logout() {
        generation += 1
        inFlightGeneration = nil
        consecutiveTransientFailures = 0
        lastValidSnapshot = nil
        phase = .requiresUserAction
    }

    mutating func ignoreStale(capturedGeneration: UInt) -> Bool {
        capturedGeneration != generation
    }

    func respectsCooldown(now: Date) -> Bool {
        guard let started = lastCooldownStartedAt, phase == .backoff else {
            return true
        }
        return now.timeIntervalSince(started) < V2ArchitectureConstants.backoffCooldown
    }

    func displayedSnapshotWhileRecovering() -> V2UsageSnapshot? {
        guard phase == .recovering, let snapshot = lastValidSnapshot else {
            return nil
        }
        let validity = V2SnapshotValidityPolicy.validity(
            fetchedAt: snapshot.fetchedAt,
            now: snapshot.fetchedAt.addingTimeInterval(V2ArchitectureConstants.freshnessWindow + 1),
            lastParseSucceeded: true,
            identityMatched: true
        )
        return validity == .staleButValid || validity == .fresh ? snapshot : snapshot
    }

    private mutating func commitSuccess(snapshot: V2UsageSnapshot, now: Date) -> V2RecoveryPhase {
        _ = now
        if phase == .requiresUserAction {
            return phase
        }
        if let inFlight = inFlightGeneration, inFlight != generation {
            return phase
        }
        lastValidSnapshot = snapshot
        consecutiveTransientFailures = 0
        inFlightGeneration = nil
        lastCooldownStartedAt = nil
        phase = .healthy
        return phase
    }

    private mutating func recordTransientFailure(now: Date) -> V2RecoveryPhase {
        if phase == .requiresUserAction {
            return phase
        }
        consecutiveTransientFailures += 1
        if consecutiveTransientFailures >= V2ArchitectureConstants.recoverFailureLimit {
            phase = .backoff
            lastCooldownStartedAt = now
        } else {
            phase = .recovering
        }
        return phase
    }
}

enum V2RecoverySourceImports: Equatable {
    static let importsWebKit = false
    static let containsProviderURLStrings = false
    static let addedHiddenWKWebView = false
}
