import SwiftUI

@main
struct AIUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var didEvaluateWelcome = false

    var body: some Scene {
        if ProcessInfo.processInfo.isRunningUnderXcodeTests {
            // MenuBarExtra + LSUIElement can exit before XCTest connects.
            WindowGroup {
                EmptyView()
            }
        } else {
            menuBarScene
        }
    }

    private var menuBarScene: some Scene {
        MenuBarExtra {
            UsagePanelView(viewModel: viewModel)
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
                    model.statusMessage = "Claude 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginChatGPT: { [weak coordinator] in
                coordinator?.showChatGPTLogin { credential in
                    model.setChatGPTCredential(credential)
                    model.statusMessage = "ChatGPT 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            },
            onLoginGrok: { [weak coordinator] in
                coordinator?.showGrokLogin { credential in
                    model.setGrokCredential(credential)
                    model.statusMessage = "Grok 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            }
        )
    }
}
