//
//  HTScreen.swift
//  Hammertime
//
//  Created by Chris Jones on 20/10/2021.
//

import Cocoa

struct HTGammaPoint {
    var red: Float
    var green: Float
    var blue: Float
}

@objc
class HTScreen: NSObject {
    // MARK: - Simple properties
    private static let screenIDKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
    let screen: NSScreen

    // MARK: - Initialiser
    init(_ screen: NSScreen) {
        self.screen = screen
    }

    // MARK: - Computed properties
    /// Numerical ID for this screen. Generated by macOS and not guaranteed to be stable across display reconfigurations or reboots
    var id: CGDirectDisplayID {
        get {
            return screen.deviceDescription[HTScreen.screenIDKey] as? CGDirectDisplayID ?? 0
        }
    }
    /// UUID for this screen. Generated by macOS and not guaranteed to be stable across display reconfigurations or reboots
    var uuid: UUID {
        get {
            return UUID.init(cfUUID: CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue())
        }
    }
    /// Name of the screen. Typically taken from EDID values where available
    var name: String {
        get {
            screen.localizedName
        }
    }
    /// Frame of the screen
    var frame: NSRect {
        get {
            screen.frame
        }
    }
    /// Visible frame of the screen
    var visibleFrame: NSRect {
        get {
            screen.visibleFrame
        }
    }
    /// Background image of the screen
    var backgroundImage: URL? {
        get {
            NSWorkspace.shared.desktopImageURL(for: screen)
        }
        set {
            do {
                if (newValue != nil) {
                    try NSWorkspace.shared.setDesktopImageURL(newValue!, for: screen)
                }
            } catch {
                // FIXME: Do proper logging here
                print("Setting desktop image failed: \(error.localizedDescription)")
            }
        }
    }
    /// Fetch an NSImage snapshot of the whole screen
    func snapshot() -> NSImage? {
        return snapshotForRect(rect: NSMakeRect(0, 0, screen.frame.width, screen.frame.height))
    }

    /// Fetch an NSImage snapshot of a region of the screen
    func snapshotForRect(rect: NSRect) -> NSImage? {
        if let cgImage = CGDisplayCreateImage(id, rect: rect) {
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        } else {
            return nil
        }
    }

    /// Make this screen a mirror of another screen
    /// - Parameters:
    ///   - aScreen: The screen that this screen should copy
    ///   - permanent: If true, screen mirroring is configured permanently. If false, screen mirroring will be forgotten when logging out.
    /// - Returns: True if mirroring was started correctly, otherwise False
    func mirrorOf(_ aScreen: HTScreen, permanent: Bool = false) -> Bool {
        var config: CGDisplayConfigRef?
        var result: CGError

        CGBeginDisplayConfiguration(&config)
        result = CGConfigureDisplayMirrorOfDisplay(config, id, aScreen.id)
        CGCompleteDisplayConfiguration(config, permanent ? CGConfigureOption.permanently : CGConfigureOption.forSession)

        // FIXME: Log errors
        return result == .success
    }

    /// Stops this screen mirroring another screen
    /// - Parameter permanent: If true, screen mirroring is removed permanently. If false, screen mirroring will resume after logging out
    /// - Returns: True if mirroring was stopped correctly, otherwise False
    func mirrorStop(permanent: Bool = false) -> Bool {
        var config: CGDisplayConfigRef?
        var result: CGError

        CGBeginDisplayConfiguration(&config)
        result = CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay)
        CGCompleteDisplayConfiguration(config, permanent ? CGConfigureOption.permanently : CGConfigureOption.forSession)

        // FIXME: Log errors
        return result == .success
    }

    /// Sets the origin of this screen within the global display coordinate space. The origin of the primary display is (0,0). The new origin set here is placed as close as possible to the requested location, without overlapping or leaving a gap between displays. Note that if this screen is part of a mirrored set, the mirroring may be removed
    /// - Parameters:
    ///   - x: The desired X coordinate for the upper-left corner of this screen
    ///   - y: The desired Y coordinate for the upper-left corner of this screen
    /// - Returns: True if the origin was set, otherwise False
    func setOrigin(x: Int32, y: Int32) -> Bool {
        var config: CGDisplayConfigRef?
        var result: CGError

        CGBeginDisplayConfiguration(&config)
        result = CGConfigureDisplayOrigin(config, id, x, y)
        CGCompleteDisplayConfiguration(config, .permanently)

        // FIXME: Log errors
        return result == .success
    }

    /// Get or set the rotation of the screen. Valid values are: 0, 90, 180, 270
    var rotation: Int {
        get {
            Int(CGDisplayRotation(id))
        }
        set {
            var rotation: Int
            switch (newValue) {
            case 0:
                rotation = kIOScaleRotate0
            case 90:
                rotation = kIOScaleRotate90
            case 180:
                rotation = kIOScaleRotate180
            case 270:
                rotation = kIOScaleRotate270
            default:
                return
            }

            let servicePort = id.getIOService()
            if (servicePort != 0) {
                let options = IOOptionBits((kIOFBSetTransform | (rotation) << 16))
                IOServiceRequestProbe(servicePort, options)
            }
        }
    }

    /// Sets this screen as the primary display (i.e. contain the menubar and dock)
    /// - Returns: True if the operation succeded, otherwise false
    func setPrimary() -> Bool {
        if (CGMainDisplayID() == id) {
            // noop, we are already the main display
            return true;
        }

        var config: CGDisplayConfigRef?
        var dErr: CGDisplayErr
        var displayCount: UInt32 = 0

        dErr = CGGetOnlineDisplayList(0, nil, &displayCount)
        if (dErr != .success) {
            // FIXME: Log an error
            return false
        }
        var onlineDisplays: [CGDirectDisplayID] = Array(repeating: 0, count: Int(displayCount))
        dErr = CGGetOnlineDisplayList(displayCount, &onlineDisplays, &displayCount)
        if (dErr != .success) {
            // FIXME: Log an error
            return false
        }

        let deltaX = -CGDisplayBounds(id).minX
        let deltaY = -CGDisplayBounds(id).minY

        dErr = CGBeginDisplayConfiguration(&config)
        if (dErr != .success) {
            // FIXME: Log an error
            return false
        }

        for dID in onlineDisplays {
            if (dID) == 0 {
                continue
            }
            dErr = CGConfigureDisplayOrigin(config,
                                            dID,
                                            Int32(CGDisplayBounds(dID).minX + deltaX),
                                            Int32(CGDisplayBounds(dID).minY + deltaY))
            if (dErr != .success) {
                CGCancelDisplayConfiguration(config)
                // FIXME: Log an error
                return false
            }
        }

        CGCompleteDisplayConfiguration(config, .forSession)
        return true
    }

    func setGamma(whitepoint: HTGammaPoint, blackpoint: HTGammaPoint) -> Bool {
        guard let originalGamma = HTScreenManager.shared.gammaTableForDisplayID(id) else {
            // FIXME: Log error
            return false
        }

        let originalReds   = originalGamma.red
        let originalGreens = originalGamma.green
        let originalBlues  = originalGamma.blue

        let count = originalReds.count

        var redTable   = [CGGammaValue](repeating: 0, count: count)
        var greenTable = [CGGammaValue](repeating: 0, count: count)
        var blueTable  = [CGGammaValue](repeating: 0, count: count)

        for i in 0..<count {
            redTable[i] = blackpoint.red + (whitepoint.red - blackpoint.red) * originalReds[i]
            greenTable[i] = blackpoint.green + (whitepoint.green - blackpoint.green) * originalGreens[i]
            blueTable[i] = blackpoint.blue + (whitepoint.blue - blackpoint.blue) * originalBlues[i]

            HTScreenManager.shared.setGammaTableForDisplay(HTGammaTable(id: id, red: redTable, green: greenTable, blue: blueTable))
        }

        let result = CGSetDisplayTransferByTable(id, UInt32(count), redTable, greenTable, blueTable)
        if (result != .success) {
            // FIXME: Log error
            return false
        }

        return true
    }

    // FIXME: This won't work on Apple Silicon until we figure out how to get DisplayServices{Get,Set}Brightness working
    var brightness: Float {
        get {
            var brightness: Float = 0.0
            DisplayServicesGetBrightness(id, &brightness)
            return brightness
        }
        set {
            DisplayServicesSetBrightness(id, newValue)
        }
    }

    // MARK: - Private CoreGraphics API use beyond this point
    var currentMode: CGSDisplayMode {
        get {
            var modeID: Int32 = 0
            var mode = CGSDisplayMode()

            // Fetch information about the screen mode
            CGSGetCurrentDisplayMode(id, &modeID)
            CGSGetDisplayModeDescriptionOfLength(id, modeID, &mode, Int32(MemoryLayout<CGSDisplayMode>.stride))

            return mode
        }
    }

    /// Fetch all of the available display modes for this screen. Note that not all modes are guaranteed to be valid.
    /// - Returns: An array of CGSDisplayMode structs
    func availableModes() -> [CGSDisplayMode] {
        var info = [CGSDisplayMode]()
        var numModes: Int32 = 0
        CGSGetNumberOfDisplayModes(id, &numModes)

        for index in 0..<numModes {
            var mode = CGSDisplayMode()
            CGSGetDisplayModeDescriptionOfLength(id, index, &mode, Int32(MemoryLayout<CGSDisplayMode>.stride))
            info.append(mode)
        }

        return info
    }

    func setMode(_ mode: CGSDisplayMode) -> Bool {
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        CGSConfigureDisplayMode(config, id, Int32(mode.modeNumber))
        return CGCompleteDisplayConfiguration(config, .permanently) == CGError.success
    }
}
