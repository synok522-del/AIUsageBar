import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowCoordinator: NSObject, ObservableObject, NSWindowDelegate {

    private enum WindowID: Hashable {
        case main
        case settings
        case claudeLogin
        case chatGPTLogin
        case grokLogin
        case welcome
    }

    private var windows: [WindowID: NSWindow] = [:]
    private var welcomeSuppressedForCurrentSession = false
    private var languageCancellable: AnyCancellable?

    override init() {
        super.init()
        languageCancellable = AppLanguageStore.shared.$preference
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.relocalizeOpenWindows()
            }
    }


    // MARK: - Welcome

    func showWelcomeIfNeeded(
        viewModel: UsageViewModel,
        onLoginClaude: @escaping () -> Void,
        onLoginChatGPT: @escaping () -> Void,
        onLoginGrok: @escaping () -> Void
    ) {
        guard !welcomeSuppressedForCurrentSession else {
            return
        }

        let policy = WelcomePresentationPolicy(
            isClaudeLoggedIn: !viewModel.claudeSessionKey.isEmpty,
            isChatGPTLoggedIn: !viewModel.chatGPTSessionToken.isEmpty,
            isGrokLoggedIn: !viewModel.grokSessionToken.isEmpty,
            isSuppressedForCurrentSession: welcomeSuppressedForCurrentSession
        )

        guard policy.shouldShow else {
            return
        }

        present(
            id: .welcome,
            title: L10n.t(.mainWindowTitle),
            size: nil,
            styleMask: [.titled, .closable]
        ) { [weak self] in
            WelcomeView(
                onLoginChatGPT: { [weak self] in
                    self?.close(.welcome)
                    onLoginChatGPT()
                },
                onLoginClaude: { [weak self] in
                    self?.close(.welcome)
                    onLoginClaude()
                },
                onLoginGrok: { [weak self] in
                    self?.close(.welcome)
                    onLoginGrok()
                },
                onLater: { [weak self] in
                    self?.suppressWelcomeForCurrentSession()
                }
            )
        }
    }


    // MARK: - Main window

    func showMainWindow(viewModel: UsageViewModel) {
        present(
            id: .main,
            title: L10n.t(.mainWindowTitle),
            size: nil,
            styleMask: [.titled, .closable, .miniaturizable, .resizable]
        ) {
            UsagePanelView(
                viewModel: viewModel,
                windowCoordinator: self,
                chrome: .mainWindow
            )
        }
    }

    // MARK: - Settings

    func showSettings(
        viewModel: UsageViewModel,
        onLoginClaude: @escaping () -> Void,
        onLoginChatGPT: @escaping () -> Void,
        onLoginGrok: @escaping () -> Void
    ) {

        present(
            id: .settings,
            title: L10n.t(.settingsWindowTitle),
            size: nil,
            styleMask: [.titled, .closable]
        ) {

            SettingsView(
                viewModel: viewModel,
                onLoginChatGPT: onLoginChatGPT,
                onLoginClaude: onLoginClaude,
                onLoginGrok: onLoginGrok
            )
        }
    }


    // MARK: - Claude Login

    func showClaudeLogin(
        onSuccess: @escaping (WebCredential) -> Void
    ) {

        present(
            id: .claudeLogin,
            title: L10n.t(.loginWindowTitle("Claude")),
            size: NSSize(width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable]
        ) { [weak self] in

            ClaudeLoginView(

                onSuccess: { value in
                    onSuccess(value)
                    self?.close(.claudeLogin)
                }
            )
        }
    }


    // MARK: - ChatGPT Login

    func showChatGPTLogin(
        onSuccess: @escaping (WebCredential) -> Void
    ) {

        present(
            id: .chatGPTLogin,
            title: L10n.t(.loginWindowTitle("ChatGPT")),
            size: NSSize(width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable]
        ) { [weak self] in

            ChatGPTLoginView(

                onSuccess: { value in
                    onSuccess(value)
                    self?.close(.chatGPTLogin)
                }
            )
        }
    }


    // MARK: - Grok Login

    func showGrokLogin(
        onSuccess: @escaping (WebCredential) -> Void
    ) {

        present(
            id: .grokLogin,
            title: L10n.t(.loginWindowTitle("Grok")),
            size: NSSize(width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable]
        ) { [weak self] in

            GrokLoginView(

                onSuccess: { value in
                    onSuccess(value)
                    self?.close(.grokLogin)
                }
            )
        }
    }


    // MARK: - Window

    private func present<Content: View>(
        id: WindowID,
        title: String,
        size: NSSize?,
        styleMask: NSWindow.StyleMask,
        @ViewBuilder content: () -> Content
    ) {

        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: content()
        )

        let window = NSWindow(
            contentViewController: controller
        )

        window.isReleasedWhenClosed = false

        window.title = title
        window.styleMask = styleMask

        if id == .main {
            controller.view.layoutSubtreeIfNeeded()
            let fitting = controller.view.fittingSize
            window.setContentSize(
                NSSize(
                    width: max(360, fitting.width),
                    height: max(280, fitting.height)
                )
            )
            window.minSize = NSSize(width: 340, height: 240)
            window.backgroundColor = NSColor(
                red: 0.067,
                green: 0.071,
                blue: 0.102,
                alpha: 1
            )
        } else if let size {
            window.setContentSize(size)
        } else {
            controller.view.layoutSubtreeIfNeeded()
            window.setContentSize(controller.view.fittingSize)
        }

        window.center()
        window.delegate = self

        windows[id] = window
        syncActivationPolicy()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }


    private func relocalizeOpenWindows() {
        windows[.main]?.title = L10n.t(.mainWindowTitle)
        windows[.welcome]?.title = L10n.t(.mainWindowTitle)
        windows[.settings]?.title = L10n.t(.settingsWindowTitle)
        windows[.claudeLogin]?.title = L10n.t(.loginWindowTitle("Claude"))
        windows[.chatGPTLogin]?.title = L10n.t(.loginWindowTitle("ChatGPT"))
        windows[.grokLogin]?.title = L10n.t(.loginWindowTitle("Grok"))
    }

    private func syncActivationPolicy() {
        let showsDock = AppActivationPolicyDecision.showsDockIcon(
            visibleWindowCount: windows.count
        )
        NSApp.setActivationPolicy(showsDock ? .regular : .accessory)
    }

    private func close(_ id: WindowID) {

        windows[id]?.close()

    }

    private func suppressWelcomeForCurrentSession() {
        welcomeSuppressedForCurrentSession = true
        close(.welcome)
    }


    func windowWillClose(_ notification: Notification) {

        guard let window = notification.object as? NSWindow else {
            return
        }

        windows = windows.filter {
            $0.value !== window
        }
        syncActivationPolicy()
    }
}
