import Contracts
import Foundation

public struct TVAppCandidate: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let source: URL
    public let macBundleID: String?
    public let download: URL
    public let launchArguments: [String]
    public init?(id: String, title: String, detail: String, source: String,
                 macBundleID: String? = nil, download: String? = nil,
                 launchArguments: [String] = []) {
        guard let sourceURL = URL(string: source) else { return nil }
        let downloadURL: URL
        if let download {
            guard let parsedDownload = URL(string: download) else { return nil }
            downloadURL = parsedDownload
        } else {
            downloadURL = sourceURL
        }
        self.id = id; self.title = title; self.detail = detail; self.source = sourceURL
        self.macBundleID = macBundleID; self.download = downloadURL
        self.launchArguments = launchArguments
    }
}

public enum TVAppsModule {
    public static func descriptor(count: Int) -> ModuleDescriptor {
        .init(.video, title: "看点什么", subtitle: "电视应用 · 电影 · 视频", symbol: "play.rectangle", status: count > 0 ? .ready : .needsSetup)
    }

    /// Prefer external player apps over embedding. Bili remains the adapters path; IINA/QuickTime are the fast local demo.
    public static let candidates: [TVAppCandidate] = [
        .init(id: "iina", title: "IINA · 本机影片", detail: "已安装则一键接入；用外部播放器打开本地视频，适合今晚客厅演示。",
              source: "https://iina.io",
              macBundleID: "com.colliderli.iina",
              download: "https://iina.io"),
        .init(id: "quicktime", title: "QuickTime Player", detail: "系统自带播放器；无 IINA 时的兜底本机播放入口。",
              source: "https://support.apple.com/guide/quicktime-player/welcome/mac",
              macBundleID: "com.apple.QuickTimePlayerX",
              download: "https://support.apple.com/guide/quicktime-player/welcome/mac"),
        .init(id: "youtube", title: "YouTube / VacuumTube", detail: "可自动检测；上游 v2.0.1 未通过 macOS 严格签名校验，暂不自动安装。",
              source: "https://github.com/shy1132/VacuumTube",
              macBundleID: "rocks.shy.VacuumTube",
              download: "https://github.com/shy1132/VacuumTube/releases/latest"),
        .init(id: "bilibili", title: "Bilibili / BiliTVMac", detail: "独立 App 适配器（mmTVAdapters）；安装后按 Bundle ID 自动检测并以电视全屏模式启动。",
              source: "https://github.com/asdf17128/bili-webos",
              macBundleID: "com.mmtv.bilitv",
              download: "https://github.com/Chiuvenz/mmTVAdapters",
              launchArguments: ["--tv-fullscreen"])
    ].compactMap { $0 }

    public static func entries(in configuration: AppConfiguration) -> [AppEntry] {
        configuration.entries.filter { $0.module == .video }
    }
}
