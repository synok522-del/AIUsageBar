import Foundation
import Testing
@testable import AIUsageBar

struct Maintain3Tests {
    @Test func chatGPTOptionalReasonsReachPanelAndDiskWithoutZero() throws {
        let cases: [(Any?, UsageUnavailableReason)] = [
            (nil, .absent), (NSNull(), .absent),
            (["used_percent": "25"], .malformed),
            (["used_percent": 101], .malformed),
            (["used_percent": true], .malformed),
            ("wrong window type", .malformed),
            ([:], .absent)
        ]
        for (secondary, reason) in cases {
            var limits: [String: Any] = ["primary_window": ["used_percent": 25]]
            limits["secondary_window"] = secondary
            let usage = try ChatGPTService.parseUsage(["rate_limit": limits])
            #expect(usage.weeklyRemainingPercent == nil)
            #expect(usage.weeklyUnavailableReason == reason)
            let snapshot = V1UsageAdapters.chatGPTSnapshot(usage: usage, token: "synthetic")
            let info = try #require(UsageInfoFromSnapshot.make(snapshot, stale: false))
            let row = OptionalMeterRowBinding(isSupported: true, info: info,
                unavailableText: reason.localizedDescription, resetText: nil)
            #expect(row.percent == nil)
            #expect(row.unavailableText == reason.localizedDescription)
            let record = try #require(LastGoodUsageStore.record(from: snapshot))
            let encoded = try JSONEncoder().encode(record)
            let restored = try JSONDecoder().decode(PersistedLastGoodRecord.self, from: encoded)
            #expect(restored.meters.last?.unavailableReason == reason)
            #expect(String(data: encoded, encoding: .utf8)?.contains("synthetic") == false)
        }
    }

    @Test func availableZeroRemainsZeroOnPanel() throws {
        let usage = try ChatGPTService.parseUsage(["rate_limit": [
            "primary_window": ["used_percent": 100],
            "secondary_window": ["used_percent": 100]
        ]])
        let info = try #require(UsageInfoFromSnapshot.make(
            V1UsageAdapters.chatGPTSnapshot(usage: usage, token: "synthetic"), stale: false))
        let row = OptionalMeterRowBinding(isSupported: true, info: info,
            unavailableText: L10n.windowDataUnavailable, resetText: nil)
        #expect(info.sessionPercent == 0)
        #expect(row.percent == 0)
        #expect(row.unavailableText == nil)
        #expect(info.weeklyUnavailableReason == nil)
    }

    @Test func requiredFieldReasonsAndFetchFailurePreserveFreshness() throws {
        for (value, reason) in [(NSNull() as Any, UsageUnavailableReason.absent),
                                ("0" as Any, .malformed), (-1 as Any, .malformed)] {
            do {
                _ = try ChatGPTService.parseUsage(["rate_limit": ["primary_window": ["used_percent": value]]])
                Issue.record("Invalid field accepted")
            } catch {
                #expect(UsageUnavailableReason.forError(error) == reason)
                let info = try #require(UsageRefreshStatePolicy.state(afterFailure: UsageInfo(), error: error))
                #expect(!info.isLoaded)
                #expect(info.unavailableReason == reason)
            }
        }
        do {
            _ = try ClaudeService.parseUsage(["five_hour": "wrong type"])
            Issue.record("Invalid Claude window accepted")
        } catch { #expect(UsageUnavailableReason.forError(error) == .malformed) }
        do {
            _ = try GrokService.parseRateLimits(["remainingQueries": 101, "totalQueries": 100])
            Issue.record("Out-of-range Grok value accepted")
        } catch { #expect(UsageUnavailableReason.forError(error) == .malformed) }
        let failure = try #require(UsageRefreshStatePolicy.state(afterFailure: UsageInfo(), error: URLError(.timedOut)))
        #expect(failure.unavailableReason == .fetchFailed)
        let previous = UsageInfo(sessionPercent: 42, isLoaded: true, observedAt: Date())
        let retained = try #require(UsageRefreshStatePolicy.state(afterFailure: previous, error: UsageReadError(reason: .absent)))
        #expect(retained.sessionPercent == 42)
        #expect(retained.observedAt == previous.observedAt)
        #expect(retained.unavailableReason == .absent)
    }

    @Test func grokWeeklyReasonsDistinguishMissingMalformedAndDecodeFailure() throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        for (used, reason) in [(nil as Double?, UsageUnavailableReason.absent), (150.0, .malformed)] {
            do {
                _ = try GrokCreditsConfigDecoder.validatedWeekly(usedRaw: used,
                    periodType: 2, periodEnd: now.addingTimeInterval(3600), now: now)
                Issue.record("Invalid weekly quota accepted")
            } catch { #expect(UsageUnavailableReason.forError(error) == reason) }
        }
        // Valid empty protobuf message: expected config is absent.
        let emptyMessage = GrokCreditsConfigDecoder.weeklyQuotaResult(httpStatus: 200,
            contentType: "application/grpc-web+proto", body: Data([0, 0, 0, 0, 0]))
        if case .failure(let error) = emptyMessage { #expect(error.reason == .absent) }
        else { Issue.record("Missing config accepted") }
        let truncated = GrokCreditsConfigDecoder.weeklyQuotaResult(httpStatus: 200,
            contentType: "application/grpc-web+proto", body: Data([0, 0]))
        if case .failure(let error) = truncated { #expect(error.reason == .fetchFailed) }
        else { Issue.record("Decode failure accepted") }
        let usage = GrokUsage(sessionRemainingPercent: 80, resetText: "", sessionWindowSeconds: 7200,
            weeklyRemainingPercent: nil, weeklyResetText: nil, weeklyRelativeResetText: nil,
            weeklyUnavailableReason: .absent)
        let info = try #require(UsageInfoFromSnapshot.make(
            V1UsageAdapters.grokSnapshot(usage: usage, sso: "synthetic"), stale: false))
        #expect(info.weeklyUnavailableReason == .absent)
        #expect(GrokCardPresentation.from(info).weeklyPercent == nil)
        #expect(GrokCardPresentation.from(info).showsWeeklyRow)
    }

    @Test @MainActor func claudeFetchUsesFirstOrganizationAndSanitizedName() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Maintain3ClaudeProtocol.self]
        let usage = try await ClaudeService(session: URLSession(configuration: configuration))
            .fetchUsage(sessionKey: "synthetic")
        #expect(usage.sessionRemainingPercent == 75)
        #expect(usage.organizationName == "First Team")
        #expect(usage.organizationID == "first")
        #expect(ClaudeOrganizationPresentation.diagnostic(organizationID: usage.organizationID,
            name: usage.organizationName) == L10n.claudeOrganizationNamed("First Team", "irst"))
    }

    @Test func claudeFirstWithoutIdentifierIsUnavailable() {
        #expect(throws: ClaudeOrganizationSelectionError.unavailable) {
            _ = try ClaudeService.selectOrganization(from: [["name": "Missing"], ["id": "later"]])
        }
    }
}

final class Maintain3ClaudeProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let body: String
        if url.path == "/api/organizations" {
            body = #"[{"id":"first","uuid":"different","name":" First\nTeam "},{"id":"second","name":"Second"}]"#
        } else if url.path == "/api/organizations/first/usage" {
            body = #"{"five_hour":{"utilization":25},"seven_day":{"utilization":50}}"#
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
