import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopen: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            onReopen?()
        }
        return true
    }
}

@main
struct AIUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var didEvaluateWelcome = false
    @State private var didEvaluateMainWindow = false

    var body: some Scene {
        MenuBarExtra {
            UsagePanelView(
                viewModel: viewModel,
                windowCoordinator: windowCoordinator,
                chrome: .menuBarPanel
            )
        } label: {
            MenuBarStatusView(viewModel: viewModel)
                .task {
                    configureReopenHandler()
                    showWelcomeIfNeededOnce()
                    showMainWindowIfNeededOnce()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func configureReopenHandler() {
        let coordinator = windowCoordinator
        let model = viewModel
        appDelegate.onReopen = {
            coordinator.showMainWindow(viewModel: model)
        }
    }

    private func showMainWindowIfNeededOnce() {
        guard !didEvaluateMainWindow else {
            return
        }

        didEvaluateMainWindow = true

        let policy = MainWindowPresentationPolicy(
            openAtLaunch: AppPresentationSettings.openMainWindowAtLaunch
        )
        guard policy.shouldOpenOnLaunch else {
            return
        }

        windowCoordinator.showMainWindow(viewModel: viewModel)
    }

    private func showWelcomeIfNeededOnce() {
        guard !didEvaluateWelcome else {
            return
        }

        didEvaluateWelcome = true

        let coordinator = windowCoordinator
        let model = viewModel

        coordinator.showWelcomeIfNeeded(
            viewModel: model,
            onLoginClaude: { [weak coordinator] in
                coordinator?.showClaudeLogin { credential in
                    model.setClaudeSessionKey(credential.value)
                    model.statusMessage = L10n.t(.loginSucceeded("Claude"))

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginChatGPT: { [weak coordinator] in
                coordinator?.showChatGPTLogin { credential in
                    model.setChatGPTCredential(credential)
                    model.statusMessage = L10n.t(.loginSucceeded("ChatGPT"))

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginGrok: { [weak coordinator] in
                coordinator?.showGrokLogin { credential in
                    model.setGrokCredential(credential)
                    model.statusMessage = L10n.t(.loginSucceeded("Grok"))
                }
            }
        )
    }
}
