import Foundation

/// 17F-011 discovery only: inspect GET /rest/grok/credits for a Free Grok account.
/// Removable. Does not enable a Weekly UI row or change quota math.
enum GrokFreeCreditsProbe {
    static let creditsURL = URL(string: "https://grok.com/rest/grok/credits")!

    enum Classification: String, Equatable {
        case noWeeklyEntitlement = "NO_WEEKLY_ENTITLEMENT"
        case historicalOrStaleWeeklyData = "HISTORICAL_OR_STALE_WEEKLY_DATA"
        case activeWeeklyDataUnexpected = "ACTIVE_WEEKLY_DATA_UNEXPECTED"
        case endpointUnavailable = "ENDPOINT_UNAVAILABLE_FOR_FREE_ACCOUNT"
        case otherStructured = "OTHER_STRUCTURED_RESPONSE"
    }

    struct FieldReport: Equatable {
        var creditUsagePercent: String = "ABSENT"
        var periodType: String = "ABSENT"
        var periodStart: String = "ABSENT"
        var periodEnd: String = "ABSENT"
        var billingPeriodEnd: String = "ABSENT"
        var productUsage: String = "ABSENT"
        var entitlementKeys: String = "ABSENT"
        var periodEndRelation: String = "UNKNOWN"
    }

    struct Result: Equatable {
        let httpStatus: Int?
        let responseClass: String
        let jsonParsed: Bool
        let fields: FieldReport
        let classification: Classification

        var diagnosticLabel: String {
            "credits:HTTP_\(httpStatus.map(String.init) ?? "nil") \(responseClass) json=\(jsonParsed) used=\(fields.creditUsagePercent) period=\(fields.periodType) start=\(fields.periodStart) end=\(fields.periodEnd) endRel=\(fields.periodEndRelation) billing=\(fields.billingPeriodEnd) products=\(fields.productUsage) keys=\(fields.entitlementKeys) class=\(classification.rawValue)"
        }
    }

    static func classify(
        httpStatus: Int?,
        responseClass: String,
        jsonParsed: Bool,
        fields: FieldReport
    ) -> Classification {
        if responseClass == "HTML/WAF" || responseClass == "unavailable" {
            return .endpointUnavailable
        }

        if let status = httpStatus, !(200..<300).contains(status) {
            return .endpointUnavailable
        }

        guard jsonParsed else {
            return .otherStructured
        }

        let periodType = fields.periodType
        let looksWeekly = periodType != "ABSENT" && periodType.uppercased().contains("WEEKLY")

        if !looksWeekly {
            if periodType == "ABSENT" && fields.creditUsagePercent == "ABSENT" {
                return .otherStructured
            }
            return .noWeeklyEntitlement
        }

        switch fields.periodEndRelation {
        case "PAST":
            return .historicalOrStaleWeeklyData
        case "FUTURE", "NOW":
            return .activeWeeklyDataUnexpected
        default:
            return .otherStructured
        }
    }

    static func parseJSON(
        _ object: [String: Any],
        now: Date = Date()
    ) -> FieldReport {
        var fields = FieldReport()
        let config = object["config"] as? [String: Any] ?? object
        let period = config["currentPeriod"] as? [String: Any]

        if let used = ServiceSupport.parsedNumber(config["creditUsagePercent"]) {
            fields.creditUsagePercent = String(ServiceSupport.percent(used))
        }

        if let type = period?["type"] as? String, !type.isEmpty {
            fields.periodType = type
        }

        if let start = stringValue(period?["start"]) {
            fields.periodStart = start
        }

        if let end = stringValue(period?["end"]) {
            fields.periodEnd = end
        }

        if let billing = stringValue(config["billingPeriodEnd"]) {
            fields.billingPeriodEnd = billing
        }

        let products = (config["productUsage"] as? [[String: Any]] ?? []).compactMap {
            productLabel(from: $0)
        }
        if !products.isEmpty {
            fields.productUsage = products.joined(separator: ",")
        }

        let entitlementNames = [
            "subscriptionStatus", "entitled", "isEntitled", "plan", "tier",
            "product", "status", "subscription", "hasSubscription"
        ].filter { key in
            config[key] != nil || object[key] != nil
        }
        if !entitlementNames.isEmpty {
            fields.entitlementKeys = entitlementNames.joined(separator: ",")
        }

        let endValue = period?["end"] ?? config["billingPeriodEnd"]
        if let date = ServiceSupport.resetDate(endValue) {
            if date > now.addingTimeInterval(60) {
                fields.periodEndRelation = "FUTURE"
            } else if date < now.addingTimeInterval(-60) {
                fields.periodEndRelation = "PAST"
            } else {
                fields.periodEndRelation = "NOW"
            }
        }

        return fields
    }

    static func fetch(
        cookieHeader: String,
        now: Date = Date()
    ) async -> Result {
        var request = URLRequest(url: creditsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://grok.com", forHTTPHeaderField: "Origin")
        request.setValue("https://grok.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            GrokWebKitSessionRestorer.userAgent,
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode
            let contentType = http?.value(forHTTPHeaderField: "Content-Type")
            let responseClass: String
            if ServiceSupport.isNonJSONResponse(contentType: contentType, data: data) {
                responseClass = "HTML/WAF"
            } else if (data as NSData).length > 0,
                      (try? JSONSerialization.jsonObject(with: data)) != nil {
                responseClass = "JSON"
            } else {
                responseClass = "other"
            }

            var jsonParsed = false
            var fields = FieldReport()
            if responseClass == "JSON",
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                jsonParsed = true
                fields = parseJSON(object, now: now)
            }

            let classification = classify(
                httpStatus: status,
                responseClass: responseClass,
                jsonParsed: jsonParsed,
                fields: fields
            )

            return Result(
                httpStatus: status,
                responseClass: responseClass,
                jsonParsed: jsonParsed,
                fields: fields,
                classification: classification
            )
        } catch {
            return Result(
                httpStatus: nil,
                responseClass: "unavailable",
                jsonParsed: false,
                fields: FieldReport(),
                classification: .endpointUnavailable
            )
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func productLabel(from entry: [String: Any]) -> String? {
        guard let product = entry["product"] as? String, !product.isEmpty else {
            return nil
        }
        let percent =
            ServiceSupport.parsedNumber(entry["usagePercent"])
            ?? ServiceSupport.parsedNumber(entry["creditUsagePercent"])
        if let percent {
            return "\(product)=\(ServiceSupport.percent(percent))%"
        }
        return product
    }
}
