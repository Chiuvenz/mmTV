import AppKit
import GameController
import Carbon
import Contracts

@MainActor public final class NativeInput {
    public var onEvent: ((RemoteEvent) -> Void)?
    public var onHome: (() -> Void)?
    public var shouldHandleInput: (() -> Bool)?
    public private(set) var globalHomeAvailable = false
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var held: RemoteEvent?
    private var repeatTimer: Timer?
    private var heldSince: Date?

    public init() {}

    public func start() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.shouldHandleInput?() ?? true else { return false }
                if event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                    if NSApp.keyWindow?.firstResponder is NSTextView { return false }
                    guard let mapped = KeyboardRemoteMapping.event(forKeyCode: event.keyCode) else {
                        return false
                    }
                    if mapped == .home {
                        self.onHome?()
                        return true
                    }
                    self.onEvent?(mapped)
                    return true
                }
                return false
            }
            return consumed ? nil : event
        }
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureControllers() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setHeld(nil) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setHeld(nil) }
        })
        configureControllers()
        registerHomeHotKey()
    }

    public func stop() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; keyMonitor = nil
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
        repeatTimer?.invalidate(); repeatTimer = nil; held = nil
        if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }; hotKeyHandler = nil
    }

    private func registerHomeHotKey() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let instance = Unmanaged<NativeInput>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in instance.onHome?() }
            return noErr
        }, 1, &type, pointer, &hotKeyHandler)
        guard result == noErr else { return }
        let id = EventHotKeyID(signature: 0x4D4D5456, id: 1)
        globalHomeAvailable = RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    private func configureControllers() {
        for controller in GCController.controllers() {
            guard let gamepad = controller.extendedGamepad else { continue }
            gamepad.dpad.valueChangedHandler = { [weak self] _, x, y in
                let direction: RemoteEvent? = if y > 0.5 { .up } else if y < -0.5 { .down } else if x < -0.5 { .left } else if x > 0.5 { .right } else { nil }
                Task { @MainActor in self?.setHeld(direction) }
            }
            gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor in if NSApp.isActive { self?.onEvent?(.select) } }
            }
            gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor in if NSApp.isActive { self?.onEvent?(.back) } }
            }
        }
    }

    private func setHeld(_ direction: RemoteEvent?, emitInitial: Bool = true) {
        guard held != direction else { return }
        repeatTimer?.invalidate(); repeatTimer = nil
        held = direction; heldSince = Date()
        guard let direction, NSApp.isActive else { return }
        if emitInitial { onEvent?(direction) }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, NSApp.isActive, self.held == direction,
                      let since = self.heldSince, Date().timeIntervalSince(since) > 0.32 else { return }
                self.onEvent?(direction)
            }
        }
    }
}

/// Keyboard events injected by mmTV Remote (and physical keyboards) into mmTV focus routing.
public enum KeyboardRemoteMapping {
    public static let menuKeyCode: UInt16 = 120 // F2

    public static func event(forKeyCode keyCode: UInt16) -> RemoteEvent? {
        switch keyCode {
        case 123: .left
        case 124: .right
        case 125: .down
        case 126: .up
        case 36, 76: .select
        case 53: .back
        case 115: .home
        case menuKeyCode: .menu
        default: nil
        }
    }
}
