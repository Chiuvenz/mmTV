import Contracts
import Foundation

public struct TVAppCandidate: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let source: URL
    public init(id: String, title: String, detail: String, source: URL) {
        self.id = id; self.title = title; self.detail = detail; self.source = source
    }
}
public enum TVAppsModule {
    public static func descriptor(count: Int) -> ModuleDescriptor {
        .init(.video, title: "看点什么", subtitle: "电视应用 · 电影 · 视频", symbol: "play.rectangle", status: count > 0 ? .ready : .needsSetup)
    }
    public static let candidates: [TVAppCandidate] = [
        .init(id: "youtube", title: "YouTube / VacuumTube", detail: "独立电视客户端；安装后选择 .app 接入。", source: URL(string: "https://github.com/shy1132/VacuumTube")!),
        .init(id: "bilibili", title: "Bilibili / BiliTV", detail: "电视 Web 客户端；需要移植打包，当前不视为已兼容。", source: URL(string: "https://github.com/asdf17128/bili-webos")!)
    ]
    public static func entries(in configuration: AppConfiguration) -> [AppEntry] {
        configuration.entries.filter { $0.module == .video }
    }
}
