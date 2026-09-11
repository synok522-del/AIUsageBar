import AppKit
import Foundation

/// Observes Mac sleep/wake and forwards wake through the shared refresh path.
@MainActor
final class WorkspaceWakeObserver {
    private var token: NSObjectProtocol?
    private let center: NotificationCenter

    init(
        center: NotificationCenter = NSWorkspace.shared.notificationCenter,
        handler: @escaping () -> Void
    ) {
        self.center = center
        token = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func invalidate() {
        if let token {
            center.removeObserver(token)
            self.token = nil
        }
    }

    deinit {
        if let token {
            center.removeObserver(token)
        }
    }
}
