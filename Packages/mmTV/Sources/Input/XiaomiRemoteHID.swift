import Foundation
import IOKit.hid
import Contracts

public enum XiaomiRemoteButton: Equatable, Hashable, Sendable {
    case up, down, left, right
    case select, back, home
    case tv, menu, power, voice, volumeUp, volumeDown

    public var remoteEvent: RemoteEvent? {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .select: .select
        case .back: .back
        case .home, .tv: .home
        case .menu: .menu
        case .voice: .voice
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case .power: nil
        }
    }
}

public enum XiaomiRemoteProfile {
    public static let vendorID = 0x2717
    public static let productID = 0x32B8
    public static let productName = "小米蓝牙语音遥控器"

    public static func button(usagePage: UInt32, usage: UInt32) -> XiaomiRemoteButton? {
        guard usagePage == 0x07 else { return nil }
        return switch usage {
        case 0x52: .up
        case 0x51: .down
        case 0x50: .left
        case 0x4F: .right
        case 0x28: .select
        case 0xF1: .back
        case 0x4A: .home
        case 0x35: .tv
        case 0x65: .menu
        case 0x66: .power
        case 0x3E: .voice
        case 0x80: .volumeUp
        case 0x81: .volumeDown
        default: nil
        }
    }
}

public enum RemoteInputAccessStatus: String, Sendable {
    case granted, denied, unknown

    public var title: String {
        switch self {
        case .granted: "已授权"
        case .denied: "未授权"
        case .unknown: "待授权"
        }
    }
}

private func xiaomiDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let instance = Unmanaged<XiaomiRemoteHID>.fromOpaque(context).takeUnretainedValue()
    let transferredDevice = UnsafeTransfer(value: device)
    MainActor.assumeIsolated {
        instance.deviceMatched(transferredDevice.value, result: result)
    }
}

private func xiaomiDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let instance = Unmanaged<XiaomiRemoteHID>.fromOpaque(context).takeUnretainedValue()
    let transferredDevice = UnsafeTransfer(value: device)
    MainActor.assumeIsolated {
        instance.deviceRemoved(transferredDevice.value, result: result)
    }
}

private func xiaomiValueReceived(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else { return }
    let instance = Unmanaged<XiaomiRemoteHID>.fromOpaque(context).takeUnretainedValue()
    let transferredValue = UnsafeTransfer(value: value)
    MainActor.assumeIsolated {
        instance.valueReceived(transferredValue.value, result: result)
    }
}

private struct UnsafeTransfer<Value>: @unchecked Sendable {
    let value: Value
}

@MainActor final class XiaomiRemoteHID {
    var onButton: ((XiaomiRemoteButton, Bool) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private var manager: IOHIDManager?
    private var matchedDevice: IOHIDDevice?
    private var pressedButtons: Set<XiaomiRemoteButton> = []
    private let openOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    static var accessStatus: RemoteInputAccessStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .unknown
        }
    }

    static func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func start() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, openOptions)
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: XiaomiRemoteProfile.vendorID,
            kIOHIDProductIDKey: XiaomiRemoteProfile.productID,
        ] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, xiaomiDeviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, xiaomiDeviceRemoved, context)
        IOHIDManagerRegisterInputValueCallback(manager, xiaomiValueReceived, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        if IOHIDManagerOpen(manager, openOptions) != kIOReturnSuccess {
            stop()
        }
    }

    func stop() {
        releasePressedButtons()
        matchedDevice = nil
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, openOptions)
        self.manager = nil
        onConnectionChanged?(false)
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice, result: IOReturn) {
        guard result == kIOReturnSuccess, matchedDevice == nil else { return }
        matchedDevice = device
        onConnectionChanged?(true)
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice, result: IOReturn) {
        guard result == kIOReturnSuccess, device == matchedDevice else { return }
        releasePressedButtons()
        matchedDevice = nil
        onConnectionChanged?(false)
    }

    fileprivate func valueReceived(_ value: IOHIDValue, result: IOReturn) {
        guard result == kIOReturnSuccess, let matchedDevice else { return }
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetDevice(element) == matchedDevice,
              let button = XiaomiRemoteProfile.button(
                usagePage: IOHIDElementGetUsagePage(element),
                usage: IOHIDElementGetUsage(element)
              ) else { return }
        let isPressed = IOHIDValueGetIntegerValue(value) != 0
        if isPressed {
            guard pressedButtons.insert(button).inserted else { return }
        } else {
            guard pressedButtons.remove(button) != nil else { return }
        }
        onButton?(button, isPressed)
    }

    private func releasePressedButtons() {
        let pressed = pressedButtons
        pressedButtons.removeAll()
        pressed.forEach { onButton?($0, false) }
    }
}
