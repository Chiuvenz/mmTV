import Photos
import Contracts

public enum PhotosModule {
    public static var descriptor: ModuleDescriptor {
        .init(.photos, title: "照片与回忆", subtitle: "旅行 · 家人 · 私人影像馆", symbol: "photo.on.rectangle.angled", status: .needsSetup)
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
    public static func requestAuthorization() async -> String {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return authorizationDescription
    }
    public static func assetCountIfAuthorized() -> Int? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        return PHAsset.fetchAssets(with: nil).count
    }
}
