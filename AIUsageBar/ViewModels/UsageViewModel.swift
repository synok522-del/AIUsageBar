//
//  UsageViewModel.swift
//  AIUsageBar
//
//

import AppKit
import Combine
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {

    private enum StorageKey {
        static let claudeSessionKey = "claudeSessionKey"
        static let chatGPTSessionToken = "chatGPTSessionToken"
        static let chatGPTCookieHeader = "chatGPTCookieHeader"
        static let grokSessionToken = "grokSessionToken"
        static let grokCookieHeader = "grokCookieHeader"

        // 舊版 key
        static let oldChatGPTSessionToken = "chatgptSessionToken"
    }


    @Published var claude = UsageInfo()
    @Published var chatGPT = UsageInfo()
    @Published var grok = UsageInfo()
    @Published var statusMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?


    @Published private(set) var claudeSessionKey: String = ""

    @Published private(set) var chatGPTSessionToken: String = ""

    @Published private(set) var grokSessionToken: String = ""

    private var chatGPTCookieHeader = ""
    private var grokCookieHeader = ""
    private var grokHTTPAuthGeneration = GrokHTTPAuthGeneration()
    private var lanes = ProviderRefreshLaneBook()
    private var laneWaiters: [UsageProviderID: LaneWaiterBox] = [:]
    private var laneWork: [UsageProviderID: Task<Bool, Never>] = [:]
    private var wakeObserver: WorkspaceWakeObserver?
    private var wakeCoalesceTask: Task<Void, Never>?
    private var coalescedWakeExclusions: Set<UsageProviderID> = []
    private(set) var wakeTriggeredRefreshCount = 0


    private let claudeService: any ClaudeUsageFetching
    private let chatGPTService: any ChatGPTUsageFetching
    private let grokService: GrokUsageFetching
    private let grokSessionRestorer: GrokSessionRestoring
    private let grokCookieSource: GrokRefreshCookieSource
    private let usageNotificationManager: UsageNotificationManager
    private let lastGoodStore: LastGoodUsageStoring
    private let backoffStore: HTTPRateLimitBackoffStoring
    private let refreshDeadlines: ProviderRefreshDeadlines
    private let now: () -> Date
    private let wakeCoalesce: TimeInterval
    private var v2 = V2RuntimeState()

    private struct LaneWaiterBox {
        var epoch: UInt
        var waiters: [CheckedContinuation<Bool, Never>]
    }

    /// Claude last-good may be persisted, but cold-launch restore stays off
    /// until P0-5 org pinning can bind the snapshot to a stable organization.
    private static let coldLaunchRestoreProviders: Set<UsageProviderID> = [
        .chatGPT, .grok
    ]


    private var refreshTimer: Timer?
    private var resetRefreshTimer: Timer?
    private var resetRefreshRequests: Set<UsageCacheIdentity> = []
    private let credentialStore: KeychainManager


    init(
        claudeService: any ClaudeUsageFetching = ClaudeService(),
        chatGPTService: any ChatGPTUsageFetching = ChatGPTService(),
        grokService: GrokUsageFetching = GrokService(),
        grokSessionRestorer: GrokSessionRestoring? = nil,
        grokCookieSource: GrokRefreshCookieSource? = nil,
        usageNotificationManager: UsageNotificationManager? = nil,
        credentialStore: KeychainManager? = nil,
        persistenceDefaults: UserDefaults? = nil,
        lastGoodStore: LastGoodUsageStoring? = nil,
        backoffStore: HTTPRateLimitBackoffStoring? = nil,
        refreshDeadlines: ProviderRefreshDeadlines = .production,
        observesWorkspaceWake: Bool? = nil,
        wakeNotificationCenter: NotificationCenter? = nil,
        wakeCoalesce: TimeInterval = 0.02,
        now: @escaping () -> Date = Date.init
    ) {

        self.credentialStore = credentialStore ?? KeychainManager(inMemory: KeychainManager.isTestProcess)
        self.claudeService = claudeService
        self.chatGPTService = chatGPTService
        self.grokService = grokService
        self.grokSessionRestorer =
            grokSessionRestorer ?? GrokWebKitSessionRestorer.shared
        self.grokCookieSource =
            grokCookieSource ?? WebSessionManager.shared
        self.usageNotificationManager =
            usageNotificationManager ?? UsageNotificationManager()
        let defaults = persistenceDefaults ?? {
            if KeychainManager.isTestProcess {
                return UserDefaults(suiteName: "aiusgbar.tests.\(UUID().uuidString)") ?? .standard
            }
            return .standard
        }()
        self.lastGoodStore = lastGoodStore ?? LastGoodUsageStore(defaults: defaults)
        self.backoffStore = backoffStore ?? HTTPRateLimitBackoffStore(defaults: defaults)
        self.refreshDeadlines = refreshDeadlines
        self.now = now
        self.wakeCoalesce = max(0, wakeCoalesce)

        if !KeychainManager.isTestProcess { migrateToKeychain() }

        self.claudeSessionKey =
            self.credentialStore.read(
                StorageKey.claudeSessionKey
            ) ?? ""

        let savedChatGPTToken =
            self.credentialStore.read(
                StorageKey.chatGPTSessionToken
            ) ?? ""

        self.chatGPTSessionToken = savedChatGPTToken
        self.chatGPTCookieHeader =
            self.credentialStore.read(
                StorageKey.chatGPTCookieHeader
            ) ?? {
                guard !savedChatGPTToken.isEmpty else {
                    return ""
                }

                return "__Secure-next-auth.session-token=\(savedChatGPTToken)"
            }()

        let savedGrokToken =
            self.credentialStore.read(
                StorageKey.grokSessionToken
            ) ?? ""

        self.grokSessionToken = savedGrokToken
        self.grokCookieHeader =
            self.credentialStore.read(
                StorageKey.grokCookieHeader
            ) ?? {
                guard !savedGrokToken.isEmpty else {
                    return ""
                }

                return "sso=\(savedGrokToken)"
            }()

        restorePersistedLastGoodIfNeeded(now: now())

        if observesWorkspaceWake ?? !KeychainManager.isTestProcess {
            wakeObserver = WorkspaceWakeObserver(
                center: wakeNotificationCenter ?? NSWorkspace.shared.notificationCenter
            ) { [weak self] in
                self?.handleWake()
            }
        }

        if !KeychainManager.isTestProcess { startAutoRefresh() }
    }


    deinit {
        refreshTimer?.invalidate()
        resetRefreshTimer?.invalidate()
        wakeCoalesceTask?.cancel()
    }



    // MARK: - Keychain Migration

    private func migrateToKeychain() {

        let defaults = UserDefaults.standard


        // Claude

        if self.credentialStore.read(
            StorageKey.claudeSessionKey
        ) == nil {

            if let oldValue = defaults.string(
                forKey: StorageKey.claudeSessionKey
            ) {

                self.credentialStore.save(
                    oldValue,
                    forKey: StorageKey.claudeSessionKey
                )

                defaults.removeObject(
                    forKey: StorageKey.claudeSessionKey
                )
            }
        }


        // ChatGPT 新 key

        if self.credentialStore.read(
            StorageKey.chatGPTSessionToken
        ) == nil {


            let newValue =
            defaults.string(
                forKey: StorageKey.chatGPTSessionToken
            )


            let oldValue =
            defaults.string(
                forKey: StorageKey.oldChatGPTSessionToken
            )


            if let token = newValue ?? oldValue {

                self.credentialStore.save(
                    token,
                    forKey: StorageKey.chatGPTSessionToken
                )


                defaults.removeObject(
                    forKey: StorageKey.chatGPTSessionToken
                )

                defaults.removeObject(
                    forKey: StorageKey.oldChatGPTSessionToken
                )
            }
        }
    }



    // MARK: - Login / Logout

    func setClaudeSessionKey(_ value: String) {
        let identityChanged = claudeSessionKey != value
        if identityChanged {
            let hadFlight = lanes.isInFlight(.claude)
            abortProviderLane(.claude)
            claude = UsageInfo()
            usageNotificationManager.resetTracking(for: .claude)
            let previousAccountKey = UsageIdentity.accountKey(from: claudeSessionKey)
            v2.invalidateProvider(
                .claude,
                accountKey: previousAccountKey
            )
            if let previousAccountKey {
                lastGoodStore.remove(provider: .claude, accountKey: previousAccountKey)
                backoffStore.clear(provider: .claude, accountKey: previousAccountKey)
            }
            resetRefreshRequests = Set(resetRefreshRequests.filter { $0.provider != .claude })
            scheduleNextResetRefresh()
            claudeSessionKey = value
            persistClaudeSessionKey(value)
            if hadFlight, !value.isEmpty {
                requestRefresh(.claude)
            }
            return
        }

        claudeSessionKey = value
        persistClaudeSessionKey(value)
        if !value.isEmpty {
            surfaceBackoffStatus(provider: .claude, providerName: "Claude")
        }
    }

    private func persistClaudeSessionKey(_ value: String) {
        if value.isEmpty {

            self.credentialStore.delete(
                StorageKey.claudeSessionKey
            )

        } else {

            self.credentialStore.save(
                value,
                forKey: StorageKey.claudeSessionKey
            )
        }
    }



    func setChatGPTSessionToken(_ value: String) {

        setChatGPTCredential(
            WebCredential(
                cookieName: "__Secure-next-auth.session-token",
                value: value,
                cookieHeader: "__Secure-next-auth.session-token=\(value)"
            )
        )
    }

    func setChatGPTCredential(_ credential: WebCredential) {
        let identityChanged =
            chatGPTSessionToken != credential.value
            || chatGPTCookieHeader != credential.cookieHeader
        if identityChanged {
            let hadFlight = lanes.isInFlight(.chatGPT)
            abortProviderLane(.chatGPT)
            chatGPT = UsageInfo()
            usageNotificationManager.resetTracking(for: .chatGPT)
            let previousAccountKey = UsageIdentity.accountKey(from: chatGPTSessionToken)
            v2.invalidateProvider(
                .chatGPT,
                accountKey: previousAccountKey
            )
            if let previousAccountKey {
                lastGoodStore.remove(provider: .chatGPT, accountKey: previousAccountKey)
                backoffStore.clear(provider: .chatGPT, accountKey: previousAccountKey)
            }
            resetRefreshRequests = Set(resetRefreshRequests.filter { $0.provider != .chatGPT })
            scheduleNextResetRefresh()
            persistChatGPTCredential(credential)
            if hadFlight, !credential.value.isEmpty {
                requestRefresh(.chatGPT)
            }
            return
        }

        persistChatGPTCredential(credential)
        if !credential.value.isEmpty {
            surfaceBackoffStatus(provider: .chatGPT, providerName: "ChatGPT")
        }
    }

    private func persistChatGPTCredential(_ credential: WebCredential) {
        chatGPTSessionToken = credential.value
        chatGPTCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {

            self.credentialStore.delete(
                StorageKey.chatGPTSessionToken
            )
            self.credentialStore.delete(
                StorageKey.chatGPTCookieHeader
            )

        } else {

            self.credentialStore.save(
                credential.value,
                forKey: StorageKey.chatGPTSessionToken
            )
            self.credentialStore.save(
                credential.cookieHeader,
                forKey: StorageKey.chatGPTCookieHeader
            )
        }
    }

    func setGrokSessionToken(_ value: String) {

        setGrokCredential(
            WebCredential(
                cookieName: "sso",
                value: value,
                cookieHeader: "sso=\(value)"
            )
        )
    }

    var grokHTTPAuthGenerationValue: UInt {
        grokHTTPAuthGeneration.value
    }

    func setGrokCredential(_ credential: WebCredential) {
        let previousToken = grokSessionToken
        let previousHeader = grokCookieHeader
        let identityChanged =
            previousToken != credential.value || previousHeader != credential.cookieHeader

        if !identityChanged {
            if !credential.value.isEmpty {
                surfaceBackoffStatus(provider: .grok, providerName: "Grok")
                if skipDueToBackoff(
                    provider: .grok,
                    accountKey: UsageIdentity.accountKey(from: credential.value)
                ) {
                    requestRefresh(.grok)
                }
            }
            return
        }

        abortProviderLane(.grok)
        grokHTTPAuthGeneration.invalidate()
        let previousAccountKey = UsageIdentity.accountKey(from: previousToken)
        v2.invalidateProvider(
            .grok,
            accountKey: previousAccountKey
        )
        if let previousAccountKey {
            lastGoodStore.remove(provider: .grok, accountKey: previousAccountKey)
            backoffStore.clear(provider: .grok, accountKey: previousAccountKey)
        }
        resetRefreshRequests = Set(resetRefreshRequests.filter { $0.provider != .grok })
        scheduleNextResetRefresh()

        grokSessionToken = credential.value
        grokCookieHeader = credential.cookieHeader

        if credential.value.isEmpty {
            grok = UsageInfo()

            self.credentialStore.delete(
                StorageKey.grokSessionToken
            )
            self.credentialStore.delete(
                StorageKey.grokCookieHeader
            )
            grokSessionRestorer.reset()
            usageNotificationManager.resetTracking(for: .grok)
        } else {
            self.credentialStore.save(
                credential.value,
                forKey: StorageKey.grokSessionToken
            )
            self.credentialStore.save(
                credential.cookieHeader,
                forKey: StorageKey.grokCookieHeader
            )

            grok = UsageInfo()
            grokSessionRestorer.reset()
            usageNotificationManager.resetTracking(for: .grok)
            requestRefreshAll()
        }
    }



    // MARK: - Refresh

    func refreshAll() async {
        async let chatGPTRefresh: Bool = refreshLane(.chatGPT)
        async let claudeRefresh: Bool = refreshLane(.claude)
        // Keep Grok on this MainActor task so WKWebsiteDataStore.default()
        // first-touch cannot start on a child executor. ChatGPT/Claude remain
        // independently coalesced and can complete while Grok is in flight.
        let grokSucceeded = await refreshLane(.grok)
        let (chatGPTSucceeded, claudeSucceeded) = await (chatGPTRefresh, claudeRefresh)
        _ = (claudeSucceeded, chatGPTSucceeded, grokSucceeded)
    }

    func handleWake() {
        let providers = Set([
            UsageProviderID.chatGPT, .claude, .grok
        ].filter { lanes.isInFlight($0) })
        coalescedWakeExclusions.formUnion(providers)
        wakeCoalesceTask?.cancel()
        wakeCoalesceTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let delay = BoundedAsyncWait.nanoseconds(for: self.wakeCoalesce)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else {
                return
            }
            let excluded = self.coalescedWakeExclusions
            self.coalescedWakeExclusions.removeAll()
            self.wakeTriggeredRefreshCount += 1
            await self.refreshWakeLanes(excluding: excluded)
        }
    }

    func invalidateWakeObserver() {
        wakeObserver?.invalidate()
        wakeObserver = nil
        wakeCoalesceTask?.cancel()
        wakeCoalesceTask = nil
        coalescedWakeExclusions.removeAll()
    }

    func isProviderInFlight(_ provider: UsageProviderID) -> Bool {
        lanes.isInFlight(provider)
    }

    private func requestRefreshAll() {
        isLoading = true
        Task { @MainActor [weak self] in
            await self?.refreshAll()
        }
    }

    private func requestRefresh(_ provider: UsageProviderID) {
        isLoading = true
        Task { @MainActor [weak self] in
            _ = await self?.refreshLane(provider)
        }
    }

    private func refreshWakeLanes(excluding excluded: Set<UsageProviderID>) async {
        await withTaskGroup(of: Bool.self) { group in
            for provider in [UsageProviderID.chatGPT, .claude, .grok]
                where !excluded.contains(provider) {
                group.addTask { @MainActor [weak self] in
                    guard let self else { return false }
                    return await self.refreshLane(provider)
                }
            }
            for await _ in group { }
        }
    }

    private func refreshLane(_ provider: UsageProviderID) async -> Bool {
        if lanes.isInFlight(provider) {
            return await withCheckedContinuation { continuation in
                let epoch = lanes.currentEpoch(provider)
                if var box = laneWaiters[provider], box.epoch == epoch {
                    box.waiters.append(continuation)
                    laneWaiters[provider] = box
                } else {
                    laneWaiters[provider] = LaneWaiterBox(epoch: epoch, waiters: [continuation])
                }
            }
        }

        let epoch = lanes.begin(provider)
        isLoading = true
        let result = await executeLane(provider, epoch: epoch)
        finishLane(provider, epoch: epoch)
        resumeLaneWaiters(provider, epoch: epoch, result: result)
        return result
    }

    private func finishLane(_ provider: UsageProviderID, epoch: UInt) {
        lanes.finish(provider, epoch: epoch)
        isLoading = lanes.anyInFlight
    }

    private func resumeLaneWaiters(
        _ provider: UsageProviderID,
        epoch: UInt,
        result: Bool
    ) {
        guard let box = laneWaiters[provider], box.epoch == epoch else {
            return
        }
        laneWaiters[provider] = nil
        for waiter in box.waiters {
            waiter.resume(returning: result)
        }
    }

    private func abortProviderLane(_ provider: UsageProviderID) {
        let epoch = lanes.currentEpoch(provider)
        lanes.abort(provider)
        laneWork[provider]?.cancel()
        laneWork[provider] = nil
        resumeLaneWaiters(provider, epoch: epoch, result: false)
        if provider == .grok {
            v2.grokRecovery.abortInFlightRecovery()
        }
        isLoading = lanes.anyInFlight
    }

    private func executeLane(_ provider: UsageProviderID, epoch: UInt) async -> Bool {
        let timeout = refreshDeadlines.timeout(for: provider)
        let work = Task { @MainActor in
            await self.performLane(provider, epoch: epoch)
        }
        laneWork[provider] = work
        defer {
            if laneWork[provider] == work {
                laneWork[provider] = nil
            }
        }

        let winner = await BoundedAsyncWait.race(timeout: timeout, work: work)
        switch winner {
        case .finished(let succeeded):
            return succeeded
        case .timedOut:
            work.cancel()
            if lanes.claim(provider, epoch: epoch, success: false) {
                if provider == .grok {
                    v2.grokRecovery.abortInFlightRecovery()
                }
                applyDeadlineOutcome(provider)
                return false
            }
            return lanes.claimedSuccess(provider, epoch: epoch)
        }
    }

    private func performLane(_ provider: UsageProviderID, epoch: UInt) async -> Bool {
        switch provider {
        case .chatGPT:
            return await refreshChatGPT(epoch: epoch)
        case .claude:
            return await refreshClaude(epoch: epoch)
        case .grok:
            return await refreshGrok(epoch: epoch)
        default:
            return false
        }
    }

    private func applyDeadlineOutcome(_ provider: UsageProviderID) {
        let error = ProviderRefreshTimeoutError.timedOut
        switch provider {
        case .chatGPT:
            applyFailureState(&chatGPT, providerName: "ChatGPT", error: error)
        case .claude:
            applyFailureState(&claude, providerName: "Claude", error: error)
        case .grok:
            applyFailureState(&grok, providerName: "Grok", error: error)
        default:
            break
        }
    }

    private func applyFailureState(
        _ info: inout UsageInfo,
        providerName: String,
        error: Error
    ) {
        if let nextState = UsageRefreshStatePolicy.state(afterFailure: info, error: error, now: now()) {
            info = nextState
            let message = nextState.errorMessage ?? "更新失敗"
            statusMessage = "\(providerName)：\(message)"
        }
    }

    private func currentAccountKey(for provider: UsageProviderID) -> String? {
        switch provider {
        case .chatGPT:
            return UsageIdentity.accountKey(from: chatGPTSessionToken)
        case .claude:
            return UsageIdentity.accountKey(from: claudeSessionKey)
        case .grok:
            return UsageIdentity.accountKey(from: grokSessionToken)
        default:
            return nil
        }
    }

    private func canCommit(
        provider: UsageProviderID,
        epoch: UInt,
        capturedGeneration: UInt,
        expectedAccountKey: String?
    ) -> Bool {
        guard lanes.isCurrent(provider, epoch: epoch) else {
            return false
        }
        let generationMatches: Bool
        switch provider {
        case .chatGPT:
            generationMatches = v2.chatGPTRecovery.shouldCommit(captured: capturedGeneration)
        case .claude:
            generationMatches = v2.claudeRecovery.shouldCommit(captured: capturedGeneration)
        case .grok:
            generationMatches = true
        default:
            generationMatches = false
        }
        guard generationMatches else {
            return false
        }
        return currentAccountKey(for: provider) == expectedAccountKey
    }

    private func skipDueToBackoff(provider: UsageProviderID, accountKey: String?) -> Bool {
        guard let accountKey else {
            return false
        }
        return backoffStore.isBackingOff(
            provider: provider,
            accountKey: accountKey,
            now: now()
        )
    }

    private func recordRateLimitIfNeeded(
        provider: UsageProviderID,
        accountKey: String?,
        error: Error
    ) {
        guard error.isRateLimitedError, let accountKey else {
            return
        }
        backoffStore.record(
            provider: provider,
            accountKey: accountKey,
            retryAfter: error.rateLimitedRetryAfter,
            now: now()
        )
    }

    private func recordWeeklyRateLimit(
        provider: UsageProviderID,
        accountKey: String?,
        retryAfter: TimeInterval?
    ) {
        guard let accountKey else {
            return
        }
        backoffStore.record(
            provider: provider,
            accountKey: accountKey,
            retryAfter: retryAfter,
            now: now()
        )
    }

    private func forgetResetRefresh(for provider: UsageProviderID) {
        resetRefreshRequests = Set(resetRefreshRequests.filter { $0.provider != provider })
    }

    private func surfaceBackoffStatus(
        provider: UsageProviderID,
        providerName: String,
        accountKey: String? = nil
    ) {
        let key = accountKey ?? currentAccountKey(for: provider)
        guard let key,
              let until = backoffStore.backoffUntil(provider: provider, accountKey: key, now: now()) else {
            return
        }
        let seconds = max(1, Int(ceil(until.timeIntervalSince(now()))))
        statusMessage = "\(providerName)：請求過於頻繁，約 \(seconds) 秒後可再更新"
    }

    private func clearBackoff(provider: UsageProviderID, accountKey: String?) {
        guard let accountKey else {
            return
        }
        backoffStore.clear(provider: provider, accountKey: accountKey)
    }

    private func evaluateNotifications() {
        let snapshots = v2.lastSnapshots.filter {
            !v2.restoredFromPersistence.contains($0.key)
        }
        usageNotificationManager.evaluate(
            claude: claude,
            chatGPT: chatGPT,
            grok: grok,
            snapshots: snapshots
        )
    }

    private func restorePersistedLastGoodIfNeeded(now: Date = Date()) {
        restorePersistedLastGood(for: .chatGPT, now: now)
        restorePersistedLastGood(for: .grok, now: now)
        // Claude disk restore is intentionally skipped until P0-5 org pinning
        // can bind usage to a stable organization. Persistence still runs after
        // a verified network commit so the data is ready once org pin lands.
    }

    private func restorePersistedLastGood(for provider: UsageProviderID, now: Date) {
        guard Self.coldLaunchRestoreProviders.contains(provider) else {
            return
        }
        guard let accountKey = currentAccountKey(for: provider),
              let snapshot = lastGoodStore.load(provider: provider, accountKey: accountKey) else {
            return
        }
        guard v2.restoreLastGood(snapshot, expectedAccountKey: accountKey, now: now) else {
            return
        }
        guard let info = UsageInfoFromSnapshot.make(snapshot, stale: true, now: now) else {
            v2.invalidateProvider(provider, accountKey: accountKey)
            return
        }
        switch provider {
        case .chatGPT:
            chatGPT = info
        case .claude:
            claude = info
        case .grok:
            grok = info
        default:
            break
        }
        scheduleNextResetRefresh(now: now)
    }

    private func grokCookiesBounded() async -> [HTTPCookie] {
        let timeout = refreshDeadlines.cookieStore
        let source = grokCookieSource
        let work = Task { @MainActor in
            await source.grokCookies()
        }
        switch await BoundedAsyncWait.race(timeout: timeout, work: work) {
        case .finished(let cookies):
            return cookies
        case .timedOut:
            return []
        }
    }



    // MARK: - Auto Refresh

    private func startAutoRefresh() {

        refreshTimer?.invalidate()


        resetRefreshTimer?.invalidate()
        resetRefreshTimer = nil
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 600,
            repeats: true
        ) { [weak self] _ in


            guard let self else {
                return
            }


            Task {
                await self.refreshAll()
            }

        }
        scheduleNextResetRefresh()
    }



    // MARK: - Claude

    private func refreshClaude(epoch: UInt) async -> Bool {

        let key =
        claudeSessionKey
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !key.isEmpty else {

            claude = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }

        let expectedAccountKey = UsageIdentity.accountKey(from: key)
        if skipDueToBackoff(provider: .claude, accountKey: expectedAccountKey) {
            forgetResetRefresh(for: .claude)
            surfaceBackoffStatus(
                provider: .claude,
                providerName: "Claude",
                accountKey: expectedAccountKey
            )
            return false
        }

        let captured = v2.claudeRecovery.generation
        v2.noteFetch(.claude)
        let source = ClaudeProductionUsageSource(
            service: claudeService,
            sessionKey: key
        )

        do {
            let snapshot = try await source.fetchSnapshot()
            guard canCommit(
                provider: .claude,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            guard canCommit(
                provider: .claude,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            guard lanes.claim(.claude, epoch: epoch, success: true) else {
                return false
            }
            guard commitV2Snapshot(snapshot, now: now()) else { throw AIUsageServiceError.invalidPayload("Claude") }
            finishLane(.claude, epoch: epoch)
            applyClaude(usage, observedAt: snapshot.asOf)
            clearBackoff(provider: .claude, accountKey: expectedAccountKey)
            evaluateNotifications()
            lastUpdated = now()
            return true
        } catch {
            guard canCommit(
                provider: .claude,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            recordRateLimitIfNeeded(
                provider: .claude,
                accountKey: expectedAccountKey,
                error: error
            )
            applyFailureState(&claude, providerName: "Claude", error: error)
            evaluateNotifications()
            return false
        }
    }



    // MARK: - ChatGPT

    private func refreshChatGPT(epoch: UInt) async -> Bool {

        let token =
        chatGPTSessionToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !token.isEmpty else {

            chatGPT = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }

        let expectedAccountKey = UsageIdentity.accountKey(from: token)
        if skipDueToBackoff(provider: .chatGPT, accountKey: expectedAccountKey) {
            forgetResetRefresh(for: .chatGPT)
            surfaceBackoffStatus(
                provider: .chatGPT,
                providerName: "ChatGPT",
                accountKey: expectedAccountKey
            )
            return false
        }

        let captured = v2.chatGPTRecovery.generation
        v2.noteFetch(.chatGPT)
        let source = ChatGPTProductionUsageSource(
            service: chatGPTService,
            cookieHeader: chatGPTCookieHeader.isEmpty
                ? "__Secure-next-auth.session-token=\(token)"
                : chatGPTCookieHeader,
            accountCredential: token
        )

        do {
            let snapshot = try await source.fetchSnapshot()
            guard canCommit(
                provider: .chatGPT,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            guard canCommit(
                provider: .chatGPT,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            guard lanes.claim(.chatGPT, epoch: epoch, success: true) else {
                return false
            }
            guard commitV2Snapshot(snapshot, now: now()) else { throw AIUsageServiceError.invalidPayload("ChatGPT") }
            finishLane(.chatGPT, epoch: epoch)
            applyChatGPT(usage, observedAt: snapshot.asOf)
            clearBackoff(provider: .chatGPT, accountKey: expectedAccountKey)
            evaluateNotifications()
            lastUpdated = now()
            return true
        } catch {
            guard canCommit(
                provider: .chatGPT,
                epoch: epoch,
                capturedGeneration: captured,
                expectedAccountKey: expectedAccountKey
            ) else {
                return false
            }
            recordRateLimitIfNeeded(
                provider: .chatGPT,
                accountKey: expectedAccountKey,
                error: error
            )
            applyFailureState(&chatGPT, providerName: "ChatGPT", error: error)
            evaluateNotifications()
            return false
        }
    }



    // MARK: - Grok

    private func refreshGrok(epoch: UInt) async -> Bool {

        let token =
        grokSessionToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !token.isEmpty else {

            grok = UsageInfo(
                errorMessage: "尚未登入"
            )

            return false
        }

        let expectedAccountKey = UsageIdentity.accountKey(from: token)
        if skipDueToBackoff(provider: .grok, accountKey: expectedAccountKey) {
            forgetResetRefresh(for: .grok)
            surfaceBackoffStatus(
                provider: .grok,
                providerName: "Grok",
                accountKey: expectedAccountKey
            )
            return false
        }


        let fallbackHeader = grokCookieHeader.isEmpty
            ? "sso=\(token)"
            : grokCookieHeader
        let authGeneration = grokHTTPAuthGeneration.value

        return await fetchGrokUsage(
            fallbackHeader: fallbackHeader,
            allowRecovery: true,
            authGeneration: authGeneration,
            epoch: epoch,
            expectedAccountKey: expectedAccountKey
        )
    }

    private func fetchGrokUsage(
        fallbackHeader: String,
        allowRecovery: Bool,
        authGeneration: UInt,
        epoch: UInt,
        expectedAccountKey: String?
    ) async -> Bool {
        let recoveryLatched = v2.grokRecovery.state == .requiresUserAction
        guard canCommitGrok(epoch: epoch, authGeneration: authGeneration, expectedAccountKey: expectedAccountKey) else {
            return false
        }

        let webKitCookies = await grokCookiesBounded()
        guard canCommitGrok(epoch: epoch, authGeneration: authGeneration, expectedAccountKey: expectedAccountKey) else {
            return false
        }

        let webKitRateLimitsCookieHeader = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: webKitCookies,
            fallbackHeader: fallbackHeader,
            url: GrokSessionContext.rateLimitsURL
        )
        let webKitWeeklyCookieHeader = GrokSessionContext.cookieHeaderForRequest(
            webKitCookies: webKitCookies,
            fallbackHeader: fallbackHeader,
            url: GrokSessionContext.weeklyCreditsURL
        )
        let accountCredential = grokSessionToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let webKitCredentialsMatch =
            GrokService.ssoToken(from: webKitRateLimitsCookieHeader) == accountCredential &&
            GrokService.ssoToken(from: webKitWeeklyCookieHeader) == accountCredential
        let rateLimitsCookieHeader = webKitCredentialsMatch
            ? webKitRateLimitsCookieHeader
            : fallbackHeader
        let weeklyCookieHeader = webKitCredentialsMatch
            ? webKitWeeklyCookieHeader
            : fallbackHeader
        let source = GrokProductionUsageSource(
            service: grokService,
            rateLimitsCookieHeader: rateLimitsCookieHeader,
            weeklyCookieHeader: weeklyCookieHeader,
            accountCredential: accountCredential
        )
        v2.noteFetch(.grok)

        do {
            let snapshot = try await source.fetchSnapshot()
            guard canCommitGrok(epoch: epoch, authGeneration: authGeneration, expectedAccountKey: expectedAccountKey) else {
                return false
            }
            guard let usage = source.lastUsage else {
                return false
            }

            try Task.checkCancellation()
            if v2.grokRecovery.state == .recovering {
                let recovered = GrokV2RecoveryGate.isRecovered(
                    snapshot: snapshot,
                    expectedAccountKey: expectedAccountKey,
                    cookiePresent: true,
                    webKitReady: true
                )
                if !recovered {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(
                        AIUsageServiceError.invalidPayload("Grok recovery identity"),
                        authGeneration: authGeneration,
                        epoch: epoch,
                        expectedAccountKey: expectedAccountKey
                    )
                    return false
                }
            }

            try Task.checkCancellation()
            guard lanes.claim(.grok, epoch: epoch, success: true) else {
                return false
            }
            if v2.grokRecovery.state == .recovering {
                v2.grokRecovery.markSuccess()
            }
            guard commitV2Snapshot(snapshot, now: now()) else { throw AIUsageServiceError.invalidPayload("Grok") }
            finishLane(.grok, epoch: epoch)
            applyGrok(usage, observedAt: snapshot.asOf)
            if usage.weeklyRateLimited {
                recordWeeklyRateLimit(
                    provider: .grok,
                    accountKey: expectedAccountKey,
                    retryAfter: usage.weeklyRateLimitRetryAfter
                )
                surfaceBackoffStatus(
                    provider: .grok,
                    providerName: "Grok",
                    accountKey: expectedAccountKey
                )
            } else {
                clearBackoff(provider: .grok, accountKey: expectedAccountKey)
            }
            evaluateNotifications()
            lastUpdated = now()
            return true
        } catch {
            guard canCommitGrok(epoch: epoch, authGeneration: authGeneration, expectedAccountKey: expectedAccountKey) else {
                return false
            }

            if error.isRateLimitedError {
                recordRateLimitIfNeeded(
                    provider: .grok,
                    accountKey: expectedAccountKey,
                    error: error
                )
                applyGrokFailure(
                    error,
                    authGeneration: authGeneration,
                    epoch: epoch,
                    expectedAccountKey: expectedAccountKey
                )
                evaluateNotifications()
                return false
            }

            if recoveryLatched {
                applyGrokFailure(
                    error,
                    authGeneration: authGeneration,
                    epoch: epoch,
                    expectedAccountKey: expectedAccountKey
                )
                evaluateNotifications()
                return false
            }

            if Task.isCancelled { return false }
            if GrokHTTPRefreshAuthPolicy.shouldAttemptRecovery(
                captured: authGeneration,
                current: grokHTTPAuthGeneration.value,
                didAlreadyRetry: !allowRecovery,
                error: error
            ) {
                guard let expectedAccountKey else {
                    applyGrokFailure(
                        error,
                        authGeneration: authGeneration,
                        epoch: epoch,
                        expectedAccountKey: expectedAccountKey
                    )
                    return false
                }
                let scope = RecoveryScope(
                    provider: .grok,
                    accountKey: expectedAccountKey
                )
                guard v2.grokRecovery.beginRecovery(scope: scope) else {
                    applyGrokFailure(
                        error,
                        authGeneration: authGeneration,
                        epoch: epoch,
                        expectedAccountKey: expectedAccountKey
                    )
                    return false
                }
                guard v2.grokRecovery.consumeRestoreAttempt() else {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(
                        error,
                        authGeneration: authGeneration,
                        epoch: epoch,
                        expectedAccountKey: expectedAccountKey
                    )
                    return false
                }

                _ = await grokSessionRestorer.restoreAfterRecoverableFailure()
                guard canCommitGrok(epoch: epoch, authGeneration: authGeneration, expectedAccountKey: expectedAccountKey) else {
                    return false
                }
                guard v2.grokRecovery.consumeRetryFetch() else {
                    v2.grokRecovery.markRequiresUserAction()
                    applyGrokFailure(
                        error,
                        authGeneration: authGeneration,
                        epoch: epoch,
                        expectedAccountKey: expectedAccountKey
                    )
                    return false
                }
                return await fetchGrokUsage(
                    fallbackHeader: fallbackHeader,
                    allowRecovery: false,
                    authGeneration: authGeneration,
                    epoch: epoch,
                    expectedAccountKey: expectedAccountKey
                )
            }

            if v2.grokRecovery.state == .recovering {
                if GrokSessionRecoveryPolicy.isAuthenticationFailure(error) {
                    v2.grokRecovery.markRequiresUserAction()
                } else {
                    v2.grokRecovery.markFailure()
                }
            } else if v2.grokRecovery.state != .requiresUserAction {
                // Keep transport and malformed-response failures recoverable;
                // only an explicit authentication response may demand login.
                v2.grokRecovery.markFailure()
            }

            applyGrokFailure(
                error,
                authGeneration: authGeneration,
                epoch: epoch,
                expectedAccountKey: expectedAccountKey
            )
            evaluateNotifications()
            return false
        }
    }

    private func canCommitGrok(
        epoch: UInt,
        authGeneration: UInt,
        expectedAccountKey: String?
    ) -> Bool {
        GrokHTTPRefreshAuthPolicy.shouldCommit(
            captured: authGeneration,
            current: grokHTTPAuthGeneration.value
        ) && canCommit(
            provider: .grok,
            epoch: epoch,
            capturedGeneration: 0,
            expectedAccountKey: expectedAccountKey
        )
    }

    private func applyClaude(_ usage: ClaudeUsage, observedAt: Date) {
        claude = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent,
            weeklyAvailable: true,
            resetText: usage.resetText,
            weeklyResetText: usage.weeklyResetText,
            isLoaded: true,
            errorMessage: nil,
            isStale: false,
            observedAt: observedAt
        )
        clearStatusMessage(for: "Claude")
    }

    private func applyChatGPT(_ usage: ChatGPTUsage, observedAt: Date) {
        chatGPT = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent ?? 0,
            weeklyAvailable: usage.weeklyRemainingPercent != nil,
            resetText: usage.resetText,
            weeklyResetText: usage.weeklyResetText ?? "",
            isLoaded: true,
            errorMessage: nil,
            isStale: false,
            observedAt: observedAt
        )
        clearStatusMessage(for: "ChatGPT")
    }

    private func applyGrok(_ usage: GrokUsage, observedAt: Date) {
        grok = UsageInfo(
            sessionPercent: usage.sessionRemainingPercent,
            weeklyPercent: usage.weeklyRemainingPercent ?? 0,
            weeklyAvailable: usage.weeklyRemainingPercent != nil,
            resetText: usage.weeklyRemainingPercent != nil
                ? (usage.weeklyRelativeResetText ?? "")
                : usage.resetText,
            weeklyResetText: usage.weeklyResetText ?? "",
            sessionWindowSeconds: usage.sessionWindowSeconds,
            isLoaded: true,
            errorMessage: nil,
            isStale: false,
            observedAt: observedAt
        )
        clearStatusMessage(for: "Grok")
    }

    private func applyGrokFailure(
        _ error: Error,
        authGeneration: UInt,
        epoch: UInt,
        expectedAccountKey: String?
    ) {
        guard canCommitGrok(
            epoch: epoch,
            authGeneration: authGeneration,
            expectedAccountKey: expectedAccountKey
        ) else {
            return
        }
        applyFailureState(&grok, providerName: "Grok", error: error)
    }

    @discardableResult
    private func commitV2Snapshot(_ snapshot: UsageSnapshot, now: Date = Date()) -> Bool {
        guard v2.commit(snapshot, now: now) else {
            return false
        }

        if snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey) == .fresh {
            resetRefreshRequests = Set(resetRefreshRequests.filter {
                $0.provider != snapshot.provider || $0.accountKey != snapshot.accountKey
            })
            lastGoodStore.save(snapshot)
        }
        scheduleNextResetRefresh(now: now)
        return true
    }

    private func resetRefreshIdentity(for snapshot: UsageSnapshot) -> UsageCacheIdentity? {
        guard let meter = snapshot.displayedPrimaryMeter else {
            return nil
        }

        return UsageCacheIdentity(
            provider: snapshot.provider,
            accountKey: snapshot.accountKey,
            meterId: meter.meterId,
            window: meter.window,
            durationSeconds: meter.windowDurationSeconds
        )
    }

    private func scheduleNextResetRefresh(now: Date = Date()) {
        resetRefreshTimer?.invalidate()
        resetRefreshTimer = nil

        guard let nextReset = v2.lastSnapshots.values
            .compactMap({ $0.displayedPrimaryMeter?.resetAt })
            .filter({ $0 > now })
            .min() else {
            return
        }

        let interval = max(0.1, nextReset.timeIntervalSince(now))
        resetRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resetRefreshTimer = nil
                self.expireInvalidUsage()
            }
        }
    }

    func v2Snapshot(for provider: UsageProviderID) -> UsageSnapshot? {
        v2.lastSnapshots[provider]
    }

    func v2PathInvocationCount() -> Int {
        v2.pathInvocations
    }

    func v2FetchInvocationCount(for provider: UsageProviderID) -> Int {
        v2.fetchInvocations[provider] ?? 0
    }

    func v2GrokRecoveryState() -> RecoveryState {
        v2.grokRecovery.state
    }

    func v2GrokRecoveryHasActiveScope() -> Bool {
        v2.grokRecovery.hasActiveScope
    }

    func v2GrokRestoresUsed() -> Int {
        v2.grokRecovery.restoresUsed
    }

    func v2GrokRetriesUsed() -> Int {
        v2.grokRecovery.retriesUsed
    }

    func v2LastNotifiedMeterId(for provider: UsageProviderID) -> String? {
        usageNotificationManager.lastNotifiedMeterID(for: provider)
    }

    func v2PrimaryMeterValidity(for provider: UsageProviderID, now: Date) -> UsageValidity? {
        guard let snapshot = v2.lastSnapshots[provider] else {
            return nil
        }
        return snapshot.validity(now: now, expectedAccountKey: snapshot.accountKey)
    }

    func v2RestoredFromPersistence(_ provider: UsageProviderID) -> Bool {
        v2.restoredFromPersistence.contains(provider)
    }

    func backoffUntil(provider: UsageProviderID, accountKey: String, now: Date? = nil) -> Date? {
        backoffStore.backoffUntil(provider: provider, accountKey: accountKey, now: now ?? self.now())
    }

    func expireInvalidUsage(now: Date = Date()) {
        var shouldRefresh = false
        for snapshot in v2.lastSnapshots.values {
            guard snapshot.validity(
                now: now,
                expectedAccountKey: snapshot.accountKey
            ) == .expired,
            let identity = resetRefreshIdentity(for: snapshot),
            resetRefreshRequests.insert(identity).inserted else {
                continue
            }
            shouldRefresh = true
        }

        if shouldRefresh {
            requestRefreshAll()
        }
    }

    private func clearStatusMessage(for provider: String) {
        guard UsageRefreshStatePolicy.shouldClearStatusMessage(
            statusMessage,
            for: provider
        ) else {
            return
        }

        statusMessage = ""
    }
}
