import Foundation
import Contracts

public enum EntryHealthChecker {
    public static func check(
        _ entry: AppEntry,
        fileManager: FileManager = .default,
        relocatedPath: String? = nil
    ) -> EntryHealth {
        if let resources = entry.resourceDirectory, !resources.isEmpty,
           !fileManager.fileExists(atPath: resources) {
            return .missingResources
        }
        if fileManager.fileExists(atPath: entry.location) {
            if entry.kind == .executable && !fileManager.isExecutableFile(atPath: entry.location) {
                return .notExecutable
            }
            return .ready
        }
        if let relocatedPath, fileManager.fileExists(atPath: relocatedPath) {
            return .relocated(relocatedPath)
        }
        return .missingTarget
    }
}
