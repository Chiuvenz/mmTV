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
            subtitle = "模拟灯光 · 原生快捷控件"
        } else if configuration?.canUseLiveAPI == true {
            subtitle = "灯光 · 场景 · Home Assistant"
        } else if configuration?.showsLovelaceCard == true {
            subtitle = "原生控件 · 可选 Lovelace"
        } else {
            subtitle = "配置 HA URL / 令牌与 entity ID"
        }
        return .init(.home, title: "我的家", subtitle: subtitle, symbol: "house", status: status)
    }

    /// Back-compat for call sites that only need a static card before config loads.
    public static var descriptor: ModuleDescriptor {
        descriptor(for: nil)
    }

    public static let setupDescription = """
    客厅演示优先原生 SwiftUI 快捷控件（灯/场景开关，遥控友好）。\
    configuration.json 的 homeAssistant 保留 baseURL、长期访问令牌（仅 REST）、entity ID 列表、\
    uiMode（默认 controls；设为 lovelace 才显示可选仪表盘卡片）。\
    Lovelace WKWebView 已降级为可选；用户需自建 HA（默认 http://homeassistant.local:8123）。\
    HA 故障不影响游戏与视频。
    """

    public static func resolvedConfiguration(in app: AppConfiguration) -> HomeAssistantConfiguration {
        app.homeAssistant ?? HomeAssistantConfiguration(useMock: true)
    }
}
