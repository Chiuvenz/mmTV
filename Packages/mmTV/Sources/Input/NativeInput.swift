import AppKit
import GameController
import Carbon
import Contracts

@MainActor public final class NativeInput {
    public var onEvent: ((RemoteEvent) -> Void)?
    public var onHome: (() -> Void)?
    public var shouldHandleInput: (() -> Bool)?
    public var onXiaomiRemoteConnectionChanged: ((Bool) -> Void)?
    public var onRemoteInputAccessChanged: ((RemoteInputAccessStatus) -> Void)?
    public private(set) var globalHomeAvailable = false
    public private(set) var xiaomiRemoteConnected = false
    public private(set) var remoteInputAccess = RemoteInputAccessStatus.unknown
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var held: RemoteEvent?
    private var repeatTimer: Timer?
    private var heldSince: Date?
    private let xiaomiRemote = XiaomiRemoteHID()
    private var xiaomiHeld: RemoteEvent?
    private var lastLocalEvent: (event: RemoteEvent, date: Date)?
    private var lastXiaomiEvent: (event: RemoteEvent, date: Date)?
    public init() {}
    public func start() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.shouldHandleInput?() ?? true else { return false }
                if event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                    if NSApp.keyWindow?.firstResponder is NSTextView { return false }
                    let mapped: RemoteEvent? = switch event.keyCode {
                    case 123: .left
                    case 124: .right
                    case 125: .down
                    case 126: .up
                    case 36, 76: .select
                    case 53: .back
                    case 115: .home
                    default: nil
                    }
                    if let mapped {
                        if self.shouldSuppressLocalEvent(mapped) { return true }
                        self.lastLocalEvent = (mapped, .now)
                        self.onEvent?(mapped)
                        return true
                    }
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
        xiaomiRemote.onButton = { [weak self] button, pressed in
            self?.handleXiaomiButton(button, pressed: pressed)
        }
        xiaomiRemote.onConnectionChanged = { [weak self] connected in
            guard let self else { return }
            self.xiaomiRemoteConnected = connected
            if !connected, self.xiaomiHeld != nil {
                self.xiaomiHeld = nil
                self.setHeld(nil)
            }
            self.onXiaomiRemoteConnectionChanged?(connected)
        }
        refreshRemoteInputAccess()
        xiaomiRemote.start()
        configureControllers()
        registerHomeHotKey()
    }
    @discardableResult public func requestRemoteInputAccess() -> Bool {
        let granted = XiaomiRemoteHID.requestAccess()
        refreshRemoteInputAccess()
        return granted
    }
    public func refreshRemoteInputAccess() {
        remoteInputAccess = XiaomiRemoteHID.accessStatus
        onRemoteInputAccessChanged?(remoteInputAccess)
    }
    public func stop() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; keyMonitor = nil
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
        repeatTimer?.invalidate(); repeatTimer = nil; held = nil
        xiaomiHeld = nil
        xiaomiRemote.stop()
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
    private func handleXiaomiButton(_ button: XiaomiRemoteButton, pressed: Bool) {
        guard let event = button.remoteEvent else { return }
        if !pressed {
            if xiaomiHeld == event {
                xiaomiHeld = nil
                setHeld(nil)
            }
            return
        }

        let recentlyHandledLocally = lastLocalEvent.map {
            $0.event == event && Date.now.timeIntervalSince($0.date) < 0.15
        } ?? false
        lastXiaomiEvent = (event, .now)

        if event == .home {
            if !recentlyHandledLocally { onHome?() }
            return
        }
        guard NSApp.isActive, shouldHandleInput?() ?? true else { return }
        if event.isRepeatable {
            xiaomiHeld = event
            setHeld(event, emitInitial: !recentlyHandledLocally)
        } else if !recentlyHandledLocally {
            onEvent?(event)
        }
    }

    private func shouldSuppressLocalEvent(_ event: RemoteEvent) -> Bool {
        if xiaomiHeld == event { return true }
        return lastXiaomiEvent.map {
            $0.event == event && Date.now.timeIntervalSince($0.date) < 0.15
        } ?? false
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

private extension RemoteEvent {
    var isRepeatable: Bool {
        switch self {
        case .up, .down, .left, .right, .volumeUp, .volumeDown: true
        case .select, .back, .home, .menu, .voice: false
        }
    }
}
