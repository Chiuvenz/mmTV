import Contracts
public enum HomeModule {
    public static var descriptor: ModuleDescriptor {
        .init(.home, title: "我的家", subtitle: "灯光 · 设备 · 家庭场景", symbol: "house", status: .unavailable)
    }
    public static let setupDescription = "Home Assistant 将作为独立服务运行。家庭控制版本将加入服务地址、凭据与设备选择；客厅界面关闭后，HA 的自动化仍继续运行。"
}
