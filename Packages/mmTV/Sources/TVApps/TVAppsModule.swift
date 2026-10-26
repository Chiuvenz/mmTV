import Contracts
import Foundation

public struct TVAppCandidate: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let source: URL
    public let macBundleID: String?
    public let download: URL
    public init(id: String, title: String, detail: String, source: URL,
                macBundleID: String? = nil, download: URL? = nil) {
        self.id = id; self.title = title; self.detail = detail; self.source = source
        self.macBundleID = macBundleID; self.download = download ?? source
    }
}
public enum TVAppsModule {
    public static func descriptor(count: Int) -> ModuleDescriptor {
        .init(.video, title: "看点什么", subtitle: "电视应用 · 电影 · 视频", symbol: "play.rectangle", status: count > 0 ? .ready : .needsSetup)
    }
    public static let candidates: [TVAppCandidate] = [
        .init(id: "youtube", title: "YouTube / VacuumTube", detail: "原生 macOS 包；安装后 mmTV 可自动检测并接入。",
              source: URL(string: "https://github.com/shy1132/VacuumTube")!,
              macBundleID: "rocks.shy.VacuumTube",
              download: URL(string: "https://github.com/shy1132/VacuumTube/releases/latest")!),
        .init(id: "bilibili", title: "Bilibili / BiliTV", detail: "LG webOS 客户端；Mac 适配尚在开发，不提供虚假的一键接入。",
              source: URL(string: "https://github.com/asdf17128/bili-webos")!,
              download: URL(string: "https://github.com/asdf17128/bili-webos/releases/latest")!)
    ]
    public static func entries(in configuration: AppConfiguration) -> [AppEntry] {
        configuration.entries.filter { $0.module == .video }
    }
}
