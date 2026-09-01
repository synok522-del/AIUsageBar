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
///
/// Values are allowed in the in-memory Cookie header for the authenticated
/// request. Observability must never log/print/persist/expose those values —
/// only names, domains, paths, counts, expiration presence, and response
/// classification metadata.
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

/// 17F-009C discovery: probe the structured weekly SuperGrok credits source.
enum GrokWeeklyDiscoveryProbe {
    static let creditsURL = URL(string: "https://grok.com/rest/grok/credits")!

    struct ProductUsage: Equatable {
        let product: String
        let usedPercent: Int
    }

    struct ParsedWeekly: Equatable {
        let usedPercent: Int
        let remainingPercent: Int
        let periodType: String
        let resetTimestamp: String
        let productUsage: [ProductUsage]

        var diagnosticLabel: String {
            let products = productUsage
                .map { "\($0.product)=\($0.usedPercent)%" }
                .joined(separator: ",")
            let productSuffix = products.isEmpty ? "" : " products=[\(products)]"
            return "weekly:used=\(usedPercent)% remaining=\(remainingPercent)% period=\(periodType) reset=\(resetTimestamp)\(productSuffix)"
        }
    }

    enum Outcome: Equatable {
        case parsed(ParsedWeekly)
        case unavailable(String)

        var diagnosticLabel: String {
            switch self {
            case .parsed(let weekly):
                return weekly.diagnosticLabel
            case .unavailable(let reason):
                return "weekly:unavailable(\(reason))"
            }
        }
    }

    static func parseCreditsResponse(_ object: [String: Any]) -> Outcome {
        guard let config = object["config"] as? [String: Any] else {
            return .unavailable("missing-config")
        }

        let period = config["currentPeriod"] as? [String: Any]
        let periodType = period?["type"] as? String ?? ""
        guard periodType.contains("WEEKLY") else {
            return .unavailable("non-weekly-period")
        }

        guard let used = ServiceSupport.parsedNumber(config["creditUsagePercent"]) else {
            return .unavailable("missing-creditUsagePercent")
        }

        let usedPercent = ServiceSupport.percent(used)
        let remainingPercent = max(0, 100 - usedPercent)

        let resetTimestamp =
            (period?["end"] as? String)
            ?? (config["billingPeriodEnd"] as? String)
            ?? ""

        guard !resetTimestamp.isEmpty else {
            return .unavailable("missing-reset")
        }

        let productUsage = (config["productUsage"] as? [[String: Any]] ?? [])
            .compactMap { entry -> ProductUsage? in
                guard let product = entry["product"] as? String,
                      let percent = ServiceSupport.parsedNumber(entry["usagePercent"]) else {
                    return nil
                }

                return ProductUsage(
                    product: product,
                    usedPercent: ServiceSupport.percent(percent)
                )
            }

        return .parsed(
            ParsedWeekly(
                usedPercent: usedPercent,
                remainingPercent: remainingPercent,
                periodType: periodType,
                resetTimestamp: resetTimestamp,
                productUsage: productUsage
            )
        )
    }

    func fetch(cookieHeader: String) async -> Outcome {
        var request = URLRequest(url: Self.creditsURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://grok.com", forHTTPHeaderField: "Origin")
        request.setValue("https://grok.com/?_s=usage", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let data = try await ServiceSupport.data(for: request, serviceName: "Grok")
            let object = try ServiceSupport.jsonObject(from: data, serviceName: "Grok")
            return Self.parseCreditsResponse(object)
        } catch let error as AIUsageServiceError {
            switch error {
            case .wafBlocked:
                return .unavailable("HTML/WAF")
            case .httpStatus(_, let statusCode):
                return .unavailable("HTTP_\(statusCode)")
            case .invalidPayload:
                return .unavailable("invalid-payload")
            case .invalidResponse:
                return .unavailable("invalid-response")
            case .missingValue:
                return .unavailable("missing-value")
            }
        } catch {
            return .unavailable("network")
        }
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
