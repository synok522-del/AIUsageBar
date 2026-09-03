import Foundation

struct GrokService {
    private let webBaseURL = URL(string: "https://grok.com")!
    private let session: URLSession

    init(session: URLSession = GrokService.sharedSession) {
        self.session = session
    }

    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(
            configuration: configuration,
            delegate: GrokURLSessionRedirectDelegate.shared,
            delegateQueue: nil
        )
    }()

    func fetchUsage(
        rateLimitsCookieHeader: String,
        weeklyCookieHeader: String
    ) async throws -> GrokUsage {
        let rateLimits = try await fetchRateLimits(cookieHeader: rateLimitsCookieHeader)
        let session = try Self.parseRateLimits(rateLimits)

        let weekly = await fetchWeeklyQuota(cookieHeader: weeklyCookieHeader)

        return GrokUsage(
            sessionRemainingPercent: session.remainingPercent,
            resetText: session.resetText,
            sessionWindowSeconds: session.windowSeconds,
            weeklyRemainingPercent: weekly?.remainingPercent,
            weeklyResetText: weekly.map {
                ServiceSupport.absoluteResetText(
                    NSNumber(value: $0.resetAt.timeIntervalSince1970)
                )
            },
            weeklyRelativeResetText: weekly.map {
                ServiceSupport.resetText(
                    NSNumber(value: $0.resetAt.timeIntervalSince1970)
                )
            }
        )
    }

    static func parseRateLimits(_ usage: [String: Any]) throws -> (
        remainingPercent: Int,
        resetText: String,
        windowSeconds: Int
    ) {
        guard let remaining = ServiceSupport.parsedNumber(usage["remainingQueries"]) else {
            throw AIUsageServiceError.invalidPayload("Grok remainingQueries")
        }

        let totalQueries = ServiceSupport.parsedNumber(usage["totalQueries"])

        guard let totalQueries, totalQueries > 0 else {
            throw AIUsageServiceError.invalidPayload("Grok totalQueries")
        }

        let remainingPercent = ServiceSupport.percent((remaining / totalQueries) * 100)
        let windowSeconds = Int(
            ServiceSupport.parsedNumber(usage["windowSizeSeconds"])?.rounded() ?? 0
        )

        let resetText = ServiceSupport.resetText(
            usage["resetAt"] ?? usage["reset_at"]
        )

        return (remainingPercent, resetText, max(0, windowSeconds))
    }

    static func sessionRowLabel(windowSeconds: Int) -> String {
        guard windowSeconds > 0 else {
            return "短窗"
        }

        let hours = windowSeconds / 3600
        let minutes = (windowSeconds % 3600) / 60
        let seconds = windowSeconds % 60

        if hours > 0 {
            if minutes == 0 {
                return "\(hours) 小時"
            }
            return "\(hours) 小時 \(minutes) 分鐘"
        }

        if minutes > 0 {
            if seconds == 0 {
                return "\(minutes) 分鐘"
            }
            return "\(minutes) 分鐘 \(seconds) 秒"
        }

        return "\(seconds) 秒"
    }

    static func ssoToken(from cookieHeader: String) -> String? {
        for part in cookieHeader.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("sso-rw=") {
                continue
            }
            if trimmed.hasPrefix("sso=") {
                let value = String(trimmed.dropFirst(4))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    static func cookieHeader(from cookies: [HTTPCookie]) -> String? {
        credential(from: cookies)?.cookieHeader
    }

    static func credential(from cookies: [HTTPCookie]) -> WebCredential? {
        let pool = cookies.filter {
            WebSessionProvider.matchesGrokProductHost($0.domain)
        }

        guard let sso = pool.first(where: { $0.name == "sso" && !$0.value.isEmpty }) else {
            return nil
        }

        var header = "sso=\(sso.value)"
        if let ssoRw = pool.first(where: { $0.name == "sso-rw" && !$0.value.isEmpty }) {
            header += "; sso-rw=\(ssoRw.value)"
        }

        return WebCredential(
            cookieName: sso.name,
            value: sso.value,
            cookieHeader: header
        )
    }

    private func fetchRateLimits(cookieHeader: String) async throws -> [String: Any] {
        try await postRateLimits(
            cookieHeader: cookieHeader,
            body: ["modelName": "grok-3"]
        )
    }

    private func postRateLimits(
        cookieHeader: String,
        body: [String: String]
    ) async throws -> [String: Any] {
        let url = webBaseURL.appendingPathComponent("rest/rate-limits")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://grok.com", forHTTPHeaderField: "Origin")
        request.setValue("https://grok.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await ServiceSupport.data(
            for: request,
            serviceName: "Grok",
            session: session
        )
        return try ServiceSupport.jsonObject(from: data, serviceName: "Grok")
    }

    private func fetchWeeklyQuota(cookieHeader: String) async -> GrokWeeklyQuota? {
        var request = GrokCreditsConfigDecoder.makeRequest(
            cookieHeader: cookieHeader,
            baseURL: webBaseURL
        )
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            return GrokCreditsConfigDecoder.weeklyQuota(
                httpStatus: http?.statusCode ?? 0,
                contentType: http?.value(forHTTPHeaderField: "Content-Type"),
                body: data,
                grpcStatusHeader: http?.value(forHTTPHeaderField: "Grpc-Status")
            )
        } catch {
            return nil
        }
    }
}
