import AppKit
import Contracts
import Core
import Foundation

public struct EntryAvailabilitySnapshot: Equatable, Sendable {
    public let entryID: UUID
    public let resolvedLocation: String?
    public let health: EntryHealth

    public init(entryID: UUID, resolvedLocation: String?, health: EntryHealth) {
        self.entryID = entryID
        self.resolvedLocation = resolvedLocation
        self.health = health
    }
}

/// Performs volume and bundle checks away from the MainActor, then hands immutable
/// snapshots to the UI. Views never touch the file system while rendering.
public actor EntryAvailabilityService {
    public init() {}

    public func inspect(_ entries: [AppEntry]) -> [UUID: EntryAvailabilitySnapshot] {
        Dictionary(uniqueKeysWithValues: entries.map { entry in
            let resolvedLocation = ApplicationLocationResolver.resolvedLocation(for: entry)
            let relocated = resolvedLocation.flatMap { $0 == entry.location ? nil : $0 }
            let health = EntryHealthChecker.check(entry, relocatedPath: relocated)
            return (
                entry.id,
                EntryAvailabilitySnapshot(
                    entryID: entry.id,
                    resolvedLocation: resolvedLocation,
                    health: health
                )
            )
        })
    }
}

/// Converts AppKit icons to Sendable image data on a dedicated actor and caches
/// the result. SwiftUI only reconstructs an NSImage after the asynchronous load.
public actor ApplicationIconLoader {
    public static let shared = ApplicationIconLoader()

    private var cache: [String: Data] = [:]
    private var knownMissing: Set<String> = []

    public init() {}

    public func iconData(for path: String) -> Data? {
        if let cached = cache[path] { return cached }
        if knownMissing.contains(path) { return nil }
        guard FileManager.default.fileExists(atPath: path) else {
            knownMissing.insert(path)
            return nil
        }
        guard let data = NSWorkspace.shared.icon(forFile: path).tiffRepresentation else {
            knownMissing.insert(path)
            return nil
        }
        cache[path] = data
        return data
    }

    public func invalidate(path: String? = nil) {
        if let path {
            cache[path] = nil
            knownMissing.remove(path)
        } else {
            cache.removeAll()
            knownMissing.removeAll()
        }
    }
}
