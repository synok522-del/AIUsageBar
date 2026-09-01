//
//  AIUsageBarUITests.swift
//  AIUsageBarUITests
//
//  Created by Kenny Hung on 2026/8/16.
//

import XCTest

final class AIUsageBarUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
    }

    @MainActor
    func testAppLaunches() throws {
        app.launch()

        let isRunning =
            app.wait(for: .runningForeground, timeout: 5) ||
            app.state == .runningBackground

        XCTAssertTrue(isRunning, "App state was \(app.state.rawValue)")
        XCTAssertTrue(
            app.staticTexts["ui-test-host"].waitForExistence(timeout: 5)
        )
    }
}
