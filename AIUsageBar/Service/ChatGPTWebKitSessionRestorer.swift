import AppKit
import Foundation
import WebKit

/// Restores a process-local chatgpt.com WebKit browsing session after auth expiry.
///
/// Healthy ChatGPT refresh must not call this type. Recovery navigates
/// `chatgpt.com` on the shared default data store and succeeds only when a
/// usable next-auth session cookie can be assembled.
@MainActor
protocol ChatGPTSessionRestoring: AnyObject {
    func restoreAfterRecoverableFailure() async -> ChatGPTSessionRestoreOutcome
    func reset()
}

@MainActor
final class ChatGPTWebKitSessionRestorer: NSObject, WKNavigationDelegate, ChatGPTSessionRestoring {
    static let shared = ChatGPTWebKitSessionRestorer()
    static let restoreURL = URL(string: "https://chatgpt.com/")!
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private var gate = ChatGPTSessionRestorerGate()
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var pending: (
        generation: UInt,
        continuation: CheckedContinuation<ChatGPTSessionRestoreOutcome, Never>
    )?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func restoreAfterRecoverableFailure() async -> ChatGPTSessionRestoreOutcome {
        invalidateInFlight(resume: .cancelled)
        gate.invalidateForRecovery()
        teardownWebView()
        return await performRestore()
    }

    func reset() {
        invalidateInFlight(resume: .cancelled)
        gate.reset()
        teardownWebView()
    }

    private func performRestore() async -> ChatGPTSessionRestoreOutcome {
        let attempt = gate.beginRestore()
        let outcome: ChatGPTSessionRestoreOutcome = await withCheckedContinuation { continuation in
            pending = (attempt, continuation)
            startNavigation()
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                self?.finish(.timeout, generation: attempt)
            }
        }
        gate.complete(attemptGeneration: attempt, outcome: outcome)
        return outcome
    }

    private func startNavigation() {
        teardownWebView()

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 240),
            configuration: configuration
        )
        webView.customUserAgent = Self.userAgent
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: -16_000, y: -16_000, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle, .stationary]
        window.contentView = webView
        hostWindow = window

        webView.load(URLRequest(url: Self.restoreURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let generation = pending?.generation
        Task { @MainActor [weak self] in
            guard let self, let generation else {
                return
            }

            let cookies = await WebSessionManager.shared.cookies(for: .chatGPT)
            let hasSession = ChatGPTSessionContext.cookieHeader(from: cookies) != nil
            self.finish(
                hasSession ? .success : .failure,
                generation: generation
            )
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure, generation: pending?.generation)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure, generation: pending?.generation)
    }

    private func finish(
        _ outcome: ChatGPTSessionRestoreOutcome,
        generation: UInt?
    ) {
        timeoutTask?.cancel()
        timeoutTask = nil

        guard let pending,
              let generation,
              pending.generation == generation else {
            return
        }

        self.pending = nil
        pending.continuation.resume(returning: outcome)
    }

    private func invalidateInFlight(resume outcome: ChatGPTSessionRestoreOutcome) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let pending {
            self.pending = nil
            pending.continuation.resume(returning: outcome)
        }
    }

    private func teardownWebView() {
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        hostWindow?.contentView = nil
        hostWindow = nil
    }
}
