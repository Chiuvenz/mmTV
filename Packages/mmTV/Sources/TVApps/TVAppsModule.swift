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
    public static func descriptor(count: Int, mediaLibrary: MediaLibraryConfiguration? = nil) -> ModuleDescriptor {
        let ready = count > 0 || mediaLibrary?.libraryURL != nil
        let subtitle: String
        if mediaLibrary != nil {
            subtitle = "Jellyfin 媒体库 · 电视应用"
        } else {
            subtitle = "电视应用 · 电影 · 视频"
        }
        return .init(.video, title: "看点什么", subtitle: subtitle, symbol: "play.rectangle",
                     status: ready ? .ready : .needsSetup)
    }

    /// Prefer a hosted open-source library (Jellyfin) over crude open-file players.
    /// IINA/QuickTime remain fallbacks; Bili stays on the adapters path.
    public static let candidates: [TVAppCandidate] = [
        .init(id: "jellyfin", title: "Jellyfin Server", detail: "开源媒体库服务端；扫描外置盘 Movies/TV，再在壳内打开 Web UI。本机未装时先 brew install --cask jellyfin。",
              source: "https://jellyfin.org",
              macBundleID: "org.jellyfin.server",
              download: "https://jellyfin.org/downloads/"),
        .init(id: "jellyfin-mp", title: "Jellyfin Media Player", detail: "可选桌面客户端；未装时可直接用壳内 Jellyfin Web（http://127.0.0.1:8096）。",
              source: "https://github.com/jellyfin/jellyfin-media-player",
              macBundleID: "org.jellyfin.JellyfinMediaPlayer",
              download: "https://github.com/jellyfin/jellyfin-media-player/releases"),
        .init(id: "iina", title: "IINA · 单文件兜底", detail: "无媒体库时的本机播放器兜底；客厅优先 Jellyfin 库体验。",
              source: "https://iina.io",
              macBundleID: "com.colliderli.iina",
              download: "https://iina.io"),
        .init(id: "quicktime", title: "QuickTime Player", detail: "系统自带播放器；无 IINA / Jellyfin 时的兜底。",
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

    public static func resolvedMediaLibrary(in app: AppConfiguration) -> MediaLibraryConfiguration? {
        app.mediaLibrary
    }

    /// Real library folders created on this Mac mini’s mounted volume (do not invent alternate roots).
    public static let inspectedLibraryRoots = MediaLibraryConfiguration.defaultLibraryRoots
}
