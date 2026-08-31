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

final class WebSessionManager {

    static let shared = WebSessionManager()

    private init() {}

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
