//
//  CGDirectDisplayID.swift
//  Hammertime
//
//  Created by Chris Jones on 22/10/2021.
//

import Foundation
import Cocoa

// Taken from: https://github.com/dgurkaynak/Penc/blob/514cd28168c1f138846e8c092e49e720b39045d9/Penc/extensions/NSScreenExtension.swift
// Used under MIT license:
//  MIT License
//
//  Copyright (c) 2017 Deniz Gurkaynak
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
extension CGDirectDisplayID {
    func getIOService() -> io_service_t {
        var serialPortIterator = io_iterator_t()
        var ioServ: io_service_t = 0

        let matching = IOServiceMatching("IODisplayConnect")

        let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &serialPortIterator)
        if KERN_SUCCESS == kernResult && serialPortIterator != 0 {
            ioServ = IOIteratorNext(serialPortIterator)

            while ioServ != 0 {
                let info = IODisplayCreateInfoDictionary(ioServ, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary as! [String: AnyObject]
                let venderID = info[kDisplayVendorID] as? UInt32
                let productID = info[kDisplayProductID] as? UInt32
                let serialNumber = info[kDisplaySerialNumber] as? UInt32 ?? 0

                if CGDisplayVendorNumber(self) == venderID &&
                    CGDisplayModelNumber(self) == productID &&
                    CGDisplaySerialNumber(self) == serialNumber {
                    break
                }

                ioServ = IOIteratorNext(serialPortIterator)
            }

            IOObjectRelease(serialPortIterator)
        }

        return ioServ
    }
}
