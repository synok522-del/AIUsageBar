import Foundation
import Testing
@testable import AIUsageBar

struct S01CChatGPTCodexEquivalenceTests {
    private let reset = Date(timeIntervalSince1970: 1_788_854_400)

    @Test("T-1C-01 Same accountKey + overlapping window + remaining within 1% + resetAt within 120s → candidate equivalent")
    func candidateEquivalentRequiresAllFourConditions() {
        let web = webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)
        let close = reset.addingTimeInterval(120)
        let codex = codexMeter(account: "acct-a", window: .short, remaining: 41, reset: close)
        #expect(ChatGPTCodexEquivalence.isCandidateEquivalent(web, codex))

        let similarPercentOnly = codexMeter(
            account: "acct-b",
            window: .weekly,
            remaining: 40,
            reset: reset.addingTimeInterval(10_000)
        )
        #expect(ChatGPTCodexEquivalence.isCandidateEquivalent(web, similarPercentOnly) == false)
    }

    @Test("T-1C-02 Same remaining, different accountKey → not equivalent")
    func differentAccountKeyIsNotEquivalent() {
        let web = webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)
        let codex = codexMeter(account: "acct-b", window: .short, remaining: 40, reset: reset)
        #expect(ChatGPTCodexEquivalence.isCandidateEquivalent(web, codex) == false)
    }

    @Test("T-1C-03 Same remaining, window class differs (5h/short vs 7d/weekly) → not equivalent")
    func differentWindowClassIsNotEquivalent() {
        let web = webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)
        let codex = codexMeter(account: "acct-a", window: .weekly, remaining: 40, reset: reset)
        #expect(ChatGPTCodexEquivalence.isCandidateEquivalent(web, codex) == false)
        #expect(ChatGPTCodexEquivalence.windowsOverlap(.short, .weekly) == false)
    }

    @Test("T-1C-04 resetAt differs by more than 120s → not equivalent")
    func resetOutsideToleranceIsNotEquivalent() {
        let web = webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)
        let codex = codexMeter(
            account: "acct-a",
            window: .short,
            remaining: 40,
            reset: reset.addingTimeInterval(121)
        )
        #expect(ChatGPTCodexEquivalence.isCandidateEquivalent(web, codex) == false)
    }

    @Test("T-1C-05 One source missing a meter the other has → not equivalent")
    func missingMeterIsNotEquivalent() {
        let web = [
            webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset),
            webMeter(
                account: "acct-a",
                window: .weekly,
                remaining: 80,
                reset: reset,
                meterId: "chatgpt.secondary_window"
            )
        ]
        let codex = [
            codexMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)
        ]
        #expect(
            ChatGPTCodexEquivalence.isCandidateSnapshotEquivalent(web: web, codex: codex) == false
        )
    }

    @Test("T-1C-06 Only one sample → NOT_PROVEN, never auto-equivalent")
    func oneSampleIsNeverProvenEquivalent() {
        let sample = ChatGPTCodexEquivalenceSample(
            web: [webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)],
            codex: [codexMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)]
        )
        #expect(
            ChatGPTCodexEquivalence.isCandidateEquivalent(sample.web[0], sample.codex[0])
        )
        #expect(
            ChatGPTCodexEquivalence.verdict(samples: [sample], liveEvidencePresent: true)
                == .notProven
        )
        #expect(
            ChatGPTCodexEquivalence.verdict(samples: [sample], liveEvidencePresent: false)
                == .notProven
        )
    }

    @Test("T-1C-07 Conflicting samples → PROVEN_DIFFERENT")
    func conflictingSamplesAreProvenDifferent() {
        let matching = ChatGPTCodexEquivalenceSample(
            web: [webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)],
            codex: [codexMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)]
        )
        let conflicting = ChatGPTCodexEquivalenceSample(
            web: [webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)],
            codex: [codexMeter(account: "acct-a", window: .short, remaining: 10, reset: reset)]
        )
        #expect(
            ChatGPTCodexEquivalence.verdict(
                samples: [matching, conflicting],
                liveEvidencePresent: false
            ) == .provenDifferent
        )
    }

    @Test("T-1C-08 NOT_PROVEN default when live evidence file is absent")
    func absentLiveEvidenceIsNotProven() {
        #expect(
            ChatGPTCodexEquivalence.verdict(samples: [], liveEvidencePresent: false)
                == .notProven
        )
        let matching = ChatGPTCodexEquivalenceSample(
            web: [webMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)],
            codex: [codexMeter(account: "acct-a", window: .short, remaining: 40, reset: reset)]
        )
        let matchingAgain = matching
        #expect(
            ChatGPTCodexEquivalence.verdict(
                samples: [matching, matchingAgain],
                liveEvidencePresent: false
            ) == .notProven
        )
        #expect(ChatGPTCodexEquivalence.liveEvidenceDocumentName == "S01C-live-capture.json")
    }

    @Test("V1 primary_window maps to short and secondary_window maps to weekly")
    func v1WindowMapping() {
        #expect(ChatGPTCodexEquivalence.windowClass(forMeterId: "chatgpt.primary_window") == .short)
        #expect(ChatGPTCodexEquivalence.windowClass(forMeterId: "chatgpt.secondary_window") == .weekly)
        #expect(
            ChatGPTCodexEquivalence.windowClass(forMeterId: CodexRateLimitsParser.primaryMeterID)
                == .short
        )
        #expect(
            ChatGPTCodexEquivalence.windowClass(forMeterId: CodexRateLimitsParser.secondaryMeterID)
                == .weekly
        )
        let mapped = ChatGPTCodexEquivalence.webObservations(
            accountKey: "acct-a",
            sessionRemainingPercent: 55,
            sessionResetAt: reset,
            weeklyRemainingPercent: 80,
            weeklyResetAt: reset
        )
        #expect(mapped.map(\.windowClass) == [.short, .weekly])
    }

    private func webMeter(
        account: String,
        window: LabWindowClass,
        remaining: Int,
        reset: Date,
        meterId: String = "chatgpt.primary_window"
    ) -> LabUsageMeterObservation {
        LabUsageMeterObservation(
            provider: .chatGPT,
            accountKey: account,
            windowClass: window,
            remainingPercent: remaining,
            resetAt: reset,
            meterPresent: true,
            meterId: meterId
        )
    }

    private func codexMeter(
        account: String,
        window: LabWindowClass,
        remaining: Int,
        reset: Date
    ) -> LabUsageMeterObservation {
        LabUsageMeterObservation(
            provider: .codex,
            accountKey: account,
            windowClass: window,
            remainingPercent: remaining,
            resetAt: reset,
            meterPresent: true,
            meterId: window == .weekly
                ? CodexRateLimitsParser.secondaryMeterID
                : CodexRateLimitsParser.primaryMeterID
        )
    }
}
