//
//  ClaudeUsage.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import Foundation

struct ClaudeUsage {
    let sessionRemainingPercent: Int
    let weeklyRemainingPercent: Int
    let resetText: String
}

struct ClaudeService {
    private let baseURL = URL(string: "https://claude.ai")!

    func fetchUsage(sessionKey: String) async throws -> ClaudeUsage {
        let organizationID = try await fetchOrganizationID(sessionKey: sessionKey)
        let usage = try await fetchUsage(organizationID: organizationID, sessionKey: sessionKey)

        let sessionUsed = ServiceSupport.percent(usage["five_hour"]?["utilization"])
        let weeklyUsed = ServiceSupport.percent(usage["seven_day"]?["utilization"])
        let sessionReset = ServiceSupport.resetText(usage["five_hour"]?["resets_at"])
        let weeklyReset = ServiceSupport.resetText(usage["seven_day"]?["resets_at"])

        return ClaudeUsage(
            sessionRemainingPercent: max(0, 100 - sessionUsed),
            weeklyRemainingPercent: max(0, 100 - weeklyUsed),
            resetText: sessionReset.isEmpty ? weeklyReset : sessionReset
        )
    }

    private func fetchOrganizationID(sessionKey: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/organizations")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let data = try await ServiceSupport.data(for: request, serviceName: "Claude")
        guard let organizations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = organizations.first else {
            throw AIUsageServiceError.invalidPayload("Claude organization")
        }

        if let id = first["id"] as? String { return id }
        if let uuid = first["uuid"] as? String { return uuid }
        throw AIUsageServiceError.missingValue("找不到 Claude Organization ID")
    }

    private func fetchUsage(organizationID: String, sessionKey: String) async throws -> [String: [String: Any]] {
        let url = baseURL
            .appendingPathComponent("api/organizations")
            .appendingPathComponent(organizationID)
            .appendingPathComponent("usage")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let data = try await ServiceSupport.data(for: request, serviceName: "Claude")
        let object = try ServiceSupport.jsonObject(from: data, serviceName: "Claude")

        return object.reduce(into: [String: [String: Any]]()) { result, item in
            if let dictionary = item.value as? [String: Any] {
                result[item.key] = dictionary
            }
        }
    }
}
