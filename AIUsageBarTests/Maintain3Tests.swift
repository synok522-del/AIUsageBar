import Foundation
import Testing
@testable import AIUsageBar

struct Maintain3Tests {
    @Test func chatGPTOptionalReasonsReachPanelAndDiskWithoutZero() throws {
        let cases: [(Any?, UsageUnavailableReason)] = [
            (nil, .absent), (NSNull(), .absent),
            (["used_percent": "25"], .malformed),
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
                                ("0" as Any, .malformed), (true as Any, .malformed)] {
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
        for (used, reason) in [(nil as Double?, UsageUnavailableReason.absent), (Double.infinity, .malformed), (Double.nan, .malformed)] {
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

    @Test func finiteUsageClampsAndKeepsProviderCardsAvailable() throws {
        for (used, remaining) in [(102.0, 0), (100.4, 0), (-3.0, 100),
                                  (Double.greatestFiniteMagnitude, 0),
                                  (-Double.greatestFiniteMagnitude, 100), (42.5, 57)] {
            let chatGPT = try ChatGPTService.parseUsage(["rate_limit": [
                "primary_window": ["used_percent": used],
                "secondary_window": ["used_percent": 105]
            ]])
            let chatInfo = try #require(UsageInfoFromSnapshot.make(
                V1UsageAdapters.chatGPTSnapshot(usage: chatGPT, token: "synthetic"), stale: false))
            #expect(chatInfo.isLoaded)
            #expect(chatInfo.sessionPercent == remaining)
            #expect(chatInfo.weeklyPercent == 0)
            #expect(chatInfo.unavailableReason == nil)
            #expect(chatInfo.weeklyUnavailableReason == nil)
            let row = OptionalMeterRowBinding(isSupported: true, info: chatInfo,
                unavailableText: L10n.windowDataUnavailable, resetText: nil)
            #expect(row.percent == 0)
            #expect(row.unavailableText == nil)

            let claude = try ClaudeService.parseUsage([
                "five_hour": ["utilization": used], "seven_day": ["utilization": 105]
            ])
            let claudeInfo = try #require(UsageInfoFromSnapshot.make(
                V1UsageAdapters.claudeSnapshot(usage: claude, sessionKey: "synthetic", organizationID: nil), stale: false))
            #expect(claudeInfo.isLoaded)
            #expect(claudeInfo.sessionPercent == remaining)
            #expect(claudeInfo.weeklyPercent == 0)
            #expect(claudeInfo.unavailableReason == nil)
            #expect(claudeInfo.weeklyUnavailableReason == nil)
        }
    }

    @Test func usageTypeChecksRemainStrict() throws {
        let invalid: [(Any?, UsageUnavailableReason)] = [
            (nil, .absent), (NSNull(), .absent), ("42", .malformed),
            (true, .malformed), (false, .malformed),
            (Double.infinity, .malformed), (-Double.infinity, .malformed),
            (Double.nan, .malformed), ([42], .malformed)
        ]
        for (value, reason) in invalid {
            do { _ = try ServiceSupport.usagePercent(value); Issue.record("Invalid percent accepted") }
            catch { #expect(UsageUnavailableReason.forError(error) == reason) }
            let primary: [String: Any] = value.map { ["used_percent": $0] } ?? [:]
            do {
                _ = try ChatGPTService.parseUsage(["rate_limit": ["primary_window": primary]])
                Issue.record("Invalid required usage accepted")
            } catch {
                #expect(UsageUnavailableReason.forError(error) == reason)
                let info = try #require(UsageRefreshStatePolicy.state(afterFailure: UsageInfo(), error: error))
                #expect(!info.isLoaded)
                #expect(info.unavailableReason == reason)
            }
        }
    }

    @Test func grokRatioMatchesBuild5Boundaries() throws {
        // Build 5 clamped the computed ratio but rejected nonpositive totals.
        for (remaining, total, expected) in [(101.0, 100.0, 100), (-3.0, 100.0, 0),
                                            (0.0, 100.0, 0), (1.0, 3.0, 33),
                                            (Double.greatestFiniteMagnitude, 1.0, 0)] {
            let session = try GrokService.parseRateLimits([
                "remainingQueries": remaining, "totalQueries": total
            ])
            #expect(session.remainingPercent == expected)
        }
        // An overflowing ratio was non-finite and Build 5's percent helper returned 0.
        for total in [0.0, -100.0] {
            for remaining in [-3.0, 0.0, 101.0] {
                do {
                    _ = try GrokService.parseRateLimits([
                        "remainingQueries": remaining, "totalQueries": total
                    ])
                    Issue.record("Nonpositive total accepted")
                } catch { #expect(UsageUnavailableReason.forError(error) == .malformed) }
            }
        }
        for invalid in ["42", true, Double.infinity, Double.nan] as [Any] {
            for field in ["remainingQueries", "totalQueries"] {
                var usage: [String: Any] = ["remainingQueries": 42, "totalQueries": 100]
                usage[field] = invalid
                do { _ = try GrokService.parseRateLimits(usage); Issue.record("Invalid ratio operand accepted") }
                catch { #expect(UsageUnavailableReason.forError(error) == .malformed) }
            }
        }
    }

    @Test func grokWeeklyFiniteExtremesClampWithoutOverflow() throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        for (used, remaining) in [(105.0, 0), (-3.0, 100), (100.4, 0),
                                  (Double.greatestFiniteMagnitude, 0),
                                  (-Double.greatestFiniteMagnitude, 100)] {
            let quota = try GrokCreditsConfigDecoder.validatedWeekly(usedRaw: used,
                periodType: 2, periodEnd: now.addingTimeInterval(3600), now: now)
            #expect(quota.remainingPercent == remaining)
            #expect(quota.usedPercent == 100 - remaining)
        }
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
