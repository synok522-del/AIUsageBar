import Foundation

/// Races an async operation against a timeout and resumes at most once.
enum BoundedAsyncWait {
    static func value<T: Sendable>(
        timeout: TimeInterval,
        operation: @escaping @Sendable () async -> T,
        onTimeout: T
    ) async -> T {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            func resumeOnce(_ value: T) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else {
                    return
                }
                resumed = true
                continuation.resume(returning: value)
            }

            let work = Task {
                let value = await operation()
                resumeOnce(value)
            }
            Task {
                let nanoseconds = nanoseconds(for: timeout)
                try? await Task.sleep(nanoseconds: nanoseconds)
                work.cancel()
                resumeOnce(onTimeout)
            }
        }
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
