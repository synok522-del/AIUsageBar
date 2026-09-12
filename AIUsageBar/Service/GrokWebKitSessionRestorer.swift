import AppKit
import Foundation
import WebKit

/// Restores a process-local grok.com WebKit browsing session.
///
/// READY is latched only after navigation completes with a usable grok.com
/// `sso` cookie. Failure, timeout, and logout cannot latch READY. A later
/// recoverable fetch failure can invalidate READY and restore once more.
@MainActor
protocol GrokSessionRestoring: AnyObject {
    func restoreIfNeeded() async -> GrokSessionRestoreOutcome
    func restoreAfterRecoverableFailure() async -> GrokSessionRestoreOutcome
    func reset()
}

@MainActor
final class GrokWebKitSessionRestorer: NSObject, WKNavigationDelegate, GrokSessionRestoring {
    static let shared = GrokWebKitSessionRestorer()
    nonisolated static let restoreURL = URL(string: "https://grok.com/")!
    nonisolated static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private var gate = GrokSessionRestorerGate()
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var pending: (
        generation: UInt,
        continuation: CheckedContinuation<GrokSessionRestoreOutcome, Never>
    )?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func restoreIfNeeded() async -> GrokSessionRestoreOutcome {
        if gate.phase == .ready {
            return .success
        }

        return await performRestore()
    }

    func restoreAfterRecoverableFailure() async -> GrokSessionRestoreOutcome {
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

    private func performRestore() async -> GrokSessionRestoreOutcome {
        guard pending == nil else { return .cancelled }
        let attempt = gate.beginRestore()
        let outcome: GrokSessionRestoreOutcome = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .cancelled)
                    return
                }
                pending = (attempt, continuation)
                startNavigation()
                timeoutTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                    self?.finish(.timeout, generation: attempt)
                }
            }
        }, onCancel: { @MainActor [weak self] in
            self?.finish(.cancelled, generation: attempt)
        })
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
        guard webView === self.webView else { return }
        let generation = pending?.generation
        Task { @MainActor [weak self] in
            guard let self, let generation else {
                return
            }

            let cookies = await WebSessionManager.shared.cookies(for: .grok)
            let hasUsableSSO = GrokSessionContext.cookieHeader(
                from: cookies,
                to: GrokSessionContext.rateLimitsURL
            ) != nil
            self.finish(
                hasUsableSSO ? .success : .failure,
                generation: generation
            )
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === self.webView else { return }
        finish(.failure, generation: pending?.generation)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === self.webView else { return }
        finish(.failure, generation: pending?.generation)
    }

    private func finish(
        _ outcome: GrokSessionRestoreOutcome,
        generation: UInt?
    ) {
        guard let pending,
              let generation,
              pending.generation == generation else {
            return
        }

        timeoutTask?.cancel()
        timeoutTask = nil
        self.pending = nil
        pending.continuation.resume(returning: outcome)
    }

    private func invalidateInFlight(resume outcome: GrokSessionRestoreOutcome) {
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
