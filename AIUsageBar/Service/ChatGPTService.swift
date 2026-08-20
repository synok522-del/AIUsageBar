import Foundation

struct ChatGPTService {
    private let baseURL = URL(string: "https://chatgpt.com")!

    func fetchUsage(sessionToken: String) async throws -> ChatGPTUsage {
        try await fetchUsage(
            cookieHeader: "__Secure-next-auth.session-token=\(sessionToken)"
        )
    }

    func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage {
        let accessToken = try await fetchAccessToken(cookieHeader: cookieHeader)
        let usage = try await fetchUsage(accessToken: accessToken)

        return try Self.parseUsage(usage)
    }

    static func parseUsage(_ usage: [String: Any]) throws -> ChatGPTUsage {
        guard let rateLimit = usage["rate_limit"] as? [String: Any],
              let primaryWindow = rateLimit["primary_window"] as? [String: Any] else {
            throw AIUsageServiceError.invalidPayload(
                "ChatGPT rate_limit.primary_window"
            )
        }

        let usedPercent = try ServiceSupport.requiredPercent(
            primaryWindow["used_percent"],
            serviceName: "ChatGPT",
            field: "rate_limit.primary_window.used_percent"
        )
        return ChatGPTUsage(
            sessionRemainingPercent: max(0, 100 - usedPercent),
            resetText: ServiceSupport.resetText(primaryWindow["reset_at"])
        )
    }

    private func fetchAccessToken(cookieHeader: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/auth/session")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let data = try await ServiceSupport.data(for: request, serviceName: "ChatGPT")
        let object = try ServiceSupport.jsonObject(from: data, serviceName: "ChatGPT")
        guard let accessToken = object["accessToken"] as? String, !accessToken.isEmpty else {
            throw AIUsageServiceError.missingValue("無法取得 ChatGPT Access Token")
        }
        return accessToken
    }

    private func fetchUsage(accessToken: String) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent("backend-api/wham/usage")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data = try await ServiceSupport.data(for: request, serviceName: "ChatGPT")
        return try ServiceSupport.jsonObject(from: data, serviceName: "ChatGPT")
    }
}
