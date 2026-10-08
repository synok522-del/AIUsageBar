import Foundation
import WebKit

/// Compile-time isolation: bundle metadata cannot turn a validation build into production.
enum AppBuildIdentity {
    static let validationBundleID = "synok522.AIUsageBar.LiveValidation"
    #if LIVE_VALIDATION
    static let isLiveValidation = true
    #else
    static let isLiveValidation = false
    #endif

    static var keychainService: String {
        isLiveValidation ? "com.synok522.AIUsageBar.LiveValidation" : "com.synok522.AIUsageBar"
    }

    static func permitsUpdater(info: [String: Any]) -> Bool {
        !isLiveValidation && !(info["AIUsageBarLiveValidation"] as? Bool ?? false)
            && info["CFBundleIdentifier"] as? String != validationBundleID
    }

    /// All validation WebViews share one process-local store; no production cookie access.
    @MainActor static let websiteDataStore: WKWebsiteDataStore =
        isLiveValidation ? .nonPersistent() : .default()

    static func validateBundle() {
        let bundleID = Bundle.main.bundleIdentifier
        let marker = Bundle.main.object(forInfoDictionaryKey: "AIUsageBarLiveValidation") as? Bool ?? false
        precondition(isLiveValidation ? bundleID == validationBundleID && marker
                     : bundleID != validationBundleID && !marker,
                     "Build flavor and bundle identity disagree")
    }
}
