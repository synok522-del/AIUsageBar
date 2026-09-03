import Foundation

struct GrokWeeklyQuota: Equatable {
    let usedPercent: Int
    let remainingPercent: Int
    let resetAt: Date
}

enum GrokCreditsConfigDecoder {
    static let requestPath = "/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig"
    static let emptyFrame = Data([0x00, 0x00, 0x00, 0x00, 0x00])
    static let weeklyPeriodType = 2

    static func remainingPercent(usedPercent: Int) -> Int {
        let used = clampPercent(Double(usedPercent))
        return max(0, 100 - used)
    }

    static func remainingPercent(usedRaw: Double) -> Int {
        remainingPercent(usedPercent: clampPercent(usedRaw))
    }

    static func weeklyQuota(
        httpStatus: Int,
        contentType: String?,
        body: Data,
        grpcStatusHeader: String? = nil
    ) -> GrokWeeklyQuota? {
        guard (200..<300).contains(httpStatus) else {
            return nil
        }
        if ServiceSupport.isNonJSONResponse(contentType: contentType, data: body) {
            return nil
        }
        guard let frames = try? parseFrames(body) else {
            return nil
        }
        guard frames.compressedCount == 0, let message = frames.message else {
            return nil
        }
        let grpc = grpcStatus(from: frames.trailerText)
            ?? grpcStatusHeader.map { $0 == "0" ? "OK" : $0 }
        guard grpc == nil || grpc == "OK" || grpc == "0" else {
            return nil
        }
        return try? decodeValidatedWeekly(message)
    }

    static func decodeValidatedWeekly(_ message: Data) throws -> GrokWeeklyQuota {
        var reader = ProtoReader(data: message)
        var config: Data?
        while let field = try reader.next() {
            if field.number == 1, field.wire == 2 {
                config = field.bytes
            }
        }
        guard let config else {
            throw DecodeError.invalid
        }

        var usedRaw: Float?
        var periodType: Int?
        var periodEnd: Date?

        var configReader = ProtoReader(data: config)
        while let field = try configReader.next() {
            switch (field.number, field.wire) {
            case (1, 5):
                usedRaw = field.float32
            case (8, 2):
                let period = decodePeriod(field.bytes)
                periodType = period.type
                periodEnd = period.end
            default:
                break
            }
        }

        return try validatedWeekly(
            usedRaw: usedRaw.map(Double.init),
            periodType: periodType,
            periodEnd: periodEnd
        )
    }

    static func validatedWeekly(
        usedRaw: Double?,
        periodType: Int?,
        periodEnd: Date?
    ) throws -> GrokWeeklyQuota {
        guard let usedRaw, usedRaw.isFinite else {
            throw DecodeError.invalid
        }
        guard periodType == weeklyPeriodType else {
            throw DecodeError.invalid
        }
        guard let periodEnd, periodEnd.timeIntervalSince1970.isFinite else {
            throw DecodeError.invalid
        }

        let used = clampPercent(usedRaw)
        return GrokWeeklyQuota(
            usedPercent: used,
            remainingPercent: remainingPercent(usedPercent: used),
            resetAt: periodEnd
        )
    }

    static func makeRequest(cookieHeader: String, baseURL: URL) -> URLRequest {
        let url = URL(string: requestPath, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/grpc-web+proto", forHTTPHeaderField: "Content-Type")
        request.setValue("application/grpc-web+proto", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "X-Grpc-Web")
        request.setValue("connect-es/2.1.1", forHTTPHeaderField: "X-User-Agent")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://grok.com", forHTTPHeaderField: "Origin")
        request.setValue("https://grok.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpShouldHandleCookies = false
        request.httpBody = emptyFrame
        return request
    }

    private enum DecodeError: Error {
        case invalid
        case truncatedFrame
    }

    private struct Frames {
        var message: Data?
        var trailerText: String?
        var compressedCount = 0
    }

    private static func parseFrames(_ data: Data) throws -> Frames {
        var offset = 0
        var frames = Frames()
        while offset < data.count {
            guard offset + 5 <= data.count else {
                throw DecodeError.truncatedFrame
            }
            let flag = data[offset]
            let length =
                Int(data[offset + 1]) << 24
                | Int(data[offset + 2]) << 16
                | Int(data[offset + 3]) << 8
                | Int(data[offset + 4])
            offset += 5
            guard offset + length <= data.count else {
                throw DecodeError.truncatedFrame
            }
            let payload = data.subdata(in: offset..<(offset + length))
            offset += length
            if flag & 0x01 != 0 {
                frames.compressedCount += 1
                continue
            }
            if flag == 0x80 {
                frames.trailerText = String(data: payload, encoding: .utf8)
                continue
            }
            if flag == 0, frames.message == nil {
                frames.message = payload
            }
        }
        return frames
    }

    private static func decodePeriod(_ data: Data) -> (type: Int?, end: Date?) {
        var reader = ProtoReader(data: data)
        var type: Int?
        var end: Date?
        while let field = try? reader.next() {
            switch (field.number, field.wire) {
            case (1, 0):
                type = field.varint
            case (3, 2):
                end = decodeTimestamp(field.bytes)
            default:
                break
            }
        }
        return (type, end)
    }

    private static func decodeTimestamp(_ data: Data) -> Date? {
        var reader = ProtoReader(data: data)
        var seconds: Int64 = 0
        var nanos: Int32 = 0
        while let field = try? reader.next() {
            switch (field.number, field.wire) {
            case (1, 0):
                seconds = Int64(field.varint)
            case (2, 0):
                nanos = Int32(truncatingIfNeeded: field.varint)
            default:
                break
            }
        }
        guard seconds != 0 || nanos != 0 else {
            return nil
        }
        return Date(
            timeIntervalSince1970: TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
        )
    }

    private static func grpcStatus(from trailer: String?) -> String? {
        guard let trailer else {
            return nil
        }
        for line in trailer.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "grpc-status" {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func clampPercent(_ value: Double) -> Int {
        guard value.isFinite else {
            return 0
        }
        return min(100, max(0, Int(value.rounded())))
    }
}

private struct ProtoField {
    var number: Int
    var wire: Int
    var varint: Int = 0
    var bytes: Data = Data()
    var float32: Float = 0
}

private struct ProtoReader {
    let data: Data
    var offset = 0

    mutating func next() throws -> ProtoField? {
        guard offset < data.count else {
            return nil
        }
        let key = try readVarint()
        let number = Int(key >> 3)
        let wire = Int(key & 0x7)
        switch wire {
        case 0:
            return ProtoField(number: number, wire: wire, varint: Int(try readVarint()))
        case 1:
            _ = try readBytes(8)
            return ProtoField(number: number, wire: wire)
        case 2:
            let length = Int(try readVarint())
            return ProtoField(number: number, wire: wire, bytes: try readBytes(length))
        case 5:
            let bytes = try readBytes(4)
            let bits =
                UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
            return ProtoField(
                number: number,
                wire: wire,
                float32: Float(bitPattern: bits)
            )
        default:
            throw GrokCreditsConfigDecoderError.truncated
        }
    }

    private mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift > 63 {
                throw GrokCreditsConfigDecoderError.truncated
            }
        }
        throw GrokCreditsConfigDecoderError.truncated
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw GrokCreditsConfigDecoderError.truncated
        }
        let slice = data.subdata(in: offset..<(offset + count))
        offset += count
        return slice
    }
}

private enum GrokCreditsConfigDecoderError: Error {
    case truncated
}
