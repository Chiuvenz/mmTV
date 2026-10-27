import Darwin
import Foundation
import IOKit.hid

private let xiaomiVendorID = 0x2717
private let xiaomiRemoteProductID = 0x32B8

private func hex(_ value: UInt32) -> String {
    String(format: "0x%04X", value)
}

private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
private let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: xiaomiVendorID,
    kIOHIDProductIDKey as String: xiaomiRemoteProductID,
]

IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
    let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown remote"
    let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "Unknown transport"
    print("connected product=\(product) transport=\(transport)")
    fflush(stdout)
}, nil)
IOHIDManagerRegisterDeviceRemovalCallback(manager, { _, _, _, _ in
    print("disconnected")
    fflush(stdout)
}, nil)
IOHIDManagerRegisterInputValueCallback(manager, { _, result, _, value in
    guard result == kIOReturnSuccess else { return }
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let integerValue = IOHIDValueGetIntegerValue(value)
    print("page=\(hex(page)) usage=\(hex(usage)) value=\(integerValue)")
    fflush(stdout)
}, nil)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard openResult == kIOReturnSuccess else {
    fputs("Unable to open Xiaomi remote HID device: \(openResult)\n", stderr)
    exit(EXIT_FAILURE)
}

print("Waiting for Xiaomi remote input (VID 0x2717, PID 0x32B8). Press Control-C to stop.")
fflush(stdout)
CFRunLoopRun()
