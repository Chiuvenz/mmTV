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
    public init(id: String, title: String, detail: String, source: URL,
                macBundleID: String? = nil, download: URL? = nil,
                launchArguments: [String] = []) {
        self.id = id; self.title = title; self.detail = detail; self.source = source
        self.macBundleID = macBundleID; self.download = download ?? source
        self.launchArguments = launchArguments
    }
}
public enum TVAppsModule {
    public static func descriptor(count: Int) -> ModuleDescriptor {
        .init(.video, title: "看点什么", subtitle: "电视应用 · 电影 · 视频", symbol: "play.rectangle", status: count > 0 ? .ready : .needsSetup)
    }
    public static let candidates: [TVAppCandidate] = [
        .init(id: "youtube", title: "YouTube / VacuumTube", detail: "可自动检测；上游 v2.0.1 未通过 macOS 严格签名校验，暂不自动安装。",
              source: URL(string: "https://github.com/shy1132/VacuumTube")!,
              macBundleID: "rocks.shy.VacuumTube",
              download: URL(string: "https://github.com/shy1132/VacuumTube/releases/latest")!),
        .init(id: "bilibili", title: "Bilibili / BiliTVMac", detail: "mmTV 独立 Mac 适配器；安装后可自动检测并以电视全屏模式启动。",
              source: URL(string: "https://github.com/asdf17128/bili-webos")!,
              macBundleID: "com.mmtv.bilitv",
              download: URL(string: "https://github.com/Chiuvenz/mmTV/tree/main/Integrations/BiliTVMac")!,
              launchArguments: ["--tv-fullscreen"])
    ]
    public static func entries(in configuration: AppConfiguration) -> [AppEntry] {
        configuration.entries.filter { $0.module == .video }
    }
}
