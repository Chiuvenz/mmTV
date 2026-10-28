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
public enum HomeControlKind: String, Codable, Sendable {
    case light
    case `switch`
    case scene
}

/// One remotes-focusable HA control (light / switch / scene).
public struct HomeControl: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: HomeControlKind
    public init(id: String, title: String, kind: HomeControlKind) {
        self.id = id; self.title = title; self.kind = kind
    }
    /// Demo defaults used when `useMock` is true or before the user pastes real entity IDs.
    public static let demoDefaults: [HomeControl] = [
        .init(id: "light.living_room", title: "客厅灯", kind: .light),
        .init(id: "light.tv_backlight", title: "电视氛围灯", kind: .light),
        .init(id: "scene.movie_night", title: "观影模式", kind: .scene)
    ]
}

public struct HomeControlState: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: HomeControlKind
    /// For lights/switches: on/off. Scenes stay `nil` (activation-only).
    public var isOn: Bool?
    public var detail: String
    public init(id: String, title: String, kind: HomeControlKind, isOn: Bool? = nil, detail: String = "") {
        self.id = id; self.title = title; self.kind = kind; self.isOn = isOn; self.detail = detail
    }
}

/// How the Home module presents Home Assistant on the TV shell.
/// - `controls`: remotes-friendly native SwiftUI light/scene grid (REST or mock) — default.
/// - `lovelace`: optionally show HA’s Lovelace frontend in WKWebView (demoted; optional WallPanel on HA).
public enum HomeUIMode: String, Codable, Sendable {
    case controls
    case lovelace
}

/// Minimal Home Assistant settings. Token lives only in Application Support
/// configuration (never ship tokens in the repo or release zip).
public struct HomeAssistantConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var token: String
    /// When true, Home uses in-app mock lights/scenes — no network required.
    public var useMock: Bool
    public var controls: [HomeControl]
    /// Primary UI. Default `controls` keeps native quick actions first; set `lovelace` to also show the dashboard card.
    public var uiMode: HomeUIMode
    /// Path appended to `baseURL` for Lovelace / WallPanel dashboards (e.g. `/lovelace/tv` or `/`).
    public var dashboardPath: String
    public init(baseURL: String = "http://homeassistant.local:8123",
                token: String = "",
                useMock: Bool = true,
                controls: [HomeControl] = HomeControl.demoDefaults,
                uiMode: HomeUIMode = .controls,
                dashboardPath: String = "/") {
        self.baseURL = baseURL
        self.token = token
        self.useMock = useMock
        self.controls = controls
        self.uiMode = uiMode
        self.dashboardPath = dashboardPath
    }
    public var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public var looksLikePlaceholderToken: Bool {
        let value = trimmedToken.lowercased()
        return value.isEmpty
            || value.contains("replace")
            || value.contains("paste")
            || value == "your_token_here"
    }
    public var canUseLiveAPI: Bool {
        !useMock && !looksLikePlaceholderToken && URL(string: baseURL) != nil
    }
    /// Resolved dashboard URL for WKWebView / browser launch (open-source HA frontend).
    public var dashboardURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else { return nil }
        let raw = dashboardPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = raw.isEmpty ? "/" : (raw.hasPrefix("/") ? raw : "/" + raw)
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }
    public var prefersLovelaceUI: Bool {
        uiMode == .lovelace && dashboardURL != nil && !useMock
    }
    /// Show the optional Lovelace opener card (demoted after native controls).
    public var showsLovelaceCard: Bool {
        uiMode == .lovelace && dashboardURL != nil
    }

    enum CodingKeys: String, CodingKey {
        case baseURL, token, useMock, controls, uiMode, dashboardPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "http://homeassistant.local:8123"
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        useMock = try container.decodeIfPresent(Bool.self, forKey: .useMock) ?? true
        controls = try container.decodeIfPresent([HomeControl].self, forKey: .controls) ?? HomeControl.demoDefaults
        uiMode = try container.decodeIfPresent(HomeUIMode.self, forKey: .uiMode) ?? .controls
        dashboardPath = try container.decodeIfPresent(String.self, forKey: .dashboardPath) ?? "/"
    }
}

/// Open-source media library (Jellyfin preferred). Server is hosted by the user on this Mac mini.
public enum MediaLibraryProvider: String, Codable, Sendable {
    case jellyfin
    case emby
}

public struct MediaLibraryConfiguration: Codable, Equatable, Sendable {
    public var provider: MediaLibraryProvider
    public var baseURL: String
    /// Absolute paths the user should add as Jellyfin/Emby libraries (informational + seed).
    public var libraryRoots: [String]
    /// When true, mmTV opens the library Web UI inside the shell (WKWebView); otherwise `/usr/bin/open`.
    public var embedInShell: Bool
    public init(provider: MediaLibraryProvider = .jellyfin,
                baseURL: String = "http://127.0.0.1:8096",
                libraryRoots: [String] = MediaLibraryConfiguration.defaultLibraryRoots,
                embedInShell: Bool = true) {
        self.provider = provider
        self.baseURL = baseURL
        self.libraryRoots = libraryRoots
        self.embedInShell = embedInShell
    }
    public static let defaultLibraryRoots: [String] = [
        "/Volumes/mmTV Media/Media/Movies",
        "/Volumes/mmTV Media/Media/TV"
    ]
    public var libraryURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    public var displayTitle: String {
        switch provider {
        case .jellyfin: "Jellyfin 媒体库"
        case .emby: "Emby 媒体库"
        }
    }
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var entries: [AppEntry] = []
    public var disabledModules: Set<ModuleID> = []
    public var tvMode: Bool = false
    /// Optional HA block. Absent in older configs → Home stays on mock/setup path.
    public var homeAssistant: HomeAssistantConfiguration?
    /// Optional Jellyfin/Emby library. Absent → video module keeps app-launcher cards only.
    public var mediaLibrary: MediaLibraryConfiguration?
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
