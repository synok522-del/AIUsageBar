import Foundation

enum ChatGPTSessionRestorerPhase: Equatable {
    case unknown
    case restoring
    case ready
}

enum ChatGPTSessionRestoreOutcome: Equatable {
    case success
    case failure
    case timeout
    case cancelled
}

struct ChatGPTSessionRestorerGate: Equatable {
    private(set) var generation: UInt = 0
    private(set) var phase: ChatGPTSessionRestorerPhase = .unknown

    mutating func beginRestore() -> UInt {
        phase = .restoring
        return generation
    }

    mutating func complete(
        attemptGeneration: UInt,
        outcome: ChatGPTSessionRestoreOutcome
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

    mutating func reset() {
        generation += 1
        phase = .unknown
    }
}

/// Invalidated synchronously on ChatGPT logout or credential replacement.
struct ChatGPTHTTPAuthGeneration: Equatable {
    private(set) var value: UInt = 0

    mutating func invalidate() {
        value += 1
    }
}

enum ChatGPTHTTPRefreshAuthPolicy {
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
            && ChatGPTSessionRecoveryPolicy.shouldAttemptRecovery(
                didAlreadyRetry: didAlreadyRetry,
                error: error
            )
    }
}

enum ChatGPTSessionRecoveryPolicy {
    static func isRecoverableSessionFailure(_ error: Error) -> Bool {
        guard let serviceError = error as? AIUsageServiceError else {
            return false
        }

        switch serviceError {
        case .httpStatus(_, let statusCode):
            return statusCode == 401 || statusCode == 403
        case .missingValue:
            return true
        case .wafBlocked, .invalidPayload, .invalidResponse:
            return false
        }
    }

    static func shouldAttemptRecovery(
        didAlreadyRetry: Bool,
        error: Error
    ) -> Bool {
        !didAlreadyRetry && isRecoverableSessionFailure(error)
    }

    static func presentationErrorAfterExhaustedRecovery(_ error: Error) -> Error {
        guard isRecoverableSessionFailure(error) else {
            return error
        }

        if let serviceError = error as? AIUsageServiceError,
           case .httpStatus(_, 401) = serviceError {
            return serviceError
        }

        return AIUsageServiceError.httpStatus("ChatGPT", 401)
    }
}

enum ChatGPTSessionContext {
    static func cookieHeader(from cookies: [HTTPCookie]) -> String? {
        let header = WebLoginProvider.chatGPT.credential(from: cookies)?.cookieHeader
        guard let header, !header.isEmpty else {
            return nil
        }
        return header
    }

    static func cookieHeaderForRequest(
        webKitCookies: [HTTPCookie],
        fallbackHeader: String
    ) -> String {
        cookieHeader(from: webKitCookies) ?? fallbackHeader
    }
}
