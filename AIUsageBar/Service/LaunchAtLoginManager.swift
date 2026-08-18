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
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {

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
