import Foundation
import Testing
@testable import AIUsageBar

struct MainWindowPresentationTests {
    init() {
        AppLanguageSettings.testingOverride = .chineseTraditional
    }

    @Test("Main window opens at launch unless the user turned it off")
    func mainWindowLaunchDefaultAndOverride() {
        let key = AppPresentationSettings.openMainWindowAtLaunchKey
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        #expect(AppPresentationSettings.openMainWindowAtLaunch)
        #expect(
            MainWindowPresentationPolicy(openAtLaunch: true).shouldOpenOnLaunch
        )
        #expect(
            MainWindowPresentationPolicy(openAtLaunch: false).shouldOpenOnLaunch
                == false
        )

        AppPresentationSettings.openMainWindowAtLaunch = false
        #expect(AppPresentationSettings.openMainWindowAtLaunch == false)
        AppPresentationSettings.openMainWindowAtLaunch = true
        #expect(AppPresentationSettings.openMainWindowAtLaunch)
    }

    @Test("Dock icon appears only while a titled window is open")
    func dockIconFollowsVisibleWindowCount() {
        #expect(AppActivationPolicyDecision.showsDockIcon(visibleWindowCount: 0) == false)
        #expect(AppActivationPolicyDecision.showsDockIcon(visibleWindowCount: 1))
        #expect(AppActivationPolicyDecision.showsDockIcon(visibleWindowCount: 3))
    }
}
