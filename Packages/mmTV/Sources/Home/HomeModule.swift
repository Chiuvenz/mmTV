import Contracts

public enum HomeModule {
    public static func descriptor(for configuration: HomeAssistantConfiguration?) -> ModuleDescriptor {
        let status: ModuleStatus
        if let configuration {
            status = configuration.useMock || configuration.canUseLiveAPI || configuration.dashboardURL != nil
                ? .ready : .needsSetup
        } else {
            status = .needsSetup
        }
        let subtitle: String
        if configuration?.useMock == true {
            subtitle = "模拟灯光 · 可开 Lovelace"
        } else if configuration?.prefersLovelaceUI == true {
            subtitle = "Lovelace 仪表盘 · Home Assistant"
        } else if configuration?.canUseLiveAPI == true {
            subtitle = "灯光 · 场景 · Home Assistant"
        } else {
            subtitle = "配置 HA URL 即可打开仪表盘"
        }
        return .init(.home, title: "我的家", subtitle: subtitle, symbol: "house", status: status)
    }

    /// Back-compat for call sites that only need a static card before config loads.
    public static var descriptor: ModuleDescriptor {
        descriptor(for: nil)
    }

    public static let setupDescription = """
    客厅演示优先打开开源 Home Assistant Lovelace 前端（壳内 WKWebView 或系统浏览器），\
    不是只靠粘贴令牌的裸控件列表。用户需自建 HA（默认 http://homeassistant.local:8123）；\
    可选在 HA 安装 lovelace-wallpanel（HACS）做电视/墙面仪表盘，并把 dashboardPath 指到该页。\
    useMock=true 时仍用遥控友好的快捷控件；令牌仅用于 REST 快捷控件，Lovelace 用 HA 自己的登录。\
    HA 故障不影响游戏与视频。
    """

    public static func resolvedConfiguration(in app: AppConfiguration) -> HomeAssistantConfiguration {
        app.homeAssistant ?? HomeAssistantConfiguration(useMock: true)
    }
}
