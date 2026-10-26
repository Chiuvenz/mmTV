import AppKit
import Contracts
import OSLog

@MainActor public final class MacApplicationLauncher: ApplicationLaunching {
    public var onProcessExit: ((Int32) -> Void)?
    public init() {}
    private var processes: [Int32: Process] = [:]
    public func launch(_ entry: AppEntry) async throws -> ApplicationHandle {
        try EntryValidation.validate(entry)
        guard let resolvedLocation = ApplicationLocationResolver.resolvedLocation(for: entry) else {
            throw LaunchError.missing(entry.location)
        }
        if let resources = entry.resourceDirectory, !resources.isEmpty,
           !FileManager.default.fileExists(atPath: resources) { throw LaunchError.missing(resources) }
        if entry.kind == .application {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.arguments = entry.arguments
            let app = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: resolvedLocation), configuration: configuration)
            return ApplicationHandle(pid: app.processIdentifier, bundleID: app.bundleIdentifier)
        }
        guard FileManager.default.isExecutableFile(atPath: resolvedLocation) else { throw LaunchError.invalid("该文件不可执行，请选择应用或可执行文件。") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedLocation)
        process.arguments = entry.arguments
        if let folder = entry.resourceDirectory, !folder.isEmpty { process.currentDirectoryURL = URL(fileURLWithPath: folder) }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let pid = process.processIdentifier
            Task { @MainActor in
                self?.processes[pid] = nil
                self?.onProcessExit?(pid)
            }
        }
        try process.run()
        processes[process.processIdentifier] = process
        if let trackedID = entry.trackedBundleID {
            for _ in 0..<60 {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: trackedID).first(where: { !$0.isTerminated }) {
                    app.activate()
                    return ApplicationHandle(pid: app.processIdentifier, bundleID: trackedID)
                }
                try await Task.sleep(for: .milliseconds(300))
            }
            throw LaunchError.invalid("启动器已运行，但 18 秒内未找到 Bundle ID 为 \(trackedID) 的游戏。请检查启动器与实际游戏标识。")
        }
        guard process.isRunning else { throw LaunchError.invalid("启动器已退出。若它另开了游戏，请填写实际游戏 Bundle ID。") }
        return ApplicationHandle(pid: process.processIdentifier)
    }
    public func activate(_ handle: ApplicationHandle) -> Bool {
        if let process = NSRunningApplication(processIdentifier: handle.pid), !process.isTerminated { return process.activate() }
        return processes[handle.pid]?.isRunning == true
    }
    public func terminate(_ handle: ApplicationHandle) -> Bool {
        if let app = NSRunningApplication(processIdentifier: handle.pid), !app.isTerminated { return app.terminate() }
        if let process = processes[handle.pid], process.isRunning { process.terminate(); return true }
        return false
    }
}
