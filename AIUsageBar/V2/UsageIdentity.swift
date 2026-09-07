import Foundation

struct UsageAccountCache {
    private var snapshots: [UsageCacheIdentity: UsageSnapshot] = [:]

    mutating func store(_ snapshot: UsageSnapshot) {
        guard !snapshot.accountKeyUnavailable else {
            return
        }
        for identity in snapshot.cacheIdentities {
            snapshots[identity] = snapshot
        }
    }

    func snapshot(for identity: UsageCacheIdentity) -> UsageSnapshot? {
        guard identity.accountKey != nil else {
            return nil
        }
        return snapshots[identity]
    }

    mutating func invalidateAccount(provider: UsageProviderID, accountKey: String) {
        snapshots = snapshots.filter { key, _ in
            !(key.provider == provider && key.accountKey == accountKey)
        }
    }
}

struct UsageNotificationIdentityState {
    var threshold = 20
    private var lastValidPercent: [UsageCacheIdentity: Int] = [:]
    private var notified: Set<UsageCacheIdentity> = []

    mutating func shouldNotify(
        identity: UsageCacheIdentity,
        remainingPercent: Int?,
        isLoaded: Bool,
        hasError: Bool
    ) -> Bool {
        guard isLoaded,
              !hasError,
              let remainingPercent,
              (0...100).contains(remainingPercent),
              identity.accountKey != nil else {
            return false
        }

        let previous = lastValidPercent[identity]
        lastValidPercent[identity] = remainingPercent

        if remainingPercent > threshold {
            notified.remove(identity)
            return false
        }

        guard let previous,
              previous > threshold,
              !notified.contains(identity) else {
            return false
        }

        notified.insert(identity)
        return true
    }

    mutating func resetAccount(provider: UsageProviderID, accountKey: String) {
        lastValidPercent = lastValidPercent.filter { key, _ in
            !(key.provider == provider && key.accountKey == accountKey)
        }
        notified = Set(notified.filter { key in
            !(key.provider == provider && key.accountKey == accountKey)
        })
    }
}
