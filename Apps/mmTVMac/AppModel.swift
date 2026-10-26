import AppKit
import Observation
import Contracts
import Core
import Input
import MacHost
import Games
import TVApps
import Music
import PhotoGallery
import Home
import Assistant
import Remote

@MainActor @Observable final class AppModel {
    let isPreview: Bool
    let version = "0.2.0-dev"
    var configuration = AppConfiguration()
    let session: SessionCoordinator
    let input = NativeInput()
    var focus = GridFocus()
    var homeFocus = 0
    var editor: AppEntry?
    var isEditing = false
    var showingSettings = false
    var showingSetup = false
    var message: String?
    var loadError: String?
    var probeResult: String?
    var loadingProbe = false
    let store: ConfigurationStore
    private var observers: [NSObjectProtocol] = []
    private let launcher: MacApplicationLauncher
    private var navigationGeneration = 0
    let isolatedModule: ModuleID?
    var columns = 3

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isPreview = arguments.contains("--preview-only")
        if let flag = arguments.firstIndex(of: "--config"), arguments.indices.contains(flag + 1) {
            store = .init(url: URL(fileURLWithPath: arguments[flag + 1]))
        } else { store = .standard }
        if let flag = arguments.firstIndex(of: "--module"), arguments.indices.contains(flag + 1) {
            isolatedModule = ModuleID(rawValue: arguments[flag + 1])
        } else { isolatedModule = nil }
        launcher = MacApplicationLauncher()
        session = SessionCoordinator(launcher: launcher)
        do {
            var loaded = try store.load()
            var enriched = false
            for index in loaded.entries.indices where loaded.entries[index].kind == .application && loaded.entries[index].applicationBundleID == nil {
                if let bundleID = ApplicationLocationResolver.bundleIdentifier(at: loaded.entries[index].location) {
                    loaded.entries[index].applicationBundleID = bundleID
                    enriched = true
                }
            }
            configuration = loaded
            if enriched { try? store.save(loaded) }
        } catch { loadError = error.localizedDescription }
        if isPreview { return }
        launcher.onProcessExit = { [weak self] pid in self?.processExited(pid) }
        input.onEvent = { [weak self] event in self?.handle(event) }
        input.onHome = { [weak self] in self?.returnHome() }
        input.shouldHandleInput = { [weak self] in
            guard let self else { return false }
            return !self.showingSettings && !self.isEditing && !self.showingSetup && self.message == nil && NSApp.keyWindow?.identifier?.rawValue == "mmtv.main"
        }
        input.start()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            Task { @MainActor in self?.processExited(pid) }
        })
        if let isolatedModule { open(isolatedModule) }
    }
    var modules: [ModuleDescriptor] {
        let all = [GamesModule.descriptor(count: entries(.games).filter { FileManager.default.fileExists(atPath: $0.location) }.count), TVAppsModule.descriptor(count: entries(.video).filter { FileManager.default.fileExists(atPath: $0.location) }.count),
                   MusicModule.descriptor, PhotosModule.descriptor, HomeModule.descriptor, AssistantModule.descriptor, RemoteModule.descriptor]
        return all.map { module in
            if configuration.disabledModules.contains(module.id) {
                return .init(module.id, title: module.title, subtitle: module.subtitle, symbol: module.symbol, status: .disabled)
            }
            return module
        }
    }
    var visibleModules: [ModuleDescriptor] {
        modules.filter { !configuration.disabledModules.contains($0.id) && (isolatedModule == nil || $0.id == isolatedModule) }
    }
    var currentModule: ModuleDescriptor? { modules.first { $0.id == session.route } }
    func entries(_ module: ModuleID) -> [AppEntry] { configuration.entries.filter { $0.module == module } }
    var currentEntries: [AppEntry] { session.route.map(entries) ?? [] }
    var runningEntries: [AppEntry] { configuration.entries.filter { session.running[$0.id] != nil } }
    func resolvedLocation(_ entry: AppEntry) -> String? {
        ApplicationLocationResolver.resolvedLocation(for: entry)
    }
    func health(_ entry: AppEntry) -> EntryHealth {
        let relocated = resolvedLocation(entry).flatMap { $0 == entry.location ? nil : $0 }
        return EntryHealthChecker.check(entry, relocatedPath: relocated)
    }
    @discardableResult func repairLocationIfNeeded(_ entry: AppEntry) -> AppEntry {
        guard let location = resolvedLocation(entry), location != entry.location else { return entry }
        var repaired = entry; repaired.location = location
        do { try upsert(repaired) }
        catch { message = "应用已找到，但保存新路径失败：\(error.localizedDescription)" }
        return repaired
    }
    var itemCount: Int {
        switch session.route {
        case nil: visibleModules.count
        case .games, .video: currentEntries.count + 1
        default: 1
        }
    }
    func save(_ updated: AppConfiguration) throws {
        guard loadError == nil else { throw LaunchError.invalid("当前配置读取失败，为保护原文件已停止写入。请修复或重新导入配置。") }
        try store.save(updated)
        configuration = updated
    }
    func upsert(_ entry: AppEntry) throws {
        try EntryValidation.validate(entry)
        var updated = configuration
        if let index = updated.entries.firstIndex(where: { $0.id == entry.id }) { updated.entries[index] = entry }
        else { updated.entries.append(entry) }
        try save(updated)
    }
    func remove(_ entry: AppEntry) {
        do {
            var updated = configuration; updated.entries.removeAll { $0.id == entry.id }
            try save(updated)
            focus.select(focus.index, count: itemCount)
            message = "已移除入口，应用和资源仍保留在电脑上。"
        } catch { message = error.localizedDescription }
    }
    func setEnabled(_ module: ModuleID, _ enabled: Bool) {
        do {
            var updated = configuration
            if enabled { updated.disabledModules.remove(module) } else { updated.disabledModules.insert(module) }
            try save(updated)
            focus.select(focus.index, count: itemCount)
        } catch { message = error.localizedDescription }
    }
    func open(_ module: ModuleID) {
        guard !configuration.disabledModules.contains(module) else { return }
        navigationGeneration += 1
        homeFocus = focus.index; focus = GridFocus(); probeResult = nil
        Task { await session.dispatch(.openModule(module), entries: configuration.entries, disabled: configuration.disabledModules) }
    }
    func returnHome() {
        navigationGeneration += 1
        showingSettings = false
        showingSetup = false
        isEditing = false
        Task { await session.dispatch(.showHome, entries: configuration.entries) }
        focus = GridFocus(index: homeFocus)
        NSApp.activate()
        NSApp.windows.first(where: { $0.identifier?.rawValue == "mmtv.main" })?.makeKeyAndOrderFront(nil)
    }
    func launch(_ entry: AppEntry) {
        let entry = repairLocationIfNeeded(entry)
        let generation = navigationGeneration
        Task {
            let result = await session.dispatch(.launch(entry.id), entries: configuration.entries, disabled: configuration.disabledModules)
            if case .rejected(let reason) = result { message = reason }
            if generation != navigationGeneration { returnHome() }
        }
    }
    func addEntry() {
        guard let module = session.route, [.games, .video].contains(module) else { return }
        editor = AppEntry(title: "", module: module, location: "")
        isEditing = true
    }
    func edit(_ entry: AppEntry) { editor = entry; isEditing = true }
    func candidateLocation(_ candidate: TVAppCandidate) -> String? {
        guard let bundleID = candidate.macBundleID else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    }
    func candidateIsConnected(_ candidate: TVAppCandidate) -> Bool {
        guard let bundleID = candidate.macBundleID else { return false }
        return entries(.video).contains { $0.applicationBundleID == bundleID }
    }
    func connect(_ candidate: TVAppCandidate) {
        guard let bundleID = candidate.macBundleID,
              let location = candidateLocation(candidate) else {
            message = "尚未检测到可直接接入的 macOS 应用。请先安装客户端，再回到这里检测。"
            return
        }
        if candidateIsConnected(candidate) { message = "该客户端已经接入。"; return }
        do {
            try upsert(.init(title: candidate.title.components(separatedBy: " / ").last ?? candidate.title,
                             module: .video, location: location,
                             applicationBundleID: bundleID,
                             notes: "由 mmTV 应用目录自动接入。"))
            message = "已接入 \(candidate.title)。"
        } catch { message = error.localizedDescription }
    }
    func handle(_ event: RemoteEvent) {
        guard !showingSettings, !isEditing, !showingSetup else { return }
        switch event {
        case .home: returnHome()
        case .back:
            if session.route != nil { returnHome() }
        case .select:
            if session.route == nil {
                let list = visibleModules
                if list.indices.contains(focus.index) { open(list[focus.index].id) }
            } else if session.route == .games || session.route == .video {
                let list = currentEntries
                if list.indices.contains(focus.index) { launch(list[focus.index]) } else { addEntry() }
            } else { showingSetup = true }
        default: focus.move(event, count: itemCount, columns: columns)
        }
    }
    func processExited(_ pid: Int32) {
        if session.applicationExited(pid: pid) { returnHome() }
    }
    func performProbe() {
        guard !loadingProbe else { return }
        loadingProbe = true
        Task {
            defer { loadingProbe = false }
            if session.route == .music {
                probeResult = await MusicModule.requestAuthorization()
            } else if session.route == .photos {
                let result = await PhotosModule.requestAuthorization()
                let count = PhotosModule.assetCountIfAuthorized()
                probeResult = result + (count.map { " 图库共 \($0) 个资源。" } ?? "")
            }
        }
    }
    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mmTV-configuration.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: url, options: .atomic)
            message = "配置已导出；换机器后请重新选择应用和媒体路径。"
        } catch { message = error.localizedDescription }
    }
    func importConfiguration() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let loaded = try ConfigurationStore(url: url).load()
            let alert = NSAlert()
            alert.messageText = "导入 \(loaded.entries.count) 个应用入口？"
            alert.informativeText = "将替换当前配置；原配置保留为 .previous 备份。"
            alert.addButton(withTitle: "导入"); alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            // Explicit import is also the recovery path for an unreadable configuration.
            try store.save(loaded)
            loadError = nil; configuration = loaded
            message = "配置已导入，请检查本机路径。"
        } catch { message = error.localizedDescription }
    }
    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mmTV-diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let entryLines = configuration.entries.map { entry in
            "- [\(entry.module.rawValue)] \(entry.title): \(health(entry).title) | \(entry.location) | appBundle=\(entry.applicationBundleID ?? "-") | trackedBundle=\(entry.trackedBundleID ?? "-")"
        }
        let eventLines = session.events.map { event in
            "- \(event.date.ISO8601Format()) [\(event.kind.rawValue)] \(event.title): \(event.detail)"
        }
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        let report = """
        mmTV diagnostics
        generated: \(Date.now.ISO8601Format())
        appVersion: \(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        architecture: \(architecture)
        globalHomeHotkey: \(input.globalHomeAvailable ? "available" : "unavailable")
        config: \(store.url.path)

        entries:
        \(entryLines.isEmpty ? "- none" : entryLines.joined(separator: "\n"))

        recentEvents:
        \(eventLines.isEmpty ? "- none" : eventLines.joined(separator: "\n"))
        """
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            message = "诊断报告已导出。报告包含本机应用路径，不包含账号口令。"
        } catch { message = error.localizedDescription }
    }
}
