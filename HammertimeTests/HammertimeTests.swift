//
//  HammertimeTests.swift
//  HammertimeTests
//
//  Created by Chris Jones on 20/10/2021.
//

import XCTest
@testable import Hammertime

class HammertimeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetMainScreen() throws {
        let mainScreen = HTScreenManager.mainScreen()

        XCTAssertNotNil(mainScreen)
        XCTAssertNotEqual(mainScreen?.id, 0)
        XCTAssertNotEqual(mainScreen?.name, "")
        XCTAssertTrue([0, 90, 180, 270].contains(mainScreen?.rotation))
    }

    func testBrightness() throws {
        let mainScreen = HTScreenManager.mainScreen()

        let origBrightness = mainScreen?.brightness

        mainScreen?.brightness = 1.0
        XCTAssertEqual(mainScreen?.brightness, 1.0)

        mainScreen?.brightness = 0.0
        XCTAssertEqual(mainScreen?.brightness, 0.0)

        mainScreen?.brightness = origBrightness!
    }

    func testSnapshot() throws {
        let mainScreen = HTScreenManager.mainScreen()

        let snapshot = mainScreen?.snapshot()
        XCTAssertNotNil(snapshot)
    }
}
