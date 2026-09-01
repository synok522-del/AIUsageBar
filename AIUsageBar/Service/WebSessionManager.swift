//
//  WebSessionManager.swift
//  AIUsageBar
//

import Foundation
import WebKit
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
    category: "WebSession"
)

enum WebSessionProvider {
    case claude
    case chatGPT
    case grok

    var displayName: String {
        switch self {
        case .claude:
            "Claude"
        case .chatGPT:
            "ChatGPT"
        case .grok:
            "Grok"
        }
    }

    func matches(_ value: String) -> Bool {
        switch self {
        case .claude:
            return Self.matchesDomain(value, domain: "claude.ai") ||
                Self.matchesDomain(value, domain: "anthropic.com")
        case .chatGPT:
            return Self.matchesDomain(value, domain: "chatgpt.com") ||
                Self.matchesDomain(value, domain: "openai.com")
        case .grok:
            return Self.matchesGrokProductHost(value)
        }
    }

    static func matchesGrokProductHost(_ value: String) -> Bool {
        matchesDomain(value, domain: "grok.com")
    }

    private static func matchesDomain(_ value: String, domain: String) -> Bool {
        let normalizedValue = value
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return normalizedValue == domain ||
            normalizedValue.hasSuffix(".\(domain)")
    }
}

/// 17F-009B diagnostic: build a temporary Cookie header from the current
/// WKWebView/WebKit cookie store for Grok URLSession probing.
/// Cookie VALUES are never logged — names/domain/path metadata only.
enum GrokSessionContextProbe {
    static let rateLimitsURL = URL(string: "https://grok.com/rest/rate-limits")!

    struct Snapshot: Equatable {
        let source: String
        let cookieHeader: String
        let cookieNames: [String]

        var cookieCount: Int { cookieNames.count }

        var diagnosticLabel: String {
            "probe:\(source) cookies=\(cookieCount) names=[\(cookieNames.joined(separator: ","))]"
        }
    }

    static func applicableCookies(
        from cookies: [HTTPCookie],
        to url: URL,
        now: Date = Date()
    ) -> [HTTPCookie] {
        cookies.filter { cookie in
            guard WebSessionProvider.matchesGrokProductHost(cookie.domain) else {
                return false
            }

            if cookie.isSecure, url.scheme?.lowercased() != "https" {
                return false
            }

            if let expires = cookie.expiresDate, expires <= now {
                return false
            }

            return pathMatches(
                requestPath: url.path.isEmpty ? "/" : url.path,
                cookiePath: cookie.path.isEmpty ? "/" : cookie.path
            )
        }
    }

    static func cookieHeader(
        from cookies: [HTTPCookie],
        to url: URL,
        now: Date = Date()
    ) -> String? {
        let applicable = applicableCookies(from: cookies, to: url, now: now)
        guard applicable.contains(where: { $0.name == "sso" && !$0.value.isEmpty }) else {
            return nil
        }

        return HTTPCookie.requestHeaderFields(with: applicable)["Cookie"]
    }

    static func safeNames(
        from cookies: [HTTPCookie],
        to url: URL,
        now: Date = Date()
    ) -> [String] {
        applicableCookies(from: cookies, to: url, now: now)
            .map(\.name)
            .sorted()
    }

    static func cookieNames(fromHeader header: String) -> [String] {
        header.split(separator: ";").compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: "=") else {
                return nil
            }
            let name = String(trimmed[..<separator])
            return name.isEmpty ? nil : name
        }.sorted()
    }

    static func snapshot(
        webKitCookies: [HTTPCookie],
        fallbackHeader: String,
        url: URL = rateLimitsURL,
        now: Date = Date()
    ) -> Snapshot {
        if let header = cookieHeader(from: webKitCookies, to: url, now: now) {
            return Snapshot(
                source: "webkit-full",
                cookieHeader: header,
                cookieNames: safeNames(from: webKitCookies, to: url, now: now)
            )
        }

        return Snapshot(
            source: "keychain-partial",
            cookieHeader: fallbackHeader,
            cookieNames: cookieNames(fromHeader: fallbackHeader)
        )
    }

    static func log(_ snapshot: Snapshot) {
        let names = snapshot.cookieNames.joined(separator: ", ")
        logger.info(
            "Grok diagnostic cookies: names=[\(names, privacy: .public)] count=\(snapshot.cookieCount, privacy: .public) source=\(snapshot.source, privacy: .public)"
        )
    }

    private static func pathMatches(requestPath: String, cookiePath: String) -> Bool {
        if cookiePath == "/" {
            return true
        }

        guard requestPath.hasPrefix(cookiePath) else {
            return false
        }

        if requestPath.count == cookiePath.count || cookiePath.hasSuffix("/") {
            return true
        }

        let index = requestPath.index(
            requestPath.startIndex,
            offsetBy: cookiePath.count
        )
        return requestPath[index] == "/"
    }
}

final class WebSessionManager {

    static let shared = WebSessionManager()

    private init() {}

    /// Current cookies for a provider from the shared WKWebView data store.
    func cookies(for provider: WebSessionProvider) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(
                    returning: cookies.filter { provider.matches($0.domain) }
                )
            }
        }
    }

    /// 清除指定 provider 的 WebView Cookie 與網站資料。
    func clearCookies(
        for provider: WebSessionProvider,
        completion: (() -> Void)? = nil
    ) {
        let dataStore = WKWebsiteDataStore.default()

        dataStore.httpCookieStore.getAllCookies { cookies in
            let group = DispatchGroup()
            let matchingCookies = cookies.filter {
                provider.matches($0.domain)
            }

            for cookie in matchingCookies {
                group.enter()
                dataStore.httpCookieStore.delete(cookie) {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let dataTypes: Set<String> = [
                    WKWebsiteDataTypeCookies,
                    WKWebsiteDataTypeLocalStorage,
                    WKWebsiteDataTypeSessionStorage,
                    WKWebsiteDataTypeIndexedDBDatabases,
                    WKWebsiteDataTypeWebSQLDatabases,
                    WKWebsiteDataTypeDiskCache,
                    WKWebsiteDataTypeMemoryCache
                ]

                dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                    let matchingRecords = records.filter {
                        provider.matches($0.displayName)
                    }

                    guard !matchingRecords.isEmpty else {
                        logger.debug(
                            "Web session cleared for \(provider.displayName, privacy: .public)"
                        )
                        completion?()
                        return
                    }

                    dataStore.removeData(
                        ofTypes: dataTypes,
                        for: matchingRecords
                    ) {
                        logger.debug(
                            "Web session cleared for \(provider.displayName, privacy: .public)"
                        )
                        completion?()
                    }
                }
            }
        }
    }
}
