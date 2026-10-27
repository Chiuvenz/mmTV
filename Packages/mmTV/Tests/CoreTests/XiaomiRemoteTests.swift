import Testing
import Input
import Contracts

@Test func xiaomiRemote2671NavigationMapping() {
    let expected: [(UInt32, XiaomiRemoteButton, RemoteEvent)] = [
        (0x52, .up, .up),
        (0x51, .down, .down),
        (0x50, .left, .left),
        (0x4F, .right, .right),
        (0x28, .select, .select),
        (0xF1, .back, .back),
        (0x4A, .home, .home),
    ]
    for (usage, button, event) in expected {
        #expect(XiaomiRemoteProfile.button(usagePage: 0x07, usage: usage) == button)
        #expect(button.remoteEvent == event)
    }
}

@Test func xiaomiRemote2671AuxiliaryButtonsHaveSafeActions() {
    let auxiliary: [(UInt32, XiaomiRemoteButton, RemoteEvent?)] = [
        (0x35, .tv, .home),
        (0x65, .menu, .menu),
        (0x66, .power, nil),
        (0x3E, .voice, .voice),
        (0x80, .volumeUp, .volumeUp),
        (0x81, .volumeDown, .volumeDown),
    ]
    for (usage, button, event) in auxiliary {
        #expect(XiaomiRemoteProfile.button(usagePage: 0x07, usage: usage) == button)
        #expect(button.remoteEvent == event)
    }
    #expect(XiaomiRemoteProfile.button(usagePage: 0x0C, usage: 0xE9) == nil)
    #expect(XiaomiRemoteProfile.button(usagePage: 0x07, usage: 0x00) == nil)
}
