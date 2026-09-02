import Foundation

/// 17F-012 discovery: live-verify GET /rest/grok/credits for SuperGrok Weekly.
/// Removable. Does not enable a Weekly UI row or change /rate-limits math.
enum GrokWeeklyLiveProbe {
    static let creditsURL = URL(string: "https://grok.com/rest/grok/credits")!

    struct Snapshot: Equatable {
        var httpStatus: String = "ABSENT"
        var responseClass: String = "other"
        var jsonParsed: Bool = false
        var used: String = "ABSENT"
        var remaining: String = "ABSENT"
        var periodType: String = "ABSENT"
        var periodStart: String = "ABSENT"
        var periodEnd: String = "ABSENT"
        var billingPeriodEnd: String = "ABSENT"
        var products: String = "ABSENT"

        var diagnosticLabel: String {
            "credits: HTTP=\(httpStatus) json=\(jsonParsed) used=\(used) remaining=\(remaining) period=\(periodType) start=\(periodStart) end=\(periodEnd) billing=\(billingPeriodEnd) products=\(products)"
        }
    }

    static func parseJSON(_ object: [String: Any]) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.jsonParsed = true
        snapshot.responseClass = "JSON"

        let config = object["config"] as? [String: Any] ?? object
        let period = config["currentPeriod"] as? [String: Any]

        if let used = ServiceSupport.parsedNumber(config["creditUsagePercent"]) {
            let usedPercent = ServiceSupport.percent(used)
            snapshot.used = String(usedPercent)
            snapshot.remaining = String(max(0, 100 - usedPercent))
        }

        if let type = period?["type"] as? String, !type.isEmpty {
            snapshot.periodType = type.uppercased().contains("WEEKLY") ? "WEEKLY" : type
        }

        if let start = stringValue(period?["start"]) {
            snapshot.periodStart = start
        }
        if let end = stringValue(period?["end"]) {
            snapshot.periodEnd = end
        }
        if let billing = stringValue(config["billingPeriodEnd"]) {
            snapshot.billingPeriodEnd = billing
        }

        let products = (config["productUsage"] as? [[String: Any]] ?? []).compactMap {
            productLabel(from: $0)
        }
        if !products.isEmpty {
            snapshot.products = products.joined(separator: ",")
        }

        return snapshot
    }

    static func fetch(cookieHeader: String) async -> Snapshot {
        var request = URLRequest(url: creditsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = false
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

            var snapshot = Snapshot()
            snapshot.httpStatus = status.map(String.init) ?? "ABSENT"

            if ServiceSupport.isNonJSONResponse(contentType: contentType, data: data) {
                snapshot.responseClass = "HTML/WAF"
                return snapshot
            }

            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                snapshot.responseClass = "other"
                return snapshot
            }

            snapshot = parseJSON(object)
            snapshot.httpStatus = status.map(String.init) ?? "ABSENT"
            return snapshot
        } catch {
            var snapshot = Snapshot()
            snapshot.responseClass = "unavailable"
            return snapshot
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
