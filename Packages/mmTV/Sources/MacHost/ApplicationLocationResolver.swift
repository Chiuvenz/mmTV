import AppKit
import Foundation
import Contracts

public enum ApplicationLocationResolver {
    /// Resolves an application selected on another Mac by bundle identifier.
    /// Explicit executable paths are never searched or guessed.
    public static func resolvedLocation(for entry: AppEntry) -> String? {
        if FileManager.default.fileExists(atPath: entry.location) { return entry.location }
        guard entry.kind == .application,
              let bundleID = entry.applicationBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.path
    }

    public static func bundleIdentifier(at path: String) -> String? {
        Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier
    }
}
