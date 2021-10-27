//
//  HTScreenManager.swift
//  Hammertime
//
//  Created by Chris Jones on 24/10/2021.
//

import Foundation
import Cocoa
import OSLog

/// Stores tables of gamma values for a screen.
struct HTGammaTable {
    var id: CGDirectDisplayID
    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]
}

/// This is an unpleasant hack for determining whether something cares about the cached initial gammas for a screen, or the gammas we have applied
enum HTGammaType: String {
    case original
    case current
}

/// This function is called by CoreGraphics when the configuration of any screen changes
private func screenReconfigurationCallback(screenID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, userInfo: UnsafeMutableRawPointer?) {
    HTScreenManager.shared.screenDidReconfigure(screenID, withFlags: flags)
}

@objc
class HTScreenManager: NSObject {
    static var shared = HTScreenManager()

    var log: Logger
    var originalGammasCache: [HTGammaTable]
    var currentGammasCache: [HTGammaTable]

    // MARK: - Initialisers
    override init() {
        originalGammasCache = []
        currentGammasCache = []
        log = Logger(subsystem: "org.hammerspoon.Hammertime", category: "HTScreenManager")

        super.init()
        log.debug("Initialising")
        start()
    }

    // MARK: - Lifecycle management
    func start() {
        log.debug("Starting")
        cacheAllInitialScreenGammas()
        CGDisplayRegisterReconfigurationCallback(screenReconfigurationCallback, nil)
    }

    func stop() {
        log.debug("Stopping")
        CGDisplayRemoveReconfigurationCallback(screenReconfigurationCallback, nil)
        restoreAllInitialGammas()
    }

    // MARK: - Callbacks
    func screenDidReconfigure(_ screenID: CGDirectDisplayID, withFlags flags:CGDisplayChangeSummaryFlags) {
        if (flags.contains(.addFlag)) {
            // A new screen appeared, cache its gamma
            log.debug("Screen added: \(screenID)")
            cacheInitialScreenGamma(screenID)
        } else if (flags.contains(.removeFlag)) {
            // A screen was removed. Remove its cached gamma values
            log.debug("Screen removed: \(screenID)")
            removeCachedGammasForScreen(screenID, cacheType: .original)
            removeCachedGammasForScreen(screenID, cacheType: .current)
        } else if (flags.contains(.disabledFlag)) {
            // A screen was disabled. Remove any cached gamma values we applied to it
            log.debug("Screen disabled: \(screenID)")
            removeCachedGammasForScreen(screenID, cacheType: .current)
        } else if (flags.contains(.enabledFlag) || flags.contains(.beginConfigurationFlag)) {
            // NOOP
            log.debug("Screen enabled or began configuration: \(screenID)")
        } else {
            log.debug("Unknown screen configuration event on: \(screenID): \(flags.rawValue)")
            // Some kind of display reconfiguration occurred, but it didn't involve any hardware being added/removed
            // We'll re-apply our current gammas if we have them.
            // We also have to wait a few seconds to do this, so the display reconfiguration can complete.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                HTScreenManager.shared.reapplyCachedGamma(screenID)
            }
        }
    }

    // MARK: - Internal API
    /// Store all of the current gamma tables for all attached screens
    private func cacheAllInitialScreenGammas() {
        log.debug("Caching all initial screen gammas")
        // Get the number of screens
        var numScreens = CGDisplayCount()
        CGGetActiveDisplayList(0, nil, &numScreens)

        // Fetch the gamma for each screen
        var screens: [CGDirectDisplayID] = Array(repeating: 0, count: Int(numScreens))
        CGGetActiveDisplayList(numScreens, &screens, nil)

        for screen in screens {
            cacheInitialScreenGamma(screen)
        }
    }

    /// Store the current gamma tables for a single screen
    private func cacheInitialScreenGamma(_ screenID: CGDirectDisplayID) {
        log.debug("Caching screen gamma for: \(screenID)")
        let capacity: UInt32 = CGDisplayGammaTableCapacity(screenID)
        var count: UInt32 = 0

        var redTable   = [CGGammaValue](repeating: 0, count: Int(capacity))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(capacity))
        var blueTable  = [CGGammaValue](repeating: 0, count: Int(capacity))

        let result = CGGetDisplayTransferByTable(screenID, capacity, &redTable, &greenTable, &blueTable, &count)
        if (result != .success) {
            // FIXME: Log an error
            return
        }

        cacheGammasForScreen(HTGammaTable(id: screenID, red: redTable, green: greenTable, blue: blueTable), cacheType: .original)
    }

    /// Remove a cached gamma table for a single screen
    private func removeCachedGammasForScreen(_ screenID: CGDirectDisplayID, cacheType gammaType:HTGammaType) {
        log.debug("Removing cached gamma for: \(screenID) type: \(gammaType.rawValue)")
        switch (gammaType) {
        case .original:
            originalGammasCache = originalGammasCache.filter { oldTable in
                oldTable.id != screenID
            }
        case .current:
            currentGammasCache = currentGammasCache.filter { oldTable in
                oldTable.id != screenID
            }
        }

    }

    /// Re-apply a gamma table we have previously set, if it exists in our cache
    private func reapplyCachedGamma(_ screenID: CGDirectDisplayID) {
        log.debug("Reapplying cached gamma for: \(screenID)")
        if let gamma = getCachedGammasForScreen(screenID, cacheType: .current) {
            let result = CGSetDisplayTransferByTable(screenID, UInt32(gamma.red.count), gamma.red, gamma.green, gamma.blue)
            if (result != .success) {
                // FIXME: Log error here
            }
        }
    }

    // MARK: - External API

    // MARK: Static functions
    /// Get the main screen (i.e. the screen containing the currently focused window)
    /// - Returns: An HTScreen object, or nil if there is no main screen
    static func mainScreen() -> HTScreen? {
        if let screen = NSScreen.main {
            return HTScreen(screen)
        } else {
            return nil
        }
    }

    /// Get the primary screen (ie the screen whose top left is at (0,0) in the global screen coordinates space).
    /// - Returns: An HTScreen object
    static func primaryScreen() -> HTScreen {
        return allScreens().first!
    }

    /// Get all screens currently available
    /// - Returns: An array of HTScreen objects
    static func allScreens() -> [HTScreen] {
        return NSScreen.screens.map { HTScreen($0) }
    }

    // MARK: Instance methods
    /// Get a gamma table for a screen
    /// - Parameters:
    ///   - screenID: The CGDirectDisplayID of the desired screen
    ///   - gammaType: An HTGammaType value indicating if the initially cached gamma table is required, or a gamma table set by us
    /// - Returns: An optional HTGammaTable containing the gamma values
    func getCachedGammasForScreen(_ screenID: CGDirectDisplayID, cacheType gammaType:HTGammaType) -> HTGammaTable? {
        let gammas: [HTGammaTable]
        switch (gammaType) {
        case .original:
            gammas = originalGammasCache
        case .current:
            gammas = currentGammasCache
        }
        return gammas.first { table in
            table.id == Int(screenID)
        }
    }

    /// Cache a gamma table for a screen
    /// - Parameters:
    ///   - table: An HTGammaTable containing the gamma values to be cached
    ///   - gammaType: An HTGammaType value indicating if the initially cached gamma table is required, or a gamma table set by us
    func cacheGammasForScreen(_ table: HTGammaTable, cacheType gammaType:HTGammaType) {
        removeCachedGammasForScreen(table.id, cacheType: gammaType)
        switch (gammaType) {
        case .original:
            originalGammasCache.append(table)
        case .current:
            currentGammasCache.append(table)
        }
    }

    /// Reset all screens to OS provided gamma tables, removing any gamma tables we have set, and their cache
    func restoreAllInitialGammas() {
        CGDisplayRestoreColorSyncSettings()
        currentGammasCache.removeAll()
    }

    /// Reset all screens to OS configuration. This will undo any changes made to HTScreen objects with `permanent` arguments set to false
    func restorePermanentDisplayConfiguration() {
        CGRestorePermanentDisplayConfiguration()
    }

    // MARK: - Private CoreGraphics API use beyond this point

    /// Forces displays to use greyscale
    var forceToGrey: Bool {
        get { CGDisplayUsesForceToGray() }
        set { CGDisplayForceToGray(newValue) }
    }
    /// Forces displays to use inverted colors
    var invertedPolarity: Bool {
        get { CGDisplayUsesInvertedPolarity() }
        set { CGDisplaySetInvertedPolarity(newValue) }
    }
}
