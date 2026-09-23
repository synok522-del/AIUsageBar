import Combine
import Foundation
import Sparkle

enum AppUpdaterStatus: Equatable {
    case notConfigured
    case ready
    case checking
    case updateAvailable(String)
    case noEligibleUpdate
    case downloading
    case downloaded
    case extracting
    case installing
    case relaunching
    case cancelled
    case failed

    var localizedDescription: String {
        switch self {
        case .notConfigured:
            L10n.updaterNotConfigured
        case .ready:
            L10n.updaterReady
        case .checking:
            L10n.updaterChecking
        case .updateAvailable(let version):
            L10n.updaterAvailable(version)
        case .noEligibleUpdate:
            L10n.updaterNoEligibleUpdate
        case .downloading:
            L10n.updaterDownloading
        case .downloaded:
            L10n.updaterDownloaded
        case .extracting:
            L10n.updaterExtracting
        case .installing:
            L10n.updaterInstalling
        case .relaunching:
            L10n.updaterRelaunching
        case .cancelled:
            L10n.updaterCancelled
        case .failed:
            L10n.updaterFailed
        }
    }
}

/// Sparkle 2.10.0 `SUSparkleErrorDomain` codes (see `SUErrors.h` at revision
/// eef1a539a373c1f1a320624b1130fc5de7b2e100). Literal values keep the mapping
/// independent of how the Objective-C enum is imported into Swift.
enum SparkleErrorCode {
    static let domain = "SUSparkleErrorDomain"
    static let noUpdate = 1001
    static let installationCanceled = 4007
    static let installationAuthorizeLater = 4008
}

/// The updater callbacks that change user-visible status.
enum AppUpdaterEvent {
    case checkStarted
    case foundValidUpdate(String)
    case didNotFindUpdate
    case aborted(Error)
    case finishedCycle(Error?)
    case willDownload
    case didDownload
    case failedDownload(Error)
    case userCancelledDownload
    case willExtract
    case willInstall
    case willRelaunch
}

/// Pure status mapping for Sparkle delegate callbacks. Each error-carrying
/// callback is classified on its own, so the result does not depend on the
/// order in which Sparkle reports the same outcome.
enum AppUpdaterStatusReducer {
    enum ErrorOutcome: Equatable {
        case noUpdate
        case cancelled
        case failure
    }

    static func classify(_ error: Error) -> ErrorOutcome {
        let error = error as NSError
        if error.domain == SparkleErrorCode.domain {
            switch error.code {
            case SparkleErrorCode.noUpdate:
                return .noUpdate
            case SparkleErrorCode.installationCanceled, SparkleErrorCode.installationAuthorizeLater:
                return .cancelled
            default:
                return .failure
            }
        }
        if (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) {
            return .cancelled
        }
        return .failure
    }

    static func reduce(_ status: AppUpdaterStatus, _ event: AppUpdaterEvent) -> AppUpdaterStatus {
        switch event {
        case .checkStarted:
            return .checking
        case .foundValidUpdate(let version):
            return .updateAvailable(version)
        case .didNotFindUpdate:
            return .noEligibleUpdate
        case .aborted(let error), .failedDownload(let error):
            return outcomeStatus(for: error)
        case .finishedCycle(let error?):
            return outcomeStatus(for: error)
        case .finishedCycle(nil):
            // A nil error also means an offered update was dismissed or skipped.
            // Neither an unfinished check nor a dismissed offer stays authoritative.
            switch status {
            case .checking, .updateAvailable:
                return .ready
            default:
                return status
            }
        case .willDownload:
            return .downloading
        case .didDownload:
            return .downloaded
        case .userCancelledDownload:
            return .cancelled
        case .willExtract:
            return .extracting
        case .willInstall:
            return .installing
        case .willRelaunch:
            return .relaunching
        }
    }

    private static func outcomeStatus(for error: Error) -> AppUpdaterStatus {
        switch classify(error) {
        case .noUpdate:
            .noEligibleUpdate
        case .cancelled:
            .cancelled
        case .failure:
            .failed
        }
    }
}

/// App-lifetime adapter around Sparkle's stock controller and user interface.
/// It does not own a downloader, installer, retry scheduler, or session storage.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var status: AppUpdaterStatus
    @Published private(set) var automaticallyChecksForUpdates = false

    private let configuration: UpdaterConfiguration
    private var availabilityObservation: AnyCancellable?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    var isConfigured: Bool { configuration.isReady }

    var statusDescription: String { status.localizedDescription }

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        configuration = UpdaterConfiguration(infoDictionary: infoDictionary)
        status = configuration.isReady ? .ready : .notConfigured
        super.init()

        guard configuration.isReady else { return }

        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
        availabilityObservation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard isConfigured else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        guard isConfigured, controller.updater.canCheckForUpdates else { return }
        apply(.checkStarted)
        controller.checkForUpdates(nil)
    }

    private func apply(_ event: AppUpdaterEvent) {
        status = AppUpdaterStatusReducer.reduce(status, event)
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        apply(.foundValidUpdate(item.displayVersionString))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        // Sparkle may report that no eligible update exists for several reasons;
        // do not call this "latest" or infer that the feed is universally current.
        apply(.didNotFindUpdate)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        apply(.didNotFindUpdate)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        apply(.aborted(error))
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        apply(.finishedCycle(error))
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        apply(.willDownload)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        apply(.didDownload)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        apply(.failedDownload(error))
    }

    func userDidCancelDownload(_ updater: SPUUpdater) {
        apply(.userCancelledDownload)
    }

    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        apply(.willExtract)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        apply(.willInstall)
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        apply(.willRelaunch)
    }
}
