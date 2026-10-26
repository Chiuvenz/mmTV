#if DEBUG
import SwiftUI
import AppKit

/// Renders our own SwiftUI view to an artifact; does not capture the desktop.
@MainActor enum PreviewRenderer {
    static func runIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--render-preview"), arguments.indices.contains(flag + 1) else { return false }
        let destination = URL(fileURLWithPath: arguments[flag + 1])
        DispatchQueue.main.async {
            let isolatedConfig = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preview.json")
            let model = AppModel(arguments: ["mmTV", "--preview-only", "--config", isolatedConfig.path])
            let content = RootView(model: model)
                .frame(width: 1280, height: 1000)
                .environment(\.colorScheme, .dark)
                .environment(\.locale, Locale(identifier: "zh_CN"))
            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            guard let image = renderer.cgImage else { fputs("Preview render failed\n", stderr); NSApp.terminate(nil); return }
            let representation = NSBitmapImageRep(cgImage: image)
            do {
                guard let png = representation.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try png.write(to: destination)
                print("Preview rendered: \(destination.path)")
            } catch { fputs("Preview render error: \(error)\n", stderr) }
            NSApp.terminate(nil)
        }
        return true
    }
}
#endif
