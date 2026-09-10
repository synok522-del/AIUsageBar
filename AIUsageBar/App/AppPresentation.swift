import Foundation

enum UsageChrome: Equatable {
    case menuBarPanel
    case mainWindow
}

enum AppPresentationSettings {
    static let openMainWindowAtLaunchKey = "openMainWindowAtLaunch"

    /// Window version default: open a desktop window on launch.
    static var openMainWindowAtLaunch: Bool {
        get {
            guard UserDefaults.standard.object(forKey: openMainWindowAtLaunchKey) != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: openMainWindowAtLaunchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openMainWindowAtLaunchKey)
        }
    }
}

enum AppActivationPolicyDecision {
    /// Menu-bar-only stays accessory. Any titled window (main, settings, login, welcome)
    /// promotes the app to a regular Dock / Cmd-Tab citizen.
    static func showsDockIcon(visibleWindowCount: Int) -> Bool {
        visibleWindowCount > 0
    }
}

struct MainWindowPresentationPolicy: Equatable {
    var openAtLaunch: Bool

    var shouldOpenOnLaunch: Bool {
        openAtLaunch
    }
}
