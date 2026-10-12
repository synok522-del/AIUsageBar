import Foundation

protocol ChatGPTUsageFetching {
    @MainActor func fetchUsage(cookieHeader: String) async throws -> ChatGPTUsage
}

struct ChatGPTService: ChatGPTUsageFetching {
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
        let rateLimit = try ServiceSupport.usageDictionary(usage["rate_limit"])
        let primaryWindow = try ServiceSupport.usageDictionary(rateLimit["primary_window"])
        let usedPercent = try ServiceSupport.usagePercent(primaryWindow["used_percent"])

        var weeklyRemainingPercent: Int?
        var weeklyResetText: String?
        var weeklyResetAt: Date?

        var weeklyReason: UsageUnavailableReason?
        do {
            let secondaryWindow = try ServiceSupport.usageDictionary(rateLimit["secondary_window"])
            let weeklyUsedPercent = try ServiceSupport.usagePercent(secondaryWindow["used_percent"])
            weeklyRemainingPercent = 100 - weeklyUsedPercent
            weeklyResetAt = ServiceSupport.resetDate(secondaryWindow["reset_at"])
            let formattedReset = ServiceSupport.absoluteResetText(secondaryWindow["reset_at"])
            weeklyResetText = formattedReset.isEmpty ? nil : formattedReset
        } catch {
            weeklyReason = .forError(error)
        }

        return ChatGPTUsage(
            sessionRemainingPercent: max(0, 100 - usedPercent),
            resetText: ServiceSupport.resetText(primaryWindow["reset_at"]),
            weeklyRemainingPercent: weeklyRemainingPercent,
            weeklyResetText: weeklyResetText,
            sessionResetAt: ServiceSupport.resetDate(primaryWindow["reset_at"]),
            weeklyResetAt: weeklyResetAt,
            weeklyUnavailable: weeklyRemainingPercent == nil,
            weeklyUnavailableReason: weeklyReason
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
            throw AIUsageServiceError.missingValue(L10n.missingChatGPTToken)
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
