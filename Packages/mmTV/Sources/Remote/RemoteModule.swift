import Contracts
public enum RemoteModule {
    public static var descriptor: ModuleDescriptor {
        .init(.remote, title: "手机与平板", subtitle: "配对 · 遥控 · 跨设备协作", symbol: "ipad.and.iphone", status: .unavailable)
    }
    public static let setupDescription = "多终端版本将提供网页配对、遥控和状态同步。当前未开放网络监听端口；可以先用键盘或手柄控制客厅界面。"
}
