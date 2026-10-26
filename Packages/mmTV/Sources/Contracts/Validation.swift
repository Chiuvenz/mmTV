import Foundation

public enum EntryValidation {
    public static func validate(_ entry: AppEntry) throws {
        guard !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LaunchError.invalid("请填写应用名称。")
        }
        guard [.games, .video].contains(entry.module) else { throw LaunchError.invalid("仅游戏和视频模块支持外部应用。") }
        guard entry.location.hasPrefix("/"), !entry.location.contains("\0") else {
            throw LaunchError.invalid("请选择本机应用或可执行文件，路径必须是绝对路径。")
        }
        if entry.kind == .application && !entry.location.hasSuffix(".app") {
            throw LaunchError.invalid("应用路径必须指向 .app。")
        }
        if entry.kind == .executable && entry.arguments.contains(where: { $0.contains("\0") }) {
            throw LaunchError.invalid("启动参数含无效字符。")
        }
        if let resource = entry.resourceDirectory, !resource.isEmpty, !resource.hasPrefix("/") {
            throw LaunchError.invalid("资源目录必须为绝对路径。")
        }
        if let bundleID = entry.trackedBundleID, bundleID.trimmingCharacters(in: .whitespaces).isEmpty {
            throw LaunchError.invalid("跟踪 Bundle ID 不能为空，请留空或填写实际值。")
        }
        if let bundleID = entry.applicationBundleID, bundleID.trimmingCharacters(in: .whitespaces).isEmpty {
            throw LaunchError.invalid("应用 Bundle ID 不能为空，请重新选择应用。")
        }
    }
}
