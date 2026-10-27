import SwiftUI
import AppKit

@main struct mmTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    var body: some Scene {
        Window("mmTV", id: "main") {
            RootView(model: model)
                .frame(minWidth: 920, minHeight: 650)
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .background(WindowSetup(tvMode: model.configuration.tvMode))
        }
        .defaultSize(width: 1280, height: 850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("客厅") {
                Button("返回主页") { model.returnHome() }.keyboardShortcut("h", modifiers: [.control, .option])
                Button("设置") { model.openSettings() }.keyboardShortcut(",", modifiers: .command)
                Button("切换全屏") { NSApp.keyWindow?.toggleFullScreen(nil) }.keyboardShortcut("f", modifiers: [.control, .command])
            }
        }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if PreviewRenderer.runIfRequested() { return }
        #endif
        NSApp.setActivationPolicy(.regular); NSApp.activate()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.windows.first?.makeKeyAndOrderFront(nil); return true
    }
}
private struct WindowSetup: NSViewRepresentable {
    let tvMode: Bool
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.identifier = NSUserInterfaceItemIdentifier("mmtv.main")
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.035, green: 0.052, blue: 0.076, alpha: 1)
            if tvMode && !window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
