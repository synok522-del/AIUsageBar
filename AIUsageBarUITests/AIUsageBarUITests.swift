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
        XCTAssertEqual(app.state, .runningForeground)
    }
}
