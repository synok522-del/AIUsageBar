//
//  LaunchAtLoginManager.swift
//

import Foundation
import ServiceManagement
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
    category: "LaunchAtLogin"
)

@MainActor
final class LaunchAtLoginManager {

    static let shared = LaunchAtLoginManager()

    private init() {}

    var isEnabled: Bool {
        !AppBuildIdentity.isLiveValidation && SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard !AppBuildIdentity.isLiveValidation else { return }

        do {

            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

        } catch {

            logger.error("LaunchAtLogin error: \(error.localizedDescription, privacy: .public)")
        }
    }
}
