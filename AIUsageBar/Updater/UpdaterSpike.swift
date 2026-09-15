#if AIUSAGEBAR_UPDATER_SPIKE
import Combine
import Sparkle

/// U1 engine proof only. Uses Sparkle's stock UI, with no production state/UI layer.
@MainActor
final class UpdaterSpike: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published private(set) var canCheckForUpdates = false
    private var availability: AnyCancellable?

    init() {
        let isTest = KeychainManager.isTestProcess
        controller = SPUStandardUpdaterController(
            startingUpdater: !isTest,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if !isTest {
            availability = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.canCheckForUpdates = $0 }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
