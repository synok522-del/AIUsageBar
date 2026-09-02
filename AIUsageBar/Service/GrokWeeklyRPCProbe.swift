import Foundation

/// Removable 17F-014 live probe. Not production Weekly UI.
enum GrokWeeklyRPCProbe {
    static let path = "/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig"
    static let emptyFrame = Data([0x00, 0x00, 0x00, 0x00, 0x00])

    struct SemanticFields: Equatable {
        var usedPercent: Int
        var remainingPercent: Int
        var periodType: String
        var periodStart: String?
        var periodEnd: String?
        var billingPeriodEnd: String?
        var chatPercent: Int?
        var appBuilderPercent: Int?
        var imaginePercent: Int?
    }

    enum Outcome: Equatable {
        case decoded(http: Int, grpc: String, fields: SemanticFields)
        case failed(
            http: Int,
            contentType: String,
            frames: String,
            grpc: String,
            classification: String
        )
    }

    static func diagnosticLine(from outcome: Outcome) -> String {
        switch outcome {
        case let .decoded(http, grpc, fields):
            var parts = [
                "weeklyRPC:",
                "http=\(http)",
                "grpc=\(grpc)",
                "used=\(fields.usedPercent)",
                "remaining=\(fields.remainingPercent)",
                "period=\(fields.periodType)"
            ]
            if let start = fields.periodStart {
                parts.append("start=\(start)")
            }
            if let end = fields.periodEnd {
                parts.append("end=\(end)")
            }
            if let chat = fields.chatPercent {
                parts.append("chat=\(chat)")
            }
            if let app = fields.appBuilderPercent {
                parts.append("appBuilder=\(app)")
            }
            if let imagine = fields.imaginePercent {
                parts.append("imagine=\(imagine)")
            }
            if let billing = fields.billingPeriodEnd {
                parts.append("billingEnd=\(billing)")
            }
            return parts.joined(separator: " ")
        case let .failed(http, contentType, frames, grpc, classification):
            return [
                "weeklyRPC:",
                "http=\(http)",
                "contentType=\(sanitizedContentType(contentType))",
                "frames=\(frames)",
                "grpc=\(grpc)",
                "decode=\(classification)"
            ].joined(separator: " ")
        }
    }

    static func makeRequest(cookieHeader: String, baseURL: URL) -> URLRequest {
        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
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

    static func interpret(
        statusCode: Int,
        contentType: String?,
        body: Data,
        grpcStatusHeader: String? = nil
    ) -> Outcome {
        let type = contentType ?? ""
        if ServiceSupport.isNonJSONResponse(contentType: contentType, data: body) {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: "n/a",
                grpc: "n/a",
                classification: "HTML_OR_WAF"
            )
        }

        let frames: ParsedFrames
        do {
            frames = try parseFrames(body)
        } catch {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: "parse_error",
                grpc: headerOrUnknown(nil),
                classification: "FRAME_PARSE_FAILED"
            )
        }

        let grpc = grpcStatus(from: frames.trailerText)
            ?? grpcStatusHeader.map { $0 == "0" ? "OK" : $0 }
            ?? "missing"
        let frameSummary =
            "count=\(frames.count);data=\(frames.dataCount);trailer=\(frames.trailerCount);compressed=\(frames.compressedCount)"

        guard (200..<300).contains(statusCode) else {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: frameSummary,
                grpc: grpc,
                classification: "HTTP_NOT_OK"
            )
        }

        guard frames.compressedCount == 0 else {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: frameSummary,
                grpc: grpc,
                classification: "COMPRESSED_UNSUPPORTED"
            )
        }

        guard grpc == "0" || grpc == "OK" else {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: frameSummary,
                grpc: grpc,
                classification: "GRPC_NOT_OK"
            )
        }

        guard let payload = frames.message else {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: frameSummary,
                grpc: grpc,
                classification: "MISSING_PROTO_MESSAGE"
            )
        }

        do {
            let fields = try decodeConfig(payload)
            return .decoded(http: statusCode, grpc: "OK", fields: fields)
        } catch {
            return .failed(
                http: statusCode,
                contentType: type,
                frames: frameSummary,
                grpc: grpc,
                classification: "PROTO_DECODE_FAILED"
            )
        }
    }

    static func decodeConfig(_ message: Data) throws -> SemanticFields {
        var reader = ProtoReader(data: message)
        var config: Data?
        while let field = try reader.next() {
            if field.number == 1, field.wire == 2 {
                config = field.bytes
            }
        }
        guard let config else {
            throw ProbeDecodeError.missingConfig
        }

        var usedRaw: Float?
        var periodTypeRaw: Int?
        var periodStart: String?
        var periodEnd: String?
        var billingEnd: String?
        var products: [(Int, Float)] = []

        var configReader = ProtoReader(data: config)
        while let field = try configReader.next() {
            switch (field.number, field.wire) {
            case (1, 5):
                usedRaw = field.float32
            case (5, 2):
                billingEnd = decodeTimestamp(field.bytes)
            case (7, 2):
                if let product = decodeProductUsage(field.bytes) {
                    products.append(product)
                }
            case (8, 2):
                let period = decodeUsagePeriod(field.bytes)
                periodTypeRaw = period.type
                periodStart = period.start
                periodEnd = period.end
            default:
                break
            }
        }

        guard let usedRaw else {
            throw ProbeDecodeError.missingUsedPercent
        }

        let used = clampPercent(Double(usedRaw))
        let remaining = max(0, 100 - used)
        var chat: Int?
        var appBuilder: Int?
        var imagine: Int?
        for (product, percent) in products {
            let rounded = clampPercent(Double(percent))
            switch product {
            case 4:
                chat = rounded
            case 5:
                imagine = rounded
            case 7:
                appBuilder = rounded
            default:
                break
            }
        }

        return SemanticFields(
            usedPercent: used,
            remainingPercent: remaining,
            periodType: periodName(periodTypeRaw),
            periodStart: periodStart,
            periodEnd: periodEnd,
            billingPeriodEnd: billingEnd,
            chatPercent: chat,
            appBuilderPercent: appBuilder,
            imaginePercent: imagine
        )
    }

    static func parseFrames(_ data: Data) throws -> ParsedFrames {
        var offset = 0
        var frames = ParsedFrames()
        while offset < data.count {
            guard offset + 5 <= data.count else {
                throw ProbeDecodeError.truncatedFrame
            }
            let flag = data[offset]
            let length = Int(
                data[offset + 1]
            ) << 24
                | Int(data[offset + 2]) << 16
                | Int(data[offset + 3]) << 8
                | Int(data[offset + 4])
            offset += 5
            guard offset + length <= data.count else {
                throw ProbeDecodeError.truncatedFrame
            }
            let payload = data.subdata(in: offset..<(offset + length))
            offset += length
            frames.count += 1
            if flag & 0x01 != 0 {
                frames.compressedCount += 1
                continue
            }
            if flag == 0x80 {
                frames.trailerCount += 1
                frames.trailerText = String(data: payload, encoding: .utf8)
                continue
            }
            if flag == 0 {
                frames.dataCount += 1
                if frames.message == nil {
                    frames.message = payload
                }
                continue
            }
            frames.unknownCount += 1
        }
        return frames
    }

    struct ParsedFrames: Equatable {
        var count = 0
        var dataCount = 0
        var trailerCount = 0
        var compressedCount = 0
        var unknownCount = 0
        var message: Data?
        var trailerText: String?
    }

    private static func decodeProductUsage(_ data: Data) -> (Int, Float)? {
        var reader = ProtoReader(data: data)
        var product: Int?
        var percent: Float?
        while let field = try? reader.next() {
            switch (field.number, field.wire) {
            case (1, 0):
                product = field.varint
            case (2, 5):
                percent = field.float32
            default:
                break
            }
        }
        guard let product, let percent else {
            return nil
        }
        return (product, percent)
    }

    private static func decodeUsagePeriod(_ data: Data) -> (
        type: Int?,
        start: String?,
        end: String?
    ) {
        var reader = ProtoReader(data: data)
        var type: Int?
        var start: String?
        var end: String?
        while let field = try? reader.next() {
            switch (field.number, field.wire) {
            case (1, 0):
                type = field.varint
            case (2, 2):
                start = decodeTimestamp(field.bytes)
            case (3, 2):
                end = decodeTimestamp(field.bytes)
            default:
                break
            }
        }
        return (type, start, end)
    }

    private static func decodeTimestamp(_ data: Data) -> String? {
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
        var date = Date(timeIntervalSince1970: TimeInterval(seconds))
        if nanos != 0 {
            date.addTimeInterval(TimeInterval(nanos) / 1_000_000_000)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func periodName(_ value: Int?) -> String {
        switch value {
        case 1:
            return "MONTHLY"
        case 2:
            return "WEEKLY"
        case 0:
            return "UNSPECIFIED"
        case let value?:
            return "UNKNOWN(\(value))"
        case nil:
            return "missing"
        }
    }

    private static func grpcStatus(from trailer: String?) -> String? {
        guard let trailer else {
            return nil
        }
        for line in trailer.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "grpc-status" {
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                return value == "0" ? "OK" : value
            }
        }
        return nil
    }

    private static func headerOrUnknown(_ value: String?) -> String {
        value ?? "n/a"
    }

    private static func clampPercent(_ value: Double) -> Int {
        guard value.isFinite else {
            return 0
        }
        return min(100, max(0, Int(value.rounded())))
    }

    private static func sanitizedContentType(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "missing"
        }
        return String(trimmed.prefix(80)).replacingOccurrences(of: " ", with: "_")
    }
}

private enum ProbeDecodeError: Error {
    case truncatedFrame
    case missingConfig
    case missingUsedPercent
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
            let value = try readVarint()
            return ProtoField(number: number, wire: wire, varint: Int(value))
        case 1:
            try skip(8)
            return ProtoField(number: number, wire: wire)
        case 2:
            let length = Int(try readVarint())
            let bytes = try readBytes(length)
            return ProtoField(number: number, wire: wire, bytes: bytes)
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
            throw ProbeDecodeError.truncatedFrame
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
                throw ProbeDecodeError.truncatedFrame
            }
        }
        throw ProbeDecodeError.truncatedFrame
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw ProbeDecodeError.truncatedFrame
        }
        let slice = data.subdata(in: offset..<(offset + count))
        offset += count
        return slice
    }

    private mutating func skip(_ count: Int) throws {
        _ = try readBytes(count)
    }
}
