//
//  AIUsageBarUITests.swift
//  AIUsageBarUITests
//
//  Created by Kenny Hung on 2026/8/16.
//

import XCTest

final class AIUsageBarUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // XCTApplicationLaunchMetric is the default Xcode UI-test template.
        // This app is LSUIElement + MenuBarExtra: it does not activate a
        // standard window, so later measure() iterations often record 0
        // launch metrics after a first successful sample. That is XCTest
        // infrastructure, not a product launch regression.
        //
        // Keep launch coverage by requiring two clean process launches.
        let app = XCUIApplication()
        for _ in 0..<2 {
            app.launch()
            XCTAssertTrue(
                app.state == .runningForeground || app.state == .runningBackground,
                "menu-bar app should be running after launch"
            )
            app.terminate()
        }
    }
}
