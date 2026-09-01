import Foundation

extension ProcessInfo {
    /// True when Xcode launches the app as a unit-test host (`TEST_HOST`).
    var isUnitTestHost: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    /// True when UI tests pass the `-ui-testing` launch argument.
    var isUITestingLaunch: Bool {
        arguments.contains("-ui-testing")
    }

    /// True for unit-test host launches and UI-test app launches.
    var isRunningUnderXcodeTests: Bool {
        isUnitTestHost || isUITestingLaunch
    }
}
