import Photos
import Contracts

public enum PhotosModule {
    public static var descriptor: ModuleDescriptor {
        .init(.photos, title: "照片与回忆", subtitle: "今晚演示暂缓 · V0.3", symbol: "photo.on.rectangle.angled", status: .needsSetup)
    }
    public static var authorizationDescription: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: "已获得图库访问权限。"
        case .limited: "已获得部分图库访问权限。"
        case .denied: "图库访问已拒绝，可在系统设置中修改。"
        case .restricted: "当前账户限制了图库访问。"
        default: "尚未请求系统图库权限；也可以使用本地照片目录。"
        }
    }
    /// Rough effort for a living-room Photo gallery (not a calendar promise).
    public static let effortEstimate = """
    完整影像馆（系统图库/本地目录、时间线、幻灯片、视频、与音乐联动）工作面大：\
    PhotoKit 权限与性能、遥控浏览、外置盘离线恢复。仓内 ROADMAP V0.3 估约 5—8 个集中工作日（与 Music 同阶段）。\
    今晚演示切片暂缓，仅保留授权探针；不阻塞游戏 / HA / 本机视频。
    """
    public static func requestAuthorization() async -> String {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return authorizationDescription
    }
    public static func assetCountIfAuthorized() async -> Int? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        return await Task.detached(priority: .utility) {
            PHAsset.fetchAssets(with: nil).count
        }.value
    }
}
