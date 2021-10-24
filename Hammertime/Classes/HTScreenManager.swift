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
    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]
}

private func displayReconfigurationCallback(screenID: CGDirectDisplayID,
                                            flags: CGDisplayChangeSummaryFlags,
                                            userInfo: UnsafeMutableRawPointer?) {
    if (flags.contains(.addFlag)) {
        HTScreenManager.shared.storeInitialScreenGamma(screenID)
    } else if (flags.contains(.removeFlag)) {
        HTScreenManager.shared.removeGammaTableForDisplay(screenID)
        // FIXME: Something something currentGammas?
    } else if (flags.contains(.disabledFlag)) {
        // FIXME: Remove from currentGammas
    } else if (flags.contains(.enabledFlag) || flags.contains(.beginConfigurationFlag)) {
        // NOOP
    } else {
        // Some kind of display reconfiguration occurred, but it didn't involve any hardware being added/removed
        // We'll re-apply our current gammas if we have them.
        // We also have to wait a few seconds to do this, so the display reconfiguration can complete.
        // FIXME:
//                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                    screen_gammaReapply(display);
//                });
    }
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

        start()
    }

    func start() {
        storeAllInitialScreenGammas()
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, nil)
    }

    func stop() {
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, nil)
    }

    /// Get the main screen (i.e. the screen containing the currently focused window)
    /// - Returns: An HTScreen object, or nil if there is no main screen
    static func mainScreen() -> HTScreen? {
        if let screen = NSScreen.main {
            return HTScreen(screen)
        } else {
            return nil
        }
    }

    /// Get all screens currently available
    /// - Returns: An array of HTScreen objects
    static func allScreens() -> [HTScreen] {
        return NSScreen.screens.map { HTScreen($0) }
    }

    func gammaTableForDisplayID(_ display: CGDirectDisplayID) -> HTGammaTable? {
        return originalGammas.first { table in
            table.id == Int(display)
        }
    }

    func setGammaTableForDisplay(_ table: HTGammaTable) {
        removeGammaTableForDisplay(table.id)
        originalGammas.append(table)
    }

    func removeGammaTableForDisplay(_ display: CGDirectDisplayID) {
        originalGammas = originalGammas.filter { oldTable in
            oldTable.id != display
        }
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

        setGammaTableForDisplay(HTGammaTable(id: display, red: redTable, green: greenTable, blue: blueTable))
    }

    func restoreGammas() {
        CGDisplayRestoreColorSyncSettings()
        currentGammas.removeAll()
    }
}
