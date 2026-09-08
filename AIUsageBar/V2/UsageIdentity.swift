import Foundation

struct UsageAccountCache {
    private var snapshots: [UsageCacheIdentity: UsageSnapshot] = [:]

    mutating func store(_ snapshot: UsageSnapshot) {
        guard !snapshot.accountKeyUnavailable, let accountKey = snapshot.accountKey else {
            return
        }
        invalidateAccount(provider: snapshot.provider, accountKey: accountKey)
        for identity in snapshot.cacheIdentities {
            snapshots[identity] = snapshot
        }
    }

    func snapshot(for identity: UsageCacheIdentity, now: Date = Date()) -> UsageSnapshot? {
        guard identity.accountKey != nil, let snapshot = snapshots[identity] else { return nil }
        let validity = snapshot.validity(
            now: now,
            expectedAccountKey: identity.accountKey,
            meterId: identity.meterId,
            window: identity.window,
            durationSeconds: identity.durationSeconds
        )
        guard validity == .fresh || validity == .staleButValid else { return nil }
        return snapshot
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

    mutating func resetProvider(_ provider: UsageProviderID) {
        lastValidPercent = lastValidPercent.filter { key, _ in
            key.provider != provider
        }
        notified = Set(notified.filter { key in
            key.provider != provider
        })
    }

    func hasNotified(provider: UsageProviderID) -> Bool {
        notified.contains { $0.provider == provider }
    }

    func lastPercent(provider: UsageProviderID) -> Int? {
        let matches = lastValidPercent.filter { $0.key.provider == provider }
        if let sample = matches.first(where: { $0.key.accountKey == UsageNotificationIdentityState.sampleAccountKey }) {
            return sample.value
        }
        return matches.values.first
    }

    static let sampleAccountKey = "__aiusgbar-sample__"
}
