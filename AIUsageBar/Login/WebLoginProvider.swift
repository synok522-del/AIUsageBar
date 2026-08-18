//
//  WebLoginProvider.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI
import WebKit
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
    category: "WebLogin"
)

enum WebLoginProvider {
    case claude
    case chatGPT

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatGPT: return "ChatGPT"
        }
    }

    var loginURL: URL {
        switch self {
        case .claude:
            return URL(string: "https://claude.ai/login")!
        case .chatGPT:
            return URL(string: "https://chatgpt.com/auth/login")!
        }
    }

    func credential(from cookies: [HTTPCookie]) -> String? {
        switch self {
        case .claude:
            return cookies.first {
                $0.name == "sessionKey" && $0.domain.localizedCaseInsensitiveContains("claude.ai")
            }?.value
        case .chatGPT:
            return CookieTokenAssembler.value(
                from: cookies,
                baseNames: [
                    "__Secure-next-auth.session-token",
                    "__Host-next-auth.session-token",
                    "next-auth.session-token"
                ],
                domainMatcher: { domain in
                    domain.localizedCaseInsensitiveContains("chatgpt.com") ||
                    domain.localizedCaseInsensitiveContains("openai.com")
                }
            )
        }
    }
}

struct WebLoginView: NSViewRepresentable {
    let provider: WebLoginProvider
    let onCredentialFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(provider: provider, onCredentialFound: onCredentialFound)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        context.coordinator.hostedWebView = webView
        webView.load(URLRequest(url: provider.loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.stopPolling()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let provider: WebLoginProvider
        private let onCredentialFound: (String) -> Void
        fileprivate weak var hostedWebView: WKWebView?
        private var pollTimer: Timer?
        private var didDeliverCredential = false
        private var lastCookieSignature = ""

        init(provider: WebLoginProvider, onCredentialFound: @escaping (String) -> Void) {
            self.provider = provider
            self.onCredentialFound = onCredentialFound
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            logger.debug("[\(self.provider.displayName, privacy: .public)] Page: \(webView.url?.absoluteString ?? "nil", privacy: .private(mask: .hash))")
            startPolling()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logger.error("[\(self.provider.displayName, privacy: .public)] Navigation failed: \(error.localizedDescription, privacy: .private)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            logger.error("[\(self.provider.displayName, privacy: .public)] Initial navigation failed: \(error.localizedDescription, privacy: .private)")
        }

        private func startPolling() {
            guard pollTimer == nil else { return }
            pollCookies()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pollCookies()
                }
            }
        }

        private func pollCookies() {
            guard let webView = hostedWebView else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.logCookieSnapshotIfNeeded(cookies)

                    guard !self.didDeliverCredential,
                          let credential = self.provider.credential(from: cookies),
                          !credential.isEmpty else { return }

                    self.didDeliverCredential = true
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil

                    self.onCredentialFound(credential)

                    self.hostedWebView?.window?.close()
                }
            }
        }

        private func logCookieSnapshotIfNeeded(_ cookies: [HTTPCookie]) {
            let sortedCookies = cookies.sorted {
                ($0.domain, $0.name) < ($1.domain, $1.name)
            }
            let signature = sortedCookies.map {
                "\($0.domain)|\($0.name)|\($0.path)|\($0.value.count)"
            }.joined(separator: "\n")

            guard signature != lastCookieSignature else { return }
            lastCookieSignature = signature

            logger.debug("[\(self.provider.displayName, privacy: .public)] Cookie snapshot (\(sortedCookies.count))")
            if sortedCookies.isEmpty {
                logger.debug("[\(self.provider.displayName, privacy: .public)] No cookies found")
            } else {
                for cookie in sortedCookies {
                    logger.debug("[\(self.provider.displayName, privacy: .public)] name=\(cookie.name, privacy: .private(mask: .hash)), domain=\(cookie.domain, privacy: .private(mask: .hash)), path=\(cookie.path, privacy: .private(mask: .hash)), secure=\(cookie.isSecure), valueLength=\(cookie.value.count)")
                }
            }
        }

        func stopPolling() {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
}

enum CookieTokenAssembler {
    static func value(
        from cookies: [HTTPCookie],
        baseNames: [String],
        domainMatcher: (String) -> Bool
    ) -> String? {
        for baseName in baseNames {
            let matchingCookies = cookies.filter { cookie in
                domainMatcher(cookie.domain) &&
                (cookie.name == baseName || cookie.name.hasPrefix(baseName + "."))
            }

            if let exact = matchingCookies.first(where: { $0.name == baseName }) {
                return exact.value
            }

            let chunks = matchingCookies.compactMap { cookie -> (Int, String)? in
                let prefix = baseName + "."
                guard cookie.name.hasPrefix(prefix),
                      let index = Int(cookie.name.dropFirst(prefix.count)) else {
                    return nil
                }
                return (index, cookie.value)
            }.sorted { $0.0 < $1.0 }

            if !chunks.isEmpty {
                return chunks.map(\.1).joined()
            }
        }

        return nil
    }
}
