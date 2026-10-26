import Foundation
import Observation
import Contracts

@MainActor @Observable public final class SessionCoordinator {
    public private(set) var route: ModuleID?
    public private(set) var running: [UUID: ApplicationHandle] = [:]
    public private(set) var launching: UUID?
    public private(set) var error: String?
    public private(set) var lastLaunched: UUID?
    public private(set) var events: [SessionEvent] = []
    private let launcher: any ApplicationLaunching
    private var activationHistory: [UUID] = []
    private var entryTitles: [UUID: String] = [:]
    public init(launcher: any ApplicationLaunching) { self.launcher = launcher }
    public func clearError() { error = nil }
    @discardableResult public func dispatch(_ action: Action, entries: [AppEntry], disabled: Set<ModuleID> = []) async -> ActionResult {
        switch action {
        case .showHome:
            route = nil
        case .openModule(let module):
            guard !disabled.contains(module) else { return .rejected("该模块已停用。") }
            route = module
        case .launch(let id):
            guard launching == nil else { return .rejected("正在启动应用，请稍候。") }
            guard let entry = entries.first(where: { $0.id == id }) else { return .rejected("找不到该应用。") }
            guard !disabled.contains(entry.module) else { return .rejected("该模块已停用。") }
            do {
                try EntryValidation.validate(entry)
                if let handle = running[id], launcher.activate(handle) {
                    recordActivation(id)
                    record(.init(entryID: id, title: entry.title, kind: .activated,
                                 detail: "已切回正在运行的应用（PID \(handle.pid)）。"))
                    return .completed
                }
                running[id] = nil
                launching = id; error = nil
                defer { launching = nil }
                let handle = try await launcher.launch(entry)
                running[id] = handle
                entryTitles[id] = entry.title
                recordActivation(id)
                record(.init(entryID: id, title: entry.title, kind: .launched,
                             detail: "启动成功（PID \(handle.pid)）。"))
            } catch {
                self.error = error.localizedDescription
                record(.init(entryID: id, title: entry.title, kind: .failed,
                             detail: error.localizedDescription))
                return .rejected(error.localizedDescription)
            }
        }
        return .completed
    }
    private func recordActivation(_ id: UUID) {
        activationHistory.removeAll { $0 == id }; activationHistory.append(id); lastLaunched = id
    }
    private func record(_ event: SessionEvent) {
        events.insert(event, at: 0)
        if events.count > 50 { events.removeLast(events.count - 50) }
    }
    /// Only return home for the last application launched, not an unrelated app exiting.
    @discardableResult public func applicationExited(pid: Int32) -> Bool {
        let ids = running.filter { $0.value.pid == pid }.map(\.key)
        let shouldReturn = ids.contains(lastLaunched ?? UUID())
        ids.forEach { id in
            running[id] = nil
            record(.init(entryID: id, title: entryTitles[id] ?? "应用", kind: .exited,
                         detail: "应用已退出（PID \(pid)）。"))
            entryTitles[id] = nil
        }
        activationHistory.removeAll { ids.contains($0) }
        if shouldReturn { lastLaunched = activationHistory.last; route = nil }
        return shouldReturn
    }
    public func forget(_ id: UUID) { running[id] = nil; entryTitles[id] = nil; activationHistory.removeAll { $0 == id }; if lastLaunched == id { lastLaunched = activationHistory.last } }
    public func requestTermination(_ id: UUID) -> Bool {
        guard let handle = running[id] else { return false }
        return launcher.terminate(handle)
    }
}
