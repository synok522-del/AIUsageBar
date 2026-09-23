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

/// Maps Sparkle 2.10.0's documented delegate outcomes to user-visible state.
/// Sparkle 2.10.0's public Swift module exports the error domain but not the
/// `SUError` enum cases, so these values match `Sparkle/SUErrors.h` at the
/// pinned revision eef1a539a373c1f1a320624b1130fc5de7b2e100:
/// SUNoUpdateError = 1001, SUInstallationCanceledError = 4007.
enum AppUpdaterStatusTransitions {
    private static let noUpdateErrorCode = 1001
    private static let installationCanceledErrorCode = 4007

    static func checkStarted() -> AppUpdaterStatus { .checking }

    static func didNotFindUpdate(error: Error?) -> AppUpdaterStatus {
        guard let error else { return .noEligibleUpdate }
        return state(for: error)
    }

    static func didAbortWithError(_ error: Error) -> AppUpdaterStatus {
        state(for: error)
    }

    static func didFinishUpdateCycle(
        current: AppUpdaterStatus,
        error: Error?
    ) -> AppUpdaterStatus {
        guard let error else {
            switch current {
            case .checking, .updateAvailable:
                // A completed cycle with no error can mean the user dismissed
                // or skipped the offered update. Do not leave stale availability.
                return .ready
            default:
                return current
            }
        }
        return state(for: error)
    }

    static func failedToDownloadUpdate(_ error: Error) -> AppUpdaterStatus {
        state(for: error)
    }

    private static func state(for error: Error) -> AppUpdaterStatus {
        let error = error as NSError
        if error.domain == SUSparkleErrorDomain {
            switch error.code {
            case noUpdateErrorCode:
                return .noEligibleUpdate
            case installationCanceledErrorCode:
                return .cancelled
            default:
                return .failed
            }
        }
        if (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) {
            return .cancelled
        }
        return .failed
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
        status = AppUpdaterStatusTransitions.checkStarted()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        status = .updateAvailable(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        status = AppUpdaterStatusTransitions.didNotFindUpdate(error: error)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        status = AppUpdaterStatusTransitions.didNotFindUpdate(error: nil)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        status = AppUpdaterStatusTransitions.didAbortWithError(error)
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        status = AppUpdaterStatusTransitions.didFinishUpdateCycle(
            current: status,
            error: error
        )
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        status = .downloading
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        status = .downloaded
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        status = AppUpdaterStatusTransitions.failedToDownloadUpdate(error)
    }

    func userDidCancelDownload(_ updater: SPUUpdater) {
        status = .cancelled
    }

    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        status = .extracting
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        status = .installing
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        status = .relaunching
    }

}
