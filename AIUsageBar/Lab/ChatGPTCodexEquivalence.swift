import Foundation

enum LabWindowClass: String, Equatable, Sendable {
    case short
    case weekly
    case unspecified
}

enum LabUsageProvider: String, Equatable, Sendable {
    case chatGPT
    case codex
}

/// In-memory meter observation for lab comparison only.
struct LabUsageMeterObservation: Equatable, Sendable {
    var provider: LabUsageProvider
    var accountKey: String
    var windowClass: LabWindowClass
    var remainingPercent: Int?
    var resetAt: Date?
    var meterPresent: Bool
    var meterId: String
}

struct ChatGPTCodexEquivalenceSample: Equatable, Sendable {
    var web: [LabUsageMeterObservation]
    var codex: [LabUsageMeterObservation]
}

enum ChatGPTCodexEquivalenceVerdict: String, Equatable, Sendable {
    case provenEquivalent = "PROVEN_EQUIVALENT"
    case provenDifferent = "PROVEN_DIFFERENT"
    case notProven = "NOT_PROVEN"
}

/// Pure ChatGPT web vs Codex rateLimits comparison.
/// No Keychain, WebKit, FileManager, or network.
enum ChatGPTCodexEquivalence {
    static let remainingTolerancePercent = 1
    static let resetTolerance: TimeInterval = 120
    static let liveEvidenceDocumentName = "S01C-live-capture.json"

    static func windowClass(forMeterId meterId: String) -> LabWindowClass {
        switch meterId {
        case "chatgpt.primary_window", CodexRateLimitsParser.primaryMeterID:
            return .short
        case "chatgpt.secondary_window", CodexRateLimitsParser.secondaryMeterID:
            return .weekly
        default:
            return .unspecified
        }
    }

    /// Maps V1 ChatGPT remaining fields to lab observations. Does not call `ChatGPTService`.
    static func webObservations(
        accountKey: String,
        sessionRemainingPercent: Int,
        sessionResetAt: Date?,
        weeklyRemainingPercent: Int?,
        weeklyResetAt: Date?
    ) -> [LabUsageMeterObservation] {
        var meters = [
            LabUsageMeterObservation(
                provider: .chatGPT,
                accountKey: accountKey,
                windowClass: .short,
                remainingPercent: sessionRemainingPercent,
                resetAt: sessionResetAt,
                meterPresent: true,
                meterId: "chatgpt.primary_window"
            )
        ]
        if let weeklyRemainingPercent {
            meters.append(
                LabUsageMeterObservation(
                    provider: .chatGPT,
                    accountKey: accountKey,
                    windowClass: .weekly,
                    remainingPercent: weeklyRemainingPercent,
                    resetAt: weeklyResetAt,
                    meterPresent: true,
                    meterId: "chatgpt.secondary_window"
                )
            )
        }
        return meters
    }

    static func codexObservations(
        accountKey: String,
        document: CodexRateLimitsDocument
    ) -> [LabUsageMeterObservation] {
        document.meters.map { meter in
            LabUsageMeterObservation(
                provider: .codex,
                accountKey: accountKey,
                windowClass: windowClass(forMeterId: meter.meterId),
                remainingPercent: meter.remainingPercent,
                resetAt: meter.resetAt,
                meterPresent: true,
                meterId: meter.meterId
            )
        }
    }

    static func windowsOverlap(_ left: LabWindowClass, _ right: LabWindowClass) -> Bool {
        left != .unspecified && left == right
    }

    /// Candidate predicate only. Similar remaining percent is not sufficient.
    static func isCandidateEquivalent(
        _ web: LabUsageMeterObservation,
        _ codex: LabUsageMeterObservation
    ) -> Bool {
        guard web.meterPresent, codex.meterPresent else {
            return false
        }
        guard !web.accountKey.isEmpty, web.accountKey == codex.accountKey else {
            return false
        }
        guard windowsOverlap(web.windowClass, codex.windowClass) else {
            return false
        }
        guard let webRemaining = web.remainingPercent,
              let codexRemaining = codex.remainingPercent,
              abs(webRemaining - codexRemaining) <= remainingTolerancePercent else {
            return false
        }
        guard let webReset = web.resetAt, let codexReset = codex.resetAt else {
            return false
        }
        return abs(webReset.timeIntervalSince(codexReset)) <= resetTolerance
    }

    static func isCandidateSnapshotEquivalent(
        web: [LabUsageMeterObservation],
        codex: [LabUsageMeterObservation]
    ) -> Bool {
        let webPresent = web.filter(\.meterPresent)
        let codexPresent = codex.filter(\.meterPresent)
        let webWindows = Set(webPresent.map(\.windowClass))
        let codexWindows = Set(codexPresent.map(\.windowClass))
        guard webWindows == codexWindows else {
            return false
        }
        for window in webWindows {
            guard let webMeter = webPresent.first(where: { $0.windowClass == window }),
                  let codexMeter = codexPresent.first(where: { $0.windowClass == window }),
                  isCandidateEquivalent(webMeter, codexMeter) else {
                return false
            }
        }
        return !webWindows.isEmpty
    }

    /// Lab verdict. Absent live evidence never becomes `PROVEN_EQUIVALENT`.
    /// One sample is never auto-equivalent. Conflicting samples can be `PROVEN_DIFFERENT`.
    static func verdict(
        samples: [ChatGPTCodexEquivalenceSample],
        liveEvidencePresent: Bool
    ) -> ChatGPTCodexEquivalenceVerdict {
        if samples.count >= 2 {
            let flags = samples.map {
                isCandidateSnapshotEquivalent(web: $0.web, codex: $0.codex)
            }
            if flags.contains(false) {
                return .provenDifferent
            }
            if flags.allSatisfy({ $0 }) {
                return liveEvidencePresent ? .provenEquivalent : .notProven
            }
        }
        return .notProven
    }
}
