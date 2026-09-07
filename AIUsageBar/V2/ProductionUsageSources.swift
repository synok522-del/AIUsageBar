import Foundation

final class ChatGPTProductionUsageSource: UsageSource {
    let service: any ChatGPTUsageFetching
    let cookieHeader: String
    let accountCredential: String
    private(set) var lastUsage: ChatGPTUsage?
    var provider: UsageProviderID { .chatGPT }
    var sourceType: UsageSourceType { .appWebKit }

    init(
        service: any ChatGPTUsageFetching,
        cookieHeader: String,
        accountCredential: String
    ) {
        self.service = service
        self.cookieHeader = cookieHeader
        self.accountCredential = accountCredential
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        let usage = try await service.fetchUsage(cookieHeader: cookieHeader)
        lastUsage = usage
        return V1UsageAdapters.chatGPTSnapshot(
            usage: usage,
            token: accountCredential
        )
    }
}

final class ClaudeProductionUsageSource: UsageSource {
    let service: any ClaudeUsageFetching
    let sessionKey: String
    private(set) var lastUsage: ClaudeUsage?
    var provider: UsageProviderID { .claude }
    var sourceType: UsageSourceType { .appWebKit }

    init(service: any ClaudeUsageFetching, sessionKey: String) {
        self.service = service
        self.sessionKey = sessionKey
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        let usage = try await service.fetchUsage(sessionKey: sessionKey)
        lastUsage = usage
        return V1UsageAdapters.claudeSnapshot(
            usage: usage,
            sessionKey: sessionKey,
            organizationID: nil
        )
    }
}

final class GrokProductionUsageSource: UsageSource {
    let service: GrokUsageFetching
    let rateLimitsCookieHeader: String
    let weeklyCookieHeader: String
    let accountCredential: String
    private(set) var lastUsage: GrokUsage?
    var provider: UsageProviderID { .grok }
    var sourceType: UsageSourceType { .appWebKit }

    init(
        service: GrokUsageFetching,
        rateLimitsCookieHeader: String,
        weeklyCookieHeader: String,
        accountCredential: String
    ) {
        self.service = service
        self.rateLimitsCookieHeader = rateLimitsCookieHeader
        self.weeklyCookieHeader = weeklyCookieHeader
        self.accountCredential = accountCredential
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        let usage = try await service.fetchUsage(
            rateLimitsCookieHeader: rateLimitsCookieHeader,
            weeklyCookieHeader: weeklyCookieHeader
        )
        lastUsage = usage
        return V1UsageAdapters.grokSnapshot(usage: usage, sso: accountCredential)
    }
}

enum GrokV2RecoveryGate {
    static func isRecovered(
        snapshot: UsageSnapshot?,
        expectedAccountKey: String?,
        cookiePresent: Bool,
        webKitReady: Bool
    ) -> Bool {
        guard let snapshot else {
            return RecoverySuccessPolicy.isSuccess(
                fetchSucceeded: false,
                parsedValid: false,
                expectedAccountKey: expectedAccountKey,
                snapshotAccountKey: nil,
                accountKeyUnavailable: expectedAccountKey == nil,
                cookiePresent: cookiePresent,
                webKitReady: webKitReady
            )
        }

        let parsedValid = !snapshot.meters.isEmpty
        return RecoverySuccessPolicy.isSuccess(
            fetchSucceeded: true,
            parsedValid: parsedValid,
            expectedAccountKey: expectedAccountKey,
            snapshotAccountKey: snapshot.accountKey,
            accountKeyUnavailable: snapshot.accountKeyUnavailable,
            cookiePresent: cookiePresent,
            webKitReady: webKitReady
        )
    }
}

struct V2RuntimeState {
    var cache = UsageAccountCache()
    var notifications = UsageNotificationIdentityState()
    var grokRecovery = RecoveryCoordinator()
    var chatGPTRecovery = RecoveryCoordinator()
    var claudeRecovery = RecoveryCoordinator()
    var lastSnapshots: [UsageProviderID: UsageSnapshot] = [:]
    var pathInvocations = 0
    var fetchInvocations: [UsageProviderID: Int] = [:]
    var lastNotifiedMeterId: [UsageProviderID: String] = [:]

    mutating func noteFetch(_ provider: UsageProviderID) {
        pathInvocations += 1
        fetchInvocations[provider, default: 0] += 1
    }

    mutating func commit(_ snapshot: UsageSnapshot, now: Date = Date()) {
        lastSnapshots[snapshot.provider] = snapshot
        cache.store(snapshot)
        if let primary = snapshot.displayedPrimaryMeter,
           let accountKey = snapshot.accountKey {
            let identity = UsageCacheIdentity(
                provider: snapshot.provider,
                accountKey: accountKey,
                meterId: primary.meterId,
                window: primary.window
            )
            if notifications.shouldNotify(
                identity: identity,
                remainingPercent: primary.remainingPercent,
                isLoaded: true,
                hasError: false
            ) {
                lastNotifiedMeterId[snapshot.provider] = primary.meterId
            }
        }
        _ = now
    }

    mutating func invalidateProvider(_ provider: UsageProviderID, accountKey: String?) {
        switch provider {
        case .grok:
            grokRecovery.invalidate()
        case .chatGPT:
            chatGPTRecovery.invalidate()
        case .claude:
            claudeRecovery.invalidate()
        default:
            break
        }
        if let accountKey {
            cache.invalidateAccount(provider: provider, accountKey: accountKey)
            notifications.resetAccount(provider: provider, accountKey: accountKey)
        }
        lastSnapshots[provider] = nil
        lastNotifiedMeterId[provider] = nil
    }
}
