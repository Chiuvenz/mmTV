import Foundation
import Testing
import Contracts
import Core

@Test func configurationRoundTripAndPreviousBackup() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    #expect(try store.load().entries.isEmpty)
    var config = AppConfiguration()
    config.entries = [.init(title: "Example", module: .games, location: "/Applications/Example.app")]
    try store.save(config)
    #expect(try store.load() == config)
    let first = try Data(contentsOf: store.url)
    config.disabledModules = [.assistant]
    try store.save(config)
    #expect(try Data(contentsOf: store.url.appendingPathExtension("previous")) == first)
    #expect(try store.load().disabledModules == [.assistant])
}
@Test func newerConfigurationIsRejectedAndPreserved() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("config.json")
    let data = Data("{\"schemaVersion\":999}".utf8)
    try data.write(to: url)
    #expect(throws: LaunchError.unsupportedVersion(999)) { try ConfigurationStore(url: url).load() }
    #expect(try Data(contentsOf: url) == data)
}
@Test func pathsAndModulesMustBeExplicit() throws {
    #expect(throws: (any Error).self) { try EntryValidation.validate(.init(title: "", module: .games, location: "/A.app")) }
    #expect(throws: (any Error).self) { try EntryValidation.validate(.init(title: "bad", module: .games, location: "$(open /A.app)")) }
    #expect(throws: (any Error).self) { try EntryValidation.validate(.init(title: "bad", module: .music, location: "/A.app")) }
    try EntryValidation.validate(.init(title: "Launcher", module: .games, kind: .executable, location: "/path/with spaces/launch", arguments: ["--rom", "file with spaces.z64"]))
}

@Test func duplicateEntryIDsCannotOverwriteGoodConfiguration() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    var config = AppConfiguration()
    let entry = AppEntry(title: "One", module: .games, location: "/One.app")
    config.entries = [entry]
    try store.save(config)
    let original = try Data(contentsOf: store.url)
    config.entries.append(entry)
    #expect(throws: (any Error).self) { try store.save(config) }
    #expect(try Data(contentsOf: store.url) == original)
}
