import AppKit
import SwiftUI

@main
enum AIUsageBarAppLauncher {
    static func main() {
        // SceneBuilder on macOS 13 cannot use if/else, so pick an App type instead.
        if ProcessInfo.processInfo.isRunningUnderXcodeTests {
            TestHostApp.main()
        } else {
            AIUsageBarApp.main()
        }
    }
}

private final class TestHostAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement keeps the real app out of the Dock; UI tests need a
        // regular, activatable windowed process.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct TestHostApp: App {
    @NSApplicationDelegateAdaptor(TestHostAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("UI Test Host") {
            Text("AIUsageBar UI Test Host")
                .accessibilityIdentifier("ui-test-host")
                .frame(minWidth: 240, minHeight: 80)
                .padding()
        }
    }
}

struct AIUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var didEvaluateWelcome = false

    var body: some Scene {
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
