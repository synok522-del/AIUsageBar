import AppKit
import Foundation
import WebKit

/// Restores a process-local grok.com WebKit browsing session after cold start.
///
/// Keychain still holds `sso`, but Cloudflare/session cookies are typically
/// session-only and vanish when the app quits. Opening the Grok login WebView
/// works because it creates a WKWebView on the default data store and navigates
/// to grok.com. This performs the same navigation off-screen, without showing
/// UI or entering credentials.
@MainActor
final class GrokWebKitSessionRestorer: NSObject, WKNavigationDelegate {
    static let shared = GrokWebKitSessionRestorer()
    static let restoreURL = URL(string: "https://grok.com/")!
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var didRestoreThisProcess = false
    private var pending: CheckedContinuation<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func restoreIfNeeded() async {
        if didRestoreThisProcess {
            return
        }

        await withCheckedContinuation { continuation in
            pending = continuation
            startNavigation()
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                self?.finishRestore()
            }
        }

        didRestoreThisProcess = true
    }

    func reset() {
        timeoutTask?.cancel()
        timeoutTask = nil
        finishRestore()
        didRestoreThisProcess = false
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        hostWindow?.contentView = nil
        hostWindow = nil
    }

    private func startNavigation() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 240), configuration: configuration)
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
        finishRestore()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finishRestore()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finishRestore()
    }

    private func finishRestore() {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let pending else {
            return
        }
        self.pending = nil
        pending.resume()
    }
}
