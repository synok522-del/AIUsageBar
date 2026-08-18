import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowCoordinator: NSObject, ObservableObject, NSWindowDelegate {

    private enum WindowID: Hashable {
        case settings
        case claudeLogin
        case chatGPTLogin
    }

    private var windows: [WindowID: NSWindow] = [:]


    // MARK: - Settings

    func showSettings(
        viewModel: UsageViewModel,
        onLoginClaude: @escaping () -> Void,
        onLoginChatGPT: @escaping () -> Void
    ) {

        present(
            id: .settings,
            title: "AI 用量設定",
            size: nil,
            styleMask: [.titled, .closable]
        ) {

            SettingsView(
                viewModel: viewModel,
                onLoginClaude: onLoginClaude,
                onLoginChatGPT: onLoginChatGPT
            )
        }
    }


    // MARK: - Claude Login

    func showClaudeLogin(
        onSuccess: @escaping (String) -> Void
    ) {

        present(
            id: .claudeLogin,
            title: "登入 Claude",
            size: NSSize(width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable]
        ) { [weak self] in

            ClaudeLoginView(

                onSuccess: { value in
                    onSuccess(value)
                    self?.close(.claudeLogin)
                },

                onCancel: { [weak self] in
                    self?.close(.claudeLogin)
                }
            )
        }
    }


    // MARK: - ChatGPT Login

    func showChatGPTLogin(
        onSuccess: @escaping (String) -> Void
    ) {

        present(
            id: .chatGPTLogin,
            title: "登入 ChatGPT",
            size: NSSize(width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable]
        ) { [weak self] in

            ChatGPTLoginView(

                onSuccess: { value in
                    onSuccess(value)
                    self?.close(.chatGPTLogin)
                },

                onCancel: { [weak self] in
                    self?.close(.chatGPTLogin)
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

        window.title = title
        window.styleMask = styleMask

        if let size {
            window.setContentSize(size)
        } else {
            controller.view.layoutSubtreeIfNeeded()
            window.setContentSize(controller.view.fittingSize)
        }

        window.center()
        window.delegate = self

        windows[id] = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }


    private func close(_ id: WindowID) {

        windows[id]?.close()

    }


    func windowWillClose(_ notification: Notification) {

        guard let window = notification.object as? NSWindow else {
            return
        }

        windows = windows.filter {
            $0.value !== window
        }
    }
}
