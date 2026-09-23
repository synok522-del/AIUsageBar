import Foundation
import Testing
@testable import AIUsageBar

struct UpdaterConfigurationTests {
    private var validInfo: [String: Any] {
        [
            "SUFeedURL": "https://example.com/appcast.xml",
            "SUPublicEDKey": Data(repeating: 0, count: 32).base64EncodedString(),
            "SUSignedFeedFailureExpirationInterval": 0,
            "SURequireSignedFeed": true,
            "SUVerifyUpdateBeforeExtraction": true,
            "SUEnableAutomaticChecks": true,
            "SUAutomaticallyUpdate": false,
            "SUAllowsAutomaticUpdates": false,
            "SUEnableJavaScript": false,
            "SUEnableSystemProfiling": false
        ]
    }

    @Test("A fully specified signed-feed policy enables the updater")
    func fullyConfiguredPolicyIsAccepted() {
        #expect(UpdaterConfiguration(infoDictionary: validInfo).isReady)
    }

    @Test("The expiration interval must be an explicit production decision")
    func missingExpirationIntervalDisablesUpdater() {
        var info = validInfo
        info.removeValue(forKey: "SUSignedFeedFailureExpirationInterval")

        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }

    @Test("HTTP feeds and malformed EdDSA public keys are rejected")
    func invalidTransportAndKeyAreRejected() {
        var info = validInfo
        info["SUFeedURL"] = "http://example.com/appcast.xml"
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)

        info = validInfo
        info["SUPublicEDKey"] = "placeholder"
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }

    @Test("Automatic installation and unsigned-feed fallback settings are rejected")
    func unsafeUpdaterSettingsAreRejected() {
        var info = validInfo
        info["SUAllowsAutomaticUpdates"] = true
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)

        info = validInfo
        info["SUVerifyUpdateBeforeExtraction"] = false
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }
}

struct AppUpdaterStatusTransitionTests {
    private func sparkleError(_ code: Int) -> NSError {
        NSError(domain: "SUSparkleErrorDomain", code: code)
    }

    @Test("No-update callback sequence stays no-update through cycle completion")
    func noUpdateSequenceRemainsNoUpdate() {
        var status = AppUpdaterStatus.checking
        let error = sparkleError(1001) // SUNoUpdateError in Sparkle 2.10.0.

        status = AppUpdaterStatusTransitions.didNotFindUpdate(error: nil)
        #expect(status == .noEligibleUpdate)
        status = AppUpdaterStatusTransitions.didAbortWithError(error)
        #expect(status == .noEligibleUpdate)
        status = AppUpdaterStatusTransitions.didFinishUpdateCycle(current: status, error: error)
        #expect(status == .noEligibleUpdate)
    }

    @Test("Installation-cancel callbacks stay cancelled")
    func installationCancelSequenceRemainsCancelled() {
        let error = sparkleError(4007) // SUInstallationCanceledError in Sparkle 2.10.0.
        var status = AppUpdaterStatusTransitions.didAbortWithError(error)
        #expect(status == .cancelled)
        status = AppUpdaterStatusTransitions.didFinishUpdateCycle(current: status, error: error)
        #expect(status == .cancelled)
        #expect(AppUpdaterStatusTransitions.failedToDownloadUpdate(error) == .cancelled)
    }

    @Test("Sparkle appcast and network failures remain failures")
    func realFailuresMapToFailure() {
        let appcastError = sparkleError(1002) // SUAppcastError in Sparkle 2.10.0.
        var status = AppUpdaterStatusTransitions.didNotFindUpdate(error: appcastError)
        #expect(status == .failed)
        status = AppUpdaterStatusTransitions.didAbortWithError(appcastError)
        #expect(status == .failed)
        status = AppUpdaterStatusTransitions.didFinishUpdateCycle(current: status, error: appcastError)
        #expect(status == .failed)
        #expect(AppUpdaterStatusTransitions.failedToDownloadUpdate(appcastError) == .failed)

        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        #expect(AppUpdaterStatusTransitions.didFinishUpdateCycle(current: .checking, error: networkError) == .failed)
    }

    @Test("A failure on the next check clears a previous no-update result")
    func previousNoUpdateDoesNotHideCheckFailure() {
        var status = AppUpdaterStatus.noEligibleUpdate
        status = AppUpdaterStatusTransitions.checkStarted()
        #expect(status == .checking)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        status = AppUpdaterStatusTransitions.didNotFindUpdate(error: error)
        status = AppUpdaterStatusTransitions.didAbortWithError(error)
        status = AppUpdaterStatusTransitions.didFinishUpdateCycle(current: status, error: error)
        #expect(status == .failed)
    }

    @Test("A dismissed or skipped update clears stale availability")
    func completedNilErrorClearsAvailableUpdate() {
        let status = AppUpdaterStatusTransitions.didFinishUpdateCycle(
            current: .updateAvailable("1.1.0"),
            error: nil
        )
        #expect(status == .ready)
    }
}
