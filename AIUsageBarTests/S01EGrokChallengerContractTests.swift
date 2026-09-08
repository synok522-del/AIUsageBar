import Foundation
import Testing
@testable import AIUsageBar

struct S01EGrokChallengerContractTests {
    @Test("T-1E-01 Challenger fixture must expose a short-window remaining percent")
    func shortWindowRemainingIsRequired() {
        let accepted = GrokChallengerContract.parse(jsonString: Fixtures.superGrokWeekly)
        guard case .accepted(let document) = accepted else {
            Issue.record("expected accepted fixture, got \(accepted)")
            return
        }
        #expect(document.shortRemainingPercent == 40)

        let missingShort = GrokChallengerContract.parse(jsonString: Fixtures.missingShort)
        #expect(missingShort == .rejected)
    }

    @Test("T-1E-02 Challenger fixture must expose a weekly remaining percent or explicitly mark weekly absent")
    func weeklyRemainingOrExplicitAbsent() {
        let withWeekly = GrokChallengerContract.parse(jsonString: Fixtures.superGrokWeekly)
        guard case .accepted(let weekly) = withWeekly else {
            Issue.record("expected weekly fixture, got \(withWeekly)")
            return
        }
        #expect(weekly.weeklyRemainingPercent == 12)
        #expect(weekly.weeklyExplicitlyAbsent == false)

        let absent = GrokChallengerContract.parse(jsonString: Fixtures.weeklyExplicitlyAbsent)
        guard case .accepted(let free) = absent else {
            Issue.record("expected explicit weekly absent, got \(absent)")
            return
        }
        #expect(free.weeklyRemainingPercent == nil)
        #expect(free.weeklyExplicitlyAbsent)

        let silentMissing = GrokChallengerContract.parse(jsonString: Fixtures.weeklyOmitted)
        #expect(silentMissing == .rejected)
    }

    @Test("T-1E-03 Weekly reset must not be taken from a billing-period-end field")
    func weeklyResetMustNotUseBillingPeriodEnd() {
        let billed = GrokChallengerContract.parse(jsonString: Fixtures.weeklyFromBillingPeriodEnd)
        guard case .accepted(let parsed) = billed else {
            Issue.record("fixture should parse before evaluate, got \(billed)")
            return
        }
        #expect(parsed.weeklyResetFromBillingPeriodEnd)
        #expect(
            GrokChallengerContract.evaluate(fixture: billed, webEntitlement: .superGrok)
                == .rejected
        )

        let periodEnd = GrokChallengerContract.parse(jsonString: Fixtures.superGrokWeekly)
        guard case .accepted(let ok) = periodEnd else {
            Issue.record("expected current_period_end fixture, got \(periodEnd)")
            return
        }
        #expect(ok.weeklyResetFromBillingPeriodEnd == false)
        #expect(ok.weeklyResetAt != nil)
    }

    @Test("T-1E-04 SuperGrok entitlement mismatch → reject challenger")
    func superGrokEntitlementMismatchRejects() {
        let freeChallenger = GrokChallengerContract.parse(jsonString: Fixtures.weeklyExplicitlyAbsent)
        #expect(
            GrokChallengerContract.evaluate(fixture: freeChallenger, webEntitlement: .superGrok)
                == .rejected
        )
        let matching = GrokChallengerContract.parse(jsonString: Fixtures.superGrokWeekly)
        guard case .accepted = GrokChallengerContract.evaluate(
            fixture: matching,
            webEntitlement: .superGrok
        ) else {
            Issue.record("matching SuperGrok entitlement should be accepted")
            return
        }
    }

    @Test("T-1E-05 Missing local Grok source → keep web sources, no error-as-logout")
    func missingLocalKeepsWebAndIsNotLogout() {
        let missing = GrokChallengerContract.parse(jsonString: Fixtures.missingLocal)
        #expect(missing == .missingLocalSource)
        #expect(GrokChallengerContract.sourceSelection(localSourcePresent: false) == .webOnly)
        #expect(GrokChallengerContract.treatsMissingLocalAsLogout(missing) == false)
        #expect(GrokChallengerContract.webCreditsPathEnabled(after: missing))
    }

    @Test("T-1E-06 Challenger parse failure does not disable current GetGrokCreditsConfig path")
    func parseFailureDoesNotDisableWebCreditsPath() {
        let failure = GrokChallengerContract.parse(jsonString: "{")
        #expect(failure == .parseFailure)
        #expect(GrokChallengerContract.webCreditsPathEnabled(after: failure))
        #expect(
            GrokChallengerContract.webCreditsRequestPath
                == "/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig"
        )
        #expect(
            GrokChallengerContract.webCreditsRequestPath
                == GrokCreditsConfigDecoder.requestPath
        )
    }

    private enum Fixtures {
        static let superGrokWeekly = """
        {
          "entitlement": "super_grok",
          "short_window": { "remaining_percent": 40 },
          "weekly": {
            "remaining_percent": 12,
            "reset_at": "2026-09-15T12:00:00Z",
            "reset_source": "current_period_end"
          }
        }
        """

        static let missingShort = """
        {
          "entitlement": "super_grok",
          "weekly": { "remaining_percent": 12 }
        }
        """

        static let weeklyExplicitlyAbsent = """
        {
          "entitlement": "free",
          "short_window": { "remaining_percent": 88 },
          "weekly_absent": true
        }
        """

        static let weeklyOmitted = """
        {
          "entitlement": "super_grok",
          "short_window": { "remaining_percent": 40 }
        }
        """

        static let weeklyFromBillingPeriodEnd = """
        {
          "entitlement": "super_grok",
          "short_window": { "remaining_percent": 40 },
          "weekly": {
            "remaining_percent": 12,
            "billing_period_end": "2026-10-01T00:00:00Z",
            "reset_source": "billing_period_end"
          }
        }
        """

        static let missingLocal = """
        { "local_source_present": false }
        """
    }
}
