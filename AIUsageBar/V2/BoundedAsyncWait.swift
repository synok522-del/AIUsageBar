import Foundation

/// Races an async operation against a timeout and resumes at most once.
///
/// Timeout completion does not await or drain the underlying work. The
/// cancelled work task may still be running; callers must ignore late results.
enum BoundedAsyncWait {
    enum Outcome<T: Sendable>: Sendable {
        case finished(T)
        case timedOut
    }

    static func value<T: Sendable>(
        timeout: TimeInterval,
        operation: @escaping @Sendable () async -> T,
        onTimeout: T
    ) async -> T {
        switch await race(timeout: timeout, operation: operation) {
        case .finished(let value):
            return value
        case .timedOut:
            return onTimeout
        }
    }

    static func race<T: Sendable>(
        timeout: TimeInterval,
        work: Task<T, Never>
    ) async -> Outcome<T> {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            func resumeOnce(_ value: Outcome<T>) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else {
                    return
                }
                resumed = true
                continuation.resume(returning: value)
            }

            Task {
                let value = await work.value
                resumeOnce(.finished(value))
            }
            Task {
                let nanoseconds = nanoseconds(for: timeout)
                try? await Task.sleep(nanoseconds: nanoseconds)
                resumeOnce(.timedOut)
                work.cancel()
            }
        }
    }

    static func race<T: Sendable>(
        timeout: TimeInterval,
        operation: @escaping @Sendable () async -> T
    ) async -> Outcome<T> {
        let work = Task {
            await operation()
        }
        return await race(timeout: timeout, work: work)
    }

    static func nanoseconds(for timeout: TimeInterval) -> UInt64 {
        let clamped = max(0, timeout)
        let nanos = clamped * 1_000_000_000
        guard nanos.isFinite, nanos < Double(UInt64.max) else {
            return UInt64.max / 2
        }
        return UInt64(nanos)
    }
}
