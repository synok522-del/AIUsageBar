import Foundation
import Testing
@testable import AIUsageBar

/// Replays the delegate-callback sequences Sparkle 2.10.0 delivers
/// (`SPUUpdater.m`: didAbortWithError is followed by didFinishUpdateCycleFor
/// with the same error, except for SUInstallationAuthorizeLaterError).
struct AppUpdaterStatusTests {
    private func sparkleError(_ code: Int) -> NSError {
        NSError(domain: SparkleErrorCode.domain, code: code)
    }

    private func replay(
        from start: AppUpdaterStatus = .ready,
        _ events: [AppUpdaterEvent]
    ) -> AppUpdaterStatus {
        events.reduce(start, AppUpdaterStatusReducer.reduce)
    }

    @Test("No update found stays a truthful no-update result, never failure")
    func noUpdateSequence() {
        let error = sparkleError(SparkleErrorCode.noUpdate)
        let result = replay([
            .checkStarted,
            .didNotFindUpdate,
            .aborted(error),
            .finishedCycle(error)
        ])
        #expect(result == .noEligibleUpdate)
    }

    @Test("No-update error is classified without relying on callback order")
    func noUpdateIndependentOfOrder() {
        let error = sparkleError(SparkleErrorCode.noUpdate)
        #expect(replay([.checkStarted, .finishedCycle(error)]) == .noEligibleUpdate)
        #expect(replay([.checkStarted, .aborted(error)]) == .noEligibleUpdate)
    }

    @Test("Installation cancelled by the user maps to cancelled")
    func installationCancelledSequence() {
        let error = sparkleError(SparkleErrorCode.installationCanceled)
        let result = replay([
            .checkStarted,
            .foundValidUpdate("0.0.4"),
            .willDownload,
            .didDownload,
            .willExtract,
            .aborted(error),
            .finishedCycle(error)
        ])
        #expect(result == .cancelled)
    }

    @Test("Authorize-later finishes the cycle as cancelled")
    func authorizeLaterSequence() {
        // Sparkle does not call didAbortWithError for this code.
        let error = sparkleError(SparkleErrorCode.installationAuthorizeLater)
        #expect(replay([.checkStarted, .foundValidUpdate("0.0.4"), .finishedCycle(error)]) == .cancelled)
    }

    @Test("Genuine network, feed and signature failures map to failed")
    func realFailureSequences() {
        let failures: [NSError] = [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            sparkleError(1000), // SUAppcastParseError, including feed-signature rejection
            sparkleError(2001), // SUDownloadError
            sparkleError(3001) // SUSignatureError
        ]
        for error in failures {
            #expect(replay([.checkStarted, .aborted(error), .finishedCycle(error)]) == .failed)
        }
    }

    @Test("A download failure is reported as failed")
    func downloadFailureSequence() {
        let error = sparkleError(2001)
        let result = replay([
            .checkStarted,
            .foundValidUpdate("0.0.4"),
            .willDownload,
            .failedDownload(error),
            .aborted(error),
            .finishedCycle(error)
        ])
        #expect(result == .failed)
    }

    @Test("A previous no-update result does not survive a failed check")
    func previousNoUpdateThenFailure() {
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let result = replay(from: .noEligibleUpdate, [.checkStarted, .aborted(offline), .finishedCycle(offline)])
        #expect(result == .failed)

        // Even without the checkStarted event (background checks), failure wins.
        #expect(replay(from: .noEligibleUpdate, [.aborted(offline), .finishedCycle(offline)]) == .failed)
    }

    @Test("A dismissed or skipped update offer does not stay as available")
    func dismissedUpdateOffer() {
        let result = replay([.checkStarted, .foundValidUpdate("0.0.4"), .finishedCycle(nil)])
        #expect(result == .ready)
    }

    @Test("A nil-error cycle end keeps download/install progress states")
    func nilCycleEndKeepsProgress() {
        #expect(replay(from: .downloaded, [.finishedCycle(nil)]) == .downloaded)
        #expect(replay(from: .installing, [.finishedCycle(nil)]) == .installing)
    }

    @Test("Successful install path reaches relaunching")
    func installPath() {
        let result = replay([
            .checkStarted,
            .foundValidUpdate("0.0.4"),
            .willDownload,
            .didDownload,
            .willExtract,
            .willInstall,
            .willRelaunch
        ])
        #expect(result == .relaunching)
    }

    @Test("Error classification uses the Sparkle domain, not the code alone")
    func classificationRequiresDomain() {
        let foreign = NSError(domain: "OtherDomain", code: SparkleErrorCode.noUpdate)
        #expect(AppUpdaterStatusReducer.classify(foreign) == .failure)
        #expect(AppUpdaterStatusReducer.classify(sparkleError(SparkleErrorCode.noUpdate)) == .noUpdate)
    }
}
