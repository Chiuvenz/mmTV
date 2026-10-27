import Testing
@testable import Input
import Contracts

@Test func keyboardRemoteMappingCoversInjectedRemoteKeys() {
    let expected: [(UInt16, RemoteEvent)] = [
        (126, .up),
        (125, .down),
        (123, .left),
        (124, .right),
        (36, .select),
        (76, .select),
        (53, .back),
        (115, .home),
        (KeyboardRemoteMapping.menuKeyCode, .menu),
    ]
    for (keyCode, event) in expected {
        #expect(KeyboardRemoteMapping.event(forKeyCode: keyCode) == event)
    }
    #expect(KeyboardRemoteMapping.event(forKeyCode: 0) == nil)
    #expect(KeyboardRemoteMapping.menuKeyCode == 120)
}
