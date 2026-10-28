import Foundation
import MusicKit
import Contracts

public enum MusicModule {
    public static var accountConnectionEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "mmTVMusicKitEnabled") as? Bool ?? false
    }
    public static var descriptor: ModuleDescriptor {
        .init(.music, title: "听点什么", subtitle: "今晚演示暂缓 · V0.3", symbol: "music.note", status: .needsSetup)
    }
    public static var authorizationDescription: String {
        switch MusicAuthorization.currentStatus {
        case .authorized: "已授权 Apple Music；完整播放器将在音乐版本接入。"
        case .denied: "Apple Music 权限已拒绝，可在系统设置中修改。"
        case .restricted: "当前账户限制了 Apple Music 访问。"
        default: "尚未请求 Apple Music 授权。"
        }
    }
    /// Rough effort for a living-room-ready MusicKit slice (not a calendar promise).
    public static let effortEstimate = """
    完整 MusicKit 客厅体验（授权、歌单、搜索、播放队列、与视频/游戏互斥暂停）工作面大：\
    需开发者 Music capability + 稳定签名、真机账户授权、播放器 UI 与遥控焦点。\
    仓内 ROADMAP V0.3 估约 5—8 个集中工作日。今晚演示切片刻意暂缓，仅保留权限探针入口。
    """
    public static func requestAuthorization() async -> String {
        guard accountConnectionEnabled else { return "此预览构建尚未启用 Apple Music 账户连接；需完成开发者签名配置后验证。" }
        _ = await MusicAuthorization.request()
        return authorizationDescription
    }
}
