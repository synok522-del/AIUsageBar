import Foundation

protocol ClaudeUsageFetching {
    @MainActor func fetchUsage(sessionKey: String) async throws -> ClaudeUsage
}

struct ClaudeOrganization: Equatable, Sendable {
    let id: String
    let displayName: String?

    static func normalizedID(_ rawID: String?) -> String? {
        guard let rawID else { return nil }
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.count <= 256,
              !id.contains("/"), !id.contains("\\"),
              !id.contains("?"), !id.contains("#"),
              id != ".", id != "..",
              !id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return id
    }

    static func sanitizedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let scalars = name.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? UnicodeScalar(32)! : scalar
        }
        let cleaned = String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let truncated = String(cleaned.prefix(48))
        return truncated.isEmpty ? nil : truncated
    }
}

enum ClaudeOrganizationSelectionError: Error, Equatable, LocalizedError {
    case unavailable
    case ambiguous

    var errorDescription: String? {
        switch self {
        case .unavailable: L10n.claudeOrganizationUnavailable
        case .ambiguous: L10n.claudeOrganizationAmbiguous
        }
    }
}

struct ClaudeService: ClaudeUsageFetching {
    private let baseURL = URL(string: "https://claude.ai")!

    private let session: URLSession

    init(session: URLSession = ServiceSupport.quotaSession) { self.session = session }

    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        let organization = try await fetchOrganization(sessionKey: sessionKey)
        let usage = try await fetchUsage(organizationID: organization.id, sessionKey: sessionKey)

        return try Self.parseUsage(usage, organization: organization)
    }

    static func parseUsage(
        _ usage: [String: Any],
        organization: ClaudeOrganization? = nil
    ) throws -> ClaudeUsage {
        let session = try ServiceSupport.usageDictionary(usage["five_hour"])
        let sessionUsed = try ServiceSupport.usagePercent(session["utilization"])
        var weeklyUsed: Int?
        var weeklyReason: UsageUnavailableReason?
        do {
            let weekly = try ServiceSupport.usageDictionary(usage["seven_day"])
            weeklyUsed = try ServiceSupport.usagePercent(weekly["utilization"])
        } catch {
            weeklyReason = .forError(error)
        }
        let sessionReset = ServiceSupport.resetText((usage["five_hour"] as? [String: Any])?["resets_at"])
        let weeklyAbsoluteReset = weeklyUsed == nil
            ? ""
            : ServiceSupport.absoluteResetText((usage["seven_day"] as? [String: Any])?["resets_at"])

        return ClaudeUsage(
            sessionRemainingPercent: max(0, 100 - sessionUsed),
            weeklyRemainingPercent: weeklyUsed.map { max(0, 100 - $0) },
            resetText: sessionReset,
            weeklyResetText: weeklyAbsoluteReset,
            sessionResetAt: ServiceSupport.resetDate((usage["five_hour"] as? [String: Any])?["resets_at"]),
            weeklyResetAt: weeklyUsed == nil
                ? nil
                : ServiceSupport.resetDate((usage["seven_day"] as? [String: Any])?["resets_at"]),
            organizationID: organization?.id,
            organizationName: organization?.displayName,
            weeklyUnavailableReason: weeklyReason
        )
    }

    static func selectOrganization(from organizations: [[String: Any]]) throws -> ClaudeOrganization {
        guard let first = organizations.first,
              let id = ClaudeOrganization.normalizedID(first["id"] as? String)
                ?? ClaudeOrganization.normalizedID(first["uuid"] as? String) else {
            throw ClaudeOrganizationSelectionError.unavailable
        }
        return ClaudeOrganization(
            id: id,
            displayName: ClaudeOrganization.sanitizedName(first["name"] as? String)
        )
    }

    private func fetchOrganization(sessionKey: String) async throws -> ClaudeOrganization {
        let url = baseURL.appendingPathComponent("api/organizations")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let data = try await ServiceSupport.data(for: request, serviceName: "Claude", session: session)
        guard let organizations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AIUsageServiceError.invalidPayload("Claude organization")
        }
        return try Self.selectOrganization(from: organizations)
    }

    private func fetchUsage(organizationID: String, sessionKey: String) async throws -> [String: Any] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/organizations/\(organizationID)/usage"
        guard let url = components.url else {
            throw ClaudeOrganizationSelectionError.unavailable
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let data = try await ServiceSupport.data(for: request, serviceName: "Claude", session: session)
        let object = try ServiceSupport.jsonObject(from: data, serviceName: "Claude")

        return object
    }
}
