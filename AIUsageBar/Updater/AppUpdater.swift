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
        status = .checking
        controller.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        status = .updateAvailable(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        // Sparkle may report that no eligible update exists for several reasons;
        // do not call this "latest" or infer that the feed is universally current.
        status = .noEligibleUpdate
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        status = .noEligibleUpdate
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        status = Self.isCancellation(error) ? .cancelled : .failed
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        if let error {
            status = Self.isCancellation(error) ? .cancelled : .failed
        } else if status == .checking {
            // A nil error can also mean the user dismissed an update. Keep this
            // neutral and never turn it into a "latest" claim.
            status = .ready
        }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        status = .downloading
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        status = .downloaded
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        status = Self.isCancellation(error) ? .cancelled : .failed
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

    private static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError)
    }
}
