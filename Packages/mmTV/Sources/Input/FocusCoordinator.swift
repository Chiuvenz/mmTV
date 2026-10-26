import Foundation
import Contracts

public struct GridFocus: Equatable, Sendable {
    public private(set) var index: Int
    public init(index: Int = 0) { self.index = max(0, index) }
    public mutating func select(_ index: Int, count: Int) { self.index = min(max(0, index), max(0, count - 1)) }
    public mutating func move(_ event: RemoteEvent, count: Int, columns: Int) {
        guard count > 0, columns > 0 else { index = 0; return }
        index = min(index, count - 1)
        switch event {
        case .left: if index % columns > 0 { index -= 1 }
        case .right: if index % columns < columns - 1 && index + 1 < count { index += 1 }
        case .up: if index >= columns { index -= columns }
        case .down: if index + columns < count { index += columns }
        default: break
        }
    }
}
