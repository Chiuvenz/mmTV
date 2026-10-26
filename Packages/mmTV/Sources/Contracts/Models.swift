import Foundation

public enum ModuleID: String, Codable, CaseIterable, Identifiable, Sendable {
    case games, video, music, photos, home, assistant, remote
    public var id: String { rawValue }
}
public enum ModuleStatus: String, Codable, Sendable {
    case ready, needsSetup, unavailable, disabled
    public var title: String {
        switch self {
        case .ready: "已就绪"
        case .needsSetup: "待配置"
        case .unavailable: "未接入"
        case .disabled: "已停用"
        }
    }
}
public struct ModuleDescriptor: Identifiable, Sendable {
    public let id: ModuleID
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let status: ModuleStatus
    public init(_ id: ModuleID, title: String, subtitle: String, symbol: String, status: ModuleStatus) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.status = status
    }
}
public enum LaunchKind: String, Codable, CaseIterable, Sendable { case application, executable }
public struct AppEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var module: ModuleID
    public var kind: LaunchKind
    public var location: String
    public var arguments: [String]
    public var trackedBundleID: String?
    public var resourceDirectory: String?
    public var notes: String
    public var tvInteractionVerified: Bool
    public init(id: UUID = UUID(), title: String, module: ModuleID, kind: LaunchKind = .application,
                location: String, arguments: [String] = [], trackedBundleID: String? = nil,
                resourceDirectory: String? = nil, notes: String = "", tvInteractionVerified: Bool = false) {
        self.id = id; self.title = title; self.module = module; self.kind = kind
        self.location = location; self.arguments = arguments; self.trackedBundleID = trackedBundleID
        self.resourceDirectory = resourceDirectory; self.notes = notes; self.tvInteractionVerified = tvInteractionVerified
    }
}
public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var entries: [AppEntry] = []
    public var disabledModules: Set<ModuleID> = []
    public var tvMode: Bool = false
    public init() {}
}
public struct ApplicationHandle: Equatable, Sendable {
    public let pid: Int32
    public let bundleID: String?
    public init(pid: Int32, bundleID: String? = nil) { self.pid = pid; self.bundleID = bundleID }
}
public enum LaunchError: LocalizedError, Equatable {
    case invalid(String)
    case missing(String)
    case unsupportedVersion(Int)
    case notFound
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): reason
        case .missing(let path): "找不到资源：\(path)"
        case .unsupportedVersion(let version): "配置版本 \(version) 比当前应用更新，请使用匹配的应用版本。"
        case .notFound: "找不到该应用，请重新配置。"
        }
    }
}
@MainActor public protocol ApplicationLaunching: AnyObject {
    func launch(_ entry: AppEntry) async throws -> ApplicationHandle
    func activate(_ handle: ApplicationHandle) -> Bool
    func terminate(_ handle: ApplicationHandle) -> Bool
}
public enum RemoteEvent: Equatable, Sendable { case up, down, left, right, select, back, home }
public enum Action: Equatable, Sendable {
    case showHome
    case openModule(ModuleID)
    case launch(UUID)
}
public enum ActionResult: Equatable, Sendable {
    case completed
    case rejected(String)
}
