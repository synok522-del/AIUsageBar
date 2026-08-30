import Foundation

struct GrokService {
    private let webBaseURL = URL(string: "https://grok.com")!

    func fetchUsage(sessionToken: String) async throws -> GrokUsage {
        try await fetchUsage(cookieHeader: "sso=\(sessionToken)")
    }

    func fetchUsage(cookieHeader: String) async throws -> GrokUsage {
        let rateLimits = try await fetchRateLimits(cookieHeader: cookieHeader)
        let session = try Self.parseRateLimits(rateLimits)

        return GrokUsage(
            sessionRemainingPercent: session.remainingPercent,
            resetText: session.resetText,
            sessionWindowSeconds: session.windowSeconds,
            weeklyRemainingPercent: nil,
            weeklyResetText: nil
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

        let total = ServiceSupport.parsedNumber(usage["totalTokens"])
            ?? ServiceSupport.parsedNumber(usage["totalQueries"])

        guard let total, total > 0 else {
            throw AIUsageServiceError.invalidPayload("Grok totalTokens/totalQueries")
        }

        let remainingPercent = ServiceSupport.percent((remaining / total) * 100)
        let windowSeconds = Int(
            ServiceSupport.parsedNumber(usage["windowSizeSeconds"])?.rounded() ?? 0
        )

        let resetText: String
        if windowSeconds > 0 {
            resetText = ServiceSupport.resetText(
                Date().timeIntervalSince1970 + Double(windowSeconds)
            )
        } else {
            resetText = ServiceSupport.resetText(
                usage["resetAt"] ?? usage["reset_at"]
            )
        }

        return (remainingPercent, resetText, max(0, windowSeconds))
    }

    static func sessionRowLabel(windowSeconds: Int) -> String {
        guard windowSeconds > 0 else {
            return "短窗"
        }

        let hours = max(1, Int((Double(windowSeconds) / 3600.0).rounded()))
        return "\(hours) 小時"
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
        let matching = cookies.filter { WebSessionProvider.grok.matches($0.domain) }
        let preferred = matching.filter {
            WebSessionProvider.matchesGrokProductHost($0.domain)
        }
        let pool = preferred.isEmpty ? matching : preferred

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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await ServiceSupport.data(for: request, serviceName: "Grok")
        return try ServiceSupport.jsonObject(from: data, serviceName: "Grok")
    }
}
