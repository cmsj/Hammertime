//
//  HTScreenManager.swift
//  Hammertime
//
//  Created by Chris Jones on 24/10/2021.
//

import Foundation
import Cocoa

struct HTGammaTable {
    var id: CGDirectDisplayID
    var red: [Float]
    var green: [Float]
    var blue: [Float]
}

@objc
class HTScreenManager: NSObject {
    static var shared = HTScreenManager()

    var originalGammas: [HTGammaTable]
    var currentGammas: [HTGammaTable]

    override init() {
        originalGammas = []
        currentGammas = []

        super.init()

        storeAllInitialScreenGammas()
    }

    /// Get the main screen (i.e. the screen containing the currently focused window)
    /// - Returns: An HTScreen object, or nil if there is no main screen
    func mainScreen() -> HTScreen? {
        if let screen = NSScreen.main {
            return HTScreen(screen)
        } else {
            return nil
        }
    }

    /// Get all screens currently available
    /// - Returns: An array of HTScreen objects
    func allScreens() -> [HTScreen] {
        return NSScreen.screens.map { HTScreen($0) }
    }

    func storeAllInitialScreenGammas() {
        // Get the number of screens
        var numDisplays = CGDisplayCount()
        CGGetActiveDisplayList(0, nil, &numDisplays)

        // Fetch the gamma for each screen
        var displays: [CGDirectDisplayID] = Array(repeating: 0, count: Int(numDisplays))
        CGGetActiveDisplayList(numDisplays, &displays, nil)

        for display in displays {
            storeInitialScreenGamma(display)
        }
    }

    func storeInitialScreenGamma(_ display: CGDirectDisplayID) {
        let capacity: UInt32 = CGDisplayGammaTableCapacity(display)
        var count: UInt32 = 0

        var redTable   = [CGGammaValue](repeating: 0, count: Int(capacity))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(capacity))
        var blueTable  = [CGGammaValue](repeating: 0, count: Int(capacity))

        let result = CGGetDisplayTransferByTable(display, capacity, &redTable, &greenTable, &blueTable, &count)
        if (result != .success) {
            // FIXME: Log an error
            return
        }

        var red   = [Float](repeating: 0, count: Int(capacity))
        var green = [Float](repeating: 0, count: Int(capacity))
        var blue  = [Float](repeating: 0, count: Int(capacity))

        for i in 0..<Int(count) {
            red.insert(redTable[i], at: i)
            green.insert(greenTable[i], at: i)
            blue.insert(blueTable[i], at: i)
        }

        originalGammas.append(HTGammaTable(id: display, red: red, green: green, blue: blue))
    }

    func gammaTableForDisplayID(_ display: CGDirectDisplayID) -> HTGammaTable? {
        return originalGammas.first { table in
            table.id == Int(display)
        }
    }

    func setGammaTableForDisplay(_ table: HTGammaTable) {
        var filteredGammas = originalGammas.filter { oldTable in
            oldTable.id != table.id
        }
        filteredGammas.append(table)
        originalGammas = filteredGammas
    }
}
