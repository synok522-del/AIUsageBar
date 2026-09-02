//
//  ServiceSupport.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//

import Foundation

enum ServiceSupport {

    static func data(
        for request: URLRequest,
        serviceName: String,
        session: URLSession = .shared
    ) async throws -> Data {

        var request = request
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIUsageServiceError.invalidResponse(serviceName)
        }

        try validateHTTPResponse(
            statusCode: httpResponse.statusCode,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
            data: data,
            serviceName: serviceName
        )

        return data
    }

    static func validateHTTPResponse(
        statusCode: Int,
        contentType: String?,
        data: Data,
        serviceName: String
    ) throws {
        if statusCode == 401 {
            throw AIUsageServiceError.httpStatus(serviceName, 401)
        }

        if isNonJSONResponse(contentType: contentType, data: data) {
            throw AIUsageServiceError.wafBlocked(serviceName)
        }

        guard (200..<300).contains(statusCode) else {
            throw AIUsageServiceError.httpStatus(serviceName, statusCode)
        }
    }

    static func isNonJSONResponse(contentType: String?, data: Data) -> Bool {
        let type = (contentType ?? "").lowercased()
        if type.contains("text/html") || type.contains("application/xhtml") {
            return true
        }

        let prefix = String(data: data.prefix(512), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if prefix.hasPrefix("<!doctype html") ||
            prefix.hasPrefix("<html") ||
            prefix.hasPrefix("<head") {
            return true
        }

        if prefix.contains("cloudflare") &&
            (prefix.contains("<html") || prefix.contains("attention required") || prefix.contains("just a moment")) {
            return true
        }

        return false
    }

    static func jsonObject(
        from data: Data,
        serviceName: String
    ) throws -> [String: Any] {

        if isNonJSONResponse(contentType: nil, data: data) {
            throw AIUsageServiceError.wafBlocked(serviceName)
        }

        guard let object =
            try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw AIUsageServiceError.invalidPayload(serviceName)
        }

        return object
    }

    static func number(_ value: Any?) -> Double {
        parsedNumber(value) ?? 0
    }

    static func percent(_ value: Any?) -> Int {
        clampedPercent(number(value))
    }

    static func requiredPercent(
        _ value: Any?,
        serviceName: String,
        field: String
    ) throws -> Int {
        guard let value = parsedNumber(value) else {
            throw AIUsageServiceError.invalidPayload(
                "\(serviceName) \(field)"
            )
        }

        return clampedPercent(value)
    }

    static func resetText(_ value: Any?) -> String {
        guard let date = resetDate(value) else {
            return ""
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.unitsStyle = .full

        return "重置於 " +
            formatter.localizedString(
                for: date,
                relativeTo: Date()
            )
    }

    static func absoluteResetText(
        _ value: Any?,
        locale: Locale = Locale(identifier: "zh_TW"),
        timeZone: TimeZone = .current
    ) -> String {
        guard let date = resetDate(value) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "M 月 d 日 a h:mm"
        return formatter.string(from: date)
    }

    static func combinedResetText(
        session: String,
        weekly: String
    ) -> String {
        if !session.isEmpty && !weekly.isEmpty {
            return "\(session)｜\(weekly)"
        }

        if !session.isEmpty {
            return session
        }

        if !weekly.isEmpty {
            return "重置於 \(weekly)"
        }

        return ""
    }

    static func resetDate(_ value: Any?) -> Date? {
        guard let value else {
            return nil
        }

        if let number = value as? NSNumber {
            let rawTimestamp = number.doubleValue
            let timestamp =
                rawTimestamp > 100_000_000_000
                ? rawTimestamp / 1000
                : rawTimestamp

            return Date(timeIntervalSince1970: timestamp)
        }

        if let string = value as? String {
            if let timestamp = Double(string) {
                let normalized =
                    timestamp > 100_000_000_000
                    ? timestamp / 1000
                    : timestamp

                return Date(timeIntervalSince1970: normalized)
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            return formatter.date(from: string)
                ?? {
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter.date(from: string)
                }()
                ?? posixDate(from: string)
        }

        return nil
    }


    private static func posixDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    static func parsedNumber(_ value: Any?) -> Double? {
        let number: Double?

        if let value = value as? NSNumber {
            number = value.doubleValue
        } else if let value = value as? Double {
            number = value
        } else if let value = value as? Int {
            number = Double(value)
        } else if let value = value as? String {
            number = Double(value)
        } else {
            number = nil
        }

        guard let number, number.isFinite else {
            return nil
        }

        return number
    }

    private static func clampedPercent(_ value: Double) -> Int {
        let rounded = value.rounded()

        if rounded <= 0 {
            return 0
        }

        if rounded >= 100 {
            return 100
        }

        return Int(rounded)
    }
}


// MARK: - Error

enum AIUsageServiceError: LocalizedError {

    case invalidResponse(String)
    case httpStatus(String, Int)
    case invalidPayload(String)
    case missingValue(String)
    case wafBlocked(String)

    var errorDescription: String? {

        switch self {

        case .invalidResponse(let service):
            return "\(service) 回應格式錯誤"

        case .httpStatus(let service, let statusCode):

            switch statusCode {

            case 401:
                return "\(service) 登入已失效，請重新登入"

            case 403:
                return "\(service) 沒有權限，請重新登入"

            case 429:
                return "\(service) 請求過於頻繁，請稍後再試"

            case 500...599:
                return "\(service) 服務暫時無法使用"

            default:
                return "\(service) 發生錯誤（HTTP \(statusCode)）"
            }

        case .invalidPayload(let service):
            return "\(service) 回傳資料格式錯誤"

        case .missingValue(let message):
            return message

        case .wafBlocked(let service):
            return "\(service) 被網站防護擋下，請稍後再試"
        }
    }
}
