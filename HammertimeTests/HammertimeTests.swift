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

    // MARK: - HTScreenManager tests
    func testGetMainScreen() throws {
        let mainScreen = HTScreenManager.mainScreen()

        XCTAssertNotNil(mainScreen)
        XCTAssertNotEqual(mainScreen?.id, 0)
        XCTAssertNotEqual(mainScreen?.name, "")
        XCTAssertTrue([0, 90, 180, 270].contains(mainScreen?.rotation))
    }

    func testEqualityOverride() throws {
        XCTAssertEqual(HTScreenManager.mainScreen(), HTScreenManager.mainScreen())
    }

    func testAllScreens() throws {
        let allScreens = HTScreenManager.allScreens()

        XCTAssertGreaterThan(allScreens.count, 0)
        XCTAssertTrue(allScreens.contains(HTScreenManager.mainScreen()!))
    }

    func testPrivateAccessibilities() throws {
        let manager = HTScreenManager.shared

        let forceToGray = !manager.forceToGrey
        manager.forceToGrey = forceToGray
        XCTAssertEqual(forceToGray, manager.forceToGrey)
        manager.forceToGrey = !forceToGray

        let invertedPolarity = !manager.invertedPolarity
        manager.invertedPolarity = invertedPolarity
        XCTAssertEqual(invertedPolarity, manager.invertedPolarity)
        manager.invertedPolarity = !invertedPolarity
    }

    // MARK: - HTScreen tests
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
        XCTAssertNotNil(mainScreen?.snapshot())
        XCTAssertNotNil(mainScreen?.snapshotForRect(rect:mainScreen!.frame))
        XCTAssertNil(mainScreen?.snapshotForRect(rect:NSZeroRect))
    }
}
