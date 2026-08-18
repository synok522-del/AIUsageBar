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
        serviceName: String
    ) async throws -> Data {

        var request = request
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIUsageServiceError.invalidResponse(serviceName)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIUsageServiceError.httpStatus(
                serviceName,
                httpResponse.statusCode
            )
        }

        return data
    }

    static func jsonObject(
        from data: Data,
        serviceName: String
    ) throws -> [String: Any] {

        guard let object =
            try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw AIUsageServiceError.invalidPayload(serviceName)
        }

        return object
    }

    static func number(_ value: Any?) -> Double {

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let double = value as? Double {
            return double
        }

        if let int = value as? Int {
            return Double(int)
        }

        if let string = value as? String,
           let double = Double(string) {
            return double
        }

        return 0
    }

    static func percent(_ value: Any?) -> Int {

        min(
            max(
                Int(round(number(value))),
                0
            ),
            100
        )
    }

    static func resetText(_ value: Any?) -> String {

        guard let value else {
            return ""
        }

        let date: Date?

        if let number = value as? NSNumber {

            let rawTimestamp = number.doubleValue

            let timestamp =
                rawTimestamp > 100_000_000_000
                ? rawTimestamp / 1000
                : rawTimestamp

            date = Date(timeIntervalSince1970: timestamp)

        } else if let string = value as? String {

            if let timestamp = Double(string) {

                let normalized =
                    timestamp > 100_000_000_000
                    ? timestamp / 1000
                    : timestamp

                date = Date(timeIntervalSince1970: normalized)

            } else {

                let formatter = ISO8601DateFormatter()

                formatter.formatOptions = [
                    .withInternetDateTime,
                    .withFractionalSeconds
                ]

                date =
                    formatter.date(from: string)
                    ?? {

                        formatter.formatOptions = [
                            .withInternetDateTime
                        ]

                        return formatter.date(from: string)

                    }()
            }

        } else {

            date = nil

        }

        guard let date else {
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
}


// MARK: - Error

enum AIUsageServiceError: LocalizedError {

    case invalidResponse(String)
    case httpStatus(String, Int)
    case invalidPayload(String)
    case missingValue(String)

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
        }
    }
}
