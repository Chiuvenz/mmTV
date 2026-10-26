import Foundation
import Testing
import Contracts
import Core

@Test func entryHealthDistinguishesTargetResourcesAndPermissions() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    let executable = folder.appendingPathComponent("launch")
    try Data("#!/bin/sh\n".utf8).write(to: executable)
    var entry = AppEntry(title: "Game", module: .games, kind: .executable, location: executable.path)
    #expect(EntryHealthChecker.check(entry) == .notExecutable)

    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    #expect(EntryHealthChecker.check(entry) == .ready)

    entry.resourceDirectory = folder.appendingPathComponent("offline").path
    #expect(EntryHealthChecker.check(entry) == .missingResources)
    entry.resourceDirectory = nil
    entry.location = folder.appendingPathComponent("moved.app").path
    #expect(EntryHealthChecker.check(entry, relocatedPath: executable.path) == .relocated(executable.path))
    #expect(EntryHealthChecker.check(entry) == .missingTarget)
}
