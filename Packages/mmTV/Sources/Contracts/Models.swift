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
    /// Bundle identifier of the selected `.app`. It lets a configuration exported
    /// from another Mac recover when the application lives at a different path.
    public var applicationBundleID: String?
    public var trackedBundleID: String?
    public var resourceDirectory: String?
    public var notes: String
    public var tvInteractionVerified: Bool
    public init(id: UUID = UUID(), title: String, module: ModuleID, kind: LaunchKind = .application,
                location: String, arguments: [String] = [], applicationBundleID: String? = nil,
                trackedBundleID: String? = nil,
                resourceDirectory: String? = nil, notes: String = "", tvInteractionVerified: Bool = false) {
        self.id = id; self.title = title; self.module = module; self.kind = kind
        self.location = location; self.arguments = arguments; self.applicationBundleID = applicationBundleID
        self.trackedBundleID = trackedBundleID
        self.resourceDirectory = resourceDirectory; self.notes = notes; self.tvInteractionVerified = tvInteractionVerified
    }
}
public enum EntryHealth: Equatable, Sendable {
    case checking
    case ready
    case relocated(String)
    case missingTarget
    case missingResources
    case notExecutable

    public var title: String {
        switch self {
        case .checking: "正在检查"
        case .ready: "可启动"
        case .relocated: "已重定位"
        case .missingTarget: "应用离线"
        case .missingResources: "资源离线"
        case .notExecutable: "不可执行"
        }
    }
    public var isLaunchable: Bool {
        switch self {
        case .ready, .relocated: true
        default: false
        }
    }
}
public enum SessionEventKind: String, Sendable { case launched, activated, exited, failed }
public struct SessionEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let entryID: UUID
    public let title: String
    public let kind: SessionEventKind
    public let detail: String
    public init(id: UUID = UUID(), date: Date = .now, entryID: UUID, title: String,
                kind: SessionEventKind, detail: String) {
        self.id = id; self.date = date; self.entryID = entryID; self.title = title
        self.kind = kind; self.detail = detail
    }
}
public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var entries: [AppEntry] = []
    public var disabledModules: Set<ModuleID> = []
    public var tvMode: Bool = false
    /// Source-compatible product name; Codable continues to persist `tvMode`
    /// so existing configuration files remain valid.
    public var launchInFullScreen: Bool {
        get { tvMode }
        set { tvMode = newValue }
    }
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
public enum RemoteEvent: Equatable, Sendable {
    case up, down, left, right
    case select, back, home, menu
    case volumeUp, volumeDown, voice
}
public enum Action: Equatable, Sendable {
    case showHome
    case openModule(ModuleID)
    case launch(UUID)
}
public enum ActionResult: Equatable, Sendable {
    case completed
    case rejected(String)
}
