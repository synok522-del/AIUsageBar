import Foundation

enum V2UsageSourceID: String, Equatable, Sendable {
    case chatGPTWeb
    case claudeWeb
    case grokWeb
    case codexChallenger
    case claudeSnapshotBridge
    case cursorHold
    case geminiApps
    case geminiCLI
}

enum V2UsageSourceResult: Equatable {
    case snapshot(V2UsageSnapshot)
    case authFailure
    case forbidden
    case invalid
}

struct V2FetchEnvelope: Equatable {
    var httpStatus: Int
    var accountKey: String
    var fetchedAt: Date
    var payload: [String: Any]

    static func == (lhs: V2FetchEnvelope, rhs: V2FetchEnvelope) -> Bool {
        lhs.httpStatus == rhs.httpStatus
            && lhs.accountKey == rhs.accountKey
            && lhs.fetchedAt == rhs.fetchedAt
            && NSDictionary(dictionary: lhs.payload).isEqual(to: rhs.payload)
    }
}

protocol V2UsageSource {
    var sourceID: V2UsageSourceID { get }
    var isEnabled: Bool { get }
    var isSelectableForUI: Bool { get }
    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult
}

enum V2UsageSourceHTTP {
    static func classify(_ status: Int) -> V2UsageSourceResult? {
        if status == 401 {
            return .authFailure
        }
        if status == 403 {
            return .forbidden
        }
        if !(200..<300).contains(status) {
            return .invalid
        }
        return nil
    }
}

struct V2ChatGPTWebUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .chatGPTWeb }
    var isEnabled: Bool { true }
    var isSelectableForUI: Bool { true }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = previous
        if let classified = V2UsageSourceHTTP.classify(envelope.httpStatus) {
            return classified
        }
        guard !envelope.accountKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid
        }
        guard !envelope.payload.isEmpty else {
            return .invalid
        }
        do {
            let parsed = try ChatGPTService.parseUsage(envelope.payload)
            var meters: [V2UsageMeter] = []
            if let short = V2UsageMeter(
                meterId: "chatgpt.primary_window",
                window: V2Window(classification: .short, duration: 5 * 60 * 60),
                remainingPercent: parsed.sessionRemainingPercent,
                isPrimaryDisplayed: true
            ) {
                meters.append(short)
            }
            if let weeklyRemaining = parsed.weeklyRemainingPercent,
               let weekly = V2UsageMeter(
                   meterId: "chatgpt.secondary_window",
                   window: V2Window(
                       classification: .weekly,
                       duration: V2ArchitectureConstants.weeklyWindowDuration
                   ),
                   remainingPercent: weeklyRemaining,
                   isPrimaryDisplayed: false
               ) {
                meters.append(weekly)
            }
            guard let snapshot = V2UsageSnapshot(
                provider: .chatGPT,
                accountKey: envelope.accountKey,
                meters: meters,
                fetchedAt: envelope.fetchedAt
            ) else {
                return .invalid
            }
            return .snapshot(snapshot)
        } catch {
            return .invalid
        }
    }
}

struct V2ClaudeWebUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .claudeWeb }
    var isEnabled: Bool { true }
    var isSelectableForUI: Bool { true }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = previous
        if let classified = V2UsageSourceHTTP.classify(envelope.httpStatus) {
            return classified
        }
        guard !envelope.accountKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid
        }
        let usage = envelope.payload.reduce(into: [String: [String: Any]]()) { result, item in
            if let dictionary = item.value as? [String: Any] {
                result[item.key] = dictionary
            }
        }
        do {
            let parsed = try ClaudeService.parseUsage(usage)
            let meters = [
                V2UsageMeter(
                    meterId: "claude.five_hour",
                    window: V2Window(classification: .short, duration: 5 * 60 * 60),
                    remainingPercent: parsed.sessionRemainingPercent,
                    isPrimaryDisplayed: true
                ),
                V2UsageMeter(
                    meterId: "claude.seven_day",
                    window: V2Window(
                        classification: .weekly,
                        duration: V2ArchitectureConstants.weeklyWindowDuration
                    ),
                    remainingPercent: parsed.weeklyRemainingPercent,
                    isPrimaryDisplayed: false
                )
            ].compactMap { $0 }
            guard let snapshot = V2UsageSnapshot(
                provider: .claude,
                accountKey: envelope.accountKey,
                meters: meters,
                fetchedAt: envelope.fetchedAt
            ) else {
                return .invalid
            }
            return .snapshot(snapshot)
        } catch {
            return .invalid
        }
    }
}

struct V2GrokWebUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .grokWeb }
    var isEnabled: Bool { true }
    var isSelectableForUI: Bool { true }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = previous
        if let classified = V2UsageSourceHTTP.classify(envelope.httpStatus) {
            return classified
        }
        guard !envelope.accountKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid
        }

        let rateLimits = (envelope.payload["rate_limits"] as? [String: Any])
            ?? envelope.payload
        let weeklyPayload = envelope.payload["weekly"] as? [String: Any]

        do {
            let short = try GrokService.parseRateLimits(rateLimits)
            let windowClass = V2WindowClassifier.classify(
                duration: TimeInterval(short.windowSeconds)
            )
            var meters: [V2UsageMeter] = []
            if let shortMeter = V2UsageMeter(
                meterId: "grok.short",
                window: V2Window(
                    classification: windowClass,
                    duration: TimeInterval(short.windowSeconds)
                ),
                remainingPercent: short.remainingPercent,
                isPrimaryDisplayed: weeklyPayload == nil
            ) {
                meters.append(shortMeter)
            }

            if let weeklyPayload,
               let weeklyMeter = weeklyMeter(from: weeklyPayload) {
                meters.append(weeklyMeter)
                if let index = meters.firstIndex(where: { $0.meterId == "grok.short" }) {
                    meters[index].isPrimaryDisplayed = false
                }
                if let weeklyIndex = meters.firstIndex(where: { $0.meterId == "grok.weekly" }) {
                    meters[weeklyIndex].isPrimaryDisplayed = true
                }
            }

            guard meters.allSatisfy({ !$0.meterId.isEmpty }) else {
                return .invalid
            }
            guard let snapshot = V2UsageSnapshot(
                provider: .grok,
                accountKey: envelope.accountKey,
                meters: meters,
                fetchedAt: envelope.fetchedAt
            ) else {
                return .invalid
            }
            return .snapshot(snapshot)
        } catch {
            return .invalid
        }
    }

    /// Weekly reset is `current_period.end` when type is WEEKLY.
    /// `billing_period_end` is ignored.
    private func weeklyMeter(from payload: [String: Any]) -> V2UsageMeter? {
        let usedRaw = (payload["used_percent"] as? NSNumber)?.doubleValue
            ?? (payload["usedPercent"] as? NSNumber)?.doubleValue
        let periodType = (payload["period_type"] as? NSNumber)?.intValue
            ?? (payload["periodType"] as? NSNumber)?.intValue
        let periodEnd = isoDate(
            payload["current_period_end"] ?? payload["currentPeriodEnd"]
        )
        _ = payload["billing_period_end"]
        _ = payload["billingPeriodEnd"]

        guard let quota = try? GrokCreditsConfigDecoder.validatedWeekly(
            usedRaw: usedRaw,
            periodType: periodType,
            periodEnd: periodEnd,
            now: periodEnd ?? Date(timeIntervalSince1970: 1_780_000_000)
        ) else {
            return nil
        }

        return V2UsageMeter(
            meterId: "grok.weekly",
            window: V2Window(
                classification: .weekly,
                duration: V2ArchitectureConstants.weeklyWindowDuration
            ),
            remainingPercent: quota.remainingPercent,
            resetAt: quota.resetAt,
            isPrimaryDisplayed: true
        )
    }

    private func isoDate(_ raw: Any?) -> Date? {
        if let date = raw as? Date {
            return date
        }
        if let number = raw as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        guard let string = raw as? String else {
            return nil
        }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: string) {
            return date
        }
        let fraction = ISO8601DateFormatter()
        fraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fraction.date(from: string)
    }
}

struct V2CodexChallengerUsageSource: V2UsageSource {
    var isEnabled: Bool = false
    var sourceID: V2UsageSourceID { .codexChallenger }
    var isSelectableForUI: Bool { false }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = previous
        guard isEnabled else {
            return .invalid
        }
        guard !envelope.accountKey.isEmpty else {
            return .invalid
        }
        do {
            let document = try CodexRateLimitsParser.parse(
                json: try JSONSerialization.data(withJSONObject: envelope.payload)
            )
            let meters = document.meters.compactMap { meter in
                V2UsageMeter(
                    meterId: meter.meterId,
                    window: V2Window(
                        classification: ChatGPTCodexEquivalence.windowClass(forMeterId: meter.meterId) == .weekly
                            ? .weekly
                            : .short,
                        duration: nil
                    ),
                    remainingPercent: meter.remainingPercent,
                    resetAt: meter.resetAt,
                    isPrimaryDisplayed: meter.meterId == CodexRateLimitsParser.primaryMeterID
                )
            }
            guard let snapshot = V2UsageSnapshot(
                provider: .codex,
                accountKey: envelope.accountKey,
                meters: meters,
                fetchedAt: envelope.fetchedAt
            ) else {
                return .invalid
            }
            return .snapshot(snapshot)
        } catch {
            return .invalid
        }
    }
}

struct V2ClaudeSnapshotBridgeUsageSource: V2UsageSource {
    var isEnabled: Bool = false
    var sourceID: V2UsageSourceID { .claudeSnapshotBridge }
    var isSelectableForUI: Bool { isEnabled }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = previous
        guard isEnabled else {
            return .invalid
        }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: envelope.payload)
        } catch {
            return .invalid
        }
        switch ClaudeStatuslineParser.parse(json: data) {
        case .success(let document):
            let meters = document.meters.compactMap { meter in
                V2UsageMeter(
                    meterId: meter.meterId,
                    window: V2Window(
                        classification: meter.meterId == ClaudeStatuslineParser.fiveHourMeterID
                            ? .short
                            : .weekly,
                        duration: nil
                    ),
                    remainingPercent: meter.remainingPercent,
                    resetAt: meter.resetAt,
                    isPrimaryDisplayed: meter.meterId == ClaudeStatuslineParser.fiveHourMeterID
                )
            }
            guard let snapshot = V2UsageSnapshot(
                provider: .claude,
                accountKey: envelope.accountKey,
                meters: meters,
                fetchedAt: envelope.fetchedAt
            ) else {
                return .invalid
            }
            return .snapshot(snapshot)
        case .noMeterInSnapshot, .parseFailure:
            return .invalid
        }
    }
}

struct V2CursorHoldUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .cursorHold }
    var isEnabled: Bool { false }
    var isSelectableForUI: Bool { false }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = envelope
        _ = previous
        return .invalid
    }
}

struct V2GeminiAppsUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .geminiApps }
    var isEnabled: Bool { false }
    var isSelectableForUI: Bool { false }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = envelope
        _ = previous
        return .invalid
    }
}

struct V2GeminiCLIUsageSource: V2UsageSource {
    var sourceID: V2UsageSourceID { .geminiCLI }
    var isEnabled: Bool { false }
    var isSelectableForUI: Bool { false }

    func load(envelope: V2FetchEnvelope, previous: V2UsageSnapshot?) -> V2UsageSourceResult {
        _ = envelope
        _ = previous
        return .invalid
    }
}

enum V2UsageSourceCatalog {
    static func uiSelectableSourceIDs() -> [V2UsageSourceID] {
        [V2ChatGPTWebUsageSource(), V2ClaudeWebUsageSource(), V2GrokWebUsageSource()]
            .filter(\.isSelectableForUI)
            .map(\.sourceID)
    }

    static func productionTestFileURL(from testFilePath: String) -> URL {
        URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBarTests.swift")
    }

    static func productionTestCount(in source: String) -> Int {
        source.components(separatedBy: "@Test").count - 1
    }
}
