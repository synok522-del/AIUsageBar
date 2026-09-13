import Foundation

struct HTTPRateLimitBackoffRecord: Equatable, Codable, Sendable {
    var provider: String
    var accountKey: String
    var backoffUntil: Date
    var step: Int
}

enum HTTPRateLimitBackoffPolicy {
    static let minimumDelay: TimeInterval = 60
    static let exponentialCap: TimeInterval = 15 * 60

    static func delay(
        step: Int,
        retryAfter: TimeInterval?,
        minimumDelay: TimeInterval = minimumDelay,
        exponentialCap: TimeInterval = exponentialCap
    ) -> TimeInterval {
        let exponent = max(0, step)
        let rawExponential = minimumDelay * pow(2, Double(exponent))
        let exponential = min(exponentialCap, rawExponential)
        // Retry-After is a floor. Zero must not defeat the minimum/exponential delay.
        // A server value above the normal cap is honored rather than retried early.
        let retryFloor = max(0, retryAfter ?? 0)
        return max(exponential, retryFloor)
    }

    static func until(
        step: Int,
        retryAfter: TimeInterval?,
        now: Date = Date(),
        minimumDelay: TimeInterval = minimumDelay,
        exponentialCap: TimeInterval = exponentialCap
    ) -> Date {
        now.addingTimeInterval(
            delay(
                step: step,
                retryAfter: retryAfter,
                minimumDelay: minimumDelay,
                exponentialCap: exponentialCap
            )
        )
    }
}

protocol HTTPRateLimitBackoffStoring: AnyObject {
    func record(
        provider: UsageProviderID,
        accountKey: String,
        retryAfter: TimeInterval?,
        now: Date
    )
    func backoffUntil(
        provider: UsageProviderID,
        accountKey: String,
        now: Date
    ) -> Date?
    func isBackingOff(
        provider: UsageProviderID,
        accountKey: String,
        now: Date
    ) -> Bool
    func clear(provider: UsageProviderID, accountKey: String)
}

final class HTTPRateLimitBackoffStore: HTTPRateLimitBackoffStoring, @unchecked Sendable {
    static let storageKey = "aiusgbar.http429Backoff.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func record(
        provider: UsageProviderID,
        accountKey: String,
        retryAfter: TimeInterval?,
        now: Date = Date()
    ) {
        lock.lock()
        defer { lock.unlock() }
        var records = loadLocked()
        let existing = records[key(provider, accountKey)]
        let step = max(0, existing?.step ?? 0)
        records[key(provider, accountKey)] = HTTPRateLimitBackoffRecord(
            provider: provider.rawValue,
            accountKey: accountKey,
            backoffUntil: HTTPRateLimitBackoffPolicy.until(
                step: step,
                retryAfter: retryAfter,
                now: now
            ),
            step: step + 1
        )
        saveLocked(records)
    }

    func backoffUntil(
        provider: UsageProviderID,
        accountKey: String,
        now: Date = Date()
    ) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        guard let record = loadLocked()[key(provider, accountKey)] else {
            return nil
        }
        if now >= record.backoffUntil {
            return nil
        }
        return record.backoffUntil
    }

    func isBackingOff(
        provider: UsageProviderID,
        accountKey: String,
        now: Date = Date()
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let record = loadLocked()[key(provider, accountKey)] else {
            return false
        }
        return now < record.backoffUntil
    }

    func clear(provider: UsageProviderID, accountKey: String) {
        lock.lock()
        defer { lock.unlock() }
        var records = loadLocked()
        records.removeValue(forKey: key(provider, accountKey))
        saveLocked(records)
    }

    private func key(_ provider: UsageProviderID, _ accountKey: String) -> String {
        "\(provider.rawValue).\(accountKey)"
    }

    private func loadLocked() -> [String: HTTPRateLimitBackoffRecord] {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode(
            [String: HTTPRateLimitBackoffRecord].self,
            from: data
        ) else {
            return [:]
        }
        return decoded
    }

    private func saveLocked(_ records: [String: HTTPRateLimitBackoffRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}

enum RetryAfterParser {
    static func timeInterval(from header: String?, now: Date = Date()) -> TimeInterval? {
        guard let header else {
            return nil
        }
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let seconds = Double(trimmed), seconds.isFinite {
            return max(0, seconds)
        }

        for format in httpDateFormats {
            if let date = format.date(from: trimmed) {
                return max(0, date.timeIntervalSince(now))
            }
        }
        return nil
    }

    private static let httpDateFormats: [DateFormatter] = {
        let templates = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEEE, dd-MMM-yy HH:mm:ss zzz",
            "EEE MMM d HH:mm:ss yyyy"
        ]
        return templates.map { template in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = template
            return formatter
        }
    }()
}
