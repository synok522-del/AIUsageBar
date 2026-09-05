import Foundation

enum GrokSessionRestorerPhase: Equatable {
    case unknown
    case restoring
    case ready
}

enum GrokSessionRestoreOutcome: Equatable {
    case success
    case failure
    case timeout
    case cancelled
}

/// Process-local restorer gate. WebKit I/O stays in `GrokWebKitSessionRestorer`.
struct GrokSessionRestorerGate: Equatable {
    private(set) var generation: UInt = 0
    private(set) var phase: GrokSessionRestorerPhase = .unknown

    mutating func beginRestore() -> UInt {
        phase = .restoring
        return generation
    }

    mutating func complete(
        attemptGeneration: UInt,
        outcome: GrokSessionRestoreOutcome
    ) {
        guard attemptGeneration == generation else {
            return
        }

        switch outcome {
        case .success:
            phase = .ready
        case .failure, .timeout, .cancelled:
            phase = .unknown
        }
    }

    mutating func invalidateForRecovery() {
        generation += 1
        phase = .unknown
    }

    /// Overnight READY can outlive a usable grok.com `sso` cookie.
    /// Recovery must not skip WebKit restore in that state.
    mutating func invalidateReadyIfSessionUnusable(hasUsableSSO: Bool) {
        guard phase == .ready, !hasUsableSSO else {
            return
        }
        invalidateForRecovery()
    }

    mutating func reset() {
        generation += 1
        phase = .unknown
    }
}

/// Invalidated synchronously on Grok logout or credential replacement.
/// In-flight HTTP refresh captures a generation and must not recover, retry,
/// or write usage after it no longer matches.
struct GrokHTTPAuthGeneration: Equatable {
    private(set) var value: UInt = 0

    mutating func invalidate() {
        value += 1
    }
}

enum GrokHTTPRefreshAuthPolicy {
    static func shouldCommit(captured: UInt, current: UInt) -> Bool {
        captured == current
    }

    static func shouldAttemptRecovery(
        captured: UInt,
        current: UInt,
        didAlreadyRetry: Bool,
        error: Error
    ) -> Bool {
        shouldCommit(captured: captured, current: current)
            && GrokSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: didAlreadyRetry,
                error: error
            )
    }
}

enum GrokSessionRecoveryPolicy {
    static func isRecoverableSessionFailure(_ error: Error) -> Bool {
        guard let serviceError = error as? AIUsageServiceError else {
            return false
        }

        switch serviceError {
        case .wafBlocked:
            return true
        case .httpStatus(_, let statusCode):
            return statusCode == 401
        case .invalidPayload, .invalidResponse, .missingValue:
            return false
        }
    }

    static func shouldAttemptRecovery(
        didAlreadyRetry: Bool,
        error: Error
    ) -> Bool {
        !didAlreadyRetry && isRecoverableSessionFailure(error)
    }

    /// After one restore + retry, a still-recoverable WAF/401 means the
    /// stored credential is no longer a working browser session.
    static func presentationErrorAfterExhaustedRecovery(_ error: Error) -> Error {
        guard isRecoverableSessionFailure(error) else {
            return error
        }

        if let serviceError = error as? AIUsageServiceError,
           case .httpStatus(_, 401) = serviceError {
            return serviceError
        }

        return AIUsageServiceError.httpStatus("Grok", 401)
    }
}

enum GrokRedirectPolicy {
    static func requestAfterRedirect(_ request: URLRequest) -> URLRequest? {
        guard let host = request.url?.host, !host.isEmpty else {
            return nil
        }

        guard WebSessionProvider.matchesGrokProductHost(host) else {
            var stripped = request
            stripped.setValue(nil, forHTTPHeaderField: "Cookie")
            return stripped
        }

        return request
    }
}

final class GrokURLSessionRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = GrokURLSessionRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(GrokRedirectPolicy.requestAfterRedirect(request))
    }
}
