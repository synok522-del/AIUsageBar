import Foundation
import Testing
@testable import AIUsageBar

struct UpdaterConfigurationTests {
    private var validInfo: [String: Any] {
        [
            "SUFeedURL": "https://example.com/appcast.xml",
            "SUPublicEDKey": Data(repeating: 0, count: 32).base64EncodedString(),
            "SUSignedFeedFailureExpirationInterval": 0,
            "SURequireSignedFeed": true,
            "SUVerifyUpdateBeforeExtraction": true,
            "SUEnableAutomaticChecks": true,
            "SUAutomaticallyUpdate": false,
            "SUAllowsAutomaticUpdates": false,
            "SUEnableJavaScript": false,
            "SUEnableSystemProfiling": false
        ]
    }

    @Test("A fully specified signed-feed policy enables the updater")
    func fullyConfiguredPolicyIsAccepted() {
        #expect(UpdaterConfiguration(infoDictionary: validInfo).isReady)
    }

    @Test("The expiration interval must be an explicit production decision")
    func missingExpirationIntervalDisablesUpdater() {
        var info = validInfo
        info.removeValue(forKey: "SUSignedFeedFailureExpirationInterval")

        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }

    @Test("HTTP feeds and malformed EdDSA public keys are rejected")
    func invalidTransportAndKeyAreRejected() {
        var info = validInfo
        info["SUFeedURL"] = "http://example.com/appcast.xml"
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)

        info = validInfo
        info["SUPublicEDKey"] = "placeholder"
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }

    @Test("Automatic installation and unsigned-feed fallback settings are rejected")
    func unsafeUpdaterSettingsAreRejected() {
        var info = validInfo
        info["SUAllowsAutomaticUpdates"] = true
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)

        info = validInfo
        info["SUVerifyUpdateBeforeExtraction"] = false
        #expect(!UpdaterConfiguration(infoDictionary: info).isReady)
    }
}
