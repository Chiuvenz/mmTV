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

enum SettingsRemoteTarget: Hashable {
    case done
    case module(ModuleID)
    case entry(UUID)
    case tvMode
    case volumeDown, volumeUp
    case requestInputAccess
    case exportConfiguration, exportDiagnostics, importConfiguration, openConfigurationDirectory
}

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
    var xiaomiRemoteConnected = false
    var remoteInputAccess = RemoteInputAccessStatus.unknown
    var settingsFocus = 0
    var setupFocus = 0
    var systemVolume: Float32?
    var showingVolumeHUD = false
    private var volumeHUDTask: Task<Void, Never>?

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
        input.onXiaomiRemoteConnectionChanged = { [weak self] connected in
            self?.xiaomiRemoteConnected = connected
        }
        input.onRemoteInputAccessChanged = { [weak self] status in
            self?.remoteInputAccess = status
        }
        input.shouldHandleInput = {
            return NSApp.isActive && NSApp.windows.contains {
                $0.identifier?.rawValue == "mmtv.main" && $0.isVisible
            }
        }
        input.start()
        remoteInputAccess = input.remoteInputAccess
        systemVolume = SystemVolumeController.currentVolume()
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
        message = nil
        Task { await session.dispatch(.showHome, entries: configuration.entries) }
        focus = GridFocus(index: homeFocus)
        NSApp.activate()
        NSApp.windows.first(where: { $0.identifier?.rawValue == "mmtv.main" })?.makeKeyAndOrderFront(nil)
    }
    func openSettings() {
        settingsFocus = 0
        systemVolume = SystemVolumeController.currentVolume()
        showingSettings = true
    }
    func openSetup() {
        setupFocus = 0
        showingSetup = true
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
                             arguments: candidate.launchArguments,
                             applicationBundleID: bundleID,
                             notes: "由 mmTV 应用目录自动接入。"))
            message = "已接入 \(candidate.title)。"
        } catch { message = error.localizedDescription }
    }
    func handle(_ event: RemoteEvent) {
        if handleSystemModal(event) { return }
        switch event {
        case .volumeUp:
            adjustVolume(by: SystemVolumeController.step)
            return
        case .volumeDown:
            adjustVolume(by: -SystemVolumeController.step)
            return
        case .voice:
            message = "语音键已经识别；语音采集将在 Hermes / ATVV 模块接入后启用。"
            return
        case .menu:
            guard !isEditing else { return }
            if showingSettings { showingSettings = false }
            else {
                message = nil
                showingSetup = false
                openSettings()
            }
            return
        default: break
        }
        if message != nil {
            if event == .select || event == .back { message = nil }
            else if event == .home { returnHome() }
            return
        }
        if showingSettings { handleSettings(event); return }
        if showingSetup { handleSetup(event); return }
        if isEditing {
            if event == .back { isEditing = false }
            else if event == .home { returnHome() }
            else { forwardToNativeFocus(event) }
            return
        }
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
            } else { openSetup() }
        case .up, .down, .left, .right:
            focus.move(event, count: itemCount, columns: columns)
        case .menu, .volumeUp, .volumeDown, .voice: break
        }
    }

    var settingsTargets: [SettingsRemoteTarget] {
        var targets: [SettingsRemoteTarget] = [.done]
        targets.append(contentsOf: modules.map { .module($0.id) })
        targets.append(contentsOf: configuration.entries.map { .entry($0.id) })
        targets += [.tvMode, .volumeDown, .volumeUp]
        if remoteInputAccess != .granted { targets.append(.requestInputAccess) }
        targets += [.exportConfiguration, .exportDiagnostics, .importConfiguration, .openConfigurationDirectory]
        return targets
    }
    var focusedSettingsTarget: SettingsRemoteTarget? {
        let targets = settingsTargets
        return targets.indices.contains(settingsFocus) ? targets[settingsFocus] : targets.first
    }
    func isSettingsFocused(_ target: SettingsRemoteTarget) -> Bool { focusedSettingsTarget == target }
    func focusSettings(_ target: SettingsRemoteTarget) {
        guard let index = settingsTargets.firstIndex(of: target) else { return }
        settingsFocus = index
    }
    func openConfigurationDirectory() {
        let directory = store.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }
    func adjustVolume(by delta: Float32) {
        guard let level = SystemVolumeController.adjust(by: delta) else {
            systemVolume = nil
            message = "当前音频输出设备不支持 macOS 软件音量，请改用电视、显示器或音响的音量控制。"
            return
        }
        systemVolume = level
        showingVolumeHUD = true
        volumeHUDTask?.cancel()
        volumeHUDTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            self?.showingVolumeHUD = false
        }
    }
    var volumePercent: Int? { systemVolume.map { Int(($0 * 100).rounded()) } }

    private func handleSettings(_ event: RemoteEvent) {
        switch event {
        case .back: showingSettings = false
        case .home: returnHome()
        case .select:
            guard let target = focusedSettingsTarget else { return }
            activateSettings(target)
        case .up, .left:
            settingsFocus = max(0, settingsFocus - 1)
        case .down, .right:
            settingsFocus = min(max(0, settingsTargets.count - 1), settingsFocus + 1)
        case .menu, .volumeUp, .volumeDown, .voice: break
        }
    }
    private func activateSettings(_ target: SettingsRemoteTarget) {
        switch target {
        case .done: showingSettings = false
        case .module(let id): setEnabled(id, configuration.disabledModules.contains(id))
        case .entry(let id):
            guard let entry = configuration.entries.first(where: { $0.id == id }) else { return }
            showingSettings = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.edit(entry) }
        case .tvMode:
            do { var config = configuration; config.tvMode.toggle(); try save(config) }
            catch { message = error.localizedDescription }
        case .volumeDown: adjustVolume(by: -SystemVolumeController.step)
        case .volumeUp: adjustVolume(by: SystemVolumeController.step)
        case .requestInputAccess: requestRemoteInputAccess()
        case .exportConfiguration: exportConfiguration()
        case .exportDiagnostics: exportDiagnostics()
        case .importConfiguration: importConfiguration()
        case .openConfigurationDirectory: openConfigurationDirectory()
        }
    }
    private func handleSetup(_ event: RemoteEvent) {
        let hasProbe = (session.route == .photos) || (session.route == .music && MusicModule.accountConnectionEnabled)
        let count = hasProbe ? 2 : 1
        switch event {
        case .back: showingSetup = false
        case .home: returnHome()
        case .select:
            if hasProbe && setupFocus == 0 { performProbe() }
            else { showingSetup = false }
        case .up, .left: setupFocus = max(0, setupFocus - 1)
        case .down, .right: setupFocus = min(count - 1, setupFocus + 1)
        case .menu, .volumeUp, .volumeDown, .voice: break
        }
    }
    private func handleSystemModal(_ event: RemoteEvent) -> Bool {
        guard let window = NSApp.modalWindow else { return false }
        switch event {
        case .back:
            if let panel = window as? NSSavePanel { panel.cancel(nil) }
            else { NSApp.abortModal(); window.orderOut(nil) }
        case .home:
            if let panel = window as? NSSavePanel { panel.cancel(nil) }
            else { NSApp.abortModal(); window.orderOut(nil) }
            returnHome()
        default: forwardToNativeFocus(event, window: window)
        }
        return true
    }
    private func forwardToNativeFocus(_ event: RemoteEvent, window: NSWindow? = NSApp.keyWindow) {
        guard let window else { return }
        switch event {
        case .up, .left: window.selectPreviousKeyView(nil)
        case .down, .right: window.selectNextKeyView(nil)
        case .select: _ = window.firstResponder?.tryToPerform(#selector(NSResponder.insertNewline(_:)), with: nil)
        default: break
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
    func requestRemoteInputAccess() {
        let granted = input.requestRemoteInputAccess()
        remoteInputAccess = input.remoteInputAccess
        message = granted
            ? "输入监控已经授权。若返回键仍无响应，请重新启动 mmTV。"
            : "请在系统设置的“隐私与安全性 → 输入监控”中允许 mmTV，然后重新启动应用。"
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
        xiaomiRemote: \(xiaomiRemoteConnected ? "connected" : "disconnected")
        remoteInputAccess: \(remoteInputAccess.rawValue)
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
