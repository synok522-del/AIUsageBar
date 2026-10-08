import SwiftUI

@main
struct AIUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var updater = AppUpdater()
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var didEvaluateWelcome = false

    init() {
        AppBuildIdentity.validateBundle()
        #if LIVE_VALIDATION
        if CommandLine.arguments.contains("--live-validation-smoke") {
            precondition(AppBuildIdentity.keychainService == "com.synok522.AIUsageBar.LiveValidation")
            precondition(!AppBuildIdentity.websiteDataStore.isPersistent)
            precondition(!LaunchAtLoginManager.shared.isEnabled)
            precondition(!UpdaterConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]).isReady)
            print("PASS: Live Validation bundle, Keychain, WebKit, login item and updater isolation")
            exit(0)
        }
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            if AppBuildIdentity.isLiveValidation {
                Text("AIUsageBar Live Validation").font(.caption).foregroundStyle(.orange)
            }
            UsagePanelView(viewModel: viewModel, updater: updater)
        } label: {
            MenuBarStatusView(viewModel: viewModel)
                .task {
                    showWelcomeIfNeededOnce()
                }
        }
        .menuBarExtraStyle(.window)
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
                    model.statusMessage = L10n.loginSucceeded("Claude")

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginChatGPT: { [weak coordinator] in
                coordinator?.showChatGPTLogin { credential in
                    model.setChatGPTCredential(credential)
                    model.statusMessage = L10n.loginSucceeded("ChatGPT")

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginGrok: { [weak coordinator] in
                coordinator?.showGrokLogin { credential in
                    model.setGrokCredential(credential)
                    model.statusMessage = L10n.loginSucceeded("Grok")
                }
            }
        )
    }
}
