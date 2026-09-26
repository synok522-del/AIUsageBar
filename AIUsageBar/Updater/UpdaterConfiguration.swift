import CoreFoundation
import Foundation

/// Validates the public updater settings embedded in an app bundle.
/// An updater is deliberately not started until every security-sensitive value
/// is present, including the explicit signed-feed failure expiration choice.
struct UpdaterConfiguration: Equatable {
    let feedURL: URL?
    let publicEDKey: String?
    let signedFeedFailureExpirationInterval: Int?

    var isReady: Bool {
        guard
            let feedURL,
            feedURL.scheme?.lowercased() == "https",
            feedURL.host != nil,
            feedURL.user == nil,
            feedURL.password == nil,
            feedURL.query == nil,
            feedURL.fragment == nil,
            let publicEDKey,
            let publicKeyBytes = Data(base64Encoded: publicEDKey),
            publicKeyBytes.count == 32,
            let signedFeedFailureExpirationInterval,
            signedFeedFailureExpirationInterval >= 0
        else {
            return false
        }

        return true
    }

    init(infoDictionary: [String: Any]) {
        let candidateFeedURL: URL?
        if let value = infoDictionary["SUFeedURL"] as? String {
            candidateFeedURL = URL(string: value)
        } else {
            candidateFeedURL = nil
        }

        let candidatePublicEDKey = infoDictionary["SUPublicEDKey"] as? String

        let candidateExpirationInterval: Int?
        if let number = infoDictionary["SUSignedFeedFailureExpirationInterval"] as? NSNumber,
           CFGetTypeID(number) != CFBooleanGetTypeID(),
           number.doubleValue.isFinite,
           number.doubleValue >= 0,
           number.doubleValue.rounded(.towardZero) == number.doubleValue,
           number.doubleValue <= Double(Int.max) {
            candidateExpirationInterval = number.intValue
        } else {
            candidateExpirationInterval = nil
        }

        let policyIsValid = Self.isEnabled("SURequireSignedFeed", in: infoDictionary)
            && Self.isEnabled("SUVerifyUpdateBeforeExtraction", in: infoDictionary)
            && Self.isEnabled("SUEnableAutomaticChecks", in: infoDictionary)
            && Self.isDisabled("SUAutomaticallyUpdate", in: infoDictionary)
            && Self.isDisabled("SUAllowsAutomaticUpdates", in: infoDictionary)
            && Self.isDisabled("SUEnableJavaScript", in: infoDictionary)
            && Self.isDisabled("SUEnableSystemProfiling", in: infoDictionary)

        // A malformed or partial updater plist must never start Sparkle.
        feedURL = policyIsValid ? candidateFeedURL : nil
        publicEDKey = policyIsValid ? candidatePublicEDKey : nil
        signedFeedFailureExpirationInterval = policyIsValid ? candidateExpirationInterval : nil
    }

    private static func isEnabled(_ key: String, in infoDictionary: [String: Any]) -> Bool {
        (infoDictionary[key] as? NSNumber)?.boolValue == true
    }

    private static func isDisabled(_ key: String, in infoDictionary: [String: Any]) -> Bool {
        (infoDictionary[key] as? NSNumber)?.boolValue == false
    }
}
