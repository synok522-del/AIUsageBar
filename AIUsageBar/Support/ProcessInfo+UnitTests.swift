import Foundation

extension ProcessInfo {
    /// True when Xcode launches the app as a unit-test host (`TEST_HOST`).
    var isUnitTestHost: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
