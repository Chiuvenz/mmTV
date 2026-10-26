import Contracts
public enum AssistantModule {
    public static var descriptor: ModuleDescriptor {
        .init(.assistant, title: "和助手说说", subtitle: "Hermes · 搜索 · 语音", symbol: "waveform", status: .unavailable)
    }
    public static let setupDescription = "Hermes 是独立运行的 AI 服务。语音与 AI 版本将加入认证连接、任务状态和按住说话；当前游戏启动与主页导航不依赖 AI。"
}
