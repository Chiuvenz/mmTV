import Contracts

public enum HomeModule {
    public static func descriptor(for configuration: HomeAssistantConfiguration?) -> ModuleDescriptor {
        let status: ModuleStatus
        if let configuration {
            status = configuration.useMock || configuration.canUseLiveAPI ? .ready : .needsSetup
        } else {
            status = .needsSetup
        }
        let subtitle: String
        if configuration?.useMock == true {
            subtitle = "模拟灯光 · 可改真实 HA"
        } else if configuration?.canUseLiveAPI == true {
            subtitle = "灯光 · 场景 · Home Assistant"
        } else {
            subtitle = "粘贴令牌即可控灯"
        }
        return .init(.home, title: "我的家", subtitle: subtitle, symbol: "house", status: status)
    }

    /// Back-compat for call sites that only need a static card before config loads.
    public static var descriptor: ModuleDescriptor {
        descriptor(for: nil)
    }

    public static let setupDescription = """
    客厅演示：在 configuration.json 写入 homeAssistant（baseURL、long-lived token、2–3 个 entity）。\
    先把 useMock 设为 true 可无 HA 联调焦点；改 false 并粘贴令牌后走 REST。\
    HA 故障不影响游戏与视频。完整 WebSocket / 多设备见后续 V0.4。
    """

    public static func resolvedConfiguration(in app: AppConfiguration) -> HomeAssistantConfiguration {
        app.homeAssistant ?? HomeAssistantConfiguration(useMock: true)
    }
}
