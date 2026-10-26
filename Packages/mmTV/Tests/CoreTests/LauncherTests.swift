import Foundation
import Testing
import Contracts
import MacHost

@MainActor @Test func executableArgumentsArePassedLiterallyAndProcessIsTracked() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let script = folder.appendingPathComponent("test launcher with spaces")
    let output = folder.appendingPathComponent("arguments.txt")
    let injection = folder.appendingPathComponent("should-not-exist")
    try Data("#!/bin/sh\noutput=\"$1\"\nshift\nprintf '%s\\n' \"$@\" > \"$output\"\nexec /bin/sleep 10\n".utf8).write(to: script)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
    let launcher = MacApplicationLauncher()
    let entry = AppEntry(title: "Test", module: .games, kind: .executable, location: script.path,
                         arguments: [output.path, "file with spaces", "$(touch \(injection.path))"])
    let handle = try await launcher.launch(entry)
    defer { _ = launcher.terminate(handle) }
    let expected = "file with spaces\n$(touch \(injection.path))\n"
    var received: String?
    // Wait for the complete child output, not just file creation. App startup may
    // be delayed by system load; readiness is bounded by a five-second deadline.
    for _ in 0..<250 {
        received = try? String(contentsOf: output, encoding: .utf8)
        if received == expected { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(launcher.activate(handle))
    #expect(received == expected)
    #expect(!FileManager.default.fileExists(atPath: injection.path))
}
@MainActor @Test func missingExecutableAndOfflineResourcesAreRejected() async {
    let launcher = MacApplicationLauncher()
    do {
        _ = try await launcher.launch(.init(title: "Missing", module: .games, kind: .executable, location: "/no-such-mmtv-file"))
        Issue.record("Missing executable launched")
    } catch { #expect(error is LaunchError) }
    do {
        _ = try await launcher.launch(.init(title: "Offline", module: .games, kind: .executable, location: "/bin/sleep", arguments: ["10"], resourceDirectory: "/no-such-mmtv-volume"))
        Issue.record("Offline resources were ignored")
    } catch { #expect(error is LaunchError) }
}
