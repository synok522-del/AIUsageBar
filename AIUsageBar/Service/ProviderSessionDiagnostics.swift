import Foundation
import OSLog

enum SessionDiagnosticProvider: String, Sendable {
    case chatGPT
    case grok
}

enum SessionDiagnosticStage: String, Sendable {
    case initialRequest
    case webKitCredentialRead
    case credentialReconciliation
    case retryRequest
    case manualLatchReset
    case recoveryLatch
}

enum SessionDiagnosticResponseClass: String, Sendable {
    case success
    case http
    case unauthorized
    case forbidden
    case rateLimited
    case wafHTML
    case network
    case parse
    case localCredentialMismatch
    case other
}

enum SessionDiagnosticFinalClass: String, Sendable {
    case success
    case loginExpired
    case noMatchingWebKitCredential
    case identicalCredential
    case credentialReconciled
    case retryUnauthorized
    case waf
    case forbidden
    case rateLimited
    case network
    case parse
    case localCredentialMismatch
    case recoveryLatched
    case recoveryAttempt
    case otherFailure
    case manualReset
    case noManualResetNeeded
}

/// This event accepts only fixed enums, booleans, and an HTTP status code.
/// Credential material, headers, account identifiers, and response bodies
/// cannot be passed into the production diagnostic formatter.
struct ProviderSessionDiagnosticEvent: Equatable, Sendable {
    let provider: SessionDiagnosticProvider
    let stage: SessionDiagnosticStage
    let httpStatus: Int?
    let storedCredentialPresent: Bool?
    let webKitCredentialPresent: Bool?
    let credentialDiffers: Bool?
    let reconciliationAttempted: Bool?
    let recoveryState: RecoveryState?
    let manualLatchReset: Bool?
    let retryCount: Int
    let responseClass: SessionDiagnosticResponseClass
    let finalClass: SessionDiagnosticFinalClass

    var message: String {
        [
            "provider=\(provider.rawValue)",
            "stage=\(stage.rawValue)",
            "httpStatus=\(httpStatus.map { String($0) } ?? "none")",
            "storedCredentialPresent=\(flag(storedCredentialPresent))",
            "webKitCredentialPresent=\(flag(webKitCredentialPresent))",
            "credentialDiffers=\(flag(credentialDiffers))",
            "reconciliationAttempted=\(flag(reconciliationAttempted))",
            "recoveryState=\(recoveryState?.rawValue ?? "unknown")",
            "manualLatchReset=\(flag(manualLatchReset))",
            "retryCount=\(max(0, retryCount))",
            "responseClass=\(responseClass.rawValue)",
            "finalClass=\(finalClass.rawValue)"
        ].joined(separator: " ")
    }

    private func flag(_ value: Bool?) -> String {
        guard let value else {
            return "unknown"
        }
        return value ? "true" : "false"
    }
}

enum ProviderSessionDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
        category: "ProviderSession"
    )

    static func record(_ event: ProviderSessionDiagnosticEvent) {
        logger.info("\(event.message, privacy: .public)")
    }

    static func responseClass(for error: Error) -> SessionDiagnosticResponseClass {
        if let serviceError = error as? AIUsageServiceError {
            switch serviceError {
            case .httpStatus(_, 401):
                return .unauthorized
            case .httpStatus(_, 403):
                return .forbidden
            case .httpStatus:
                return .http
            case .rateLimited:
                return .rateLimited
            case .wafBlocked:
                return .wafHTML
            case .invalidPayload, .missingValue:
                return .parse
            case .invalidResponse:
                return .network
            case .localCredentialMismatch:
                return .localCredentialMismatch
            }
        }

        if let urlError = error as? URLError, urlError.code != .cancelled {
            return .network
        }
        return .other
    }

    static func httpStatus(for error: Error) -> Int? {
        guard let serviceError = error as? AIUsageServiceError,
              case .httpStatus(_, let status) = serviceError else {
            return nil
        }
        return status
    }
}
