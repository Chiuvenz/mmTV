import Foundation
import Testing
import Contracts
import Core

@MainActor final class FakeLauncher: ApplicationLaunching {
    var launches = 0
    var activated: [Int32] = []
    var failure: (any Error)?
    var nextPID: Int32 = 41
    var gate: CheckedContinuation<Void, Never>?
    var suspend = false
    func launch(_ entry: AppEntry) async throws -> ApplicationHandle {
        launches += 1
        if suspend { await withCheckedContinuation { gate = $0 } }
        if let failure { throw failure }
        defer { nextPID += 1 }
        return .init(pid: nextPID)
    }
    func activate(_ handle: ApplicationHandle) -> Bool { activated.append(handle.pid); return true }
    func terminate(_ handle: ApplicationHandle) -> Bool { true }
}
@MainActor @Test func runningApplicationReactivatesWithoutDuplicateLaunch() async {
    let launcher = FakeLauncher(); let session = SessionCoordinator(launcher: launcher)
    let entry = AppEntry(title: "Game", module: .games, location: "/Game.app")
    #expect(await session.dispatch(.launch(entry.id), entries: [entry]) == .completed)
    #expect(await session.dispatch(.launch(entry.id), entries: [entry]) == .completed)
    #expect(launcher.launches == 1)
    #expect(launcher.activated == [41])
}
@MainActor @Test func onlyTheCurrentApplicationExitReturnsHome() async {
    let launcher = FakeLauncher(); let session = SessionCoordinator(launcher: launcher)
    let a = AppEntry(title: "A", module: .games, location: "/A.app")
    let b = AppEntry(title: "B", module: .video, location: "/B.app")
    let entries = [a,b]
    _ = await session.dispatch(.openModule(.video), entries: entries)
    _ = await session.dispatch(.launch(a.id), entries: entries)
    _ = await session.dispatch(.launch(b.id), entries: entries)
    #expect(!session.applicationExited(pid: 41))
    #expect(session.route == .video)
    #expect(session.applicationExited(pid: 42))
    #expect(session.route == nil)
    #expect(session.running.isEmpty)
}
@MainActor @Test func disabledModuleRejectsLaunchAndFailureRecovers() async {
    let launcher = FakeLauncher(); let session = SessionCoordinator(launcher: launcher)
    let entry = AppEntry(title: "Game", module: .games, location: "/Game.app")
    #expect(await session.dispatch(.launch(entry.id), entries: [entry], disabled: [.games]) == .rejected("该模块已停用。"))
    #expect(launcher.launches == 0)
    launcher.failure = LaunchError.missing("/Game.app")
    _ = await session.dispatch(.launch(entry.id), entries: [entry])
    #expect(session.launching == nil)
    #expect(session.running.isEmpty)
    #expect(session.error != nil)
    launcher.failure = nil
    #expect(await session.dispatch(.launch(entry.id), entries: [entry]) == .completed)
}
@MainActor @Test func repeatedConfirmWhileLaunchingDoesNotStartAnotherProcess() async {
    let launcher = FakeLauncher(); launcher.suspend = true
    let session = SessionCoordinator(launcher: launcher)
    let entry = AppEntry(title: "Game", module: .games, location: "/Game.app")
    let first = Task { await session.dispatch(.launch(entry.id), entries: [entry]) }
    while launcher.gate == nil { await Task.yield() }
    #expect(await session.dispatch(.launch(entry.id), entries: [entry]) == .rejected("正在启动应用，请稍候。"))
    #expect(launcher.launches == 1)
    launcher.gate?.resume(); launcher.gate = nil
    #expect(await first.value == .completed)
}
